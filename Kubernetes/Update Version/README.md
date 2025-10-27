# Kubernetes 升级手册
## 基于kubekey升级
### 前提条件
- 有一个Kubernetes集群 Version v1.23.10并且能够正常工作的
- runtime是docker
- cni是calico
### 升级 Kubernetes
#### 升级至v1.24.17
```shell
export KKZONE=cn

./kk upgrade \
--with-kubernetes v1.24.17 \
--with-kubesphere v3.4.1 \
-f config-sample.yaml \
--skip-dependency-check
```
#### 升级至v1.25.16
```shell
export KKZONE=cn

./kk upgrade \
--with-kubernetes v1.25.16 \
--with-kubesphere v3.4.1 \
-f config-sample.yaml \
--skip-dependency-check
```
##### 出现升级失败，报错日志
```shell
07:03:56 UTC message: [master01]
downloading image: registry.cn-beijing.aliyuncs.com/kubesphereio/node:v3.27.4
07:03:57 UTC message: [master01]
downloading image: registry.cn-beijing.aliyuncs.com/kubesphereio/pod2daemon-flexvol:v3.27.4
07:03:58 UTC success: [node02]
07:03:58 UTC success: [node01]
07:03:58 UTC success: [master01]
07:03:58 UTC [ProgressiveUpgradeModule 1/2] Synchronize kubernetes binaries
07:04:11 UTC success: [master01]
07:04:11 UTC success: [node01]
07:04:11 UTC success: [node02]
07:04:11 UTC [ProgressiveUpgradeModule 1/2] Upgrade cluster on master
v1.25.16
07:09:16 UTC message: [master01]
upgrade master failed: master01: Failed to exec command: sudo -E /bin/bash -c "timeout -k 600s 600s /usr/local/bin/kubeadm upgrade apply v1.25.16 -y --ignore-preflight-errors=all --allow-experimental-upgrades --allow-release-candidate-upgrades --etcd-upgrade=false --certificate-renewal=true " 
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
W0725 07:04:11.451608   17566 utils.go:69] The recommended value for "clusterDNS" in "KubeletConfiguration" is: [10.233.0.10]; the provided value is: [169.254.25.10]
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.25.16"
[upgrade/versions] Cluster version: v1.24.17
[upgrade/versions] kubeadm version: v1.25.16
[upgrade/prepull] Pulling images required for setting up a Kubernetes cluster
[upgrade/prepull] This might take a minute or two, depending on the speed of your internet connection
[upgrade/prepull] You can also perform this action in beforehand using 'kubeadm config images pull'
[upgrade/apply] Upgrading your Static Pod-hosted control plane to version "v1.25.16" (timeout: 5m0s)...
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests3080113658"
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Renewing apiserver certificate
[upgrade/staticpods] Renewing apiserver-kubelet-client certificate
[upgrade/staticpods] Renewing front-proxy-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-07-25-07-04-15/kube-apiserver.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[upgrade/apply] FATAL: couldn't upgrade control plane. kubeadm has tried to recover everything into the earlier state. Errors faced: failed to obtain static Pod hash for component kube-apiserver on Node master01: Get "https://lb.kubesphere.local:6443/api/v1/namespaces/kube-system/pods/kube-apiserver-master01?timeout=10s": dial tcp 10.84.3.125:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher: Process exited with status 1
07:09:16 UTC retry: [master01]
v1.25.16
07:09:21 UTC message: [master01]
upgrade master failed: master01: Failed to exec command: sudo -E /bin/bash -c "timeout -k 600s 600s /usr/local/bin/kubeadm upgrade apply v1.25.16 -y --ignore-preflight-errors=all --allow-experimental-upgrades --allow-release-candidate-upgrades --etcd-upgrade=false --certificate-renewal=true " 
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[upgrade/config] FATAL: failed to get config map: Get "https://lb.kubesphere.local:6443/api/v1/namespaces/kube-system/configmaps/kubeadm-config?timeout=10s": dial tcp 10.84.3.125:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher: Process exited with status 1
07:09:21 UTC retry: [master01]
v1.25.16
07:09:27 UTC message: [master01]
upgrade master failed: master01: Failed to exec command: sudo -E /bin/bash -c "timeout -k 600s 600s /usr/local/bin/kubeadm upgrade apply v1.25.16 -y --ignore-preflight-errors=all --allow-experimental-upgrades --allow-release-candidate-upgrades --etcd-upgrade=false --certificate-renewal=true " 
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[upgrade/config] FATAL: failed to get config map: Get "https://lb.kubesphere.local:6443/api/v1/namespaces/kube-system/configmaps/kubeadm-config?timeout=10s": dial tcp 10.84.3.125:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher: Process exited with status 1
07:09:27 UTC message: [master01]
upgrade cluster using kubeadm failed: master01: 
failed: [master01] [KubeadmUpgrade] exec failed after 3 retries: upgrade master failed: master01: Failed to exec command: sudo -E /bin/bash -c "timeout -k 600s 600s /usr/local/bin/kubeadm upgrade apply v1.25.16 -y --ignore-preflight-errors=all --allow-experimental-upgrades --allow-release-candidate-upgrades --etcd-upgrade=false --certificate-renewal=true " 
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[upgrade/config] FATAL: failed to get config map: Get "https://lb.kubesphere.local:6443/api/v1/namespaces/kube-system/configmaps/kubeadm-config?timeout=10s": dial tcp 10.84.3.125:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher: Process exited with status 1
07:09:27 UTC retry: [master01]
v1.25.16
07:14:48 UTC message: [master01]
upgrade master failed: master01: Failed to exec command: sudo -E /bin/bash -c "timeout -k 600s 600s /usr/local/bin/kubeadm upgrade apply v1.25.16 -y --ignore-preflight-errors=all --allow-experimental-upgrades --allow-release-candidate-upgrades --etcd-upgrade=false --certificate-renewal=true " 
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
W0725 07:09:32.276558   23763 utils.go:69] The recommended value for "clusterDNS" in "KubeletConfiguration" is: [10.233.0.10]; the provided value is: [169.254.25.10]
[preflight] Running pre-flight checks.
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.25.16"
[upgrade/versions] Cluster version: v1.24.17
[upgrade/versions] kubeadm version: v1.25.16
[upgrade/prepull] Pulling images required for setting up a Kubernetes cluster
[upgrade/prepull] This might take a minute or two, depending on the speed of your internet connection
[upgrade/prepull] You can also perform this action in beforehand using 'kubeadm config images pull'
[upgrade/apply] Upgrading your Static Pod-hosted control plane to version "v1.25.16" (timeout: 5m0s)...
[upgrade/staticpods] Writing new Static Pod manifests to "/etc/kubernetes/tmp/kubeadm-upgraded-manifests1586506154"
[upgrade/staticpods] Preparing for "kube-apiserver" upgrade
[upgrade/staticpods] Renewing apiserver certificate
[upgrade/staticpods] Renewing apiserver-kubelet-client certificate
[upgrade/staticpods] Renewing front-proxy-client certificate
[upgrade/staticpods] Moved new manifest to "/etc/kubernetes/manifests/kube-apiserver.yaml" and backed up old manifest to "/etc/kubernetes/tmp/kubeadm-backup-manifests-2025-07-25-07-09-47/kube-apiserver.yaml"
[upgrade/staticpods] Waiting for the kubelet to restart the component
[upgrade/staticpods] This might take a minute or longer depending on the component/version gap (timeout 5m0s)
[upgrade/apply] FATAL: couldn't upgrade control plane. kubeadm has tried to recover everything into the earlier state. Errors faced: failed to obtain static Pod hash for component kube-apiserver on Node master01: Get "https://lb.kubesphere.local:6443/api/v1/namespaces/kube-system/pods/kube-apiserver-master01?timeout=10s": dial tcp 10.84.3.125:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher: Process exited with status 1
07:14:48 UTC retry: [master01]
v1.25.16
07:14:53 UTC message: [master01]
upgrade master failed: master01: Failed to exec command: sudo -E /bin/bash -c "timeout -k 600s 600s /usr/local/bin/kubeadm upgrade apply v1.25.16 -y --ignore-preflight-errors=all --allow-experimental-upgrades --allow-release-candidate-upgrades --etcd-upgrade=false --certificate-renewal=true " 
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[upgrade/config] FATAL: failed to get config map: Get "https://lb.kubesphere.local:6443/api/v1/namespaces/kube-system/configmaps/kubeadm-config?timeout=10s": dial tcp 10.84.3.125:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher: Process exited with status 1
07:14:53 UTC retry: [master01]
v1.25.16
07:14:59 UTC message: [master01]
upgrade master failed: master01: Failed to exec command: sudo -E /bin/bash -c "timeout -k 600s 600s /usr/local/bin/kubeadm upgrade apply v1.25.16 -y --ignore-preflight-errors=all --allow-experimental-upgrades --allow-release-candidate-upgrades --etcd-upgrade=false --certificate-renewal=true " 
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[upgrade/config] FATAL: failed to get config map: Get "https://lb.kubesphere.local:6443/api/v1/namespaces/kube-system/configmaps/kubeadm-config?timeout=10s": dial tcp 10.84.3.125:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher: Process exited with status 1
07:14:59 UTC message: [master01]
upgrade cluster using kubeadm failed: master01: 
failed: [master01] [KubeadmUpgrade] exec failed after 3 retries: upgrade master failed: master01: Failed to exec command: sudo -E /bin/bash -c "timeout -k 600s 600s /usr/local/bin/kubeadm upgrade apply v1.25.16 -y --ignore-preflight-errors=all --allow-experimental-upgrades --allow-release-candidate-upgrades --etcd-upgrade=false --certificate-renewal=true " 
[upgrade/config] Making sure the configuration is correct:
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[upgrade/config] FATAL: failed to get config map: Get "https://lb.kubesphere.local:6443/api/v1/namespaces/kube-system/configmaps/kubeadm-config?timeout=10s": dial tcp 10.84.3.125:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher: Process exited with status 1
```
##### 解决办法
###### 1. 查看kube-apiserver容器日志
```shell
root@master01:~# docker logs 22df6a5acde9
Error: invalid argument "TTLAfterFinished=true,RotateKubeletServerCertificate=true" for "--feature-gates" flag: unrecognized feature gate: TTLAfterFinished
```
原因是Kubernetes v1.25 移除了 TTLAfterFinished 这个已弃用的 Feature Gate。
集群在 v1.24 时启用了 TTLAfterFinished=true，但在升级到 v1.25 时，kube-apiserver 启动会因这个无效的参数而直接失败，导致：kube-apiserver 容器无法启动、6443 端口无服务监听
###### 2. 修复步骤
1. 恢复旧的 kube-apiserver 以恢复集群访问
```shell
# 找到 kubeadm 备份的旧静态 Pod 文件
ls /etc/kubernetes/tmp/kubeadm-backup-manifests-*

# 恢复旧的 kube-apiserver.yaml（替换当前可能损坏的配置）
cp /etc/kubernetes/tmp/kubeadm-backup-manifests-*/kube-apiserver.yaml /etc/kubernetes/manifests/

# 等待几秒，旧的 kube-apiserver 会重启
docker ps | grep kube-apiserver
```
2. 编辑 kubeadm-config ConfigMap，移除 TTLAfterFinished
```shell
kubectl -n kube-system edit cm kubeadm-config
```
修改三处 feature-gates
```shell
apiServer:
  extraArgs:
    feature-gates: RotateKubeletServerCertificate=true  # 移除 TTLAfterFinished

controllerManager:
  extraArgs:
    feature-gates: RotateKubeletServerCertificate=true  # 移除 TTLAfterFinished

scheduler:
  extraArgs:
    feature-gates: RotateKubeletServerCertificate=true  # 移除 TTLAfterFinished
```
3. 删除各节点kubelet文件TTLAfterFinished配置
```shell
sudo sed -i '/TTLAfterFinished/d' /var/lib/kubelet/config.yaml
```
#### 升级至v1.26.15
```shell
export KKZONE=cn
./kk upgrade \
--with-kubernetes v1.26.15 \
-f config-sample.yaml \
--skip-dependency-check
```
删除各节点kubelet文件TTLAfterFinished配置
```shell
sudo sed -i '/TTLAfterFinished/d' /var/lib/kubelet/config.yaml
```
#### 升级至v1.27.16
```shell
export KKZONE=cn
./kk upgrade \
--with-kubernetes v1.27.16 \
-f config-sample.yaml \
--skip-dependency-check
```
#### 升级至v1.28.15
```shell
export KKZONE=cn
./kk upgrade \
--with-kubernetes v1.28.15 \
-f config-sample.yaml \
--skip-dependency-check
```
删除各节点kubelet文件TTLAfterFinished配置
```shell
sudo sed -i '/TTLAfterFinished/d' /var/lib/kubelet/config.yaml
```
#### 升级至v1.29.15
```shell
export KKZONE=cn
./kk upgrade \
--with-kubernetes v1.29.15 \
-f config-sample.yaml \
--skip-dependency-check
```
删除各节点kubelet文件TTLAfterFinished配置
```shell
sudo sed -i '/TTLAfterFinished/d' /var/lib/kubelet/config.yaml
```
#### 升级至v1.30.13
```shell
export KKZONE=cn
./kk upgrade \
--with-kubernetes v1.30.13 \
-f config-sample.yaml \
--skip-dependency-check
```
删除各节点kubelet文件TTLAfterFinished配置
```shell
sudo sed -i '/TTLAfterFinished/d' /var/lib/kubelet/config.yaml
```
#### 升级至v1.31.9
```shell
export KKZONE=cn
./kk upgrade \
--with-kubernetes v1.31.9 \
-f config-sample.yaml \
--skip-dependency-check
```
删除各节点kubelet文件TTLAfterFinished配置
```shell
sudo sed -i '/TTLAfterFinished/d' /var/lib/kubelet/config.yaml
```
##### 报错
```shell
07:59:19 UTC message: [master01]
upgrade master failed: master01: Failed to exec command: sudo -E /bin/bash -c "timeout -k 600s 600s /usr/local/bin/kubeadm upgrade apply v1.31.9 -y --ignore-preflight-errors=all --allow-experimental-upgrades --allow-release-candidate-upgrades --etcd-upgrade=false --certificate-renewal=true " 
[preflight] Running pre-flight checks.
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
W0729 07:59:15.625351   26650 utils.go:69] The recommended value for "clusterDNS" in "KubeletConfiguration" is: [10.233.0.10]; the provided value is: [169.254.25.10]
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.31.9"
[upgrade/versions] Cluster version: v1.30.13
[upgrade/versions] kubeadm version: v1.31.9
[upgrade/prepull] Pulling images required for setting up a Kubernetes cluster
[upgrade/prepull] This might take a minute or two, depending on the speed of your internet connection
[upgrade/prepull] You can also perform this action beforehand using 'kubeadm config images pull'
[preflight] Some fatal errors occurred:
failed to create new CRI runtime service: validate service connection: validate CRI v1 runtime API for endpoint "unix:///var/run/dockershim.sock": rpc error: code = Unavailable desc = connection error: desc = "transport: Error while dialing: dial unix /var/run/dockershim.sock: connect: connection refused"[preflight] If you know what you are doing, you can make a check non-fatal with --ignore-preflight-errors=...
To see the stack trace of this error execute with --v=5 or higher: Process exited with status 2
07:59:19 UTC retry: [master01]
```
######  解决办法:
在master 节点上执行下列指令
```shell
# 确保cri-dockerd是否在正常运行
systemctl status cri-docker.service 


# 建立一个软链接，让 kubeadm 能正确连接
ln -sf /var/run/cri-dockerd.sock /var/run/dockershim.sock

# 重新执行升级指令
./kk upgrade --with-kubernetes v1.31.9 -f config-sample.yaml --skip-dependency-check
```
