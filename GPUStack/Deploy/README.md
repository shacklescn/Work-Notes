# GPUStack 部署手册
## 前提条件
| 操作系统        | 版本              |
|-------------|-----------------|
| Ubuntu      | >= 20.04        |
| Debian      | >= 11           |
| RHEL        | >= 8            |
| Rocky       | >= 8            |
| Fedora      | >= 36  |
| OpenSUSE    | >= 15.3 (leap) |
| OpenEuler   | >= 22.03 |
| macOS       | >= 14 |
基于 NVIDIA CUDA 来运行GPUStack

安装以下组件：

[Docker 容器](https://www.docker.com/)

[NVIDIA 驱动程序](https://www.nvidia.com/en-us/drivers/)

[NVIDIA CUDA Toolkit 12](https://developer.nvidia.com/cuda-toolkit)（可选，非 Docker 安装所需）

[NVIDIA cuDNN 9](https://developer.nvidia.com/cudnn)（可选，不使用 Docker 时音频模型必需）

[NVIDIA 容器工具包](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit)（可选，Docker 安装所需）
## 控制节点容器环境
```shell
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "args": [],
            "path": "nvidia-container-runtime"
        }
    }
}
root@server4:~# docker-compose -v
Docker Compose version v2.33.1

root@server4:~# docker -v
Docker version 27.5.1, build 27.5.1-0ubuntu3~22.04.2
```
## 控制节点gpustack配置
```yaml
# 
services:
  gpustack:
    image: gpustack/gpustack:v0.7.1-cuda12.8
    container_name: gpustack
    restart: unless-stopped
    network_mode: host
    shm_size: 8gb
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=all
    volumes:
      - /data/gpustack:/var/lib/gpustack
      - /etc/localtime:/etc/localtime:ro
      - /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime:ro
      - /models/:/models/:ro
    command:
      --enable-ray
```

## 计算节点容器环境
```shell
root@server5:~# cat /etc/docker/daemon.json 
{
    "default-runtime": "nvidia",
    "exec-opts": [
        "native.cgroupdriver=cgroupfs"
    ],
    "data-root": "/data/docker",
    "insecure-registries": [
        "10.84.10.5"
    ],
    "log-opts": {
        "max-file": "3",
        "max-size": "5m"
    },
    "runtimes": {
        "nvidia": {
            "args": [],
            "path": "nvidia-container-runtime"
        }
    }
}

root@server5:~# docker-compose -v
Docker Compose version v2.39.0

root@server5:~# docker -v
Docker version 26.1.4, build 5650f9b
```
## 计算节点gpustack配置
```shell
services:
  gpustack:
    image: gpustack/gpustack:v0.7.1-cuda12.8
    container_name: gpustack
    restart: unless-stopped
    network_mode: host
    shm_size: 8gb
      #deploy:
      #resources:
      #  reservations:
      #    devices:
      #      - capabilities: [gpu]
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=all
    volumes:
      - /data/gpustack:/var/lib/gpustack
      - /etc/localtime:/etc/localtime:ro
      - /usr/share/zoneinfo/Asia/Shanghai:/etc/localtime:ro
      - /data/models/:/models/:ro
    command:
      --server-url http://10.84.10.24
      --token 084837aaee0ad9f0d708f5e8c344474c
      --worker-ip 10.84.10.29
      --enable-ray
```
## vLLM (0.10.1.1)各模型运行时参数
DeepSeek-V3.1-Terminus:
- --pipeline-parallel-size=1
- --tensor-parallel-size=8
- --trust-remote-code
- --max-model-len=131072
- --enable-auto-tool-choice
- --tool-call-parser=deepseek_v3

Qwen3-235B-A22B-Instruct-2507
- --enable-expert-parallel
- --max-model-len=131072
- --tool-call-parser=hermes
- --enable-auto-tool-choice
- --tensor-parallel-size=8
- --pipeline-parallel-size=1

Qwen3-Reranker-8B
- --hf_overrides={"architectures": ["Qwen3ForSequenceClassification"],"classifier_from_token": ["no", "yes"],"is_original_qwen3_reranker": true}
- --task=score
- --max-num-seqs=1
- --max-num-batched-tokens=32768
- --max-model-len=32768
- --tensor-parallel-size=1
- --pipeline-parallel-size=1

Qwen3-Embedding-8B
- --task=embed
- --gpu-memory-utilization=0.3

InternVL3-78B
- --max-model-len=32768
- --trust-remote-code
- --limit-mm-per-prompt={"image": 16,"video": 2}
- --tool-call-parser=internlm
- --enable-auto-tool-choice
- --enable-log-requests