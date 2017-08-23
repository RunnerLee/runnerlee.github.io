---
layout: post
title: 参考 runscope 的一个 API 监控
category: 技术
tags: PHP
description: API Watcher API 监控系统
---

API Watcher 是一个集成了 API 管理，API 监控及告警的系统。

API Watcher 提供自定义 Faker，并使用 laravel 提供的 validation 进行 API 响应数据校验。动态配置监控任务的执行频率，并可以设置时间条件，达到分时间区段不同频率进行 API 监控的功能。

调度器通过 laravel 的任务调度实现, 而微信机器人则使用 [vbot](https://github.com/HanSon/vbot), 后台用的是 [encore/laravel-admin](https://github.com/z-song/laravel-admin).


## vbot 中使用 eloquent

因为 vbot 也是使用 `illuminate/container` 作为容器, 而 `Illuminate\Container\Container` 是单例模式, 因此无法直接将 vbot 注册到 laravel 的容器中.

在 vbot 中, 我需要自定义一个消息处理器, 在消息处理器中查询数据库, 能直接使用 Eloquent 最好啦.

要使用 Eloquent Model, 只需要往 Model 中传入一个 `\Illuminate\Database\ConnectionResolverInterface` 实例. 传入这个 `connection`, 用于 `Builder` 最终的执行查询语句.

所以， 我们只需要给 Vbot 增加一个服务提供者，在服务提供者里面进行这步操作.

而获取这个实例, 有两种方法.

### 方法一
vbot的配置中， 增加一项数据库配置
```php
[
    'database' => [
        'connections' => [
            'default' => [
                'driver' => 'mysql',
                'host' => env('DB_HOST', '127.0.0.1'),
                'port' => env('DB_PORT', '3306'),
                'database' => env('DB_DATABASE', 'api_watcher'),
                'username' => env('DB_USERNAME', 'root'),
                'password' => env('DB_PASSWORD', ''),
                'unix_socket' => '',
                'charset' => 'utf8',
                'collation' => 'utf8_unicode_ci',
                'prefix' => '',
                'strict' => true,
                'engine' => null,
            ],
        ],
    ],
];
```

```
use Hanson\Vbot\Foundation\ServiceProviderInterface;
use Hanson\Vbot\Foundation\Vbot;
use Illuminate\Database\Capsule\Manager;
use Illuminate\Database\Eloquent\Model;

class DatabaseServiceProvider implements ServiceProviderInterface
{

    public function register(Vbot $vbot)
    {
        Model::setConnectionResolver((new Manager($vbot))->getDatabaseManager());
    }
}

```

### 方法二
直接复制 `Illuminate\Database\DatabaseServiceProvider`

vbot的配置中， 增加一项数据库配置, 跟 laravel 原先的 `config/database.php` 中一致
```php
[
    'database' => [
        'default' => 'mysql',
        'connections' => [
            'mysql' => [
                'driver' => 'mysql',
                'host' => env('DB_HOST', '127.0.0.1'),
                'port' => env('DB_PORT', '3306'),
                'database' => env('DB_DATABASE', 'api_watcher'),
                'username' => env('DB_USERNAME', 'root'),
                'password' => env('DB_PASSWORD', ''),
                'unix_socket' => '',
                'charset' => 'utf8',
                'collation' => 'utf8_unicode_ci',
                'prefix' => '',
                'strict' => true,
                'engine' => null,
            ],
        ],
    ],
];
```

然后
```
use Hanson\Vbot\Foundation\ServiceProviderInterface;
use Hanson\Vbot\Foundation\Vbot;
use Illuminate\Database\Connectors\ConnectionFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\DatabaseManager;

class DatabaseServiceProvider implements ServiceProviderInterface
{
    public function register(Vbot $vbot)
    {
        Model::setConnectionResolver(new DatabaseManager($vbot, new ConnectionFactory($vbot)));
    }
}
```

然后就 OK 啦。 那为什么两种方法的配置不一样呢？
因为最终都是拿 `database.default` 作为默认的连接的，在 `Illuminate\Database\DatabaseManager` 中负责创建读取配置并创建连接. 而在它里面，并不会给 `database.default` 配置默认值.

但是在 `Illuminate\Database\Capsule\Manager` 中，`Manager::setupDefaultConfiguration()` 会给 `database.default` 配置一个默认值 `default`.

所以, 哈哈, 我蛋疼了点. 其实两个都可以配置成一样的.


## 部署 API Watcher

### 安装
```
git clone git@github.com:RunnerLee/api-watcher.git

composer install

php artisan migrate

php artisan admin:install

php artisan db:seed
```

### 配置微信群名及微信机器人 web server
*.env*
```
VBOT_NOTICE_USER=大丑逼
VBOT_SERVER_IP=127.0.0.1
VBOT_SERVER_PORT=9001
```

### 配置 API 分组
![](http://oupjptv0d.bkt.gdipper.com//image/github/api-watcher/DeepinScrot-4918.png)

### 增加 API
![](http://oupjptv0d.bkt.gdipper.com//image/github/api-watcher/DeepinScrot-0002.png)

### 为 API 添加请求参数
![](http://oupjptv0d.bkt.gdipper.com//image/github/api-watcher/DeepinScrot-0133.png)

### 为 API 分组增加计划任务
计划任务的条件, 通过 json 配置星期与小时.
```json
{
  "week": [],       // 周一到周日
  "hour": {
    "between": {    // 执行的时间范围
      "from": "",
      "to": ""
    },
    "unless_between": {     // 不执行的时间范围
      "from": "",
      "to": ""
    }
  }
}
```
![](http://oupjptv0d.bkt.gdipper.com//image/github/api-watcher/DeepinScrot-0435.png)

### 启动微信机器人
```
php vbot
```
以守护进程运行机器人, 需要手动拿到二维码链接然后扫码登录
```
nohup php vbot > /dev/null 2>&1 &
cat storage/vbot/url.txt
```
拿到链接 `https://login.weixin.qq.com/l/4bNWM4e8Uw==`, 替换为 `https://login.weixin.qq.com/qrcode/4bNWM4e8Uw==`


### 安装调度器
```
crontab -e
```
增加
```
* * * * * php /path/to/artisan schedule:run > /dev/null 2>&1 &
```

### 微信通知
![](http://oupjptv0d.bkt.gdipper.com//image/github/api-watcher/TIM%E6%88%AA%E5%9B%BE20170815122216.png)
