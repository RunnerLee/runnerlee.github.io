---
layout: post
title: Laravel Mysql IN 语句与 PDO 绑定值
date: 2018-12-13
update_date: 2018-12-13
summary: SQL 记录与 Laravel 源码阅读
logo: database
---

在一个 laravel 项目中, 手动使用 `DB::select()` 一条语句

```php

$sql = <<<SQL
SELECT * FROM `users` WHERE `id` IN (?) 
SQL;

$res = DB::select($sql, [
    '1,2',
])

```

数据表中对应的记录也存在, 但是实际上, 只能拿到编号为 `1` 的记录. 看一下 Laravel 源码是怎么绑定参数的:

```php
    /**
     * Bind values to their parameters in the given statement.
     *
     * @param  \PDOStatement $statement
     * @param  array  $bindings
     * @return void
     */
    public function bindValues($statement, $bindings)
    {
        foreach ($bindings as $key => $value) {
            $statement->bindValue(
                is_string($key) ? $key : $key + 1, $value,
                is_int($value) || is_float($value) ? PDO::PARAM_INT : PDO::PARAM_STR
            );
        }
    }
```

再复习下 php.net 关于 [PDPStatement::bindValue()](https://secure.php.net/manual/en/pdostatement.bindvalue.php) 的解释:

```
绑定一个值到用作预处理的 SQL 语句中的对应命名占位符或问号占位符。
```

我的理解是, 一个占位符 (无论是命名或问号) 在最终执行 binding 的时候, 都会将绑定的值转换为 SQL 中的值, 而并非只是替换进 SQL 文本中.

例如上面的例子:

```sql
SELECT * FROM `users` WHERE `id` IN (?) 
```

当传入的值为 `'3152990600000000090,3152990597600000010'` 的时候, 如果将参数类型设置为 `PDO::PARAM_STR`, 则等效于

```sql
SELECT * FROM `users` WHERE `id` IN ('3152990600000000090,3152990597600000010')
```

参数类型设置为 `PDO::PARAM_INT` 时, 则等效于

```sql
SELECT * FROM `users` WHERE `id` IN (CASE('3152990600000000090,3152990597600000010' AS SIGNED))
```

所以也就造成了查询结果只有一条的情况. 顺便 Laravel 的 `whereIn()` 实现方法

```php
namespace Illuminate\Database\Query\Grammars

use Illuminate\Database\Query\Builder;
use Illuminate\Database\Grammar as BaseGrammar;

class Grammar extends BaseGrammar
{
    protected function whereIn(Builder $query, $where)
    {
        if (! empty($where['values'])) {
            return $this->wrap($where['column']).' in ('.$this->parameterize($where['values']).')';
        }

        return '0 = 1';
    }
}
```

```php
namespace Illuminate\Database

abstract class Grammar
{
    public function parameterize(array $values)
    {
        return implode(', ', array_map([$this, 'parameter'], $values));
    }

    /**
     * Get the appropriate query parameter place-holder for a value.
     *
     * @param  mixed   $value
     * @return string
     */
    public function parameter($value)
    {
        return $this->isExpression($value) ? $this->getValue($value) : '?';
    }
}
```

Laravel 是通过判断 `whereIn()` 的参数中总共有多少个元素, 生成对应数量的占位符.
