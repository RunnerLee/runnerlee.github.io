---
layout: post
title: laravel auth 的小知识点
date: 2019-07-10
update_date: 2019-07-10
summary: 这 "bug" 气死人
logo: code
---

部门的新项目用了 laravel 5.5 开发, 今天推到测试环境发现在模型的 `boot()` 静态方法中注册的事件监听不起作用. 代码示例:

```php
public static function boot()
{
    parent::boot();
    if ($user = Auth::user()) {
        static::creating(function ($model) {
            $model->create_uid = Auth::user()->id;
        });
    }
}
```

还好是测试环境, 猜测是在这个地方读取不到 session, 导致拿不到用户登录态, 所以没注册到监听. 所以临时改为在监听里面判断登录态:

```php
static::creating(function ($model) {
    if ($user = Auth::user()) {
        $model->create_uid = Auth::user()->id;
    }
});
```

本篇完... 当然是不可能的啦, 需要找出为什么在这里还没读取到 session. 那么需要定位两个问题:

1. 都知道 laravel 的 session handler 是自己实现的, 需要确定在哪里进行了 `session_start`
2. 模型创建实例, 应该是在 `session_start` 之前, 那在哪里创建的实例

首先看一下 laravel 的 session, 是通过 `StartSession` 这个中间件来开启 session

```php
public function handle($request, Closure $next)
{
    $this->sessionHandled = true;
    
    // 前置先加载 session
    if ($this->sessionConfigured()) {
        $request->setLaravelSession(
            $session = $this->startSession($request)
        );

        $this->collectGarbage($session);
    }
    $response = $next($request);

    // 将 session_id 放到响应的 cookie 里 
    if ($this->sessionConfigured()) {
        $this->storeCurrentUrl($request, $session);

        $this->addCookieToResponse($response, $session);
    }
    return $response;
}

public function getSession(Request $request)
{
    // 通过 Illuminate\Session\SessionManager 获取 session driver
    return tap($this->manager->driver(), function ($session) use ($request) {
        // 注意在这里将 cookie 中的 session id 传到 driver 中
        $session->setId($request->cookies->get($session->getName()));
    });
}

protected function startSession(Request $request)
{
    return tap($this->getSession($request), function ($session) use ($request) {
        $session->setRequestOnHandler($request);

        // 获取了驱动并设置了 session_id 后, 在这里进行 session_start
        $session->start();
    });
}
```

然后再由具体的 driver 进行读取 session, 具体先不看. 到这里就拿到了 session, 
如果 auth 使用的是 `SessionGuard` 的话, 那么就可以通过 `Auth::user()` 拿到登录用户了. 

但是拿不到, 那就证明还没到这步. 部门的这个项目用到了 [prettus/l5-repository](https://github.com/andersao/l5-repository) 这个包.

我在控制器的构造方法中增加了一个依赖注入将一个我的 `Repository` 注入进去, 那么就可以确定, 拿控制器实例的时候, `StartSession` 这个中间件还没运行到.

看一下 route dispatcher.

```php
protected function sendRequestThroughRouter($request)
{
    $this->app->instance('request', $request);

    Facade::clearResolvedInstance('request');

    $this->bootstrap();

    return (new Pipeline($this->app))
                ->send($request)
                ->through($this->app->shouldSkipMiddleware() ? [] : $this->middleware)
                ->then($this->dispatchToRouter());
}

protected function dispatchToRouter()
{
    return function ($request) {
        $this->app->instance('request', $request);

        return $this->router->dispatch($request);
    };
}
```

没错啦, 还是 pipeline, 那大概猜到了, 先创建了控制器实例, 然后放进管道作为第一个 stage. 具体再定位进去:

```php
protected function runRouteWithinStack(Route $route, Request $request)
{
    $shouldSkipMiddleware = $this->container->bound('middleware.disable') &&
                            $this->container->make('middleware.disable') === true;

    $middleware = $shouldSkipMiddleware ? [] : $this->gatherRouteMiddleware($route);

    return (new Pipeline($this->container))
                    ->send($request)
                    ->through($middleware)
                    ->then(function ($request) use ($route) {
                        return $this->prepareResponse(
                            $request, $route->run()
                        );
                    });
}
```

在 Router 里面是另外一层管道, 把 `Route::run()` 放在第一个 stage 里面执行. 到 `Route::run()` 里面就是直接调用控制器的 action 了. 所以这个管道就是执行路由所配置的中间件了.

因为 laravel 支持在控制器里面再配置中间件, 所以到这里就猜测应该是在这里获取控制器中配置的中间件然后连同在路由中配置的中间件

看一下 `Router::gatherRouteMiddleware()`

```
public function gatherRouteMiddleware(Route $route)
{
    $middleware = collect($route->gatherMiddleware())->map(function ($name) {
        return (array) MiddlewareNameResolver::resolve($name, $this->middleware, $this->middlewareGroups);
    })->flatten();

    return $this->sortMiddleware($middleware);
}
```

再看 `Route::gatherMiddleware()`, 果不其然, 有调用 `Route::controllerMiddleware()`, 干脆一路追踪下去

```
public function gatherMiddleware()
{
    if (! is_null($this->computedMiddleware)) {
        return $this->computedMiddleware;
    }

    $this->computedMiddleware = [];

    return $this->computedMiddleware = array_unique(array_merge(
        $this->middleware(), $this->controllerMiddleware()  // 在这里获取控制器配置的中间件
    ), SORT_REGULAR);
}

public function controllerMiddleware()
{
    if (! $this->isControllerAction()) {
        return [];
    }

    return $this->controllerDispatcher()->getMiddleware(
        // 在这里去获取控制器实例
        $this->getController(), $this->getControllerMethod()
    );
}

public function getController()
{
    if (! $this->controller) {
        $class = $this->parseControllerCallback()[0];
        // 在这里获取到控制器的实例, 到这一步的时候, StartSession 这个中间件还没执行.
        // 准确地将, 整个中间件管道还没开始执行, 那么在这里获取 session 并取得登录用户, 是不可行的
        $this->controller = $this->container->make(ltrim($class, '\\'));
    }

    return $this->controller;
}
```

这样就算是把问题定位出来了, 那么就按照一开始的修改去解决这个问题就好了. 

#### 参考

暂无, 纯靠自己人肉 DEBUG

