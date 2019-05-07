---
layout: post
title: Docker 搭建 PHP 开发环境
date: 2019-05-07
update_date: 2019-05-07
summary: Docker 使用
logo: bicycle
---

最近日子过得有点茫茫然, 整理了一批学习清单但一时间不知道从哪个开始好, 先整理下之前的东西平复下心态吧.

一直在用 homestead + vagrant 做 php 的开发环境, 因为这阵子要处理一个 php5.6 的项目, brew 的 php 源又有问题, 所以干脆换成 docker 吧.

鉴于 Docker For Mac 是运行在 Hypervisor 上的一个 HyperKit 实现, 在挂载主机目录时的 IO 性能非常差, 解决方案也挺多, 我选择了最简单的一种: Docker CE Edge.

整理了一下用虚拟机(或是容器)对于开发环境的需求:
* nginx / mysql / redis / es ...
* 多个 PHP 版本共存
* 每个服务的配置文件使用挂载主机目录的方式

用 vagrant 的方案就不用讲, 整理下用 docker 的方案:
- 使用 docker compose 编排镜像
- 使用 docker 容器跑 php-fpm, 自行制作 php 镜像以安装需要的扩展, 基于 php:fpm-alpine
- nginx / redis / mysql 等直接使用官方镜像, 并给每个服务创建独立的数据卷
- nginx 映射 80 端口及 9601-9610 端口到主机端口 (个人开发习惯)    
- 宿主机依旧需要安装 php7.2 及 php7.2-fpm
- 各个服务使用的配置文件通过挂载主机目录(文件)的方式来管理, 通过 docker-compose 来配置挂载
- 将 nginx 和 php 的错误日志挂载到主机

> 虽然用了 Docker CE Edge, 但 IO 性能依旧远不及原生或是 virtualbox, 所以除了临时使用的 php5.6, 我决定还是让 php7.2-fpm 跑在宿主机.

开始搭建, 参考 Laradock, 创建一个 docker-compose 的项目目录, 目录骨架设定为:
```
|-- services/
|   |-- php56/
|   |   |-- conf.d/
|   |   |   |-- docker-php-ext-xdebug.ini
|   |   |-- Dockerfile
|   |   |-- php.ini
|   |-- nginx/
|   |   |-- sites/
|   |   |   |-- localhost.conf
|   |   |   |-- testing.conf
|   |   |-- nginx.conf
|   |-- redis/
|   |   |-- redis.conf
|   |-- mysql/
|   |   |-- my.cnf
|-- logs/
|   |-- nginx\
|   |-- php\
|-- docker-compose.yml
```

#### 1. 制作 PHP-FPM 镜像

```Dockerfile
FROM php:5.6-fpm-alpine

LABEL maintainer="RunnerLee <runnerleer@gmail.com>"

# 安装依赖及部分扩展
RUN set -xe \
    && apk add --no-cache --update --virtual .phpize-deps $PHPIZE_DEPS \
    && docker-php-ext-install bcmath pdo pdo_mysql mysql mysqli pcntl

# 安装 redis 扩展
RUN pecl install -o -f redis \
    && docker-php-ext-enable redis

# 安装 xdebug
RUN pecl install xdebug-2.5.5 \
    && docker-php-ext-enable xdebug

# ... 安装其他乱七八糟的扩展

# 清理
RUN rm -rf /usr/local/src/* \
    && rm -rf /tmp/pear/download/* \
    && rm -rf /tmp/pear/cache/*

EXPOSE 9000
```

配置 XDEBUG 

*docker-php-ext-xdebug.ini*
```ini
[xdebug]
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_handler=dbgp
xdebug.remote_mode=req
xdebug.remote_connect_back=0
xdebug.remote_host=host.docker.internal     # 因为 mac 里没有 docker0, 所以只能通过这种方式访问宿主机
xdebug.remote_port=9001
xdebug.idekey=PHPSTORM
xdebug.remote_autostart=0
xdebug.profiler_enable=0
xdebug.profiler_enable_trigger=1
xdebug.profiler_enable_trigger_value=runnerlee
xdebug.profiler_output_dir=/var/www/profiling/xdebug
```

#### 2. 配置 nginx.conf
```conf
user  nginx;
worker_processes  4;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                    '$upstream_response_time '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    sendfile        on;
    keepalive_timeout  65;
    include /etc/nginx/sites/*; # 然后通过 docker-compose 把宿主机里面的站点配置挂载到 /etc/nginx/sites/ 里去
}
```

对于 php5.6 的项目, nginx 站点配置可以这么配置:
```
fastcgi_pass php56:9000;    # php56 就是在 docker-compose 中创建的 services 名
```

而对于 php7.2 的项目, 由于 fpm 是跑在宿主机上的, 所以这么配置:
```
fastcgi_pass host.docker.internal:9000;
fastcgi_param  SCRIPT_FILENAME  /path/to/your/website$fastcgi_script_name;
```

例如这是我的 `localhost.conf` 配置:
```
server {
    listen 80;
    server_name _;
    root /home/www-data;
    autoindex on;
    location ~ \.php {
        fastcgi_pass host.docker.internal:9072;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param SCRIPT_FILENAME /Users/runner/Code$fastcgi_script_name;
    }
}
```

#### 3. 配置 mysql 和 redis

这个因人而异, 我暂时不需要修改, 所以不贴出来.

#### 4. 最终, 创建 docker-compose.yml
```
version: '3'
services:
    nginx:
        image: nginx:alpine
        ports:
            - "80:80"
            - "9601-9610:9601-9610" # 端口范围映射
        environment:
            TZ: Asia/Shanghai
        volumes:
            - www-data:/home/www-data:cached    # 挂载主机里的工作目录
            - "./services/nginx/nginx.conf:/etc/nginx/nginx.conf" # 挂载 nginx.conf
            - "./services/nginx/sites/:/etc/nginx/sites"    # 挂载 nginx 站点配置
            - nginx-log-data:/var/log/nginx:delegated   # 挂载 nginx 日志目录
    php56:
      # build: ./services/php56/
        image: runnerlee/php:5.6-fpm # 因为我创建的镜像已经提交到 dockerHub, 所以可以直接使用镜像而不用构建
        volumes:
            - www-data:/home/www-data:cached
            - "./services/php5.6/conf.d/docker-php-ext-xdebug.ini:/usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini"
            - "./services/php5.6/php.ini:/usr/local/etc/php/php.ini"
            - php56-profiling-data:/var/www/profiling:delegated
        environment:
            TZ: Asia/Shanghai
    redis:
        image: redis
        ports:
            - "6379:6379"
        volumes:
            - redis-data:/data
        environment:
            TZ: Asia/Shanghai
    mysql:
        image: mysql:5.7
        ports:
            - "3306:3306"
        environment:
            MYSQL_ALLOW_EMPTY_PASSWORD: "yes"   # 允许空密码
            MYSQL_ROOT_HOST: "%"    # 允许任意 host 登录
            MYSQL_ROOT_PASSWORD: "" # 密码设置为空
            TZ: Asia/Shanghai
volumes:
    mysql-data:
    redis-data:
    www-data:
        driver: local
        driver_opts:
            type: none
            o: bind
            device: /path/to/your/workpath
    nginx-log-data:
        driver: local
        driver_opts:
            type: none
            o: bind
            device: /path/to/runnerdock/logs/nginx/
    php56-profiling-data:
        driver: local
        driver_opts:
            type: none
            o: bind
            device: /path/to/runnerdocker/logs/php/5.6/ # 这是放 xdebug 生成的性能报告文件的地方
```

#### 5. 启动

进入 docker-compose 项目目录, 执行 
```
docker-compose up -d # 也可以指定启动某些服务
```

然后访问 `http://localhost` 即可.

就这样搭建好了开发环境. 结合 docker-compose 的环境变量配置, 我把我的开发环境放到了 GitHub:

https://github.com/RunnerLee/runnerdock

### 参考
- [Docker Compose](https://docs.docker.com/compose/overview/)
- [http://blog.cjli.info/2018/01/06/Docker-Volumes-IO-Slow-On-macOS/](http://blog.cjli.info/2018/01/06/Docker-Volumes-IO-Slow-On-macOS/)
- [Docker - 从入门到实践](https://yeasy.gitbooks.io/docker_practice/image/dockerfile/references.html)

