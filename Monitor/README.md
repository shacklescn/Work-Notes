# StarRocks 存算一体监控配置以及Grafana看板
此目录的所有监控文件均依赖于Kube-Prometheus组件
# 食用条件
- 拥有一个可正常运行的Kubernetes集群
- 拥有一个可正常运行的Kube-Prometheus组件
# 食用方法
## 1、克隆项目
```shell
git clone https://github.com/shacklescn/Work-Notes.git
```
## 2、进入Monitor目录
```shell
cd Work-Notes/Monitor/Kube-Prometheus
```
## 3、文件作用说明
```shell
root@master3:~/Work-Notes/Monitor# ll
total 24
drwxr-xr-x 2 root root 4096 Jun 24 13:34 ./
drwxr-xr-x 6 root root 4096 Jun 26 10:20 ../
-rw-r--r-- 1 root root 1250 Jun 24 13:22 all_StarRocks_node_exporter.yaml
-rw-r--r-- 1 root root 2047 Jun 24 13:15 jsj_StarRocks_exporter.yaml
```
| 文件名                  | 文件作用                |
|----------------------|---------------------|
| External_Node_Exporter | 监控k8s集群外部的Node_Exporter |
| StarRocks.yaml    | 监控集群外部的StarRocks    |
## 4、配置文件详解
### Node_Exporter篇
```yaml
apiVersion: v1
kind: Endpoints
metadata:
  labels:
    k8s-app: external-node-exporter
  name: external-node-exporter
  namespace: kubesphere-monitoring-system
subsets:
- addresses:
  - ip: 10.84.0.12
  - ip: 10.84.91.16
  - ip: 10.84.91.18
  - ip: 10.84.0.106
  - ip: 10.84.91.10
  ports:
  - name: metrics
    port: 9100
    protocol: TCP
---
kind: Service
apiVersion: v1
metadata:
  name: external-node-exporter
  namespace: kubesphere-monitoring-system
  labels:
    k8s-app: external-node-exporter
spec:
  ports:
    - name: metrics
      protocol: TCP
      port: 9100
      targetPort: 9100
  type: ClusterIP
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: external-node-exporter
  name: external-node-exporter
  namespace: kubesphere-monitoring-system
spec:
  endpoints:
    - interval: 10s
      path: /metrics
      port: metrics
      scheme: http
      basicAuth:
        username:
          key: username
          name: external-node-exporter-secret
        password:
          key: password
          name: external-node-exporter-secret
  namespaceSelector:
    matchNames:
      - kubesphere-monitoring-system
  selector:
    matchLabels:
      k8s-app: external-node-exporter
---
kind: Secret
apiVersion: v1
metadata:
  name: external-node-exporter-secret
  namespace: kubesphere-monitoring-system
data:
  password: U2VjQUAyMDI1Li4u
  username: YWRtaW4=
type: Opaque
```
Endpoints：在k8s中将外部主机定义为集群资源Endpoints

Service：为Endpoints创建SVC

ServiceMonitor:kube-prometheus提供的CRD,通过定义ServiceMonitor监控对应的SVC,来达到监控需求

Secret:密文存储 访问外部node_exporter所需的用户名和密码

### StarRocks篇
```yaml
kind: Secret
apiVersion: v1
metadata:
  name: starrocks-secret
  namespace: kubesphere-monitoring-system
data:
  password: MjZnYUdIVERaVXBuczdHUg==
  username: cm9vdA==
type: Opaque
---
apiVersion: v1
kind: Endpoints
metadata:
  labels:
    k8s-app: starrocks
  name: starrocks
  namespace: kubesphere-monitoring-system
subsets:
- addresses:
  - ip: 10.84.0.12
  - ip: 10.84.91.16
  - ip: 10.84.91.18
  ports:
  - name: fe-metrics
    port: 8030
    protocol: TCP
  - name: be-metrics
    port: 8040
    protocol: TCP
---
kind: Service
apiVersion: v1
metadata:
  name: starrocks
  namespace: kubesphere-monitoring-system
  labels:
    k8s-app: starrocks
spec:
  ports:
    - name: fe-metrics
      protocol: TCP
      port: 8030
      targetPort: 8030
    - name: be-metrics
      protocol: TCP
      port: 8040
      targetPort: 8040
  type: ClusterIP

---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: starrocks-fe
  name: starrocks-fe
  namespace: kubesphere-monitoring-system
spec:
  endpoints:
    - interval: 10s
      path: /metrics
      port: fe-metrics
      scheme: http
      basicAuth:
        username:
          key: username
          name: starrocks-secret
        password:
          key: password
          name: starrocks-secret
  namespaceSelector:
    matchNames:
      - kubesphere-monitoring-system
  selector:
    matchLabels:
      k8s-app: starrocks
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    k8s-app: starrocks
  name: starrocks-be
  namespace: kubesphere-monitoring-system
spec:
  endpoints:
    - interval: 10s
      path: /metrics
      port: be-metrics
      scheme: http
      basicAuth:
        username:
          key: username
          name: starrocks-secret
        password:
          key: password
          name: starrocks-secret
  namespaceSelector:
    matchNames:
      - kubesphere-monitoring-system
  selector:
    matchLabels:
      k8s-app: starrocks
```
Secret:密文存储 访问外部StarRocks所需的用户名和密码,也就是登录StarRocks的用户名和密码

Endpoints：在k8s中将外部服务定义为集群资源Endpoints

Service：为Endpoints创建SVC

ServiceMonitor:kube-prometheus提供的CRD,通过定义ServiceMonitor监控对应的SVC,来达到监控目的
