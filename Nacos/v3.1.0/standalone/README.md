# Nacos 集群部署手册（基于 Kubernetes）
## 一、环境准备
### 1. 基础环境
已部署好 Kubernetes 集群（v1.23+）
已配置默认存储类 csi-rbd-sc（RBD / Ceph）
确保节点具备访问互联网的能力（镜像拉取）

### 2. 命名空间
建议使用独立命名空间（例如 nacos-mcp）：
```shell
kubectl create namespace nacos-mcp
```
## 二、部署 MySQL
### 1. 应用 MySQL 资源
```shell
kubectl apply -f ./MySQL/MySQL.yaml -n nacos-mcp
```
YAML 内容:
- 使用 StatefulSet 管理 MySQL 实例
- 存储 10Gi（RBD 存储类）
- 自动创建数据库 nacos
- 用户名：nacos
- 密码：SecA@2025...
### 2. 查看 MySQL 服务端口
```shell
kubectl get svc mysql -n nacos-mcp
```
输出示例：
```shell
NAME     TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
mysql    NodePort   10.233.32.59    <none>        3306:31571/TCP   18h
```
> 说明：
> 
> 3306 为容器内部端口
> 
> 31571 为外部访问端口（NodePort）
### 3. 导入 Nacos 数据库表
#### 1. 下载 Nacos 源码包
因为nacos表在源码包中，所以要先下载源码包
```shell
# 下载nacos 源码
wget https://github.com/alibaba/nacos/releases/download/3.1.0/nacos-server-3.1.0.zip && \
     unzip nacos-server-3.1.0.zip && \
     cd nacos/conf
```
#### 2. 导入 SQL
```shell
mysql -u nacos -p'SecA@2025...' -h <NODE_IP> -P 31571 nacos < mysql-schema.sql
```
> <NODE_IP> 为任意集群节点 IP
> 
> 31571 为上一步获取的 NodePort 端口

#### 3. 验证是否导入成功
```shell
mysql -unacos -p'SecA@2025...' -h <NODE_IP> -P 31571 -e "show tables from nacos;"
```
输出示例：
```shell
mysql: [Warning] Using a password on the command line interface can be insecure.
+----------------------+
| Tables_in_nacos      |
+----------------------+
| config_info          |
| config_info_gray     |
| config_tags_relation |
| group_capacity       |
| his_config_info      |
| permissions          |
| roles                |
| tenant_capacity      |
| tenant_info          |
| users                |
+----------------------+
```
## 三、部署 Nacos
### 1. 应用 Nacos 资源
```shell
kubectl apply -f ./Nacos/Nacos.yaml -n nacos-mcp
```
YAML 内容：
- 镜像：nacos/nacos-server:v3.1.0
- 运行模式：standalone
- 启用 MySQL 外部数据源
- 存储卷：50Gi
- 含健康检查（liveness/readiness）
### 2. 查看启动日志
```shell
kubectl logs -f statefulset/nacos -n nacos-mcp
```
输出示例：
```shell
2025-10-15 10:21:07,230 INFO Nacos Server API is starting...

2025-10-15 10:21:07,237 INFO Tomcat initialized with port 8848 (http)

2025-10-15 10:21:07,335 INFO Root WebApplicationContext: initialization completed in 2103 ms

2025-10-15 10:21:07,740 INFO Adding welcome page: class path resource [static/index.html]

2025-10-15 10:21:08,306 INFO Nacos Server API is starting...

2025-10-15 10:21:08,340 INFO Exposing 1 endpoint beneath base path '/actuator'

2025-10-15 10:21:08,424 INFO Tomcat started on port 8848 (http) with context path '/nacos'

2025-10-15 10:21:08,432 INFO Nacos Server API started successfully in 3296 ms


         ,--.
       ,--.'|
   ,--,:  : |                                           Nacos Console 3.1.0
,`--.'`|  ' :                       ,---.               Running in stand alone mode, All function modules
|   :  :  | |                      '   ,'\   .--.--.    Port: 8080
:   |   \ | :  ,--.--.     ,---.  /   /   | /  /    '   Pid: 1
|   : '  '; | /       \   /     \.   ; ,. :|  :  /`./   Console: http://10.233.105.16:8080/index.html
'   ' ;.    ;.--.  .-. | /    / ''   | |: :|  :  ;_
|   | | \   | \__\/: . ..    ' / '   | .; : \  \    `.      https://nacos.io
'   : |  ; .' ," .--.; |'   ; :__|   :    |  `----.   \
|   | '`--'  /  /  ,.  |'   | '.'|\   \  /  /  /`--'  /
'   : |     ;  :   .'   \   :    : `----'  '--'.     /
;   |.'     |  ,     .-./\   \  /            `--'---'
'---'        `--`---'     `----'

2025-10-15 10:21:09,146 WARN Bean 'nacosConsoleBeanPostProcessorConfiguration' of type [com.alibaba.nacos.console.config.NacosConsoleBeanPostProcessorConfiguration$$SpringCGLIB$$0] is not eligible for getting processed by all BeanPostProcessors (for example: not eligible for auto-proxying). The currently created BeanPostProcessor [nacosDuplicateSpringBeanPostProcessor] is declared through a non-static factory method on that class; consider declaring it as static instead.

2025-10-15 10:21:09,230 INFO Tomcat initialized with port 8080 (http)

2025-10-15 10:21:09,232 INFO Root WebApplicationContext: initialization completed in 705 ms

2025-10-15 10:21:09,421 INFO Adding welcome page: class path resource [static/index.html]

2025-10-15 10:21:09,525 INFO Nacos Console is starting...

2025-10-15 10:21:09,642 INFO Exposing 1 endpoint beneath base path '/actuator'

2025-10-15 10:21:09,719 INFO Tomcat started on port 8080 (http) with context path '/'

2025-10-15 10:21:09,726 INFO Nacos Console started successfully in 1287 ms

2025-10-15 10:21:20,693 INFO Initializing Servlet 'dispatcherServlet'

2025-10-15 10:21:20,695 INFO Completed initialization in 2 ms
```
### 3. 验证服务
查看 Nacos 对外端口：
```shell
kubectl get svc nacos -n nacos-mcp
```
输出示例：
```shell
NAME    TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)                                        AGE
nacos   NodePort   10.233.50.46   <none>        8848:31978/TCP,9848:31694/TCP,8080:30688/TCP   17h
```
访问控制台：http://<NODE_IP>:30688