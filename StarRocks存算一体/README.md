# StarRocks 存算一体运维手册
| 路径类型                  | 功能描述             |
|-----------------------|------------------|
| Backup_and_Migration  | 实现数据备份与迁移功能      |
| Rolling_Migration     | 以服务不停机的方式实现数据迁移  |
# 常用命令使用手册
```sql
-- 查询FE服务状态
SHOW FRONTENDS\G;

-- 查询BE服务状态
SHOW PROC '/backends'\G;

-- 添加BE服务 
ALTER SYSTEM ADD BACKEND "10.84.91.10:9050"
      
-- 添加FE服务        
ALTER SYSTEM ADD FOLLOWER "10.84.91.10:9010";

-- 下线BE服务
ALTER SYSTEM DECOMMISSION BACKEND "10.84.91.16:9050";

-- 下线多个BE服务
ALTER SYSTEM DECOMMISSION BACKEND "10.84.0.18:9050","10.84.0.19:9050";
      
-- 删除某BE节点
ALTER SYSTEM DROP BACKEND "10.84.0.18:9050";
                  
-- 删除多个BE节点
ALTER SYSTEM DROP BACKEND "10.84.0.18:9050","10.84.0.19:9050";
                  
-- 查询建表时的sql语句也包括查表副本信息
SHOW CREATE TABLE <DB>.<tablename>;
```
# FQA
# 1、在删除某个be节点时报错 某些表只有一个副本时 需增加副本后 再进行删除BE节点
## 具体报错：

```sql
mysql> ALTER SYSTEM DROP BACKEND "10.84.91.16:9050";
ERROR 1064 (HY000): Tables such as [hts.statistics_log] on the backend[10.84.91.16:9050] have only one replica. To avoid data loss, please change the replication_num of [hts.statistics_log] to three. ALTER SYSTEM DROP BACKEND <backends> FORCE can be used to forcibly drop the backend.
```
## 解决方法:

将报错的这个表副本数增加 增加到2个以上，比如增加至3个
```sql
ALTER TABLE hts.statistics_log SET ("replication_num" = "3");
```
验证是否增加成功
```sql
mysql> SHOW CREATE TABLE hts.statistics_log;
+----------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Table          | Create Table                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
    +----------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    | statistics_log | CREATE TABLE `statistics_log` (
                                                         `enterprise_id` bigint(20) NULL COMMENT "企业编号",
                                                         `station_id` bigint(20) NULL COMMENT "站点唯一id",
                                                         `device_number` varchar(255) NOT NULL COMMENT "设备唯一id",
                                                         `dict_code` varchar(255) NOT NULL COMMENT "指标编码",
                                                         `end_time` datetime NULL COMMENT "窗口结束时间",
                                                         `end_time_long` bigint(20) NOT NULL COMMENT "窗口结束时间戳",
                                                         `business_type` varchar(11) NOT NULL COMMENT "业务类型 max-步长窗口最大值 min-步长窗口最小值 first-步长窗口第一个值 last-步长窗口最后一个值 sum-窗口数据求和 variance - 方差 stdev - 标准差",
                                                         `device_model_number` varchar(255) NULL COMMENT "设备型号",
                                                         `data_zone` bigint(20) NOT NULL COMMENT "数据逻辑分区 0-99",
                                                         `product_id` varchar(32) NULL COMMENT "产品ID",
                                                         `error_message` varchar(255) NULL COMMENT "错误信息",
                                                         `begin_time` datetime NOT NULL COMMENT "窗口开始时间",
                                                         `begin_time_long` bigint(20) NOT NULL COMMENT "窗口开始时间戳",
                                                         `step` int(11) NULL COMMENT "统计步长"
                       ) ENGINE=OLAP 
DUPLICATE KEY(`enterprise_id`, `station_id`, `device_number`)
COMMENT "OLAP"
DISTRIBUTED BY RANDOM
PROPERTIES (
"bucket_size" = "4294967296",
"compression" = "LZ4",
"fast_schema_evolution" = "true",
"replicated_storage" = "true",
"replication_num" = "3"  -- 已变成3副本 增加成功
); |
+----------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
1 row in set (0.12 sec)
```
增加成功后再执行DROP指令删除节点
```sql
mysql> ALTER SYSTEM DROP BACKEND "10.84.0.18:9050";
```
