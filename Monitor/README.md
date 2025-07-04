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
## 3、目录架构
```shell
root@master3:~/Work-Notes/Monitor/Kube-Prometheus# ll MySQL
total 24
-rw-r--r-- 1 root root 1782 Jun 30 15:57 test-mysql57-master-exporter.yaml
-rw-r--r-- 1 root root  412 Jun 30 15:56 test-mysql57-master-ServiceMonitor.yaml
-rw-r--r-- 1 root root 1791 Jun 30 15:59 test-mysql57-slave01-exporter.yaml
-rw-r--r-- 1 root root  422 Jun 30 16:01 test-mysql57-slave01-ServiceMonitor.yaml
-rw-r--r-- 1 root root 1791 Jun 30 16:09 test-mysql57-slave02-exporter.yaml
-rw-r--r-- 1 root root  422 Jun 30 16:09 test-mysql57-slave02-ServiceMonitor.yaml
-rw-r--r-- 1 root root 1782 Jun 30 16:24 test-mysql80-master-exporter.yaml
-rw-r--r-- 1 root root  412 Jun 30 16:25 test-mysql80-master-ServiceMonitor.yaml
-rw-r--r-- 1 root root 1791 Jun 30 16:27 test-mysql80-slave01-exporter.yaml
-rw-r--r-- 1 root root  422 Jun 30 16:28 test-mysql80-slave01-ServiceMonitor.yaml
-rw-r--r-- 1 root root 1791 Jun 30 16:33 test-mysql80-slave02-exporter.yaml
-rw-r--r-- 1 root root  422 Jun 30 16:34 test-mysql80-slave02-ServiceMonitor.yaml

root@master3:~/Work-Notes/Monitor/Kube-Prometheus# ll Node_Exporter
total 1
-rw-r--r-- 1 root root 1782 Jun 30 15:57 External_Node_Exporter.yaml


root@master3:~/Work-Notes/Monitor/Kube-Prometheus# ll StarRocks
total 1
-rw-r--r-- 1 root root 1782 Jun 30 15:57 External_StarRocks.yaml
```
| 文件名             | 文件作用                              |
|-----------------|-----------------------------------|
| Node_Exporter目录 | 监控k8s集群外部的Node_Exporter           |
| StarRocks目录     | 监控集群外部的StarRocks集群配置文件            |
| MySQL目录         | 监控集群外部的MySQL5.7和MySQL8.0主从信息的配置文件 |
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

### mysqld_exporter篇
mysqld_exporter分为个文件 
- 第一个文件```test-mysql57-master-exporter.yaml```是部署mysqld_exporter Pod用于链接MySQL并暴露指标信息
- 第二个文件```test-mysql57-master-ServiceMonitor.yaml```是kube-prometheus提供的CRD,通过定义ServiceMonitor监控对应的SVC,来达到监控目的

文件名带master的文件是监控MySQL主服务的配置文件，文件中带slave的是监控MySQL从服务的文件
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-mysql57-master-exporter
  namespace: kubesphere-monitoring-system
  labels:
    app: test-mysql57-master-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-mysql57-master-exporter
  template:
    metadata:
      labels:
        app: test-mysql57-master-exporter
    spec:
      restartPolicy: Always
      containers:
        - name: test-mysql57-master-exporter
          image: swr.cn-south-1.myhuaweicloud.com/starsl.cn/mysqld_exporter:latest
          args:
            - "--collect.info_schema.innodb_metrics"
            - "--collect.info_schema.tables"
            - "--collect.info_schema.processlist"
            - "--collect.info_schema.tables.databases=*"
            - "--mysqld.username=root"
            - "--mysqld.address=10.84.3.47:3306"
          env:
            - name: MYSQLD_EXPORTER_PASSWORD
              value: "Seca@2024..."
          ports:
            - containerPort: 9104
              protocol: TCP
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              cpu: 800m
              memory: 128Mi
          volumeMounts:
            - name: tz-config
              mountPath: /etc/localtime
              readOnly: true
      volumes:
        - name: tz-config
          hostPath:
            path: /usr/share/zoneinfo/PRC
            type: File
---
apiVersion: v1
kind: Service
metadata:
  name: test-mysql57-master-exporter
  namespace: kubesphere-monitoring-system
  labels:
    app: test-mysql57-master-exporter
spec:
  selector:
    app: test-mysql57-master-exporter
  ports:
    - name: test-mysql57-master-exporter
      protocol: TCP
      port: 9104
      targetPort: 9104
  type: ClusterIP
```
Deployment：部署mysqld_exporter Pod用于链接MySQL并暴露指标信息
Service：为mysqld_exporter Pod创建服务配置
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: test-mysql57-master-servicemonitor
  namespace: kubesphere-monitoring-system
spec:
  selector:
    matchLabels:
      app: test-mysql57-master-exporter 
  #namespaceSelector:
  #  matchNames:
  #    - kubesphere-monitoring-system
  endpoints:
    - port: test-mysql57-master-exporter
      path: /metrics
      interval: 15s
      scheme: http
```
ServiceMonitor:kube-prometheus提供的CRD,通过定义ServiceMonitor监控对应的SVC,来达到监控目的