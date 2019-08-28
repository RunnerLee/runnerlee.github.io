---
layout: post
title: symfony workflow 使用
date: 2019-08-28
update_date: 2019-08-28
summary: 状态机使用
logo: circle-o-notch
---

看到部门其他组的项目用到了 [symfony/workflow](https://symfony.com/doc/current/workflow.html) 这个包, 看了一下文档, 用在状态机场景时相比之前自己写的状态机有几个比较好的特性:

- 更加丰富全面的触发事件
- 灵活 `marking store` 可以用来处理多种形态的 `subject`
- metadata 绑定
- 基于配置文件配置及关联 `subject`

### 摘抄一些概念

`symfony/workflow` 是一个 [Petri 网](https://en.wikipedia.org/wiki/Petri_net) 的实现, 而 状态机 (state machine) 是它的一个子集. 更多的概念就不深入 (想深入也深入不了呀...), 摘抄一下其中几个重要的名词和概念:

一个 Petri 网模型包含这些元素:

- place 库所
- transition 变迁
- Arc 有向弧
- Token 令牌

```
一个工作流的 definition 包括 places 和actions, 以从一个位置来到另一个位置. actions 被称为 transistions. 工作流也需要知道每个对象在工作流中的位置. 那个 marking store 写入了对象的一个属性来记住当前位置.
```

![](/assets/img/2019-08-28/1.png)

![](/assets/img/2019-08-28/2.png)

### 动手实操

假设有订单表, 订单有 已下单 / 已支付 / 已完成 / 已退款 四个状态, 他的状态机定义是这样的

![](/assets/img/2019-08-28/3.png)

使用 `symfony/workflow` 来定义这个状态机:

```php
$config = [
    'order' => [
        'type' => 'state_machine',
        'single_status' => true,
        'marking_property' => 'status',
        'support' => Order::class,
        'places' => [
            'created',
            'paid',
            'completed',
            'refunded',
        ],
        'transitions' => [
            'to_pay' => [
                'from' => 'created',
                'to' => 'paid',
            ],
            'to_complete' => [
                'from' => 'paid',
                'to' => 'completed',
            ],
            'to_refund' => [
                'from' => 'paid',
                'to' => 'refund',
            ],
        ],
    ],
];
```

定义 `Order` 

```php
class Order
{
    protected $status;

    public function setStatus($status)
    {
        $this->status = $status;
    }

    public function getStatus()
    {
        return $this->status;
    }
}
```

创建 workflow:

```php
use Symfony\Component\Workflow\Registry;
use Symfony\Component\Workflow\Transition;
use Symfony\Component\Workflow\StateMachine;
use Symfony\Component\Workflow\DefinitionBuilder;
use Symfony\Component\EventDispatcher\EventDispatcher;
use Symfony\Component\Workflow\SupportStrategy\InstanceOfSupportStrategy;

$builder = new DefinitionBuilder();

$builder->addPlaces($config['order']['places']);

foreach ($config['order']['transitions'] as $name => $transition) {
    $builder->addTransition(new Transition($name, $transition['from'], $transition['to']));
}

$dispatcher = new EventDispatcher();

$workflow = new StateMachine(
    $builder->build(),
    new MethodMarkingStore($config['order']['single_status'], $config['order']['marking_property']),
    $dispatcher,
    'order'
);

$registry = new Registry();

$registry->addWorkflow($workflow, new InstanceOfSupportStrategy($config['order']['support']));
```

接下来就是使用啦:

```php

$order = new Order();

$order->setStatus('created');

$workflow = $registry->get($order);

if ($workflow->can($order, 'to_pay')) {
    $workflow->apply($order, 'to_pay');
}

```

### 一些 Tips

#### transition 尽量避免多个 `from`

虽然 [symfony/workflow] 支持单个这个特性, 但使用也有对应的规则: 要应用 transition 时从 subject 获取到的 place 必须跟 transition 的 from 保持一致.

```php
private function buildTransitionBlockerListForTransition($subject, Marking $marking, Transition $transition)
{
    foreach ($transition->getFroms() as $place) {
        if (!$marking->has($place)) {
            return new TransitionBlockerList([
                TransitionBlocker::createBlockedByMarking($marking),
            ]);
        }
    }

    if (null === $this->dispatcher) {
        return new TransitionBlockerList();
    }

    // 注意在这里触发了 guard 事件
    $event = $this->guardTransition($subject, $marking, $transition);

    if ($event->isBlocked()) {
        return $event->getTransitionBlockerList();
    }

    return new TransitionBlockerList();
}
```

#### 避免在 guard 事件监听中做中断退出操作

这主要是因为 announce 事件导致的, 看一下源码:

```php
private function announce($subject, Transition $initialTransition, Marking $marking): void
{
    ...

    foreach ($this->getEnabledTransitions($subject) as $transition) {
        $this->dispatcher->dispatch($event, sprintf('workflow.%s.announce.%s', $this->name, $transition->getName()));
    }
}

public function getEnabledTransitions($subject)
{
    $enabledTransitions = [];
    $marking = $this->getMarking($subject);

    // 在这里是将 apply 了 transition 后, 以 subject 当前的 place 作为 from, 获取所有是这个 from 的 transition
    // 在 buildTransitionBlockerListForTransition() 方法中, 会触发 guard 事件
    // 也就是如果定义了 a b c 三个 place, a->b 定义为 alpha, b->c 定义为 beta
    // 那么当 apply 了 alpha 之后, 会触发 beta 的 guard 事件
    foreach ($this->definition->getTransitions() as $transition) {
        $transitionBlockerList = $this->buildTransitionBlockerListForTransition($subject, $marking, $transition);
        if ($transitionBlockerList->isEmpty()) {
            $enabledTransitions[] = $transition;
        }
    }

    return $enabledTransitions;
}
```

#### 结合乐观锁

直接上一个结合 eloquent 的例子:

```php

public function setStatus($status, array $context)
{
    $result = $this
    ->newQuery()
    ->where([
        'id' => $this->attributes['id'],
        'status' => $this->attributes['status'],
    ])
    ->update([
        'status' => $status,
    ]);

    if (!$result) {
        throw new MarkingStateException(sprintf(
            'failed to set the "%s" status for model [%s] %s',
            $status,
            static::class,
            $this->attributes['id']
        ));
    }

    $this->attributes['status'] = $this->original['status'] = $status;
}

```

### 参考

- [symfony/workflow](https://symfony.com/doc/current/workflow.html)
- [Petri net](https://en.wikipedia.org/wiki/Petri_net)
- [https://github.com/symfony/symfony/issues/20788#issuecomment-265218446](https://github.com/symfony/symfony/issues/20788#issuecomment-265218446)

