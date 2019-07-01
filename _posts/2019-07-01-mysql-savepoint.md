---
layout: post
title: mysql 的 savepoint
date: 2019-07-01
update_date: 2019-07-01
summary: 所谓的嵌套事务
logo: database
---

之前搞 Yii 或者 TP 的项目, 要避免嵌套事务, 总是需要把事务开启的传递通过参数传递. 最近在写 laravel 的项目, 一不小心又写了嵌套的事务.

但没想到 laravel 的处理挺有意思. 用到了 savepoint. 摘抄一下维基百科关于 savepoint 的介绍:

```
savepoint是在数据库事务处理中实现“子事务”（subtransaction），也称为嵌套事务的方法。
事务可以回滚到savepoint而不影响savepoint创建前的变化。不需要放弃整个事务。
```

直接在 mysql 里面试一下:

```
mysql> begin;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from demo where id = 2;
+----+-----------+-----+------+------+------+
| id | username  | age | a    | b    | c    |
+----+-----------+-----+------+------+------+
|  2 | holy shit |  11 |    2 |    6 |   10 |
+----+-----------+-----+------+------+------+
1 rows in set (0.01 sec)
```

然后执行三次 update, 并分别创建 `savepoint`

```
mysql> update demo set username = 'aaa' where id = 2;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> savepoint trans_1;
Query OK, 0 rows affected (0.00 sec)

mysql> update demo set username = 'bbb' where id = 2;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> savepoint trans_2;
Query OK, 0 rows affected (0.00 sec)

mysql> update demo set username = 'ccc' where id = 2;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> savepoint trans_3;
Query OK, 0 rows affected (0.00 sec)
```

然后再执行一次更新

```
mysql> update demo set username = 'ddd' where id = 2;
Query OK, 1 row affected (0.01 sec)
Rows matched: 1  Changed: 1  Warnings: 0

mysql> select * from demo where id = 2;
+----+----------+-----+------+------+------+
| id | username | age | a    | b    | c    |
+----+----------+-----+------+------+------+
|  2 | ddd      |  11 |    2 |    6 |   10 |
+----+----------+-----+------+------+------+
1 row in set (0.01 sec)
```

回滚到 `trans_3`

```
mysql> rollback to trans_3;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from demo where id = 2;
+----+----------+-----+------+------+------+
| id | username | age | a    | b    | c    |
+----+----------+-----+------+------+------+
|  2 | ccc      |  11 |    2 |    6 |   10 |
+----+----------+-----+------+------+------+
1 row in set (0.00 sec)
```

然后再回滚到 `trans_2`, 再尝试回滚到 `trans_3`

```
mysql> rollback to trans_2;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from demo where id = 2;
+----+----------+-----+------+------+------+
| id | username | age | a    | b    | c    |
+----+----------+-----+------+------+------+
|  2 | bbb      |  11 |    2 |    6 |   10 |
+----+----------+-----+------+------+------+
1 row in set (0.00 sec)

mysql> rollback to trans_3;
ERROR 1305 (42000): SAVEPOINT trans_3 does not exist

mysql> rollback to trans_2;
Query OK, 0 rows affected (0.00 sec)
```

可见回滚到 `trans_2` 之后 `trans_3` 就被释放掉了, 但 `trans_2` 没有. 手动释放 `trans_2`, 再查查看

```
mysql> release savepoint trans_2;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from demo where id = 2;
+----+----------+-----+------+------+------+
| id | username | age | a    | b    | c    |
+----+----------+-----+------+------+------+
|  2 | bbb      |  11 |    2 |    6 |   10 |
+----+----------+-----+------+------+------+
1 row in set (0.01 sec)

mysql> release savepoint trans_2;
ERROR 1305 (42000): SAVEPOINT trans_2 does not exist
```

释放之后并不会回滚到 `trans_1`. 这时候直接 rollback 掉.

```
mysql> rollback;
Query OK, 0 rows affected (0.00 sec)

mysql> select * from demo where id = 2;
+----+-----------+-----+------+------+------+
| id | username  | age | a    | b    | c    |
+----+-----------+-----+------+------+------+
|  2 | holy shit |  11 |    2 |    6 |   10 |
+----+-----------+-----+------+------+------+
1 row in set (0.00 sec)
```

完美, 所以总结一下 savepoint 的注意事项:

- mysql innodb 支持
- 需要显式的 `rollback` 或 `commit`
- `rollback to` 到某个 savepoint 会释放掉它之后的 savepoint
- `rollback to` 到某个不存在的 savepoint 时会报错

猜想一下, 如果是自己在 php 中实现的话, 大概是这样的步骤:
- 开启事务时, 判断应该是 "主事务" 还是 "子事务", 如果是前者则执行 `start transcation`, 后者则创建 savepoint
- 通过参数传递事务层级, 或是将事务层级保存到某个地方, 例如类属性
- 回滚时, 根据当前层级回滚, 如果是回滚到最后一层时, 则执行 `rollback`
- 回滚后到某个 savepoint 后, 应当将 savepoint 保存为当前等级. 如果下次回滚到的层级是在这次的层级之后, 退出或不执行操作

看一下 laravel 中的实现:

```php

namespace Illuminate\Database\Concerns;

trait ManagesTransactions
{
    public function beginTransaction()
    {
        // 这里是先开启事务/创建 savepoint, 再递增 `$transactions`
        $this->createTransaction();
        $this->transactions++;
        $this->fireConnectionEvent('beganTransaction');
    }

    protected function createTransaction()
    {
        if ($this->transactions == 0) {
            try {
                $this->getPdo()->beginTransaction();
            } catch (Exception $e) {
                $this->handleBeginTransactionException($e);
            }
        } elseif ($this->transactions >= 1 && $this->queryGrammar->supportsSavepoints()) {
            $this->createSavepoint();
        }
    }
}
```

可以看到, 每次调用 `beginTransaction()` 都会递增当前层级用作开启事务时的层级标识. 如果已经开启了事务的话, 则调用 `createSavepoint()` 进行创建 savepoint.

```php
protected function createSavepoint()
{
    $this->getPdo()->exec(
        $this->queryGrammar->compileSavepoint('trans'.($this->transactions + 1))    // 注意这里加了 1
    );
}
```

而在 rollback 这里是这么处理的:

```php
public function rollBack($toLevel = null)
{
    // 取要回滚到的 savepoint, 默认取上一个 savepoint
    $toLevel = is_null($toLevel)
                ? $this->transactions - 1
                : $toLevel;

    // 如果手动传入的层级范围有问题, 不执行操作
    if ($toLevel < 0 || $toLevel >= $this->transactions) {
        return;
    }
    $this->performRollBack($toLevel);
    $this->transactions = $toLevel;
    $this->fireConnectionEvent('rollingBack');
}
```

实际的回滚操作, 因为前面创建 savepoint 的时候有 `+ 1`, 所以这里也需要 `+ 1`

```php
protected function performRollBack($toLevel)
{
    if ($toLevel == 0) {
        $this->getPdo()->rollBack();
    } elseif ($this->queryGrammar->supportsSavepoints()) {
        $this->getPdo()->exec(
            $this->queryGrammar->compileSavepointRollBack('trans'.($toLevel + 1))
        );
    }
}
```

laravel 真是屌屌的~

