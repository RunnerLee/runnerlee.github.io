---
layout: post
title: laravel 接入 jaeger 分布式追踪系统
date: 2019-08-05
update_date: 2019-08-05
summary: 算是初探吧
logo: connectdevelop
---

Jaeger 是一个兼容 opentracing 的分布式追踪系统, 摘抄一下阿里云栖里的文章来理解一下:

```
这种弹性、标准化的架构背后，原先运维与诊断的需求也变得越来越复杂。为了应对这种变化趋势，诞生一系列面向 DevOps 的诊断与分析系统，包括集中式日志系统（Logging），集中式度量系统（Metrics）和分布式追踪系统（Tracing）。

Logging，Metrics 和 Tracing 有各自专注的部分。

- Logging - 用于记录离散的事件。例如，应用程序的调试信息或错误信息。它是我们诊断问题的依据。
- Metrics - 用于记录可聚合的数据。例如，队列的当前深度可被定义为一个度量值，在元素入队或出队时被更新；HTTP 请求个数可被定义为一个计数器，新请求到来时进行累加。
- Tracing - 用于记录请求范围内的信息。例如，一次远程方法调用的执行过程和耗时。它是我们排查系统性能问题的利器。
```

> 在 opentracing 的数据模型中, Trace（调用链）通过归属于此调用链的 Span 来隐性的定义。一条 Trace（调用链）可以被认为是一个由多个 Span 组成的有向无环图（DAG图），Span 与 Span 的关系被命名为 References。

> 分布式追踪系统发展很快，种类繁多，但核心步骤一般有三个：代码埋点，数据存储、查询展示。

```
单个 Trace 中，span 间的因果关系


        [Span A]  ←←←(the root span)
            |
     +------+------+
     |             |
 [Span B]      [Span C] ←←←(Span C 是 Span A 的孩子节点, ChildOf)
     |             |
 [Span D]      +---+-------+
               |           |
           [Span E]    [Span F] >>> [Span G] >>> [Span H]
                                       ↑
                                       ↑
                                       ↑
                         (Span G 在 Span F 后被调用, FollowsFrom)
```

我简单地理解就是, 一次调用就会产生一条 trace, 并且本次调用既是一个 (root) span, 在这次调用中产生的其他调用会创建对应 span 并作关联.

例如: 客户端调用 A 系统的 A1 接口, A1 接口需要调用 B 系统的 B2 接口来获取数据, 那么就会产生一个 trace, 其中有三个 span. (此处存疑)

每个 span 中包含这些数据:
- operation name    操作名称
- start timestamp   起始时间
- finish timestamp  结束时间
- span tags         span 标签
- span log          span 日志
- spanContext       span 上下文
- reference         span 间关系

其中 spanContext 包含这些内容: 
- 任何一个 OpenTracing 的实现，都需要将当前调用链的状态（例如：trace 和 span 的 id），依赖一个独特的 Span 去跨进程边界传输
- Baggage Items，Trace 的随行数据，是一个键值对集合，它存在于 trace 中，也需要跨进程边界传输

大部分似懂非懂, 干脆上手吧.

首先先本地部署一下 jaeger, 直接用 docker 即可, docker-compose 增加配置:

```yaml
services:
    jaegertracing:
        image: jaegertracing/all-in-one
        ports:
            - 5775:5775/udp
            - 5778:5778
            - 14250:14250
            - 14268:14268
            - 6831:6831/udp
            - 6832:6832/udp
            - 16686:16686
```

`jaegertracing/all-in-one` 这个镜像提供了数据存储和 UI, 那么就是来搞定代码埋点. 需要埋点的是一个 laravel 项目, 项目中用到的 http client 是 guzzle.

首先修改 `composer.json`, 增加依赖 `jukylin/jaeger-php`

```json
{
    "minimum-stability": "dev",
    "prefer-stable": true,
    "require": {
        "jukylin/jaeger-php": "dev-master"
    }
}
```

因为 span 中需要记录起止时间, 并且希望尽可能地记录到所有的调用 (主要是避免在框架 bootstrap 过程中发生异常时还没初始化好 jaeger trace), 所以处理的方式有两种:

- 直接在 `bootstrap/app.php` 中在创建好服务容器实例之后创建 jaeger trace 并注册到容器中
- 以服务提供者 (ServiceProvider) 的形式来创建并注册到容器中

为了不折腾, 就直接写成服务提供者吧. 一定要写在 `register()` 方法中, 在里面需要做一些事:

- 创建一个 Jaeger Trace 实例
- 创建一个全局 span, 代表本次调用
- fpm 模式下使用 route.name 作为 span operation name, 匹配不到路由的则用 request.path_info. cli 模式下用 command.name
- 在框架 terminating 时, 调用 trace.flush(), 并且需要注册 register_shutdown_hander() 来实现异常退出时正常提交
- 在消息队列的 worker 中使用了信号监听来实现平滑退出和超时机制, 但会导致 register_shutdown_hander() 注册的 callback 失效, 所以需要每次消费一条消息就 flush 一次
- 注册一个经过改写的 guzzle client 到容器, 后续在项目中通过服务容器来获取 guzzle client

```php
class JaegerServiceProvider extends ServiceProvider
{
    public function boot()
    {
    }

    /**
     * laravel 在 bootstrap 中, 会先注册所有的 provider, 再调用所有 provider 的 boot
     * 而在 provider 中, laravel 有 Event / Log / Routing 三个内置的 base provider
     * 在接入 jaeger 的逻辑中, 除了初始化 trace 和创建全局 span 以外, span 和 trace 的提交都是通过事件监听完成
     * 因此为了获取更加接近于请求实际的跟踪信息 (主要是请求时间) 以及避免其他无法预料的错误
     * 需要将 JaegerServiceProvider 在 app.php 中配置为第一个 provider, 并在 register 中进行初始化.
     *
     * @see https://github.com/mauri870/laravel-jaeger-demo/blob/master/app/Providers/AppServiceProvider.php
     */
    public function register()
    {
        $config = Config::getInstance();

        if ($sampler = config('services.jaeger.sampler')) {
            $config->setSampler($this->createSampler($sampler));
        }

        $config->setTransport(new TransportUdp('', 6000));

        $tracer = $config->initTrace(config('app.name'), config('services.jaeger.agent'));

        $tags = [
            'span.kind' => 'server',
            'type' => 'fpm',
        ];
        $operationName = '';

        if (app()->runningInConsole()) {
            $tags['type'] = 'cli';
            $this->registerCommandStartingListener();
        } else {
            $tags['http.url'] = $operationName = request()->getPathInfo();
        }

        $span = $tracer->startSpan($operationName, [
            'child_of' => $tracer->extract(TEXT_MAP, $_SERVER),
            'tags' => $tags,
        ]);
        $tracer->inject($span->spanContext, TEXT_MAP, $_SERVER);

        $this->app->instance('jaeger.config', $config);
        $this->app->instance('jaeger.tracer', $tracer);
        $this->app->instance('jaeger.span', $span);
        $this->app->instance('jaeger.flushed', false);

        $this->registerRequestHandledListener();
        $this->registerMessageLoggedListener();
        $this->registerTerminateHandler();
        $this->registerQueueJobProcessListener();
    }

    /**
     * 消息队列消费记录
     * 由于队列使用了异步信号监听, 会导致 register_shutdown_handler() 失效, 所以选择在执行完一个 job 之后 flush 一次
     */
    protected function registerQueueJobProcessListener()
    {
        $span = null;

        Event::listen(JobProcessing::class, function (JobProcessing $event) use (&$span) {
            $tracer = $this->app->get('jaeger.tracer');
            $spanName = sprintf('job.%s', $event->job->resolveName());
            $span = $tracer->startSpan($spanName, [
                'child_of' => $this->app->get('jaeger.span'),
                'tags' => [
                    'span.kind' => 'server',
                    'type' => 'cli',    // 这里暂时不考虑 sync 的情况
                    'job.name' => $event->job->getName(),
                    'job.id' => $event->job->getJobId(),
                ],
            ]);
            $tracer->inject($span->spanContext, TEXT_MAP, $_SERVER);
        });

        Event::listen(JobProcessed::class, function () use (&$span) {
            $span->finish();
            $span = null;
            $tracer = $this->app->get('jaeger.tracer');
//            $tracer->spanThrifts = [];
            $tracer->flush();
        });

        $failListener = function ($event) use (&$span) {
            $span->setTags([
                'error' => true,
            ]);
            $span->log([
                'exception' => $event->exception->getMessage(),
            ]);
            $span->finish();
            $span = null;
            $tracer = $this->app->get('jaeger.tracer');
            $tracer->spanThrifts = [];
            $tracer->flush();
        };

        Event::listen(JobFailed::class, $failListener);
        Event::listen(JobExceptionOccurred::class, $failListener);
    }

    /**
     * 当处于 cli 模式下运行时, 匹配到 command 之后将 command.name 作为 span name.
     */
    protected function registerCommandStartingListener()
    {
        Event::listen(CommandStarting::class, function (CommandStarting $event) {
            $this->app->get('jaeger.span')->overwriteOperationName($event->command);
            $this->app->get('jaeger.span')->setTags([
                'command.name' => $event->command,
            ]);
        });
    }

    /**
     * 注册请求相关事件, 如果命中路由, 则将路由名作为 spanName.
     */
    protected function registerRequestHandledListener()
    {
        Event::listen(RouteMatched::class, function (RouteMatched $event) {
            $this->app->get('jaeger.span')->overwriteOperationName('/' . ltrim($event->request->route()->uri(), '/'));
        });
        Event::listen(RequestHandled::class, function (RequestHandled $event) {
            $this->app->get('jaeger.span')->setTags([
                'http.status' => $event->response->getStatusCode(),
            ]);
        });
    }

    /**
     * 注册日志记录事件, 通过事件标记 span 失败及记录日志.
     */
    protected function registerMessageLoggedListener()
    {
        Event::listen(MessageLogged::class, function (MessageLogged $event) {
            if ('error' === $event->level) {
                $this->app->get('jaeger.span')->setTags(
                    [
                        'error' => true,
                    ]
                );
                $this->app->get('jaeger.span')->log((array) $event);
            }
        });
    }

    /**
     * 注册退出 callback.
     */
    protected function registerTerminateHandler()
    {
        app()->terminating(function () {
            $this->flushJaegerTracer();
            $this->app->instance('jaeger.flushed', true);
        });

        register_shutdown_function(function () {
            if (!$this->app->has('jaeger.flushed') || $this->app->get('jaeger.flushed')) {
                return;
            }

            $this->flushJaegerTracer();
        });
    }

    /**
     * @param $sampler
     *
     * @return ProbabilisticSampler
     */
    protected function createSampler($sampler)
    {
        switch ($sampler) {
            case 'probabilistic':
                return new ProbabilisticSampler();
        }
    }

    protected function flushJaegerTracer()
    {
        $this->app->get('jaeger.span')->finish();
        $this->app->get('jaeger.config')->flush();
    }
}
```

然后就是改写 guzzle client 了. 需要在通过 guzzle client 每次调用接口时, 创建一个 span, 并将 `traceId` 传递出去. 直接上代码:

```php

namespace App\Bus\Jaeger;

use Jaeger\Span;
use GuzzleHttp\Client;
use OpenTracing\Reference;
use GuzzleHttp\RequestOptions;
use GuzzleHttp\Psr7\UriResolver;
use function GuzzleHttp\Psr7\uri_for;
use const OpenTracing\Formats\TEXT_MAP;
use Psr\Http\Message\ResponseInterface;
use GuzzleHttp\Exception\RequestException;

class GuzzleClient extends Client
{
    /**
     * @param string $method
     * @param string $uri
     * @param array  $options
     *
     * @return mixed|ResponseInterface
     */
    public function request($method, $uri = '', array $options = [])
    {
        $tracer = app()->get('jaeger.tracer');

        $spanName = $this->generateJaegerSpanName($uri, $options);

        $span = $tracer->startSpan($spanName, [
            'references' => [
                Reference::create(Reference::CHILD_OF, $tracer->extract(TEXT_MAP, $_SERVER)),
            ],
            'tags' => [
                'http.method' => $method,
                'http.url' => $spanName,
                'span.kind' => 'client',
            ],
        ]);

        $traceHeaders = [];
        $tracer->inject($span->spanContext, TEXT_MAP, $traceHeaders);

        $options[RequestOptions::HEADERS] = array_merge($options[RequestOptions::HEADERS] ?? [], $traceHeaders);
        $options[RequestOptions::SYNCHRONOUS] = true;

        return $this
            ->requestAsync($method, $uri, $options)
            ->then(
                function (ResponseInterface $response) use ($span) {
                    $this->finishSpanOnFulfilled($response, $span);

                    return $response;
                },
                function (RequestException $exception) use ($span, $options) {
                    $this->finishSpanOnFailed($exception, $span, $options);

                    throw $exception;
                }
            )
            ->wait();
    }

    private function finishSpanOnFulfilled(ResponseInterface $response, Span $span)
    {
        $span->setTags([
            'http.status_code' => $response->getStatusCode(),
        ]);
        $span->finish();
    }

    private function finishSpanOnFailed(RequestException $exception, Span $span, array $options)
    {
        $span->setTags([
            'error' => true,
            'http.status_code' => $exception->getCode(),
        ]);

        unset($options[RequestOptions::SYNCHRONOUS]);

        $span->log([
            'exception' => $exception->getMessage(),
            'request_options' => json_encode($options),
        ]);
        $span->finish();
    }

    /**
     * 将调用 api 的 host + path 作为 span name.
     *
     * @param $uri
     * @param array $options
     *
     * @return string
     */
    private function generateJaegerSpanName($uri, array $options)
    {
        $options = array_merge(
            [
                'base_uri' => $this->getConfig('base_uri'),
            ],
            $options
        );

        $uri = uri_for(null === $uri ? '' : $uri);

        if (!empty($options['base_uri'])) {
            $uri = UriResolver::resolve(uri_for($options['base_uri']), $uri);
        }

        return $uri->getHost() . $uri->getPath();
    }
}
```

搞定啦.


## 参考
- [开放分布式追踪（OpenTracing）入门与 Jaeger 实现](https://yq.aliyun.com/articles/514488?utm_content=m_43363)
- [opentracing 中文文档](https://wu-sheng.gitbooks.io/opentracing-io/content/)
- [jukylin/jaeger-php](https://github.com/jukylin/jaeger-php)
- [laravel-jaeger-demo](https://github.com/mauri870/laravel-jaeger-demo)
