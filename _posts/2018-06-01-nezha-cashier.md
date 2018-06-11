---
layout: post
title: 说说自己做的第三方支付 sdk - 哪吒收银员
date: 2018-06-01
update_date: 2018-06-01
summary: nezha-cashier
logo: dollar
---

因为一直在做支付, 接入支付跟微信这些, 官方提供的 SDK 基本毫无人性. 而众多的非官方的 SDK 也感觉不尽人意, 所以决定自己来写一个.

其实之前也用过别人的 SDK, 在我都了解第三方的接口和参数的情况下, 用别人开发的 SDK, 哪怕是上千个 star 的 SDK, 都跟官方的 SDK 一样,
需要按第三方接口的参数一个个填写进去.

我认为的, 理想的调用支付的方式是:

```php

$gateway = 'alipay_web';

$order = [
    'order_id' => '1234567890',
    'subject' => 'testing',
    'description' => 'testing',
    'return_url' => 'https://www.baidu.com/',
];

$config = get_gateway_config($gateway);

cashier($config, $gateway)->charge($order);

```

能通过修改 `$gateway` 的值, 就能完成选择不同的第三方支付.

下面直接复制一下 [runner/nezha-cashier](https://github.com/RunnerLee/nezha-cashier) 的 readme

### 支持网关
| 名称 | 网关 | 支持动作 | 支持回调 | 备注 |
| :--- | :---- | :---- | :---- | :---- |
| alipay_app | 支付宝 APP 支付 | 支付/支付查询/退款 | 支付 |  |
| alipay_qr | 支付宝扫码支付 | 支付/支付查询/退款 | 支付 |  |
| alipay_wap | 支付宝手机网站支付 | 支付/支付查询/退款 | 支付 |  |
| alipay_web | 支付宝 PC 网站支付 | 支付/支付查询/退款 | 支付 |  |
| wechat_app | 微信 APP 支付 | 支付/支付查询/退款/退款查询 | 支付通知/退款通知 |  |
| wechat_h5 | 微信 H5 支付 | 支付/支付查询/退款/退款查询 | 支付通知/退款通知 | 内置抓取付款链接功能 |
| wechat_mina | 微信小程序支付 | 支付/支付查询/退款/退款查询 | 支付通知/退款通知 |  |
| wechat_official | 微信公众号支付 | 支付/支付查询/退款/退款查询 | 支付通知/退款通知 |  |
| wechat_qr | 微信扫码支付 | 支付/支付查询/退款/退款查询 | 支付通知/退款通知 |  |
| union_web | 银联网页支付 | 支付/支付查询 | 支付通知 | 较旧版本 |
| union_app | 银联网页支付 | 支付 | 支付通知 | 较旧版本 |
| paypal_express_checkout | PayPal 快速结账 | 支付/支付查询 | 支付通知 | 不稳定 |

### 介绍

在对接第三方支付中, 尤其是需要对接多个第三方支付时, 需要阅读第三方文档然后花费大量时间拼装和调试参数, 例如调用第三方下单创建支付, 如果需要同时接入微信跟支付宝支付, 那么就需要收集文档, 可想而知是非常麻烦的(其实还好.. hhh..).

这个组件提供的把与第三方通信分为三部分:

1. request, 请求, 主动调用第三方
2. response, 响应, 主动调用第三方获得的响应
3. notification, 通知, 第三方的各类通知

而每部分又部分为不同的动作, 每个动作绑定一个固定的表单 (Form), 每个表单的内容是固定的.

例如主动调用第三方下单创建支付 (ChargeRequest), 他使用的表单是 `ChargeRequestForm`. 填写好表单后, 传入组件, 即可由组件加工好参数并调用第三方支付.

这样就能做到, 只需要了解组件的表单内容, 就可以接入多个第三方支付, 一劳永逸 (不存在的 hhh).

### 使用

这里以支付宝 PC 网站支付为例, 如果需要使用其他的支付网关, 只需要修改实例化 `Cashier` 时传入的 `$gateway` 即可.

> 注意, 组件使用的基本货币单位是 分.

```php
<?php

use Runner\NezhaCashier\Cashier;

// 按格式组装好配置
$config = [
    'app_id' => 'xxxx',
    'app_private_key' => 'xxxxx',
    'alipay_public_key' => 'xxxxx',
];

// 创建实例, 传入要使用的 Gateway
$cashier = new Cashier('alipay_web', $config);

```

创建付款

```php
<?php
// 组装 ChargeRequestForm
$data = [
    'order_id' => '151627101400000071',
    'subject' => 'testing',
    'amount' => 1,
    'currency' => 'CNY',
    'description' => 'testing description',
    'return_url' => 'https://www.baidu.com',
    'expired_at' => '2018-01-23 19:00:00',
];

$form = $cashier->charge($data);

// 以 laravel 为例
return redirect($form->get('charge_url'));
```

查询支付

```php
<?php

$form = $cashier->query([
    'order_id' => '151627101400000071',
]);

var_dump('paid' === $form->get('status'));
```

接收通知

```php
<?php
$form = $cashier->notify('charge');

var_dump('paid' === $form->get('status'));

var_dump($form->get('trade_sn'));   // 取得第三方交易号
```

退款

```php
<?php

$form = $cashier->refund([
    'order_id' => '151627101400000071',
    'refund_id' => '3151627101400000071',
    'total_amount' => 1,
    'refund_amount' => 1,
]);
```

### 表单及字段说明

#### ChargeRequestForm
| 字段名 | 是否必须 | 字段说明 | 备注 |
| --- | --- | --- | --- |
| order_id | 是 | 订单号 |  |
| subject | 是 | 订单标题 |  |
| amount | 是 | 订单金额 | 注意部分支付渠道有金额上线限制 |
| currency | 是 | 订单货币 | 注意支付渠道支付 |
| description | 是 | 订单简述 | 支付渠道会有不同的长度限制 |
| user_ip | 否 | 用户IP |  |
| return_url | 否 | 回调地址 | web类型的支付渠道必须填 |
| show_url | 否 | 展示地址 |  |
| body | 否 | 订单详细说明 | 这个参数我应该删掉 |
| expired_at | 否 | 过期时间 | unix 时间戳 |
| created_at | 否 | 创建时间 | unix 时间戳, 想不到吧, 连这个鬼都要?? |


其他依旧待补充...

### FAQ

<b>Q</b>: 相比其他的 sdk 优点在哪 ?

<b>A</b>: 无论标榜多优雅多好用的 sdk, 大多都是要求你按照第三方的参数名传入参数, 那就免不了要看文档, 免不了在代码里要做很多处理. 我想要的是, 从数据库里取出订单后, 做一遍处理就能解决接入多种支付.

<b>Q</b>: 是不是就完全不必看第三方支付的文档了 ?

<b>A</b>: 并不是, 我建议还是需要看, 并且组件中某些支付 (例如微信公众号) 是需要传入一些特殊参数的. 组件只是帮你解决烦心的调用问题.

