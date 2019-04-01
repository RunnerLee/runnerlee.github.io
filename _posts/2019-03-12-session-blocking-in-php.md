---
layout: post
title: PHP 的 session blocking
date: 2019-03-12
update_date: 2019-03-12
summary: 好久没搞这个了
logo: hand-rock-o
---

有一个 php 项目遇到了 session blocking 的问题, 在本地进行复现, 两个请求打开同一个 session 文件:

| timing  | request a | request b |
|---|---|---|
| 1 | session_start() | - |
| 2 | sleep(10) | - |
| 3 |  | session_start() |
| 4 | end | ... |
| 5 |  | end |

当第二个请求调用 `session_start()` 时发生了阻塞. 因为看不懂 php 源码, 直接看下文件的使用情况:

```shell

$ fuser /var/tmp/52domsuodlujgj8tbisut17180
/var/tmp/52domsuodlujgj8tbisut17180:  1679  8177

$ lsof /var/tmp/52domsuodlujgj8tbisut17180
COMMAND    PID    USER   FD   TYPE DEVICE SIZE/OFF    NODE NAME
php-fpm5. 1679 vagrant   16uW  REG  252,0    23941 1314854 /var/tmp/52domsuodlujgj8tbisut17180
php-fpm5. 8177 vagrant    9u   REG  252,0    23941 1314854 /var/tmp/52domsuodlujgj8tbisut17180

```

当 `request a` 完成后, 再执行 `lsof`:
```
COMMAND    PID    USER   FD   TYPE DEVICE SIZE/OFF    NODE NAME
php-fpm5. 8177 vagrant   12uW  REG  252,0    23941 1314854 /var/tmp/52domsuodlujgj8tbisut17180
```


可以看到, 1679 的进程文件描述符为 `16uW`, 而另外一个是 `9u` 查看手册:

```
u：for a read and write lock of any length;
W：for a write lock on the entire file;
```

因此可以判断 `request a` 被分配到了 PID 1679 的进程, 先拿到了 session 文件的写锁, 并在请求结束时才释放. 而另外一个请求在获取锁的时候发生了阻塞.

> 文件描述符前面的数字不知道干嘛用的, 有趣的是当前面一个进程完成后, 下面那个进程拿到锁之后那个数字总是会 + 3

那么要避免阻塞, 有两种解决办法: 打开 session 文件不上写锁, 或是手动 `session_commit()` / `session_write_close()`.

两种各有优劣:
- 不上写锁, 会导致覆盖
- 手动 commit, 则要求应用中操作 session 需要统一行为, 如果应用已经上线则需要修改较多

然而目前我能想到的正常的业务流程和业务场景里, 不上写锁带来的问题貌似都不影响, 问题不大. 

在 php 7 里, php 提供了这样的功能, 在 `session_start()` 的 `options` 传递 `read_and_close` 为 `true`, 让 php 在读完 session 文件后关闭.

而在 php 7 之前的版本就只能手动实现了. 简单地写一下改为上共享锁的实现:

```php

function get_session_save_path()
{
    if ('' === $path = session_save_path()) {
        $path = sys_get_temp_dir();
    }
    return rtrim($path, '/');
}

function readSession($id)
{
    $file = get_session_save_path() . "/{$id}";
    if (!is_file($file) || (filemtime($path) + $this->getTimeout() < time())) {
        return '';
    }
    $data = '';
    if ($handle = fopen($file, 'rb')) {
        try {
            if (flock($handle, LOCK_SH)) {
                clearstatcache(true, $handle);
                $data = fread($handle, filesize($file) ?: 0);
                flock($handle, LOCK_UN);
            }
        } finally {
            fclose($handle);
        }
    }
    return $data;
}
```

看着是不是很熟悉啊这段代码, 没错, 参考 laravel 的, 哈哈. 其实是个很基础的知识点了, 一直在写 api 差点把这个忘光了.

#### 参考:
- [PHP Session Locking: How To Prevent Sessions Blocking in PHP requests](https://ma.ttias.be/php-session-locking-prevent-sessions-blocking-in-requests/)



