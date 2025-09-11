# Higress 是什么?
Higress 官方说明：https://higress.cn/docs/latest/overview/what-is-higress/?spm=36971b57.2ef5001f.0.0.2a932c1flqhpsR

# 部署Higress部署方式
部署方式有四种：
- [使用hgctl 工具](https://higress.cn/docs/latest/ops/hgctl/?spm=36971b57.2ef5001f.0.0.2a932c1flqhpsR)
- [使用 Helm 进行云原生部署](https://higress.cn/docs/latest/ops/deploy-by-helm/?spm=36971b57.2ef5001f.0.0.2a932c1flqhpsR)
- [基于 Docker Compose 进行独立部署](https://higress.cn/docs/latest/ops/deploy-by-docker-compose/?spm=36971b57.2ef5001f.0.0.2a932c1flqhpsR)
- [通过阿里云计算巢快速部署](https://higress.cn/docs/latest/ops/deploy-by-aliyun-computenest/?spm=36971b57.2ef5001f.0.0.2a932c1flqhpsR)

此处使用基于云原生部署的方式来使用Higress
# 部署前提条件
1. 有一个正常使用的标准的K8S集群
2. 有一个可用的LB服务（可选）

# 什么是LB服务？
Kubernetes 并没有为裸金属集群提供网络负载均衡器（即 `LoadBalancer` 类型的 Service）的实现。Kubernetes 所附带的网络负载均衡器实现，实际上只是一些“胶水代码”，用于调用各个 IaaS 平台（如 GCP、AWS、Azure……）的负载均衡服务。如果你没有运行在这些受支持的 IaaS 平台上，那么当你创建 `LoadBalancer` 类型的 Service 时，它将会一直处于 “Pending（等待）” 状态，无法正常工作。

对于裸金属集群的运维人员来说，Kubernetes 只留下了两个相对弱一些的工具来将用户流量引入集群：`NodePort` 和 `externalIPs` 类型的服务。但这两种方式在生产环境中都有显著的缺点，使得裸金属集群在 Kubernetes 生态中成为“二等公民”。
MetalLB和OpenLB 的目标就是为了弥补这一缺陷，提供一个能够与标准网络设备集成的网络负载均衡器实现，使得在裸金属集群中运行的外部服务也能够尽可能地“开箱即用”。
# MetalLB安装前的准备工作
MetalLB 的正常运行需要满足以下条件：

- 一个运行在 Kubernetes 1.13.0 或更高版本的 Kubernetes 集群，且该集群尚未具备网络负载均衡功能。
- 一个能够与 MetalLB 共存的集群网络配置。
- 一些 IPv4 地址，供 MetalLB 分配给外部服务使用。
- 如果使用 BGP 模式，则需要一个或多个支持 BGP 协议 的路由器。
- 如果使用 L2 模式，则必须允许集群节点之间通过 7946 端口（TCP 和 UDP） 进行通信（也可以配置为其他端口），这是 memberlist 所要求的。

MetalLB核心功能的实现依赖于两种机制：

地址分配：基于指定的地址池进行分配；

对外公告：让集群外部的网络了解新分配的IP地址，MetalLB使用ARP、NDP或BGP实现
kube-proxy工作于ipvs模式时，必须要使用严格ARP（StrictARP）模式，因此，若有必要，先运行如下命令，配置kube-proxy。

## 1. 查询kube-proxy是否工作于ipvs模式
```bash
root@minikube:~# kubectl -n kube-system get configmap kube-proxy -o yaml | grep mode
    mode: ipvs
```
## 2. 修改kube-proxy的cm使用ARP（StrictARP）模式，默认为false
```bash
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system
```
## 3. 进入项目目录
```shell
cd Work-Notes/Higress
```

## 4. 安装MetalLB
[通过清单安装](https://metallb.io/installation/#installation-by-manifest)
```bash
kubectl apply -f metallb/metallb-native.yaml
```
## 5. 验证是否安装成功
```bash
root@minikube:~# kubectl get pod -n metallb-system
NAME                          READY   STATUS    RESTARTS   AGE
controller-5f99fd6568-l69gk   1/1     Running   0          27d
speaker-p22q8                 1/1     Running   0          27d
```
## 6. 配置LB地址池和L2模式
```shell
kubectl apply -f metallb/IPAddressPool -f metallb/L2Advertisement.yaml -n metallb-system
```

# 使用 Helm 进行云原生部署Higress并启用AI网关功能
Helm 是一个用于自动化管理和发布 Kubernetes 软件的包管理系统。通过 Helm 可以在您的 Kubernetes 集群上快速部署安装 Higress 网关。

Higress 网关由控制面组件 higress-controller 和数据面组件 higress-gateway 组成。higress-gateway负责承载数据流量，higress-controller 负责管理配置下发。
## 1. 安装higress
```shell
# 只启用AI网关功能
helm install higress -n higress-system higress.io/higress --create-namespace --render-subchart-notes --set global.enableRedis=true

# 启用AI网关功能和内置监控套件
helm install higress -n higress-system higress.io/higress --create-namespace --render-subchart-notes --set global.enableRedis=true --set global.o11y.enabled=true
```
注意：如果k8s集群中已经存在prometheus-operator或kube-prometheus不能启用内置监控套件，他们是互斥的，只能存在其一，不启用内置监控套件时可以对接外部监控可以是prometheus-operator或kube-prometheus
## 2. 常用安装参数
### 🔧 全局参数（Global Parameters）

| 参数名                          | 参数说明                                                                                                                                                                                                                               | 默认值  |
|-------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|
| `global.local`                | 如果要安装至本地 K8s 集群（如 Kind、Rancher Desktop 等），请设置为 `true`                                                                                                                                                              | `false` |
| `global.ingressClass`         | 用于过滤被 Higress Controller 监听的 Ingress 资源的 IngressClass。<br>特殊取值：<br>1. `"nginx"`：监听 Ingress 为 `nginx` 或为空的资源。<br>2. 空字符串：监听所有 Ingress。                                                              | `higress` |
| `global.watchNamespace`       | 若值不为空，Higress Controller 将只会监听指定命名空间下的资源。<br>适用于多租户隔离场景下限制网关监听范围。                                                                                                                            | `""`    |
| `global.disableAlpnH2`        | 是否在 ALPN 中禁用 HTTP/2 协议                                                                                                                                                                                                         | `false` |
| `global.enableStatus`         | 若为 `true`，Higress Controller 将更新 Ingress 的 `status` 字段。<br>迁移自 Nginx Ingress 时建议设为 `false`。                                                                                                                         | `true`  |
| `global.enableIstioAPI`       | 若为 `true`，Higress Controller 将同时监听 Istio 资源                                                                                                                                                                                  | `false` |
| `global.enableGatewayAPI`     | 若为 `true`，Higress Controller 将同时监听 Gateway API 资源                                                                                                                                                                            | `false` |
| `global.onlyPushRouteCluster` | 若为 `true`，Higress Controller 只推送被路由关联的服务                                                                                                                                                                                 | `true`  |
| `global.o11y.enabled`         | 若为 `true`，将同时安装可观测性套件（Grafana、Prometheus、Loki、PromTail）                                                                                                                                                            | `false` |
| `global.pvc.rwxSupported`     | 标识目标 K8s 集群是否支持 PersistentVolumeClaim 的 ReadWriteMany 操作方式                                                                                                                                                             | `true`  |

### ⚙️ 核心组件参数（Core Component Parameters）

#### `higress-core.gateway`

| 参数名                          | 参数说明                                       | 默认值     |
|-------------------------------|----------------------------------------------|------------|
| `higress-core.gateway.replicas`      | Higress Gateway 的 Pod 数量                  | `2`        |
| `higress-core.gateway.httpPort`      | Higress Gateway 将监听的 HTTP 端口           | `80`       |
| `higress-core.gateway.httpsPort`     | Higress Gateway 将监听的 HTTPS 端口          | `443`      |
| `higress-core.gateway.kind`          | 用于部署 Higress Gateway 的资源类型，可选 `Deployment` 或 `DaemonSet` | `Deployment` |

#### `higress-core.controller`

| 参数名                             | 参数说明                       | 默认值 |
|----------------------------------|------------------------------|--------|
| `higress-core.controller.replicas` | Higress Controller 的 Pod 数量 | `1`  |

[完整版安装参数](https://higress.cn/docs/latest/user/configurations/?spm=36971b57.2ef5001f.0.0.2a932c1flqhpsR)

## 3. 验证是否安装成功
```bash
root@minikube:~# kubectl get pod,svc -n higress-system
NAME                                      READY   STATUS    RESTARTS      AGE
pod/higress-console-75795f445-vn768       1/1     Running   2 (31h ago)   2d10h
pod/higress-controller-5497c65c95-j6784   2/2     Running   4 (31h ago)   2d10h
pod/higress-gateway-6f55cb6d54-jdxvj      1/1     Running   2 (31h ago)   33h
pod/higress-gateway-6f55cb6d54-sj8g2      1/1     Running   2 (31h ago)   33h
pod/redis-stack-server-0                  1/1     Running   2 (31h ago)   2d10h

NAME                         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                             AGE
service/higress-console      ClusterIP      10.233.13.83    <none>        8080/TCP                                                            2d10h
service/higress-controller   ClusterIP      10.233.17.195   <none>        8888/TCP,8889/TCP,15051/TCP,15010/TCP,15012/TCP,443/TCP,15014/TCP   2d10h
higress-gateway              LoadBalancer   10.233.53.184   10.84.3.100   80:31073/TCP,443:30649/TCP                                          2d10h
service/redis-stack-server   ClusterIP      10.233.6.177    <none>        6379/TCP                                                            2d10h
```
# 配置higress-console
## 1. 清除higress默认的ingress规则
```bash
kubectl delete ingress -n higress-system default
```
## 2. 暴露higress-console端口
```bash
kubectl patch svc higress-console -n higress-system -p '{"spec":{"type":"NodePort","ports":[{"port":8080,"targetPort":8080,"nodePort":30928}]}}'
```
## 3. 访问higress-console
higress-console访问地址 : http://10.84.3.100:30928
![img.png](image/higress-console.png)

## 4. 对接外部监控
```shell
# 对接prometheus-operator
kubectl apply -f higress-PodMonitor.yaml -n higress-system
```
## 5. 验证是否对接成功
![img.png](image/prometheus-targets.png)
## 6.基于外部监控(Prometheus)实现入口流量观测
导入项目中的Higress-AI-CN.json看板至grafana
![img.png](image/grafana1.png)
![img.png](image/grafana2.png)
![img.png](image/grafana3.png)
![img.png](image/grafana4.png)
复制地址并将图中选择的时间段参数删除
![img.png](image/grafana5.png)
![img.png](image/grafana6.png)
# 配置AI网关
## 1. 创建AI提供者
![img.png](image/AI-Gateway1.png)
![img.png](image/AI-Gateway2.png)
## 2. 创建消费者(访问AI网关所需的认证)
![img.png](image/consumer1.png)
![img.png](image/consumer2.png)
## 3. 创建AI路由
![img.png](image/Ai-Route1.png)
![img.png](image/Ai-Route2.png)
## 4. 测试能否正常访问
```shell
python3 OpenAI-request.py
```
![img.png](image/python.png)
![img.png](image/Traffic-and-KEY-Observations.png)

# 配置AI统计模块
## 概述
通过客户端请求 Header 中的自定义字段，将 AI 请求/响应的关键数据提取并记录到 Higress Gateway 的 ai_log 日志中，用于后续分析、监控与计费
## 测试请求：验证响应结构
```shell
LAN_IP=$(hostname -I | awk '{print $1}')
curl -sv "http://10.84.3.40:32222/v1/chat/completions" \
-X POST \
-H "Authorization: Bearer b1b9ad40f6687fa74dbbe07eaa2381b7" \
-H "Content-Type: application/json" \
-H "x-mse-consumer: General" \
-H "x-client-ip: $LAN_IP" \
-d '{
    "model": "DeepSeek-V3.1",
    "messages": [
        {"role": "system", "content": "你是一个有用的小助手"},
        {"role": "user", "content": "3，10，15，26，下一个数字是多少？"}
    ],
    "temperature": 0.7,
    "max_tokens": 5000
}'
```
Python 版本（流式响应）
```python
import openai
import os
import socket

def get_lan_ip():
    def is_private_ip(ip):
        return any(ip.startswith(prefix) for prefix in ["10.", "172.16.", "192.168."])

    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip if is_private_ip(local_ip) else "127.0.0.1"
    except Exception:
        return "127.0.0.1"

#Higress 40
PROXY_API_KEY = "b1b9ad40f6687fa74dbbe07eaa2381b7"
PROXY_SERVER_URL = "http://10.84.3.40:32222/v1"
PROXYLLM_BACKEND = "DeepSeek-V3.1"


local_lan_ip = get_lan_ip()  # 👈 获取局域网 IP
# print(f"[INFO] 局域网IP: {local_lan_ip}")

os.environ["OPENAI_API_KEY"] = PROXY_API_KEY
client = openai.OpenAI(
    base_url=PROXY_SERVER_URL,
    default_headers={
        "x-mse-consumer": "General",
        "x-client-ip": local_lan_ip,
    }
)

def generate_text(prompt, model_name=PROXYLLM_BACKEND, max_tokens=5000):
    payload = {
        'stream': True,
        'model': model_name,
        'temperature': 0.7,
        'max_tokens': max_tokens,
    }

    messages = [
        {'role': 'system', 'content': '你是一个有用的小助手'},
        {'role': 'user', 'content': prompt}
    ]

    stream = client.chat.completions.create(
        messages=messages,
        **payload
    )

    text = ""
    for chunk in stream:
        if chunk.choices:
            delta = chunk.choices[0].delta
            delta_text = getattr(delta, 'content', None) or getattr(delta, 'reasoning_content', None)

            if delta_text:
                text += delta_text
                print(delta_text, end='', flush=True)

    return text

prompt = "3，10，15，26，下一个数字是多少？"
generated_text = generate_text(prompt)
```
## 响应关键 Header 字段（用于统计和排错）
```shell
*   Trying 10.84.3.40:32222...
* Connected to 10.84.3.40 (10.84.3.40) port 32222
* using HTTP/1.x
> POST /v1/chat/completions HTTP/1.1
> Host: 10.84.3.40:32222
> User-Agent: curl/8.12.1
> Accept: */*
> Authorization: Bearer b1b9ad40f6687fa74dbbe07eaa2381b7  #请求时带的认证KEY
> Content-Type: application/json
> x-mse-consumer: General                                 #请求时传递的consumer名称
> x-client-ip: 10.84.0.106                                #请求时传递的client 地址
> Content-Length: 264
> 
* upload completely sent off: 264 bytes
< HTTP/1.1 200 OK
< server: istio-envoy
< req-cost-time: 7079
< req-arrive-time: 1757552040635                          # 请求到达网关的时间戳
< date: Thu, 11 Sep 2025 00:54:00 GMT,Thu, 11 Sep 2025 00:54:00 GMT
< content-type: application/json
< resp-start-time: 1757552047714                          # 网关开始向客户端发送响应的时间戳
< x-envoy-upstream-service-time: 7075                     # 后端服务处理耗时
< transfer-encoding: chunked
< 
{"id":"chatcmpl-5014ef48-d72c-42dc-9c3b-02684f4bee72","object":"chat.completion","created":1757552040,"model":"DeepSeek-V3.1","choices":[{"index":0,"message":{"role":"assistant","content":"要找出序列 3, 10, 15, 26 的下一个数字，我们可以分析数字之间的关系：\n\n- 观察数字：3, 10, 15, 26\n- 计算相邻数字的差：\n  - 10 - 3 = 7\n  - 15 - 10 = 5\n  - 26 - 15 = 11\n  差值序列为 7, 5, 11，没有明显的算术规律。\n\n- 考虑其他模式，比如与平方数的关系：\n  - 3 = 2² - 1\n  - 10 = 3² + 1\n  - 15 = 4² - 1\n  - 26 = 5² + 1\n\n可以看出，每个数字可以表示为 (n+1)² ± 1，其中符号交替出现：\n- 第1项（n=1）：(1+1)² - 1 = 4 - 1 = 3\n- 第2项（n=2）：(2+1)² + 1 = 9 + 1 = 10\n- 第3项（n=3）：(3+1)² - 1 = 16 - 1 = 15\n- 第4项（n=4）：(4+1)² + 1 = 25 + 1 = 26\n\n因此，第5项（n=5）应为：(5+1)² - 1 = 36 - 1 = 35\n\n所以，下一个数字是 **35**。\n\n验证：序列为 3, 10, 15, 26, 35，符合交替* Connection #0 to host 10.84.3.40 left intact
加减1的模式。\n\n**答案：35**","refusal":null,"annotations":null,"audio":null,"function_call":null,"tool_calls":[],"reasoning_content":null},"logprobs":null,"finish_reason":"stop","stop_reason":null}],"service_tier":null,"system_fingerprint":null,"usage":{"prompt_tokens":21,"total_tokens":388,"completion_tokens":367,"prompt_tokens_details":null},"prompt_logprobs":null,"kv_transfer_params":null}
```
## AI统计模块的yaml配置
整体配置大致相同，例子中只取header中的单个配置解释，其他的依葫芦画瓢即可，前提是响应的header中包含需要的字段
配置步骤：登录higress-console-->```AI网关管理```-->```AI路由管理```-->选取某一条路由右侧的```策略```按钮-->点击```AI 统计``` ```配置```按钮-->选择```YAML视图```-->贴入下列配置-->点击开启状态 下的按钮-->点击```保存```
### 配置说明
- apply_to_log: true：表示该字段将被记录到日志中。
- value_source：指定数据来源（request_header, response_header, request_body, response_body, response_streaming_body）。
- key：自定义日志字段名。
- value：对应来源中的具体路径或 Header 名称。
```yaml
attributes:
  # 从响应体提取模型名和 token 用量
  - apply_to_log: true
    apply_to_span: false
    key: "model"
    value: "usage.models.0.model_id"
    value_source: "response_body"

  - apply_to_log: true
    key: "input_token"
    value: "usage.models.0.input_tokens"
    value_source: "response_body"

  - apply_to_log: true
    key: "output_token"
    value: "usage.models.0.output_tokens"
    value_source: "response_body"

  # 从请求体提取用户问题
  - apply_to_log: true
    key: "question"
    value: "messages.@reverse.0.content"  # 取最后一条用户消息
    value_source: "request_body"

  # 流式响应：逐块拼接回答内容
  - apply_to_log: true
    key: "answer"
    rule: "append"  # 流式内容需用 append 模式拼接
    value: "choices.0.delta.content"
    value_source: "response_streaming_body"

  # 非流式响应：一次性提取完整回答
  - apply_to_log: true
    key: "answer"
    value: "choices.0.message.content"
    value_source: "response_body"

  # 从请求头提取认证信息与客户端信息
  - apply_to_log: true
    key: "bearer_token"
    value: "Authorization"
    value_source: "request_header"

  - apply_to_log: true
    key: "consumer"
    value: "x-mse-consumer"
    value_source: "request_header"

  - apply_to_log: true
    key: "client_ip"
    value: "x-client-ip"
    value_source: "request_header"

  # 从响应头提取性能指标
  - apply_to_log: true                     #👈 是否将提取的信息记录在日志中
    key: "upstream_service_time_ms"        #👈 自定义日志字段名（你想叫什么就叫什么）
    value: "x-envoy-upstream-service-time" #👈 必须是 HTTP 响应头中真实存在的 Header 名称
    value_source: "response_header"        #👈 表示从“响应头”中提取这个值

  - apply_to_log: true
    key: "request_arrive_timestamp"
    value: "req-arrive-time"
    value_source: "response_header"

  - apply_to_log: true
    key: "response_start_timestamp"
    value: "resp-start-time"
    value_source: "response_header"
```
> apply_to_span: false 表示不用于链路追踪，仅用于日志记录。如需接入链路追踪系统，可设为 true。
```log
{
  "ai_log": {
    "answer": "要找出序列 3, 10, 15, 26 的下一个数字...答案：35",
    "bearer_token": "Bearer b1b9ad40f6687fa74dbbe07eaa2381b7",
    "chat_id": "chatcmpl-4f115efd-077f-4d00-b4d6-439e3a771f1f",
    "chat_round": 1,
    "client_ip": "10.84.6.5",
    "consumer": "General",
    "input_token": 21,
    "llm_first_token_duration": 100,
    "llm_service_duration": 10117,
    "model": "DeepSeek-V3.1",
    "output_token": 523,
    "question": "3，10，15，26，下一个数字是多少？",
    "request_arrive_timestamp": "1757553263181",
    "response_start_timestamp": "1757553263283",
    "response_type": "stream",
    "upstream_service_time_ms": "96"
  },
  "authority": "10.84.3.40:32222",
  "bytes_received": "309",
  "bytes_sent": "119120",
  "duration": "10121",   #请求总耗时
  "method": "POST",
  "path": "/v1/chat/completions",
  "response_code": "200",
  "start_time": "2025-09-11T01:14:23.181Z",
  "upstream_cluster": "outbound|80||llm-gpustack-10-24.internal.static",
  "user_agent": "OpenAI/Python 1.56.2"
}
```
### 配置生效步骤
- 登录 Higress Console。
- 进入 AI网关管理 → AI路由管理。
- 选择目标路由 → 点击右侧 策略。
- 点击 AI统计 → 配置 → YAML视图。
- 粘贴上述 YAML 配置。
- 点击 开启 按钮（确保状态为启用）。
- 点击 保存。 
# 注意事项
- 确保响应中包含你配置提取的 Header 或 Body 字段，否则日志中对应字段为空。
- 流式响应需使用 rule: "append" 才能正确拼接完整回答。
- @reverse.0 表示取数组倒数第一个元素（即最新用户提问）。
- 时间戳单位为毫秒，可用于计算端到端延迟、首字节延迟等。
