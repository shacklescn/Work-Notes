# Blackbox Exporter 配置仓库

本仓库提供一组开箱即用的 Blackbox Exporter 模块，用于对 HTTP 端点进行常见断言检查。配置力求简洁、易读、易扩展。

## 内置模块

| 模块名             | 检查内容                                                                 |
|------------------|--------------------------------------------------------------------------|
| http_header_check | 端点返回 HTTP 200 且响应头 `Server` 字段完全等于 `nginx`。               |
| http_body_check   | 端点返回 HTTP 200 且响应体必须包含 JSON 片段 `"status":"UP"`（区分大小写）。 |

## 快速开始

1. 生成认证密钥
```shell
root@localhost:# htpasswd -nBC 10 "" | tr -d ':\n'; echo
New password:  #输入密钥
Re-type new password:  #在输入一次密钥
$2y$12$zsc391M1VMQuEG02FeAqv.kFeIR/wv/Jqr6wN5Y9i12BEciuQnc2i
```
2. 创建basic_auth_users文件
```shell
cat > /apps/blackbox/basic_auth_users.yml <<'EOF'
basic_auth_users:
  admin: $2y$12$zsc391M1VMQuEG02FeAqv.kFeIR/wv/Jqr6wN5Y9i12BEciuQnc2i
EOF
```
- 用户：admin
- 密码：SecA@2025... 

3. 将 `blackbox.yml` 和 `basic_auth_users.yml` 复制到 Blackbox Exporter 的配置目录。  
   docker-compose 示例：

```yaml
services:
  blackbox:
    image: prom/blackbox-exporter
    container_name: blackbox
    ports:
      - "9115:9115"
    volumes:
      - /apps/blackbox/blackbox.yml:/etc/blackbox_exporter/blackbox.yml:ro
      - /apps/blackbox/basic_auth_users.yml:/etc/blackbox_exporter/basic_auth_users.yml:ro
    command:
      - '--config.file=/etc/blackbox_exporter/blackbox.yml'
      - '--web.config.file=/etc/blackbox_exporter/basic_auth_users.yml'
    restart: unless-stopped
```
4. 通过浏览器或 curl 测试模块
```shell
# 使用 http_header_check 模块
curl 'http://localhost:9115/probe?target=https://example.com&module=http_header_check&debug=true'

# 使用 http_body_check 模块
curl 'http://localhost:9115/probe?target=https://example.com/health&module=http_body_check&debug=true'
```
5. Prometheus 集成示例
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          # - alertmanager:9093

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'blackbox'
    basic_auth:
      username:  admin
      password: SecA@2025...
    metrics_path: /probe
    params:
      module: [http_header_check]  # 或 http_body_check
    static_configs:
      - targets:
        - https://example.com
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9115  # blackbox的访问地址
```