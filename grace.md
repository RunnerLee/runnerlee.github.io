---
layout: page
title: Grace And Runnerlee
permalink: /grace/
---

```php
<?php

$sweetLife = new SweetLift(
    $runnerlee = new Male('runnerlee'),
    $grace = new Female('grace')
);

$sweetLife->bootstrap();

try {
    $sweetLife->run();

    // TODO
    // $sweetLife->haveABaby();
} catch (Exception $e) {
    $runnerlee->apologize($e);
}


```
