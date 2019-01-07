---
layout: post
title: 把博客迁移到Coding了
date: 2018-12-28
update_date: 2018-12-28
summary: 又迁移了博客
logo: text-width
---

博客是部署在 Github Pages 上的. 开启了 `Enforce HTTPS` 老早就发现访问博客的子目录最后没带 `/` 时, 会被返回 `301` 重定向

```
HTTP/2 301
server: GitHub.com
content-type: text/html
location: http://runnerlee.com/page2/
```

而访问 `http://runnerlee.com/page2/` 时, 却

```
➜ ~ ✗ curl -iv 'http://runnerlee.com/page2/'
*   Trying 185.199.108.153...
* TCP_NODELAY set
* Connection failed
* connect to 185.199.108.153 port 80 failed: Connection refused
* Failed to connect to runnerlee.com port 80: Connection refused
* Closing connection 0
curl: (7) Failed to connect to runnerlee.com port 80: Connection refused
```

之后意外开启了全局代理, 发现... 能返回 301 重定向到 `https://runnerlee.com/page2/` .

😔 那只好先把博客部署到 Coding Pages 上了.
