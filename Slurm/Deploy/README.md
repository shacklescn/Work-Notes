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
sudo mkdir -p /run/slurmdbd && sudo chown slurm:slurm /run/slurmdbd /etc/slurm/slurmdbd.conf && chmod 600 /etc/slurm/slurmdbd.conf
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
sudo mkdir -p /run/slurmdbd /var/log/slurm && sudo chown slurm:slurm /run/slurmdbd /var/log/slurm /etc/slurm/slurmdbd.conf && chmod 600 /etc/slurm/slurmdbd.conf
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

# 重新加载 slurmctld和 slurmd配置文件
sudo scontrol reconfigure
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
    ./slurm-smd-slurmrestd_25.05.3-1_amd64.deb \
    ./slurm-smd-client_25.05.3-1_amd64.deb
```
### 创建本地服务帐户和组 运行 slurmrestd 守护进程。
```shell
sudo useradd -M -r -s /usr/sbin/nologin -U slurmrestd
```
### 配置jwt认证（在控制节点操作）
#### 1. 安装jwt 软件包
```shell
apt install libjwt0 libjwt-dev
```
#### 2. 将相同的 JWT 密钥添加到slurmctld 和 slurmdbd。
仅对于控制器，建议将 JWT 密钥放在 StateSaveLocation 中。
例如，使用 /var/spool/slurm/statesave/：
```shell
mkdir -p /var/spool/slurm/statesave/
dd if=/dev/random of=/var/spool/slurm/statesave/jwt_hs256.key bs=32 count=1
chown slurm：slurm /var/spool/slurm/statesave/jwt_hs256.key 
chmod 0600 /var/spool/slurm/statesave/jwt_hs256.key 
chown slurm：slurm /var/spool/slurm/statesave 
chmod 0755 /var/spool/slurm/statesave
```
#### 3. 在 slurm.conf 和 slurmdbd.conf 中，添加 JWT 作为替代身份验证类型
```shell
AuthAltTypes=auth/jwt 
AuthAltParameters=jwt_key=/var/spool/slurm/statesave/jwt_hs256.key
```
#### 4. 重启 slurmctld
```shell
systemctl restart slurmctld.service
```
> 注意：重启完slurmctld后，需要重载全部计算节点的服务，不然slurmctld服务会报错 配置文件会不一致
#### 5. 根据需要为用户创建令牌
```shell
# 给当前用户创建jwt key 默认有效期 1800s
scontrol token 

# 给指定用户创建jwt key 默认有效期 1800s
scontrol token username=<用户名>

# 创建时设置有效期
scontrol token username=qwx lifespan=7200
```
> 注意：管理员可以通过在 slurm.conf 中设置AuthAltParameters=disable_token_creation参数来阻止用户生成令牌
### 创建RESTAPI所需```slurm.conf```文件
```shell
cat > /etc/slurm/slurm.conf << EOF
ClusterName=cool
SlurmctldHost=server2
SlurmctldPort=6817

AuthType=auth/munge

AccountingStorageType=accounting_storage/slurmdbd
AccountingStorageHost=server2
AccountingStoragePort=6819
EOF
```
### 编辑slurmrestd环境变量文件
```shell
cat > /etc/default/slurmrestd << EOF
SLURMRESTD_OPTIONS="-a rest_auth/jwt -s openapi/slurmctld -f /etc/slurm/slurm.conf :6820"
EOF
```
### 编辑slurmrestd服务文件并重启
```shell
cat > /lib/systemd/system/slurmrestd.service << EOF
[Unit]
Description=Slurm REST daemon
After=network-online.target remote-fs.target slurmctld.service
Wants=network-online.target
ConditionPathExists=/etc/slurm/slurm.conf

[Service]
Type=simple
EnvironmentFile=-/etc/default/slurmrestd
User=slurmrestd
Group=slurmrestd
ExecStart=/usr/sbin/slurmrestd $SLURMRESTD_OPTIONS
Environment=SLURM_JWT=daemon
ExecReload=/bin/kill -HUP $MAINPID
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl restart slurmrestd
```
> 注意：服务启动后会有以下两个报错，可忽略
> 
> error: Couldn't find the specified plugin name for tls/s2n looking at all files
> 
> error: cannot find tls plugin for tls/s2n
### 测试slurmrestd是否正常工作
#### 1. 查看分区
```shell
curl -H "X-SLURM-USER-NAME: qwx" \
     -H "X-SLURM-USER-TOKEN: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NTg2MTQzNDcsImlhdCI6MTc1ODYxMjU0Nywic3VuIjoicXd4In0.0SHHnc_3viOMfvRv1-Ci3hG59msflep4jweCt-RNRhs" \
     http://server7:6820/slurm/v0.0.42/partitions
{
  "partitions": [
    {
      "nodes": {
        "allowed_allocation": "",
        "configured": "server[2-5]",
        "total": 4
      },
      "accounts": {
        "allowed": "",
        "deny": ""
      },
      "groups": {
        "allowed": ""
      },
      "qos": {
        "allowed": "",
        "deny": "",
        "assigned": ""
      },
      "alternate": "",
      "tres": {
        "billing_weights": "",
        "configured": "cpu=208,mem=1063398M,node=4,billing=208"
      },
      "cluster": "",
      "select_type": [
      ],
      "cpus": {
        "task_binding": 0,
        "total": 208
      },
      "defaults": {
        "memory_per_cpu": 0,
        "partition_memory_per_cpu": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "partition_memory_per_node": {
          "set": true,
          "infinite": false,
          "number": 0
        },
        "time": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "job": ""
      },
      "grace_time": 0,
      "maximums": {
        "cpus_per_node": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "cpus_per_socket": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "memory_per_cpu": 0,
        "partition_memory_per_cpu": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "partition_memory_per_node": {
          "set": true,
          "infinite": false,
          "number": 0
        },
        "nodes": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "shares": 1,
        "oversubscribe": {
          "jobs": 1,
          "flags": [
          ]
        },
        "time": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "over_time_limit": {
          "set": false,
          "infinite": false,
          "number": 0
        }
      },
      "minimums": {
        "nodes": 0
      },
      "name": "cpu",
      "node_sets": "",
      "priority": {
        "job_factor": 1,
        "tier": 1
      },
      "timeouts": {
        "resume": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "suspend": {
          "set": false,
          "infinite": false,
          "number": 0
        }
      },
      "partition": {
        "state": [
          "UP"
        ]
      },
      "suspend_time": {
        "set": false,
        "infinite": false,
        "number": 0
      }
    },
    {
      "nodes": {
        "allowed_allocation": "",
        "configured": "server[2-5]",
        "total": 4
      },
      "accounts": {
        "allowed": "",
        "deny": ""
      },
      "groups": {
        "allowed": ""
      },
      "qos": {
        "allowed": "",
        "deny": "",
        "assigned": ""
      },
      "alternate": "",
      "tres": {
        "billing_weights": "",
        "configured": "cpu=208,mem=1063398M,node=4,billing=208"
      },
      "cluster": "",
      "select_type": [
      ],
      "cpus": {
        "task_binding": 0,
        "total": 208
      },
      "defaults": {
        "memory_per_cpu": 0,
        "partition_memory_per_cpu": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "partition_memory_per_node": {
          "set": true,
          "infinite": false,
          "number": 0
        },
        "time": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "job": ""
      },
      "grace_time": 0,
      "maximums": {
        "cpus_per_node": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "cpus_per_socket": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "memory_per_cpu": 0,
        "partition_memory_per_cpu": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "partition_memory_per_node": {
          "set": true,
          "infinite": false,
          "number": 0
        },
        "nodes": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "shares": 1,
        "oversubscribe": {
          "jobs": 1,
          "flags": [
          ]
        },
        "time": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "over_time_limit": {
          "set": false,
          "infinite": false,
          "number": 0
        }
      },
      "minimums": {
        "nodes": 0
      },
      "name": "mem_nodes",
      "node_sets": "",
      "priority": {
        "job_factor": 1,
        "tier": 1
      },
      "timeouts": {
        "resume": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "suspend": {
          "set": false,
          "infinite": false,
          "number": 0
        }
      },
      "partition": {
        "state": [
          "UP"
        ]
      },
      "suspend_time": {
        "set": false,
        "infinite": false,
        "number": 0
      }
    },
    {
      "nodes": {
        "allowed_allocation": "",
        "configured": "server[2-3]",
        "total": 2
      },
      "accounts": {
        "allowed": "",
        "deny": ""
      },
      "groups": {
        "allowed": ""
      },
      "qos": {
        "allowed": "",
        "deny": "",
        "assigned": ""
      },
      "alternate": "",
      "tres": {
        "billing_weights": "",
        "configured": "cpu=192,mem=1031422M,node=2,billing=192"
      },
      "cluster": "",
      "select_type": [
      ],
      "cpus": {
        "task_binding": 0,
        "total": 192
      },
      "defaults": {
        "memory_per_cpu": 0,
        "partition_memory_per_cpu": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "partition_memory_per_node": {
          "set": true,
          "infinite": false,
          "number": 0
        },
        "time": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "job": ""
      },
      "grace_time": 0,
      "maximums": {
        "cpus_per_node": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "cpus_per_socket": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "memory_per_cpu": 0,
        "partition_memory_per_cpu": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "partition_memory_per_node": {
          "set": true,
          "infinite": false,
          "number": 0
        },
        "nodes": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "shares": 1,
        "oversubscribe": {
          "jobs": 1,
          "flags": [
          ]
        },
        "time": {
          "set": false,
          "infinite": true,
          "number": 0
        },
        "over_time_limit": {
          "set": false,
          "infinite": false,
          "number": 0
        }
      },
      "minimums": {
        "nodes": 0
      },
      "name": "gpu",
      "node_sets": "",
      "priority": {
        "job_factor": 1,
        "tier": 1
      },
      "timeouts": {
        "resume": {
          "set": false,
          "infinite": false,
          "number": 0
        },
        "suspend": {
          "set": false,
          "infinite": false,
          "number": 0
        }
      },
      "partition": {
        "state": [
          "UP"
        ]
      },
      "suspend_time": {
        "set": false,
        "infinite": false,
        "number": 0
      }
    }
  ],
  "last_update": {
    "set": true,
    "infinite": false,
    "number": 1758612639
  },
  "meta": {
    "plugin": {
      "type": "openapi\/slurmctld",
      "name": "Slurm OpenAPI slurmctld",
      "data_parser": "data_parser\/v0.0.42",
      "accounting_storage": ""
    },
    "client": {
      "source": "server7:6820(fd:10)",
      "user": "root",
      "group": "root"
    },
    "command": [
    ],
    "slurm": {
      "version": {
        "major": "25",
        "micro": "3",
        "minor": "05"
      },
      "release": "25.05.3",
      "cluster": "cool"
    }
  },
  "errors": [
  ],
  "warnings": [
    {
      "description": "Slurm accounting storage is disabled. Could not query the following: [TRES].",
      "source": ""
    }
  ]
}
```
#### 2. 查看作业队列
```shell
curl -H "X-SLURM-USER-NAME: qwx" \
     -H "X-SLURM-USER-TOKEN: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJleHAiOjE3NTg2MTQzNDcsImlhdCI6MTc1ODYxMjU0Nywic3VuIjoicXd4In0.0SHHnc_3viOMfvRv1-Ci3hG59msflep4jweCt-RNRhs" \
     http://server7:6820/slurm/v0.0.42/jobs
{
  "jobs": [
  ],
  "last_backfill": {
    "set": true,
    "infinite": false,
    "number": 1758605397
  },
  "last_update": {
    "set": true,
    "infinite": false,
    "number": 1758612568
  },
  "meta": {
    "plugin": {
      "type": "openapi\/slurmctld",
      "name": "Slurm OpenAPI slurmctld",
      "data_parser": "data_parser\/v0.0.42",
      "accounting_storage": ""
    },
    "client": {
      "source": "server7:6820(fd:10)",
      "user": "root",
      "group": "root"
    },
    "command": [
    ],
    "slurm": {
      "version": {
        "major": "25",
        "micro": "3",
        "minor": "05"
      },
      "release": "25.05.3",
      "cluster": "cool"
    }
  },
  "errors": [
  ],
  "warnings": [
    {
      "description": "Zero jobs to dump",
      "source": ""
    }
  ]
}
```
## Slurm-Web
离线安装包： https://pan.quark.cn/s/0ffb075efe0b
```shell
# 解压离线包
tar zxvf slurm-web-offine-os22.04-v5.1.tar.gz 

# 安装离线包
cd slurm-web-offine
apt install ./slurm-web-agent_*.deb ./slurm-web-gateway_*.deb
```
### 安装Racksdb
```shell
# 安装依赖
apt install libcairo2-dev libgirepository1.0-dev

# 安装racksdb
apt install -y ./racksdb_0.5.0-1.ubuntu2404_all.deb

# 引导数据库
cp -r /usr/share/doc/python3-racksdb/examples/db/* /var/lib/racksdb/

# 获取数据中心信息
racksdb datacenters

# 获取机架内容
racksdb racks --name R1-A01 --format json

# 获取基础架构中的计算节点列表
racksdb nodes --infrastructure mercury --tags compute --list

# 更改agent配置文件
vim /etc/slurm-web/agent.ini
...........
[racksdb]

# 控制是否启用 RacksDB 集成功能，用于高级资源可视化
#
# 默认值: yes
enabled=no

# RacksDB 数据库路径
#
# 默认值: /var/lib/racksdb
db=/var/lib/racksdb

# RacksDB 数据库模式(schema)路径
#
# 默认值: /usr/share/racksdb/schemas/racksdb.yml
schema=/usr/share/racksdb/schemas/racksdb.yml

# 站点特定的 RacksDB 模式扩展路径
#
# 默认值: /etc/racksdb/extensions.yml
extensions=/etc/racksdb/extensions.yml

# RacksDB 数据库绘图模式(schema)路径
#
# 默认值: /usr/share/racksdb/schemas/drawings.yml
drawings_schema=/usr/share/racksdb/schemas/drawings.yml

# 集群在 RacksDB 中对应的基础设施名称。默认使用集群名
#infrastructure=atlas
infrastructure=mercury

# 应用于 RacksDB 数据库中计算节点的标签列表
#
# 默认值:
# - compute
tags=
  compute
```
### 安装Redis
```shell
cat > redis.conf << EOF
# 基本设置
bind 0.0.0.0
protected-mode yes
port 6379
tcp-backlog 511

# 安全 / 认证
# 请将下面的密码换为你自己的强密码
requirepass SecA@2025...

# 客户端超时（秒），0 表示关闭
timeout 0

# 日志
loglevel notice
# 空字符串表示输出到 stdout（容器环境常用）
logfile ""
syslog-enabled no

# 数据库
databases 16

# 持久化：RDB 快照配置（可选，同时可以使用 AOF）
save 900 1
save 300 10
save 60 10000

# 快照压缩（默认 yes）
rdbcompression yes

# RDB 文件位置
dir /data
dbfilename dump.rdb

# AOF（追加式日志）配置，推荐在生产开启
appendonly yes
appendfilename "appendonly.aof"
# always = 每条写操作都 fsync； everysec = 每秒 fsync； no = 由操作系统决定（性能最优但有风险）
# 生产一般选择 everysec
appendfsync everysec
# 重写策略
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# 限制内存（可根据机器规格调整）
# maxmemory 2gb
# maxmemory-policy volatile-lru

# 客户端连接 / 管道
client-output-buffer-limit pubsub 32mb 8mb 60
client-output-buffer-limit slave 256mb 64mb 60
client-output-buffer-limit normal 0 0 0

# 性能 / IO 调优
activerehashing yes
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
lazyfree-lazy-server-del yes

# 复制 / 主从（如不需要可保留默认注释）
# replicaof <masterip> <masterport>
# masterauth <masterpassword>

# 安全 / 限制
# 禁止 CONFIG 命令、重写等敏感操作（可启用 ACL，更细粒度控制）
# rename-command CONFIG ""
# rename-command SHUTDOWN ""
# rename-command FLUSHDB ""
# rename-command FLUSHALL ""
EOF
```
```shell
cat > docker-compose.yaml << EOF
services:
  redis:
    image: redis:8.2.2
    container_name: redis
    command: ["redis-server", "/usr/local/etc/redis/redis.conf"]
    ports:
      - "6379:6379"
    volumes:
      - ./redis.conf:/usr/local/etc/redis/redis.conf:ro
      - ./redis_data:/data
    restart: unless-stopped
EOF

#启动redis
docker-compose up -d
```
### 配置slurm-web-agent
```shell
cat > /etc/slurm-web/agent.ini << EOF
# This file is an example configuration file for Slurm-web agent
#
# Please DO NOT USE THIS FILE as a basis for your custom
# /etc/slurm-web/agent.ini.

[service]

# Name of cluster served by agent
#
# This parameter is required.  # 需修改为slurm集群名称
cluster=cool   

# Interface address to bind for incoming connections
#
# Default value: localhost  #默认端口只能本机访问  如果想让外部访问需设置IP
interface=10.84.3.164

# TCP port to listen for incoming connections
#
# Default value: 5012
port=5012

# When true, Cross-Origin Resource Sharing (CORS) headers are enabled.
cors=no

# Enable debug mode
debug=no

# List of log flags to enable. Special value `ALL` enables all log flags.
#
# Possible values:
# - slurmweb
# - rfl
# - werkzeug
# - urllib3
# - racksdb
# - ALL
#
# Default value:
# - ALL
log_flags=
  ALL

# List of debug flags to enable. Special value `ALL` enables all debug
# flags.
#
# Possible values:
# - slurmweb
# - rfl
# - werkzeug
# - urllib3
# - racksdb
# - ALL
#
# Default value:
# - slurmweb
debug_flags=
  slurmweb

[slurmrestd]

# URI to slurmrestd HTTP server. It can either be in the form
# http://host:port for TCP/IP server or unix:///path/to/slurmrestd.socket
# for Unix socket.
#
# Default value: unix:/run/slurmrestd/slurmrestd.socket # slurmrestd的连接端口
uri=http://server7:6820

# Authentication method with slurmrestd.
#
# The `jwt` authentication method is supported by both TCP/IP and Unix
# sockets URIs.
#
# Note that `local` authentication method is only supported with Unix socket
# URI and Slurm <= 24.11. With this method, Slurm-web agent must run with
# the _slurm_ system user as well as `slurmrestd` service. Running
# `slurmrestd` as _slurm_ system user is not possible with Slurm >= 25.05.
#
# Possible values:
# - local
# - jwt
#
# Default value: jwt
auth=jwt

# Slurmrestd JWT authentication mode, either _auto_ or _static_.
#
# In _auto_ mode, Slurm-web agent generates tokens with the signature key
# specified in `jwt_key`. The tokens have a limited lifespan as defined with
# `jwt_lifespan`. Tokens are automatically renewed upon expiration. This is
# the recommended mode.
#
# In _static_ mode, Slurm-web simply use the token provided with
# `jwt_token`.
#
# This parameter is used only when `auth` is _jwt_.
#
# Possible values:
# - auto
# - static
#
# Default value: auto
jwt_mode=auto

# The user name used in HTTP headers with JWT authentication.
#
# This parameter is used only when `auth` is _jwt_.
#
# Default value: slurm
jwt_user=slurm

# Lifespan of JWT tokens generated by Slurm-web in seconds. The default
# value is 1 hour.
#
# This parameter is used only when `auth` is _jwt_ and `jwt_mode` is _auto_.
#
# Default value: 3600
jwt_lifespan=3600

# Path to private key shared with Slurm for JWT signature. The key is used
# by Slurm-web to generate its token for authentication on slurmrestd in
# _auto_ mode. It must be the same key as used in Slurm `AuthAltParameters`
# so that Slurm services can validate JWT generated by Slurm-web.
#
# This parameter is used only when `auth` is _jwt_  and `jwt_mode` is
# _auto_.
#
# Default value: /var/lib/slurm-web/slurmrestd.key
jwt_key=/var/lib/slurm-web/slurmrestd.key

# The static JSON Web Token (JWT) used in HTTP headers with JWT
# authentication, typically generated with `scontrol token`. While this is
# generally not a good practice, it is recommended to generate tokens with
# infinite lifespan to avoid failures due to expired token.
#
# This parameter is used only when `auth` is _jwt_ and `jwt_mode` is
# _static_.
jwt_token=None

# Slurm REST API version.
#
# CAUTION: You SHOULD NOT change this parameter unless you really know what
# you are doing. This parameter is more intented for Slurm-web developers
# rather than end users. Slurm-web is officially tested and validated with
# the default value only.
#
# Default value: 0.0.41
version=0.0.41

[filters]

# List of jobs fields selected in slurmrestd API when retrieving a list of
# jobs, all other fields arefiltered out.
#
# Default value:
# - account
# - cpus
# - gres_detail
# - job_id
# - job_state
# - node_count
# - nodes
# - partition
# - priority
# - qos
# - sockets_per_node
# - state_reason
# - tasks
# - tres_per_job
# - tres_per_node
# - tres_per_socket
# - tres_per_task
# - user_name
jobs=
  account
  cpus
  gres_detail
  job_id
  job_state
  node_count
  nodes
  partition
  priority
  qos
  sockets_per_node
  state_reason
  tasks
  tres_per_job
  tres_per_node
  tres_per_socket
  tres_per_task
  user_name

# List of slurmdbd job fields selected in slurmrestd API when retrieving a
# unique job, all other fields are filtered out.
#
# Default value:
# - association
# - comment
# - derived_exit_code
# - exit_code
# - group
# - name
# - nodes
# - partition
# - priority
# - qos
# - script
# - state
# - steps
# - submit_line
# - time
# - tres
# - used_gres
# - user
# - wckey
# - working_directory
acctjob=
  association
  comment
  derived_exit_code
  exit_code
  group
  name
  nodes
  partition
  priority
  qos
  script
  state
  steps
  submit_line
  time
  tres
  used_gres
  user
  wckey
  working_directory

# List of slurmctld job fields selected in slurmrestd API when retrieving a
# unique job, all other fields are filtered out.
#
# Default value:
# - accrue_time
# - batch_flag
# - command
# - cpus
# - current_working_directory
# - exclusive
# - gres_detail
# - last_sched_evaluation
# - node_count
# - partition
# - sockets_per_node
# - standard_error
# - standard_input
# - standard_output
# - tasks
# - tres_per_job
# - tres_per_node
# - tres_per_socket
# - tres_per_task
# - tres_req_str
ctldjob=
  accrue_time
  batch_flag
  command
  cpus
  current_working_directory
  exclusive
  gres_detail
  last_sched_evaluation
  node_count
  partition
  sockets_per_node
  standard_error
  standard_input
  standard_output
  tasks
  tres_per_job
  tres_per_node
  tres_per_socket
  tres_per_task
  tres_req_str

# List of nodes fields selected in slurmrestd API, all other fields are
# filtered out.
#
# Default value:
# - name
# - cpus
# - sockets
# - cores
# - gres
# - gres_used
# - real_memory
# - state
# - reason
# - partitions
# - alloc_cpus
# - alloc_idle_cpus
nodes=
  name
  cpus
  sockets
  cores
  gres
  gres_used
  real_memory
  state
  reason
  partitions
  alloc_cpus
  alloc_idle_cpus

# List of invidual node fields selected in slurmrestd API, all other fields
# are filtered out.
#
# Default value:
# - name
# - architecture
# - operating_system
# - boot_time
# - last_busy
# - cpus
# - sockets
# - cores
# - threads
# - real_memory
# - gres
# - gres_used
# - state
# - reason
# - partitions
# - alloc_cpus
# - alloc_idle_cpus
# - alloc_memory
node=
  name
  architecture
  operating_system
  boot_time
  last_busy
  cpus
  sockets
  cores
  threads
  real_memory
  gres
  gres_used
  state
  reason
  partitions
  alloc_cpus
  alloc_idle_cpus
  alloc_memory

# List of partitions fields selected in slurmrestd API, all other fields are
# filtered out.
#
# Default value:
# - name
# - node_sets
partitions=
  name
  node_sets

# List of qos fields selected in slurmrestd API, all other fields are
# filtered out.
#
# Default value:
# - name
# - description
# - priority
# - flags
# - limits
qos=
  name
  description
  priority
  flags
  limits

# List of reservations fields selected in slurmrestd API, all other fields
# are filtered out.
#
# Default value:
# - name
# - users
# - accounts
# - node_list
# - node_count
# - start_time
# - end_time
# - flags
reservations=
  name
  users
  accounts
  node_list
  node_count
  start_time
  end_time
  flags

# List of accounts fields selected in slurmrestd API, all other fields are
# filtered out.
#
# Default value:
# - name
accounts=
  name

[policy]

# Path to RBAC policy definition file with available actions
#
# Default value: /usr/share/slurm-web/conf/policy.yml
definition=/usr/share/slurm-web/conf/policy.yml

# Path to default vendor RBAC policy definition file with roles and
# permitted actions
#
# Default value: /usr/share/slurm-web/conf/policy.ini
vendor_roles=/usr/share/slurm-web/conf/policy.ini

# Path to site RBAC policy definition file with roles and permitted actions
#
# Default value: /etc/slurm-web/policy.ini
roles=/etc/slurm-web/policy.ini

[jwt]

# Path to private key for Slurm-web internal JWT signature.
#
# Default value: /var/lib/slurm-web/jwt.key
key=/var/lib/slurm-web/jwt.key

# Cryptographic algorithm used to sign JWT
#
# Possible values:
# - HS256
# - HS384
# - HS512
# - ES256
# - ES256K
# - ES384
# - ES512
# - RS256
# - RS384
# - RS512
# - PS256
# - PS384
# - PS512
# - EdDSA
#
# Default value: HS256
algorithm=HS256

# Audience defined in generated JWT and expected in JWT provided by clients
#
# Default value: slurm-web
audience=slurm-web

[racksdb]

# Control if RacksDB integration feature for advanced visualization of
# resources is enabled.
#
# Default value: yes
enabled=no

# Path to RacksDB database
#
# Default value: /var/lib/racksdb
db=/var/lib/racksdb

# Path to RacksDB database schema
#
# Default value: /usr/share/racksdb/schemas/racksdb.yml
schema=/usr/share/racksdb/schemas/racksdb.yml

# Path to site-specific RacksDB schema extensions
#
# Default value: /etc/racksdb/extensions.yml
extensions=/etc/racksdb/extensions.yml

# Path to RacksDB database schema
#
# Default value: /usr/share/racksdb/schemas/drawings.yml
drawings_schema=/usr/share/racksdb/schemas/drawings.yml

# Name of the infrastructure for the cluster in RacksDB. By default, the
# cluster name is used.
#infrastructure=atlas
infrastructure=mercury #racksdb

# List of tags applied to compute nodes in RacksDB database
#
# Default value:
# - compute
tags=
  compute

[cache]

# Determine if caching is enabled
enabled=yes

# Hostname of Redis cache server
#
# Default value: localhost
host=<REDIS IP>

# TCP port of Redis cache server
#
# Default value: 6379
port=6379

# Password to connect to protected Redis server. When this parameter is
# not defined, Redis server is accessed without password.
password=<REDIS PASSWD>

# Expiration delay in seconds for Slurm version in cache
#
# Default value: 1800
version=1800

# Expiration delay in seconds for jobs in cache
#
# Default value: 30
jobs=30

# Expiration delay in seconds for invidual jobs in cache
#
# Default value: 10
job=10

# Expiration delay in seconds for nodes in cache
#
# Default value: 30
nodes=30

# Expiration delay in seconds for node in cache
#
# Default value: 10
node=10

# Expiration delay in seconds for partitions in cache
#
# Default value: 60
partitions=60

# Expiration delay in seconds for QOS in cache
#
# Default value: 60
qos=60

# Expiration delay in seconds for reservations in cache
#
# Default value: 60
reservations=60

# Expiration delay in seconds for accounts in cache
#
# Default value: 60
accounts=60

[metrics]

# Determine if metrics feature and integration with Prometheus (or
# compatible) is enabled.
enabled=no

# Restricted list of IP networks permitted to request metrics.
#
# Default value:
# - 127.0.0.0/24
# - ::1/128
restrict=
  127.0.0.0/24
  ::1/128

# URL of Prometheus server (or compatible) to requests metrics with PromQL.
#
# Default value: http://localhost:9090
host=http://localhost:9090

# Name of Prometheus job which scrapes Slurm-web metrics.
#
# Default value: slurm
job=slurm
EOF
```
### 配置slurm-web-gateway
```shell
cat > /etc/slurm-web/gateway.ini << EOF
# This file is an example configuration file for Slurm-web gateway
#
# Please DO NOT USE THIS FILE as a basis for your custom
# /etc/slurm-web/gateway.ini.

[service]

# Address of network interfaces to bind native service for incoming
# connections. Special value `0.0.0.0` means all network interfaces.
#
# Default value: localhost
interface=10.84.3.164

# TCP port to listen for incoming connections.
#
# Default value: 5011
port=5011

# When true, Cross-Origin Resource Sharing (CORS) headers are enabled.
cors=no

# Enable debug mode
debug=no

# List of log flags to enable. Special value `ALL` enables all log flags.
#
# Possible values:
# - slurmweb
# - rfl
# - werkzeug
# - urllib3
# - racksdb
# - ALL
#
# Default value:
# - ALL
log_flags=
  ALL

# List of debug flags to enable. Special value `ALL` enables all debug
# flags.
#
# Possible values:
# - slurmweb
# - rfl
# - werkzeug
# - urllib3
# - racksdb
# - ALL
#
# Default value:
# - slurmweb
debug_flags=
  slurmweb

[ui]

# Public URL to access the gateway component
host=http://10.84.3.164:5011

# Serve frontend application with gateway
#
# Default value: yes
enabled=yes

# Path to Slurm-web frontend application
#
# Default value: /usr/share/slurm-web/frontend
path=/usr/share/slurm-web/frontend

# Path HTML templates folder.
#
# Default value: /usr/share/slurm-web/templates
templates=/usr/share/slurm-web/templates

# Path to service message HTML template relative to the templates folder.
#
# Default value: message.html.j2
message_template=message.html.j2

# Path to service message presented to users below the login form. Slurm-web
# loads the file if it exists. However, it does not fail if file is not
# found, it is skipped silently. The content must be formatted in markdown.
#
# Default value: /etc/slurm-web/messages/login.md
message_login=/etc/slurm-web/messages/login.md

# Control if users can see the list of denied clusters, ie. clusters on
# which they do not have any permission. When false, these clusters are
# visible and marked as denied for these users. When true, these clusters
# are hidden to these users.
hide_denied=no

# Enable racks rows labels in RacksDB infrastructure graphical
# representations.
racksdb_rows_labels=no

# Enable racks labels in RacksDB infrastructure graphical representations.
racksdb_racks_labels=no

[agents]

# List of Slurm-web agents URL
#
# This parameter is required.
url=
  http://10.84.3.164:5012

# Minimal support version of Slurm-web agent API
#
# CAUTION: You SHOULD NOT change this parameter unless you really know what
# you are doing. This parameter is more intented for Slurm-web developers
# rather than end users. Slurm-web is officially tested and validated with
# the default value only.
#
# Default value: 5.1.0
version=5.1.0

# Minimal supported version of RacksDB API
#
# CAUTION: You SHOULD NOT change this parameter unless you really know what
# you are doing. This parameter is more intented for Slurm-web developers
# rather than end users. Slurm-web is officially tested and validated with
# the default value only.
#
# Default value: 0.5.0
racksdb_version=0.5.0

[authentication]

# Determine if authentication is enabled
enabled=no

# Authentification method
#
# Possible values:
# - ldap
#
# Default value: ldap
method=ldap

[ldap]

# URI to connect to LDAP server
uri=ldap://localhost

# Path to CA certificate used to validate signature of LDAP server
# certificate when using ldaps or STARTTLS protocols. When not defined, the
# default system CA certificates is used.
cacert=/path/to/certificate.pem

# Use STARTTLS protocol to negociate TLS connection with LDAP server
starttls=no

# Base DN for users entries
user_base=ou=people,dc=example,dc=org

# Base DN for group entries
group_base=ou=group,dc=example,dc=org

# Class of user entries
#
# Default value: posixAccount
user_class=posixAccount

# User entry attribute for user name
#
# Default value: uid
user_name_attribute=uid

# User entry attribute for full name
#
# Default value: cn
user_fullname_attribute=cn

# User entry attribute for primary group ID
#
# Default value: gidNumber
user_primary_group_attribute=gidNumber

# Group entry attribute for name
#
# Default value: cn
group_name_attribute=cn

# List of LDAP object classes for groups
#
# Default value:
# - posixGroup
# - groupOfNames
group_object_classes=
  posixGroup
  groupOfNames

# Lookup user DN in the scope of user base subtree. If disable, LDAP
# directory is not requested to search for the user in the subtree before
# authentication, and the user DN are considered to be in the form of
# `<user_name_attribute>=$login,<user_base>` (ex:
# `uid=$login,ou=people,dc=example,dc=org`). This notably implies all
# users entries to be at the first level under the user base in the tree.
#
# Default value: yes
lookup_user_dn=yes

# DN used to bind to the LDAP server. When this parameter is not defined,
# access to LDAP directory is performed anonymously.
bind_dn=cn=system,ou=people,dc=example,dc=org

# Password of bind DN. This parameter is required when `bind_dn` is
# defined.
bind_password=SECR3T

# As an alternative to `bind_password` parameter, path to a separate file to
# read bind DN password from. When this parameter is defined, the
# `bind_password` parameter is ignored.
bind_password_file=/etc/slurm-web/ldap_password

# After successful user authentication, when this parameter is set to _yes_,
# Slurm-web retrieves user information and groups from LDAP directory with
# authenticated user permissions. When this parameter is set to _no_
# Slurm-web searches this information with service `bind_dn` and
# `bind_password` when defined or performs the operation anonymously. When
# this parameter is omitted in configuration (default), Slurm-web uses
# service `bind_dn` and `bind_password` when defined or authenticated user
# permissions as a fallback.
lookup_as_user=no

# List of users groups allowed to connect. When this parameter is not
# defined, all users in LDAP directory are authorized to sign in.
restricted_groups=
  admins
  biology

[jwt]

# Path to private key for JWT signature
#
# Default value: /var/lib/slurm-web/jwt.key
key=/var/lib/slurm-web/jwt.key

# JWT validity duration in days
#
# Default value: 1
duration=1

# Cryptographic algorithm used to sign JWT
#
# Possible values:
# - HS256
# - HS384
# - HS512
# - ES256
# - ES256K
# - ES384
# - ES512
# - RS256
# - RS384
# - RS512
# - PS256
# - PS384
# - PS512
# - EdDSA
#
# Default value: HS256
algorithm=HS256

# Audience defined in generated JWT and expected in JWT provided by clients
#
# Default value: slurm-web
audience=slurm-web
EOF
```
### 生成Slurm-web JWT 签名密钥
```shell
/usr/libexec/slurm-web/slurm-web-gen-jwt-key
```
### 复制Slurm JWT 签名密钥
```shell
scp <控制节点IP>:/var/spool/slurm/statesave/jwt_hs256.key /var/lib/slurm-web/slurmrestd.key
chown slurm-web:slurm-web /var/lib/slurm-web/slurmrestd.key
chmod 400 /var/lib/slurm-web/slurmrestd.key
```
### 测试Slurm-web能否连接集群
```shell
root@server5:~# /usr/libexec/slurm-web/slurm-web-connect-check
INFO ⸬ slurmrestd URI: http://server7:6820, authentication: jwt, JWT mode: auto
INFO ⸬ Running slurm-web-connect-check
INFO ⸬ Generating new JWT for authentication to slurmrestd
✅ connection successful (slurm: 25.05.3, cluster: cool)
```
### 启动Slurm-web
```shell
# systemctl enable --now slurm-web-agent.service
# systemctl enable --now slurm-web-gateway.service
```
访问Slurm-web
使用浏览器访问网关http ://<slurm-web-gateway-interface IP>:5011
默认没有密码，打开就能访问
![Slurm-web-dash.png.png](../image/Slurm-web-dash.png)
## 集群增减节点
### 增节点
控制节点配置 (slurm.conf)
举例：现有一套集群三个节点server[2-4]，新增一个server5
新增节点必须出现在控制节点的 slurm.conf 里
server5未加入之前的配置
```shell
.....................................省略...................................
PartitionName=cpu Nodes=server[2-4] Default=no MaxTime=INFINITE State=UP
PartitionName=memory Nodes=server[2-4] Default=yes MaxTime=INFINITE State=UP
PartitionName=gpu Nodes=server[2-3] Default=no MaxTime=INFINITE State=UP
NodeName=server2 CPUs=96 Boards=1 SocketsPerBoard=2 CoresPerSocket=24 ThreadsPerCore=2 RealMemory=515711 Gres=gpu:nvidia_l40s:2
NodeName=server3 CPUs=96 Boards=1 SocketsPerBoard=2 CoresPerSocket=24 ThreadsPerCore=2 RealMemory=515711 Gres=gpu:nvidia_l40s:2
NodeName=server4 CPUs=8 Boards=1 SocketsPerBoard=8 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=15988
```
server5加入之后的配置
```shell
.....................................省略...................................
PartitionName=cpu Nodes=server[2-5] Default=no MaxTime=INFINITE State=UP
PartitionName=memory Nodes=server[2-5] Default=yes MaxTime=INFINITE State=UP
PartitionName=gpu Nodes=server[2-3] Default=no MaxTime=INFINITE State=UP
NodeName=server2 CPUs=96 Boards=1 SocketsPerBoard=2 CoresPerSocket=24 ThreadsPerCore=2 RealMemory=515711 Gres=gpu:nvidia_l40s:2
NodeName=server3 CPUs=96 Boards=1 SocketsPerBoard=2 CoresPerSocket=24 ThreadsPerCore=2 RealMemory=515711 Gres=gpu:nvidia_l40s:2
NodeName=server4 CPUs=8 Boards=1 SocketsPerBoard=8 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=15988
NodeName=server5 CPUs=8 Boards=1 SocketsPerBoard=8 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=15988
```
#### 修改新节点slurmd的service文件
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
新增--conf-server server2:6817 让计算节点知道去哪里去获取配置信息
#### 重新加载配置 使注册生效
```shell
scontrol reconfigure
```
#### 验证是否生效
```shell
root@server2:~# scontrol show nodes
NodeName=server2 Arch=x86_64 CoresPerSocket=24 
   CPUAlloc=0 CPUEfctv=96 CPUTot=96 CPULoad=0.00
   AvailableFeatures=(null)
   ActiveFeatures=(null)
   Gres=gpu:nvidia_l40s:2
   NodeAddr=server2 NodeHostName=server2 Version=25.05.3
   OS=Linux 5.15.0-153-generic #163-Ubuntu SMP Thu Aug 7 16:37:18 UTC 2025 
   RealMemory=515711 AllocMem=0 FreeMem=490309 Sockets=2 Boards=1
   State=IDLE ThreadsPerCore=2 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=cpu,memory,gpu 
   BootTime=2025-09-16T10:50:27 SlurmdStartTime=2025-09-23T10:08:51
   LastBusyTime=2025-09-23T10:08:51 ResumeAfterTime=None
   CfgTRES=cpu=96,mem=515711M,billing=96
   AllocTRES=
   CurrentWatts=0 AveWatts=0

NodeName=server3 Arch=x86_64 CoresPerSocket=24 
   CPUAlloc=0 CPUEfctv=96 CPUTot=96 CPULoad=0.00
   AvailableFeatures=(null)
   ActiveFeatures=(null)
   Gres=gpu:nvidia_l40s:2
   NodeAddr=server3 NodeHostName=server3 Version=25.05.3
   OS=Linux 5.15.0-151-generic #161-Ubuntu SMP Tue Jul 22 14:25:40 UTC 2025 
   RealMemory=515711 AllocMem=0 FreeMem=508844 Sockets=2 Boards=1
   State=IDLE ThreadsPerCore=2 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=cpu,memory,gpu 
   BootTime=2025-09-08T07:51:38 SlurmdStartTime=2025-09-23T10:08:51
   LastBusyTime=2025-09-23T10:08:51 ResumeAfterTime=None
   CfgTRES=cpu=96,mem=515711M,billing=96
   AllocTRES=
   CurrentWatts=0 AveWatts=0

NodeName=server4 Arch=x86_64 CoresPerSocket=1 
   CPUAlloc=0 CPUEfctv=8 CPUTot=8 CPULoad=0.00
   AvailableFeatures=(null)
   ActiveFeatures=(null)
   Gres=(null)
   NodeAddr=server4 NodeHostName=server4 Version=25.05.3
   OS=Linux 5.15.0-153-generic #163-Ubuntu SMP Thu Aug 7 16:37:18 UTC 2025 
   RealMemory=15988 AllocMem=0 FreeMem=14079 Sockets=8 Boards=1
   State=IDLE ThreadsPerCore=1 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=cpu,memory 
   BootTime=2025-09-17T11:19:04 SlurmdStartTime=2025-09-23T10:08:51
   LastBusyTime=2025-09-23T10:08:51 ResumeAfterTime=None
   CfgTRES=cpu=8,mem=15988M,billing=8
   AllocTRES=
   CurrentWatts=0 AveWatts=0

NodeName=server5 Arch=x86_64 CoresPerSocket=1 
   CPUAlloc=0 CPUEfctv=8 CPUTot=8 CPULoad=0.00
   AvailableFeatures=(null)
   ActiveFeatures=(null)
   Gres=(null)
   NodeAddr=server5 NodeHostName=server5 Version=25.05.3
   OS=Linux 5.15.0-153-generic #163-Ubuntu SMP Thu Aug 7 16:37:18 UTC 2025 
   RealMemory=15988 AllocMem=0 FreeMem=14054 Sockets=8 Boards=1
   State=IDLE ThreadsPerCore=1 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=cpu,memory 
   BootTime=2025-09-17T11:19:08 SlurmdStartTime=2025-09-23T10:08:51
   LastBusyTime=2025-09-23T10:08:51 ResumeAfterTime=None
   CfgTRES=cpu=8,mem=15988M,billing=8
   AllocTRES=
   CurrentWatts=0 AveWatts=0
```
### 减节点(减server5)
#### 设置节点不可调度
```shell
scontrol update NodeName=server5 State=DRAIN Reason="维护中"
```
#### 验证是否生效
```shell
root@server2:~# scontrol show nodes
NodeName=server2 Arch=x86_64 CoresPerSocket=24 
   CPUAlloc=0 CPUEfctv=96 CPUTot=96 CPULoad=0.00
   AvailableFeatures=(null)
   ActiveFeatures=(null)
   Gres=gpu:nvidia_l40s:2
   NodeAddr=server2 NodeHostName=server2 Version=25.05.3
   OS=Linux 5.15.0-153-generic #163-Ubuntu SMP Thu Aug 7 16:37:18 UTC 2025 
   RealMemory=515711 AllocMem=0 FreeMem=490327 Sockets=2 Boards=1
   State=IDLE ThreadsPerCore=2 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=cpu,memory,gpu 
   BootTime=2025-09-16T10:50:28 SlurmdStartTime=2025-09-19T15:58:06
   LastBusyTime=2025-09-23T08:48:32 ResumeAfterTime=None
   CfgTRES=cpu=96,mem=515711M,billing=96
   AllocTRES=
   CurrentWatts=0 AveWatts=0

NodeName=server3 Arch=x86_64 CoresPerSocket=24 
   CPUAlloc=0 CPUEfctv=96 CPUTot=96 CPULoad=0.01
   AvailableFeatures=(null)
   ActiveFeatures=(null)
   Gres=gpu:nvidia_l40s:2
   NodeAddr=server3 NodeHostName=server3 Version=25.05.3
   OS=Linux 5.15.0-151-generic #161-Ubuntu SMP Tue Jul 22 14:25:40 UTC 2025 
   RealMemory=515711 AllocMem=0 FreeMem=508848 Sockets=2 Boards=1
   State=IDLE ThreadsPerCore=2 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=cpu,memory,gpu 
   BootTime=2025-09-08T07:51:39 SlurmdStartTime=2025-09-19T15:58:06
   LastBusyTime=2025-09-23T08:48:32 ResumeAfterTime=None
   CfgTRES=cpu=96,mem=515711M,billing=96
   AllocTRES=
   CurrentWatts=0 AveWatts=0

NodeName=server4 Arch=x86_64 CoresPerSocket=1 
   CPUAlloc=0 CPUEfctv=8 CPUTot=8 CPULoad=0.00
   AvailableFeatures=(null)
   ActiveFeatures=(null)
   Gres=(null)
   NodeAddr=server4 NodeHostName=server4 Version=25.05.3
   OS=Linux 5.15.0-153-generic #163-Ubuntu SMP Thu Aug 7 16:37:18 UTC 2025 
   RealMemory=15988 AllocMem=0 FreeMem=14076 Sockets=8 Boards=1
   State=IDLE ThreadsPerCore=1 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=cpu,memory 
   BootTime=2025-09-17T11:19:05 SlurmdStartTime=2025-09-19T15:58:06
   LastBusyTime=2025-09-23T08:48:32 ResumeAfterTime=None
   CfgTRES=cpu=8,mem=15988M,billing=8
   AllocTRES=
   CurrentWatts=0 AveWatts=0

NodeName=server5 Arch=x86_64 CoresPerSocket=1 
   CPUAlloc=0 CPUEfctv=8 CPUTot=8 CPULoad=0.00
   AvailableFeatures=(null)
   ActiveFeatures=(null)
   Gres=(null)
   NodeAddr=server5 NodeHostName=server5 Version=25.05.3
   OS=Linux 5.15.0-153-generic #163-Ubuntu SMP Thu Aug 7 16:37:18 UTC 2025 
   RealMemory=15988 AllocMem=0 FreeMem=14055 Sockets=8 Boards=1
   State=IDLE+DRAIN ThreadsPerCore=1 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=cpu,memory 
   BootTime=2025-09-17T11:19:09 SlurmdStartTime=2025-09-19T15:58:06
   LastBusyTime=2025-09-23T08:48:32 ResumeAfterTime=None
   CfgTRES=cpu=8,mem=15988M,billing=8
   AllocTRES=
   CurrentWatts=0 AveWatts=0
   Reason=维护中 [root@2025-09-23T09:46:15]
root@server2:~# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
cpu          up   infinite      1  drain server5
cpu          up   infinite      3   idle server[2-4]
memory*      up   infinite      1  drain server5
memory*      up   infinite      3   idle server[2-4]
gpu          up   infinite      2   idle server[2-3]
```
> 恢复节点可调度时可使用   scontrol update NodeName=server5 State=RESUME
#### 编辑控制节点的 /etc/slurm/slurm.conf，删除或注释掉该节点。
```shell
.....................................省略...................................
PartitionName=cpu Nodes=server[2-4] Default=no MaxTime=INFINITE State=UP #默认是Nodes=server[2-5]
PartitionName=memory Nodes=server[2-4] Default=yes MaxTime=INFINITE State=UP #默认是Nodes=server[2-5]
PartitionName=gpu Nodes=server[2-3] Default=no MaxTime=INFINITE State=UP
NodeName=server2 CPUs=96 Boards=1 SocketsPerBoard=2 CoresPerSocket=24 ThreadsPerCore=2 RealMemory=515711 Gres=gpu:nvidia_l40s:2
NodeName=server3 CPUs=96 Boards=1 SocketsPerBoard=2 CoresPerSocket=24 ThreadsPerCore=2 RealMemory=515711 Gres=gpu:nvidia_l40s:2
NodeName=server4 CPUs=8 Boards=1 SocketsPerBoard=8 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=15988
#NodeName=server5 CPUs=8 Boards=1 SocketsPerBoard=8 CoresPerSocket=1 ThreadsPerCore=1 RealMemory=15988
```
#### 重新加载配置 使改动生效
```shell
scontrol reconfigure
```
#### 验证节点是否已删除
```shell
root@server2:~# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
cpu          up   infinite      3   idle server[2-4]
memory*      up   infinite      3   idle server[2-4]
gpu          up   infinite      2   idle server[2-3]
root@server2:~# scontrol show nodes
NodeName=server2 Arch=x86_64 CoresPerSocket=24 
   CPUAlloc=0 CPUEfctv=96 CPUTot=96 CPULoad=0.00
   AvailableFeatures=(null)
   ActiveFeatures=(null)
   Gres=gpu:nvidia_l40s:2
   NodeAddr=server2 NodeHostName=server2 Version=25.05.3
   OS=Linux 5.15.0-153-generic #163-Ubuntu SMP Thu Aug 7 16:37:18 UTC 2025 
   RealMemory=515711 AllocMem=0 FreeMem=490321 Sockets=2 Boards=1
   State=IDLE ThreadsPerCore=2 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=cpu,memory,gpu 
   BootTime=2025-09-16T10:50:27 SlurmdStartTime=2025-09-23T09:51:02
   LastBusyTime=2025-09-23T09:51:02 ResumeAfterTime=None
   CfgTRES=cpu=96,mem=515711M,billing=96
   AllocTRES=
   CurrentWatts=0 AveWatts=0

NodeName=server3 Arch=x86_64 CoresPerSocket=24 
   CPUAlloc=0 CPUEfctv=96 CPUTot=96 CPULoad=0.00
   AvailableFeatures=(null)
   ActiveFeatures=(null)
   Gres=gpu:nvidia_l40s:2
   NodeAddr=server3 NodeHostName=server3 Version=25.05.3
   OS=Linux 5.15.0-151-generic #161-Ubuntu SMP Tue Jul 22 14:25:40 UTC 2025 
   RealMemory=515711 AllocMem=0 FreeMem=508847 Sockets=2 Boards=1
   State=IDLE ThreadsPerCore=2 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=cpu,memory,gpu 
   BootTime=2025-09-08T07:51:38 SlurmdStartTime=2025-09-23T09:51:02
   LastBusyTime=2025-09-23T09:51:02 ResumeAfterTime=None
   CfgTRES=cpu=96,mem=515711M,billing=96
   AllocTRES=
   CurrentWatts=0 AveWatts=0

NodeName=server4 Arch=x86_64 CoresPerSocket=1 
   CPUAlloc=0 CPUEfctv=8 CPUTot=8 CPULoad=0.00
   AvailableFeatures=(null)
   ActiveFeatures=(null)
   Gres=(null)
   NodeAddr=server4 NodeHostName=server4 Version=25.05.3
   OS=Linux 5.15.0-153-generic #163-Ubuntu SMP Thu Aug 7 16:37:18 UTC 2025 
   RealMemory=15988 AllocMem=0 FreeMem=14080 Sockets=8 Boards=1
   State=IDLE ThreadsPerCore=1 TmpDisk=0 Weight=1 Owner=N/A MCS_label=N/A
   Partitions=cpu,memory 
   BootTime=2025-09-17T11:19:05 SlurmdStartTime=2025-09-23T09:51:02
   LastBusyTime=2025-09-23T09:51:02 ResumeAfterTime=None
   CfgTRES=cpu=8,mem=15988M,billing=8
   AllocTRES=
   CurrentWatts=0 AveWatts=0
```