---
layout: post
title: 用 guzzle 以 multipart/form-data 提交多维数组
category: 技术
tags: http curl php guzzle multipart
description: 用 guzzle 以 multipart/form-data 提交多维数组
author: RunnerLee
---

用 guzzle 以 multipart/form-data 来提交时, 一般是这么操作的:

```php
<?php
use GuzzleHttp\Client;

$client = new Client();

$parameters = [];

$multipart = [];

foreach ($parameters as $name => $value) {
    $multipart[] = [
        'name' => $name,
        'contents' => $value,
    ];
}

$response = $client->post('http://exmaple.com', [
    'multipart' => $multipart,
]);
```

而当 `$parameters` 是一个多维数组时, 就操蛋了...

```
PHP Fatal error:  Uncaught InvalidArgumentException: Invalid resource type: array in /Users/runner/code/company/sdk/service/vendor/guzzlehttp/psr7/src/functions.php:116
```

那么解决肯定也是很简单啦, 直接贴代码:

```php
<?php

function createMultipart(array $parameters, $prefix = '')
{
    $return = [];
    foreach ($parameters as $name => $value) {
        $item = [
            'name' => empty($prefix) ? $name : "{$prefix}[{$name}]",
        ];
        switch (true) {
            case (is_object($value) && ($value instanceof CURLFile)):
                $item['contents'] = fopen($value->getFilename(), 'r');
                $item['filename'] = $value->getPostFilename();
                $item['headers'] = [
                    'content-type' => $value->getMimeType(),
                ];
                break;
            case (is_string($value) && is_file($value)):
                $item['contents'] = fopen($value, 'r');
                break;
            case is_array($value):
                $return = array_merge($return, createMultipart($value, $item['name']));
                continue 2;
            default:
                $item['contents'] = $value;
        }
        $return[] = $item;
    }

    return $return;
}
```

#### 参考
- [https://github.com/guzzle/guzzle/issues/1177#issuecomment-130006560](https://github.com/guzzle/guzzle/issues/1177#issuecomment-130006560)
- [https://guzzle-cn.readthedocs.io/zh_CN/latest/request-options.html#multipart](https://guzzle-cn.readthedocs.io/zh_CN/latest/request-options.html#multipart)

