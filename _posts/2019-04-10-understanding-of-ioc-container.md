---
layout: post
title: IoC 容器理解
date: 2019-04-10
update_date: 2019-04-10
summary: IoC Container
logo: inbox
---

最近一直想写个 php 的 IoC 容器, 参考 Laravel 的 Container 整理了一下先汇总一下思路.

#### 控制反转

先摘抄一下控制反转 (IoC) 在维基百科上的解释:

```
控制反转（Inversion of Control，缩写为IoC），是面向对象编程中的一种设计原则，可以用来减低计算机代码之间的耦合度。其中最常见的方式叫做依赖注入（Dependency Injection，简称DI），还有一种方式叫“依赖查找”（Dependency Lookup）。
```

也就是, 依赖注入和依赖查找是控制反转的实现. 他们做的事情, 最终的目的就是: 让类所关联或依赖的其他类不需要显式地创建, 而是通过外部容器注入, 进而达到解耦和单一职责的目的.

依赖查找一般用工厂方法来实现, 而依赖注入通常有几种实现方式:
- 基于接口
- 基于 set
- 基于构造方法
- 基于注释 (或类型约束)

下面用简单的伪代码来看有无使用控制反转的区别:

```php
class Alpha
{
}

class Beta
{
    protected $alpha;

    // Before
    public function __construct()
    {
        $this->alpha = new Alpha();
    }

    // 依赖注入
    public function __construct(Alpha $alpha)
    {
        $this->alpha = $alpha;
    }

    // 依赖查找
    public function __construct()
    {
        $this->alpha = factory::get('alpha');
    }
}
```

> 由于是示例所以 `Alpha` 相对简单. 但当 `Alpha` 是一个 db connection 时, 就需要获取 connection config 并传入, 如果需要在每个地方都这么操作那将是非常麻烦的.

<!-- #### 依赖注入 -->

<!-- 依赖注入, 在 PHP 中最常见的形式就是给类的构造方法的参数定义类型约束, 通过容器的工厂方法来解析参数取得依赖从而创建对象.  -->

#### 容器

容器提供依赖实例的方式除了依靠框架的自动加载以外, 容器自身还维护了一个 map 来保存一些类的别名, 从而实现通过某个类的类名或是他的别名来从容器中获取实例 (应用场景之一就是绑定接口到某个实现). 甚至是可以根据对象的不同, 为同个别名绑定不同的实现, 从而实现根据上下文绑定实现.

容器还可以保存对于一些可以共享复用的对象, 从而避免重复实例化, 也可以看做是间接实现了单例.

下面用 php 来实现一个简单的 IoC 容器.

```php
use Closure;
use ReflectionClass;
use ReflectionParameter;
use RuntimeException;
use ReflectionException;
use Exception;

class Container
{
    /**
     * @var array
     */
    protected $bindings = [];

    /**
     * @param string $name
     * @param string|null $concrete
     */
    public function bind($name, $concrete = null)
    {
        if (is_null($concrete)) {
            $concrete = $name;
        }

        $this->bindings[$name] = $concrete;
    }

    /**
     * @param string $name
     * @return object
     * @throws ReflectionException
     */
    public function build($name)
    {
        $concrete = $this->getConcrete($name);

        if ($concrete instanceof Closure) {
            return $concrete($this);
        }

        $reflector = new ReflectionClass($concrete);

        if (!$reflector->isInstantiable()) {
            throw new RuntimeException(sprintf('%s is not instantiable', $name));
        }

        $constructor = $reflector->getConstructor();

        if (!$constructor || !$constructor->getParameters()) {
            return $reflector->newInstance();
        }

        return $reflector->newInstanceArgs($this->getDependencies($constructor->getParameters()));
    }

    /**
     * @param ReflectionParameter[] $reflectionParameters
     * @return array
     * @throws
     */
    protected function getDependencies(array $reflectionParameters)
    {
        $result = [];
        foreach ($reflectionParameters as $parameter) {
            if (!is_null($parameter->getClass())) {
                try {
                    $result[] = $this->build($parameter->getClass()->getName());
                } catch (Exception $exception) {
                    if (!$parameter->isOptional()) {
                        throw $exception;
                    }
                    $result[] = $parameter->getDefaultValue();
                }
            } else {
                if (!$parameter->isDefaultValueAvailable()) {
                    throw new RuntimeException(
                        sprintf(
                            'parameter %s has no default value',
                            $parameter->getName()
                        )
                    );
                }
                $result[] = $parameter->getDefaultValue();
            }
        }

        return $result;
    }

    /**
     * @param $name
     * @return string|Closure
     */
    protected function getConcrete($name)
    {
        $concrete = $name;

        while (true) {
            if (!isset($this->bindings[$concrete]) || $concrete === $this->bindings[$concrete]) {
                return $concrete;
            }
            if (($concrete = $this->bindings[$concrete]) instanceof Closure) {
                return $concrete;
            }
        }
    }
}
```

然后来试着调用一下:

```php
class Runner
{
    protected $stack;

    public function __construct(SplStack $stack)
    {
        $this->stack = $stack;
    }
}

interface DemoInterface
{}

class Demo implements DemoInterface
{}

class Alpha
{
    protected $demo;

    public function __construct(DemoInterface $demo)
    {
        $this->demo = $demo;
    }
}

class RunnerSecond
{
    public function __construct()
    {
//        throw new RuntimeException('hello world');
    }
}

class Holy
{
    protected $runner;
    public function __construct(RunnerSecond $runner = null)
    {
        $this->runner = $runner;
    }
}

$container = new Container();

$container->bind('holy', SplStack::class);

$container->bind('emmmmmmm', function (Container $container) {
    return $container->build(SplQueue::class);
});

$container->bind(DemoInterface::class, Demo::class);

$a = $container->build(Runner::class);

$b = new Runner($container->build('holy'));

print_r($a);

print_r($b);

print_r($container->build('emmmmmmm'));

print_r($container->build(Alpha::class));

print_r($container->build(Holy::class));
```
