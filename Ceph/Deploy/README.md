# 环境准备
## 三台机器 系统环境
```
Ubuntu 20.04.3 LTS
```
## 三台机器 安装基础环境
```shell
apt install docker.io -y
systemctl start docker && systemctl enable docker
```
## 三台机器 Python版本
```shell
Python 3.8.6
```
## 三台机器  主机名
```shell
10.2.0.25 ceph-1
10.2.0.26 ceph-2
10.2.0.27 ceph-3
```
## 三台机器双网卡
```shell
10.2.0.25 192.168.1.1  ceph-1
10.2.0.26 192.168.1.2  ceph-2
10.2.0.27 192.168.1.3  ceph-3
```
## 三台机器及各组件位置
```shell
10.2.0.25 ceph-1  ceph-mon01   ceph-mgr01  cephadm
10.2.0.26 ceph-2  ceph-mon02   ceph-mgr02
10.2.0.27 ceph-3  ceph-mon03   ceph-mgr03
```
## 三台机器 /etc/hosts
```shell
root@ceph-1:~# cat /etc/hosts
10.2.0.25 ceph-1
10.2.0.26 ceph-2
10.2.0.27 ceph-3
```
## 三台机器时间同步
```shell
timedatectl set-timezone Asia/Shanghai && apt install ntpdate -y && ntpdate ntp1.aliyun.com
```
# 部署Ceph Cluster
## 下载cephadm
```shell
CEPH_RELEASE=18.2.2 # replace this with the active release
curl --silent --remote-name --location https://download.ceph.com/rpm-${CEPH_RELEASE}/el9/noarch/cephadm
chmod a+x cephadm && mv cephadm /usr/bin/
```
## 引导 Ceph 集群
```shell
cephadm  bootstrap --mon-ip 10.2.0.25 --cluster-network 192.168.1.0/24
```
## 部署完成后的集群相关信息
```shell
Ceph Dashboard is now available at:

			URL: https://ceph-1:8443/ #Ceph 管理UI登录地址
			User: admin	#Ceph 管理UI登录地址用户名
		Password: njc4a24jel	#Ceph 管理UI登录地址密码

	Enabling client.admin keyring and conf on hosts with "admin" label
	Saving cluster configuration to /var/lib/ceph/e48ba8d6-e341-11ee-8b2b-2799cf0b1efd/config directory
	Enabling autotune for osd_memory_target
	You can access the Ceph CLI as following in case of multi-cluster or non-default config:

		sudo /usr/bin/cephadm shell --fsid e48ba8d6-e341-11ee-8b2b-2799cf0b1efd -c /etc/ceph/ceph.conf -k /etc/ceph/ceph.client.admin.keyring

	Or, if you are only running a single cluster on this host:

		sudo /usr/bin/cephadm shell 

	Please consider enabling telemetry to help improve Ceph:

		ceph telemetry on

	For more information see:

		https://docs.ceph.com/en/latest/mgr/telemetry/

	Bootstrap complete.
```
## 安装 ceph 管理工具包, 其中包括 ceph, rbd, mount.ceph 等命令
```shell
cephadm install ceph-common
```
## 查看集群状态
```shell
root@ceph-1:/# ceph -s
cluster:
id:     e48ba8d6-e341-11ee-8b2b-2799cf0b1efd
health: HEALTH_WARN
OSD count 0 < osd_pool_default_size 3 #默认osd最小不低于3个

	services:
		mon: 1 daemons, quorum ceph-1 (age 7m) #因为引导的机器只有一个因此此处只显示一个mon和一个mgr
		mgr: ceph-1.qceian(active, since 3m)
		osd: 0 osds: 0 up, 0 in
	
	data:
		pools:   0 pools, 0 pgs
		objects: 0 objects, 0 B
		usage:   0 B used, 0 B / 0 B avail
		pgs: 
```
## 查看 ceph 集群所有组件运行状态
	root@ceph-1:~# ceph orch ps 
	NAME                  HOST    PORTS             STATUS         REFRESHED  AGE  MEM USE  MEM LIM  VERSION  IMAGE ID      CONTAINER ID  
	alertmanager.ceph-1   ceph-1  *:9093,9094       running (12m)    57s ago  15m    14.8M        -  0.25.0   c8568f914cd2  018414dcf1ab  
	ceph-exporter.ceph-1  ceph-1                    running (15m)    57s ago  15m    8544k        -  18.2.2   6dc5f0faebb2  c0ea09d777dd  
	crash.ceph-1          ceph-1                    running (15m)    57s ago  15m    7291k        -  18.2.2   6dc5f0faebb2  89b779ea23e2  
	grafana.ceph-1        ceph-1  *:3000            running (12m)    57s ago  14m    77.8M        -  9.4.7    954c08fa6188  c0ae6724d69d  
	mgr.ceph-1.qceian     ceph-1  *:9283,8765,8443  running (17m)    57s ago  17m     499M        -  18.2.2   6dc5f0faebb2  d7251b71a893  
	mon.ceph-1            ceph-1                    running (17m)    57s ago  17m    35.9M    2048M  18.2.2   6dc5f0faebb2  898749e36b63  
	node-exporter.ceph-1  ceph-1  *:9100            running (15m)    57s ago  15m    12.5M        -  1.5.0    0da6a335fe13  7cf94b074f3e  
	prometheus.ceph-1     ceph-1  *:9095            running (13m)    57s ago  13m    35.3M        -  2.43.0   a07b618ecd1d  461c066a4f82
## Grafana 初始化：
### 设置 Grafana 初始管理员密码：
默认情况下， Grafana 不会创建初始管理员用户。 为了创建管理员用户， 可以创建一个包含以下内容的 grafana.yaml 文件：
```shell
cat > grafana_passwd.yaml << EOF
service_type: grafana
spec:
  initial_admin_password: Seca@2024...
EOF
```
### 应用规范
```shell
ceph orch apply -i grafana_passwd.yaml
```
### 查看组件名称
```shell
root@ceph-1:~# ceph orch ls
NAME                       PORTS        RUNNING  REFRESHED  AGE  PLACEMENT                     
alertmanager               ?:9093,9094      1/1  5m ago     4h   count:1                       
ceph-exporter                               3/3  6m ago     16m  *                             
crash                                       3/3  6m ago     4h   *                             
grafana                    ?:3000           1/1  5m ago     88s  count:1                       
mgr                                         2/2  6m ago     67m  ceph-2;ceph-3;count:2         
mon                                         3/3  6m ago     70m  ceph-1;ceph-2;ceph-3;count:3  
node-exporter              ?:9100           3/3  6m ago     4h   *                             
osd                                           3  6m ago     -    <unmanaged>                   
osd.all-available-devices                     3  6m ago     87m  *                             
prometheus                 ?:9095           1/1  5m ago     4h   count:
```

### 重新部署grafana，使配置生效
```shell
ceph orch redeploy grafana
```
## 删除ceph组件的方法
```shell
root@ceph-1:~#ceph orch rm grafana #grafana 是执行ceph orch ls后获取的组件名称
```
## 验证是否删除成功
```shell
root@ceph-1:~# ceph orch ps
NAME                  HOST    PORTS             STATUS         REFRESHED  AGE  MEM USE  MEM LIM  VERSION  IMAGE ID      CONTAINER ID  
alertmanager.ceph-1   ceph-1  *:9093,9094       running (12m)    57s ago  15m    14.8M        -  0.25.0   c8568f914cd2  018414dcf1ab  
ceph-exporter.ceph-1  ceph-1                    running (15m)    57s ago  15m    8544k        -  18.2.2   6dc5f0faebb2  c0ea09d777dd  
crash.ceph-1          ceph-1                    running (15m)    57s ago  15m    7291k        -  18.2.2   6dc5f0faebb2  89b779ea23e2   
mgr.ceph-1.qceian     ceph-1  *:9283,8765,8443  running (17m)    57s ago  17m     499M        -  18.2.2   6dc5f0faebb2  d7251b71a893  
mon.ceph-1            ceph-1                    running (17m)    57s ago  17m    35.9M    2048M  18.2.2   6dc5f0faebb2  898749e36b63  
node-exporter.ceph-1  ceph-1  *:9100            running (15m)    57s ago  15m    12.5M        -  1.5.0    0da6a335fe13  7cf94b074f3e  
prometheus.ceph-1     ceph-1  *:9095            running (13m)    57s ago  13m    35.3M        -  2.43.0   a07b618ecd1d  461c066a4f82
```
## 查看指定组件运行状态
```shell
root@ceph-1:~# ceph orch ps --daemon-type mon
NAME        HOST    PORTS  STATUS         REFRESHED  AGE  MEM USE  MEM LIM  VERSION  IMAGE ID      CONTAINER ID  
mon.ceph-1  ceph-1         running (17m)    87s ago  17m    35.9M    2048M  18.2.2   6dc5f0faebb2  898749e36b63 
```
## 将公钥拷贝至另外两台机器
```shell
ssh-copy-id -f -i /etc/ceph/ceph.pub root@ceph-2
ssh-copy-id -f -i /etc/ceph/ceph.pub root@ceph-3
```
## 将主机添加到集群中, 注意：目标主机必须安装了 python3 和 docker
```shell
root@ceph-1:~# ceph orch host add ceph-2
Added host 'ceph-2' with addr '10.2.0.26'

root@ceph-1:~# ceph orch host add ceph-3
Added host 'ceph-3' with addr '10.2.0.27'
```
## 验证节点状态
```shell
root@ceph-1:~# ceph orch host ls
HOST    ADDR       LABELS  STATUS  
ceph-1  10.2.0.25  _admin          
ceph-2  10.2.0.26                  
ceph-3  10.2.0.27                  
3 hosts in cluster
```
## 查看集群是否已经扩展完成(3个crash，3个mon，2个mgr)
```shell
root@ceph-1:~# ceph orch ps 
NAME                  HOST    PORTS             STATUS          REFRESHED  AGE  MEM USE  MEM LIM  VERSION    IMAGE ID      CONTAINER ID  
alertmanager.ceph-1   ceph-1  *:9093,9094       running (117s)    34s ago  24m    15.7M        -  0.25.0     c8568f914cd2  8902ecedc41a  
ceph-exporter.ceph-1  ceph-1                    running (24m)     34s ago  24m    8584k        -  18.2.2     6dc5f0faebb2  c0ea09d777dd  
ceph-exporter.ceph-2  ceph-2                    running (3m)      35s ago   3m    15.8M        -  18.2.2     6dc5f0faebb2  3faa6de9a163  
ceph-exporter.ceph-3  ceph-3                    running (2m)      36s ago   2m    7856k        -  18.2.2     6dc5f0faebb2  fe25fed0c188  
crash.ceph-1          ceph-1                    running (24m)     34s ago  24m    7012k        -  18.2.2     6dc5f0faebb2  89b779ea23e2  
crash.ceph-2          ceph-2                    running (3m)      35s ago   3m    8288k        -  18.2.2     6dc5f0faebb2  af2b2fbe2d02  
crash.ceph-3          ceph-3                    running (2m)      36s ago   2m    8955k        -  18.2.2     6dc5f0faebb2  5735a1545c33  
grafana.ceph-1        ceph-1  *:3000            running (21m)     34s ago  23m    79.1M        -  9.4.7      954c08fa6188  c0ae6724d69d  
mgr.ceph-1.qceian     ceph-1  *:9283,8765,8443  running (26m)     34s ago  26m     503M        -  18.2.2     6dc5f0faebb2  d7251b71a893  
mgr.ceph-2.cuszrq     ceph-2  *:8443,9283,8765  running (3m)      35s ago   3m     427M        -  18.2.2     6dc5f0faebb2  01cf8d55b7cc  
mon.ceph-1            ceph-1                    running (26m)     34s ago  26m    44.6M    2048M  18.2.2     6dc5f0faebb2  898749e36b63  
mon.ceph-2            ceph-2                    running (3m)      35s ago   3m    34.1M    2048M  18.2.2     6dc5f0faebb2  264c1677c6e0  
mon.ceph-3            ceph-3                    running (2m)      36s ago   2m    27.9M    2048M  18.2.2     6dc5f0faebb2  069a4e9e0f4b  
node-exporter.ceph-1  ceph-1  *:9100            running (24m)     34s ago  24m    13.2M        -  1.5.0      0da6a335fe13  7cf94b074f3e  
node-exporter.ceph-2  ceph-2  *:9100            running (3m)      35s ago   3m    8231k        -  1.5.0      0da6a335fe13  2fd606c8247e  
node-exporter.ceph-3  ceph-3  *:9100            running           36s ago   2m        -        -  <unknown>  <unknown>     <unknown>     
prometheus.ceph-1     ceph-1  *:9095            running (113s)    34s ago  21m    35.3M        -  2.43.0     a07b618ecd1d  978ea0af16d2
```
## 查看各节点可用磁盘
```shell
root@ceph-1:~# cephadm shell ceph orch device ls
Inferring fsid e48ba8d6-e341-11ee-8b2b-2799cf0b1efd
Inferring config /var/lib/ceph/e48ba8d6-e341-11ee-8b2b-2799cf0b1efd/mon.ceph-1/config
Using ceph image with id '6dc5f0faebb2' and tag 'v18' created on 2024-03-11 22:56:38 +0800 CST
quay.io/ceph/ceph@sha256:9d7bcfea8d18999ed9e00e9c9d124f9ff14a1602e92486da20752c2a40a6c07f
HOST    PATH      TYPE  DEVICE ID   SIZE  AVAILABLE  REFRESHED  REJECT REASONS  
ceph-1  /dev/sdb  ssd               100G  Yes        21m ago                    
ceph-2  /dev/sdb  ssd               100G  Yes        14m ago                    
ceph-3  /dev/sdb  ssd               100G  Yes        13m ago
```
注意：如果发现有osd的AVAILABLE是为No的状态，此时需要把该磁盘的文件系统清除掉，SDD硬盘执行后就能看到成效，HDD执行后需要等待一段时间，清理指令：```wipefs -a -f /dev/sdb```
## 部署osd
```shell
root@ceph-1:~# ceph orch daemon add osd ceph-1:/dev/sdb
Created osd(s) 0 on host 'ceph-1'
root@ceph-1:~# ceph orch daemon add osd ceph-2:/dev/sdb
Created osd(s) 1 on host 'ceph-2'
root@ceph-1:~# ceph orch daemon add osd ceph-3:/dev/sdb
Created osd(s) 2 on host 'ceph-3'
```
## 验证OSD是否部署完成
```shell
root@ceph-1:~# ceph orch device ls
HOST    PATH      TYPE  DEVICE ID   SIZE  AVAILABLE  REFRESHED  REJECT REASONS                                                           
ceph-1  /dev/sdb  ssd               100G  No         10s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
ceph-2  /dev/sdb  ssd               100G  No         11s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected  
ceph-3  /dev/sdb  ssd               100G  No         10s ago    Has a FileSystem, Insufficient space (<10 extents) on vgs, LVM detected
```
## 验证集群状态：
```shell
cluster:
id:     e48ba8d6-e341-11ee-8b2b-2799cf0b1efd
health: HEALTH_OK

	services:
		mon: 3 daemons, quorum ceph-1,ceph-2,ceph-3 (age 35m)
		mgr: ceph-1.qceian(active, since 54m), standbys: ceph-2.cuszrq
		osd: 3 osds: 3 up (since 2m), 3 in (since 2m)
	
	data:
		pools:   1 pools, 1 pgs
		objects: 2 objects, 449 KiB
		usage:   90 MiB used, 300 GiB / 300 GiB avail
		pgs:     1 active+clean
```
# RBD(块存储)使用详解：
## 1、创建存储池
```shell
root@ceph-1:~# ceph osd pool create rbd-data1 32 32
pool 'rbd-data1' created
```
## 2、验证存储池
```shell
root@ceph-1:~# ceph osd pool ls
.mgr
cephfs_data
cephfs_metadata
rbd-data1
```
## 3、在存储池启用 rbd
```shell
root@ceph-1:~# ceph osd pool application enable rbd-data1 rbd
enabled application 'rbd' on pool 'rbd-data1'
```

## 4、初始化 rbd
```shell
root@ceph-1:~# rbd pool init -p rbd-data1
```

## 5、创建两个 img 镜像
```shell
root@ceph-1:~# rbd create data-img1 --size 3G --pool rbd-data1 --image-format 2 --image-feature layering
root@ceph-1:~# rbd create data-img2 --size 3G --pool rbd-data1 --image-format 2 --image-feature layering
```

## 6、验证镜像
```shell
root@ceph-1:~# rbd ls --pool rbd-data1
data-img1
data-img2
```

## 7、列出对象的多个信息
```shell
root@ceph-1:~# rbd ls --pool rbd-data1 -l
NAME       SIZE   PARENT  FMT  PROT  LOCK
data-img1  3 GiB            2            
data-img2  3 GiB            2
```
## 8、查看镜像详细信息
```shell
root@ceph-1:~# rbd --image data-img2 --pool rbd-data1 info
rbd image 'data-img2':
	size 3 GiB in 768 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 38fafca0521d
	block_name_prefix: rbd_data.38fafca0521d
	format: 2
	features: layering
	op_features:
	flags:
	create_timestamp: Sat Mar 16 12:49:23 2024
	access_timestamp: Sat Mar 16 12:49:23 2024
	modify_timestamp: Sat Mar 16 12:49:23 2024

root@ceph-1:~# rbd --image data-img1 --pool rbd-data1 info
rbd image 'data-img1':
	size 3 GiB in 768 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 38f47f072bb7
	block_name_prefix: rbd_data.38f47f072bb7
	format: 2
	features: layering
	op_features: 
	flags: 
	create_timestamp: Sat Mar 16 12:49:16 2024
	access_timestamp: Sat Mar 16 12:49:16 2024
	modify_timestamp: Sat Mar 16 12:49:16 2024
```
## 9、以 json 格式显示镜像信息：
root@ceph-1:~# rbd ls --pool rbd-data1 -l --format json --pretty-format
```shell
root@ceph-1:~# rbd ls --pool rbd-data1 -l --format json --pretty-format
[
    {
        "image": "data-img1",
        "id": "38f47f072bb7",
        "size": 3221225472,
        "format": 2
    },
    {
        "image": "data-img2",
        "id": "38fafca0521d",
        "size": 3221225472,
        "format": 2
    }
]
```
## 10、镜像的其他特性：
- layering: 支持镜像分层快照特性， 用于快照及写时复制， 可以对 image 创建快照并保护，然后从快照克隆出新的 image 出来， 父子 image 之间采用 COW 技术， 共享对象数据。
- striping: 支持条带化 v2， 类似 raid 0， 只不过在 ceph 环境中的数据被分散到不同的对象中，可改善顺序读写场景较多情况下的性能。
- exclusive-lock: 支持独占锁， 限制一个镜像只能被一个客户端使用。
- object-map: 支持对象映射(依赖 exclusive-lock),加速数据导入导出及已用空间统计等，此特性开启的时候，会记录 image 所有对象的一个位图， 用以标记对象是否真的存在，在一些场景下可以加速 io。
- fast-diff: 快速计算镜像与快照数据差异对比(依赖 object-map)。
- deep-flatten: 支持快照扁平化操作， 用于快照管理时解决快照依赖关系等。
- journaling: 修改数据是否记录日志， 该特性可以通过记录日志并通过日志恢复数据(依赖独占锁),开启此特性会增加系统磁盘IO使用。

## 11、镜像特性的启用：
```shell
rbd feature enable exclusive-lock --pool rbd-data1 --image data-img1 #启用独占锁
rbd feature enable object-map --pool rbd-data1 --image data-img1     #启用对象映射
rbd feature enable fast-diff --pool rbd-data1 --image data-img1      #启用快速计算镜像与快照数据差异对比
```
## 12、验证镜像特性：
```shell
root@ceph-1:~# rbd --image data-img1 --pool rbd-data1 info
rbd image 'data-img1':
    size 3 GiB in 768 objects
    order 22 (4 MiB objects)
    snapshot_count: 0
    id: 38f47f072bb7
    block_name_prefix: rbd_data.38f47f072bb7
    format: 2
    features: layering, exclusive-lock, object-map, fast-diff   #启用后此处会显示对应的特性名
    op_features: 
    flags: object map invalid, fast diff invalid
    create_timestamp: Sat Mar 16 12:49:16 2024
    access_timestamp: Sat Mar 16 12:49:16 2024
    modify_timestamp: Sat Mar 16 12:49:16 2024
```

## 13、镜像特性的禁用
禁用指定存储池中指定镜像的特性:
```shell
root@ceph-1:~# rbd feature disable fast-diff --pool rbd-data1 --image data-img1
```
## 14、验证镜像特性：
```shell
root@ceph-1:~# rbd --image data-img1 --pool rbd-data1 info
rbd image 'data-img1':
    size 3 GiB in 768 objects
    order 22 (4 MiB objects)
    snapshot_count: 0
    id: 38f47f072bb7
    block_name_prefix: rbd_data.38f47f072bb7
    format: 2
    features: layering, exclusive-lock   #禁用后此处会消除掉对应特性名
    op_features: 
    flags: 
    create_timestamp: Sat Mar 16 12:49:16 2024
    access_timestamp: Sat Mar 16 12:49:16 2024
    modify_timestamp: Sat Mar 16 12:49:16 2024
```

## 15、配置客户端使用 RBD
客户端要想挂载使用 ceph RBD， 需要安装 ceph 客户端组件 ceph-common 
```shell
dpkg -i ceph-common_15.2.17-0ubuntu0.20.04.6_amd64.deb
```
## 16、客户端使用 admin 账户挂载并使用 RBD：
```shell
root@ceph-1:~# scp /etc/ceph/ceph.conf /etc/ceph/ceph.client.admin.keyring root@客户端IP地址:/etc/ceph/
```

## 17、客户端映射镜像
```shell
root@ceph-1:~# rbd -p rbd-data1 map data-img1
/dev/rbd0
root@ceph-1:~# rbd -p rbd-data1 map data-img2
/dev/rbd1
```
## 18、客户端验证镜像：
```shell
root@ceph-1:~# lsblk
NAME                                                                                                  MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
loop0                                                                                                   7:0    0 55.4M  1 loop /snap/core18/2128
loop1                                                                                                   7:1    0 55.7M  1 loop /snap/core18/2812
loop2                                                                                                   7:2    0 39.1M  1 loop /snap/snapd/21184
loop3                                                                                                   7:3    0 70.3M  1 loop /snap/lxd/21029
loop4                                                                                                   7:4    0 63.9M  1 loop /snap/core20/2182
loop5                                                                                                   7:5    0 91.9M  1 loop /snap/lxd/24061
sda                                                                                                     8:0    0   40G  0 disk
├─sda1                                                                                                  8:1    0    1M  0 part
├─sda2                                                                                                  8:2    0    1G  0 part /boot
└─sda3                                                                                                  8:3    0   39G  0 part
└─ubuntu--vg-ubuntu--lv                                                                             253:0    0   20G  0 lvm  /
sdb                                                                                                     8:16   0  100G  0 disk
└─ceph--224ef8c9--81ec--4725--af73--09ee9f0ae118-osd--block--a55889b6--d13d--488e--85c5--20db8de848b6 253:1    0  100G  0 lvm  
sr0                                                                                                    11:0    1  1.2G  0 rom  
rbd0                                                                                                  252:0    0    3G  0 disk
rbd1                                                                                                  252:16   0    3G  0 disk
```

## 19、客户端格式化磁盘并挂载使用：
```shell
root@ceph-1:~# mkfs.xfs /dev/rbd0
meta-data=/dev/rbd0              isize=512    agcount=8, agsize=98304 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1
data     =                       bsize=4096   blocks=786432, imaxpct=25
         =                       sunit=16     swidth=16 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=16 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
root@ceph-1:~# mkfs.xfs /dev/rbd1
meta-data=/dev/rbd1              isize=512    agcount=8, agsize=98304 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=1, sparse=1, rmapbt=0
         =                       reflink=1
data     =                       bsize=4096   blocks=786432, imaxpct=25
         =                       sunit=16     swidth=16 blks
naming   =version 2              bsize=4096   ascii-ci=0, ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=16 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
root@ceph-1:~# mkdir /test1
root@ceph-1:~# mkdir /test0
root@ceph-1:~# mount /dev/rbd1 /test1
root@ceph-1:~# mount /dev/rbd0 /test0
root@ceph-1:~# df -h
Filesystem                         Size  Used Avail Use% Mounted on
/dev/rbd1                          3.0G   54M  3.0G   2% /test1
/dev/rbd0                          3.0G   54M  3.0G   2% /test0
```
## 20、客户端验证写入数据：
```shell
root@ceph-1:~# ll -h
-rw-------  1 root root 1.2G Mar 16 11:07 ceph_v18.tar
root@ceph-1:~# cp ceph_v18.tar /test1/
```

## 21、查看存储池空间：
```shell
root@ceph-1:~# ceph df
--- RAW STORAGE ---
CLASS     SIZE    AVAIL     USED  RAW USED  %RAW USED
ssd    300 GiB  296 GiB  3.7 GiB   3.7 GiB       1.25
TOTAL  300 GiB  296 GiB  3.7 GiB   3.7 GiB       1.25
 
--- POOLS ---
POOL             ID  PGS   STORED  OBJECTS     USED  %USED  MAX AVAIL
.mgr              1    1  449 KiB        2  1.3 MiB      0     94 GiB
cephfs_data       2   64      0 B        0      0 B      0     94 GiB
cephfs_metadata   3   32  2.3 KiB       22   96 KiB      0     94 GiB
rbd-data1         4   32  1.2 GiB      332  3.6 GiB   1.28     94 GiB
```
## 22、客户端使用普通账户挂载并使用 RBD：
### 创建普通账户
```shell
root@ceph-1:~# ceph auth add client.test mon 'allow r' osd 'allow rwx pool=rbd-data1'
added key for client.test
```
### 验证用户信息：
```shell
root@ceph-1:~# ceph auth get client.test
[client.test]
    key = AQA5LvVlU9HoNRAAmzFQVO6NwTKZ37et24KqUw==
        caps mon = "allow r"
        caps osd = "allow rwx pool=rbd-data1"
```
### 创建 keyring 文件两种方式：
#### 第一种：
```shell
root@ceph-1:~# ceph-authtool --create-keyring ceph.client.test.keyring
creating ceph.client.test.keyring
root@ceph-1:~# ls
ceph.client.test.keyring snap
```
#### 第二种：
```shell
root@ceph-1:~# ceph auth get client.test -o ceph.client.test.keyring
```
#### 验证keyring 文件
```shell
root@ceph-1:~# cat ceph.client.test.keyring 
    [client.test]
        key = AQA5LvVlU9HoNRAAmzFQVO6NwTKZ37et24KqUw==
        caps mon = "allow r"
        caps osd = "allow rwx pool=rbd-data1"
```
#### 同步普通用户认证文件：
```shell
scp ceph.conf ceph.client.test.keyring root@客户端IP:/etc/ceph/
```
#### 在客户端验证权限：
```shell
root@ceph-1:~# ceph --user test -s
cluster:
id:     e48ba8d6-e341-11ee-8b2b-2799cf0b1efd
health: HEALTH_OK

    services:
        mon: 3 daemons, quorum ceph-1,ceph-2,ceph-3 (age 2h)
        mgr: ceph-1.qceian(active, since 2h), standbys: ceph-2.cuszrq
        mds: 1/1 daemons up, 2 standby
        osd: 3 osds: 3 up (since 95m), 3 in (since 96m)
			 
    data:
        volumes: 1/1 healthy
        pools:   4 pools, 129 pgs
        objects: 356 objects, 1.2 GiB
        usage:   3.7 GiB used, 296 GiB / 300 GiB avail
        pgs:     129 active+clean
```
#### 映射 rbd：
```shell
root@ceph-1:~# rbd --user test -p rbd-data1 map data-img1
/dev/rbd0
root@ceph-1:~# fdisk -l /dev/rbd0
Disk /dev/rbd0: 3 GiB, 3221225472 bytes, 6291456 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 65536 bytes / 65536 bytes
```
#### 格式化并使用 rbd 镜像：
```shell
root@ceph-1:~# mkfs.ext4 /dev/rbd0
root@ceph-1:~# mkdir /data
root@ceph-1:~# mount /dev/rbd0 /data/
root@ceph-1:~# df -TH
Filesystem                        Type      Size  Used Avail Use% Mounted on
/dev/rbd0                         xfs       3.3G   57M  3.2G   2% /data
```
#### 管理端验证镜像状态
```shell
root@ceph-1:~# rbd ls -p rbd-data1 -l
NAME       SIZE   PARENT  FMT  PROT  LOCK
data-img1  3 GiB            2        excl  #施加锁文件， 已经被客户端映射
data-img2  3 GiB            2
```
## 23、rbd 镜像空间拉伸:
```shell
root@ceph-1:~# rbd ls -p rbd-data1 -l
NAME       SIZE   PARENT  FMT  PROT  LOCK
data-img1  3 GiB            2        excl
data-img2  3 GiB            2            
root@ceph-1:~# rbd resize --pool rbd-data1 --image data-img1 --size 8G
Resizing image: 100% complete...done.
# resize2fs /dev/rbd0 # 在 node 节点对磁盘重新识别
# xfs_growfs /data/ #在 node 挂载点对挂载点识别
root@ceph-1:~# rbd ls -p rbd-data1 -l
NAME       SIZE   PARENT  FMT  PROT  LOCK
data-img1  8 GiB            2        excl
data-img2  3 GiB            2 
```
## 24、开机自动挂载：
```shell
root@ceph-1:~# vim /etc/fstab
/dev/rbd0  /data xfs defaults 0 0
查看映射
root@ceph-1:~# rbd showmapped
id  pool       namespace  image      snap  device   
0   rbd-data1             data-img1  -     /dev/rbd0
```
## 25、卸载 rbd 镜像：
```shell
root@ceph-1:~# umount /data
root@ceph-1:~# rbd --user test -p rbd-data1 unmap data-img1
```

## 26、删除 rbd 镜像：
```shell
#删除存储池 rbd-data1 中的 data-img1、data-img2 镜像：
root@ceph-1:~# rbd rm --pool rbd-data1 --image data-img1
Removing image: 100% complete...done.
root@ceph-1:~# rbd rm --pool rbd-data1 --image data-img2
Removing image: 100% complete...done.
```
## 27、删除RBD存储池
```shell
root@ceph-1:~# ceph osd pool delete rbd-data1 rbd-data1 --yes-i-really-really-mean-it
pool 'rbd-data1' removed
```

# CephFs使用详解：
CephFs需要部署 MDS 提供 CephFs 功能
## 1、创建一个 pool 用于存储 cephfs 数据
```shell
root@ceph-1:~# ceph osd pool create cephfs_data 64 64
pool 'cephfs_data' created
```
## 2、创建一个 pool 用于存储 cephfs 元数据
```shell
root@ceph-1:~# ceph osd pool create cephfs_metadata 32 32
pool 'cephfs_metadata' created
```
## 3、创建 cephfs, 指定 cephfs_metadata 存储元数据, 指定 cephfs_data 存储实际数据
```shell
root@ceph-1:~# ceph fs new cephfs cephfs_metadata cephfs_data
  Pool 'cephfs_data' (id '2') has pg autoscale mode 'on' but is not marked as bulk.
  Consider setting the flag by running
    # ceph osd pool set cephfs_data bulk true
new fs with metadata pool 3 and data pool 2
```
## 4、设置默认最大PG数：
```shell
ceph config set mon mon_max_pg_per_osd 500
```
## 5、验证是否设置成功：
```shell
ceph config get mon mon_max_pg_per_osd
500
```
注意：默认cephfs的PG数总和为250，如已存在多个cephfs时。PG数会出现不足情况，此时可以修改默认值,设置默认最大PG数
## 6、查看 cephfs
```shell
root@ceph-1:~# ceph fs ls
name: cephfs, metadata pool: cephfs_metadata, data pools: [cephfs_data ]
```
## 7、在 ceph01, ceph02, ceph03 部署 mds
```shell
root@ceph-1:~# ceph orch apply mds cephfs --placement="3 ceph-1 ceph-2 ceph-3"
Scheduled mds.cephfs update...
```
## 8、查看 mds 是否启动
```shell
root@ceph-1:~# ceph orch ps --daemon-type mds
NAME                      HOST    PORTS  STATUS         REFRESHED  AGE  MEM USE  MEM LIM  VERSION  IMAGE ID      CONTAINER ID  
mds.cephfs.ceph-1.wtqitv  ceph-1         running (19s)     9s ago  19s    12.8M        -  18.2.2   6dc5f0faebb2  07f40cb41845  
mds.cephfs.ceph-2.wikqcw  ceph-2         running (17s)    11s ago  17s    12.7M        -  18.2.2   6dc5f0faebb2  44ae41015346  
mds.cephfs.ceph-3.umdhxv  ceph-3         running (21s)    11s ago  21s    14.6M        -  18.2.2   6dc5f0faebb2  fdfdee1a2cfa 
``` 
## 9、查看当前集群的所有 pool
```shell
root@ceph-1:~# ceph osd lspools
1 .mgr
2 cephfs_data
3 cephfs_metadata
```
## 10、创建客户端账户：
```shell
root@ceph-1:~# ceph auth add client.yanyan mon 'allow *' mds 'allow *' osd 'allow * pool=cephfs-data'
added key for client.yanyan
```
## 11、验证账户
```shell
root@ceph-1:~# ceph auth get client.yanyan
[client.yanyan]
key = AQBnfyNm86e6BRAAVnpzxEkAP8f782U6pJCAxg==
caps mds = "allow *"
caps mon = "allow *"
caps osd = "allow * pool=cephfs-data"
```
## 12、创建 keyring 文件
```shell
root@ceph-1:~# ceph auth get client.yanyan -o ceph.client.yanyan.keyring
```
## 13、创建 key 文件
```shell
root@ceph-1:~# ceph auth print-key client.yanyan > yanyan.key
```
## 14、验证用户的 keyring 文件
```shell
root@ceph-1:~# cat ceph.client.yanyan.keyring
[client.yanyan]
    key = AQBnfyNm86e6BRAAVnpzxEkAP8f782U6pJCAxg==
    caps mds = "allow *"
    caps mon = "allow *"
    caps osd = "allow * pool=cephfs-data"
```
## 15、挂载机器安装ceph-common
```shell
apt update && apt install ceph-common -y
```
## 16、同步客户端认证文件
```shell
root@ceph-1:~# scp ceph.conf ceph.client.yanyan.keyring yanyan.key root@10.2.0.45:/etc/ceph/
```
## 17、客户端验证权限
```shell
root@ceph-client:~# ceph --user yanyan -s
cluster:
id:     e48ba8d6-e341-11ee-8b2b-2799cf0b1efd
health: HEALTH_OK

	services:
	mon: 3 daemons, quorum ceph-1,ceph-2,ceph-3 (age 36m)
	mgr: ceph-1.qceian(active, since 2h), standbys: ceph-2.cuszrq
	mds: 1/1 daemons up, 2 standby
	osd: 3 osds: 3 up (since 2h), 3 in (since 5w)

	data:
	volumes: 1/1 healthy
	pools:   6 pools, 250 pgs
	objects: 30 objects, 451 KiB
	usage:   140 MiB used, 300 GiB / 300 GiB avail
	pgs:     250 active+clean
```
## 18、第一种挂载方式内核空间挂载:
### 1、secretfile方式挂载
```shell
root@ceph-client:~# mkdir /data
root@ceph-client:~#mount -t ceph 10.2.0.25:6789,10.2.0.26:6789,10.2.0.27:6789:/ /data -o name=yanyan,secretfile=/etc/ceph/yanyan.key,fs=cephfs-data
```
### 2、验证是否挂载成功
```shell
root@ceph-client:~#df -h | grep data
10.2.0.25:6789,10.2.0.26:6789,10.2.0.27:6789:/                    95G     0   95G   0% /data
```
### 3、验证写入数据
```shell
root@ceph-client:~# touch test.txt
root@ceph-client:~# echo 123456 > test.txt
root@ceph-client:~# cat test.txt
123456
root@ceph-client:~# cp test.txt /data/
root@ceph-client:~# cat /data/test.txt
123456
```
## 19、第二种挂载方式：
### 1、secret方式挂载：
```shell
[root@ceph-client ~]# umount /data/
root@ceph-client:~# cat /etc/ceph/yanyan.key
AQBnfyNm86e6BRAAVnpzxEkAP8f782U6pJCAxg==
root@ceph-client:~#mount -t ceph 10.2.0.25:6789,10.2.0.26:6789,10.2.0.27:6789:/ /data -o name=yanyan,secret=AQBnfyNm86e6BRAAVnpzxEkAP8f782U6pJCAxg==,fs=cephfs-data
```
### 2、验证是否挂载成功
```shell
root@ceph-client:~# df -h | grep data
10.2.0.25:6789,10.2.0.26:6789,10.2.0.27:6789:/   95G     0   95G   0% /data
```
### 3、验证写入数据
```shell
root@ceph-client:~# ls /data/
test.txt
root@ceph-client:~# cp /etc/hosts /data/
root@ceph-client:~# ls /data/
hosts  test.txt
root@ceph-client:~# cat /data/hosts
127.0.0.1 localhost
127.0.1.1      ceph-client

    # The following lines are desirable for IPv6 capable hosts
    ::1     ip6-localhost ip6-loopback
    fe00::0 ip6-localnet
    ff00::0 ip6-mcastprefix
    ff02::1 ip6-allnodes
    ff02::2 ip6-allrouters
```
## 20、开机挂载
```shell
root@ceph-client:~#cat /etc/fstab
10.2.0.25:6789,10.2.0.26:6789,10.2.0.27:6789:/ /data ceph defaults,name=yanyan,secretfile=/etc/ceph/yanyan.key,_netdev 0 0
```
## 21、删除Cephfs Pool
### 1、三台节点停掉MDS服务
```shell
root@ceph-2:~# systemctl stop ceph-e48ba8d6-e341-11ee-8b2b-2799cf0b1efd@mon.ceph-1.service
root@ceph-2:~# systemctl status ceph-e48ba8d6-e341-11ee-8b2b-2799cf0b1efd@mon.ceph-1.service
● ceph-e48ba8d6-e341-11ee-8b2b-2799cf0b1efd@mon.ceph-1.service - Ceph mon.ceph-1 for e48ba8d6-e341-11ee-8b2b-2799cf0b1efd
Loaded: loaded (/etc/systemd/system/ceph-e48ba8d6-e341-11ee-8b2b-2799cf0b1efd@.service; disabled; vendor preset: enabled)
Active: inactive (dead)
```
### 2、把要删除的cephfs存储池置为空闲
```shell
ceph fs fail cephfs
```
### 3、删除cephfs
```shell
ceph fs rm cephfs
```
### 4、设置可删除cephfs存储池
```shell
ceph config set mon mon_allow_pool_delete true
```
### 5、删除cephfs存储池
```shell
root@ceph-1:~# ceph osd pool delete cephfs_data cephfs_data --yes-i-really-really-mean-it
pool 'cephfs_data' removed
root@ceph-1:~# ceph osd pool delete cephfs_metadata cephfs_metadata --yes-i-really-really-mean-it
pool 'cephfs_metadata' removed
```
# 对接Kubernetes(Ceph-CSI)
## Ceph RBD CSI 部署
Ceph 官网参考链接 https://docs.ceph.com/en/quincy/rbd/rbd-kubernetes/?highlight=kubernetes

Ceph-csi 中参考链接 https://github.com/ceph/ceph-csi/blob/devel/docs/deploy-rbd.md
### 1、Ceph Cluster集群操作
#### 1.1创建对接kubernetes的存储池，存储池名为kubernetes
```shell
root@ceph-1:~# ceph osd pool create kubernetes
pool 'kubernetes' created
```
#### 1.2、初始化对接kubernetes的存储池
```shell
root@ceph-1:~#  rbd pool init kubernetes
```
#### 1.3、创建客户端用户
```shell
root@ceph-1:~# ceph auth get-or-create client.kubernetes mon 'profile rbd' osd 'profile rbd pool=kubernetes' mgr 'profile rbd pool=kubernetes'
[client.kubernetes]
key = AQD12VVlvLB5GBAAF7DWL9Z6ATEsCsNvyhgbkg==
```
#### 1.4、查看集群中mon信息
```shell
root@ceph-1:~# ceph mon dump
dumped monmap epoch 3
epoch 3
fsid e48ba8d6-e341-11ee-8b2b-2799cf0b1efd
last_changed 2024-04-09T10:08:25.108190+0000
created 2024-04-09T10:03:47.719363+0000
min_mon_release 18 (reef)
election_strategy: 1
0: [v2:10.2.0.25:3300/0,v1:10.2.0.25:6789/0] mon.ceph-1
1: [v2:10.2.0.26:3300/0,v1:10.2.0.26:6789/0] mon.ceph-2
2: [v2:10.2.0.27:3300/0,v1:10.2.0.27:6789/0] mon.ceph-3
```
### 2、部署CSI Plugin
#### 2.1、Ceph-CSI 驱动与 Ceph 集群交互所需的配置信息（建议保持默认）
```shell
root@master:~#cat ceph-config-map.yaml
---
apiVersion: v1
kind: ConfigMap
data:
  ceph.conf: |
    [global]
    auth_cluster_required = cephx
    auth_service_required = cephx
    auth_client_required = cephx
  # keyring is a required key and its value should be empty
  keyring: |
metadata:
  name: ceph-config
```
#### 2.2、配置 CSI驱动器的 ConfigMap文件，里面记录了ceph的mon节点IP:端口和clusterID
```shell
root@master:~#cat csi-config-map.yaml    #此文件需要修改，填写正确的clusterID，monitors 字段
---
apiVersion: v1
kind: ConfigMap
data:
  config.json: |-
    [
      {
        "clusterID": "e48ba8d6-e341-11ee-8b2b-2799cf0b1efd",
        "monitors": [
          "10.2.0.25:6789,10.2.0.26:6789,10.2.0.27:6789"
        ]
      }
    ]
metadata:
  name: ceph-csi-config
```
#### 2.3、ceph-csi 的最新版本需要一个额外的ConfigMap对象来定义密钥管理服务 (KMS) 提供程序的详细信息。因未设置 KMS，将空配置放入csi-kms-config-map.yaml
```shell
root@master:~#cat csi-kms-config-map.yaml
---
apiVersion: v1
kind: ConfigMap
data:
  config.json: |-
    {}
metadata:
  name: ceph-csi-encryption-kms-config

```
#### 2.4、csi-provisioner-rbac.yaml、csi-provisioner-rbac.yaml 创建ceph-csi所需的ServiceAccout用户和RBAC认证鉴权文件，创建PV和PVC时需要在k8s中对一些资源进行增删操作，例如：PVC,PV，官方不建议进行修改
```shell
root@master:~#cat csi-provisioner-rbac.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rbd-csi-provisioner
  # replace with non-default namespace name
  namespace: ceph

---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-external-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "update", "delete", "patch"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims/status"]
    verbs: ["update", "patch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshots"]
    verbs: ["get", "list", "patch"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshots/status"]
    verbs: ["get", "list", "patch"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshotcontents"]
    verbs: ["create", "get", "list", "watch", "update", "delete", "patch"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshotclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["volumeattachments"]
    verbs: ["get", "list", "watch", "update", "patch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["volumeattachments/status"]
    verbs: ["patch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["csinodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshotcontents/status"]
    verbs: ["update", "patch"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["serviceaccounts"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["serviceaccounts/token"]
    verbs: ["create"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-csi-provisioner-role
subjects:
  - kind: ServiceAccount
    name: rbd-csi-provisioner
    # replace with non-default namespace name
    namespace: ceph
roleRef:
  kind: ClusterRole
  name: rbd-external-provisioner-runner
  apiGroup: rbac.authorization.k8s.io

---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  # replace with non-default namespace name
  namespace: ceph
  name: rbd-external-provisioner-cfg
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "watch", "list", "delete", "update", "create"]

---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-csi-provisioner-role-cfg
  # replace with non-default namespace name
  namespace: ceph
subjects:
  - kind: ServiceAccount
    name: rbd-csi-provisioner
    # replace with non-default namespace name
    namespace: ceph
roleRef:
  kind: Role
  name: rbd-external-provisioner-cfg
  apiGroup: rbac.authorization.k8s.io
```
```shell
root@master:~# cat csi-nodeplugin-rbac.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rbd-csi-nodeplugin
  # replace with non-default namespace name
  namespace: ceph
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-csi-nodeplugin
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get"]
  # allow to read Vault Token and connection options from the Tenants namespace
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["serviceaccounts"]
    verbs: ["get"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["volumeattachments"]
    verbs: ["list", "get"]
  - apiGroups: [""]
    resources: ["serviceaccounts/token"]
    verbs: ["create"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-csi-nodeplugin
subjects:
  - kind: ServiceAccount
    name: rbd-csi-nodeplugin
    # replace with non-default namespace name
    namespace: ceph
roleRef:
  kind: ClusterRole
  name: rbd-csi-nodeplugin
  apiGroup: rbac.authorization.k8s.io
```
#### 2.5、创建StorageClass文件
```shell
root@master:~#csi-rbd-sc.yaml         # 此文件需要修改，填写正确的 clusterID，pool 字段
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: csi-rbd-sc
provisioner: rbd.csi.ceph.com
parameters:
   clusterID: e48ba8d6-e341-11ee-8b2b-2799cf0b1efd
   pool: kubernetes
   imageFeatures: layering
   csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
   csi.storage.k8s.io/provisioner-secret-namespace: ceph
   csi.storage.k8s.io/controller-expand-secret-name: csi-rbd-secret
   csi.storage.k8s.io/controller-expand-secret-namespace: ceph
   csi.storage.k8s.io/node-stage-secret-name: csi-rbd-secret
   csi.storage.k8s.io/node-stage-secret-namespace: ceph
#reclaimPolicy: Retain
allowVolumeExpansion: true
reclaimPolicy: Delete
#volumeBindingMode: WaitForFirstConsumer
mountOptions:
   - discard
```
#### 2.6、设置 cephx 凭据以便与 Ceph 集群通信。
```shell
root@master:~#cat csi-rbd-secret.yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: csi-rbd-secret
  namespace: ceph
stringData:
  userID: kubernetes
  userKey: AQD12VVlvLB5GBAAF7DWL9Z6ATEsCsNvyhgbkg==
```
#### 2.7、ceph-csi配置器
```shell
root@master:~#cat csi-rbdplugin-provisioner.yaml
---
kind: Service
apiVersion: v1
metadata:
  name: csi-rbdplugin-provisioner
  # replace with non-default namespace name
  namespace: ceph
  labels:
    app: csi-metrics
spec:
  selector:
    app: csi-rbdplugin-provisioner
  ports:
    - name: http-metrics
      port: 8080
      protocol: TCP
      targetPort: 8680

---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: csi-rbdplugin-provisioner
  # replace with non-default namespace name
  namespace: ceph
spec:
  replicas: 1
  selector:
    matchLabels:
      app: csi-rbdplugin-provisioner
  template:
    metadata:
      labels:
        app: csi-rbdplugin-provisioner
    spec:
      serviceAccountName: rbd-csi-provisioner
      priorityClassName: system-cluster-critical
      containers:
        - name: csi-provisioner
          image: docker.io/qinwenxiang/csi-provisioner:v3.6.0
          args:
            - "--csi-address=$(ADDRESS)"
            - "--v=1"
            - "--timeout=150s"
            - "--retry-interval-start=500ms"
            - "--leader-election=true"
            #  set it to true to use topology based provisioning
            - "--feature-gates=Topology=false"
            - "--feature-gates=HonorPVReclaimPolicy=true"
            - "--prevent-volume-mode-conversion=true"
            # if fstype is not specified in storageclass, ext4 is default
            - "--default-fstype=ext4"
            - "--extra-create-metadata=true"
          env:
            - name: ADDRESS
              value: unix:///csi/csi-provisioner.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
        - name: csi-snapshotter
          image: docker.io/qinwenxiang/csi-snapshotter:v6.3.0
          args:
            - "--csi-address=$(ADDRESS)"
            - "--v=1"
            - "--timeout=150s"
            - "--leader-election=true"
            - "--extra-create-metadata=true"
          env:
            - name: ADDRESS
              value: unix:///csi/csi-provisioner.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
        - name: csi-attacher
          image: docker.io/qinwenxiang/csi-attacher:v4.4.0
          args:
            - "--v=1"
            - "--csi-address=$(ADDRESS)"
            - "--leader-election=true"
            - "--retry-interval-start=500ms"
            - "--default-fstype=ext4"
          env:
            - name: ADDRESS
              value: /csi/csi-provisioner.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
        - name: csi-resizer
          image: docker.io/qinwenxiang/csi-resizer:v1.9.0
          args:
            - "--csi-address=$(ADDRESS)"
            - "--v=1"
            - "--timeout=150s"
            - "--leader-election"
            - "--retry-interval-start=500ms"
            - "--handle-volume-inuse-error=false"
            - "--feature-gates=RecoverVolumeExpansionFailure=true"
          env:
            - name: ADDRESS
              value: unix:///csi/csi-provisioner.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
        - name: csi-rbdplugin
          # for stable functionality replace canary with latest release version
          image: docker.io/qinwenxiang/cephcsi:canary
          args:
            - "--nodeid=$(NODE_ID)"
            - "--type=rbd"
            - "--controllerserver=true"
            - "--endpoint=$(CSI_ENDPOINT)"
            - "--csi-addons-endpoint=$(CSI_ADDONS_ENDPOINT)"
            - "--v=5"
            - "--drivername=rbd.csi.ceph.com"
            - "--pidlimit=-1"
            - "--rbdhardmaxclonedepth=8"
            - "--rbdsoftmaxclonedepth=4"
            - "--enableprofiling=false"
            - "--setmetadata=true"
          env:
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: NODE_ID
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            # - name: KMS_CONFIGMAP_NAME
            #   value: encryptionConfig
            - name: CSI_ENDPOINT
              value: unix:///csi/csi-provisioner.sock
            - name: CSI_ADDONS_ENDPOINT
              value: unix:///csi/csi-addons.sock
          imagePullPolicy: "IfNotPresent"
              volumeMounts:
            - name: socket-dir
              mountPath: /csi
            - mountPath: /dev
              name: host-dev
            - mountPath: /sys
              name: host-sys
            - mountPath: /lib/modules
              name: lib-modules
              readOnly: true
            - name: ceph-csi-config
              mountPath: /etc/ceph-csi-config/
            - name: ceph-csi-encryption-kms-config
              mountPath: /etc/ceph-csi-encryption-kms-config/
            - name: keys-tmp-dir
              mountPath: /tmp/csi/keys
            - name: ceph-config
              mountPath: /etc/ceph/
            - name: oidc-token
              mountPath: /run/secrets/tokens
              readOnly: true
        - name: csi-rbdplugin-controller
          # for stable functionality replace canary with latest release version
          image: docker.io/qinwenxiang/cephcsi:canary
          args:
            - "--type=controller"
            - "--v=5"
            - "--drivername=rbd.csi.ceph.com"
            - "--drivernamespace=$(DRIVER_NAMESPACE)"
            - "--setmetadata=true"
          env:
            - name: DRIVER_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
           - name: ceph-csi-config
              mountPath: /etc/ceph-csi-config/
            - name: keys-tmp-dir
              mountPath: /tmp/csi/keys
            - name: ceph-config
              mountPath: /etc/ceph/
        - name: liveness-prometheus
          image: docker.io/qinwenxiang/cephcsi:canary
          args:
            - "--type=liveness"
            - "--endpoint=$(CSI_ENDPOINT)"
            - "--metricsport=8680"
            - "--metricspath=/metrics"
            - "--polltime=60s"
            - "--timeout=3s"
          env:
            - name: CSI_ENDPOINT
              value: unix:///csi/csi-provisioner.sock
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
          imagePullPolicy: "IfNotPresent"
      volumes:
        - name: host-dev
          hostPath:
            path: /dev
        - name: host-sys
          hostPath:
            path: /sys
        - name: lib-modules
          hostPath:
            path: /lib/modules
        - name: socket-dir
          emptyDir: {
            medium: "Memory"
          }
        - name: ceph-config
          configMap:
            name: ceph-config
        - name: ceph-csi-config
          configMap:
            name: ceph-csi-config
        - name: ceph-csi-encryption-kms-config
          configMap:
            name: ceph-csi-encryption-kms-config
        - name: keys-tmp-dir
          emptyDir: {
            medium: "Memory"
          }
        - name: oidc-token
          projected:
            sources:
              - serviceAccountToken:
                  path: oidc-token
                  expirationSeconds: 3600
                  audience: ceph-csi-kms
```
#### 2.8、节点插件，负责每个节点都能与ceph集群正常交互
```shell
root@master:~#cat csi-rbdplugin.yaml
---
kind: DaemonSet
apiVersion: apps/v1
metadata:
  name: csi-rbdplugin
  # replace with non-default namespace name
  namespace: ceph
spec:
  selector:
    matchLabels:
      app: csi-rbdplugin
  template:
    metadata:
      labels:
        app: csi-rbdplugin
    spec:
      serviceAccountName: rbd-csi-nodeplugin
      hostNetwork: true
      hostPID: true
      priorityClassName: system-node-critical
      # to use e.g. Rook orchestrated cluster, and mons' FQDN is
      # resolved through k8s service, set dns policy to cluster first
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: driver-registrar
          # This is necessary only for systems with SELinux, where
          # non-privileged sidecar containers cannot access unix domain socket
          # created by privileged CSI driver container.
          securityContext:
            privileged: true
            allowPrivilegeEscalation: true
          image: docker.io/qinwenxiang/csi-node-driver-registrar:v2.9.0
          args:
            - "--v=1"
           - "--csi-address=/csi/csi.sock"
            - "--kubelet-registration-path=/var/lib/kubelet/plugins/rbd.csi.ceph.com/csi.sock"
          env:
            - name: KUBE_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
            - name: registration-dir
              mountPath: /registration
        - name: csi-rbdplugin
          securityContext:
            privileged: true
            capabilities:
              add: ["SYS_ADMIN"]
            allowPrivilegeEscalation: true
          # for stable functionality replace canary with latest release version
          image: docker.io/qinwenxiang/cephcsi:canary
          args:
            - "--nodeid=$(NODE_ID)"
            - "--pluginpath=/var/lib/kubelet/plugins"
            - "--stagingpath=/var/lib/kubelet/plugins/kubernetes.io/csi/"
            - "--type=rbd"
            - "--nodeserver=true"
            - "--endpoint=$(CSI_ENDPOINT)"
            - "--csi-addons-endpoint=$(CSI_ADDONS_ENDPOINT)"
            - "--v=5"
            - "--drivername=rbd.csi.ceph.com"
            - "--enableprofiling=false"
          env:
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: NODE_ID
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            # - name: KMS_CONFIGMAP_NAME
            #   value: encryptionConfig
            - name: CSI_ENDPOINT
              value: unix:///csi/csi.sock
            - name: CSI_ADDONS_ENDPOINT
              value: unix:///csi/csi-addons.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
            - mountPath: /dev
              name: host-dev
            - mountPath: /sys
              name: host-sys
            - mountPath: /run/mount
              name: host-mount
            - mountPath: /etc/selinux
              name: etc-selinux
              readOnly: true
            - mountPath: /lib/modules
              name: lib-modules
              readOnly: true
            - name: ceph-csi-config
              mountPath: /etc/ceph-csi-config/
            - name: ceph-csi-encryption-kms-config
              mountPath: /etc/ceph-csi-encryption-kms-config/
            - name: plugin-dir
              mountPath: /var/lib/kubelet/plugins
              mountPropagation: "Bidirectional"
            - name: mountpoint-dir
              mountPath: /var/lib/kubelet/pods
              mountPropagation: "Bidirectional"
            - name: keys-tmp-dir
              mountPath: /tmp/csi/keys
            - name: ceph-logdir
              mountPath: /var/log/ceph
            - name: ceph-config
              mountPath: /etc/ceph/
            - name: oidc-token
              mountPath: /run/secrets/tokens
              readOnly: true
        - name: liveness-prometheus
          securityContext:
            privileged: true
            allowPrivilegeEscalation: true
          image: docker.io/qinwenxiang/cephcsi:canary
          args:
            - "--type=liveness"
            - "--endpoint=$(CSI_ENDPOINT)"
            - "--metricsport=8680"
            - "--metricspath=/metrics"
            - "--polltime=60s"
            - "--timeout=3s"
          env:
            - name: CSI_ENDPOINT
              value: unix:///csi/csi.sock
            - name: POD_IP
              valueFrom:
                fieldRef:
              fieldPath: status.podIP
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
          imagePullPolicy: "IfNotPresent"
      volumes:
        - name: socket-dir
          hostPath:
            path: /var/lib/kubelet/plugins/rbd.csi.ceph.com
            type: DirectoryOrCreate
        - name: plugin-dir
          hostPath:
            path: /var/lib/kubelet/plugins
            type: Directory
        - name: mountpoint-dir
          hostPath:
            path: /var/lib/kubelet/pods
            type: DirectoryOrCreate
        - name: ceph-logdir
          hostPath:
            path: /var/log/ceph
            type: DirectoryOrCreate
        - name: registration-dir
          hostPath:
            path: /var/lib/kubelet/plugins_registry/
            type: Directory
        - name: host-dev
          hostPath:
            path: /dev
        - name: host-sys
          hostPath:
            path: /sys
        - name: etc-selinux
         hostPath:
            path: /etc/selinux
        - name: host-mount
          hostPath:
            path: /run/mount
        - name: lib-modules
          hostPath:
            path: /lib/modules
        - name: ceph-config
          configMap:
            name: ceph-config
        - name: ceph-csi-config
          configMap:
            name: ceph-csi-config
        - name: ceph-csi-encryption-kms-config
          configMap:
            name: ceph-csi-encryption-kms-config
        - name: keys-tmp-dir
          emptyDir: {
            medium: "Memory"
          }
        - name: oidc-token
          projected:
            sources:
              - serviceAccountToken:
                  path: oidc-token
                  expirationSeconds: 3600
                  audience: ceph-csi-kms
---
# This is a service to expose the liveness metrics
apiVersion: v1
kind: Service
metadata:
  name: csi-metrics-rbdplugin
  # replace with non-default namespace name
  namespace: ceph
  labels:
    app: csi-metrics
spec:
  ports:
    - name: http-metrics
      port: 8080
      protocol: TCP
      targetPort: 8680
  selector:
    app: csi-rbdplugin
```
#### 2.9、创建名称空间
```shell
root@master:~#kubectl create ns ceph
```
#### 2.10、apply配置文件
```shell
kubectl apply -f csi-config-map.yaml -n ceph
kubectl apply -f csi-kms-config-map.yaml -n ceph
kubectl apply -f ceph-config-map.yaml -n ceph
kubectl apply -f csi-rbd-secret.yaml -n ceph
kubectl apply -f csi-provisioner-rbac.yaml -n ceph
kubectl apply -f csi-nodeplugin-rbac.yaml -n ceph
kubectl apply -f csi-rbdplugin-provisioner.yaml -n ceph
kubectl apply -f csi-rbdplugin.yaml -n ceph
kubectl apply -f csi-rbd-sc.yaml -n ceph
```
#### 2.11、测试能否声明PVC申请PV,Pod能否挂载PV使用
有两种PVC文件,第一种是可以直接被Pod所挂载
```shell
root@master:~# cat raw-filesystem-pvc.yaml 
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem #挂载至/路径的方式
  resources:
    requests:
      storage: 10Gi
  storageClassName: csi-rbd-sc
```
第二种是挂载为设备文件
```shell
root@master:~# cat pvc/raw-block-pvc.yaml 
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: raw-block-pvc
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Block
  resources:
    requests:
      storage: 1Gi
  storageClassName: csi-rbd-sc
```
创建并应用PVC文件
```shell
kubectl apply -f raw-filesystem-pvc.yaml  -n ceph
```
测试Pod文件
```shell
root@master:~# cat ceph-rbd-demo.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ceph-rbd
spec:
  replicas: 1
  selector:
    matchLabels: #rs or deployment
      app: testing
  template:
    metadata:
      labels:
        app: testing
    spec:
      containers:
      - name: testing
        image: registry.cn-shanghai.aliyuncs.com/qwx_images/test-tools:v3
        imagePullPolicy: IfNotPresent
        volumeMounts:
        - name: data
          mountPath: /mnt
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: data

```
创建并应用Pod文件
```shell
kubectl apply -f ceph-rbd-demo.yaml -n ceph
```
验证Pod是否正常runing
```shell
root@master:~# kubectl get pod -n ceph
NAME                                           READY   STATUS    RESTARTS   AGE
ceph-rbd-2-56c596f786-p7n52                    1/1     Running   0          10s
```
验证ceph集群中是kubernetes存储池中是否有image创建
```shell
root@ceph-1:~# rbd ls --pool kubernetes
csi-vol-cabc6db4-d94e-4722-bd12-f50fd47f62ac
```
## Ceph CephFS CSI 部署
Ceph-csi 中参考链接 https://github.com/ceph/ceph-csi/blob/devel/docs/deploy-cephfs.md
### 1、 Ceph 集群配置
```shell
root@ceph-1:~# ceph fs volume create cephfs     
root@ceph-1:~# ceph fs subvolume create cephfs csi
root@ceph-1:~# ceph fs subvolumegroup create cephfs csi
```
### 2、kubernetes操作
部署文件：https://shackles.cn/Software/ceph-csi.tar.gz
```shell
root@master:~# ll
-rw-r--r-- 1 root root  579 Nov 13 13:59 ceph-conf.yaml
-rw-r--r-- 1 root root 5934 Nov 14 16:01 csi-cephfsplugin-provisioner.yaml
-rw-r--r-- 1 root root 6588 Nov 14 16:02 csi-cephfsplugin.yaml
-rw-r--r-- 1 root root 3280 Nov 14 14:09 csi-config-map.yaml   #需修改clusterID和monitors
-rw-r--r-- 1 root root  115 Nov 13 14:20 csi-kms-config-map.yaml
-rw-r--r-- 1 root root  846 Nov 13 14:09 csi-nodeplugin-rbac.yaml
-rw-r--r-- 1 root root 3000 Nov 13 14:09 csi-provisioner-rbac.yaml    
-rw-r--r-- 1 root root  164 Nov 13 14:09 csidriver.yaml
-rw-r--r-- 1 root root  405 Nov 14 14:30 secret.yaml            #需修改userKey和adminKey
-rw-r--r-- 1 root root 2673 Nov 14 16:10 storageclass.yaml      #需修改clusterID和fsName
```
文件作用：
- csi-config-map.yaml：Ceph CSI 插件配置信息
- csi-cephfsplugin-provisioner.yaml：CephFS CSI插件的资源配置文件。
- csi-cephfsplugin.yaml：CephFS CSI 插件的资源配置文件。
- csi-nodeplugin-rbac.yaml：CSI节点插件对集群的 RBAC认证授权文件
- csi-provisioner-rbac.yaml：CSI存储卷供应器（provisioner）对集群的 RBAC认证授权文件
- secret.yaml：ceph集群客户端访问用户和token信息
- storageclass.yaml：存储类配置文件信息
创建测试PVC文件
```shell
root@master:~#cat cephfs-pvc-demo.yaml 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ceph-cephfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: csi-cephfs-sc
```
创建测试Pod
```shell
root@master:~/qwx/ceph/ceph-cephfs-csi/test# cat ceph-cephfs.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ceph-cephfs
spec:
  replicas: 1
  selector:
    matchLabels: #rs or deployment
      app: testing
  template:
    metadata:
      labels:
        app: testing
    spec:
      containers:
      - name: testing
        image: registry.cn-shanghai.aliyuncs.com/qwx_images/test-tools:v3
        imagePullPolicy: IfNotPresent
        volumeMounts:
        - name: ceph-cephfs-pvc
          mountPath: /mnt
      volumes:
        - name: ceph-cephfs-pvc
          persistentVolumeClaim:
            claimName: ceph-cephfs-pvc
```
验证Pod是否创建成功：
```shell
root@master:~# kubectl get pod -n ceph
NAME                                           READY   STATUS    RESTARTS   AGE
ceph-cephfs-68657cbf6b-zrwdq                   1/1     Running   0          30s
```
验证Ceph Cluster是否有对应的卷创建
```shell
root@ceph-1:~# ceph fs subvolume ls cephfs csi
[
    {
        "name": "csi-vol-0a134d07-2ab5-4505-b9e7-d6a24a56e280"
    }
]
```