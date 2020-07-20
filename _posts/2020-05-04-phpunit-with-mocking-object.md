---
layout: post
title: 单元测试的对象mocking
date: 2020-05-04
update_date: 2020-05-04
summary: 单元测试
logo: baby
---

通过 laravel 的 testing 了解到 [mockery/mockery](https://github.com/mockery/mockery) 这个包。这个包主要有两个功能：`Method Stubs` 和 `Test Spies`. 

使用比较好上手，看下 laravel facade 中的集成 mockery 的使用和实现

```php
# https://laravel.com/docs/7.x/mocking#mocking-facades

use SomeServiceFacade;    // facade
use Tests\TestCase;

class SomeTest extend TestCase
{
    public function testSomething()
    {
        SomeServiceFacade::shouldReceive('foo')
            ->once()
            ->with('bar')
            ->andReturn('val');

        // do some testing
    }
}
```

在这段测试中，`SomeServiceFacade` 是一个 facade，如果没有调用到 `SomeServiceFacade::foo()` 或是调用次数大于一次就会抛异常，调用到时会返回 `val`. 

并且当测试步骤中，通过 `SomeServiceFacade::getFacadeRoot()` 获取到的 facade 的 `root object` 实际上是 `Mockery\Mock` 实例。

```php
namespace Illuminate\Support\Facades;

abstract class Facade
{
    public static function shouldReceive()
    {
        $name = static::getFacadeAccessor();

        $mock = static::isMock()
                    ? static::$resolvedInstance[$name]
                    : static::createFreshMockInstance();

        return $mock->shouldReceive(...func_get_args());
    }

    protected static function createFreshMockInstance()
    {
        return tap(static::createMock(), function ($mock) {
            static::swap($mock);

            $mock->shouldAllowMockingProtectedMethods();
        });
    }
}
```

这个功能我一般来用测试调用了子系统或外部系统的地方。例如某个功能需要调用子系统获取数据并加工后返回给客户端，在编写测试时，








