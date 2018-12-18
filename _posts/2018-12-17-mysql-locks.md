---
layout: post
title: MySQL 的锁
date: 2018-12-17
update_date: 2018-12-17
summary: SQL 记录
logo: unlock
---

写一个关于锁的笔记笔记, 先列下目录.

Mysql 中的锁大致分为三种类型: 全局锁, 表级锁, 行锁.

行锁又分为 "共享锁" 和 "排他锁" 两种.

在行锁的使用中, 由于并发原因, 可能会产生 "死锁".

而在锁的应用上, 又有 "悲观锁" 和 "乐观锁" 两种方式.

数据库编程中控制并发的机制主要有两种: 锁和多版本机制.

#### 参考
- [MySQL中的共享锁与排他锁](https://www.hollischuang.com/archives/923)
- [行锁功过：怎么减少行锁对性能的影响？](https://time.geekbang.org/column/article/70215)
- [mysql死锁问题分析](https://www.cnblogs.com/LBSer/p/5183300.html)
- [两阶段锁协议](https://www.cnblogs.com/zszmhd/p/3365220.html)
- [悲观锁与乐观锁](https://juejin.im/post/5b4977ae5188251b146b2fc8)
- [MySQL 加锁处理分析](http://hedengcheng.com/?p=771#_Toc374698322)
- [MySQL-InnoDB-MVCC多版本并发控制](https://segmentfault.com/a/1190000012650596)
- [全局锁和表锁 ：给表加个字段怎么有这么多阻碍？](https://time.geekbang.org/column/article/69862)