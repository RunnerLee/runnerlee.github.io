---
layout: post
title: php 的 es query builder
date: 2020-03-22
update_date: 2020-03-22
summary: 好像没什么卵用..
logo: search
---

先直接贴 GitHub repo: [RunnerLee/esq-builder](https://github.com/runnerlee/esq-builder)

自己在实际项目里面比较少用到 es，没什么深度使用的场景。根据几个遇到的基础使用场景总结，想要解决几个问题：

* 简化查询条件拼接
* 不过度隐藏 dsl 细节
* 满足简单的查询和统计要求

在此之前，想要做一个简单的列表搜索，例如 "商品末级分类+商品名称前缀+创建者/维护者"，在 php 中需要拼装这样非常不直观的数组：

```php
$query = [
    'bool' => [
        'must' => [
            [
                'term' => [
                    'category_id' => 1,
                ],
            ],
            [
                'prefix' => [
                    'goods_name' => 'abc',
                ],
            ],
            [
                'bool' => [
                    'should' => [
                        [
                            'term' => [
                                'create_uid' => 'runnerlee',
                            ],
                        ],
                        [
                            'term' => [
                                'update_uid' => 'runnerlee',
                            ],
                        ]
                    ],
                ],
            ]
        ],
    ],
];
```

在 GitHub 搜轮子搜到这个：https://github.com/ongr-io/ElasticsearchDSL

他的用法是这样的：

```php
$matchAll = new ONGR\ElasticsearchDSL\Query\MatchAllQuery();
$search = new ONGR\ElasticsearchDSL\Search();
$search->addQuery($matchAll);
$params = [
    'index' => 'your_index',
    'body' => $search->toArray(),
];

$results = $client->search($params);
```

结合平常用的 laravel 的 eloquent，我想要能否这样去拼装我的查询:

```php
$query = new QueryBuilder();
$query
    ->term('demo_field', 'demo_value')
    ->prefix('demo_field_2', 'demo_value_2');


// 一开始想过用这种形势
// $query->where('term', 'demo_field', 'demo_value');
// 或者是这种
// $query->whereTerm('demo_field', 'demo_value');
// 但觉得这样在阅读代码理解查询逻辑时不太友善
```

借用 [ongr/elasticsearch-dsl](https://github.com/ongr-io/ElasticsearchDSL) 套一层封装，现在对最上面的例子可以这么处理了：

```php
use Runner\EsqBuilder\QueryBuilder;
use Runner\EsqBuilder\SearchBuilder;

$builder = new SearchBuilder();

$builder->query()
    ->term('category_id', 1)
    ->prefix('goods_name', 'abc')
    ->bool(function (QueryBuilder $query) {
        $query->shouldTerm('create_uid', 'runnerlee')
            ->shouldTerm('update_uid', 'runnerlee');
    });
```

感觉还是清爽的。在 `QueryBuilder` 中，把 `query` 当作是一个大的 `bool`, 你可以直接调用支持的 `clause` 来往 `bool` 里加查询条件，默认的类型为 `must`.

你也可以用 `<boolType><clause>` 来指定 `clause` 的类型。例如 `$query->shouldTerm()` 或是 `$query->mustNotTerm()`. 

嵌套 `bool` 的使用就跟 eloquent 的 `Model::query()` 方法类似了。

整个 `SearchBuilder` 由四个 components 组成：

- QueryBuilder
- AggregationBuilder
- SortBuilder
- HighlightBuilder

给上面的例子加上排序和分页：

```php
$page = min(100, max(1, $_GET['page'] ?? 1));
$perPage = 20;
$builder->setFrom(($page - 1) * $perPage);
$builder->setSize($perPage);
$builder->sort()->fieldSort('id', 'desc');

$response = $builder
    ->setClient(ClientBuilder::create()->build())
    ->serach('your_index');
```

### 参考
- [ongr/elasticsearch-dsl](https://github.com/ongr-io/ElasticsearchDSL)
- [Elasticsearch-PHP](https://www.elastic.co/guide/en/elasticsearch/client/php-api/current/index.html)

