#!/bin/bash
set -e

# 安装目录
INSTALL_DIR="/apps"
DATA_DIR="/data/starrocks"
SR_VERSION="3.4.0"
SR_PACKAGE="StarRocks-${SR_VERSION}-ubuntu-amd64"
SR_URL="https://releases.starrocks.io/starrocks/${SR_PACKAGE}.tar.gz"
SR_HOME="${INSTALL_DIR}/StarRocks"

# 检查root
if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] 请以 root 用户运行脚本"
  exit 1
fi

# 检查是否传入参数
if [ -z "$1" ]; then
  echo "[ERROR] 请在执行脚本时传入 FE Helper 的 IP 地址，例如：192.168.1.1"
  echo "用法: sudo ./install.sh <IP地址>"
  exit 1
fi

INPUT_IP="$1"

# 校验是否为合法 IP（不带端口）
if ! echo "$INPUT_IP" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "[ERROR] 参数格式错误！必须是合法 IP 地址（不要包含端口）"
  echo "示例：sudo ./install.sh 10.84.10.7"
  exit 1
fi

# 自动拼接端口
FE_HELPER="${INPUT_IP}:9010"

echo "[INFO] 创建目录..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$DATA_DIR/fe/meta"
mkdir -p "$DATA_DIR/be/storage"

# 下载并解压
if [ ! -d "$SR_HOME" ]; then
  echo "[INFO] 下载并解压 StarRocks..."
  curl -L "$SR_URL" | tar -xz -C "$INSTALL_DIR"
  mv "${INSTALL_DIR}/${SR_PACKAGE}" "$SR_HOME"
else
  echo "[INFO] StarRocks 已存在，跳过下载"
fi

# 写 FE 配置
FE_CONF="${SR_HOME}/fe/conf/fe.conf"
cat > "$FE_CONF" << EOF
LOG_DIR = \${STARROCKS_HOME}/log

DATE = "\$(date +%Y%m%d-%H%M%S)"
JAVA_OPTS="-Dlog4j2.formatMsgNoLookups=true -Xmx32768m -XX:+UseMembar -XX:SurvivorRatio=8 -XX:MaxTenuringThreshold=7 -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+CMSClassUnloadingEnabled -XX:-CMSParallelRemarkEnabled -XX:CMSInitiatingOccupancyFraction=75 -XX:SoftRefLRUPolicyMSPerMB=0 -Xloggc:\${LOG_DIR}/fe.gc.log.\$DATE -XX:+PrintConcurrentLocks"

JAVA_OPTS_FOR_JDK_11="-Dlog4j2.formatMsgNoLookups=true -Xmx32768m -XX:+UseG1GC -Xlog:gc*:\${LOG_DIR}/fe.gc.log.\$DATE:time -XX:G1HeapRegionSize=32m -XX:InitiatingHeapOccupancyPercent=40 -XX:ConcGCThreads=8 -XX:ParallelGCThreads=20 -Djava.security.policy=\${STARROCKS_HOME}/conf/udf_security.policy"

sys_log_delete_age = 7d
audit_log_delete_age = 7d
dump_log_delete_age = 7d
qe_max_connection=20000
sys_log_level = INFO
meta_dir = ${DATA_DIR}/fe/meta/
http_port = 8030
rpc_port = 9020
query_port = 9030
edit_log_port = 9010
mysql_service_nio_enabled = true
priority_networks = 10.84.10.0/24
EOF

echo "[INFO] fe.conf 配置完成"

# 写 BE 配置
BE_CONF="${SR_HOME}/be/conf/be.conf"
cat > "$BE_CONF" << EOF
mem_limit = 60%
sys_log_level = INFO
be_port = 9060
be_http_port = 8040
heartbeat_service_port = 9050
brpc_port = 8060
starlet_port = 9070
default_replication_num = 3
priority_networks = 10.84.10.0/24
storage_root_path = ${DATA_DIR}/be/
EOF

echo "[INFO] be.conf 配置完成"

# 创建 FE systemd 服务
FE_SERVICE="/etc/systemd/system/starrocks-fe.service"
cat > "$FE_SERVICE" << EOF
[Unit]
Description=starrocks-fe daemon

[Service]
Type=simple
Environment="JAVA_HOME=/usr/local/jdk11"
ExecStart=/bin/bash ${SR_HOME}/fe/bin/start_fe.sh --helper="${FE_HELPER}"
ExecStop=/bin/bash ${SR_HOME}/fe/bin/stop_fe.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 创建 BE systemd 服务
BE_SERVICE="/etc/systemd/system/starrocks-be.service"
cat > "$BE_SERVICE" << EOF
[Unit]
Description=starrocks-be daemon

[Service]
Type=simple
Environment="JAVA_HOME=/usr/local/jdk11"
ExecStart=/bin/bash ${SR_HOME}/be/bin/start_be.sh
ExecStop=/bin/bash ${SR_HOME}/be/bin/stop_be.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "[INFO] systemd 服务文件创建完成"

# 重载 systemd
systemctl daemon-reload

# 启动并设置开机启动
systemctl enable --now starrocks-fe.service
systemctl enable --now starrocks-be.service

echo "[INFO] StarRocks FE 和 BE 已启动并设置为开机自启"

