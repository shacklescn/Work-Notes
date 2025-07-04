# StarRocks 存算一体搭建部署
安装之前须查看系统CPU是否支持AVX2指令集,StarRocks 依靠 AVX2 指令集充分发挥其矢量化能力,因此CPU指令集必须存在AVX2否则服务将无法正常工作。
```shell
cat /proc/cpuinfo | grep avx2
```
# 资源规划
| 节点地址       | 组件        | 角色       | CPU（逻辑核） | 内存|
|------------|-----------|----------|----------|----------|
| 10.84.10.7 | FE&BE     | LEADER   | 40核      | 125Gi   |
| 10.84.10.8 | FE&BE     | FOLLOWER | 40核      | 125Gi   |
| 10.84.10.9 | FE&BE     | FOLLOWER | 40核      | 125Gi   |
注意：每台FE的JVM最大堆内存设置为32768m，BE限制最多使用整体的60%（75GB），系统预留15%,具体配置可在脚本中fe.conf和be.conf中体现
# 环境配置（三台机器都要做）
### 1、克隆项目
```shell
git clone https://github.com/shacklescn/Work-Notes.git
```
### 2、进入搭建目录
```shell
cd Work-Notes/StarRocks存算一体/Deploy/
```
### 3、初始化基础环境
```shell
bash StarRocks-init.sh
```
# 安装LEADER StarRocks服务（LEADER节点操作）
## 1、安装并启动StarRocks服务
```shell
bash StarRocks-LEADER.sh
```
## 2、验证是否成功
```shell
#第一种验证方式
netstat -ntpl | grep "9060\|8040\|9050\|8060\|9070\|8030\|9020\|9030\|9010" 
tcp        0      0 0.0.0.0:9050            0.0.0.0:*               LISTEN      3568/starrocks_be   
tcp        0      0 0.0.0.0:9060            0.0.0.0:*               LISTEN      3568/starrocks_be   
tcp        0      0 0.0.0.0:8060            0.0.0.0:*               LISTEN      3568/starrocks_be   
tcp        0      0 0.0.0.0:8040            0.0.0.0:*               LISTEN      3568/starrocks_be   
tcp6       0      0 :::9030                 :::*                    LISTEN      35940/java          
tcp6       0      0 :::9070                 :::*                    LISTEN      3568/starrocks_be   
tcp6       0      0 :::9010                 :::*                    LISTEN      35940/java          
tcp6       0      0 :::9020                 :::*                    LISTEN      35940/java          
tcp6       0      0 :::8030                 :::*                    LISTEN      35940/java 

#第二种验证方式
cat /opt/StarRocks/fe/log/fe.log | grep thrift
2025-07-04 09:14:16.241+08:00 INFO (UNKNOWN 10.84.10.7_9010_1721006047505(-1)|1) [FrontendThriftServer.start():65] thrift server started with port 9020.
```
## 3、部署后操作
### 3.1. 安装MySQL客户端
```shell
apt install mysql-client-core-8.0
```
### 3.2. 无密码登录StarRocks
```shell
mysql -h 10.84.10.7 -P9030 -uroot --prompt="StarRocks"
```
### 3.3. 设置root密码
```sql
set PASSWORD=PASSWORD('J.K6%\;r*n#Z,5BW_xXp*');
```
### 3.4. SQL查询优化
```sql
SET GLOBAL group_concat_max_len = 2048000;
SET enable_query_cache=true;
SET GLOBAL pipeline_dop=3;
SET enable_profile = true;
```
- group_concat_max_len：group_concat 函数返回的字符串的最大长度，单位为字符。
- enable_query_cache:是否开启 Query Cache,取值范围：true 和 false,true 表示开启，false 表示关闭（默认值）,开启该功能后，只有当查询满足Query Cache 所述条件时，才会启用 Query Cache。 
- pipeline_dop:一个 Pipeline 实例的并行数量。可通过设置实例的并行数量调整查询并发度。默认值为 0，即系统自适应调整每个 pipeline 的并行度。您也可以设置为大于 0 的数值，通常为 BE 节点 CPU 物理核数的一半。从 3.0 版本开始，支持根据查询并发度自适应调节 pipeline_dop,有多少副本就配置多少。 
- enable_profile：用于设置是否需要查看查询的 profile。默认为 false，即不需要查看 profile。默认情况下，只有在查询发生错误时，BE 才会发送 profile 给 FE，用于查看错误。正常结束的查询不会发送 profile。发送 profile 会产生一定的网络开销，对高并发查询场景不利。当用户希望对一个查询的 profile 进行分析时，可以将这个变量设为 true 后，发送查询。查询结束后，可以通过在当前连接的 FE 的 web 页面（地址：fe_host:fe_http_port/query）查看 profile。该页面会显示最近 100 条开启了 enable_profile 的查询的 profile。
### 3.5. 添加be节点至集群
```sql
-- 单节点
ALTER SYSTEM ADD BACKEND "10.84.10.7:9050"
```
### 3.6. 验证是否添加成功
```sql
StarRocks> SHOW PROC '/backends'\G
*************************** 1. row ***************************
            BackendId: 10002
                   IP: 10.84.10.7
        HeartbeatPort: 9050
               BePort: 9060
             HttpPort: 8040
             BrpcPort: 8060
        LastStartTime: 2025-07-04 14:54:57
        LastHeartbeat: 2025-03-17 10:33:40
                Alive: true
 SystemDecommissioned: false
ClusterDecommissioned: false
            TabletNum: 69
     DataUsedCapacity: 0.000 B
        AvailCapacity: 746.239 GB
        TotalCapacity: 786.374 GB
              UsedPct: 5.10 %
       MaxDiskUsedPct: 5.10 %
               ErrMsg: 
              Version: 3.4.0-e94580b
               Status: {"lastSuccessReportTabletsTime":"2025-03-17 10:33:39"}
    DataTotalCapacity: 746.239 GB
          DataUsedPct: 0.00 %
             CpuCores: 8
             MemLimit: 50.866GB
    NumRunningQueries: 0
           MemUsedPct: 0.30 %
           CpuUsedPct: 0.1 %
     DataCacheMetrics: Status: Normal, DiskUsage: 0B/580GB, MemUsage: 0B/0B
             Location: 
           StatusCode: OK
1 row in set (0.02 sec)
```
Alive: true:添加成功
# 安装FOLLOWER StarRocks服务（在两个FOLLOWER节点操作）
```shell
bash StarRocks-FOLLOWER.sh <LEADER IP>
```
安装完后，验证方式和LEADER的验证方法一致
## 1、添加FE
```sql
ALTER SYSTEM ADD FOLLOWER "10.84.10.8:9010", "10.84.10.9:9010";
```
## 2、添加BE
```sql
-- 多节点
ALTER SYSTEM ADD BACKEND "10.84.10.8:9050", "10.84.10.9:9050";
```
## 3、查验FE和BE服务是否正常
```sql
-- FE服务

mysql> SHOW FRONTENDS\G;
*************************** 1. row ***************************
             Name: 10.84.10.7_9010_1721006047505
               IP: 10.84.10.7
      EditLogPort: 9010
         HttpPort: 8030
        QueryPort: 9030
          RpcPort: 9020
             Role: LEADER
        ClusterId: 463766615
             Join: true
            Alive: true
ReplayedJournalId: 5042
    LastHeartbeat: 2025-07-04 13:54:43
         IsHelper: true
           ErrMsg: 
        StartTime: 2025-07-04 09:22:27
          Version: 3.4.0-e94580b
*************************** 2. row ***************************
             Name: 10.84.10.8_9010_1721021656623
               IP: 10.84.10.8
      EditLogPort: 9010
         HttpPort: 8030
        QueryPort: 9030
          RpcPort: 9020
             Role: FOLLOWER
        ClusterId: 463766615
             Join: true
            Alive: true
ReplayedJournalId: 5040
    LastHeartbeat: 2025-07-04 13:54:43
         IsHelper: true
           ErrMsg: 
        StartTime: 2025-07-04 13:53:49
          Version: 3.4.0-e94580b
*************************** 3. row ***************************
             Name: 10.84.10.9_9010_1721021647617
               IP: 10.84.10.9
      EditLogPort: 9010
         HttpPort: 8030
        QueryPort: 9030
          RpcPort: 9020
             Role: FOLLOWER
        ClusterId: 463766615
             Join: true
            Alive: true
ReplayedJournalId: 5040
    LastHeartbeat: 2025-07-04 13:54:43
         IsHelper: true
           ErrMsg: 
        StartTime: 2025-07-04 13:51:06
          Version: 3.4.0-e94580b
3 rows in set (0.02 sec)
```
三台机器 Alive: true  服务正常
```sql
-- BE服务

mysql> SHOW PROC '/backends'\G;
*************************** 1. row ***************************
            BackendId: 17766290
                   IP: 10.84.10.7
        HeartbeatPort: 9050
               BePort: 9060
             HttpPort: 8040
             BrpcPort: 8060
        LastStartTime: 2025-07-04 09:16:49
        LastHeartbeat: 2025-07-04 16:34:41
                Alive: true
 SystemDecommissioned: false
ClusterDecommissioned: false
            TabletNum: 98399
     DataUsedCapacity: 497.679 GB
        AvailCapacity: 926.605 GB
        TotalCapacity: 1.475 TB
              UsedPct: 38.67 %
       MaxDiskUsedPct: 38.67 %
               ErrMsg: 
              Version: 3.3.3-312ed45
               Status: {"lastSuccessReportTabletsTime":"2025-07-04 16:34:29"}
    DataTotalCapacity: 1.391 TB
          DataUsedPct: 34.94 %
             CpuCores: 16
    NumRunningQueries: 0
           MemUsedPct: 34.37 %
           CpuUsedPct: 11.3 %
     DataCacheMetrics: Status: Normal, DiskUsage: 0B/520GB, MemUsage: 0B/0B
             Location: 
*************************** 2. row ***************************
            BackendId: 18810542
                   IP: 10.84.10.8
        HeartbeatPort: 9050
               BePort: 9060
             HttpPort: 8040
             BrpcPort: 8060
        LastStartTime: 2025-07-04 09:20:08
        LastHeartbeat: 2025-07-04 16:34:41
                Alive: true
 SystemDecommissioned: false
ClusterDecommissioned: false
            TabletNum: 98398
     DataUsedCapacity: 497.660 GB
        AvailCapacity: 924.666 GB
        TotalCapacity: 1.475 TB
              UsedPct: 38.80 %
       MaxDiskUsedPct: 38.80 %
               ErrMsg: 
              Version: 3.3.3-312ed45
               Status: {"lastSuccessReportTabletsTime":"2025-07-04 16:34:42"}
    DataTotalCapacity: 1.389 TB
          DataUsedPct: 34.99 %
             CpuCores: 32
    NumRunningQueries: 0
           MemUsedPct: 26.94 %
           CpuUsedPct: 2.0 %
     DataCacheMetrics: Status: Normal, DiskUsage: 0B/520GB, MemUsage: 0B/0B
             Location: 
*************************** 3. row ***************************
            BackendId: 18810543
                   IP: 10.84.10.9
        HeartbeatPort: 9050
               BePort: 9060
             HttpPort: 8040
             BrpcPort: 8060
        LastStartTime: 2025-07-04 09:21:03
        LastHeartbeat: 2025-07-04 16:34:41
                Alive: true
 SystemDecommissioned: false
ClusterDecommissioned: false
            TabletNum: 98399
     DataUsedCapacity: 497.669 GB
        AvailCapacity: 924.650 GB
        TotalCapacity: 1.475 TB
              UsedPct: 38.80 %
       MaxDiskUsedPct: 38.80 %
               ErrMsg: 
              Version: 3.3.3-312ed45
               Status: {"lastSuccessReportTabletsTime":"2025-07-04 16:33:54"}
    DataTotalCapacity: 1.389 TB
          DataUsedPct: 34.99 %
             CpuCores: 32
    NumRunningQueries: 0
           MemUsedPct: 26.93 %
           CpuUsedPct: 0.8 %
     DataCacheMetrics: Status: Normal, DiskUsage: 0B/520GB, MemUsage: 0B/0B
             Location: 
3 rows in set (0.01 sec)
```
三台机器 Alive: true  服务正常