---
layout: post
title: 判断数组元素是否被引用
date: 2019-02-22
update_date: 2019-02-22
summary: 貌似没什么卵用
logo: location-arrow
---

在 Laravel 中用 `dump()` 或是 `dd()` 的时候, 如果打印一个数组是这样的:

```php
$arr = [
    'a' => '1',
    'b' => 2,
];
$a = & $arr['a'];
dump($arr);
```

那么就能得到这样的输出:

```
array:2 [
  "a" => & "1"
  "b" => 2
]
```

可以看到 `dump()` 能获取到下标 `a` 被引用的状态. 是怎么实现的呢 ?

还没看源码之前, 搜了下 php 函数, 除了 `debug_zval_dump()` 貌似没其他函数可以获取到状态. 但在 StackOverflow 里搜到一个这样的办法:

```php
// @see: https://stackoverflow.com/questions/4817562/detecting-whether-a-php-variable-is-a-reference-referenced

function EqualReferences(&$first, &$second){
    if($first !== $second){
        return false;
    } 
    $value_of_first = $first;
    $first = ($first === true) ? false : true; // modify $first
    $is_ref = ($first === $second); // after modifying $first, $second will not be equal to $first, unless $second and $first points to the same variable.
    $first = $value_of_first; // unmodify $first
    return $is_ref;
}

$a = array('foo');
$b = array('foo');
$c = &$a;
$d = $a;

var_dump(EqualReferences($a, $b)); // false
var_dump(EqualReferences($b, $c)); // false
var_dump(EqualReferences($a, $c)); // true
var_dump(EqualReferences($a, $d)); // false
var_dump($a); // unmodified
var_dump($b); // unmodified
```

理解一下, 大概的原理就是, 变量 a 引用变量 b, 再把变量 b 的值赋给变量 c 作为备份. 修改变量 b 的值, 如果修改后 a 和 b 的值相同, 则确定 a 跟 b 是引用.

查看一下 php 中关于引用的解释:

> $a 和 $b 在这里是完全相同的，这并不是 $a 指向了 $b 或者相反，而是 $a 和 $b 指向了同一个地方。如果具有引用的数组被拷贝，其值不会解除引用。对于数组传值给函数也是如此。

那么基本可以确定, 如果一个数组中某个元素被引用, 那么 copy 这个数组后的新数组中的那个下标会跟原数组的同个下标引用到同个地方. 尝试地来实现一个检查数组的版本:

```php
function get_ref_index($arr)
{
    $copy = $arr;
    $return = [];
    foreach ($copy as $key => $value) {
        // 生成随机数替换以避免出现刚好值相等的情况
        $copy[$key] = uniqid(mt_rand());
        if ($arr[$key] === $copy[$key]) {
            $return[] = $key;
        }
        $copy[$key] = $value;
    }
    return $return;
}

$arr = [
    'a' => '1',
    'b' => '2',
];
$a = & $arr['a'];

print_r(get_ref_index($arr));
```

然后看一下 `symfony/var-dumper` 是怎么做的:

```php
// @see: https://github.com/symfony/var-dumper/blob/master/Cloner/VarCloner.php#L83

$cookie = (object) [];     // Unique object used to detect hard references

// ...

for ($i = 0; $i < $len; ++$i) {
    // Detect when we move on to the next tree depth
    if ($i > $currentDepthFinalIndex) {
        ++$currentDepth;
        $currentDepthFinalIndex = $len - 1;
        if ($currentDepth >= $minDepth) {
            $minimumDepthReached = true;
        }
    }
    $refs = $vals = $queue[$i];

    // ...

    foreach ($vals as $k => $v) {
        // $v is the original value or a stub object in case of hard references
        $refs[$k] = $cookie;
        if ($zvalIsRef = $vals[$k] === $cookie) {
            $vals[$k] = &$stub;         // Break hard references to make $queue completely
            unset($stub);               // independent from the original structure
            // ...
        }
        // ...
    }
```

可以看到, 同样也是复制了一个数组, 并通过遍历数组后替换下标的值并检查原数组中同下标的值是否改变来判断. 但这里面是用了一个 `stdClass` 来做替换, 这样相比随机数更好些, 因为对象比较用全等运算符时, 需要两个对象变量都是指向同一个实例.

不过这里面的其他很多逻辑还不大能看懂, 得再琢磨琢磨. 今天摸鱼到此为止 😅.

同时也记录下接下来要去了解的内容: 强引用 (hard reference) 和 弱引用 (weak reference).

#### 参考
- [StackOverflow - Detecting whether a PHP variable is a reference/referenced](https://stackoverflow.com/questions/4817562/detecting-whether-a-php-variable-is-a-reference-referenced)]
- [对象比较](http://php.net/manual/zh/language.oop5.object-comparison.php)
- [引用做什么](http://php.net/manual/zh/language.references.whatdo.php)
- [symfony/var-dumper](https://github.com/symfony/var-dumper)
