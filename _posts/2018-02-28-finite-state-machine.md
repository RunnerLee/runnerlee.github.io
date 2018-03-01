---
layout: post
title: heshen 有限状态机
category: 技术
tags: php fsm
description: heshen 有限状态机
author: RunnerLee
---

> 年轻的樵夫哟，你掉的是这个金斧头，还是这个银斧头呢?

状态机一直在用 [yohang/Finite](https://github.com/yohang/Finite), 好用, 但配置复杂, 并且很久没维护了. 最终还是决定写一个, 命名想了很久, 最终决定用河神来命名, 哈哈哈, 我选择金斧头.

我的需求很简单, 管理每个状态转移, 并支持转移动作回调, 以及转移动作支持回调检查.

![](http://oupjptv0d.bkt.gdipper.com//heshen/fsm.png)

直接来用! [runner/heshen](https://github.com/RunnerLee/heshen)

先定义 Stateful 对象

```php
<?php
use Runner\Heshen\Contracts\StatefulInterface;

class Document implements StatefulInterface
{
    protected $state = 'a';

    public function getState(): string
    {
        return $this->state;
    }

    public function setState(string $state): void
    {
        echo "\nsetting\n";
        $this->state = $state;
    }
}

```

然后定义一个 Blueprint 来配置 Transition 及 State
```php
<?php

use Runner\Heshen\Blueprint;
use Runner\Heshen\State;
use Runner\Heshen\Contracts\StatefulInterface;

class Graph extends Blueprint {
    protected function configure(): void
    {
        $this->addState('a', State::TYPE_INITIAL);
        $this->addState('b', State::TYPE_NORMAL);
        $this->addState('c', State::TYPE_NORMAL);
        $this->addState('d', State::TYPE_FINAL);

        $this->addTransition('one', 'a', 'b');
        $this->addTransition('two', 'b', 'c', function (StatefulInterface $stateful, array $parameters) {
            return ($parameters['number'] ?? 0) > 5;
        });
    }

    protected function preOne(StatefulInterface $stateful, array $parameters = [])
    {
        echo "before apply transition 'one'\n";
    }
    
    protected function postOne(StatefulInterface $stateful, array $parameters = [])
    {
        echo "after apply transition 'one'\n";
    }
}
```

开始使用!
```php
<?php

use Runner\Heshen\Machine;

$machine = new Machine(new Document, new Graph);

var_dump($machine->can('one')); // output: bool(true)
var_dump($machine->can('two')); // output: bool(false)

$machine->apply('one');
/*
 * output:
 * before apply transition 'one'
 * setting
 * after apply transition 'one'
 */

var_dump($machine->can('two', ['number' => 1])); // output: bool(false)
var_dump($machine->can('two', ['number' => 6])); // output: bool(true)

```

通过 Factory 获取 Machine
```php
<?php

use Runner\Heshen\Factory;

$factory = new Factory([
    Document::class => Graph::class,
]);

$document = new Document;

$machine = $factory->make($document);

var_dump($machine->can('one')); // output: bool(true)
```

