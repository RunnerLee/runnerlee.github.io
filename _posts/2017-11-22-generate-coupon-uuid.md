---
layout: post
title: 生成由阿拉伯数字和小写字母组成的六位数唯一号码
date: 2017-11-22
update_date: 2017-11-22
summary: uuid 的愚蠢实现
logo: slideshare
---

有个优惠码的需求, 由于历史原因, 优惠码需要是由小写字母跟阿拉伯数字组成的六位数的码, 并且必须是唯一的.

找不到什么高效的办法, 也看不懂高大上的算法.. 那就土办法吧.

优惠码的形式是六位数的 36 进制数, 最大值为 `zzzzzz` 也就是 十进制的 `2176782335`, 也就是最多会有 2176782336 个码. 随机生成肯定是不靠谱的, 从 0 开始自增也不靠谱, 那样容易被猜到其他的优惠码.

那么换成, 把 2176782336 个码按照递增顺序均匀切割成若干块, 每次随机取一块, 然后从块里面按自增获取一个码就好了.

假设每块里面有 50000 个码, 切割后会有 43536 块, 把每块里面开始的码当作种子 (`a`) 存入种子池, 记录每块里面已获取的码的数量 (`b`), 每次获取后, 把 `b` 自增.

那么当获取到种子后, 计算码的公式为:

```
a * 50000 + b
```

然后再把获取到的码转换成 36 进制. 通过这种方式生成的码, 可以做到唯一, 并且两次生成的码几乎不会是自增的.

实现上, 可以把使用 redis 存放种子池, 使用一个有序集合, member 为种子值, score 为已获取的码数量.

可以通过 redis 的无序集合来检测是否有重复码产生, 利用 `sadd` 的返回值来判断. 写了一个小脚本跑了一下, 生成到 7750w 个码的时候只有一个重复(问题可能是我中止了执行修改了脚本后再次执行导致的). 然后 redis 就挂了, 哈哈. 实际上在跑的时候, 不需要用 redis 去记录所有的码.

一个简单的实现:

```php
<?php
/**
 * @author: RunnerLee
 * @email: runnerleer@gmail.com
 * @time: 2017-11
 */

namespace Runner\IdiotUuid;

use Exception;
use Predis\Client;

class Idiot
{
    const REDIS_AVAILABLE_SEEDS = 'coupon:available:seeds';

    const REDIS_SEEDS = 'coupon:seeds';

    /**
     * @var Client
     */
    protected $redis;

    /**
     * Coupon constructor.
     *
     * @param Client $client
     */
    public function __construct(Client $client)
    {
        $this->redis = $client;
    }

    /**
     * 初始化种子池, 提出头尾两个种子, 剩下可用码数 2176650000.
     *
     * @return void
     */
    public function initSeeds()
    {
        if (0 === $this->redis->exists(static::REDIS_SEEDS)) {
            $this->redis->zadd(static::REDIS_SEEDS, array_fill(1, 43534, 0));
            $this->redis->sadd(static::REDIS_AVAILABLE_SEEDS, range(1, 43534));
        }
    }

    /**
     * @throws Exception
     *
     * @return string
     */
    public function apply()
    {
        /*
         * 从有效种子池中获取一个有效的种子
         */
        if (is_null($index = $this->redis->srandmember(static::REDIS_AVAILABLE_SEEDS))) {
            throw new Exception('no available seeds');
        }

        /**
         * 获取种子的使用次数.
         */
        $score = (int) $this->redis->zscore(static::REDIS_SEEDS, $index);

        /**
         * 计算 code 值
         */
        $number = (int) $index * 50000 + $score;

        /*
         * 自增种子使用次数, 供下次直接使用
         */
        $this->redis->zincrby(static::REDIS_SEEDS, 1, $index);

        /*
         * 如果种子使用次数达到 50000 次, 从有效池中移除
         */
        if (49999 === $score) {
            $this->redis->srem(static::REDIS_AVAILABLE_SEEDS, $index);
        }

        /*
         * 返回三十六进制的 code
         */
        return str_pad(base_convert($number, 10, 36), 6, '0', STR_PAD_LEFT);
    }
}
```

GitHub: [https://github.com/RunnerLee/idiot-uuid](https://github.com/RunnerLee/idiot-uuid)
