---
layout: post
title: IoC 容器理解
date: 2019-04-10
update_date: 2019-04-26
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
}

// 依赖查找并注入依赖
new Beta(Factory::get('alpha'));
```

> 由于是示例所以 `Alpha` 相对简单. 但当 `Alpha` 是一个 db connection 时, 就需要获取 connection config 并传入, 如果需要在每个地方都这么操作那将是非常麻烦的.

<!-- #### 依赖注入 -->

<!-- 依赖注入, 在 PHP 中最常见的形式就是给类的构造方法的参数定义类型约束, 通过容器的工厂方法来解析参数取得依赖从而创建对象.  -->

#### 容器

容器总是在创建外部所需要的 service, 就像上面的查找依赖的例子一样, 外部通过一个 key 来向容器索取所需要的实例.

容器除了依靠框架提供的自动加载来创建所需实例依赖, 还维护了一个 map 来关联绑定 key 跟实现. 所以这里的 key 更像是一个别名, 他可以有多种形式, 从而可以实现各种类型的绑定:
* 普通的绑定, 用类名绑定自己
* 语义化别名的绑定, 例如用 `cache` 绑定到 `FileCache::class` 的实现上
* 接口绑定实现, 例如用 `CacheInterface::class` 绑定到 `FileCache::class` 上
* 递归地绑定别名, 例如将 `db` 绑定到 `MySQLConnection::class` 的实现上, 将 `mysql` 绑定到 `db` 上


在实际实现中, 一些 service 例如 DBConnection 应当避免重复实例化, 亦或是实例可以复用时, 除了依赖 service 自身实现的单例以外, 容器也应当实现避免重复创建 (通过容器间接实现单例), 因此需要将一些指定的 service 实例保存起来.

同时, 也可能会遇到一些无法或不建议通过容器创建的实例, 但同样需要避免重复实例化或可用于复用时, 容器应当支持直接将实例注册到容器中.

容器在创建 service 实例时, service 的构造方法可能存在需要注入的依赖, 可以通过反射来获取参数的类型约束, 并使用类型约束从容器获取对应的实例 (递归).
所以在有些容器的实现中, 加入了 "上下文绑定" (contextual binding) 的特性. 既绑定某个类需要注入的依赖所能获取到的具体实现.

简单地定义一个容器的接口:

```php

interface ContainerInterface
{
    public function bind($name, $contrete);

    public function make($name);

    public function instance($name, $instance);
}
```

我把实现提交到了 GitHub: [https://github.com/RunnerLee/container](https://github.com/RunnerLee/container)

#### 参考

- [Laravel Container](https://laravel.com/docs/5.8/container)
- [Pimple](https://pimple.symfony.com/)
- [依赖注入与Ioc容器](https://blog.csdn.net/dream_successor/article/details/79078905)
- [\[Wikipedia\] inversion of control](https://en.wikipedia.org/wiki/Inversion_of_control)

