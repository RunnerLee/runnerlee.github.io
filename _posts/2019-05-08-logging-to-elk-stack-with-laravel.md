---
layout: post
title: laravel项目使用ELK做日志采集系统
date: 2019-05-08
update_date: 2019-05-08
summary: ELK简单应用
logo: connectdevelop
---

应一个朋友要求重新玩一下搭建 ELK 做日志采集分析, 并结合 laravel 使用的例子.

一个应用 LNMP 架构的 laravel 项目, 会产生并且需要采集的日志数据有:
- nginx access log 及 error log
- laravel 产生的应用 (错误) 日志
- php-fpm 的 slowlog 和 php error log
- mysql 慢查询日志
- ...

要做的是把这些日志按照类别提交到 elasticsearch 中. 在提交方式的选择上, elasticsearch 本身提供了 RESTful API, 通过官方提供的 sdk 可以很方便地在 PHP 中提交应用日志.

而其他类别的日志, 则可以通过 logstash 和 filebeat 进行采集提交. 但为了容错, 统一地将所有的日志写入到文件, 再使用 agent 进行采集.

所以简单整理一下方案:
- 所有日志写入到本地文件,再有 agent (filebeat / logstash) 进行采集
- 不同类别的日志提交到 es 时使用不同的索引. 索引使用时间范围 (time-based) 索引
- 所有日志使用 filebeat 采集, 但也实现配置 logstash 采集 fpm 慢日志及 json 格式的 nginx access log
- 考虑增加 redis 或 kafka 作为缓冲层接收 filebeat / logstash 提交的数据, 并创建一个新的 logstash 从缓存层读取数据提交至 es
- 使用 docker 部署

要实现的目标是:
- 采集日志, 统一管理分析
- 使用日志实现简单的系统监控及告警
- 监控面板查看应用运行情况

使用 filebeat 的目的是 logstash 比较迟资源, 而 filebeat 更轻量且内置了比较齐全的 input 模块. 但也有一个问题, filebeat 只支持在 output.elasticsearch 处设置索引名, 一个 filebeat 实例采集的 log 将提交到同一个索引下, 并根据 input 模块给文档不同的类型 (默认会使用 `doc` 作为类型) 并放入不同的子集中.

一个大概的效果就是:
```json
{
    "nginx": {
        "access": {
            "remote_ip": "127.0.0.1"
        }
    }
}

{
    "mysql": {
        "slow": {
            "schema": "testing_db"
        }
    }
}
```

摘抄一下官网文档 [类型和映射](https://www.elastic.co/guide/cn/elasticsearch/guide/current/mapping.html#_%E7%B1%BB%E5%9E%8B%E7%BB%93%E8%AE%BA):
```
类型不适合 完全不同类型的数据 。如果两个类型的字段集是互不相同的，这就意味着索引中将有一半的数据是空的（字段将是 稀疏的 ），最终将导致性能问题。在这种情况下，最好是使用两个单独的索引。
```

正常情况下 nginx 的 access log 的数量会比其他几个日志多出很多, 但由于一个 filebeat 实例只能配置使用一个索引名称, 所以就划分为前者独立一个实例采集, 其他日志起另外一个实例采集.

一些版本的选择:
- laravel: 5.8
- ELK: 6.7.0
- nginx: lastest
- mysql: 5.7
- php: 7.2

先准备好应用及搭建好运行环境, 配置好日志格式, 然后搭建 ELK. 动手吧 ~

#### 1. 创建 laravel 应用

创建一个 laravel 5.8 的项目, 并修改 logging 配置

```php
# config/logging.php
return [
    'channels' => [
        'daily' => [
            'driver' => 'daily',
            'path' => storage_path('logs/laravel.log'),
            'formatter' => \Monolog\Formatter\LogstashFormatter::class,
            'level' => 'debug',
            'days' => 14,
        ],
    ],
];
```

然后通过依赖容器给 `LogstashFormatter::__constrcut()` 注入 `applicationName`:

```php
# app/Providers/AppServiceProvider.php

public function register()
{
    $this->app->when(LogstashFormatter::class)->needs('$applicationName')->give(function () {
        return config('app.name');
    });
}
```

#### 2. 配置 nginx
```
server {
    access_log /data/logs/nginx/laravel.access.log; # 这里暂不自定义日志格式, 使用默认的日志格式
    error_log /data/logs/nginx/laravel.error.log;
}
```

#### 3. 开启 mysql 慢查询日志
```
long_query_time=2
slow_query_log=On
slow_query_log_file="/var/log/mysql/mysql_slow_query.log"  
log_queries_not_using-indexes=On
```

#### 4. 开启PHP FPM slow log

#### 5. 开启 PHP error log

#### 6. 配置 filebeat


因为其他屁事没写完.. 先随便上传上来了, 什么时候再补齐一下了.



#参考
- https://blog.csdn.net/weixin_39471249/article/details/80732661
- https://www.elastic.co/guide/cn/elasticsearch/guide/current/mapping.html
