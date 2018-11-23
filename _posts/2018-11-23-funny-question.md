---
layout: post
title: 午后一条判断括号闭合的小题目
date: 2018-11-23
update_date: 2018-11-23
summary: 睡不着
logo: coffee
---

看到一条题目:

```
写个函数，判断下面扩号是否闭合，左右对称即为闭合： ((()))，)(())，(())))，(((((())，(()())，()()
```

参考别人的答案自己改进了下:

```php

$str = '((()))，)(())，(())))，(((((())，(()())，()()';

function check($str)
{
    $n = 0;
    for ($i = 0; $i < strlen($str); ++$i) {

        $n += $str[$i] === '(' ? 1 : ($str[$i] === ')' ? -1 : 0);

        // switch ($str[$i]) {
        //     case '(':
        //         ++$n;
        //         break;
        //     case ')':
        //         --$n;
        //         if ($n < 0) {
        //             return false;
        //         }
        //         break;
        // }
    }

    return 0 === $n;
}

var_dump(check('(()()()()(())(((),)))'));
```
