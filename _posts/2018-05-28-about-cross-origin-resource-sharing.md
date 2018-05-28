---
layout: post
title: 折腾下CORS
category: 技术
tags: http cors
description: 折腾下CORS
author: RunnerLee
---

CORS, 全程 Cross-Origin Resource Sharing, 翻译跨域资源共享. 是一种跨域调用的解决方案.

> 跨域资源共享标准新增了一组 HTTP 首部字段，允许服务器声明哪些源站有权限访问哪些资源。

在没有应用 CORS 的情况下, 在浏览器中调用跨域资源, 通过抓包可以看到, 其实请求是正确响应的了, 只不过浏览器 "拒绝" 使用了. 

那要浏览器使用, 其实只要在响应头里加三行:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Method: GET,POST,PUT,PATCH,DELETE,OPTIONS
Access-Control-Allow-Credentials: true
```
(前阵子几个同事搞得挺大的最后也就是加这三个东西 🤪)

其中 `Access-Control-Allow-Origin` 是用于控制允许访问的域名, 设置为 `*` 明显是不行的, 并且服务端应该校验它的.

还是了解一下这几个到底是啥, 以及怎么用的.

### 简单请求

跨域请求会被区分为两类: 简单请求与非简单请求 (应该是吧, MDN 上也叫 需预检的请求, ), 简单请求的定义是:

1. method 为: GET, POST, HEAD
2. 不包含 Fetch 规范定义的对 CORS 安全的首部字段集合以外的自定义头部 ( Fetch 规范有待了解)
3. `Content-Type` 的值为 `text/plain`, `multipart/form-data`, `application/x-www-form-urlencoed`

如果不满足以上三个条件, 则请求不是简单请求.

### 预检请求 (Preflight Request)

如果请求不满足简单请求的条件, 请求就变成了需预检的请求. 所谓的预检, 就是向服务端以 OPTIONS 的方法调用目标 URI, 服务端只要返回一个不带 response body 的响应, 并且响应头中带有 `Access-Control-Allow-Method` 即可, 如果该响应头的值包含实际请求使用的方法, 例如想用 POST, 它响应了 POST, 那就没问题.

那么到这里, 就理清了 CORS 请求的两种情况:
1. 简单请求, 啥都不用干, 直接调用.
2. 需预检请求, 先发一个 OPTIONS 请求 (浏览器自行完成)

那么列一下几个请求头和响应头中需要用到的几个字段:

### 请求头

- Origin, 预检请求或实际请求的来源
- Access-Control-Request-Method, 用于预检请求, 告知实际请求使用的方法
- Access-Control-Request-Headers, 用于预检请求, 告知实际请求携带的请求头

### 响应头
- Access-Control-Allow-Origin, 响应允许访问的来源
- Access-Control-Expose-Headers, 告知浏览器 XMLHttpRequest 能获取到的自定义响应头
- Access-Control-Max-Age, 用于预检请求, 告知预检请求结果缓存时间, -1 时禁用, 无设定时浏览器有默认值. 单位秒.
- Access-Control-Allow-Credentials, 用于预检请求和实际请求, 用于指定携带了 cookie 或是 HTTP Authentication (即 credentials) 的请求, 是否允许浏览器把响应发给 XMLHttpRequest, 布尔值.
- Access-Control-Allow-Headers, 用于预检请求, 告知实际请求中允许携带的头部
- Access-Control-Allow-Methods, 告知实际请求允许使用的方法

> 注意, 当开启时, `Access-Control-Allow-Origin` 不能为 `*`. 而当它的值非 `*`, 时, 响应头 `Vary` 的值必须包含 `Origin`

那么大概的流程就是:
1. 判断是否是 CORS 请求
2. 判断 Origin 是否合法, 不合法则拒绝
3. 判断是否是预检请求 (Preflight Request)

如果是预检请求, 则处理步骤为:
1. 判断是否有 Access-Control-Request-Method, 没有则拒绝
2. 判断是否有 Access-Control-Request-Headers, 如果有, 判断内容是否合法
3. 设置 Access-Control-Allow-Origin
4. 设置 Access-Control-Allow-Methods
5. 设置 Access-Control-Allow-Credentials
6. 设置 Access-Control-Allow-Headers
7. 设置 Access-Control-Max-Age
8. 返回不带 body 的 response

如果是实际请求, 则处理步骤为:
1. 设置 Access-Control-Allow-Origin
2. 设置 Access-Control-Expose-Headers, 非必须
3. 设置 Access-Control-Allow-Credentials
4. 返回响应

可以看这个图: [image](https://www.html5rocks.com/static/images/cors_server_flowchart.png).

那么理清了之后, 实现一个就很简单啦: [cors-provider](https://github.com/fastdlabs/cors-provider), Powered By RunnerLee.

### 参考
- [https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#The_HTTP_response_headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#The_HTTP_response_headers)
- [https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Access-Control-Allow-Credentials](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Access-Control-Allow-Credentials)
- [https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Access-Control-Max-Age](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Headers/Access-Control-Max-Age)
- [https://fetch.spec.whatwg.org/#cors-safelisted-request-header](https://fetch.spec.whatwg.org/#cors-safelisted-request-header)
- [https://github.com/barryvdh/laravel-cors](https://github.com/barryvdh/laravel-cors)
