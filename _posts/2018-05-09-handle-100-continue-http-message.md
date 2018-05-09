---
layout: post
title: 处理带有 HTTP 100 Continue 的响应
category: 技术
tags: http curl php
description: 处理带有 HTTP 100 Continue 的响应
author: RunnerLee
---

在一个新项目里面做验证苹果内支付的支付凭证, 用了 [fastd/http](https://github.com/fastdlabs/http), 
结果 `Response` 能拿到正确的 statusCode, 而 headers 跟 body 则全为空.

在 sendRequest 时, curl 是这么用的

```
$this->withOption(CURLOPT_HTTPHEADER, $headers);
$this->withOption(CURLOPT_URL, $url);
$this->withOption(CURLOPT_CUSTOMREQUEST, $this->getMethod());
$this->withOption(CURLINFO_HEADER_OUT, true);
$this->withOption(CURLOPT_HEADER, true);
$this->withOption(CURLOPT_RETURNTRANSFER, true);

foreach ($this->options as $key => $option) {
    curl_setopt($ch, $key, $option);
}

$response = curl_exec($ch);
$errorCode = curl_errno($ch);
$errorMsg = curl_error($ch);

list($responseHeaders, $response) = explode("\r\n\r\n", $response, 2);
```

通过 `CURLOPT_HEADER` 将 response headers 同 body 一起输出. 然后根据 `\r\n\r\n` 切割. 然后看一下苹果那边的响应:

```
HTTP/1.1 100 Continue

HTTP/1.1 200 Apple WebObjects
x-apple-jingle-correlation-key: DUWRKYSQ56LP3NL2J3THK6VBFY
x-apple-request-uuid: 1d2d1562-50ef-96fd-b57a-4ee6757aa12e
pod: 100
x-apple-translated-wo-url: /WebObjects/MZFinance.woa/wa/verifyReceipt
apple-tk: false
edge-control: no-store
edge-control: cache-maxage=0
x-apple-lokamai-no-cache: true
cache-control: private
cache-control: no-cache
cache-control: no-store
cache-control: no-transform
cache-control: must-revalidate
cache-control: max-age=0
itspod: 100
x-webobjects-loadaverage: 21
apple-seq: 0
apple-originating-system: MZFinance
strict-transport-security: max-age=31536000
x-frame-options: SAMEORIGIN
x-apple-orig-url: https://sandbox.itunes.apple.com/WebObjects/MZFinance.woa/wa/verifyReceipt
x-apple-application-site: SB
date: Wed, 09 May 2018 15:36:39 GMT
set-cookie: itspod=100; version="1"; expires=Sat, 09-Jun-2018 15:36:39 GMT; path=/; domain=.apple.com
set-cookie: mzf_in=990185; version="1"; path=/WebObjects; domain=.apple.com; secure; HttpOnly
set-cookie: mzf_dr=0; version="1"; expires=Thu, 01-Jan-1970 00:00:00 GMT; path=/WebObjects; domain=.apple.com
apple-timing-app: 7 ms
expires: Wed, 09 May 2018 15:36:39 GMT
x-apple-application-instance: 990185
content-length: 1273

{"status":0}
```

多了一行 `HTTP/1.1 100 Continue`, 搜 MDN 

> HTTP `100 Continue` 信息型状态响应码表示目前为止一切正常, 客户端应该继续请求, 如果已完成请求则忽略. 为了让服务器检查请求的首部, 客户端必须在发送请求实体前, 在初始化请求中发送 Expect: 100-continue 首部并接收 100 Continue 响应状态码.

看了鸟哥的[文章](http://www.laruence.com/2011/01/20/1840.html), 大致可以猜测出原因:

- curl 在 POST 或 PUT 的时候, 如果 request body 大于 1024 字节的时候, 不会直接发起请求而是分两步
- 先发送一个带 `Expect: 100-continue` 的请求进行询问 Server 是否接受
- Server 返回 `100 continue` 后, curl 把 request body 发给 Server
- 刚好我测试时使用的苹果的支付凭证大于 1024 字节, 触发这个机制

那么解决方案也可以参考鸟哥或者是 Guzzle 的做法, 就是指定一个空的 `Expect:` 请求头, 也就是不进行询问.
```
curl_setopt($ch, CURLOTP_HTTPHEADER, ['Expect:']);
```

Guzzle 的做法是当 `options` 中没指定的话, 就置空避免 curl 自动添加

https://github.com/guzzle/guzzle/blob/master/src/Handler/CurlFactory.php?utf8=%E2%9C%93#L276
```
// If the Expect header is not present, prevent curl from adding it
if (!$request->hasHeader('Expect')) {
    $conf[CURLOPT_HTTPHEADER][] = 'Expect:';
}
```

> 如果 `options` 中有指定的话, guzzle 是通过 `CURLOPT_HEADERFUNCTION` 和 `CURLOPT_FILE` 来分别读取 headers 和 body, 具体细节还没看懂, 哈.

那么前面 MDN 的文档讲到, 服务端可能会根据 `Expect` 检查是否接受请求, 而 MDN 的关于 Expect 的文档也讲到:

> 常见的浏览器不会发送 Expect 消息头，但是其他类型的客户端如 cURL 默认会这么做。

如果我认为强制不进行询问也是可以的, 哈, 又涨姿势了.

顺便吐槽一下 [@JanHuang](https://github.com/JanHuang) 之前关于这块的处理:

https://github.com/fastdlabs/http/commit/4be3d6fd913f63f357dae037f52d42da2fe4c0a1

```
$responseInfo = explode("\r\n\r\n", $response);
$response = array_pop($responseInfo);
$responseHeaders = array_pop($responseInfo);
```

一开始觉得这种处理方式有点猥琐但也算有效, 但下班路上才想到.. 如果 response body 里带有 `\r\n\r\n`, 那不就出事了 ?
