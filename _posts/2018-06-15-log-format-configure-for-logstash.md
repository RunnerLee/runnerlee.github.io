---
layout: post
title: 配置 Nginx Access Log 及 Logstash 采集
date: 2018-06-15
update_date: 2018-06-15
summary: ELK 踩坑系列
logo: file
---

首先需要配置 nginx 的 access log.

> 区分 SLB 及 非 SLB 部署, SLB 部署时, 需要将 `client_ip` 设置为 `$http_x_forwarded_for`. 非 SLB 时, 设置为 `$remote_addr`.

```
log_format access '{"@timestamp":"$time_iso8601",'
                        '"@source":"$server_addr",'
                        '"hostname":"$hostname",'
                        '"client_ip":"$http_x_forwarded_for",'
                        '"client":"$remote_addr",'
                        '"request_method":"$request_method",'
                        '"scheme":"$scheme",'
                        '"domain":"$server_name",'
                        '"referer":"$http_referer",'
                        '"request":"$request_uri",'
                        '"args":"$args",'
                        '"body":"$request_body",'
                        '"size":$body_bytes_sent,'
                        '"status": $status,'
                        '"responsetime":$request_time,'
                        '"upstreamtime":"$upstream_response_time",'
                        '"upstreamaddr":"$upstream_addr",'
                        '"http_user_agent":"$http_user_agent",'
                        '"https":"$https"'
                        '}';
```

由于 nginx 的 `request_body` 有可能包含特殊的十六进制字符(类似于\xE0), 造成无法正常解析 json.

解决的办法之一是升级 Nginx 版本到至少 1.11.8, 利用 Log Format 的新参数 `escape` 来解决这个问题.

这样能直接 通过 设置 file input 的 `codec` 为 `json` 来完成读取解析, 或是直接使用 filebeat 提交至 elasticsearch.

如果无法升级, 就不能直接在 file input 中设置 `codec` 为 `json`, 那需要在读取出来后, 进行一些替换, 再解析 json.

> 区别于5.0 之前的版本, 在 5.0 之后的 Logstash, 都无法按照网上所说的直接用 `event["message"]`, 而是要通过 `event.get` 的 api 进行操作. 替换十六进制字符的 ruby 代码:

```ruby

if event.get('message').include?('\x') then
    event.set('message', event.get('message').gsub(/\\x([0-9A-F]{2})/) {
        case $1
            when '22'
                '\\"'
            when '0D'
                '\\r'
            when '0A'
                '\\n'
            when '27'
                '\\\''
            when '5C'
                '\\\\'
            else
                $1.hex.chr
        end
    })
end
```

同时, 如果是 SLB 部署, 需要截取到用户的 IP, 另存为 `ip` 的字段, 并删除 `client_ip`.

完整的配置

```
input {
	file {
		path => ["path/to/log/file.log"]
		ignore_older => 0
	}
}
filter {
	ruby {
		code => "if event.get('message').include?('\x') then
    event.set('message', event.get('message').gsub(/\\x([0-9A-F]{2})/) {
        case $1
            when '22'
                '\\"'
            when '0D'
                '\\r'
            when '0A'
                '\\n'
            when '27'
                '\\\''
            when '5C'
                '\\\\'
            else
                $1.hex.chr
        end
    })
end"
	}
	json {
		source => "message"
	}
	mutate {
		convert => [ "status","integer" ]
		convert => [ "size","integer" ]
		convert => [ "upstreatime","float" ]
		split   => ["x_forward_ip", ","]
		add_field => ["ip", "%{[x_forward_ip][0]}"]
		remove_field => ["x_forward_ip"]
		remove_field => "message"
	}
	geoip {
		source => "ip"
	}
}
output {
#	elasticsearch {
#		hosts => "127.0.0.1:9200"
#		index => "logstash-nginx-access-%{+YYYY.MM.dd}"
#	}
	stdout {
		codec => rubydebug
	}
}
```

### 参考
- [https://grafana.com/dashboards/2292](https://grafana.com/dashboards/2292)
- [https://nginx.org/en/docs/http/ngx_http_log_module.html#log_format](https://nginx.org/en/docs/http/ngx_http_log_module.html#log_format)
