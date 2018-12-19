---
layout: post
title: php 内置 webserver 使用注意
date: 2018-12-19
update_date: 2018-12-19
summary: php 技巧
logo: server
---

昨天在一个 Laravel 项目里面有一段逻辑是通过 http 调用项目内部的 API. 

暂时不管这种做法存在的问题, 尴尬的是, 请求一直是超时的. 而将参数复制出来用 Postman 或者 curl 则没问题.

因为我习惯了在 laravel 项目中直接通过 `php artisan serve --port=x` 来开发, 所以以为是 php 内置的 webserver 在 mac 中的问题.

就换了 nginx 先避开问题, 之后搜了一圈也没找到问题所在. 然后...

昨晚睡觉前才想起来... php 内置的 webserver 是单进程单线程的... 看一下 [php.net](http://php.net/manual/en/features.commandline.webserver.php):

```
The web server runs only one single-threaded process, so PHP applications will stall if a request is blocked.
```

当初用 swoole server 把 worker process 数量调成 1 也是类似情况..

😓 猪脑子




