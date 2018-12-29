---
layout: post
title: 午后一条判断括号闭合的小题目
date: 2018-11-23
update_date: 2018-12-29
summary: 睡不着
logo: coffee
---

看到一条题目:

```
写个函数，判断下面扩号是否闭合，左右对称即为闭合： ((()))，)(())，(())))，(((((())，(()())，()()
```

参考别人的答案自己改进了下:

```php
function check($str)
{
    $n = 0;
    for ($i = 0; $i < strlen($str); ++$i) {

        // 实际上不能用三元运算符, 我错了 ~
        // $n += $str[$i] === '(' ? 1 : ($str[$i] === ')' ? -1 : 0);

        switch ($str[$i]) {
            case '(':
                ++$n;
                break;
            case ')':
                --$n;
                if ($n < 0) {
                    return false;
                }
                break;
        }
    }

    return 0 === $n;
}


$str = '((()))，)(())，(())))，(((((())，(()())，()()';

var_dump(check($str));
```

### 2018-12-29 Updated

上面的三元运算被挑出 bug 了. 增加一种效率略低一点的方法

```php

function demo($str)
{
    $n = $i = 0;
    $len = strlen($str);
    while ($n >= 0 && $i < $len) {
        $n += $str[$i] === '(' ? 1 : ($str[$i] === ')' ? -1 : 0);
        ++$i;
    }

    return 0 === $n;
}
```
