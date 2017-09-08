---
layout: post
title: Grafana 面板配置
category: 技术
tags: DevOps
description: Grafana 面板配置, 基于模板变量 + Influxdb 正则
---

Grafana 屌炸天的模板变量, 搭配 Influxdb 对正则强大的支持, 可以做出实现资源编排又很酷炫的监控面板.

*效果图*
![Alt text](/assets/img/2017-09-08/2017-09-08-14-55-115.29.5.144-3000.png)

要做到这种效果, 需要了解两个东西:
1. Grafana 面板的建立跟配置, 以及导入模板. 模板变量的创建跟使用.
2. Influxdb 的查询语言


### Influxdb 的查询语言

就是一个类 SQL 语言, 官方文档的介绍是:

> InfluxQL is an SQL-like query language for interacting with data in InfluxDB.

与经常用的 MySQL 的查询语言, 我总结的差异是:
* CRUD 中 Influxdb 只有 C R D
* Influxdb 对正则表达式的支持. 例如 `SELECT "value" FROM /kong_sms_request_status_*/`
* tag 跟 field 都可以用于 where 查询
* Influxdb 有更丰富的聚合查询

例如, kong 里面, 每个 API 的状态码分布, 最终会生成好几个 measurement, 规则是 `kong_{api_name}_request_status_{status_code}`, 例如:

```
kong_sms_request_status_200
kong_sms_request_status_422
kong_sms_request_status_502
```

如果要创建一个可以看状态码分布的面板就很痛苦, 因为总是得去增加一条 query 来查新出现的状态码. 那怎么办呢?

借助 Influxdb 对正则的支持, 我们可以用一条语句解决:
```
SELECT mean("value") FROM /kong_sms_request_status_*/ WHERE time > now() - 10m GROUP BY time(10s) fill(0)
```

查询结果
```
name: kong_sms_request_status_200
time                mean
----                ----
1504855780000000000 0
1504855790000000000 3
1504855800000000000 0
1504855810000000000 2

name: kong_sms_request_status_429
time                mean
----                ----
1504855780000000000 0
1504855790000000000 0
1504855800000000000 0
1504855810000000000 0

name: kong_sms_request_status_502
time                mean
----                ----
1504855780000000000 0
1504855790000000000 0
1504855800000000000 0
1504855810000000000 2
```

### Grafana 模板变量
在另外一篇文档里面讲过配置 Influxdb 数据源的监控面板. 可以通过 UI 中轻松选择 metric 来展示. 例如我们配置了查看内存可用率的一个面板组件, 会自动生成一条 SQL 语句
```
SELECT mean("available_percent") FROM "mem" WHERE $timeFilter GROUP BY time($__interval) fill(0)
```

这条语句最终生成的语句是
```
SELECT mean("available_percent") FROM "mem" WHERE time > now() - 6h GROUP BY time(10s) fill(null)
```

可见, 在原始的语句中, 两个变量最终的值是:
```
$__interval  =>   10s
$timeFilter  => time > now() - 6h
```

那当我们几台机器都怼到一个数据库的时候, `mem` 这个 measurement 就会有一个 tag, 值是每个 telegraf 配置的 hostname.

也就是, 如果我们要查 A 机器的内存可用率, 可以用这条语句来做
```
SELECT mean("available_percent") FROM "mem" WHERE "host" = 'A' AND time > now() - 6h GROUP BY time(10s) fill(null)
```

同理, B 机器可以用
```
SELECT mean("available_percent") FROM "mem" WHERE "host" = 'B' AND time > now() - 6h GROUP BY time(10s) fill(null)
```

嗯.. 如果有一百台机器, 那么就要写一百条 query. 当然, 可以使用一个 `group by` 来做, 只需要一条查询语句, 然后让 Grafana 自动帮我们画出一百条线

```
SELECT mean("available_percent") FROM "mem" WHERE time > now() - 6h GROUP BY time(10s),"host" fill(null)
```

但是... 一百条也太多了吧, 怎么看? 如果我想, 有一个下拉框, 让我选择想看哪条就用哪条呢?

模板变量! 我们需要先查出 `mem` 这个 measurement 的 `host` 这个 tag 全部的值, 然后当做变量, 最后在配置 Panel 的时候使用变量. 先看图示步骤:

*打开模板变量配置*
![](/assets/img/2017-09-08/DeepinScrot-5939.png)

*点击新增变量*
![](/assets/img/2017-09-08/DeepinScrot-0156.png)

*配置参数*
![](/assets/img/2017-09-08/DeepinScrot-0641.png)

*最终效果*
![](/assets/img/2017-09-08/DeepinScrot-1938.png)

最后, 我们可以来 配置 Panel 的 query 了. 注意这条 query 中, `GROUP BY` 我增加了一个 `host`. 当模板变量配置为可以多选时, 可以在一个 Panel 中实现多条线.
```
SELECT mean("available_percent") FROM "mem" WHERE "host" =~ /^$host$/ AND time > now() - 6h GROUP BY time(10s),"host" fill(null)
```

完工!

### Tips
一些建面板的 Tips

接着开坑...
