# Slurm 部署手册
## 环境准备
### 角色规划
| 主机IP        | 主机名称    | 节点角色                     | 节点特殊设备 |
|-------------|---------|---------------------------------|--------|
| 10.84.10.27 | server2 | 控制节点、计算节点、build节点和DB节点 | GPU*2  |
| 10.84.10.28 | server3 | 计算节点                          | GPU*2  |
| 10.84.3.163 | server4 | 计算节点                          |        |
| 10.84.3.164 | server5 | 登录节点                          |        |
###  时间同步(所有节点)
```bash
timedatectl set-timezone Asia/Shanghai && \
sudo sed -i 's/^#NTP=/NTP=10.84.10.6/' /etc/systemd/timesyncd.conf && \
sudo systemctl restart systemd-timesyncd
```
### 设置hosts(所有节点)
```shell
10.84.10.27 server2
10.84.10.28 server3
10.84.3.163 server4
10.84.3.164 server5
```
### 系统版本(所有节点)
```shell
root@server2:~/slurm# lsb_release -a
No LSB modules are available.
Distributor ID:	Ubuntu
Description:	Ubuntu 22.04.5 LTS
Release:	22.04
Codename:	jammy
```
## 安装依赖（所有节点）
### 安装munge服务
```shell
apt update && apt install munge libmunge-dev openmpi-bin libopenmpi-dev
```
### 配置主节点munge 服务（slurm控制节点操作）
#### 1. 生成密钥
```
sudo /usr/sbin/mungekey
```
> 会在/etc/munge/下生产一个munge.key文件
#### 2. 设置key文件权限
```shell
sudo chown munge:munge /etc/munge/munge.key
sudo chmod 0400 /etc/munge/munge.key
```
#### 3. 设置目录权限
```shell
sudo chown -R munge:munge /etc/munge /var/log/munge /var/lib/munge
```
#### 4. 启动munge服务
```shell
sudo systemctl enable munge
sudo systemctl start munge
```
### 配置从节点munge 服务（slurm计算节点操作）
#### 1. 分发munge.key
把主节点中的```/etc/munge/munge.key```copy至从节点的```/etc/munge/munge.key```
```shell
# 主节点操作
scp /etc/munge/munge.key <从节点IP>:/etc/munge/
```
#### 2. 设置key文件权限
```shell
sudo chown munge:munge /etc/munge/munge.key
sudo chmod 0400 /etc/munge/munge.key
```
#### 3. 设置目录权限
```shell
sudo chown -R munge:munge /etc/munge /var/log/munge /var/lib/munge
```
#### 4. 启动munge服务
```shell
sudo systemctl enable munge
sudo systemctl start munge
```
### 验证munge 是否正常工作
```shell
root@server2:~# munge -n | unmunge
STATUS:          Success (0)
ENCODE_HOST:     server2 (127.0.1.1)
ENCODE_TIME:     2025-09-15 15:10:07 +0800 (1757920207)
DECODE_TIME:     2025-09-15 15:10:07 +0800 (1757920207)
TTL:             300
CIPHER:          aes128 (4)
MAC:             sha256 (5)
ZIP:             none (0)
UID:             root (0)
GID:             root (0)
LENGTH:          0

root@server2:~# munge -n | ssh 10.84.10.28 unmunge
root@10.84.10.28's password: 
STATUS:          Success (0)
ENCODE_HOST:     server3 (127.0.1.1)
ENCODE_TIME:     2025-09-15 15:48:34 +0800 (1757922514)
DECODE_TIME:     2025-09-15 15:48:36 +0800 (1757922516)
TTL:             300
CIPHER:          aes128 (4)
MAC:             sha256 (5)
ZIP:             none (0)
UID:             root (0)
GID:             root (0)
LENGTH:          0
......
......
```

## 构建并安装 Slurm
### 安装依赖
```shell
apt-get install build-essential fakeroot devscripts equivs
```
### 下载 Slurm 安装包并解压
```shell
wget https://download.schedmd.com/slurm/slurm-25.05.3.tar.bz2 && \
     tar -xaf slurm-25.05.3.tar.bz2 && \
     cd slurm-25.05.3
```
### 安装 Slurm 包依赖项
```shell
mk-build-deps -i debian/control
```
### 创建 shlibs.local 指定自定义库依赖
```shell
cat > debian/shlibs.local << EOF
libmunge 2 libmunge2 (>= 0.5.14)
EOF
```
### 构建 Slurm 包
```shell
debuild -b -uc -us
```
> **注意**：使用官方给的 debuild -b -uc -us 构建 Slurm 包时会报错 可以使用 DEB_BUILD_OPTIONS=nostrip dpkg-buildpackage -b -uc -us来执行构建
编译完成后在父目录中会有对应的deb文件
```shell
root@server2:~/slurm# ls
munge-0.5.16         slurm-25.05.3                    slurm-smd_25.05.3-1_amd64.buildinfo   slurm-smd-dev_25.05.3-1_amd64.deb                 slurm-smd-libpmi0_25.05.3-1_amd64.deb        slurm-smd-sackd_25.05.3-1_amd64.deb      slurm-smd-slurmrestd_25.05.3-1_amd64.deb
munge-0.5.16.tar.xz  slurm-25.05.3.tar.bz2            slurm-smd_25.05.3-1_amd64.changes     slurm-smd-doc_25.05.3-1_all.deb                   slurm-smd-libpmi2-0_25.05.3-1_amd64.deb      slurm-smd-slurmctld_25.05.3-1_amd64.deb  slurm-smd-sview_25.05.3-1_amd64.deb
munge-deps           slurm-offline-debs.tar.gz        slurm-smd_25.05.3-1_amd64.deb         slurm-smd-libnss-slurm_25.05.3-1_amd64.deb        slurm-smd-libslurm-perl_25.05.3-1_amd64.deb  slurm-smd-slurmd_25.05.3-1_amd64.deb     slurm-smd-torque_25.05.3-1_all.deb
offline-debs         slurm-smd_25.05.3-1_amd64.build  slurm-smd-client_25.05.3-1_amd64.deb  slurm-smd-libpam-slurm-adopt_25.05.3-1_amd64.deb  slurm-smd-openlava_25.05.3-1_all.deb         slurm-smd-slurmdbd_25.05.3-1_amd64.deb
```
其中```slurm-smd_25.05.3-1_amd64.build```  ```slurm-smd_25.05.3-1_amd64.buildinfo```  ```slurm-smd_25.05.3-1_amd64.changes```是构建时的日志或者调试信息可忽略，其他的deb包才是安装slurm要用的

编译好的deb包：链接：https://pan.quark.cn/s/e08504d51728
## 控制节点配置
### 安装对应的slurm包
```shell
apt install ./slurm-smd_25.05.3-1_amd64.deb \
    ./slurm-smd-client_25.05.3-1_amd64.deb \
    ./slurm-smd-slurmctld_25.05.3-1_amd64.deb
```
### 创建Slurm运行服务的用户和组
```shell
sudo groupadd --system slurm && useradd --system --gid slurm --shell /sbin/nologin --home-dir /var/lib/slurm slurm 
```
### 配置 slurm.conf
```shell
cat > /etc/slurm/slurm.conf << EOF
ClusterName=cool
ControlMachine=server2
MailProg=/usr/bin/s-nail
SlurmUser=slurm
SlurmctldPort=6817

SlurmdPort=6818
AuthType=auth/munge
StateSaveLocation=/var/spool/slurmctld
SlurmdSpoolDir=/var/spool/slurmd
SwitchType=switch/none
MpiDefault=none
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmdPidFile=/var/run/slurmd.pid
TaskPlugin=task/cgroup
ProctrackType=proctrack/cgroup
ReturnToService=0
SlurmctldTimeout=300
SlurmdTimeout=300
InactiveLimit=0
MinJobAge=300
KillWait=30
Waittime=0
SchedulerType=sched/backfill

GresTypes=gpu

SlurmctldDebug=info
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdDebug=info
SlurmdLogFile=/var/log/slurm/slurmd.log
AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost=server2
AccountingStoragePort=6819


PartitionName=cpu Nodes=server[2-5] Default=no MaxTime=INFINITE State=UP
PartitionName=memory Nodes=server[2-5] Default=yes MaxTime=INFINITE State=UP
PartitionName=gpu Nodes=server[2-3] Default=no MaxTime=INFINITE State=UP
NodeName=server2 CPUs=96 Boards=1 SocketsPerBoard=2 CoresPerSocket=24 ThreadsPerCore=2 RealMemory=515711 Gres=gpu:nvidia_l40s:2
NodeName=server3 CPUs=96 Boards=1 SocketsPerBoard=2 CoresPerSocket=24 ThreadsPerCore=2 RealMemory=515711 Gres=gpu:nvidia_l40s:2
NodeName=server4 CPUs=8 Boards=1 SocketsPerBoard=8 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=15988
NodeName=server5 CPUs=8 Boards=1 SocketsPerBoard=8 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=15988
EOF
```
> NodeName开头的行需要到已安装slurmd的机器上执行 slurmd -C 获取
> 
> slurmctld和slurmd共用一个slurm.conf
### 创建用户 & spool/log 目录
```shell
touch /var/log/slurm/slurmctld.log && mkdir /var/spool/slurmctld && chown -R slurm:slurm /var/log/slurm /var/spool/slurmctld /var/spool/slurmd
```
### 启动slurmctld和slurmd
```shell
sudo systemctl enable slurmctld --now
```
### 验证服务是否正常
```shell
# 1.查看日志是否存在报错
cat /var/log/slurm/slurmctld.log 
[2025-09-16T16:36:41.198] error: Configured MailProg is invalid  # 没配置邮件通知  可忽略
[2025-09-16T16:36:41.201] slurmctld version 25.05.3 started on cluster cool(1127)
[2025-09-16T16:36:41.205] _parse_part_spec: changing default partition from cpu to memory
[2025-09-16T16:36:41.205] _parse_part_spec: changing default partition from memory to gpu
[2025-09-16T16:36:41.206] Recovered state of 2 nodes
[2025-09-16T16:36:41.206] Recovered information about 0 jobs
[2025-09-16T16:36:41.206] select/cons_tres: part_data_create_array: select/cons_tres: preparing for 3 partitions
[2025-09-16T16:36:41.206] Recovered state of 0 reservations
[2025-09-16T16:36:41.206] read_slurm_conf: backup_controller not specified
[2025-09-16T16:36:41.206] select/cons_tres: select_p_reconfigure: select/cons_tres: reconfigure
[2025-09-16T16:36:41.206] select/cons_tres: part_data_create_array: select/cons_tres: preparing for 3 partitions
[2025-09-16T16:36:41.206] Running as primary controller
# 2. 查看端口是否正常监听
netstat -ntpl | grep slurmctld
tcp        0      0 0.0.0.0:6817            0.0.0.0:*               LISTEN      20373/slurmctld 
```
## 计算节点配置
### 安装对应的slurm包
```shell
apt install ./slurm-smd_25.05.3-1_amd64.deb \
    ./slurm-smd-slurmd_25.05.3-1_amd64.deb \
    ./slurm-smd-client_25.05.3-1_amd64.deb
```
### 获取计算节点中的资源配置信息
```shell
root@server3:~# slurmd -C
NodeName=server3 CPUs=96 Boards=1 SocketsPerBoard=2 CoresPerSocket=24 ThreadsPerCore=2 RealMemory=515711 Gres=gpu:nvidia_l40s:2

root@server4:~# slurmd -C
NodeName=server4 CPUs=8 Boards=1 SocketsPerBoard=8 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=15988
```
### 注册计算节点（在控制节点操作）
```shell
echo "NodeName=server3 CPUs=96 Boards=1 SocketsPerBoard=2 CoresPerSocket=24 ThreadsPerCore=2 RealMemory=515711 Gres=gpu:nvidia_l40s:2" >> /etc/slurm/slurm.conf
```
> 注意：注册计算节点时，需要在集群内控制节点统一配置，之后使用scp指令 下发至每个计算节点，下发完成后重启服务生效
### 复制控制节点中的```slurm.conf```和```cgroup.conf```并创建```gres.conf```
```shell
# 复制控制节点中的slurm.conf和cgroup.conf
#普通节点
scp <控制节点IP>:/etc/slurm/{cgroup.conf,slurm.conf} /etc/slurm/

# GPU节点创建gres.conf
cat > /etc/slurm/gres.conf << EOF
NodeName=server2 Name=gpu Type=nvidia_l40s File=/dev/nvidia0
NodeName=server2 Name=gpu Type=nvidia_l40s File=/dev/nvidia1
EOF
```
/etc/slurm/gres.conf 是 Slurm 的 GRES（Generic RESource）配置文件，专门用来告诉 Slurm：

节点上有哪些“特殊资源”（比如 GPU、MPS、MIC、NVMe 等）。

这些资源对应到系统里的哪些设备文件（/dev/nvidia0、/dev/nvidia1）。

每种资源的类型/型号（比如 nvidia_l40s）。
> 注意：gres.conf 是每个计算节点本地的配置文件，只写该节点自己的 GPU，不要把所有节点的都写进去。
> 
> server2 的 gres.conf 只写 server2 的卡。
> 
> server3 的 gres.conf 只写 server3 的卡。
### 创建Slurm运行服务的用户和组
```shell
sudo groupadd --system slurm && useradd --system --gid slurm --shell /sbin/nologin --home-dir /var/lib/slurm slurm
```
> 注意：此处创建的slurm用户的UID 要和控制节点中的UID保持一致，否则会报错 Security violation, ping RPC from uid 997
### 创建节点工作目录和设置节点工作目录权限
```shell
mkdir /var/spool/slurmd && chown -R slurm:slurm /var/spool/slurmd
```
### 启动slurmd
```shell
sudo systemctl enable slurmd --now
```
### 验证服务是否正常
```shell
# 1.查看日志是否存在报错
cat /var/log/slurm/slurmd.log
[2025-09-16T16:31:31.677] slurmd version 25.05.3 started
[2025-09-16T16:31:31.685] slurmd started on Tue, 16 Sep 2025 16:31:31 +0800
[2025-09-16T16:31:31.685] CPUs=96 Boards=1 Sockets=2 Cores=24 Threads=2 Memory=515711 TmpDisk=896475 Uptime=20464 CPUSpecList=(null) FeaturesAvail=(null) FeaturesActive=(null)
# 2. 查看端口是否正常监听
netstat -ntpl | grep slurmd      
tcp        0      0 0.0.0.0:6818            0.0.0.0:*               LISTEN      19674/slurmd 
```
## DBD 节点配置
### 安装MySQL
```shell
cat > docker-compose.yaml << EOF 
services:
  mysql8:
    container_name: mysql8
    image: mysql:8.0.39
    restart: always
    ports:
     - 3306:3306
    command:  --default-authentication-plugin=mysql_native_password
    volumes:
     - /data/mysql8/data:/var/lib/mysql
     - /etc/localtime:/etc/localtime:ro
     - ./my.cnf:/etc/mysql/my.cnf
    environment:
       MYSQL_ROOT_PASSWORD: 'SecA@2025...'
    logging:
      options:
        max-size: "50M"
        max-file: "10"
      driver: json-file
EOF
cat > my.cnf << EOF
[mysqld]
pid-file        = /var/run/mysqld/mysqld.pid
socket          = /var/run/mysqld/mysqld.sock
datadir         = /var/lib/mysql
bind-address = 0.0.0.0
innodb_buffer_pool_size=2G
innodb_lock_wait_timeout=900
character_set_server = utf8mb4
collation_server = utf8mb4_unicode_ci
sql_mode = STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION
skip_name_resolve = 1
innodb_file_per_table = 1
symbolic-links=0

[client]
default-character-set = utf8mb4
EOF
```
> 注意：部署完MySQL后要在数据库中创建 slurm_acct_db 库
### 安装对应的slurm包
```shell
apt install ./slurm-smd_25.05.3-1_amd64.deb \
    ./slurm-smd-client_25.05.3-1_amd64.deb \
    ./slurm-smd-slurmdbd_25.05.3-1_amd64.deb
```
### 创建Slurm运行服务的用户和组
```shell
sudo groupadd --system slurm && useradd --system --gid slurm --shell /sbin/nologin --home-dir /var/lib/slurm slurm
```
### 配置slurmdbd配置文件
```shell
cat > /etc/slurm/slurmdbd.conf << EOF 
# 是否归档事件/作业等
ArchiveEvents=yes
ArchiveJobs=yes
ArchiveResvs=yes
ArchiveSteps=no
ArchiveSuspend=no
ArchiveTXN=no
ArchiveUsage=no

# Munge 认证
AuthInfo=/var/run/munge/munge.socket.2
AuthType=auth/munge

# DBD 服务主机名（运行 slurmdbd 的机器）
DbdHost=server2   # ← 写运行 slurmdbd 的主机名，不是数据库地址

DebugLevel=info

# 清理策略
PurgeEventAfter=1month
PurgeJobAfter=12month
PurgeResvAfter=1month
PurgeStepAfter=1month
PurgeSuspendAfter=1month
PurgeTXNAfter=12month
PurgeUsageAfter=24month

# 日志 & PID
LogFile=/var/log/slurm/slurmdbd.log
PidFile=/run/slurmdbd/slurmdbd.pid

# 运行用户（和 slurm.conf 里的 SlurmUser 一致，用 slurm）
SlurmUser=slurm

# 数据库连接信息
StorageType=accounting_storage/mysql
StorageHost=10.84.10.27
StoragePort=3306
StorageUser=root
StoragePass=SecA@2025...
StorageLoc=slurm_acct_db
EOF
```
### 创建PID目录并授权
```shell
sudo mkdir -p /run/slurmdbd && sudo chown slurm:slurm /run/slurmdbd
```
### 启动 slurmdbd服务
```shell
sudo systemctl daemon-reload && sudo systemctl start slurmdbd && sudo systemctl status slurmdbd
● slurmdbd.service - Slurm DBD accounting daemon
     Loaded: loaded (/lib/systemd/system/slurmdbd.service; enabled; vendor preset: enabled)
     Active: active (running) since Tue 2025-09-16 14:58:18 CST; 2min 23s ago
   Main PID: 16642 (slurmdbd)
      Tasks: 197
     Memory: 8.6M
        CPU: 39ms
     CGroup: /system.slice/slurmdbd.service
             └─16642 /usr/sbin/slurmdbd -D -s

Sep 16 14:58:18 server2 systemd[1]: Started Slurm DBD accounting daemon.
Sep 16 14:58:18 server2 slurmdbd[16642]: [2025-09-16T14:58:18.058] accounting_storage/as_mysql: _check_mysql_concat_is_sane: MySQL server version is: 8.0.39
Sep 16 14:58:18 server2 slurmdbd[16642]: [2025-09-16T14:58:18.103] slurmdbd version 25.05.3 started
```
### 注册 cluster 到数据库
```shell
sacctmgr -i add cluster cool
```
> 可以到MySQL中查看 slurm_acct_db 库中的表  查看是否有数据

### 验证服务是否正常
```shell
# 1.查看日志是否存在报错
cat /var/log/slurm/slurmdbd.log
[2025-09-16T16:35:38.810] accounting_storage/as_mysql: _check_mysql_concat_is_sane: MySQL server version is: 8.0.39
[2025-09-16T16:35:38.845] slurmdbd version 25.05.3 started
# 2. 查看端口是否正常监听
netstat -ntpl | grep slurmdbd
tcp        0      0 0.0.0.0:6819            0.0.0.0:*               LISTEN      20095/slurmdbd
```
### 验证服务是否可用
```shell
sacct

JobID           JobName  Partition    Account  AllocCPUS      State ExitCode 
------------ ---------- ---------- ---------- ---------- ---------- -------- 
1              tf_mnist        gpu       root          8  COMPLETED      0:0 
1.batch           batch                  root          8  COMPLETED      0:0 
1.0             python3                  root          8  COMPLETED      0:0 
```
正常情况下在集群内任意节点 都可执行```sacct```来查看历史任务，但只能查看当前用户的历史任务，比如root 用户执行时是查看以root用户执行的job
## Login 节点配置
### 安装对应的slurm包
```shell
apt install ./slurm-smd_25.05.3-1_amd64.deb \
    ./slurm-smd-client_25.05.3-1_amd64.deb
```
### 创建Slurm运行服务的用户和组
```shell
sudo groupadd --system slurm && useradd --system --gid slurm --shell /sbin/nologin --home-dir /var/lib/slurm slurm
```
> 注意：此处创建的slurm用户的UID 要和控制节点中的UID保持一致，否则会报错 Security violation, ping RPC from uid 997
### 分发控制节点中的```slurm.conf```
```shell
# 复制控制节点中的slurm.conf
scp <控制节点IP>:/etc/slurm/slurm.conf /etc/slurm/
```
## 查看集群状态
```shell
root@server2:~# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
cpu          up   infinite      4   idle server[2-5]
memory       up   infinite      4   idle server[2-5]
gpu*         up   infinite      2   idle server[2-3]
```