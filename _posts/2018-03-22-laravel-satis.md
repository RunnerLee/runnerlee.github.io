---
layout: post
title: 用 laravel 和 satis 搭建 packagist 私有源
category: 技术
tags: laravel satis packagist composer
description: 用 laravel 和 satis 搭建 packagist 私有源
author: RunnerLee
---

公司搭建了自己的 GitLab, 但是如果要在 composer 里依赖到 GitLab 上的私有仓库, 就要把用到私有仓库的地址全部放到 `composer.json` 里, 很麻烦.

composer 官方提供了 satis, 但是仅提供了生成功能, 不带自动更新, 很尴尬. 但只要搭建一个 webhook 用来接收 GitLab 的推送, 就可以解决.

## 安装使用 satis

首先了解 satis 的[安装使用文档](https://getcomposer.org/doc/articles/handling-private-packages-with-satis.md).

```
composer create-project composer/satis ./satis
```

在 satis 目录中创建一个 `satis.json` 文件

```
{
    "name": "packagist name",
    "homepage": "http://custom.packagist.domain",
    "repositories": [
        {
            "type": "git",
            "url": "git@gitlab.custom.com:group/project.git"
        }
    ],
    "require": {
        "group/project": "*"
    }
}
```

> homepage 注意需要 https. 否则需要修改 composer 配置, [参考](https://getcomposer.org/doc/06-config.md#secure-http).

然后执行生成

```
php bin/satis build satis.json ./publish
```

代码库就生成到了 `publish` 目录, 将他作为 `http://custom.packagist.domain` (既 `homepage`) 的站点根目录即可.

项目中的 `composer.json` 文件增加配置

```
{
    "repositories": [
        {
            "type": "composer",
            "url": "http://custom.packagist.domain"
        }
    ]
}
```

而当 `satis.json` 中增加仓库的时候, 直接再执行 `php bin/satis build satis.json ./publish` 会再次全量生成, satis 也支持生成指定的包.

```
php bin/satis build satis.json ./publish group/project
```

## 思路

维护一个仓库列表, 使用这个仓库列表来生成 `satis.json`. 当新增包时, 再次生成 `satis.json`. 用这个配置文件来生成库. 当包有更新时, 指定更新这个包.

但有一个限制, 就是指定更新某个包只能使用包名, 而不能使用仓库地址. 而从 gitlab 向我们的 webhook 中我们 post 过来的数据中, 没办法拿到包名, 只能拿到仓库地址. (废话==)

那只能自己实现用仓库地址获取到包名了.

过程不表, 当你在 `composer.json` 中添加一个 `git` 类型的 `repository` 时, composer 是通过 `Composer\Repository\VcsRepository` 这个类来获取包名的.

直接上代码:

```php
<?php

use Composer\Factory;
use Composer\IO\ConsoleIO;
use Symfony\Component\Console\Input\ArgvInput;
use Symfony\Component\Console\Output\ConsoleOutput;
use Symfony\Component\Console\Helper\HelperSet;
use Composer\Repository\VcsRepository;

$consoleIo = new Composer\IO\ConsoleIO(
    new ArgvInput,
    new ConsoleOutput,
    new HelperSet
);

$repository = new VcsRepository(
    [
        'type' => 'git',
        'url' => 'git@gitlab.custom.com:group/project.git',
    ],
    $consoleIo,
    Factory::createConfig($io)
);

$composerInfo = $repository->getDriver()->getComposerInformation($repository->getDriver()->getRootIdentifier());

print_r($composerInfo); //  composer.json 内容

$packageName = $composerInfo['name'];

```

如果不考虑 repository 的类型的话, 甚至可以直接使用 `Composer\Repository\Vcs\GitDriver` 来获取.

获取到包名, 就可以用来执行 satis 啦.

## 结合 laravel

未完待续..

