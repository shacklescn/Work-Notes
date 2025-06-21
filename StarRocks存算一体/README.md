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

-- 下线BE服务
ALTER SYSTEM DECOMMISSION BACKEND "10.84.91.16:9050";

-- 下线多个BE服务
ALTER SYSTEM DECOMMISSION BACKEND "10.84.0.18:9050","10.84.0.19:9050";
      
-- 删除某BE节点
ALTER SYSTEM DROP BACKEND "10.84.0.18:9050";
                  
-- 删除多个BE节点
ALTER SYSTEM DROP BACKEND "10.84.0.18:9050","10.84.0.19:9050";
                  
-- 查询建表时的sql语句也包括查表副本信息
SHOW TABLETS FROM <DB>.<tablename>;
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
SHOW TABLETS FROM hts.statistics_log;
TODO:缺个样例
```
增加成功后再执行DROP指令删除节点
```sql
mysql> ALTER SYSTEM DROP BACKEND "10.84.0.18:9050";
```
