---
layout: post
title: 替换 laravel 第三方扩展包的模板
category: 技术
tags: laravel template service provider
description: 替换 laravel 第三方扩展包的模板
author: RunnerLee
---

用 [laravel-admin](laravel-admin.org) 做了后台, 然后因为同事说想替换这个扩展包提供的模板, 他的做法是声明一个新的 class 继承后覆盖父类中使用的模板名.

有没有其他的方法呢 ?

laravel-admin 的模板, 使用的命名空间是 `admin`, laravel-admin 是通过 `Illuminate\Support\ServiceProvider::loadViewsFrom()` 来注册模板命名空间的:

*Illuminate\Support\ServiceProvider*
```
abstract class ServiceProvider
{
    protected function loadViewsFrom($path, $namespace)
    {
        if (is_array($this->app->config['view']['paths'])) {
            foreach ($this->app->config['view']['paths'] as $viewPath) {
                if (is_dir($appPath = $viewPath.'/vendor/'.$namespace)) {
                    $this->app['view']->addNamespace($namespace, $appPath);
                }
            }
        }

        $this->app['view']->addNamespace($namespace, $path);
    }
}
```

再看下注册命名空间跟获取模板

*Illuminate\View\Factory*
```
class Factory implements FactoryContract
{
    public function make($view, $data = [], $mergeData = [])
    {
        $path = $this->finder->find(
            $view = $this->normalizeName($view)
        );
        $data = array_merge($mergeData, $this->parseData($data));
        return tap($this->viewInstance($view, $path, $data), function ($view) {
            $this->callCreator($view);
        });
    }
    
    public function addNamespace($namespace, $hints)
    {
        $this->finder->addNamespace($namespace, $hints);

        return $this;
    }
}
```

再查看 finder
*Illuminate\View\FileViewFinder*
```
<?php
class FileViewFinder implements ViewFinderInterface
{
    public function find($name)
    {
        if (isset($this->views[$name])) {
            return $this->views[$name];
        }
        if ($this->hasHintInformation($name = trim($name))) {
            return $this->views[$name] = $this->findNamespacedView($name);
        }
        return $this->views[$name] = $this->findInPaths($name, $this->paths);
    }

    protected function findNamespacedView($name)
    {
        list($namespace, $view) = $this->parseNamespaceSegments($name);
        return $this->findInPaths($view, $this->hints[$namespace]);
    }
	
	protected function findInPaths($name, $paths)
    {
        foreach ((array) $paths as $path) {
            foreach ($this->getPossibleViewFiles($name) as $file) {
                if ($this->files->exists($viewPath = $path.'/'.$file)) {
                    return $viewPath;
                }
            }
        }

        throw new InvalidArgumentException("View [$name] not found.");
    }

    public function addNamespace($namespace, $hints)
    {
        $hints = (array) $hints;

        if (isset($this->hints[$namespace])) {
            $hints = array_merge($this->hints[$namespace], $hints);
        }

        $this->hints[$namespace] = $hints;
    }
}
```

也就是, 如果是有命名空间的话, 会从 `Illuminate\View\FileViewFinder::$hints` 中拿到命名空间映射的目录, 从目录中查找模板文件. 一个命名空间可以映射多个目录.

当调用服务提供者提供的注册命名空间模板的时候, 会默认先以命名空间为目录名到 `resource/vendor/{$namespace}` 注册映射目录, 而因为最终在 `FileViewFinder::addNamespace()` 中以 `array_merge` 去合并映射目录, 所以是先注册的优先查找.

所以, 有两种方法去实现覆盖扩展包的模板:

### 方法一

在 `resource/vendor/{$namespace}` 创建一个同名模板文件.

### 方法二

在 `App\Providers\AppServiceProvider::boot()` 中, 以相同的 `namespace` 注册一个映射目录, 然后在该映射目录下创建一个同名的模板文件.

然后把 `AppServiceProvider` 在扩展包的提供者之前注册就好了.

需要注意, laravel 5.5 提供的自动发现, 如果扩展包使用了自动发现, 那这个扩展包会比 `config/app.php` 中配置的服务提供者先注册启动, 例如 `laravel-admin`.

所以如果使用这个方法, 则需要在 `composer.json` 中关闭扩展包的自动发现.