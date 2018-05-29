---
layout: post
title: 修复注册 gitlab-runner 时提示 network problems 及 status=404 
date: 2017-11-13
update_date: 2017-11-13
summary: GitLab 跳坑系列
logo: git
---

GitLab 社区版 8.16.4, 在注册 runner 的时候, 一直提示这个错误

```
ERROR: Registering runner... failed runner=<token> status=404 Not Found
PANIC: Failed to register this runner. Perhaps you are having network problems
```

尝试了很多方法, 包括重启 gitlab 服务 以及 runner 均无法. 最终通过更新 runner 至 1.11.1 解决. (如果已经是这个版本, 卸载干净再安装). 

```
yum install gitlab-ci-multi-runner-1.11.1-1.x86_64
```

安装完成后, 进入 runner 注册步骤. 完成后, 需要重新注册服务

```
gitlab-runner install <service name> \
--working-directory=/path/to/runner/path \
--config /etc/gitlab-runner/config.toml \
--user <user>
```

之后启动 runner
```
gitlab-runner start
```

