#!/bin/bash
#前提条件
#注意：s3路径结尾不能加/否则会报错
# CREATE REPOSITORY green_pioneer_iot_prod_bak
# WITH BROKER
# ON LOCATION "s3://starrocks/green_pioneer_prod_uat_bak"
# PROPERTIES(
#    "aws.s3.access_key" = "StarRocks",
#    "aws.s3.secret_key" = "SecA@2025...",
#    "aws.s3.endpoint" = "http://10.84.3.46:9000"
# );

# CREATE REPOSITORY green_pioneer_iot_uat_bak
# WITH BROKER
# ON LOCATION "s3://starrocks/green_pioneer_iot_uat_bak"
# PROPERTIES(
#    "aws.s3.access_key" = "StarRocks",
#    "aws.s3.secret_key" = "SecA@2025...",
#    "aws.s3.endpoint" = "http://10.84.3.46:9000"
# );
# ======================
# 核心参数
# ======================

LOG_FILE="/var/log/starrocks/starrocks_snapshot.log"
BACKUP_NAME="BACKUP_$(date +%Y%m%d)"

PROD_DB="green_pioneer_iot_prod"
UAT_DB="green_pioneer_iot_uat"
MYSQL_CMD="mysql -uroot -h10.84.0.106 -P9030 -peQ59z!2HJwA2r"

PROD_REPO="green_pioneer_iot_prod_bak"
UAT_REPO="green_pioneer_iot_uat_bak"
# ======================
# 初始化日志目录和文件（只创建一次）
# ======================
LOG_DIR="$(dirname "$LOG_FILE")"
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y/%m/%d %H:%M:%S')] 创建日志目录：$LOG_DIR" >> "$LOG_FILE"
fi

# 若日志文件不存在则创建
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    echo "[$(date '+%Y/%m/%d %H:%M:%S')] 创建日志文件：$LOG_FILE" >> "$LOG_FILE"
fi

log() {
    echo "[$(date '+%Y/%m/%d %H:%M:%S')] $1" >> $LOG_FILE
}

# ======================
# 执行库级别备份
# 参数: 库名  目标仓库
# ======================
execute_backup() {
    local db=$1
    local target=$2
    log "[DRS] 触发异地备份：$db → $target"
    $MYSQL_CMD -e "BACKUP DATABASE $db SNAPSHOT $BACKUP_NAME TO $target;" >> $LOG_FILE 2>&1
}

# ======================
# 主程序
# ======================
log "=== 启动StarRocks异地备份任务 ==="
execute_backup $PROD_DB "$PROD_REPO" &
execute_backup $UAT_DB "$UAT_REPO" &
wait
log "=== 所有备份指令已发送 ==="
