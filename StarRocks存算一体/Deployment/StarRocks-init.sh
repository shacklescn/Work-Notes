#!/bin/bash
set -e  # 遇到错误立即退出

# 配置项
SYSCTL_EXTRA="/etc/sysctl.d/99-custom-limits.conf"
LIMITS_PROC_FILE="/etc/security/limits.d/20-nproc.conf"
LIMITS_FILE="/etc/security/limits.conf"
CHRONY_CONF="/etc/chrony/chrony.conf"
CURRENT_TZ=$(timedatectl show -p Timezone --value)
SYSCTL_MARKER="# Added by StarRocks setup"

JDKPKGNAME="./jdk-11.0.27_linux-x64_bin.tar.gz"
JAVA_HOME_PATH="/usr/local/jdk11"
JDK_UNPACK_DIR="/usr/local/jdk-11.0.27"

# 日志打印
log() {
  echo -e "[INFO] $1"
}

warn() {
  echo -e "[WARN] $1"
}

error() {
  echo -e "[ERROR] $1"
}

# 创建目录
ensure_dir() {
  local dir=$1
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
    log "创建目录：$dir"
  else
    log "目录已存在：$dir，跳过"
  fi
}

# 写配置文件（如果不存在）
write_if_not_exists() {
  local file=$1
  local content=$2
  if [ ! -f "$file" ]; then
    echo "$content" > "$file"
    log "$file 不存在，已创建"
  else
    log "$file 已存在，跳过"
  fi
}

# 追加配置（如果不包含关键字）
append_if_not_contains() {
  local file=$1
  local keyword=$2
  local content=$3
  if grep -q "$keyword" "$file"; then
    log "$file 已包含配置，跳过"
  else
    echo -e "\n$content" >> "$file"
    log "$file 已追加配置"
  fi
}

# 权限检查
if [ "$(id -u)" -ne 0 ]; then
  error "请以 root 用户运行该脚本"
  exit 1
fi

# /apps
ensure_dir "/apps"

# 安装 JDK
if [ ! -d "$JAVA_HOME_PATH" ]; then
  tar -zxf "$JDKPKGNAME" -C /usr/local/ && mv "$JDK_UNPACK_DIR" "$JAVA_HOME_PATH"
  log "JDK 安装完成：$JAVA_HOME_PATH"
else
  log "JDK 已存在，跳过"
fi

# 环境变量
append_if_not_contains "/etc/profile" "JAVA_HOME=${JAVA_HOME_PATH}" "
# Java 11 配置
export JAVA_HOME=${JAVA_HOME_PATH}
export PATH=\$JAVA_HOME/bin:\$PATH
export LANG=en_US.UTF8
"
source /etc/profile

# swap
if grep -q "swap" /etc/fstab && ! grep -q "^#.*swap" /etc/fstab; then
  sed -i '/swap/s/^/# /' /etc/fstab
  swapoff -a
  log "swap 已禁用"
else
  log "swap 已禁用或已被注释，跳过"
fi

# 内核参数
append_if_not_contains "/etc/sysctl.conf" "$SYSCTL_MARKER" "
$SYSCTL_MARKER
vm.overcommit_memory = 1
vm.swappiness = 0
net.ipv4.tcp_abort_on_overflow=1
net.core.somaxconn=1024
vm.max_map_count = 262144
"
sysctl -p

# 时区
if [ "$CURRENT_TZ" != "Asia/Shanghai" ]; then
  timedatectl set-timezone Asia/Shanghai
  hwclock -w
  log "时区已设置为 Asia/Shanghai"
else
  log "当前时区已是 Asia/Shanghai，跳过"
fi

# chrony
if ! command -v chronyd &>/dev/null; then
  apt-get update
  apt-get install -y chrony
  log "chrony 已安装"
else
  log "chrony 已安装，跳过"
fi

append_if_not_contains "$CHRONY_CONF" "ntp1.aliyun.com" "
pool ntp1.aliyun.com iburst
pool ntp2.aliyun.com iburst
sourcedir /run/chrony-dhcp
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
keyfile /etc/chrony/chrony.keys
ntsdumpdir /var/lib/chrony
leapsectz right/UTC
logdir /var/log/chrony
"
systemctl restart chrony
log "chrony 配置完成并重启"

# limits.conf
append_if_not_contains "$LIMITS_FILE" "655350" "
# Added by StarRocks setup
* soft nproc 65535
* hard nproc 65535
* soft nofile 655350
* hard nofile 655350
* soft stack unlimited
* hard stack unlimited
* soft memlock unlimited
* hard memlock unlimited
"

# limits.d nproc
if [ ! -f "$LIMITS_PROC_FILE" ]; then
  cat <<EOF > "$LIMITS_PROC_FILE"
*          soft    nproc     65535
root       soft    nproc     65535
EOF
  log "$LIMITS_PROC_FILE 不存在，已创建"
else
  append_if_not_contains "$LIMITS_PROC_FILE" "65535" "
# Added by setup script
*          soft    nproc     65535
root       soft    nproc     65535
"
fi

# sysctl.d 最大进程数
write_if_not_exists "$SYSCTL_EXTRA" "
# Custom kernel limits
kernel.threads-max = 120000
kernel.pid_max = 200000
"
sysctl --system
log "kernel.threads-max 和 pid_max 已配置并加载"

log "系统初始化完成，请重启系统以使所有配置生效"
