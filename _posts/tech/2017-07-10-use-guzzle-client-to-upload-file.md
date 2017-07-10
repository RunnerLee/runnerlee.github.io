---
layout: post
title: 使用 Guzzle 上传文件
category: 技术
tags: PHP
description: 使用 Guzzle 上传文件
---

上传文件, 只能通过 multipart/form-data 的表单上传.

简单的上传文件的例子:
```php
use GuzzleHttp\Client;

$client = new Client;

$client->request('POST', 'http://foo.com/upload_file', [
    [
        'name' => 'image',
        'contents' => fopen('/home/runner/demo.png', 'r'),
        'filename' => 'avatar.png',
    ],
]);

```

这样上传, 就完成了整个上传.

本文结束.

哈哈哈哈哈哈哈

如果是由客户端调用上传而来的文件, 要再上传一次到别的地方 (例如云存储), 那应该这么做:

```php
use GuzzleHttp\Client;

$client = new Client;

$client->request('POST', 'http://foo.com/upload_file', [
    [
        'name' => 'image',
        'contents' => fopen($_FILES['image']['tmp_name'], 'r'),
        'filename' => 'avatar.png',
        'headers' => [
            'content-type' => $_FILES['image']['type'],
        ]
    ],
]);
```

在这里, 必须设置 `content-type`, 否则再次上传的文件, 将无法获取到 mime type.

原因看这里:
```php
#class: GuzzleHttp\Psr7\MultipartStream
private function createElement($name, StreamInterface $stream, $filename, array $headers)
{

    ... ...

    // Set a default Content-Type if one was not supplied
    $type = $this->getHeader($headers, 'content-type');
    if (!$type && ($filename === '0' || $filename)) {
        if ($type = mimetype_from_filename($filename)) {
            $headers['Content-Type'] = $type;
        }
    }

    return [$stream, $headers];
}
```

看下 `mimetype_from_filename` 这个辅助函数
```php
function mimetype_from_filename($filename)
{
    return mimetype_from_extension(pathinfo($filename, PATHINFO_EXTENSION));
}

function mimetype_from_extension($extension)
{
    static $mimetypes = [
        ... ...
        'zip' => 'application/zip',
    ];

    $extension = strtolower($extension);

    return isset($mimetypes[$extension])
        ? $mimetypes[$extension]
        : null;
}
```

因此可以看到, 默认的 `mime type` 是从文件扩展名从获取而来的. 而当使用从 `$_FILES` 拿到的文件名中并不包含扩展名.

Thanks.
