---
layout: post
title: 为 FastD 更换路由组件
date: 2019-01-04
update_date: 2019-01-04
summary: 玩一玩
logo: cut
---

前公司的同事问我 FastD 的路由匹配的事, 最后确定框架提供的路由暂时没办法满足他的需求. 一时间又懒得研究, 那就干脆换个路由吧.

[FastRoute](https://github.com/nikic/FastRoute) 是个十分强大而又简易的路由组件, 就选定用 "FastRoute" 来换.

FastD 本身的路由调度. 大致步骤是:

```
bootstrap -> createRequest -> handleRequest -> dispatchToRouter -> handleResponse -> sendResponse
```

而在路由调度中, 主要分几个步骤:

```
路由注册 -> 匹配路由 -> 执行匹配路由
```

直接看一下 FastD 的实现

```php

namespace FastD;

class Application extends Container
{
    public function handleRequest(ServerRequestInterface $request)
    {
        try {
            $this->add('request', $request);

            return $this->get('dispatcher')->dispatch($request);
        } catch (Exception $exception) {
            return $this->handleException($exception);
        } catch (Throwable $exception) {
            $exception = new FatalThrowableError($exception);

            return $this->handleException($exception);
        }
    }
}
```

```php

namespace FastD\Routing;

class RouteDispatcher extends Dispatcher
{
    public function dispatch(ServerRequestInterface $request)
    {
        $route = $this->routeCollection->match($request);

        foreach ($this->appendMiddleware as $middleware) {
            $route->withAddMiddleware($middleware);
        }

        return $this->callMiddleware($route, $request);
    }
}

```

大概的 UML 图
![routing](/assets/img/2019-01-04/2.png)

当然 UML 中的 `Router` 是 Laravel 中的叫法, FastD 中叫的是 `Dispatcher`. 

那么用 FastRoute 来替换的话, 由于 FastRoute 的 `Dispatcher` 需要将路由配置解析成数组再传入构造方法, 因此需要把 `Router` 拆分出一个 `RouteDispatcher`.

看一下 UML 图
![routing](/assets/img/2019-01-04/1.png)

然后是实现

```php

use FastRoute\RouteCollector;

/**
 * Class Router.
 *
 * @method get($uri, $action, $middleware = [])
 * @method post($uri, $action, $middleware = [])
 * @method put($uri, $action, $middleware = [])
 * @method patch($uri, $action, $middleware = [])
 * @method delete($uri, $action, $middleware = [])
 * @method options($uri, $action, $middleware = [])
 */
class Router
{
    protected $routes;

    protected $methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'];

    public function __construct(RouteCollector $collector)
    {
        $this->routes = $collector;
    }

    public function addRoute($method, $uri, $action, $middleware = [])
    {
        $this->routes->addRoute($method, $uri, [
            'callback' => $action,
            'middleware' => $middleware,
        ]);
    }

    public function __call($name, $arguments)
    {
        if (in_array($method = strtoupper($name), $this->methods)) {
            $this->addRoute($method, ...$arguments);
        }
    }
}
```

```php
use FastD\Routing\Exceptions\RouteNotFoundException;
use FastD\Routing\Route;
use FastD\Routing\RouteCollection;
use FastRoute\Dispatcher;
use FastRoute\RouteCollector;
use Psr\Http\Message\ServerRequestInterface;
use FastD\Routing\RouteDispatcher as FastDRouteDispatcher;

class RouteDispatcher
{
    protected $dispatcher;

    protected $fastDRouteDispatcher;

    public function __construct(RouteCollector $routes)
    {
        $this->dispatcher = new Dispatcher\GroupCountBased($routes->getData());

        $this->fastDRouteDispatcher = new FastDRouteDispatcher(
            new RouteCollection(),
            config()->get('middleware', [])
        );
    }

    public function dispatcher()
    {
        return $this->dispatcher;
    }

    public function dispatch(ServerRequestInterface $request)
    {
        $result = $this->dispatcher->dispatch(
            $request->getMethod(),
            $request->getUri()->getPath()
        );

        switch ($result[0]) {
            case Dispatcher::NOT_FOUND:
            case Dispatcher::METHOD_NOT_ALLOWED:
                throw new RouteNotFoundException($request->getUri()->getPath());
        }

        foreach ($result[2] as $key => $value) {
            $request->withAttribute($key, $value);
        }

        $route = new Route($request->getMethod(), $request->getUri()->getPath(), $this->concat($result[1]['callback']));

        $route->withAddMiddleware($result[1]['middleware']);

        return $this->fastDRouteDispatcher->callMiddleware($route, $request);
    }

    protected function concat($callback)
    {
        if (!is_string($callback)) {
            return $callback;
        }

        return "Controller\\{$callback}";
    }
}
```

最终再做一个 `RouteServiceProvider`

```php
use FastD\Container\Container;
use FastD\Container\ServiceProviderInterface;
use FastRoute\DataGenerator\GroupCountBased as GroupCountBasedDataGenerator;
use FastRoute\RouteCollector;
use FastRoute\RouteParser\Std;

class RouteServiceProvider implements ServiceProviderInterface
{
    public function register(Container $container)
    {
        $routes = new RouteCollector(
            new Std(),
            new GroupCountBasedDataGenerator()
        );

        $container->add('router', new Router($routes));
        $container->add('routes', $routes);

        $this->mapRoutes();

        $container->add('dispatcher', new RouteDispatcher($routes));
    }

    protected function mapRoutes()
    {
        require app()->getPath().'/config/routes.php';
    }
}
```

然后就可以在路由中这么配置啦:

```
$router = app()->get('router');

$router->get('/users/{id:\d+}', 'UsersController@show', [
    // middlewares
]);
```

这样就算告一段落, 但是还是需要解决下 group, 以及研究下 FastRoute 他到底 fast 在哪里.

### 参考
- [https://github.com/RunnerLee/fastd-fastroute](https://github.com/RunnerLee/fastd-fastroute)
- [https://github.com/nikic/FastRoute](https://github.com/nikic/FastRoute)
