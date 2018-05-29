---
layout: post
title: CSRF 与 API
category: 技术
tags: http csrf api
description: CSRF 与 API
author: RunnerLee
---

CSRF, 全称 Cross-Site Request Forgery, 跨站请求伪造, 也称 session riding, 这个别称很形象.

> 是一种挟制用户在当前已登录的 Web 应用程序上执行非本意的操作的攻击方法. -- 维基百科

举个例子, 假如 A 站点中有用户登录功能, 登录后有个转账的功能, 是表单 POST 跳转提交到一个 url `/do_transfer`. 用户 🐷 在 A 站点登录, 然后又打开了 B 站点.

B 站点中页面构建了一个表单, 是 POST 跳转提交到 A 站点中的 `/do_transfer`, 转账目标是攻击者. 那么如果这个表单提交了, 用户 🐷 的账户余额就会被盗取, 这就是一个 CSRF 攻击样例.

那么列举一下其中关键的几个点:
1. A 站点有用户功能
2. 用户需要在 A 站点中已登录, 登录信息未过期
3. A 站点接收表单提交没做来源校验
4. 攻击者暂时没获取到用户的登录凭证
5. 攻击在浏览器中完成, 需要用户触发 (访问 B 站点), 通过跳转提交发起攻击

那么防范这种攻击的方法, 主要是围绕上面第三点来展开的, 也就是需要检查来源, 目前主要有两步:
1. 检查 Referer
2. 应用校验 token


前几天看到了同事写的一份后端项目重构方案, 这是一个前后端分离的项目, 并且没有用户功能, 后端只需要提供 API. 方案中大篇幅介绍了要使用一种 "向页面或客户端中注入 token" 来解决 "裸 API" 的问题, 目的是防止恶意调用. 其实一句话可以概括: CSRF token. 当然, 其中说到一些 token 生成时接口加解密等等, 这都不影响. 

我认为, 一个不需要认证登录的 API 是没必要做 CSRF 防范的, 因为本身并不达到上面总结的几个点. 针对这个项目解决恶意调用, 我目前能想到的方法是:

1. 严格的CORS规则
2. 检查 Referer
3. 重放攻击
4. 限流
5. 验证码

虽说无法百分百解决被恶意调用的问题, 但应该能把影响控制到最小, 没办法, 谁让你没登录呢 🤪.

### 参考
- [https://zh.wikipedia.org/zh/%E8%B7%A8%E7%AB%99%E8%AF%B7%E6%B1%82%E4%BC%AA%E9%80%A0](https://zh.wikipedia.org/zh/%E8%B7%A8%E7%AB%99%E8%AF%B7%E6%B1%82%E4%BC%AA%E9%80%A0)
- [https://www.ibm.com/developerworks/cn/web/1102_niugang_csrf/index.html](https://www.ibm.com/developerworks/cn/web/1102_niugang_csrf/index.html)
- [https://laravel.com/docs/5.6/csrf](https://laravel.com/docs/5.6/csrf)
