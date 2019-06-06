---
layout: post
title: 使用 xdebug profiler + qcachegrind 做性能分析
date: 2019-06-06
update_date: 2019-06-06
summary: PHP 性能分析
logo: spinner
---

首先安装 xdebug, 无论是 OSX 上直接跑 fpm, 还是用虚拟机或 docker 都可以, 安装后, 配置 xdebug

```ini
[xdebug]
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_handler=dbgp
xdebug.remote_mode=req
xdebug.remote_connect_back=0
xdebug.remote_host=0.0.0.0
xdebug.remote_port=9001
xdebug.idekey=PHPSTORM
xdebug.remote_autostart=0
xdebug.profiler_enable=0
xdebug.profiler_enable_trigger=1
xdebug.profiler_enable_trigger_value=1111111
xdebug.profiler_output_dir=/path/to/profiling/folder
```

> 其中 `remote_host` 在 mac 版的 docker 中, 需要配置为 `host.docker.internal` 才能在容器中访问到宿主机上的 PHPSTORM 进行断点调试.

其中关于性能报告的几项配置:

* `profiler_enable` 为 0 关闭自动生成性能报告
* `profiler_enable_trigger` 为 1 开启触发生成性能报告
* `profiler_enable_trigger_value` 触发性能报告的 "密钥"
* `profiler_output_dir` 性能报告文件目录

为了不过多影响本地调试, 关闭自动生成性能报告, 改由触发生成. 触发方式为在 GET / POST / COOKIE 变量中传一个 `XDEBUG_PROFILE=${TRIGGER_VALUE}`.

#### 触发性能分析

如果用 chrome 的话, 则可以安装 [Xdebug Helper](https://chrome.google.com/webstore/detail/xdebug-helper/eadndfjplgieldjbigjakmdgkmoaaaoc). 配置 `trigger_value`.

![](/assets/img/2019-06-06/chrome_xdebug_helper.png)

如果是用 postman 或是 insomnia, 则可以在 queryString 或是 requestBody, 甚至是 cookie 中传递.

#### 查看分析报告

在 mac 上使用的工具是 `qcachegrind`. 安装方式:

```shell
$ brew install graphviz
$ brew install qcachegrind
```

其中可能是我使用的系统版本比较新, 只有通过终端启动 qcachegrind 才能正常查看调用图.

根据 fpm 跑在宿主机还是虚拟机, xdebug 生成的性能报告中文件目录就会不一样. 首先是 fpm 跑在宿主机的情况.

命令行打开执行 

```shell
$ cd /path/to/profiling/folder
$ qcachegrind
```

然后打开已经生成的报告文件

![](/assets/img/2019-06-06/1.png)

然后就可以了. 其中主要看调用次数, 时间消耗 (目前好像没有 xhprof 有的内存使用报告), 这里摘抄一下 xhprof 的几项关键信息, 同样适用于 xdebug.

```
funciton name ： 函数名
calls: 调用次数
Incl. Wall Time (microsec)： 函数运行时间（包括子函数）
IWall%：函数运行时间（包括子函数）占比
Excl. Wall Time (microsec)：函数运行时间（不包括子函数）
EWall%：函数运行时间（不包括子函数）
```

我用 laravel 跑了一个简单的例子, 看这个图左边圈中部分, 有两项自身运行时间都超过 30% (Excl. Wall Time / Self). 右上圈中的是源文件中具体某一行的运行时间. 右下圈中的是执行次数.

![](/assets/img/2019-06-06/2.png)

个人习惯是打开性能报告后, 按照以下步骤定位性能问题:

- 按照运行时间排序, 如果可以从 `Self` 直接定位到具体问题就最好.
- 如果 `Self` 的时间不明显, 可以先看 controller 的运行时间, 如果占的百分比较大, 就可以通过 `Source Code` 中看其中每一行的运行时间
- 如果 controller 的运行时间占比较小, 则定位框架的启动过程及关闭过程中

如果是 php5.6 的项目, 还可以借助 xhprof 来查看内存使用情况.

如果 fpm 是跑在容器或是虚拟机中, 且站点目录跟宿主机不一致的话, 生成的报告就无法直接查看 `Source Code`, 那么可以配置目录映射 (用 phpstorm 的话肯定熟悉这个).

![](/assets/img/2019-06-06/3.png)

关于 qcachegrind 的安装和使用, 也可以参考下面的博文.

#### 参考

- [PHP:使用xdebug profiler 做性能分析](https://zhuanlan.zhihu.com/p/26615449)
- [https://langui.sh/2011/06/16/how-to-install-qcachegrind-kcachegrind-on-mac-osx-snow-leopard/](https://langui.sh/2011/06/16/how-to-install-qcachegrind-kcachegrind-on-mac-osx-snow-leopard/)
