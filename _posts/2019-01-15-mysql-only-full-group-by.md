---
layout: post
title: MySQL 的 ONLY_FULL_GROUP_BY
date: 2019-01-15
update_date: 2019-01-15
summary: SQL 记录
logo: database
---

应该经常会写或看到类似这样的 SQL 来实现分组求最值:

```sql
SELECT * FROM orders GROUP BY status
```

这样的语句, 在 MySQL 5.7 中, 会报一个错误:

```
Error Code: 1055. Expression #1 of SELECT list is not in GROUP BY clause and contains nonaggregated column 'orders.id' which is not functionally dependent on columns in GROUP BY clause; this is incompatible with sql_mode=only_full_group_by
```

此处可以看到是由于 `sql_mode` 中开启了 `ONLY_FULL_GROUP_BY` 的原因. 在 MySQL 中开启了它, 将会要求 select list 中只能包含 `GROUP BY` 后的列以及聚合函数, 也就是严格匹配. (SQL 92)

因此, 解决这个问题就有两种方式可选: 改 MySQL 配置, 或是改 SQL 语句. 为了后续升级迁移及维护, 需要优先考虑后者.

下面进行一个实验, 创建一个员工表, 并且从员工表中查询出每个部门中考核分数最高的员工.

```sql
CREATE TABLE staff (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(20) NOT NULL DEFAULT '',
    score INT(10) UNSIGNED NOT NULL,
    department VARCHAR(20) NOT NULL,
    INDEX(department)
)

INSERT INTO staff(null, 'aaa', 10, 'a');
INSERT INTO staff(null, 'bbb', 10, 'a');
INSERT INTO staff(null, 'ccc', 10, 'c');
```

在 MySQL5.7 之前, 可以这么做:

```
mysql> SELECT id, name, MAX(score) score, department FROM staff GROUP BY department;
+----+------+-------+------------+
| id | name | score | department |
+----+------+-------+------------+
|  1 | aaa  |    11 | a          |
|  3 | ccc  |    12 | b          |
+----+------+-------+------------+
2 rows in set (0.01 sec)
```

而在 MySQL5.7 中将报错, 那么利用 select list 中只能有 group by list 和聚合参数结果, 我们可以增加多一个子查询, 在派生表中获取到每个部门的最高分,
从而查出对应的其他字段.

> 这里假定每个部门中的最高分是唯一的

```sql
mysql> SELECT
           id, name, staff.score, staff.department
       FROM
           staff,
           (SELECT
               MAX(score) score, department
           FROM
               staff
           GROUP BY department) temp
       WHERE
           staff.score = temp.score
           AND staff.department=temp.dapartment;
+----+------+-------+------------+
| id | name | score | department |
+----+------+-------+------------+
|  2 | bbb  |    11 | a          |
|  3 | ccc  |    12 | b          |
+----+------+-------+------------+
2 rows in set (0.00 sec)
```

执行 `EXPLAIN` 

![](/assets/img/2019-01-16/1.png)

可以看到, MySQL 会先将子查询的 `GROUP BY` 结果放到派生表, 然后以派生表作为驱动表, 驱动与 `staff` 做连表查询, 结合索引的情况下, 应该能较快得到结果.

到这里就基本能解决 `ONLY_FULL_GROUP_BY` 所带来的问题. 那么其实还有问题:

1. 如果部门内的 `score` 有重复值怎么办?
2. 为什么一定要不允许 select list 中有不明确的 column ?

其实这也就是求最值的一个我理解的不可避免的情况, 就是最值存在重复, 当只能取一条时, 决定取哪条. 如果不在 select list 中明确, 那么得到的结果可能是不定的.
而如果要明确, 就可以手动指定一个聚合函数来选择行. 例如可以在子查询中增加 `MAX(id)` 来指定如果有两条最高分时选择 `ID` 最大的行.

### 参考
- [http://www.ywnds.com/?p=8184](http://www.ywnds.com/?p=8184)
- [https://mp.weixin.qq.com/s/u9Twv24IKxfHVyj62B4VtQ](https://mp.weixin.qq.com/s/u9Twv24IKxfHVyj62B4VtQ)
- [https://blog.csdn.net/dc2222333/article/details/78234649](https://blog.csdn.net/dc2222333/article/details/78234649)

