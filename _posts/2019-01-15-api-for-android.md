---
layout: post
title: 安卓不喜欢 API 里的 null
date: 2019-01-15
update_date: 2019-01-15
summary: API 联调
logo: android
---

跟安卓联调过接口的都知道, 他们要求接口下发数据一定不能有 `null`. 作为后端, 也只是想了个办法去转换 `null` 为空字符串而已.

请教了安卓并且搜了一下资料, 了解到其实并不是有 `null` 就会异常. 

而是 java 作为强类型语言, 类似一个场景, 在判断一个约定为字符串的字段是否为空时, java 的处理方式是

```java
target.isEmpty()
```

而在 php 则是直接 `empty($target)`. 而当 `target` 为 `null` 时, 在 java 里就会产生空指针异常 (这里我是以 js 的方式来理解的, 因为我不懂 java).

所以其实 `null` 是能解决的, 搜了一下 java 可以用 `TextYtils.isEmpty()` 来检查是否 `null`, 亦或是 `== null` 来判断. 但这样的工作量是较大的.

因此, 类似的场景, 就有两种解决方式了:

1. 后端不处理接口返回, 但跟安卓约定好哪些字段可能为 `null`, 安卓在联调时做对应检查, 抓包看了一些大厂的接口, 的确也有一些是返回 `null` 的.
2. 后端将接口返回进行处理, 将 `null` 转换为空字符串.

在 Laravel 中, 我们一般都会使用一个封装好的方法来做统一的返回, 以实现响应包装和应用 fractal, 那么就只需要在其中做转换就好啦. 这里提供两个方法:

递归转换 `null` 为空字符串

```php
function convertNullToEmptyString(array $data) :array
{
    foreach ($data as &$item) {
        if (null === $item) {
            $item = '';
        } elseif (is_array($item)) {
            $item = convertNullToEmptyString($item);
        }
    }
    return $data;
}
```

队列转换 `null` 为空字符串

```php
function convertNullToEmptyString(array $data) :array
{
    $queue = [&$data];
    $i = 0;
    while (true) {
        if (!isset($queue[$i])) {
            break;
        }
        foreach ($queue[$i] as &$item) {
            if (null === $item) {
                $item = '';
            } elseif (is_array($item)) {
                $queue[] = &$item;
            }
        }
        ++$i;
    }

    return $data;
}
```
