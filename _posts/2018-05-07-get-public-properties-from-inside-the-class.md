---
layout: post
title: 从对象内部获取对象所有 public 属性
date: 2018-05-07
update_date: 2018-06-13
summary: OOP Visibility
logo: object-group
---

刷到这条面试题, 从对象内部获取对象的所有 public 属性并以数组形式返回, 尽量不使用反射, 并封装为 trait, 当时直接就这么做了:

```php
return get_class_vars(static::class);
```

然后转眼就发现懵逼了...

因为调用 `get_class_vars()` 或是 `get_object_vars()` 都是在类内部运行, 由于类作用域的关系, 他是可以获取到保护和私有属性的. 这就懵逼了.

那么解决的话就是一个思路, 在当前类的作用域的外部执行这个就行了. 目前想到的是两种办法:

1. 在方法中通过匿名类解决.

```php
<?php
trait Tool
{
    protected $callback;

    public function getPublicPropertries()
    {
        if (is_null($this->callback)) {
            $this->callback = new class {
                public function __invoke($class)
                {
                    return get_object_vars($class)
                }
            };
        }
        return call_user_func($this->callback, $this);
    }
}
```

2. 通过 Closure::bind() 创建匿名函数并绑定对象和作用域到一个匿名类.

> bind() 不支持绑定到匿名类或是 PHP 内置类 (例如 \stdClass)

```php
<?php
trait Tool
{
    public function getPublicPropertries()
    {
        $class = new class{};
        $callback = Closure::bind(
            function ($class) {
                return get_object_vars($class);
            },
            $class,
            $class
        );

        return $callback($this);
    }
}
```

这样就解决问题了.

加油加油 💪

