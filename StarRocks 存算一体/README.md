# StarRocks 存算一体架构的备份与恢复
官方地址：https://docs.starrocks.io/zh/docs/3.4/administration/management/Backup_and_restore/#%E5%88%9B%E5%BB%BA%E4%BB%93%E5%BA%93

StarRocks 支持将数据以快照文件的形式备份到远端存储系统中，或将备份的数据从远端存储系统恢复至任意 StarRocks 集群。通过这个功能，您可以定期为 StarRocks 集群中的数据进行快照备份，或者将数据在不同 StarRocks 集群间迁移。 从 v3.4.0 开始，StarRocks 进一步增强了备份恢复功能，支持了更多对象，并且重构语法以提高灵活性。

StarRocks 支持在以下外部存储系统中备份数据：

Apache™ Hadoop® （HDFS）集群

AWS S3

Google GCS

阿里云 OSS

腾讯云 COS

华为云 OBS

MinIO

StarRocks 支持备份以下对象：

内部数据库、表（所有类型和分区策略）和分区

External Catalog 的元数据（自 v3.4.0 开始支持）

同步物化视图和异步物化视图

逻辑视图（自 v3.4.0 开始支持）

UDF（自 v3.4.0 开始支持）

说明：

**StarRocks 存算分离集群不支持数据备份和恢复。**

# 创建仓库
要使用快照备份的功能首先要创建仓库，仓库用于在远端存储系统中存储备份文件。备份数据前，您需要基于远端存储系统路径在 StarRocks 中创建仓库。您可以在同一集群中创建多个仓库。详细使用方法参阅 [CREATE REPOSITORY](https://docs.starrocks.io/zh/docs/3.4/sql-reference/sql-statements/backup_restore/CREATE_REPOSITORY/)。
## 在 MinIO 中创建仓库
以下示例在 MinIO 存储空间 starrocks  Bucket中创建仓库 green_pioneer_iot_prod_bak。
```sql
CREATE REPOSITORY green_pioneer_iot_prod_bak
WITH BROKER
ON LOCATION "s3://starrocks/green_pioneer_prod_uat_bak"
PROPERTIES(
   "aws.s3.access_key" = "StarRocks",
   "aws.s3.secret_key" = "SecA@2025...",
   "aws.s3.endpoint" = "http://10.84.3.46:9000"
);
```
仓库创建完成后，您可以通过 [SHOW REPOSITORIES](https://docs.starrocks.io/zh/docs/3.4/sql-reference/sql-statements/backup_restore/SHOW_REPOSITORIES/) 查看已创建的仓库。完成数据恢复后，您可以通过 [DROP REPOSITORY](https://docs.starrocks.io/zh/docs/3.4/sql-reference/sql-statements/backup_restore/DROP_REPOSITORY/) 语句删除 StarRocks 中的仓库。但备份在远端存储系统中的快照数据目前无法通过 StarRocks 直接删除，您需要手动删除备份在远端存储系统的快照路径。

# 备份数据
创建数据仓库后，您可以通过 [BACKUP](https://docs.starrocks.io/zh/docs/3.4/sql-reference/sql-statements/backup_restore/BACKUP/) 命令创建数据快照并将其备份至远端仓库。数据备份为异步操作。您可以通过 [SHOW BACKUP](https://docs.starrocks.io/zh/docs/3.4/sql-reference/sql-statements/backup_restore/SHOW_BACKUP/) 语句查看备份作业状态，或通过 [CANCEL BACKUP](https://docs.starrocks.io/zh/docs/3.4/sql-reference/sql-statements/backup_restore/CANCEL_BACKUP/) 语句取消备份作业。

StarRocks 支持以数据库、表、或分区为粒度全量备份数据。

当表的数据量很大时，建议您按分区分别执行，以降低失败重试的代价。如果您需要对数据进行定期备份，建议您在建表时制定分区策略策略，从而可以在后期运维过程中，仅定期备份新增分区中的数据。
## 备份数据库
对数据库执行完全备份将备份数据库中的所有表、物化视图、逻辑视图和 UDF。

以下示例为数据库 green_pioneer_iot_prod 创建数据快照 green_pioneer_iot_prod_xxxxx 并备份至仓库 green_pioneer_iot_prod_bak 中。
```sql
-- 自 v3.4.0 起支持。
BACKUP DATABASE green_pioneer_iot_prod SNAPSHOT green_pioneer_iot_prod_xxxxx
TO green_pioneer_iot_prod_bak;

-- 兼容先前版本语法。
BACKUP SNAPSHOT green_pioneer_iot_prod.green_pioneer_iot_prod_xxxxx
TO green_pioneer_iot_prod_bak;
```
## 验证备份数据库是否成功
```sql
mysql> SHOW BACKUP FROM green_pioneer_iot_prod\G;
*************************** 1. row ***************************
               JobId: 20844445
        SnapshotName: BACKUP_20250613
              DbName: green_pioneer_iot_prod
               State: FINISHED
          BackupObjs: [green_pioneer_iot_prod.access_people_online], [green_pioneer_iot_prod.am_103_properties], [green_pioneer_iot_prod.am_308_properties], [green_pioneer_iot_prod.broad_link_event], [green_pioneer_iot_prod.broad_link_properties], [green_pioneer_iot_prod.carrier_properties], [green_pioneer_iot_prod.controllable_charging_station_properties], [green_pioneer_iot_prod.cpu_room_evn_properties], [green_pioneer_iot_prod.device_history_message], [green_pioneer_iot_prod.device_key_data], [green_pioneer_iot_prod.ems_properties], [green_pioneer_iot_prod.fan_coil_unit_properties], [green_pioneer_iot_prod.fire_protection_system_properties], [green_pioneer_iot_prod.gas_detector_properties], [green_pioneer_iot_prod.grid_side_elec_meter_properties], [green_pioneer_iot_prod.heat_pump_source_properties], [green_pioneer_iot_prod.heat_storage_properties], [green_pioneer_iot_prod.insert_row_energy], [green_pioneer_iot_prod.insert_row_properties], [green_pioneer_iot_prod.mathematical_science_carStatistic_properties], [green_pioneer_iot_prod.mathematical_science_deviceData_properties], [green_pioneer_iot_prod.mathematical_science_pedestrian_properties], [green_pioneer_iot_prod.mathematical_science_visitorData_properties], [green_pioneer_iot_prod.metal1v1_properties], [green_pioneer_iot_prod.metal_properties], [green_pioneer_iot_prod.mini_reaction_kettle_properties], [green_pioneer_iot_prod.mitsubishi_properties], [green_pioneer_iot_prod.pdg_properties], [green_pioneer_iot_prod.predict_weather_properties], [green_pioneer_iot_prod.pv_properties], [green_pioneer_iot_prod.sever_model_properties], [green_pioneer_iot_prod.temp_computer_room_properties], [green_pioneer_iot_prod.thermal_energy_storage_meter_properties], [green_pioneer_iot_prod.total_combine_active_energy], [green_pioneer_iot_prod.total_combine_active_energy_has_index], [green_pioneer_iot_prod.uncontrollable_charging_station_properties], [green_pioneer_iot_prod.ups_properties], [green_pioneer_iot_prod.vertical_ladder_BwmsjData_properties], [green_pioneer_iot_prod.vertical_ladder_ByData_properties], [green_pioneer_iot_prod.vertical_ladder_Gdata_properties], [green_pioneer_iot_prod.vertical_ladder_JqrData_properties], [green_pioneer_iot_prod.vertical_ladder_JxgdData_properties], [green_pioneer_iot_prod.vertical_ladder_properties], [green_pioneer_iot_prod.weather_properties], [green_pioneer_iot_prod.ws_203_properties], [green_pioneer_iot_prod.wts_305_properties], [green_pioneer_iot_prod.wts_506_properties]
          CreateTime: 2025-06-13 02:00:02
SnapshotFinishedTime: 2025-06-13 02:00:21
  UploadFinishedTime: 2025-06-13 03:22:56
        FinishedTime: 2025-06-13 03:23:04
     UnfinishedTasks: 
            Progress: 
          TaskErrMsg: 
              Status: [OK]
             Timeout: 86400
1 row in set (0.00 sec)
 
-- State: FINISHED 代表备份成功
```
备份作业当前所在阶段：
- PENDING：作业初始状态。
- SNAPSHOTING：正在进行快照操作。
- UPLOAD_SNAPSHOT：快照结束，准备上传。
- UPLOADING：正在上传快照。
- SAVE_META：正在本地生成元数据文件。
- UPLOAD_INFO：上传元数据文件和本次备份作业的信息。
- FINISHED：备份完成。
- CANCELLED：备份失败或被取消。

## 备份表
StarRocks 支持备份和恢复所有类型和分区策略的表。对表进行完全备份会备份表中数据以及在其上建立的同步物化视图。

以下示例将数据库 green_pioneer_iot_prod 中的表 device_realtime_data_history 备份到快照 green_pioneer_iot_prod_xxxxx 中，并将快照上传到仓库 green_pioneer_iot_prod_bak。
```sql
-- 自 v3.4.0 起支持。单表
BACKUP DATABASE green_pioneer_iot_prod SNAPSHOT green_pioneer_iot_prod_xxxxx
TO green_pioneer_iot_prod_bak
ON (TABLE device_realtime_data_history);

-- 兼容先前版本语法。 单表
BACKUP SNAPSHOT green_pioneer_iot_prod.green_pioneer_iot_prod_xxxxx
TO green_pioneer_iot_prod_bak
ON (`device_realtime_data_history`);

-- 兼容先前版本语法。 多表
BACKUP SNAPSHOT green_pioneer_iot_prod.green_pioneer_iot_prod_xxxxx
TO green_pioneer_iot_prod_bak
ON (`device_realtime_data_history`, `device_history_message`, `device_dict_data_statistics`, `kafka_message`, `device_key_data`, `unit_device_switch`, `day_status`, `device_event_record`);
```
## 验证备份表是否成功
```sql
mysql> SHOW BACKUP FROM green_pioneer_iot_prod\G;
*************************** 1. row ***************************
               JobId: 17068181
        SnapshotName: SNAPSHOT_20250613
              DbName: green_pioneer_iot_prod
               State: FINISHED
          BackupObjs: [green_pioneer_iot_prod.device_realtime_data_history], [green_pioneer_iot_prod.device_history_message], [green_pioneer_iot_prod.device_dict_data_statistics], [green_pioneer_iot_prod.kafka_message], [green_pioneer_iot_prod.device_key_data], [green_pioneer_iot_prod.unit_device_switch], [green_pioneer_iot_prod.day_status], [green_pioneer_iot_prod.device_event_record]
          CreateTime: 2025-06-13 16:55:52
SnapshotFinishedTime: 2025-06-13 16:57:15
  UploadFinishedTime: 2025-06-13 19:24:20
        FinishedTime: 2025-06-13 19:24:31
     UnfinishedTasks: 
            Progress: 
          TaskErrMsg: 
              Status: [OK]
             Timeout: 86400
1 row in set (0.00 sec)
-- State: FINISHED  代表备份成功
-- BackupObjs是指备份的表信息 由库和表名组成
```
备份作业当前所在阶段：
- PENDING：作业初始状态。
- SNAPSHOTING：正在进行快照操作。
- UPLOAD_SNAPSHOT：快照结束，准备上传。
- UPLOADING：正在上传快照。
- SAVE_META：正在本地生成元数据文件。
- UPLOAD_INFO：上传元数据文件和本次备份作业的信息。
- FINISHED：备份完成。
- CANCELLED：备份失败或被取消。
说明：

**在3.4以下不包括3.4版本 只能备份表引擎为OLAP的(ENGINE=OLAP) 不能备份External Catalog(外表)的元数据**

# 恢复数据
您可以将备份至远端仓库的数据快照恢复到当前或其他 StarRocks 集群，完成数据恢复或迁移。

从快照还原数据时，必须指定快照的时间戳。

通过 [RESTORE](https://docs.starrocks.io/zh/docs/3.4/sql-reference/sql-statements/backup_restore/RESTORE/) 语句将远端仓库中的数据快照恢复至当前或其他 StarRocks 集群以恢复或迁移数据。

数据恢复为异步操作。您可以通过 [SHOW RESTORE](https://docs.starrocks.io/zh/docs/3.4/sql-reference/sql-statements/backup_restore/SHOW_RESTORE/) 语句查看恢复作业状态，或通过 [CANCEL RESTORE](https://docs.starrocks.io/zh/docs/3.4/sql-reference/sql-statements/backup_restore/CANCEL_RESTORE/) 语句取消恢复作业。

## 在新集群中创建仓库（可选）
如需将数据迁移至其他 StarRocks 集群，您需要在新集群中使用相同仓库名和地址创建仓库，否则将无法查看先前备份的数据快照。详细信息见 创建仓库。

## 获取快照时间戳
开始恢复或迁移前，您可以通过 [SHOW SNAPSHOT](https://docs.starrocks.io/zh/docs/3.4/sql-reference/sql-statements/backup_restore/SHOW_SNAPSHOT/) 查看特定仓库获取对应数据快照的时间戳。
以下示例查看仓库 green_pioneer_iot_prod_bak 中的数据快照信息。
```sql
mysql> SHOW SNAPSHOT ON green_pioneer_iot_prod_bak;
+-------------------+-------------------------+--------+
| Snapshot          | Timestamp               | Status |
+-------------------+-------------------------+--------+
| SNAPSHOT_20250613 | 2025-06-13-08-55-52-494 | OK     |
+-------------------+-------------------------+--------+
1 row in set (0.08 sec)
```
## 恢复数据库
以下示例将快照 SNAPSHOT_20250612 中的数据库 green_pioneer_iot_prod, 还原到目标群集中的数据库 green_pioneer_iot_prod。如果快照中不存在该数据库，系统将返回错误。如果目标群集中不存在该数据库，系统将自动创建该数据库。
```sql
-- 自 v3.4.0 起支持。
RESTORE SNAPSHOT SNAPSHOT_20250613
FROM green_pioneer_iot_prod_bak
DATABASE green_pioneer_iot_prod
PROPERTIES("backup_timestamp" = "2025-06-13-08-55-52-494");

-- 兼容先前版本语法。
RESTORE SNAPSHOT green_pioneer_iot_prod.SNAPSHOT_20250613
FROM `green_pioneer_iot_prod_bak` 
PROPERTIES("backup_timestamp" = "2025-06-13-08-55-52-494");
```
## 验证恢复状态
```sql
StarRocks: SHOW RESTORE FROM green_pioneer_iot_prod\G;
*************************** 1. row ***************************
               JobId: 25668
               Label: SNAPSHOT_20250613
           Timestamp: 2025-06-13-08-55-52-494
              DbName: green_pioneer_iot_prod
               State: FINISHED
           AllowLoad: false
      ReplicationNum: 1
         RestoreObjs: device_realtime_data_history, device_history_message, device_dict_data_statistics, kafka_message, device_key_data, unit_device_switch, day_status, device_event_record
          CreateTime: 2025-06-13 14:57:01
    MetaPreparedTime: 2025-06-13 14:57:04
SnapshotFinishedTime: 2025-06-13 14:57:07
DownloadFinishedTime: 2025-06-13 14:57:46
        FinishedTime: 2025-06-13 14:57:52
     UnfinishedTasks: 
            Progress: 
          TaskErrMsg: 
              Status: [OK]
             Timeout: 86400
1 row in set (0.00 sec)
```
恢复作业当前所在阶段：
- PENDING：作业初始状态。
- SNAPSHOTING：正在进行本地新建表的快照操作。
- DOWNLOAD：正在发送下载快照任务。
- DOWNLOADING：快照正在下载。
- COMMIT：准备生效已下载的快照。
- COMMITTING：正在生效已下载的快照。
- FINISHED：恢复完成。
- CANCELLED：恢复失败或被取消。
## 恢复报错合集
### 1. 迁移时备份的是集群的数据  要恢复到单节点中会报错
例如以下错误
```sql
StarRocks: SHOW RESTORE\G;
*************************** 1. row ***************************
               JobId: 25655
               Label: BACKUP_20250612
           Timestamp: 2025-06-12-06-44-37-167
              DbName: hts_prod
               State: CANCELLED
           AllowLoad: false
      ReplicationNum: 3
         RestoreObjs: device_dict_data_statistics, device_history_message, device_key_data, statistics_log
          CreateTime: 2025-06-12 14:49:09
    MetaPreparedTime: NULL
SnapshotFinishedTime: NULL
DownloadFinishedTime: NULL
        FinishedTime: 2025-06-12 14:49:10
     UnfinishedTasks: 
            Progress: 
          TaskErrMsg: 
              Status: [COMMON_ERROR, msg: failed to find 3 different hosts to create table: device_dict_data_statistics]
             Timeout: 86400
*************************** 2. row ***************************
               JobId: 25662
               Label: BACKUP_20250612
           Timestamp: 2025-06-12-06-44-37-344
              DbName: hts_test
               State: CANCELLED
           AllowLoad: false
      ReplicationNum: 3
         RestoreObjs: device_dict_data_statistics, device_history_message, device_key_data, statistics_log
          CreateTime: 2025-06-12 14:50:00
    MetaPreparedTime: NULL
SnapshotFinishedTime: NULL
DownloadFinishedTime: NULL
        FinishedTime: 2025-06-12 14:50:01
     UnfinishedTasks: 
            Progress: 
          TaskErrMsg: 
              Status: [COMMON_ERROR, msg: failed to find 3 different hosts to create table: device_dict_data_statistics]
             Timeout: 86400
```
意思是StarRocks 无法在当前集群中找到足够的 Backend 节点 来满足该表的副本需求（ReplicationNum: 3）。因为集群中默认副本是3副本，恢复时要写入3个Backend 节点，导入单节点中时只有1个Backend 节点，无法满足需求
解决办法：
恢复时，在SQL语句中显示指定1个副本
```sql
RESTORE SNAPSHOT BACKUP_20250612
FROM hts_prod_bak
DATABASE hts_prod
PROPERTIES("backup_timestamp" = "2025-06-12-06-44-37-167",
"replication_num" = "1"
);


RESTORE SNAPSHOT BACKUP_20250612
FROM hts_test_bak
DATABASE hts_test
PROPERTIES("backup_timestamp" = "2025-06-12-06-44-37-344",
"replication_num" = "1"
);
```
# StarRocks 定时备份脚本
## StarRocks 3.4 以上 定时备份库的脚本
```shell
StarRocks/Backup_and_Migration/starrocks-snapshot.sh
```

## StarRocks 3.4以下不包括3.4 定时备份库和表的脚本
```shell
StarRocks/Backup_and_Migration/starrocks-snapshot-3.3.3.sh
```

## 使用方法
```shell
git clone https://github.com/shacklescn/Work-Notes.git

cd Work-Notes/StarRocks/Backup_and_Migration

#写入crontab
root@starrocks:~# crontab -l
# StarRocks snapshot备份 每台凌晨2点钟执行备份数据
0 2 * * * /Work-Notes/StarRocks/Backup_and_Migration/starrocks-snapshot.sh
```

## 修改脚本的变量部分
```shell
# starrocks-snapshot.sh
#脚本注释部分必须要提前创建   备份仓库   拿其中一个举例
# CREATE REPOSITORY green_pioneer_iot_prod_bak                #green_pioneer_iot_prod_bak 备份仓库名  可自定义
# WITH BROKER
# ON LOCATION "s3://starrocks/green_pioneer_prod_uat_bak"     #存储在minio 的哪个Bucket下的哪个路径
# PROPERTIES(
#    "aws.s3.access_key" = "StarRocks",             #备份仓库的minio AK
#    "aws.s3.secret_key" = "SecA@2025...",          #备份仓库的minio SK
#    "aws.s3.endpoint" = "http://10.84.3.46:9000"   #备份仓库的minio 地址
# );

PROD_DB="green_pioneer_iot_prod"  #需要备份的库名
UAT_DB="green_pioneer_iot_uat"    #需要备份的库名
MYSQL_CMD="mysql -uroot -h10.84.0.106 -P9030 -peQ59z!2HJwA2r"  #StarRocks fe leader的地址 和 用户名密码
PROD_REPO="green_pioneer_iot_prod_bak"  #备份的仓库 
UAT_REPO="green_pioneer_iot_uat_bak"    #备份的仓库



# starrocks-snapshot-3.3.3.sh
#脚本注释部分必须要提前创建   备份仓库   拿其中一个举例
#CREATE REPOSITORY dev_bak
#WITH BROKER
#ON LOCATION "s3://heatstorage/dev_bak"
#PROPERTIES(
#    "aws.s3.access_key" = "StarRocks",
#    "aws.s3.secret_key" = "SecA@2025...",
#    "aws.s3.endpoint" = "http://10.84.3.46:9000"
#);

PROD_DB="hts_prod"       #需要备份的库名
TEST_DB="hts_test"       #需要备份的库名
MYSQL_CMD="mysql -uroot -h10.84.0.12 -P9030 -p26gaGHTDZUpns7GR"   #StarRocks fe leader的地址 和 用户名密码

PROD_REPO="hts_prod_bak"      #备份的仓库 
TEST_REPO="hts_test_bak"      #备份的仓库

execute_table_backup dev dev_bak \  #第一个参数dev 是需要备份的数据库的名字 第二个参数dev_bak是备份仓库的名字 下面是备份数据库中的哪些表 有多个就用以下方式写上
    device_realtime_data_history device_history_message device_dict_data_statistics \
    kafka_message device_key_data unit_device_switch day_status device_event_record
```
