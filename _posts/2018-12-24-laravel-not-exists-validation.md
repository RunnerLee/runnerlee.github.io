---
layout: post
title: Laravel 表单验证实现 NOT EXISTS
date: 2018-12-24
update_date: 2018-12-24
summary: laravel
logo: check
---

一直有一个需求是检查某个字段值 **不存在** 数据库中, 今天又看了一下 laravel validation 源码. 
才发现从 5.3 开始已经把具体验证和错误消息处理的部分方法拆分了 trait. 

直接看一下 `exists` 的验证规则的具体实现:

```php
namespace Illuminate\Validation\Concerns

trait ValidatesAttributes
{
    public function validateExists($attribute, $value, $parameters)
    {
        $this->requireParameterCount(1, $parameters, 'exists');

        list($connection, $table) = $this->parseTable($parameters[0]);

        // The second parameter position holds the name of the column that should be
        // verified as existing. If this parameter is not specified we will guess
        // that the columns being "verified" shares the given attribute's name.
        $column = $this->getQueryColumn($parameters, $attribute);

        $expected = (is_array($value)) ? count($value) : 1;

        return $this->getExistCount(
            $connection, $table, $column, $value, $parameters
        ) >= $expected;
    }
}
```

那要实现 `not_exists` 就简单啦:

```php
Validator::extend('not_exists', function ($attributes, $value, $parameters, $validator) {
    return !$validator->validateExists($attributes, $value, $parameters);
});
```

解决 ~ 🤪




