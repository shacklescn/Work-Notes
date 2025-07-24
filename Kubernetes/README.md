# Kubernetes 日常运维手册
```shell

```

# FQA
## 1、节点根目录可用空间不足
### 根因
Docker overlay2 目录占用磁盘容量过多，导致磁盘空间告警。
### 解决方法
| 步骤          | 操作命令/说明                                                                                                                                                 | 输出/结果                            |
| ----------- |---------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------|
| ① 定位高占用目录   | `du -h --max-depth=1 /var/lib/docker/overlay2 \| sort -h`                                                                                               | 确认是哪个目录占用磁盘多                     |              
| ② 关联容器/Pod  | `docker inspect $(docker ps -aq) \| grep -A 10 目录ID`                                                                                                    | 根据overlay2 层唯一哈希值 找出 Pod UID和容器名 |
| ③ 获取 Pod 信息 | `kubectl get pods --all-namespaces -o json \| jq -r '.items[] \| select(.metadata.uid == "UUID") \| .metadata.namespace + "/" + .metadata.name'` | 定位是哪个命名空间的Pod                    |
### 示例
```shell
# 定位磁盘占用最高的 overlay2 目录
root@node3:~ du -h --max-depth=1 /var/lib/docker/overlay2 | sort -h
---------------------------省略--------------------------------
102G	/var/lib/docker/overlay2/04c487f80bd18b17aaec661f7a48226a54349a3de2528372ab93bc20f1637c22
281G	/var/lib/docker/overlay2

# 根据overlay2 层唯一哈希值 找出 Pod UID和容器名
root@node3:~# docker inspect $(docker ps -aq) | grep -A 10 "04c487f80bd18b17aaec661f7a48226a54349a3de2528372ab"
                "LowerDir": "/var/lib/docker/overlay2/04c487f80bd18b17aaec661f7a48226a54349a3de2528372ab93bc20f1637c22-init/diff:/var/lib/docker/overlay2/fe5edf93e25c4940da9c73f79df07b1fb157427400dc10e5c9286cbcac917ec6/diff:/var/lib/docker/overlay2/7bd99349fda9d80b48e123550606f2a12cbc952a5e0cac1935cda8471566c848/diff:/var/lib/docker/overlay2/0c4430d78428e94fdca3ba3bed5fd83e9e10afb2c98ae1f97174d677a6841502/diff:/var/lib/docker/overlay2/b752a2a097ed367bdaa11f04dfeba3fbf3078e0fd6e517bedf2daf5515655f0f/diff:/var/lib/docker/overlay2/efcb8b3eac76e679c7589b32c747b05fe0bda2fbb15e9ddc2e3f58077ae1bed6/diff:/var/lib/docker/overlay2/816b491574d6ef8c64df1a6f87819b5b84f36b6a8c5342eeb7e69ecce5342f31/diff",
                "MergedDir": "/var/lib/docker/overlay2/04c487f80bd18b17aaec661f7a48226a54349a3de2528372ab93bc20f1637c22/merged",
                "UpperDir": "/var/lib/docker/overlay2/04c487f80bd18b17aaec661f7a48226a54349a3de2528372ab93bc20f1637c22/diff",
                "WorkDir": "/var/lib/docker/overlay2/04c487f80bd18b17aaec661f7a48226a54349a3de2528372ab93bc20f1637c22/work"
            },
            "Name": "overlay2"
        },
        "Mounts": [
            {
                "Type": "bind",
                "Source": "/var/lib/kubelet/pods/eeecc784-948c-45d8-bc3d-cd31e290fb6e/containers/container-dg6tf2/185e057c",
                "Destination": "/dev/termination-log",
                "Mode": "",
                "RW": true,

# 根据UUID（eeecc784-948c-45d8-bc3d-cd31e290fb6e） 到master机器上查询是哪个命名空间的Pod
root@master3:~# kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.metadata.uid == "eeecc784-948c-45d8-bc3d-cd31e290fb6e") | .metadata.namespace + "/" + .metadata.name'
heat-storage/storage-back-64c4b95766-2x5kx
```

## 2、Kubernetes v1.24+ 创建ServiceAccount未生成Secret问题
### 前提条件
- Kubernetes的版本是v1.24+
- 拥有一个可以正常使用的kubesphere
#### 解决方法
##### 1. 在指定namespace创建账户：
```shell
kubectl create serviceaccount material-horizon-dev -n  material-horizon-dev
```
##### 2. 创建role规则(kubesphere内置创建的有，可不操作)

创建完namespace并将namespace分配给企业空间后，默认会添加以下三条role规则
```shell
root@master01:~# kubectl get role -n material-horizon-dev
NAME                      CREATED AT
kubesphere:iam:admin      2025-07-23T07:11:01Z
kubesphere:iam:operator   2025-07-23T07:11:01Z
kubesphere:iam:viewer     2025-07-23T07:11:01Z
```
##### 3. 将规则与账户进行绑定
```shell
kubectl create rolebinding material-horizon-dev-operator-binding \
  --role=kubesphere:iam:operator \
  --serviceaccount=material-horizon-dev:material-horizon-dev \
  -n material-horizon-dev
```
##### 4. 创建Secret
```shell
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: material-horizon-dev-token
  namespace: material-horizon-dev
  annotations:
    kubernetes.io/service-account.name: material-horizon-dev
type: kubernetes.io/service-account-token
EOF
```
##### 5. 生成kubeconfig
```shell
# 变量准备
#!/bin/bash

set -e

SA_NAME="material-horizon-dev"
NAMESPACE="material-horizon-dev"
OUTPUT_FILE="${SA_NAME}.kubeconfig"

# 动态获取 kubernetes Service 的 ClusterIP 和端口
CLUSTER_IP=$(kubectl -n default get svc kubernetes -o jsonpath='{.spec.clusterIP}')
SERVER="https://${CLUSTER_IP}:443"

# 获取当前 kubeconfig 中的集群名（仅用于命名）
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')

# 获取 token 与 CA
TOKEN=$(kubectl get secret "${SA_NAME}-token" -n "${NAMESPACE}" -o jsonpath='{.data.token}' | base64 -d)
CA_CRT=$(kubectl get secret "${SA_NAME}-token" -n "${NAMESPACE}" -o jsonpath='{.data.ca\.crt}')

# 生成 kubeconfig
cat <<EOF > "${OUTPUT_FILE}"
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CA_CRT}
    server: ${SERVER}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${SA_NAME}
    namespace: ${NAMESPACE}
  name: ${SA_NAME}@${CLUSTER_NAME}
current-context: ${SA_NAME}@${CLUSTER_NAME}
users:
- name: ${SA_NAME}
  user:
    token: ${TOKEN}
EOF

echo "✅ kubeconfig 已生成：$(realpath ${OUTPUT_FILE})"
```