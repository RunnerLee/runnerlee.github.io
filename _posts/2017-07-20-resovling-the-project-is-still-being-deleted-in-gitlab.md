---
layout: post
title: 解决 GitLab 中新建与已删除项目同名时报错
category: 技术
tags: GitLab
description: 解决 GitLab 中新建与已删除项目同名时报错 the project is still being deleted
author: RunnerLee
---

我用的版本是 `社区版 8.16.4`

删除项目后, 在同个分组下再新建一个同名的项目, 一直提示
```
The project is still being deleted. Please try again later.
```

参考网上的办法, 要进 ruby console 进行删除. 并且需要先找到项目的ID.

### 找项目ID
网上的办法, 是从 `production.log` 中找到项目ID. 然而我打开 `production.log` 之后只能看到这样的信息
```
Parameters: {"utf8"=>"✓", "authenticity_token"=>"", "project"=>{"namespace_id"=>"1", "path"=>"demo", "description"=>"", "visibility_level"=>"0"}}
```
而别人的是这样
```
Parameters: {"authenticity_token"=>"{token}", "namespace_key"=>"[FILTERED]", "namespace_id"=>"{namespace}", "project_id"=>"{repo}"}
```

但是我在 GitLab 的管理后台的 监控 - 后台作业 里, 能看到一条 `Dead` 的任务

![Dead Job](/assets/img/DeepinScrot-0059.png)

猜测其中的 `14` 应该就是项目 ID 了.

### 开始删除
```
# 进入gitlab 安装目录
cd /opt/gitlab

# 进入 console
bin/gitlab-rails

# 查找项目, 取消正在删除状态并保存
p = Project.unscoped.find(14)
p.pending_delete = false
p.save validate:false
```

这时候, 可以在 UI 上再次看到被删除的项目. 紧接着

```
u = User.find_by_username('your_login_username')
AuthorizedProjectsWorker.new.perform(u.id)
Projects::DestroyService.new(p, u, {}).execute
```

### 参考
* [https://gitlab.com/gitlab-org/gitlab-ce/issues/27457](https://gitlab.com/gitlab-org/gitlab-ce/issues/27457)
* [解决 Gitlab 中 the project is still being deleted 错误](https://www.himysql.com/post/resovling-the-project-is-still-being-deleted-in-gitlab/)
