---
layout: post
title: 计算乌拉姆数列
date: 2019-03-10
update_date: 2019-04-18
summary: 瞎学一点数学
logo: sort-numeric-asc
---

摘抄一下乌拉姆数列的定义:

```
 任取两个正整数a和b，乌拉姆序列U(a,b)按如下方式定义：U(a,b)1 = a，U(a,b)2 = b，对于k > 2，
 U(a,b)k是比U(a,b)(k-1)更大，且存在用U(a,b)之前的这些项中的不同两项之和唯一表示的最小整数。
 例如，序列U(1,2)的开头部分如下所示
 1, 2, 3 = 1 + 2, 4 = 1 + 3, 6 = 2 + 4, 8 = 2 + 6, 11 = 3 + 8;
 5不在这个序列是，因为5 = 1 + 4 = 2 + 3，有两种表示方法，同样地7也是如此因为7 = 1 + 6 = 3 + 4。

 数列的首两项U1和U2定义为1和2，对于n>2，Un为最小而又能刚好以一种方法表达成之前其中两个相异项的和。
 例如3=1+2，故U3=3；4=1+3（注意2+2不计算在内），故U4=4；5=2+3=1+4，所以它不在数列内。
```

一个 PHP 实现:

```php
$numbers = [1, 2];

$max = 1000;

for ($i = 3; $i < $max; ++$i) {
    $count = 0;
    foreach ($numbers as $value) {
        $left = $i - $value;
        if ($left != $value && in_array($left, $numbers)) {
            if (++$count > 2) {
                break;
            }
        }
    }

    2 == $count && $numbers[] = $i;
}

print_r($numbers);
```

Update:

同样的思路, 用 Go 实现一次:

```go
package main

import "fmt"

func ulam(a int, b int, max int) []int {
	sequence := []int{a, b}
	numbers := map[int]int{
		a: 1,
		b: 1,
	}
	counter := 0
	for i := int(3); i < max; i++ {
		counter = 0
		for m := range sequence {
			left := i - sequence[m]
			if left != sequence[m] {
				if _, ok := numbers[left]; ok {
					counter++
					if counter > 2 {
						break
					}
				}
			}
		}
		if 2 == counter {
			sequence = append(sequence, i)
			numbers[i] = 1
		}
	}
	return sequence
}

func main() {
	fmt.Println(ulam(1, 2, 100))
}
```
