---
layout: post
title: 午后一道数学小题目
date: 2019-04-24
update_date: 2019-04-24
summary: 睡不好
logo: coffee
---

求 0 - 100 之间, 所有 3 或是 5 的倍数的和. 一开始没注意想, 把 3 和 5 的共同倍数给加了两次.

循环实现:

```php
function funny($number)
{
    $sum = 0;
    for ($i = 3; $i <= $number; $i += 3) {
        $sum += $i;
        if (($temp = $i + ($i / 3) * 2) <= $number && $temp % 3 !== 0) {
            $sum += $temp;
        }
    }

    return $sum;
}
```

等差数列求和:

```php
function funny($max)
{
    $callback = function ($num) use ($max) {
        $time = intval($max / $num);

        $return = ($time + 1) * $num * ($half = intval($time / 2));

        if (1 === $time % 2) {
            $return += ($half + 1) * $num;
        }

        return $return;
    };

    return $callback(3) + $callback(5) - $callback(15);
}
```

今年我小学四年级毕业了, 老师跟妈妈说, 我上学没用, 卖猪肉最好了.
