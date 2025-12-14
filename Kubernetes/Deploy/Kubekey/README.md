# 基于kubekey 的kubernetes v1.20.10的部署手册
## 1. 下载kubekey（默认最新版）
```shell
curl -sfL https://get-kk.kubesphere.io | sh -
```
## 2. 创建 manifests 文件
```shell
./kk create manifest --with-kubernetes v1.20.10  --with-registry "docker registry"
```
参数说明：
> --with-kubernetes： 指定 k8s 版本
> 
> --with-registry：使用 docker 作为镜像仓库
## 3. 制作制品
根据生成的 manifest，执行下面的命令制作制品（artifact）。
```shell
export KKZONE=cn
./kk artifact export -m manifest-sample.yaml -o kubernetes-12010-artifact.tar.gz
```
预期结果：
```shell
root@base-os:~# ./kk artifact export -m manifest-sample.yaml -o kubernetes-1.20.10-artifact.tar.gz


 _   __      _          _   __           
| | / /     | |        | | / /           
| |/ / _   _| |__   ___| |/ /  ___ _   _ 
|    \| | | | '_ \ / _ \    \ / _ \ | | |
| |\  \ |_| | |_) |  __/ |\  \  __/ |_| |
\_| \_/\__,_|_.__/ \___\_| \_/\___|\__, |
                                    __/ |
                                   |___/

02:01:21 UTC [CheckFileExist] Check output file if existed
02:01:21 UTC success: [LocalHost]
......(部分内容省略)
images/index.json
images/oci-layout
images/oci-put-blob2751000164
images/oci-put-blob3505359311
kube/v1.20.10/amd64/kubeadm
kube/v1.20.10/amd64/kubectl
kube/v1.20.10/amd64/kubelet
registry/compose/v2.26.1/amd64/docker-compose-linux-x86_64
registry/harbor/v2.10.1/amd64/harbor-offline-installer-v2.10.1.tgz
registry/registry/2/amd64/registry-2-linux-amd64.tar.gz
repository/amd64/ubuntu/22.04/ubuntu-22.04-amd64.iso
runc/v1.1.12/amd64/runc.amd64
02:36:23 UTC success: [LocalHost]
02:36:23 UTC [ChownOutputModule] Chown output file
02:36:23 UTC Skip chown for kubernetes-1.20.10-artifact.tar.gz: SUDO_UID/GID missing (not using sudo)
02:36:23 UTC success: [LocalHost]
02:36:23 UTC [ChownWorkerModule] Chown ./kubekey dir
02:36:23 UTC Skip chown for /root/kubekey: SUDO_UID/GID missing (not using sudo)
02:36:23 UTC success: [LocalHost]
02:36:23 UTC Pipeline[ArtifactExportPipeline] execute successfully
```
## 4. 

```