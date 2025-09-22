# Slurm 部署手册
## 环境准备
### 角色规划
| 主机IP        | 主机名称    | 节点角色                  | 节点特殊设备 |
|-------------|---------|-----------------------|--------|
| 10.84.10.27 | server2 | 控制节点、计算节点、build节点和DB节点 | GPU*2  |
| 10.84.10.28 | server3 | 计算节点                  | GPU*2  |
| 10.84.3.163 | server4 | 计算节点                  |        |
| 10.84.3.164 | server5 | 计算节点                  |        |
| 10.84.3.165 | server6 | 登录节点                  |        |
| 10.84.3.166 | server7 | REST API节点            |        |
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
10.84.3.165 server6
10.84.3.166 server7
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

## 构建Slurm
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
# 传统模式
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
sudo groupadd --system --gid 999 slurm && \
sudo useradd --system \
  --uid 997 \
  --gid 999 \
  --shell /sbin/nologin \
  --home-dir /var/lib/slurm \
  --create-home \
  slurm
```
### 配置slurmdbd配置文件
```shell
cat > /etc/slurm/slurmdbd.conf << EOF 
#
# Example slurmdbd.conf file.
#
# See the slurmdbd.conf man page for more information.
#
# Archive info

# 是否归档事件/作业等
ArchiveEvents=yes                       # 清除事件时，也会将其存档。布尔值，yes存档事件数据，否则为no。默认值为no
ArchiveJobs=yes                         # 清除作业时，还要将其存档。布尔值，yes存档作业数据，否则为no。默认值为no。
ArchiveResvs=yes                        # 在清理（purge）过期或完成的资源预留（reservations）时，是否将这些预留信息归档保存。yes保存  否则为no
#ArchiveDir="/tmp"
ArchiveSteps=yes                        # 在清理作业步骤（steps）时，同时将其归档。布尔值，设为 “yes” 表示归档步骤数据，设为 “no” 则不归档。默认值为 “no”。
ArchiveSuspend=no                       # 在清理挂起（suspend）数据时，同时将其归档。布尔值，设为 “yes” 表示归档挂起数据，设为 “no” 则不归档。默认值为 “no”。
ArchiveTXN=no                           # 在清理事务（transaction）数据时，同时将其归档。布尔值，设为 “yes” 表示归档事务数据，设为 “no” 则不归档。默认值为 “no”。
ArchiveUsage=no                         # 在清理使用量数据（集群、关联账户和 WCKey）时，同时将其归档。布尔值，设为 “yes” 表示归档使用数据，设为 “no” 则不归档。默认值为 “no”。
#ArchiveScript=
#JobPurge=12
#StepPurge=1
#

# Munge 认证
AuthType=auth/munge                    # Slurm 各组件之间通信所使用的身份验证方法。 默认 auth/munge
AuthInfo=/var/run/munge/munge.socket.2 # 用于指定与各集群的 Slurm 控制守护进程（slurmctld）进行通信时，身份验证所需的附加信息。
#

# DBD 服务主机名和运行用户
DbdAddr=server2                        # 默认和DbdHost名称保持一致
DbdHost=server2                        # 指定运行 Slurm 数据库守护进程的机器主机名。
#DbdPort=7031
SlurmUser=slurm
#MessageTimeout=300
#DefaultQOS=normal,standby

# 日志 & PID
LogFile=/var/log/slurm/slurmdbd.log
PidFile=/run/slurmdbd/slurmdbd.pid
DebugLevel=verbose                     # Slurm 数据库守护进程（slurmdbd）日志的详细程度。默认值为 info。

# 清理策略
PurgeEventAfter=1month                 # 设置事件记录在结束后经过多长时间从数据库中清除。此类事件包括节点宕机时间等系统事件。此处是1个月
PurgeJobAfter=12month                  # 设置单个作业记录在结束后经过多长时间从数据库中清除。
PurgeResvAfter=1month                  # 设置单个资源预留记录在结束后经过多长时间从数据库中清除。
PurgeStepAfter=1month                  # 设置单个作业步骤记录在结束后经过多长时间从数据库中清除。
PurgeSuspendAfter=1month               # 单个作业挂起记录  在挂起事件结束后经过多长时间从数据库中清除。
PurgeTXNAfter=12month                  # 设置单个事务记录在发生后经过多长时间从数据库中清除。
PurgeUsageAfter=24month                # 设置资源使用记录 在创建或最后一次修改后，经过多长时间从数据库中清除。
#PluginDir=/usr/lib/slurm
#PrivateData=accounts,users,usage,jobs
#TrackWCKey=yes
#

# 数据库连接信息
StorageType=accounting_storage/mysql
StorageHost=10.84.10.27
StoragePort=3306
StoragePass=SecA@2025...
StorageUser=root
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
## 控制节点配置
### 安装对应的slurm包
```shell
apt install ./slurm-smd_25.05.3-1_amd64.deb \
    ./slurm-smd-client_25.05.3-1_amd64.deb \
    ./slurm-smd-slurmctld_25.05.3-1_amd64.deb
```
### 创建Slurm运行服务的用户和组
```shell
sudo groupadd --system --gid 999 slurm && \
sudo useradd --system \
  --uid 997 \
  --gid 999 \
  --shell /sbin/nologin \
  --home-dir /var/lib/slurm \
  --create-home \
  slurm
```
### 配置 slurm.conf
```shell
cat > /etc/slurm/slurm.conf << EOF
#
# Example slurm.conf file. Please run configurator.html
# (in doc/html) to build a configuration file customized
# for your environment.
#
#
# slurm.conf file generated by configurator.html.
# Put this file on all nodes of your cluster.
# See the slurm.conf man page for more information.
#
ClusterName=cool                    # 集群名，任意英文和数字名字
SlurmctldHost=server2(10.84.10.27)  # 启动slurmctld进程的节点名，如这里的server2   主服务器
#SlurmctldHost=server3(10.84.10.28)  # 备份服务器 
#SlurmctldHost=
#
#DisableRootJobs=NO
#EnforcePartLimits=NO
#Epilog=
#EpilogSlurmctld=
#FirstJobId=1
#MaxJobId=67043328
GresTypes=gpu                       # 设置GPU时需要
#GroupUpdateForce=0
#GroupUpdateTime=600
#JobFileAppend=0
#JobRequeue=1
#JobSubmitPlugins=lua
#KillOnBadExit=0
#LaunchType=launch/slurm
#Licenses=foo*4,bar
#MailProg=/bin/mail
#MaxJobCount=10000
#MaxStepCount=40000
#MaxTasksPerNode=512
MpiDefault=none                         # 默认MPI类型
#MpiParams=ports=#-#
#PluginDir=
#PlugStackConfig=
#PrivateData=jobs
ProctrackType=proctrack/cgroup         # 进程追踪，定义用于确定特定的作业所对应的进程的算法，它使用信号、杀死和记账与作业步相关联的进程
     # Cgroup: 采用Linux cgroup来生成作业容器并追踪进程，需要设定/etc/slurm/cgroup.conf文件
     # Cray XC: 采用Cray XC专有进程追踪
     # LinuxProc: 采用父进程IP记录，进程可以脱离Slurm控制
     # Pgid: 采用Unix进程组ID(Process Group ID)，进程如改变了其进程组ID则可以脱离Slurm控制
#Prolog=
#PrologFlags=
#PrologSlurmctld=
#PropagatePrioProcess=0
#PropagateResourceLimits=
#PropagateResourceLimitsExcept=
#RebootProgram=
AuthType=auth/munge                     # 认证方式，该处采用munge进行认证
ReturnToService=1                       # 设定当DOWN（失去响应）状态节点如何恢复服务，默认为0。 
     # 0: 节点状态保持DOWN状态，只有当管理员明确使其恢复服务时才恢复
     # 1: 仅当由于无响应而将DOWN节点设置为DOWN状态时，才可以当有效配置注册后使DOWN节点恢复服务。如节点由于任何其它原因（内存不足、意外重启等）被设置为DOWN，其状态将不会自动更改。当节点的内存、GRES、CPU计数等等于或大于slurm.conf中配置的值时，该节点才注册为有效配置。
     # 2: 使用有效配置注册后，DOWN节点将可供使用。该节点可能因任何原因被设置为DOWN状态。当节点的内存、GRES、CPU计数等等于或大于slurm.conf 中配置的值，该节点才注册为有效配置。￼

SlurmctldPidFile=/var/run/slurmctld.pid # 存储slurmctld进程号PID的文件
SlurmctldPort=6817                      # Slurmctld服务端口，设为6817，如不设置，默认为6817号端口
SlurmdPidFile=/var/run/slurmd.pid       # 存储slurmd进程号PID的文件
SlurmdPort=6818                         # Slurmd服务端口，设为6818，如不设置，默认为6818号端口
SlurmdSpoolDir=/var/spool/slurmd        # Slurmd服务所需要的目录，为各节点各自私有目录，不得多个slurmd节点共享
SlurmUser=slurm                         # 用户数据库操作的用户
#SlurmdUser=root
#SrunEpilog=
#SrunProlog=
StateSaveLocation=/var/spool/slurmctld  # 存储slurmctld服务状态的目录，如有备份控制节点，则需要所有SlurmctldHost节点都能共享读写该目录
SwitchType=switch/none                  # 用于应用程序通信的交换机或互连类型。默认值为无需特殊插件即可启动或终止作业（以太网和 InfiniBand）。
#TaskEpilog=
TaskPlugin=task/affinity,task/affinity  # #设定任务启动插件。可被用于提供节点内的资源管理（如绑定任务到特定处理器），TaskPlugin值可为: task/affinity: CPU亲和支持（man srun查看其中--cpu-bind、--mem-bind和-E选项）。task/cgroup: 强制采用Linux控制组cgroup分配资源（man group.conf查看帮助）。task/none: #无任务启动动作
#TaskProlog=
#TopologyPlugin=topology/tree
#TmpFS=/tmp
#TrackWCKey=no
#TreeWidth=
#UnkillableStepProgram=
#UsePAM=0
#
#
# TIMERS
#BatchStartTimeout=10
#CompleteWait=0
#EpilogMsgTime=2000
#GetEnvTimeout=2
#HealthCheckInterval=0
#HealthCheckProgram=
InactiveLimit=0                         # 潜伏期控制器等待srun命令响应多少秒后，将在考虑作业或作业步骤不活动并终止它之前。0表示无限长等待
KillWait=30                             # 在作业到达其时间限制前等待多少秒后在发送SIGKILLL信号之前发送TERM信号以优雅地终止
#MessageTimeout=10  
#ResvOverRun=0
MinJobAge=300                           # Slurm控制器在等待作业结束多少秒后清理其记录
#OverTimeLimit=0
SlurmctldTimeout=120                    # 设定备份控制器在主控制器等待多少秒后成为激活的控制器
SlurmdTimeout=300                       # Slurm控制器等待slurmd未响应请求多少秒后将该节点状态设置为DOWN
#UnkillableStepTimeout=60
#VSizeFactor=0
Waittime=0                              # 在一个作业步的第一个任务结束后等待多少秒后结束所有其它任务，0表示无限长等待
#
#
# SCHEDULING
#DefMemPerCPU=0
#MaxMemPerCPU=0
#SchedulerTimeSlice=30
SchedulerType=sched/backfill           # 要使用的调度程序的类型。注意，slurmctld守护程序必须重新启动才能使调度程序类型的更改生效（重新配置正在运行的守护程序对此参数无效）。如果需要，可以使用scontrol命令手动更改作业优先级。可接受的类型为：
     # sched/backfill # 用于回填调度模块以增加默认FIFO调度。如这样做不会延迟任何较高优先级作业的预期启动时间，则回填调度将启动较低优先级作业。回填调度的有效性取决于用户指定的作业时间限制，否则所有作业将具有相同的时间限制，并且回填是不可能的。注意上面SchedulerParameters选项的文档。这是默认配置
     # sched/builtin # 按优先级顺序启动作业的FIFO调度程序。如队列中的任何作业无法调度，则不会调度该队列中优先级较低的作业。对于作业的一个例外是由于队列限制（如时间限制）或关闭/耗尽节点而无法运行。在这种情况下，可以启动较低优先级的作业，而不会影响较高优先级的作业。
     # sched/hold # 如果 /etc/slurm.hold 文件存在，则暂停所有新提交的作业，否则使用内置的FIFO调度程序。
SelectType=select/cons_tres
#
#
# JOB PRIORITY
#PriorityFlags=
#PriorityType=priority/multifactor
#PriorityDecayHalfLife=
#PriorityCalcPeriod=
#PriorityFavorSmall=
#PriorityMaxAge=
#PriorityUsageResetPeriod=
#PriorityWeightAge=
#PriorityWeightFairshare=
#PriorityWeightJobSize=
#PriorityWeightPartition=
#PriorityWeightQOS=
#
#
# LOGGING AND ACCOUNTING
#AccountingStorageEnforce=0
AccountingStorageHost=server2                       # 记账数据库主机名
#AccountingStoragePass=
AccountingStoragePort=6819                          # 记账数据库服务监听端口
AccountingStorageType=accounting_storage/slurmdbd   # 与作业记账收集一起，Slurm可以采用不同风格存储可以以许多不同的方式存储会计信息，可为以下值之一：
     # accounting_storage/none: 不记录记账信息
     # accounting_storage/slurmdbd: 将作业记账信息写入Slurm DBD数据库
 # AccountingStorageLoc: 设定文件位置或数据库名，为完整绝对路径或为数据库的数据库名，当采用slurmdb时默认为slurm_acct_db

#AccountingStorageUser=
#AccountingStoreFlags=
#JobCompHost=
#JobCompLoc=
#JobCompPass=
#JobCompPort=
JobCompType=jobcomp/none
#JobCompUser=
#JobContainerType=
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=info                         # Slurmctld守护进程可以配置为采用不同级别的详细度记录，从0（不记录）到7（极度详细） 默认info
SlurmctldLogFile=/var/log/slurm/slurmctld.log     # slurmctld组件的日志文件，如是空白，则记录到syslog
SlurmdDebug=info                            # Slurmd守护进程可以配置为采用不同级别的详细度记录，从0（不记录）到7（极度详细） 默认info
SlurmdLogFile=/var/log/slurm/slurmd.log           # 如为空白，则记录到syslog，如名字中的有字符串"%h"，则"%h"将被替换为节点名
#SlurmSchedLogFile=
#SlurmSchedLogLevel=
#DebugFlags=
#
#
# POWER SAVE SUPPORT FOR IDLE NODES (optional)
#SuspendProgram=
#ResumeProgram=
#SuspendTimeout=
#ResumeTimeout=
#ResumeRate=
#SuspendExcNodes=
#SuspendExcParts=
#SuspendRate=
#SuspendTime=
#
#
# COMPUTE NODES
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

### 配置gres.conf
```shell
cat > /etc/slurm/gres.conf << EOF  
NodeName=server2 Name=gpu Type=nvidia_l40s File=/dev/nvidia0
NodeName=server2 Name=gpu Type=nvidia_l40s File=/dev/nvidia1
EOF
```
### 创建用户 & spool/log 目录
```shell
touch /var/log/slurm/slurmctld.log && mkdir /var/spool/slurmctld && chown -R slurm:slurm /var/log/slurm /var/spool/slurmctld /var/spool/slurmd
```
### 启动slurmctld
```shell
sudo systemctl enable slurmctld --now
```
### 验证服务是否正常
```shell
# 1.查看日志是否存在报错
cat /var/log/slurm/slurmctld.log 
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
### 注册 cluster 到数据库
```shell
sacctmgr -i add cluster cool
```
> 可以到MySQL中查看 slurm_acct_db 库中的表  查看是否有数据
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
echo "NodeName=server4 CPUs=8 Boards=1 SocketsPerBoard=8 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=15988" >> /etc/slurm/slurm.conf
```
> 注意：注册计算节点时，需要在集群内控制节点统一配置，之后使用scp指令 下发至每个计算节点，下发完成后重启服务生效
### 复制控制节点中的```slurm.conf```并创建```gres.conf```和```cgroup.conf```
```shell
#普通节点
scp <控制节点IP>:/etc/slurm/{cgroup.conf,slurm.conf} /etc/slurm/

cat > /etc/slurm/cgroup.conf  << EOF
ConstrainDevices=yes
ConstrainCores=yes
ConstrainRAMSpace=yes
ConstrainSwapSpace=no
EOF

# GPU节点创建gres.conf
cat > /etc/slurm/gres.conf << EOF
NodeName=server3 Name=gpu Type=nvidia_l40s File=/dev/nvidia0
NodeName=server3 Name=gpu Type=nvidia_l40s File=/dev/nvidia1
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
> 
- ConstrainDevices=yes  #根据作业所分配的 GRES（Generic Resources，通用资源）设备，限制该作业可访问的系统设备。此功能通过 Linux cgroup 的 devices 子系统 实现。
- ConstrainCores=yes    #将进程可使用的 CPU 核心限制在作业所分配资源的子集内。此功能依赖 Linux 的 cpuset 控制组（cgroup）子系统 实现。
- ConstrainRAMSpace=yes #根据作业所分配的内存资源，限制其可使用的物理内存（RAM）空间。
- ConstrainSwapSpace=no #限制作业可使用的交换空间（Swap）总量。默认值为 no —— 即不限制 Swap 使用。

### 创建Slurm运行服务的用户和组
```shell
sudo groupadd --system --gid 999 slurm && \
sudo useradd --system \
  --uid 997 \
  --gid 999 \
  --shell /sbin/nologin \
  --home-dir /var/lib/slurm \
  --create-home \
  slurm
```
> 注意：此处创建的slurm用户的UID 要和控制节点中的UID保持一致，否则会报错 Security violation, ping RPC from uid xxx
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
## Login 节点配置
### 安装对应的slurm包
```shell
apt install ./slurm-smd_25.05.3-1_amd64.deb \
    ./slurm-smd-client_25.05.3-1_amd64.deb
```
### 创建Slurm运行服务的用户和组
```shell
sudo groupadd --system --gid 999 slurm && \
sudo useradd --system \
  --uid 997 \
  --gid 999 \
  --shell /sbin/nologin \
  --home-dir /var/lib/slurm \
  --create-home \
  slurm
```
> 注意：此处创建的slurm用户的UID 要和控制节点中的UID保持一致，否则会报错 Security violation, ping RPC from uid 997
### 分发控制节点中的```slurm.conf```
```shell
# 复制控制节点中的slurm.conf
scp <控制节点IP>:/etc/slurm/slurm.conf /etc/slurm/
```
### 验证登录节点是否正常工作
```shell
root@server6:~# scontrol ping
Slurmctld(primary) at server2 is UP
root@server2:~# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
cpu          up   infinite      4   idle server[2-5]
memory       up   infinite      4   idle server[2-5]
gpu*         up   infinite      2   idle server[2-3]
```
## RESTAPI 节点部署
### 安装对应的slurm包
```shell
apt install ./slurm-smd_25.05.3-1_amd64.deb \
    ./slurm-smd-slurmd_25.05.3-1_amd64.deb \
    ./slurm-smd-slurmrestd_25.05.3-1_amd64.deb
```
### 创建本地服务帐户和组 运行 slurmrestd 守护进程。
```shell
sudo useradd -M -r -s /usr/sbin/nologin -U slurmrestd
```
### 复制控制节点中的```/etc/slurm/slurm.conf```到```/etc/slurm/```
```shell
scp <控制节点IP>:/etc/slurm/slurm.conf /etc/slurm/
```
# 无配置(configless)模式
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
sudo groupadd --system --gid 999 slurm && \
sudo useradd --system \
  --uid 997 \
  --gid 999 \
  --shell /sbin/nologin \
  --home-dir /var/lib/slurm \
  --create-home \
  slurm
```
### 配置slurmdbd配置文件
```shell
cat > /etc/slurm/slurmdbd.conf << EOF 
#
# Example slurmdbd.conf file.
#
# See the slurmdbd.conf man page for more information.
#
# Archive info

# 是否归档事件/作业等
ArchiveEvents=yes                       # 清除事件时，也会将其存档。布尔值，yes存档事件数据，否则为no。默认值为no
ArchiveJobs=yes                         # 清除作业时，还要将其存档。布尔值，yes存档作业数据，否则为no。默认值为no。
ArchiveResvs=yes                        # 在清理（purge）过期或完成的资源预留（reservations）时，是否将这些预留信息归档保存。yes保存  否则为no
#ArchiveDir="/tmp"
ArchiveSteps=yes                        # 在清理作业步骤（steps）时，同时将其归档。布尔值，设为 “yes” 表示归档步骤数据，设为 “no” 则不归档。默认值为 “no”。
ArchiveSuspend=no                       # 在清理挂起（suspend）数据时，同时将其归档。布尔值，设为 “yes” 表示归档挂起数据，设为 “no” 则不归档。默认值为 “no”。
ArchiveTXN=no                           # 在清理事务（transaction）数据时，同时将其归档。布尔值，设为 “yes” 表示归档事务数据，设为 “no” 则不归档。默认值为 “no”。
ArchiveUsage=no                         # 在清理使用量数据（集群、关联账户和 WCKey）时，同时将其归档。布尔值，设为 “yes” 表示归档使用数据，设为 “no” 则不归档。默认值为 “no”。
#ArchiveScript=
#JobPurge=12
#StepPurge=1
#

# Munge 认证
AuthType=auth/munge                    # Slurm 各组件之间通信所使用的身份验证方法。 默认 auth/munge
AuthInfo=/var/run/munge/munge.socket.2 # 用于指定与各集群的 Slurm 控制守护进程（slurmctld）进行通信时，身份验证所需的附加信息。
#

# DBD 服务主机名和运行用户
DbdAddr=server2                        # 默认和DbdHost名称保持一致
DbdHost=server2                        # 指定运行 Slurm 数据库守护进程的机器主机名。
#DbdPort=7031
SlurmUser=slurm
#MessageTimeout=300
#DefaultQOS=normal,standby

# 日志 & PID
LogFile=/var/log/slurm/slurmdbd.log
PidFile=/run/slurmdbd/slurmdbd.pid
DebugLevel=verbose                     # Slurm 数据库守护进程（slurmdbd）日志的详细程度。默认值为 info。

# 清理策略
PurgeEventAfter=1month                 # 设置事件记录在结束后经过多长时间从数据库中清除。此类事件包括节点宕机时间等系统事件。此处是1个月
PurgeJobAfter=12month                  # 设置单个作业记录在结束后经过多长时间从数据库中清除。
PurgeResvAfter=1month                  # 设置单个资源预留记录在结束后经过多长时间从数据库中清除。
PurgeStepAfter=1month                  # 设置单个作业步骤记录在结束后经过多长时间从数据库中清除。
PurgeSuspendAfter=1month               # 单个作业挂起记录  在挂起事件结束后经过多长时间从数据库中清除。
PurgeTXNAfter=12month                  # 设置单个事务记录在发生后经过多长时间从数据库中清除。
PurgeUsageAfter=24month                # 设置资源使用记录 在创建或最后一次修改后，经过多长时间从数据库中清除。
#PluginDir=/usr/lib/slurm
#PrivateData=accounts,users,usage,jobs
#TrackWCKey=yes
#

# 数据库连接信息
StorageType=accounting_storage/mysql
StorageHost=10.84.10.27
StoragePort=3306
StoragePass=SecA@2025...
StorageUser=root
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
## 控制节点配置
### 安装对应的slurm包
```shell
apt install ./slurm-smd_25.05.3-1_amd64.deb \
    ./slurm-smd-client_25.05.3-1_amd64.deb \
    ./slurm-smd-slurmctld_25.05.3-1_amd64.deb
```
### 创建Slurm运行服务的用户和组
```shell
sudo groupadd --system --gid 999 slurm && \
sudo useradd --system \
  --uid 997 \
  --gid 999 \
  --shell /sbin/nologin \
  --home-dir /var/lib/slurm \
  --create-home \
  slurm
```
### 配置 slurm.conf
```shell
cat > /etc/slurm/slurm.conf << EOF
#
# Example slurm.conf file. Please run configurator.html
# (in doc/html) to build a configuration file customized
# for your environment.
#
#
# slurm.conf file generated by configurator.html.
# Put this file on all nodes of your cluster.
# See the slurm.conf man page for more information.
#
ClusterName=cool                    # 集群名，任意英文和数字名字
SlurmctldHost=server2(10.84.10.27)  # 启动slurmctld进程的节点名，如这里的server2   主服务器
#SlurmctldHost=server3(10.84.10.28)  # 备份服务器 
SlurmctldParameters=enable_configless # 采用无配置模式
#SlurmctldHost=
#
#DisableRootJobs=NO
#EnforcePartLimits=NO
#Epilog=
#EpilogSlurmctld=
#FirstJobId=1
#MaxJobId=67043328
GresTypes=gpu                       # 设置GPU时需要
#GroupUpdateForce=0
#GroupUpdateTime=600
#JobFileAppend=0
#JobRequeue=1
#JobSubmitPlugins=lua
#KillOnBadExit=0
#LaunchType=launch/slurm
#Licenses=foo*4,bar
#MailProg=/bin/mail
#MaxJobCount=10000
#MaxStepCount=40000
#MaxTasksPerNode=512
MpiDefault=none                         # 默认MPI类型
#MpiParams=ports=#-#
#PluginDir=
#PlugStackConfig=
#PrivateData=jobs
ProctrackType=proctrack/cgroup         # 进程追踪，定义用于确定特定的作业所对应的进程的算法，它使用信号、杀死和记账与作业步相关联的进程
     # Cgroup: 采用Linux cgroup来生成作业容器并追踪进程，需要设定/etc/slurm/cgroup.conf文件
     # Cray XC: 采用Cray XC专有进程追踪
     # LinuxProc: 采用父进程IP记录，进程可以脱离Slurm控制
     # Pgid: 采用Unix进程组ID(Process Group ID)，进程如改变了其进程组ID则可以脱离Slurm控制
#Prolog=
#PrologFlags=
#PrologSlurmctld=
#PropagatePrioProcess=0
#PropagateResourceLimits=
#PropagateResourceLimitsExcept=
#RebootProgram=
AuthType=auth/munge                     # 认证方式，该处采用munge进行认证
ReturnToService=1                       # 设定当DOWN（失去响应）状态节点如何恢复服务，默认为0。 
     # 0: 节点状态保持DOWN状态，只有当管理员明确使其恢复服务时才恢复
     # 1: 仅当由于无响应而将DOWN节点设置为DOWN状态时，才可以当有效配置注册后使DOWN节点恢复服务。如节点由于任何其它原因（内存不足、意外重启等）被设置为DOWN，其状态将不会自动更改。当节点的内存、GRES、CPU计数等等于或大于slurm.conf中配置的值时，该节点才注册为有效配置。
     # 2: 使用有效配置注册后，DOWN节点将可供使用。该节点可能因任何原因被设置为DOWN状态。当节点的内存、GRES、CPU计数等等于或大于slurm.conf 中配置的值，该节点才注册为有效配置。￼

SlurmctldPidFile=/var/run/slurmctld.pid # 存储slurmctld进程号PID的文件
SlurmctldPort=6817                      # Slurmctld服务端口，设为6817，如不设置，默认为6817号端口
SlurmdPidFile=/var/run/slurmd.pid       # 存储slurmd进程号PID的文件
SlurmdPort=6818                         # Slurmd服务端口，设为6818，如不设置，默认为6818号端口
SlurmdSpoolDir=/var/spool/slurmd        # Slurmd服务所需要的目录，为各节点各自私有目录，不得多个slurmd节点共享
SlurmUser=slurm                         # 用户数据库操作的用户
#SlurmdUser=root
#SrunEpilog=
#SrunProlog=
StateSaveLocation=/var/spool/slurmctld  # 存储slurmctld服务状态的目录，如有备份控制节点，则需要所有SlurmctldHost节点都能共享读写该目录
SwitchType=switch/none                  # 用于应用程序通信的交换机或互连类型。默认值为无需特殊插件即可启动或终止作业（以太网和 InfiniBand）。
#TaskEpilog=
TaskPlugin=task/affinity,task/affinity  # #设定任务启动插件。可被用于提供节点内的资源管理（如绑定任务到特定处理器），TaskPlugin值可为: task/affinity: CPU亲和支持（man srun查看其中--cpu-bind、--mem-bind和-E选项）。task/cgroup: 强制采用Linux控制组cgroup分配资源（man group.conf查看帮助）。task/none: #无任务启动动作
#TaskProlog=
#TopologyPlugin=topology/tree
#TmpFS=/tmp
#TrackWCKey=no
#TreeWidth=
#UnkillableStepProgram=
#UsePAM=0
#
#
# TIMERS
#BatchStartTimeout=10
#CompleteWait=0
#EpilogMsgTime=2000
#GetEnvTimeout=2
#HealthCheckInterval=0
#HealthCheckProgram=
InactiveLimit=0                         # 潜伏期控制器等待srun命令响应多少秒后，将在考虑作业或作业步骤不活动并终止它之前。0表示无限长等待
KillWait=30                             # 在作业到达其时间限制前等待多少秒后在发送SIGKILLL信号之前发送TERM信号以优雅地终止
#MessageTimeout=10  
#ResvOverRun=0
MinJobAge=300                           # Slurm控制器在等待作业结束多少秒后清理其记录
#OverTimeLimit=0
SlurmctldTimeout=120                    # 设定备份控制器在主控制器等待多少秒后成为激活的控制器
SlurmdTimeout=300                       # Slurm控制器等待slurmd未响应请求多少秒后将该节点状态设置为DOWN
#UnkillableStepTimeout=60
#VSizeFactor=0
Waittime=0                              # 在一个作业步的第一个任务结束后等待多少秒后结束所有其它任务，0表示无限长等待
#
#
# SCHEDULING
#DefMemPerCPU=0
#MaxMemPerCPU=0
#SchedulerTimeSlice=30
SchedulerType=sched/backfill           # 要使用的调度程序的类型。注意，slurmctld守护程序必须重新启动才能使调度程序类型的更改生效（重新配置正在运行的守护程序对此参数无效）。如果需要，可以使用scontrol命令手动更改作业优先级。可接受的类型为：
     # sched/backfill # 用于回填调度模块以增加默认FIFO调度。如这样做不会延迟任何较高优先级作业的预期启动时间，则回填调度将启动较低优先级作业。回填调度的有效性取决于用户指定的作业时间限制，否则所有作业将具有相同的时间限制，并且回填是不可能的。注意上面SchedulerParameters选项的文档。这是默认配置
     # sched/builtin # 按优先级顺序启动作业的FIFO调度程序。如队列中的任何作业无法调度，则不会调度该队列中优先级较低的作业。对于作业的一个例外是由于队列限制（如时间限制）或关闭/耗尽节点而无法运行。在这种情况下，可以启动较低优先级的作业，而不会影响较高优先级的作业。
     # sched/hold # 如果 /etc/slurm.hold 文件存在，则暂停所有新提交的作业，否则使用内置的FIFO调度程序。
SelectType=select/cons_tres
#
#
# JOB PRIORITY
#PriorityFlags=
#PriorityType=priority/multifactor
#PriorityDecayHalfLife=
#PriorityCalcPeriod=
#PriorityFavorSmall=
#PriorityMaxAge=
#PriorityUsageResetPeriod=
#PriorityWeightAge=
#PriorityWeightFairshare=
#PriorityWeightJobSize=
#PriorityWeightPartition=
#PriorityWeightQOS=
#
#
# LOGGING AND ACCOUNTING
#AccountingStorageEnforce=0
AccountingStorageHost=server2                       # 记账数据库主机名
#AccountingStoragePass=
AccountingStoragePort=6819                          # 记账数据库服务监听端口
AccountingStorageType=accounting_storage/slurmdbd   # 与作业记账收集一起，Slurm可以采用不同风格存储可以以许多不同的方式存储会计信息，可为以下值之一：
     # accounting_storage/none: 不记录记账信息
     # accounting_storage/slurmdbd: 将作业记账信息写入Slurm DBD数据库
 # AccountingStorageLoc: 设定文件位置或数据库名，为完整绝对路径或为数据库的数据库名，当采用slurmdb时默认为slurm_acct_db

#AccountingStorageUser=
#AccountingStoreFlags=
#JobCompHost=
#JobCompLoc=
#JobCompPass=
#JobCompPort=
JobCompType=jobcomp/none
#JobCompUser=
#JobContainerType=
JobAcctGatherFrequency=30
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=info                         # Slurmctld守护进程可以配置为采用不同级别的详细度记录，从0（不记录）到7（极度详细） 默认info
SlurmctldLogFile=/var/log/slurm/slurmctld.log     # slurmctld组件的日志文件，如是空白，则记录到syslog
SlurmdDebug=info                            # Slurmd守护进程可以配置为采用不同级别的详细度记录，从0（不记录）到7（极度详细） 默认info
SlurmdLogFile=/var/log/slurm/slurmd.log           # 如为空白，则记录到syslog，如名字中的有字符串"%h"，则"%h"将被替换为节点名
#SlurmSchedLogFile=
#SlurmSchedLogLevel=
#DebugFlags=
#
#
# POWER SAVE SUPPORT FOR IDLE NODES (optional)
#SuspendProgram=
#ResumeProgram=
#SuspendTimeout=
#ResumeTimeout=
#ResumeRate=
#SuspendExcNodes=
#SuspendExcParts=
#SuspendRate=
#SuspendTime=
#
#
# COMPUTE NODES
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

### 配置gres.conf
```shell
cat > /etc/slurm/gres.conf << EOF  
NodeName=server2 Name=gpu Type=nvidia_l40s File=/dev/nvidia0
NodeName=server2 Name=gpu Type=nvidia_l40s File=/dev/nvidia1

NodeName=server3 Name=gpu Type=nvidia_l40s File=/dev/nvidia0
NodeName=server3 Name=gpu Type=nvidia_l40s File=/dev/nvidia1
EOF
```
> 注意：在无配置模型的架构中 控制节点中的gres.conf文件需要填写集群内部所有的资源配置，比如集群内server2 和server3 中 各有两块显卡，在传统模式是在每个机器的/etc/slurm/中放一份gres.conf文件，gres.conf文件记录当前所在节点的显卡资源，在无配置模式中是在控制节点中/etc/slurm/放一份gres.conf文件，此文件需要记录集群内所有GPU资源的配置信息
### 创建用户 & spool/log 目录
```shell
touch /var/log/slurm/slurmctld.log && mkdir /var/spool/slurmctld && chown -R slurm:slurm /var/log/slurm /var/spool/slurmctld /var/spool/slurmd
```
### 启动slurmctld
```shell
sudo systemctl enable slurmctld --now
```
### 验证服务是否正常
```shell
# 1.查看日志是否存在报错
cat /var/log/slurm/slurmctld.log 
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
### 注册 cluster 到数据库
```shell
sacctmgr -i add cluster cool
```
> 可以到MySQL中查看 slurm_acct_db 库中的表  查看是否有数据
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
echo "NodeName=server4 CPUs=8 Boards=1 SocketsPerBoard=8 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=15988" >> /etc/slurm/slurm.conf
```
> 注意：注册计算节点时，需要在集群内控制节点统一配置，之后使用scp指令 下发至每个计算节点，下发完成后重启服务生效
### 修改slurmd的service文件
```shell
cat > /lib/systemd/system/slurmd.service << 
[Unit]
Description=Slurm node daemon
After=munge.service network-online.target remote-fs.target sssd.service
Wants=network-online.target
#ConditionPathExists=/etc/slurm/slurm.conf

[Service]
Type=notify
EnvironmentFile=-/etc/sysconfig/slurmd
EnvironmentFile=-/etc/default/slurmd
RuntimeDirectory=slurm
RuntimeDirectoryMode=0755
ExecStart=/usr/sbin/slurmd --systemd $SLURMD_OPTIONS --conf-server server2:6817
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
LimitNOFILE=131072
LimitMEMLOCK=infinity
LimitSTACK=infinity
Delegate=yes
TasksMax=infinity

# Uncomment the following lines to disable logging through journald.
# NOTE: It may be preferable to set these through an override file instead.
#StandardOutput=null
#StandardError=null

[Install]
WantedBy=multi-user.target
EOF
```
在```ExecStart```最后加上```--conf-server server2:6817```
### 创建Slurm运行服务的用户和组
```shell
sudo groupadd --system --gid 999 slurm && \
sudo useradd --system \
  --uid 997 \
  --gid 999 \
  --shell /sbin/nologin \
  --home-dir /var/lib/slurm \
  --create-home \
  slurm
```
> 注意：此处创建的slurm用户的UID 要和控制节点中的UID保持一致，否则会报错 Security violation, ping RPC from uid xxx
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
## Login 节点配置
### 安装对应的slurm包
```shell
apt install ./slurm-smd_25.05.3-1_amd64.deb \
    ./slurm-smd-client_25.05.3-1_amd64.deb
```
### 创建Slurm运行服务的用户和组
```shell
sudo groupadd --system --gid 999 slurm && \
sudo useradd --system \
  --uid 997 \
  --gid 999 \
  --shell /sbin/nologin \
  --home-dir /var/lib/slurm \
  --create-home \
  slurm
```
> 注意：此处创建的slurm用户的UID 要和控制节点中的UID保持一致，否则会报错 Security violation, ping RPC from uid 997
### 创建```slurm.conf```
```shell
cat > /etc/slurm/slurm.conf << EOF 
ClusterName=cool
ControlMachine=server2
SlurmctldPort=6817
AuthType=auth/munge
SlurmUser=slurm
EOF
```
### 验证登录节点是否正常工作
```shell
root@server6:~# scontrol ping
Slurmctld(primary) at server2 is UP
root@server6:~# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
cpu          up   infinite      4   idle server[2-5]
memory*      up   infinite      4   idle server[2-5]
gpu          up   infinite      2   idle server[2-3]
```
## RESTAPI 节点部署
### 安装对应的slurm包
```shell
apt install ./slurm-smd_25.05.3-1_amd64.deb \
    ./slurm-smd-slurmd_25.05.3-1_amd64.deb \
    ./slurm-smd-slurmrestd_25.05.3-1_amd64.deb
```
### 创建本地服务帐户和组 运行 slurmrestd 守护进程。
```shell
sudo useradd -M -r -s /usr/sbin/nologin -U slurmrestd
```
### 复制控制节点中的```/etc/slurm/slurm.conf```到```/etc/slurm/```
```shell
scp <控制节点IP>:/etc/slurm/slurm.conf /etc/slurm/
```