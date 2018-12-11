---
layout: post
title: 在 Postman 中利用 Pre-Script 设置请求头
date: 2018-12-11
update_date: 2018-12-11
summary: Postman 技巧
logo: send
---

因为项目需要在请求头中放 MD5 签名, Insomnia 不支持, 只能重新用回 Postman. 记录一下步骤:

#### 配置自定义请求头, 使用未定义的环境变量

![](/assets/img/2018-12-11/postman_1.png)

> 可以请求 `postman-echo.com/get` 来测试

#### 编辑 Pre-Script

```js

var timestamp = Math.round((new Date()).getTime() / 1000),
    secret = pm.variables.get('secret'),
    appKey = pm.variables.get('app_id');
    
signature = CryptoJS.MD5(appKey + timestamp + secret).toString();

pm.variables.set('request_timestamp', Math.round((new Date()).getTime() / 1000));

pm.variables.set('request_signature', signature);

```

查看结果

```json

{
    "args": {},
    "headers": {
        "x-forwarded-proto": "https",
        "host": "postman-echo.com",
        "accept": "*/*",
        "accept-encoding": "gzip, deflate",
        "cache-control": "no-cache",
        "cookie": "sails.sid=s%3AsA5sZQ3cvKWT6maoZWEGbUxXW6NRH2jc",
        "postman-token": "e1be48b0-7653-45d6-b4a7-7476f4d88b9b",
        "user-agent": "PostmanRuntime/7.4.0",
        "x-app-id": "1",
        "x-signature": "1aab422c30e51a9e998a28b857403346",
        "x-timestamp": "1544518166",
        "x-forwarded-port": "80"
    },
    "url": "https://postman-echo.com/get"
}

```




