# 环境规划
| 服务器角色 | 组件版本 | IP 示例 | 部署服务 | 系统版本 |
|:-----------|:--------:|:--------:|:----------|:----------|
| HAProxy + Router1 | - | 10.0.0.200 | HAProxy、Keepalived、MySQL Router 实例1 | Ubuntu 24.04.3 LTS |
| HAProxy + Router2 | - | 10.0.0.201 | HAProxy、Keepalived、MySQL Router 实例2 | Ubuntu 24.04.3 LTS |
| Virtual IP Address | - | 10.0.0.202 | - | Ubuntu 24.04.3 LTS |
| MySQL PRIMARY | 8.0.44 | 10.0.0.203 | MySQL InnoDB Cluster（主） | Ubuntu 24.04.3 LTS |
| MySQL SECONDARY01 | 8.0.44 | 10.0.0.204 | MySQL InnoDB Cluster（从） | Ubuntu 24.04.3 LTS |
| MySQL SECONDARY02 | 8.0.44 | 10.0.0.205 | MySQL InnoDB Cluster（从） | Ubuntu 24.04.3 LTS |
# 架构特点
- 数据库层：3 台 MySQL 节点，组成 InnoDB Cluster，确保数据高可用。
- 中间件层：2 台服务器同时运行 HAProxy、Keepalived 和 MySQL Router，避免单点故障。

# 系统优化
```shell
cat >> /etc/security/limits.conf << EOF
* soft nofile 655360
* hard nofile 131072
* soft nproc 655350
* hard nproc 655350
* soft memlock unlimited
* hard memlock unlimited
EOF
```
# Hosts文件配置(所有机器都要设置)
```
10.0.0.203 mysql-cls-01 PRIMARY
10.0.0.204 mysql-cls-02 SECONDARY01
10.0.0.205 mysql-cls-03 SECONDARY02
```
# 安装 MySQL （MySQL所有节点都要做）
## 安装依赖
```shell
apt install -y libaio-dev && \
ln -s /lib/x86_64-linux-gnu/libaio.so.1t64 /lib/x86_64-linux-gnu/libaio.so.1
```
## 创建数据目录和运行账户
```shell
mkdir -p /data/mysql/{binlogs,conf,data,log,run} && \
  useradd mysql -s /usr/sbin/nologin && \
  chown -R mysql:mysql /data/mysql
```
## 解压二进制文件至指定目录
```shell
# root@PRIMARY:~# ls
# mysql-8.0.44-linux-glibc2.28-x86_64.tar.xz
mkdir -p /apps/ && \
  tar xf mysql-8.0.44-linux-glibc2.28-x86_64.tar.xz \
  --transform 's/mysql-8.0.44-linux-glibc2.28-x86_64/mysql/' \
  -C /apps/ && \
  chown -R mysql:mysql /apps/mysql
```
## 创建MySQL配置文件
```shell
cat > /data/mysql/conf/my.cnf << EOF 
[mysqld]
# 基础配置
pid-file        = /data/mysql/run/mysqld.pid
socket          = /data/mysql/run/mysql.sock
datadir         = /data/mysql/data
secure-file-priv= NULL
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0
server-id=1

# 允许最大连接数
max_connections=2000
# 允许连接失败的次数
max_connect_errors=500
# 限制server接受的数据包大小
max_allowed_packet = 1G

# 存储引擎和字符集配置
default-storage-engine=INNODB
# 默认使用"mysql_native_password"插件认证
default_authentication_plugin=mysql_native_password
lower_case_table_names=1
sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'
log_timestamps=SYSTEM
# 服务端使用的字符集默认为UTF8
character-set-server=utf8

# 复制与GTID配置
log_bin = /data/mysql/binlogs/mysql-bin
binlog_format = ROW
gtid_mode = ON
enforce_gtid_consistency = ON
log_slave_updates = ON
binlog_transaction_dependency_tracking = WRITESET

# MGR插件配置
plugin_load_add = 'group_replication.so'
group_replication_group_name = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"  # 唯一UUID
group_replication_start_on_boot = OFF
group_replication_bootstrap_group = OFF
group_replication_single_primary_mode = ON   # 单主模式
group_replication_local_address = "mysql-cls-01:33061"  # 当前节点通信地址
group_replication_group_seeds = "mysql-cls-01:33061,mysql-cls-02:33061,mysql-cls-03:33061"  # 所有节点地址

#------------- log ---------------
log-error                   = /data/mysql/log/mysql_error.log
# 记录慢查询语句
slow_query_log              = on
long_query_time             = 5
slow_query_log_file         = /data/mysql/log/slow_query.log
# 通用查询日志
general_log                 = on
general_log_file            = /data/mysql/log/general.log

#------------- binlog ---------------
# binlog日志保留时间
expire_logs_days            = 7
# 当每进行n次事务提交之后，将binlog_cache中的数据写入磁盘
sync_binlog                 = 100
binlog_cache_size           = 2M

#------------- timeout ----------------
connect_timeout             = 30
net_read_timeout            = 60
interactive_timeout         = 1800
wait_timeout                = 1800

#------------- innodb -------------
innodb_file_per_table               = 1
# 数据库缓冲池大小,建议服务器内存的50~70%
innodb_buffer_pool_size             = 5G
# mysql事务日志文件（ib_logfile0）的大小
innodb_log_file_size                = 512M

[mysql]
# 设置mysql客户端默认字符集
default-character-set=utf8

[client]
# 设置mysql客户端连接服务端时默认使用的端口
port=3306
socket=/data/mysql/run/mysql.sock
EOF
```

## 创建MySQL Service文件
```shell
cat > /etc/systemd/system/mysqld.service << EOF
After=syslog.target
 
[Install]
WantedBy=multi-user.target
 
[Service]
User=mysql
Group=mysql
 
Type=simple
 
# Disable service start and stop timeout logic of systemd for mysqld service.
TimeoutSec=0
 
# Execute pre and post scripts as root
PermissionsStartOnly=true
 
# Needed to create system tables
# ExecStartPre=/usr/bin/mysqld_pre_systemd
 
# Start main service
ExecStart=/apps/mysql/bin/mysqld_safe \
          --defaults-file=/data/mysql/conf/my.cnf \
          --datadir=/data/mysql/data \
          --user=mysql
 
# Use this to switch malloc implementation
# EnvironmentFile=-/etc/sysconfig/mysql
 
# Sets open_files_limit
LimitNOFILE = 65565
 
Restart=on-failure
Restart=always
RestartSec=5
 
RestartPreventExitStatus=1
 
# Set enviroment variable MYSQLD_PARENT_PID. This is required for restart.
Environment=MYSQLD_PARENT_PID=1
 
PrivateTmp=false
EOF
```

## 初始化MySQL
```shell
/apps/mysql/bin/mysqld --initialize --user=mysql --basedir=/apps/mysql --datadir=/data/mysql/data --lower-case-table-names=1

#root@PRIMARY:~# /apps/mysql/bin/mysqld --initialize --user=mysql --basedir=/apps/mysql --datadir=/data/mysql/data --lower-case-table-names=1
#2025-11-17T05:12:45.953442Z 0 [System] [MY-013169] [Server] /apps/mysql/bin/mysqld (mysqld 8.0.44) initializing of server in progress as process 66703
#2025-11-17T05:12:45.958312Z 1 [System] [MY-013576] [InnoDB] InnoDB initialization has started.
#2025-11-17T05:12:46.193265Z 1 [System] [MY-013577] [InnoDB] InnoDB initialization has ended.
#2025-11-17T05:12:47.309305Z 6 [Note] [MY-010454] [Server] A temporary password is generated for root@localhost: #+QGNa6+GAP7     # 连接密码
```
## 启动MySQL
```shell
systemctl start mysqld && systemctl status mysqld

# 查看启动日志
#tail -f /data/mysql/log/mysql_error.log
#2025-11-17T05:12:55.496951Z mysqld_safe Starting mysqld daemon with databases from /data/mysql/data
#025-11-17T13:12:55.679081+08:00 0 [Warning] [MY-011070] [Server] 'Disabling symbolic links using --skip-symbolic-links (or equivalent) is the default. Consider not using this option as it' is deprecated and will be removed in a future release.
#2025-11-17T13:12:55.679103+08:00 0 [Warning] [MY-011070] [Server] 'binlog_format' is deprecated and will be removed in a future release.
#2025-11-17T13:12:55.679113+08:00 0 [Warning] [MY-011068] [Server] The syntax 'log_slave_updates' is deprecated and will be removed in a future release. Please use log_replica_updates instead.
#2025-11-17T13:12:55.679117+08:00 0 [Warning] [MY-011069] [Server] The syntax '--binlog-transaction-dependency-tracking' is deprecated and will be removed in a future release.
#2025-11-17T13:12:55.679134+08:00 0 [Warning] [MY-011068] [Server] The syntax 'expire-logs-days' is deprecated and will be removed in a future release. Please use binlog_expire_logs_seconds instead.
#2025-11-17T13:12:55.679216+08:00 0 [Warning] [MY-010918] [Server] 'default_authentication_plugin' is deprecated and will be removed in a future release. Please use authentication_policy instead.
#2025-11-17T13:12:55.679226+08:00 0 [System] [MY-010116] [Server] /apps/mysql/bin/mysqld (mysqld 8.0.44) starting as process 67367
#2025-11-17T13:12:55.680338+08:00 0 [Warning] [MY-013242] [Server] --character-set-server: 'utf8' is currently an alias for the character set UTF8MB3, but will be an alias for UTF8MB4 in a future release. Please consider using UTF8MB4 in order to be unambiguous.
#2025-11-17T13:12:55.688323+08:00 0 [Warning] [MY-013907] [InnoDB] Deprecated configuration parameters innodb_log_file_size and/or innodb_log_files_in_group have been used to compute innodb_redo_log_capacity=1073741824. Please use innodb_redo_log_capacity instead.
#2025-11-17T13:12:55.689400+08:00 1 [System] [MY-013576] [InnoDB] InnoDB initialization has started.
#2025-11-17T13:12:55.958993+08:00 1 [System] [MY-013577] [InnoDB] InnoDB initialization has ended.
#2025-11-17T13:12:56.105259+08:00 0 [Warning] [MY-010068] [Server] CA certificate ca.pem is self signed.
#2025-11-17T13:12:56.105339+08:00 0 [System] [MY-013602] [Server] Channel mysql_main configured to support TLS. Encrypted connections are now supported for this channel.
#2025-11-17T13:12:56.115403+08:00 0 [System] [MY-011323] [Server] X Plugin ready for connections. Bind-address: '::' port: 33060, socket: /tmp/mysqlx.sock
#2025-11-17T13:12:56.115459+08:00 0 [System] [MY-010931] [Server] /apps/mysql/bin/mysqld: ready for connections. Version: '8.0.44'  socket: '/data/mysql/run/mysql.sock'  port: 3306  MySQL Community Server - GPL.
```
## 修改root权限和密码
```sql
-- 安装MySQL客户端 apt install mysql-client -y
-- 连接MySQL 默认只能通过127.0.0.1连接
-- mysql -u root -p#+QGNa6+GAP7 -h 127.0.0.1
mysql> ALTER USER 'root'@'localhost' IDENTIFIED BY 'Kevin_1128'; -- 将初始化生成的临时密码改为你设定的安全密码，不修改无法操作
Query OK, 0 rows affected (0.01 sec)

mysql> CREATE USER 'root'@'%' IDENTIFIED BY 'Kevin_1128';-- 创建允许从任何主机连接的 root 用户
Query OK, 0 rows affected (0.01 sec)

mysql> GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;-- 授予root权限
Query OK, 0 rows affected (0.01 sec)

mysql> FLUSH PRIVILEGES; -- 立即刷新权限，使更改生效
Query OK, 0 rows affected (0.01 sec)
```
## 开启克隆插件（所有MySQL节点）
```sql
-- 安装克隆插件
INSTALL PLUGIN clone SONAME 'mysql_clone.so';

-- 验证插件是否安装成功
SELECT PLUGIN_NAME, PLUGIN_STATUS 
FROM information_schema.plugins 
WHERE PLUGIN_NAME = 'clone';

+-------------+---------------+
| PLUGIN_NAME | PLUGIN_STATUS |
+-------------+---------------+
| clone       | ACTIVE        |
+-------------+---------------+
1 row in set (0.00 sec)
```
# 部署 InnoDB Cluster
## 连接MySQL
```shell
mysql -u root -pKevin_1128 -h mysql-cls-01
```
## 创建集群用户
```sql
mysql> CREATE USER 'repl'@'%' IDENTIFIED BY 'Kevin_1128';
Query OK, 0 rows affected (0.00 sec)

mysql> GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
Query OK, 0 rows affected (0.01 sec)

mysql> GRANT BACKUP_ADMIN ON *.* TO 'repl'@'%';
Query OK, 0 rows affected (0.00 sec)

mysql> GRANT CLONE_ADMIN ON *.* TO 'repl'@'%';
Query OK, 0 rows affected (0.01 sec)

mysql> FLUSH PRIVILEGES;
Query OK, 0 rows affected (0.00 sec)
```
## 创建 InnoDB Cluster
在主节点验证目标实例是否符合加入集群的条件
```sql
-- 检查必要的变量
SELECT 
  VARIABLE_NAME, 
  VARIABLE_VALUE,
  CASE 
    WHEN VARIABLE_NAME = 'server_id' AND VARIABLE_VALUE != '0' THEN 'OK'
    WHEN VARIABLE_NAME = 'gtid_mode' AND VARIABLE_VALUE = 'ON' THEN 'OK'
    WHEN VARIABLE_NAME = 'enforce_gtid_consistency' AND VARIABLE_VALUE = 'ON' THEN 'OK'
    WHEN VARIABLE_NAME = 'log_bin' AND VARIABLE_VALUE = 'ON' THEN 'OK'
    WHEN VARIABLE_NAME = 'binlog_format' AND VARIABLE_VALUE = 'ROW' THEN 'OK'
    ELSE 'CHECK'
  END AS STATUS
FROM performance_schema.global_variables 
WHERE VARIABLE_NAME IN ('server_id', 'gtid_mode', 'enforce_gtid_consistency', 'log_bin', 'binlog_format');
-- 预期输出
+--------------------------+----------------+--------+
| VARIABLE_NAME            | VARIABLE_VALUE | STATUS |
+--------------------------+----------------+--------+
| binlog_format            | ROW            | OK     |
| enforce_gtid_consistency | ON             | OK     |
| gtid_mode                | ON             | OK     |
| log_bin                  | ON             | OK     |
| server_id                | 1              | OK     |
+--------------------------+----------------+--------+
5 rows in set (0.0020 sec)

-- 检查 Group Replication 插件状态
SELECT * FROM information_schema.plugins WHERE plugin_name LIKE '%group_replication%';
-- 预期输出
+-------------------+----------------+---------------+-------------------+---------------------+----------------------+------------------------+--------------------+---------------------------+----------------+-------------+
| PLUGIN_NAME       | PLUGIN_VERSION | PLUGIN_STATUS | PLUGIN_TYPE       | PLUGIN_TYPE_VERSION | PLUGIN_LIBRARY       | PLUGIN_LIBRARY_VERSION | PLUGIN_AUTHOR      | PLUGIN_DESCRIPTION        | PLUGIN_LICENSE | LOAD_OPTION |
+-------------------+----------------+---------------+-------------------+---------------------+----------------------+------------------------+--------------------+---------------------------+----------------+-------------+
| group_replication | 1.1            | ACTIVE        | GROUP REPLICATION | 1.4                 | group_replication.so | 1.11                   | Oracle Corporation | Group Replication (1.1.0) | GPL            | ON          |
+-------------------+----------------+---------------+-------------------+---------------------+----------------------+------------------------+--------------------+---------------------------+----------------+-------------+
```
## 配置 Group Replication
```sql
-- 设置 Group Replication 引导（只在第一个节点执行）
mysql> SET GLOBAL group_replication_bootstrap_group=ON;
Query OK, 0 rows affected (0.00 sec)

-- 启动 Group Replication
mysql> START GROUP_REPLICATION;
Query OK, 0 rows affected (1.09 sec)

-- 关闭引导模式
mysql> SET GLOBAL group_replication_bootstrap_group=OFF;
Query OK, 0 rows affected (0.00 sec)

-- 检查成员状态
mysql> SELECT * FROM performance_schema.replication_group_members;
-- 预期输出
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION | MEMBER_COMMUNICATION_STACK |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| group_replication_applier | 0d8e9d80-c374-11f0-9dec-000c297c6677 | PRIMARY     |        3306 | ONLINE       | PRIMARY     | 8.0.44         | XCom                       |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
1 row in set (0.00 sec)

-- 检查集群状态
SELECT * FROM performance_schema.replication_group_member_stats\G;
*************************** 1. row ***************************
                              CHANNEL_NAME: group_replication_applier
                                   VIEW_ID: 17633622381450665:1
                                 MEMBER_ID: 0d8e9d80-c374-11f0-9dec-000c297c6677
               COUNT_TRANSACTIONS_IN_QUEUE: 0
                COUNT_TRANSACTIONS_CHECKED: 0
                  COUNT_CONFLICTS_DETECTED: 0
        COUNT_TRANSACTIONS_ROWS_VALIDATING: 0
        TRANSACTIONS_COMMITTED_ALL_MEMBERS: 0d8e9d80-c374-11f0-9dec-000c297c6677:1-4,
aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa:1
            LAST_CONFLICT_FREE_TRANSACTION: 
COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE: 0
         COUNT_TRANSACTIONS_REMOTE_APPLIED: 1
         COUNT_TRANSACTIONS_LOCAL_PROPOSED: 0
         COUNT_TRANSACTIONS_LOCAL_ROLLBACK: 0
1 row in set (0.00 sec)
```

## 添加其他节点
### 同步数据（在俩从节点中执行）
```sql
-- 设置允许的克隆捐赠者列表（安全限制）
SET GLOBAL clone_valid_donor_list = 'mysql-cls-01:3306';

-- 从指定捐赠者克隆数据,一次性指令，执行一次只克隆一次（完全覆盖本地数据）
CLONE INSTANCE FROM 'repl'@'mysql-cls-01':3306 IDENTIFIED BY 'Kevin_1128';
```
### 添加节点（在俩从节点中执行）
```sql
CHANGE MASTER TO MASTER_USER='repl', MASTER_PASSWORD='Kevin_1128' FOR CHANNEL 'group_replication_recovery';

START GROUP_REPLICATION;
```
## 验证是否已加入集群
```sql
mysql> SELECT * FROM performance_schema.replication_group_members;
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION | MEMBER_COMMUNICATION_STACK |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| group_replication_applier | 0d8e9d80-c374-11f0-9dec-000c297c6677 | PRIMARY     |        3306 | ONLINE       | PRIMARY     | 8.0.44         | XCom                       |
| group_replication_applier | ac81c4a7-c37c-11f0-9997-000c29673f68 | SECONDARY01 |        3306 | ONLINE       | SECONDARY   | 8.0.44         | XCom                       |
| group_replication_applier | c8d6f280-c37d-11f0-83db-000c29ef5e8a | SECONDARY02 |        3306 | ONLINE       | SECONDARY   | 8.0.44         | XCom                       |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
3 rows in set (0.01 sec)

-- 检查集群状态
mysql> SELECT * FROM performance_schema.replication_group_member_stats\G;
*************************** 1. row ***************************
                              CHANNEL_NAME: group_replication_applier
                                   VIEW_ID: 17633622381450665:7
                                 MEMBER_ID: 0d8e9d80-c374-11f0-9dec-000c297c6677
               COUNT_TRANSACTIONS_IN_QUEUE: 0
                COUNT_TRANSACTIONS_CHECKED: 5
                  COUNT_CONFLICTS_DETECTED: 0
        COUNT_TRANSACTIONS_ROWS_VALIDATING: 0
        TRANSACTIONS_COMMITTED_ALL_MEMBERS: 0d8e9d80-c374-11f0-9dec-000c297c6677:1-4,
aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa:1-10
            LAST_CONFLICT_FREE_TRANSACTION: aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa:6
COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE: 0
         COUNT_TRANSACTIONS_REMOTE_APPLIED: 5
         COUNT_TRANSACTIONS_LOCAL_PROPOSED: 5
         COUNT_TRANSACTIONS_LOCAL_ROLLBACK: 0
*************************** 2. row ***************************
                              CHANNEL_NAME: group_replication_applier
                                   VIEW_ID: 17633622381450665:7
                                 MEMBER_ID: ac81c4a7-c37c-11f0-9997-000c29673f68
               COUNT_TRANSACTIONS_IN_QUEUE: 0
                COUNT_TRANSACTIONS_CHECKED: 0
                  COUNT_CONFLICTS_DETECTED: 0
        COUNT_TRANSACTIONS_ROWS_VALIDATING: 0
        TRANSACTIONS_COMMITTED_ALL_MEMBERS: 0d8e9d80-c374-11f0-9dec-000c297c6677:1-4,
aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa:1-10
            LAST_CONFLICT_FREE_TRANSACTION: 
COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE: 0
         COUNT_TRANSACTIONS_REMOTE_APPLIED: 1
         COUNT_TRANSACTIONS_LOCAL_PROPOSED: 0
         COUNT_TRANSACTIONS_LOCAL_ROLLBACK: 0
*************************** 3. row ***************************
                              CHANNEL_NAME: group_replication_applier
                                   VIEW_ID: 17633622381450665:7
                                 MEMBER_ID: c8d6f280-c37d-11f0-83db-000c29ef5e8a
               COUNT_TRANSACTIONS_IN_QUEUE: 0
                COUNT_TRANSACTIONS_CHECKED: 0
                  COUNT_CONFLICTS_DETECTED: 0
        COUNT_TRANSACTIONS_ROWS_VALIDATING: 0
        TRANSACTIONS_COMMITTED_ALL_MEMBERS: 0d8e9d80-c374-11f0-9dec-000c297c6677:1-4,
aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa:1-10
            LAST_CONFLICT_FREE_TRANSACTION: 
COUNT_TRANSACTIONS_REMOTE_IN_APPLIER_QUEUE: 0
         COUNT_TRANSACTIONS_REMOTE_APPLIED: 0
         COUNT_TRANSACTIONS_LOCAL_PROPOSED: 0
         COUNT_TRANSACTIONS_LOCAL_ROLLBACK: 0
3 rows in set (0.00 sec)
```
## 验证能否正常同步数据
```sql
-- 在 PRIMARY 上创建测试数据 
mysql> CREATE DATABASE IF NOT EXISTS cluster_test;
USE cluster_test;
CREATE TABLE IF NOT EXISTS test_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    node_name VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 在 PRIMARY 上插入测试数据
mysql> INSERT INTO test_data (node_name) VALUES ('from_primary');

-- 在 SECONDARY01 或 SECONDARY02 上验证数据同步
mysql> SELECT * FROM cluster_test.test_data;
+----+--------------+---------------------+
| id | node_name    | created_at          |
+----+--------------+---------------------+
|  1 | from_primary | 2025-11-17 15:30:28 |
+----+--------------+---------------------+

-- 在 SECONDARY01 或 SECONDARY02 上验证只读模式
mysql> INSERT INTO test_data (node_name) VALUES ('from_secondary');
ERROR 1046 (3D000): No database selected
```
## 创建集群元数据信息
### 安装mysql-shell
```shell
apt install mysql-shell -y
```
### 启动 MySQL Shell 
在任意一台服务器上启动 MySQL Shell
```shell
# 要连接PRIMARY
root@PRIMARY:~# mysqlsh --uri=root:Kevin_1128@10.0.0.204:3306 --py
```
### 创建集群元数据信息
```shell
root@PRIMARY:~# mysqlsh --uri=root:Kevin_1128@10.0.0.204:3306 --py
.........
 MySQL  10.0.0.204:3306 ssl  Py > cluster = dba.create_cluster('myCluster')
A new InnoDB Cluster will be created on instance 'SECONDARY01:3306'.

You are connected to an instance that belongs to an unmanaged replication group.
Do you want to setup an InnoDB Cluster based on this replication group? [Y/n]: Y
Creating InnoDB Cluster 'myCluster' on 'SECONDARY01:3306'...

Adding Seed Instance...
Adding Instance 'PRIMARY:3306'...
Adding Instance 'SECONDARY01:3306'...
Adding Instance 'SECONDARY02:3306'...
Resetting distributed recovery credentials across the cluster...
NOTE: User 'mysql_innodb_cluster_1'@'%' already existed at instance 'SECONDARY01:3306'. It will be deleted and created again with a new password.
NOTE: User 'mysql_innodb_cluster_1'@'%' already existed at instance 'SECONDARY01:3306'. It will be deleted and created again with a new password.
Cluster successfully created based on existing replication group.


# 查看集群状态
 MySQL  10.0.0.204:3306 ssl  Py > cluster.status()
{
    "clusterName": "myCluster", 
    "defaultReplicaSet": {
        "name": "default", 
        "primary": "SECONDARY01:3306", 
        "ssl": "DISABLED", 
        "status": "OK", 
        "statusText": "Cluster is ONLINE and can tolerate up to ONE failure.", 
        "topology": {
            "PRIMARY:3306": {
                "address": "PRIMARY:3306", 
                "memberRole": "SECONDARY", 
                "mode": "R/O", 
                "readReplicas": {}, 
                "replicationLag": "applier_queue_applied", 
                "role": "HA", 
                "status": "ONLINE", 
                "version": "8.0.44"
            }, 
            "SECONDARY01:3306": {
                "address": "SECONDARY01:3306", 
                "memberRole": "PRIMARY", 
                "mode": "R/W", 
                "readReplicas": {}, 
                "replicationLag": "applier_queue_applied", 
                "role": "HA", 
                "status": "ONLINE", 
                "version": "8.0.44"
            }, 
            "SECONDARY02:3306": {
                "address": "SECONDARY02:3306", 
                "memberRole": "SECONDARY", 
                "mode": "R/O", 
                "readReplicas": {}, 
                "replicationLag": "applier_queue_applied", 
                "role": "HA", 
                "status": "ONLINE", 
                "version": "8.0.44"
            }
        }, 
        "topologyMode": "Single-Primary"
    }, 
    "groupInformationSourceMember": "SECONDARY01:3306"
}
```
## 验证集群是否会自动选举新的PRIMARY
### 停止PRIMARY的MySQL服务
```shell
systemctl stop mysqld
```
### 在从节点查看集群状态
```sql
mysql> SELECT * FROM performance_schema.replication_group_members;
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION | MEMBER_COMMUNICATION_STACK |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| group_replication_applier | ac81c4a7-c37c-11f0-9997-000c29673f68 | SECONDARY01 |        3306 | ONLINE       | PRIMARY     | 8.0.44         | XCom                       |
| group_replication_applier | c8d6f280-c37d-11f0-83db-000c29ef5e8a | SECONDARY02 |        3306 | ONLINE       | SECONDARY   | 8.0.44         | XCom                       |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
```
### 当PRIMARY节点恢复后是一个独立节点，需要重新加入集群
```sql
START GROUP_REPLICATION;

-- 恢复阶段RECOVERING
mysql> SELECT * FROM performance_schema.replication_group_members;
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION | MEMBER_COMMUNICATION_STACK |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| group_replication_applier | 0d8e9d80-c374-11f0-9dec-000c297c6677 | PRIMARY     |        3306 | RECOVERING   | SECONDARY   | 8.0.44         | XCom                       |
| group_replication_applier | ac81c4a7-c37c-11f0-9997-000c29673f68 | SECONDARY01 |        3306 | ONLINE       | PRIMARY     | 8.0.44         | XCom                       |
| group_replication_applier | c8d6f280-c37d-11f0-83db-000c29ef5e8a | SECONDARY02 |        3306 | ONLINE       | SECONDARY   | 8.0.44         | XCom                       |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+

-- 恢复阶段SECONDARY
mysql> SELECT * FROM performance_schema.replication_group_members;
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| CHANNEL_NAME              | MEMBER_ID                            | MEMBER_HOST | MEMBER_PORT | MEMBER_STATE | MEMBER_ROLE | MEMBER_VERSION | MEMBER_COMMUNICATION_STACK |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
| group_replication_applier | 0d8e9d80-c374-11f0-9dec-000c297c6677 | PRIMARY     |        3306 | ONLINE       | SECONDARY   | 8.0.44         | XCom                       |
| group_replication_applier | ac81c4a7-c37c-11f0-9997-000c29673f68 | SECONDARY01 |        3306 | ONLINE       | PRIMARY     | 8.0.44         | XCom                       |
| group_replication_applier | c8d6f280-c37d-11f0-83db-000c29ef5e8a | SECONDARY02 |        3306 | ONLINE       | SECONDARY   | 8.0.44         | XCom                       |
+---------------------------+--------------------------------------+-------------+-------------+--------------+-------------+----------------+----------------------------+
```
> 注意：如果上面START GROUP_REPLICATION有问题，可用下列方法解决
```sql
-- 1. 停止 Group Replication
STOP GROUP_REPLICATION;

-- 2. 重置状态
RESET MASTER;
RESET SLAVE ALL;

-- 3. 重新配置恢复通道（确保用户名和密码正确设置）
CHANGE MASTER TO 
  MASTER_USER='repl', 
  MASTER_PASSWORD='Kevin_1128'
FOR CHANNEL 'group_replication_recovery';

-- 4. 重新启动
START GROUP_REPLICATION;

-- 5. 监控状态
SELECT * FROM performance_schema.replication_group_members;
```
# 配置 MySQL Router 高可用
## 1. 安装 MySQL Router、HAProxy、keepalived
```shell
apt install -y mysql-router haproxy keepalived

# 检查mysqlrouter是否创建
grep mysqlrouter /etc/passwd
# 不存在则手动创建（系统用户、禁止交互登录）
useradd -r -s /bin/false mysqlrouter
```
## 2. 修改内核参数（两台机器都要做）
允许应用程序绑定（bind）到「非本地」IP 地址
```shell
echo 'net.ipv4.ip_nonlocal_bind = 1' >> /etc/sysctl.conf && sysctl -p
```
## 3. MySQLRouter启动文件
```shell
cat > /etc/systemd/system/mysqlrouter@.service << EOF

[Unit]
Description=MySQL Router for instance %i
After=network.target

[Service]
Type=notify
User=mysqlrouter
Group=mysqlrouter
RuntimeDirectory=mysqlrouter-%i
ExecStart=/usr/bin/mysqlrouter -c /etc/mysqlrouter-%i/mysqlrouter.conf
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```
## 4. 初始化实例
### 1. 初始化实例（Router1）10.0.0.200
```shell
root@HAProxyRouter1:~# mysqlrouter --bootstrap root@10.0.0.203:3306 --directory /etc/mysqlrouter-1 --user=mysqlrouter --conf-base-port 6446 --force
Please enter MySQL password for root: 
# Bootstrapping MySQL Router 8.0.43 ((Ubuntu)) instance at '/etc/mysqlrouter-1'...

Fetching Cluster Members
trying to connect to mysql-server at SECONDARY01:3306
- Creating account(s) (only those that are needed, if any)
Failed changing the authentication plugin for account 'mysql_router1_kjd0931'@'%':  mysql_native_password which is deprecated is the default authentication plugin on this server.
- Verifying account (using it to run SQL queries that would be run by Router)
- Storing account in keyring
- Adjusting permissions of generated files
- Creating configuration /etc/mysqlrouter-1/mysqlrouter.conf

# MySQL Router configured for the InnoDB Cluster 'myCluster'

After this MySQL Router has been started with the generated configuration

    $ mysqlrouter -c /etc/mysqlrouter-1/mysqlrouter.conf

InnoDB Cluster 'myCluster' can be reached by connecting to:

## MySQL Classic protocol

- Read/Write Connections: localhost:6446
- Read/Only Connections:  localhost:6447

## MySQL X protocol

- Read/Write Connections: localhost:6448
- Read/Only Connections:  localhost:6449
```
### 2. 初始化实例（Router2）10.0.0.201
```shell
root@HAProxyRouter2:~# mysqlrouter --bootstrap root@10.0.0.203:3306 --directory /etc/mysqlrouter-2 --user=mysqlrouter --conf-base-port 6446 --force
Please enter MySQL password for root: 
# Bootstrapping MySQL Router 8.0.43 ((Ubuntu)) instance at '/etc/mysqlrouter-2'...

Fetching Cluster Members
trying to connect to mysql-server at SECONDARY01:3306
- Creating account(s) (only those that are needed, if any)
Failed changing the authentication plugin for account 'mysql_router2_csjsgua'@'%':  mysql_native_password which is deprecated is the default authentication plugin on this server.
- Verifying account (using it to run SQL queries that would be run by Router)
- Storing account in keyring
- Adjusting permissions of generated files
- Creating configuration /etc/mysqlrouter-2/mysqlrouter.conf

# MySQL Router configured for the InnoDB Cluster 'myCluster'

After this MySQL Router has been started with the generated configuration

    $ mysqlrouter -c /etc/mysqlrouter-2/mysqlrouter.conf

InnoDB Cluster 'myCluster' can be reached by connecting to:

## MySQL Classic protocol

- Read/Write Connections: localhost:6446
- Read/Only Connections:  localhost:6447

## MySQL X protocol

- Read/Write Connections: localhost:6448
- Read/Only Connections:  localhost:6449
```
## 5. 修改目录权限并启动服务
### 1. Router1 (10.0.0.200)
```shell
sudo chown -R mysqlrouter:mysqlrouter /etc/mysqlrouter-1 && \
     sed -i 's/^bind_address *= *.*/bind_address=10.0.0.200/' /etc/mysqlrouter-1/mysqlrouter.conf && \
     sudo systemctl daemon-reload && \
     sudo systemctl start mysqlrouter@1 && \
     sudo systemctl status mysqlrouter@1
```
### 2. Router2 (10.0.0.201)
```shell
sudo chown -R mysqlrouter:mysqlrouter /etc/mysqlrouter-2  && \
     sed -i 's/^bind_address *= *.*/bind_address=10.0.0.201/' /etc/mysqlrouter-2/mysqlrouter.conf  && \
     sudo systemctl daemon-reload  && \
     sudo systemctl start mysqlrouter@2  && \
     sudo systemctl status mysqlrouter@2
```
## 6. 配置 Keepalived 实现 VIP 漂移
### 1. HAProxyRouter1的配置
```shell
cat > /etc/keepalived/keepalived.conf << EOF 
! Configuration File for keepalived

global_defs {
   router_id HAProxyRouter1
   vrrp_skip_check_adv_addr
   vrrp_garp_interval 0
   vrrp_gna_interval 0
}

vrrp_script chk_haproxy {
    script "pidof haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state MASTER
    interface ens33
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.0.0.202/24
    }
    track_script {
        chk_haproxy
    }
}
EOF
```
### 2. HAProxyRouter2的配置
```shell
cat > /etc/keepalived/keepalived.conf << EOF 
! Configuration File for keepalived

global_defs {
   router_id HAProxyRouter2
   vrrp_skip_check_adv_addr
   vrrp_garp_interval 0
   vrrp_gna_interval 0
}

vrrp_script chk_haproxy {
    script "pidof haproxy"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface ens33
    virtual_router_id 51
    priority 50
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        10.0.0.202/24
    }
    track_script {
        chk_haproxy
    }
}
EOF
```
## 7. 配置 HAProxy 负载均衡
### 1. HAProxy配置
HAProxy + Router1和 HAProxy + Router2 都要配置
```shell
cat > /etc/haproxy/haproxy.cfg << EOF
global
    daemon
    log 127.0.0.1 local0
    maxconn 4096

defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    retries 3

# 监控界面
listen stats
    bind *:1936
    mode http
    stats enable
    stats uri /haproxy?stats
    stats realm HAProxy\ Statistics
    stats auth admin:Kevin_1128

# MySQL Router 负载均衡 - 主入口
frontend mysql_main
    bind 10.0.0.202:3306
    mode tcp
    default_backend mysql_routers

backend mysql_routers
    mode tcp
    balance roundrobin
    option tcp-check
    tcp-check connect
    tcp-check expect string mysql
    server mysql_router1 10.0.0.200:6446 check inter 2s rise 2 fall 3 weight 1
    server mysql_router2 10.0.0.201:6446 check inter 2s rise 2 fall 3 weight 1
EOF
```
### 2. HaProxy 监控地址
- 用户名：admin
- 密码：Kevin_1128
- HaProxy1:http://10.0.0.200:1936/haproxy?stats
- HaProxy2:http://10.0.0.201:1936/haproxy?stats
## 8. 测试高可用
停止keepalived服务，模拟HA1 down机了 测试访问10.0.0.202时还能不能正常返回信息
```shell
# 停止前
root@HAProxyRouter1:~# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 1000
    link/ether 00:0c:29:95:15:78 brd ff:ff:ff:ff:ff:ff
    altname enp2s1
    inet 10.0.0.200/24 brd 10.0.0.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet 10.0.0.202/24 scope global secondary ens33
       valid_lft forever preferred_lft forever
    inet6 2409:8a1e:8073:b4d2:20c:29ff:fe95:1578/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86032sec preferred_lft 14032sec
    inet6 fe80::20c:29ff:fe95:1578/64 scope link 
       valid_lft forever preferred_lft forever
# 停止服务
root@HAProxyRouter1:~# systemctl stop keepalived

# 停止后 10.0.0.202 没了
root@HAProxyRouter1:~# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 1000
    link/ether 00:0c:29:95:15:78 brd ff:ff:ff:ff:ff:ff
    altname enp2s1
    inet 10.0.0.200/24 brd 10.0.0.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet6 2409:8a1e:8073:b4d2:20c:29ff:fe95:1578/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 84749sec preferred_lft 12749sec
    inet6 fe80::20c:29ff:fe95:1578/64 scope link 
       valid_lft forever preferred_lft forever
       
# 到HA2上看  10.0.0.202出现了
root@HAProxyRouter2:~# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host noprefixroute 
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UNKNOWN group default qlen 1000
    link/ether 00:0c:29:68:32:cf brd ff:ff:ff:ff:ff:ff
    altname enp2s1
    inet 10.0.0.201/24 brd 10.0.0.255 scope global ens33
       valid_lft forever preferred_lft forever
    inet 10.0.0.202/24 scope global secondary ens33
       valid_lft forever preferred_lft forever
    inet6 2409:8a1e:8073:b4d2:20c:29ff:fe68:32cf/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 84745sec preferred_lft 12745sec
    inet6 fe80::20c:29ff:fe68:32cf/64 scope link 
       valid_lft forever preferred_lft forever

# 测试202IP是否还能访问
root@HAProxyRouter1:~# mysql -u root -pKevin_1128 -h 10.0.0.202 -P 3306 -e "show databases;"
mysql: [Warning] Using a password on the command line interface can be insecure.
+-------------------------------+
| Database                      |
+-------------------------------+
| cluster_test                  |
| information_schema            |
| mysql                         |
| mysql_innodb_cluster_metadata |
| performance_schema            |
| sys                           |
+-------------------------------+
```