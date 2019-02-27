---
layout: post
title: 用 pipeline 处理多促销活动
date: 2019-02-27
update_date: 2019-02-27
summary: pipeline 应用场景
logo: shopping-cart
---

在做一个购物系统的时候, 有一个需求是这样: 有多种形式的促销活动, 在一笔订单中, 需要按照优先级先后应用多个促销活动, 并且将促销活动所产生的 discount 金额均摊到每个商品中作为让利金额, 且每种商品只能应用一个促销活动. 

促销活动的种类较多, 但主要分为两大类: 针对商品维度的促销活动和针对订单维度的促销活动. 大概有:

- 商品促销活动, 可以针对单个或多个商品创建促销活动. 促销方式有多种, 例如: 商品改价, 捆绑折扣, 满减, 每满指定数量减免等
- 店铺促销活动, 整单满减
- 会员价活动
- 会员整单折扣, 会员日整单折扣
- 优惠券

这个需求分析下来, 技术难点主要是几个:
- 多促销并存
- 促销产生的 discount 需要均摊到命中活动的商品上
- 每种商品只能命中一次活动

举一个例子就是:

```
春节期间, 超市设置了多个优惠活动:
- 1.25 升装百事可乐原价 9 元, 现优惠价 8 元.
- 某品牌巧克力购满三件仅需 9.99 元
- 某品牌酸奶购满 20 元立减 3 元
- 每天 20:00 到 22:00 生鲜蔬菜购满 30 元打七折
- 整单满 200 元立减 30 元
- 凭会员卡购满 200 元立减 5 元
```

综合分析下来, 最终选择使用管道来实现. 将每种活动定义 Stage, 将购物车中的商品列表作为 Payload. 同时把 Stage 按照活动的优先级别, 依次装入管道.

在每个 Stage 中, 都需要进行这些操作:
- 将命中的商品进行标记, 扫描商品列表时, 过滤掉已标记的商品
- 计算命中活动的 discount 金额, 增加到 Payload 中传给下个 Stage
- 将 discount 按照比例均摊到命中商品中

![](/assets/img/2019-02-27/1.png)

最终的代码实现:

```php
use Runner\Pipeline\Pipeline;

class ActivitiesManager
{
    public function match($skuList)
    {
        $pipeline = new Pipeline();
        return $pipeline
            ->stage($this->getStages())
            ->payload([
                'sku_list' => $skuList,
                'hit_activities' => [],
            ])
            ->process();
    }

    protected function getStages()
    {
        return [
            new DemoStage(),
        ];
    }
}

class DemoStage
{
    protected $config;

    public function __construct(array $config)
    {
        $this->config = $config;
    }

    public function handle(array $payload, $next)
    {
        foreach ($payload['sku_list'] as $sku) {
            if ($sku->hit) {
                continue;
            }
            $sku->hit = true;
            $sku->discount = '1.01';
        }
        $payload['hit_activities'][] = [
            'type' => 'demo_activity',
            'discount' => '100.01',
        ];
        return $next($payload);
    }
}
```

最终在实现中这么调用

```php

$manage = new ActivitiesManager();

$result = $manage->match($skuList);

// 获取命中的促销活动
print_r($result['hit_activities']);

foreach($result['sku_list'] as $sku) {
    echo $sku->discount . PHP_EOL;  // 获取每种商品均摊到的折扣金额
}
```

这样就能把复杂的多种类促销叠加使用的需求实现, 并且能以单种促销规则为单位拆分. 
