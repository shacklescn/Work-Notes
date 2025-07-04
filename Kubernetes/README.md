# Kubernetes 日常运维手册
```shell

```

# FQA
## 1、节点根目录可用空间不足，登录此节点查看磁盘情况
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