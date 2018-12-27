---
layout: post
title: 装饰器闭包实现与类实现
date: 2018-12-27
update_date: 2018-12-27
summary: design pattern
logo: link
---

装饰器模式也叫修饰模式, 用于动态地给一个对象增加额外的职责. 复制以下维基百科的说明:

```
修饰模式，是面向对象编程领域中，一种动态地往一个类中添加新的行为的设计模式。就功能而言，修饰模式相比生成子类更为灵活，这样可以给某个对象而不是整个类添加一些功能。
```

装饰器的角色构成有:
- 抽象构件 Component
- 具体构件 ConcreteComponent
- 装饰 Decorator, 实现 Component, 同时持有一个 Component 对象
- 具体装饰 ConcreteDecorator

![Decorator](/assets/img/design-pattern/decorator/1.png)

从 UML 图中可以看出, ConcreteComponent 和 Decorator 都实现了 Component. 下面简单实现一个装饰器

```php
interface Component
{
    public function handle();
}

abstract class Decorator implements Component
{
    protected $component;

    public function __construct(Component $component)
    {
        $this->component = $component;
    }

    public function handle()
    {
        $this->operate();
        return $this->component->handle();
    }

    abstract public function operate();
}

class ConcreteComponent implements Component
{
    public function handle()
    {
        echo 'Component' . PHP_EOL;
    }
}

$component = new ConcreteComponent;

$concreteDecoratorA = new class($component) extends Decorator {
    public function operate()
    {
        echo 'A' . PHP_EOL;
    }
};

$concreteDecoratorB = new class($concreteDecoratorA) extends Decorator {
    public function operate()
    {
        echo 'B' . PHP_EOL;
    }
};

$concreteDecoratorB->handle();
```

得到输出:

```
B
A
Component
```

可以看出, 应用装饰器模式后, `Decorator` 可以为 `ConcreteComponent` 增加新的行为, 而不需要通过继承的方式, 从而避免众多由于子类增多导致的问题. 而 `Decorator` 的职责单一, 不需要改动 `ConcreteComponent`, 并且方便拆卸.

下面用装饰器来实现做煎饼的过程
```php
class ConcreteComponent implements Component
{
    public function handle()
    {
        echo '煎饼出锅' . PHP_EOL;
    }
}
abstract class Decorator implements Component
{
    protected $component;

    public function __construct(Component $component)
    {
        $this->component = $component;
    }
}
$component = new ConcreteComponent;
$a = new class($component) extends Decorator {
    public function handle()
    {
        echo '加火腿' . PHP_EOL;
        return $this->component->handle();
    }
};
$b = new class($a) extends Decorator {
    public function handle()
    {
        echo '加生菜' . PHP_EOL;
        return $this->component->handle();
    }
};
$c = new class($b) extends Decorator {
    public function handle()
    {
        echo '下蛋' . PHP_EOL;
        return $this->component->handle();
    }
};
$d = new class($c) extends Decorator {
    public function handle()
    {
        echo '下面液' . PHP_EOL;
        return $this->component->handle();
    }
};
$e = new class($d) extends Decorator {
    public function handle()
    {
        echo '刷油' . PHP_EOL;
        return $this->component->handle();
    }
};

$e->handle();
```

输出

```
刷油
下面液
下蛋
加生菜
加火腿
煎饼出锅
```

这样, 你就可以方便地加培根, 加番茄酱, 加各种肉各种酱...

而手动关联这一步也可以稍加修改用闭包来实现, 主要使用了 `array_reduce()` 来产生一个 callback 来实现 `Decorator` 对 `Component` 的调用.
并返回 `Decorator` 作为 `Component`.

```php
abstract class Decorator implements Component
{
    protected $component;

    public function setComponent(Component $component)
    {
        $this->component = $component;

        return $this;
    }
}

$a = new class extends Decorator {
    public function handle()
    {
        return $this->component->handle();
    }
};

// ... 

$callback = array_reduce(
    [$c, $b, $a],
    function (Component $carry, Decorator $item) {
        return $item->setComponent($carry);
    },
    new ConcreteComponent()
);
print_r($callback->handle());
```

那么再来一个更加彻底的闭包实现:

```php
// concreteDecorator, callback is component
$a = function ($callback) {
    echo 'a' . PHP_EOL;
    return $callback();
};

$b = function ($callback) {
    echo 'b' . PHP_EOL;
    return $callback();
};

$c = function ($callback) {
    echo 'c' . PHP_EOL;
    return $callback();
};

$callback = array_reduce(
    [$c, $b, $a],

    function ($carry, $item) {

        return function () use ($carry, $item) {
            return $item($carry);
        };

    },

    function () {
        echo 'hello world' . PHP_EOL;
    }
);

echo $callback() . PHP_EOL;
```

那么当实现到这一步的时候, 已经接近管道模式 (pipeline pattern) 了. 下次再来 🤪

