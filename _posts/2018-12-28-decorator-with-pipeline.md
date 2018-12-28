---
layout: post
title: 管道与装饰器
date: 2018-12-28
update_date: 2018-12-28
summary: pattern design
logo: arrows-v
---

管道模式 (pipeline pattern) 是一种用于将复杂的逻辑拆分为多个子任务单元的设计模式. 每个子任务将载荷处理完成后将处理结果传递给下个子任务, 并在管道末端返回最终结果.

管道模式的角色构成有:

- 载荷 (Payload)
- 阶段 (Stage)
- 管道 (Pipeline), 持有多个 Stage 实现


![Pipeline](/assets/img/design-pattern/pipeline/1.png)

直接简单实现一个管道

```php
interface StageInterface
{
    public function handle($payload);
}

interface PipelineInterface
{
    public function pipe(StageInterface $stage);

    public function process($payload);
}

class Pipeline implements PipelineInterface
{
    protected $stages;

    public function pipe(StageInterface $stage)
    {
        $this->stages[] = $stage;
        return $this;
    }

    public function process($payload)
    {
        foreach ($this->stages as $stage) {
            $payload = $stage->handle($payload);
        }
        return $payload;
    }
}
$a = new class implements StageInterface {
    public function handle($payload)
    {
        echo 'a' . PHP_EOL;
        return $payload * 2;
    }
};

$b = new class implements StageInterface {
    public function handle($payload)
    {
        echo 'b' . PHP_EOL;
        return $payload + 3;
    }
};

echo (new Pipeline())->pipe($a)->pipe($b)->process(1) . PHP_EOL;

```

输出

```
a
b
5
```

可以看到管道模式中, 每个阶段是接收上个阶段返回处理后的 payload 进行再次处理, 并传递给下个阶段. 这跟装饰器的执行过程是类似的, 依靠多个附加的功能类依次调用来实现各自的目的.

正常情况下, 管道的每个阶段里都无法看到载荷的原始载荷, 也无法像装饰器一样可以先调用下一个阶段获得结果.

把传入 payload 视为流入, 返回结果视为流出的话, 也就是每个阶段只能控制阶段本身的流出. 那如果想做到处理阶段本身的流出, 同时控制后面其他阶段的流出, 要怎么实现呢?

![Pipeline Stream](/assets/img/design-pattern/pipeline/2.png)

结合装饰器, 我把装饰器中的 Decorator 与管道中的 Stage 结合, 在 Stage 中维持一个 Stage 对象, 相当于 Decorator 中 维持有 Component.

具体看代码:

```php
class Stage
{
    protected $callback;

    protected $next;

    public function __construct($callback, self $next = null)
    {
        $this->callback = $callback;
        $this->next = $next;
    }

    public function handle($payload)
    {
        // destination callback (without next stage)
        if (is_null($this->next)) {
            return call_user_func($this->callback, $payload);
        }

        return call_user_func($this->callback, $payload, function ($payload) {
            return $this->next->handle($payload);
        });
    }
}

class Pipeline
{
    protected $decorators = [];

    protected $payload;

    protected $method = 'handle';

    public function payload($payload)
    {
        $this->payload = $payload;

        return $this;
    }

    public function pipe($decorator)
    {
        $this->decorators[] = $decorator;

        return $this;
    }

    public function method($method)
    {
        $this->method = $method;

        return $this;
    }

    public function process($callback = null)
    {
        $stage = array_reduce(
            array_reverse($this->decorators),
            $this->carry(),
            new Stage($this->prepareCallback($callback))
        );

        return $stage->handle($this->payload);
    }

    protected function carry()
    {
        return function ($stage, $decorator) {
            return new Stage(
                is_callable($decorator) ? $decorator : [$decorator, $this->method],
                $stage
            );
        };
    }

    protected function prepareCallback($callback = null)
    {
        if (is_null($callback)) {
            $callback = function ($payload) {
                return $payload;
            };
        }

        return $callback;
    }
}

$pipeline = new Pipeline();

$a = function ($payload, $next) {
    echo 'a' . PHP_EOL;
    return $next($payload);
};
$b = function ($payload, $next) {
    echo 'b' . PHP_EOL;
    return $next($payload);
};
$c = new class{
    public function handle($payload, $next)
    {
        echo 'c' . PHP_EOL;
        return $next($payload);
    }
};

$result = $pipeline->pipe($a)->pipe($b)->pipe($c)->method('handle')->payload(1)->process(function ($payload) {
    return $payload * 20;
});
```

输出

```
a
b
c
20
```

其实, 这几乎就已经实现了一个中间件啦.

### 参考
- [https://github.com/RunnerLee/pipeline](https://github.com/RunnerLee/pipeline)
- [https://blog.csdn.net/AIkiller/article/details/79296236](https://blog.csdn.net/AIkiller/article/details/79296236)
- [https://github.com/thephpleague/pipeline](https://github.com/thephpleague/pipeline)
- [https://github.com/illuminate/pipeline](https://github.com/illuminate/pipeline)