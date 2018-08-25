---
layout: post
title: 正则验证中国手机号码
date: 2017-10-12
update_date: 2018-08-25
summary: 只能做到校验号码段
logo: phone
---

手机号码验证是个蛋疼的问题, 根据维基百科的介绍.

> 中国内地手机卡号以 1 开头，共 11 位数，前 7 位数字通常称为手机号段。手机号段类似于地区电话区号，但又不完全相同。2010 年 11 月之前，一般可以从手机号段直接区分城市归属地和运营商。<br> 示例：1XX-YYYY-ZZZZ<br>第 1~3 位数表示电信运营商。<br>第 4~7 位数表示地区号码 (YYYY)。<br>第 8~11 位数表示客户号码 (ZZZZ)。

验证地区号码跟客户号码应该没必要, 我们只要匹配匹配前三位要符合范围就好. 并且我们只需要让 "公众移动通信网网号段" 的号码段通过即可, 不需要支持 "物联网业务专用号段".

范围就不多描述了, 直接上代码吧.

#### 2018-02-22 更新

由于三大运营商都新增加了新的号码段, 对正则做一下更新:
- 中国移动获得 198 作为公众移动通信网网号段
- 中国电信获得 199 作为公众移动通信网网号段
- 中国联通获得 166 作为公众移动通信网网号段

```php
<?php

function verify($phoneNumber)
{
    if (0 === preg_match('/^(13\d|15[012356789]|166|17[01235678]|18\d|19[89])\d{8}$/', $phoneNumber)) {
        return false;
    }
    if ('13800138000' === $phoneNumber || 0 < preg_match('/^(\d)\g{1}{7}$/', substr($phoneNumber, 3))) {
        return false;
    }
    return true;
}

var_dump(verify('13800138000'));
var_dump(verify('13411011211'));
```

### 参考链接
- [https://www.ithome.com/html/it/319951.htm](https://www.ithome.com/html/it/319951.htm)
- [中国内地移动终端通讯号段 - 维基百科](https://zh.wikipedia.org/wiki/%E4%B8%AD%E5%9B%BD%E5%86%85%E5%9C%B0%E7%A7%BB%E5%8A%A8%E7%BB%88%E7%AB%AF%E9%80%9A%E8%AE%AF%E5%8F%B7%E7%A0%81)
