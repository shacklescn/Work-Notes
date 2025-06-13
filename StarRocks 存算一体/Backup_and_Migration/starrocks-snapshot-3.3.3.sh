#!/bin/bash
#前提条件
#注意：s3路径结尾不能加/否则会报错
#CREATE REPOSITORY dev_bak
#WITH BROKER
#ON LOCATION "s3://heatstorage/dev_bak"
#PROPERTIES(
#    "aws.s3.access_key" = "StarRocks",
#    "aws.s3.secret_key" = "SecA@2025...",
#    "aws.s3.endpoint" = "http://10.84.3.46:9000"
#);
#
#CREATE REPOSITORY hts_bak
#WITH BROKER
#ON LOCATION "s3://heatstorage/hts_bak"
#PROPERTIES(
#    "aws.s3.access_key" = "StarRocks",
#    "aws.s3.secret_key" = "SecA@2025...",
#    "aws.s3.endpoint" = "http://10.84.3.46:9000"
#);
#
#CREATE REPOSITORY hts_prod_bak
#WITH BROKER
#ON LOCATION "s3://heatstorage/hts_prod_bak"
#PROPERTIES(
#    "aws.s3.access_key" = "StarRocks",
#    "aws.s3.secret_key" = "SecA@2025...",
#    "aws.s3.endpoint" = "http://10.84.3.46:9000"
#);
#
#CREATE REPOSITORY hts_test_bak
#WITH BROKER
#ON LOCATION "s3://heatstorage/hts_test_bak"
#PROPERTIES(
#    "aws.s3.access_key" = "StarRocks",
#    "aws.s3.secret_key" = "SecA@2025...",
#    "aws.s3.endpoint" = "http://10.84.3.46:9000"
#);
#
#CREATE REPOSITORY prod_bak
#WITH BROKER
#ON LOCATION "s3://heatstorage/prod_bak"
#PROPERTIES(
#    "aws.s3.access_key" = "StarRocks",
#    "aws.s3.secret_key" = "SecA@2025...",
#    "aws.s3.endpoint" = "http://10.84.3.46:9000"
#);
#
#CREATE REPOSITORY test_bak
#WITH BROKER
#ON LOCATION "s3://heatstorage/test_bak"
#PROPERTIES(
#    "aws.s3.access_key" = "StarRocks",
#    "aws.s3.secret_key" = "SecA@2025...",
#    "aws.s3.endpoint" = "http://10.84.3.46:9000"
#);

# ======================
# 核心配置参数
# ======================
LOG_FILE="/var/log/starrocks/starrocks_snapshot.log"
BACKUP_DATE="$(date +%Y%m%d)"
BACKUP_NAME="SNAPSHOT_${BACKUP_DATE}"

PROD_DB="hts_prod"
TEST_DB="hts_test"
MYSQL_CMD="mysql -uroot -h10.84.0.12 -P9030 -p26gaGHTDZUpns7GR"

PROD_REPO="hts_prod_bak"
TEST_REPO="hts_test_bak"

# ======================
# 轻量级日志函数
# ======================
log() {
    echo "[$(date '+%Y/%m/%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

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

# ======================
# 执行库级别备份
# 参数: 库名  目标仓库
# ======================
execute_backup() {
    local db="$1"
    local repo="$2"
    log "[库级备份] 开始备份：$db → $repo"
    $MYSQL_CMD -e "BACKUP SNAPSHOT ${db}.${BACKUP_NAME} TO ${repo};" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log "[库级备份] 成功：$db"
    else
        log "[库级备份] 失败：$db"
    fi
}

# ======================
# 执行表级别备份
# 参数: 库名  目标仓库  表名列表
# ======================
execute_table_backup() {
    local db="$1"
    local repo="$2"
    shift 2
    local tables=("$@")
    local table_list=$(IFS=, ; echo "${tables[*]}")
    log "[表级备份] 开始备份：$db → $repo，表：${table_list}"
    $MYSQL_CMD -e "BACKUP SNAPSHOT ${db}.${BACKUP_NAME} TO ${repo} ON (${table_list});" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log "[表级备份] 成功：$db"
    else
        log "[表级备份] 失败：$db"
    fi
}

# ======================
# 主程序
# ======================
log "=== 启动 StarRocks 备份任务：${BACKUP_NAME} ==="

# 表级备份任务（可按需增删）
execute_table_backup dev dev_bak \
    device_realtime_data_history device_history_message device_dict_data_statistics \
    kafka_message device_key_data unit_device_switch day_status device_event_record

execute_table_backup hts hts_bak \
    device_history_message device_key_data device_dict_data_statistics statistics_log

execute_table_backup prod prod_bak \
    device_realtime_data_history device_history_message device_dict_data_statistics \
    kafka_message device_key_data unit_device_switch day_status device_event_record

execute_table_backup test test_bak \
    device_realtime_data_history device_history_message device_dict_data_statistics \
    kafka_message device_key_data unit_device_switch day_status device_event_record

# 异步库级别备份
execute_backup "$PROD_DB" "$PROD_REPO" &
execute_backup "$TEST_DB" "$TEST_REPO" &
wait

log "=== 所有备份任务已完成 ==="

