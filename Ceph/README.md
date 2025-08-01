# Ceph 运维手册
```shell
# 查看集群状态信息
ceph -s

# 查看ceph集群中OSD(磁盘)的状态
ceph osd status

# 查看某个OSD属于哪个节点
ceph osd find <OSD ID>

# 查看已创建卷组
ceph fs subvolume ls cephfs

# 查看卷组中的子卷
ceph fs subvolume ls <cephfs name> <子卷 name>

# 查看已创建image
rbd -p <pool name> ls

# 查看各个存储池所用空间
ceph df
```
# FQA
## 1、Ceph osd 异常  处于autoout,exists状态
### 问题详情
```shell
# 查看集群状态和各组件是否正常
root@ceph01:~# ceph -s
  cluster:
    id:     660ee6be-a333-11ef-88f2-1587797466c6
    health: HEALTH_WARN
            1 failed cephadm daemon(s)
 
  services:
    mon: 5 daemons, quorum ceph01,ceph02,ceph03,ceph04,ceph05 (age 78m)
    mgr: ceph02.lldufe(active, since 32h), standbys: ceph01.usjsfn
    mds: 2/2 daemons up, 2 standby
    osd: 10 osds: 9 up (since 32h), 9 in (since 32h)   # 10个osd  9 个 UP 有一个有问题
 
  data:
    volumes: 2/2 healthy
    pools:   7 pools, 481 pgs
    objects: 55.72k objects, 151 GiB
    usage:   406 GiB used, 7.5 TiB / 7.9 TiB avail
    pgs:     481 active+clean
 
  io:
    client:   682 B/s rd, 1.3 MiB/s wr, 0 op/s rd, 103 op/s wr

# 查看是哪个osd 有问题
root@ceph01:~# ceph osd status
ID  HOST     USED  AVAIL  WR OPS  WR DATA  RD OPS  RD DATA  STATE           
 0  ceph01  46.0G   847G      7     27.5k      0        0   exists,up       
 1  ceph01  50.2G   843G      9     56.7k      0        0   exists,up       
 2  ceph01  39.2G   854G      0      819       1        0   exists,up       
 3  ceph02  43.9G   849G      3     17.5k      2        0   exists,up       
 4  ceph02  41.7G   852G      0     3276       0        0   exists,up       
 5  ceph02  50.3G   843G      8      257k      1        0   exists,up       
 6  ceph03  32.8G   860G      5      663k      0        0   exists,up       
 7  ceph03  56.9G   836G      3      243k      2        0   exists,up       
 8             0      0       0        0       0        0   autoout,exists  
 9  ceph03  44.7G   849G      1     5734       0        0   exists,up
 
# 查找osd8是属于哪台机器
root@ceph01:~# ceph osd find 8
{
    "osd": 8,
    "addrs": {
        "addrvec": [
            {
                "type": "v2",
                "addr": "10.84.10.10:6800",
                "nonce": 1753226352
            },
            {
                "type": "v1",
                "addr": "10.84.10.10:6801",
                "nonce": 1753226352
            }
        ]
    },
    "osd_fsid": "3a7b49f3-6c04-4b50-9381-c654211d2899",
    "host": "ceph04",
    "crush_location": {
        "host": "ceph04",
        "root": "default"
    }
}

# 到ceph04机器中查看osd8的服务日志
root@ceph04:~# journalctl -u ceph-660ee6be-a333-11ef-88f2-1587797466c6@osd.8.service -n 20 --no-pager
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.402+0000 7fdc5b066640  0 ceph version 18.2.4 (e7ad5345525c7aa95470c26863873b581076945d) reef (stable), process ceph-osd, pid 8
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.402+0000 7fdc5b066640  0 pidfile_write: ignore empty --pid-file
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.402+0000 7fdc5b066640  1 bdev(0x555f3e37ce00 /var/lib/ceph/osd/ceph-8/block) open path /var/lib/ceph/osd/ceph-8/block
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.402+0000 7fdc5b066640  1 bdev(0x555f3e37ce00 /var/lib/ceph/osd/ceph-8/block) open size 960160071680 (0xdf8e000000, 894 GiB) block_size 4096 (4 KiB) non-rotational device, discard not supported
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.402+0000 7fdc5b066640  1 bluestore(/var/lib/ceph/osd/ceph-8) _set_cache_sizes cache_size 3221225472 meta 0.45 kv 0.45 data 0.06
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.402+0000 7fdc5b066640  1 bdev(0x555f3e37d180 /var/lib/ceph/osd/ceph-8/block) open path /var/lib/ceph/osd/ceph-8/block
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.406+0000 7fdc5b066640  1 bdev(0x555f3e37d180 /var/lib/ceph/osd/ceph-8/block) open size 960160071680 (0xdf8e000000, 894 GiB) block_size 4096 (4 KiB) non-rotational device, discard not supported
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.406+0000 7fdc5b066640  1 bluefs add_block_device bdev 1 path /var/lib/ceph/osd/ceph-8/block size 894 GiB
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.406+0000 7fdc5b066640  1 bdev(0x555f3e37d180 /var/lib/ceph/osd/ceph-8/block) close
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.450+0000 7fdc5b066640  1 bdev(0x555f3e37ce00 /var/lib/ceph/osd/ceph-8/block) close
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.694+0000 7fdc5b066640  0 starting osd.8 osd_data /var/lib/ceph/osd/ceph-8 /var/lib/ceph/osd/ceph-8/journal
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.698+0000 7fdc5b066640 -1 unable to find any IPv4 address in networks '10.84.3.0/24' interfaces ''
Jun 23 14:21:38 ceph04 bash[12281]: debug 2025-06-23T06:21:38.698+0000 7fdc5b066640 -1 Failed to pick cluster address.
Jun 23 14:21:38 ceph04 systemd[1]: ceph-660ee6be-a333-11ef-88f2-1587797466c6@osd.8.service: Main process exited, code=exited, status=1/FAILURE
Jun 23 14:21:39 ceph04 systemd[1]: ceph-660ee6be-a333-11ef-88f2-1587797466c6@osd.8.service: Failed with result 'exit-code'.
Jun 23 14:21:49 ceph04 systemd[1]: ceph-660ee6be-a333-11ef-88f2-1587797466c6@osd.8.service: Scheduled restart job, restart counter is at 5.
Jun 23 14:21:49 ceph04 systemd[1]: Stopped Ceph osd.8 for 660ee6be-a333-11ef-88f2-1587797466c6.
Jun 23 14:21:49 ceph04 systemd[1]: ceph-660ee6be-a333-11ef-88f2-1587797466c6@osd.8.service: Start request repeated too quickly.
Jun 23 14:21:49 ceph04 systemd[1]: ceph-660ee6be-a333-11ef-88f2-1587797466c6@osd.8.service: Failed with result 'exit-code'.
Jun 23 14:21:49 ceph04 systemd[1]: Failed to start Ceph osd.8 for 660ee6be-a333-11ef-88f2-1587797466c6.
```
上方报错显示说```unable to find any IPv4 address in networks '10.84.3.0/24' interfaces Failed to pick cluster address``` 意思是找不到集群内部通讯IP，无法上传心跳
### 解决办法
#### 1、检查ceph04网络
```shell
root@ceph04:~# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eno5: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether d4:f5:ef:91:92:78 brd ff:ff:ff:ff:ff:ff
    altname enp93s0f0
3: eno6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether d4:f5:ef:91:92:79 brd ff:ff:ff:ff:ff:ff
    altname enp93s0f1
    inet 10.84.10.10/24 brd 10.84.10.255 scope global eno6
       valid_lft forever preferred_lft forever
    inet6 fe80::d6f5:efff:fe91:9279/64 scope link 
       valid_lft forever preferred_lft forever
4: eno7: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether d4:f5:ef:91:92:7a brd ff:ff:ff:ff:ff:ff
    altname enp93s0f2
5: eno8: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether d4:f5:ef:91:92:7b brd ff:ff:ff:ff:ff:ff
    altname enp93s0f3
6: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:56:85:e9:66 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
```
只有一个网卡为UP,检查ceph04的网线是不是少插一个
#### 2、检查网络配置是否异常 
```shell
root@ceph04:~# cat /etc/netplan/50-cloud-init.yaml 
# This file is generated from information provided by the datasource.  Changes
# to it will not persist across an instance reboot.  To disable cloud-init's
# network configuration capabilities, write a file
# /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg with the following:
# network: {config: disabled}
network:
    ethernets:
        eno6:
            addresses:
            - 10.84.10.10/24
            nameservers:
                addresses:
                - 10.0.13.23
                - 10.0.13.24
                search: []
            routes:
            -   to: default
                via: 10.84.10.1
    version: 2
```
#### 3、配置网卡文件
```shell
# 网卡配置
network:
  ethernets:
    eno6:
      addresses:
      - 10.84.10.10/23
      routes:
      - to: default
        via: 10.84.10.1
      nameservers:
        addresses:
        - 10.0.13.23
        - 10.0.13.24
        search: []
    eno5:
      addresses:
      - 10.84.3.245/24
      routes:
      - to: 10.84.3.0/24
        via: 10.84.3.1
      nameservers:
        addresses:
        - 10.0.13.23
        - 10.0.13.24
        search: []
  version: 2
# 使网卡配置生效
netplan apply
```
#### 4、重启osd服务
```shell
#重启osd服务
systemctl restart ceph-660ee6be-a333-11ef-88f2-1587797466c6@osd.8.service

#查看日志
root@ceph04:~# journalctl -u ceph-660ee6be-a333-11ef-88f2-1587797466c6@osd.8.service -n 20 --no-pager
Jun 23 16:01:01 ceph04 bash[6238]: debug 2025-06-23T08:01:00.997+0000 7f9264eaf640  1 osd.8 pg_epoch: 3715 pg[2.3( v 3714'20100499 (3652'20070406,3714'20100499] local-lis/les=3656/3657 n=1076 ec=76/76 lis/c=3656/3656 les/c/f=3657/3714/0 sis=3715) [5,8,9] r=1 lpr=3715 pi=[3656,3715)/1 luod=0'0 lua=3657'20099698 crt=3714'20100499 mlcod 0'0 active mbc={}] start_peering_interval up [5,8,9] -> [5,8,9], acting [5,9,1] -> [5,8,9], acting_primary 5 -> 5, up_primary 5 -> 5, role -1 -> 1, features acting 4540138322906710015 upacting 4540138322906710015
Jun 23 16:01:01 ceph04 bash[6238]: debug 2025-06-23T08:01:00.997+0000 7f9264eaf640  1 osd.8 pg_epoch: 3715 pg[2.3( v 3714'20100499 (3652'20070406,3714'20100499] local-lis/les=3656/3657 n=1076 ec=76/76 lis/c=3656/3656 les/c/f=3657/3714/0 sis=3715) [5,8,9] r=1 lpr=3715 pi=[3656,3715)/1 crt=3714'20100499 mlcod 0'0 unknown NOTIFY mbc={}] state<Start>: transitioning to Stray
Jun 23 16:01:04 ceph04 bash[6238]: debug 2025-06-23T08:01:04.014+0000 7f9262eab640  1 osd.8 pg_epoch: 3717 pg[5.1f( v 3715'860669 (3643'830600,3715'860669] local-lis/les=3656/3657 n=508 ec=1309/1302 lis/c=3656/3656 les/c/f=3657/3716/0 sis=3717) [3,8,9] r=1 lpr=3717 pi=[3656,3717)/1 luod=0'0 lua=3653'860598 crt=3715'860669 mlcod 0'0 active mbc={}] start_peering_interval up [3,8,9] -> [3,8,9], acting [3,9,1] -> [3,8,9], acting_primary 3 -> 3, up_primary 3 -> 3, role -1 -> 1, features acting 4540138322906710015 upacting 4540138322906710015
Jun 23 16:01:04 ceph04 bash[6238]: debug 2025-06-23T08:01:04.014+0000 7f9262eab640  1 osd.8 pg_epoch: 3717 pg[5.1f( v 3715'860669 (3643'830600,3715'860669] local-lis/les=3656/3657 n=508 ec=1309/1302 lis/c=3656/3656 les/c/f=3657/3716/0 sis=3717) [3,8,9] r=1 lpr=3717 pi=[3656,3717)/1 crt=3715'860669 mlcod 0'0 unknown NOTIFY mbc={}] state<Start>: transitioning to Stray
Jun 23 16:01:19 ceph04 bash[6238]: debug 2025-06-23T08:01:19.638+0000 7f92676b4640  1 osd.8 pg_epoch: 3719 pg[2.e( v 3718'22585735 (3651'22555702,3718'22585735] local-lis/les=3656/3657 n=1052 ec=76/76 lis/c=3656/3656 les/c/f=3657/3718/0 sis=3719) [2,9,8] r=2 lpr=3719 pi=[3656,3719)/1 luod=0'0 lua=3653'22585111 crt=3718'22585735 mlcod 0'0 active mbc={}] start_peering_interval up [2,9,8] -> [2,9,8], acting [2,9,5] -> [2,9,8], acting_primary 2 -> 2, up_primary 2 -> 2, role -1 -> 2, features acting 4540138322906710015 upacting 4540138322906710015
Jun 23 16:01:19 ceph04 bash[6238]: debug 2025-06-23T08:01:19.638+0000 7f92676b4640  1 osd.8 pg_epoch: 3719 pg[2.e( v 3718'22585735 (3651'22555702,3718'22585735] local-lis/les=3656/3657 n=1052 ec=76/76 lis/c=3656/3656 les/c/f=3657/3718/0 sis=3719) [2,9,8] r=2 lpr=3719 pi=[3656,3719)/1 crt=3718'22585735 mlcod 0'0 unknown NOTIFY mbc={}] state<Start>: transitioning to Stray
Jun 23 16:01:23 ceph04 bash[6238]: debug 2025-06-23T08:01:23.666+0000 7f926a6ba640  1 osd.8 pg_epoch: 3721 pg[5.8( v 3720'1068588 (3645'1038500,3720'1068588] local-lis/les=3656/3657 n=494 ec=1309/1302 lis/c=3656/3656 les/c/f=3657/3720/0 sis=3721) [8,7,2] r=0 lpr=3721 pi=[3656,3721)/1 luod=0'0 lua=3657'1068313 crt=3720'1068588 mlcod 0'0 active mbc={}] start_peering_interval up [8,7,2] -> [8,7,2], acting [2,7,5] -> [8,7,2], acting_primary 2 -> 8, up_primary 8 -> 8, role -1 -> 0, features acting 4540138322906710015 upacting 4540138322906710015
Jun 23 16:01:23 ceph04 bash[6238]: debug 2025-06-23T08:01:23.666+0000 7f926a6ba640  1 osd.8 pg_epoch: 3721 pg[5.8( v 3720'1068588 (3645'1038500,3720'1068588] local-lis/les=3656/3657 n=494 ec=1309/1302 lis/c=3656/3656 les/c/f=3657/3720/0 sis=3721) [8,7,2] r=0 lpr=3721 pi=[3656,3721)/1 crt=3720'1068588 mlcod 0'0 unknown mbc={}] state<Start>: transitioning to Primary
Jun 23 16:01:24 ceph04 bash[6238]: debug 2025-06-23T08:01:24.686+0000 7f926a6ba640  1 osd.8 pg_epoch: 3722 pg[5.8( v 3720'1068588 (3645'1038500,3720'1068588] local-lis/les=3721/3722 n=494 ec=1309/1302 lis/c=3656/3656 les/c/f=3657/3720/0 sis=3721) [8,7,2] r=0 lpr=3721 pi=[3656,3721)/1 crt=3720'1068588 mlcod 0'0 active mbc={}] state<Started/Primary/Active>: react AllReplicasActivated Activating complete
Jun 23 16:01:39 ceph04 bash[6238]: debug 2025-06-23T08:01:39.855+0000 7f92676b4640  1 osd.8 pg_epoch: 3723 pg[2.1e( v 3722'30033884 (3652'30003802,3722'30033884] local-lis/les=3656/3657 n=1038 ec=76/76 lis/c=3656/3656 les/c/f=3657/3722/0 sis=3723) [2,7,8] r=2 lpr=3723 pi=[3656,3723)/1 luod=0'0 lua=3657'30033181 crt=3722'30033884 mlcod 0'0 active mbc={}] start_peering_interval up [2,7,8] -> [2,7,8], acting [2,7,5] -> [2,7,8], acting_primary 2 -> 2, up_primary 2 -> 2, role -1 -> 2, features acting 4540138322906710015 upacting 4540138322906710015
Jun 23 16:01:39 ceph04 bash[6238]: debug 2025-06-23T08:01:39.855+0000 7f92676b4640  1 osd.8 pg_epoch: 3723 pg[2.1e( v 3722'30033884 (3652'30003802,3722'30033884] local-lis/les=3656/3657 n=1038 ec=76/76 lis/c=3656/3656 les/c/f=3657/3722/0 sis=3723) [2,7,8] r=2 lpr=3723 pi=[3656,3723)/1 crt=3722'30033884 mlcod 0'0 unknown NOTIFY mbc={}] state<Start>: transitioning to Stray
Jun 23 16:01:57 ceph04 bash[6238]: debug 2025-06-23T08:01:57.984+0000 7f926a6ba640  1 osd.8 pg_epoch: 3725 pg[2.18( v 3724'19499075 (3652'19469003,3724'19499075] local-lis/les=3656/3657 n=1039 ec=76/76 lis/c=3656/3656 les/c/f=3657/3724/0 sis=3725) [8,4,6] r=0 lpr=3725 pi=[3656,3725)/1 luod=0'0 lua=3657'19498332 crt=3724'19499075 mlcod 0'0 active mbc={}] start_peering_interval up [8,4,6] -> [8,4,6], acting [2,4,6] -> [8,4,6], acting_primary 2 -> 8, up_primary 8 -> 8, role -1 -> 0, features acting 4540138322906710015 upacting 4540138322906710015
Jun 23 16:01:57 ceph04 bash[6238]: debug 2025-06-23T08:01:57.984+0000 7f926a6ba640  1 osd.8 pg_epoch: 3725 pg[2.18( v 3724'19499075 (3652'19469003,3724'19499075] local-lis/les=3656/3657 n=1039 ec=76/76 lis/c=3656/3656 les/c/f=3657/3724/0 sis=3725) [8,4,6] r=0 lpr=3725 pi=[3656,3725)/1 crt=3724'19499075 mlcod 0'0 unknown mbc={}] state<Start>: transitioning to Primary
Jun 23 16:01:58 ceph04 bash[6238]: debug 2025-06-23T08:01:58.820+0000 7f92686b6640  0 log_channel(cluster) log [DBG] : 7.3c scrub starts
Jun 23 16:01:58 ceph04 bash[6238]: debug 2025-06-23T08:01:58.836+0000 7f92646ae640  0 log_channel(cluster) log [DBG] : 7.3c scrub ok
Jun 23 16:01:59 ceph04 bash[6238]: debug 2025-06-23T08:01:58.996+0000 7f92666b2640  1 osd.8 pg_epoch: 3726 pg[2.18( v 3724'19499075 (3652'19469003,3724'19499075] local-lis/les=3725/3726 n=1039 ec=76/76 lis/c=3656/3656 les/c/f=3657/3724/0 sis=3725) [8,4,6] r=0 lpr=3725 pi=[3656,3725)/1 crt=3724'19499075 mlcod 0'0 active mbc={}] state<Started/Primary/Active>: react AllReplicasActivated Activating complete
Jun 23 16:01:59 ceph04 bash[6238]: debug 2025-06-23T08:01:59.844+0000 7f9262eab640  0 log_channel(cluster) log [DBG] : 7.7f deep-scrub starts
Jun 23 16:01:59 ceph04 bash[6238]: debug 2025-06-23T08:01:59.864+0000 7f9262eab640  0 log_channel(cluster) log [DBG] : 7.7f deep-scrub ok
Jun 23 16:02:01 ceph04 bash[6238]: debug 2025-06-23T08:02:01.940+0000 7f92666b2640  0 log_channel(cluster) log [DBG] : 4.90 scrub starts
Jun 23 16:02:01 ceph04 bash[6238]: debug 2025-06-23T08:02:01.956+0000 7f92666b2640  0 log_channel(cluster) log [DBG] : 4.90 scrub ok
```
#### 5、在集群中验证osd8是否正常
```shell
root@ceph01:~# ceph -s
  cluster:
    id:     660ee6be-a333-11ef-88f2-1587797466c6
    health: HEALTH_WARN
            1 failed cephadm daemon(s)
 
  services:
    mon: 5 daemons, quorum ceph01,ceph02,ceph03,ceph04,ceph05 (age 10m)
    mgr: ceph02.lldufe(active, since 33h), standbys: ceph01.usjsfn
    mds: 2/2 daemons up, 2 standby
    osd: 10 osds: 10 up (since 49s), 10 in (since 49s); 21 remapped pgs  #10个osd 10个UP  证明osd8已恢复正常
 
  data:
    volumes: 2/2 healthy
    pools:   7 pools, 481 pgs
    objects: 55.64k objects, 150 GiB
    usage:   444 GiB used, 8.3 TiB / 8.7 TiB avail
    pgs:     17063/166926 objects misplaced (10.222%)  #数据平衡中
             458 active+clean
             20  active+remapped+backfill_wait
             1   active+clean+scrubbing
             1   active+remapped+backfilling
             1   active+clean+scrubbing+deep
 
  io:
    client:   341 B/s rd, 914 KiB/s wr, 0 op/s rd, 45 op/s wr
    recovery: 36 MiB/s, 1 keys/s, 13 objects/s
    
# 数据平衡完后再查看
root@ceph01:~# ceph -s
  cluster:
    id:     660ee6be-a333-11ef-88f2-1587797466c6
    health: HEALTH_OK  #已恢复正常  问题解决
 
  services:
    mon: 5 daemons, quorum ceph01,ceph02,ceph03,ceph04,ceph05 (age 24m)
    mgr: ceph02.lldufe(active, since 33h), standbys: ceph01.usjsfn
    mds: 2/2 daemons up, 2 standby
    osd: 10 osds: 10 up (since 14m), 10 in (since 14m)
 
  data:
    volumes: 2/2 healthy
    pools:   7 pools, 481 pgs
    objects: 55.70k objects, 151 GiB
    usage:   405 GiB used, 8.3 TiB / 8.7 TiB avail
    pgs:     481 active+clean
 
  io:
    client:   341 B/s rd, 2.0 MiB/s wr, 0 op/s rd, 138 op/s wr
```
## 2、清理cephfs中的子卷
有时候把存储类的策略修改成了```reclaimPolicy: Retain``` 删除掉PV和PVC时，ceph中的卷目录依旧存在，此时如果想在ceph集群中删除需要执行以下操作
语法格式：
```shell
ceph fs subvolume rm <文件系统名称> <子卷名称> [<子卷组名称>] [选项]
```
示例：
```shell
root@ceph01:~# ceph fs subvolume ls cephfs csi
[
    {
        "name": "csi-vol-8d0cff75-f827-4481-9c32-488fade7d73c"
    },
    {
        "name": "csi-vol-50409f8d-02ad-4f0a-83be-17efb6b4a40c"
    }
]

root@ceph01:~# ceph fs subvolume rm cephfs csi-vol-50409f8d-02ad-4f0a-83be-17efb6b4a40c csi --force
root@ceph01:~# ceph fs subvolume ls cephfs csi
[
    {
        "name": "csi-vol-8d0cff75-f827-4481-9c32-488fade7d73c"
    }
]
```
## 3、清理rbd中的image
语法格式：
```shell
rbd rm -p <pool_name> <image_name>
```
示例：
```shell
root@ceph01:~# rbd rm kubernetes/csi-vol-a0016be4-54a1-489a-b5dd-2dd14c9b2ec6
Removing image: 100% complete...done.
```
如果image被使用中是无法被删除的
```shell
#举例
root@ceph01:~# rbd rm kubernetes/csi-vol-e483e366-cf2a-4273-91c6-483357f9444d
2024-11-22T11:17:11.041+0800 7f9ad9ffb700 -1 librbd::image::PreRemoveRequest: 0x5572469d42b0 check_image_watchers: image has watchers - not removing
Removing image: 0% complete...failed.
rbd: error: image still has watchers
This means the image is still open or the client using it crashed. Try again after closing/unmapping it or waiting 30s for the crashed client to timeout.
```
## 4、查询PVC挂载的是哪个image
### 4.1、mount 方式查询
```shell
root@master2:~#  mount | grep rbd
/dev/rbd0 on /var/lib/kubelet/plugins/kubernetes.io/csi/pv/pvc-f0d8f905-f5dc-42ee-9846-15ac33b84773/globalmount/0001-0024-660ee6be-a333-11ef-88f2-1587797466c6-0000000000000002-6fb4417f-70e0-4c86-9555-c37fbabd8783 type ext4 (rw,relatime,discard,stripe=16,_netdev)
/dev/rbd0 on /var/lib/kubelet/pods/8694e7f8-ce29-4f5d-8852-8c393030cd44/volumes/kubernetes.io~csi/pvc-f0d8f905-f5dc-42ee-9846-15ac33b84773/mount type ext4 (rw,relatime,discard,stripe=16,_netdev)
/dev/rbd0 on /var/lib/kubelet/pods/8694e7f8-ce29-4f5d-8852-8c393030cd44/volume-subpaths/pvc-f0d8f905-f5dc-42ee-9846-15ac33b84773/init/0 type ext4 (rw,relatime,discard,stripe=16)
/dev/rbd0 on /var/lib/kubelet/pods/8694e7f8-ce29-4f5d-8852-8c393030cd44/volume-subpaths/pvc-f0d8f905-f5dc-42ee-9846-15ac33b84773/redis/0 type ext4 (rw,relatime,discard,stripe=16)
/dev/rbd1 on /var/lib/kubelet/plugins/kubernetes.io/csi/pv/pvc-69a041be-842a-4221-89e3-4c334e1f7b0b/globalmount/0001-0024-660ee6be-a333-11ef-88f2-1587797466c6-0000000000000002-c0b75db4-bfdf-47a0-8052-858748b57e4b type ext4 (rw,relatime,discard,stripe=16,_netdev)
/dev/rbd1 on /var/lib/kubelet/pods/8694e7f8-ce29-4f5d-8852-8c393030cd44/volumes/kubernetes.io~csi/pvc-69a041be-842a-4221-89e3-4c334e1f7b0b/mount type ext4 (rw,relatime,discard,stripe=16,_netdev)
```
c37fbabd8783和858748b57e4b 对应着image后12位ID
### 4.2、kubectl方式查询
```shell
root@master3:~# kubectl get pv -o json | jq -r '.items[].spec.csi.volumeHandle' | awk '{print substr($0, length($0)-11, 12)}'
eacd7eae6dac
22b2a7243ba5
3ca22c459750
336983644613
0d307d6a4308
4ac1dda8b4e4
1d84dbf5391b
21165433a318
f2a5cfc0fc8c
3ac1966671d0
cba3c416b0cc
d7137d9762fe
10df14a9911d
f1c9bc1d3272
9d2fb0a15225
15c0f11c48e1
e824dfb6ae43
ec9b06ca124e
080437d9c845
3a1e596feff5
c9f639075c10
74e531b5cc5f
47d474ae1bcc
662f189a137b
e293c7181050
6ac00c255632
8704a3f5d12f
b525a49c99d4
38fb5be734f2
b7caaf5818ed
2c478e37695f
ed50bcf367de
f9350590b5f3
3e7976475437
214399b30053
7b5ea1c44080
59396c916b51
d0dce30aa264
babcb350317c
738d5e0975b7
220e9c3aa08e
32f3bb1a06bd
337cb970910e
537878622304
f640638dc040
858527881202
ff1c546e760a
bacb6f3ec559
```
每个ID对应着ceph中rbd的image ID
例如：eacd7eae6dac  对应着csi-vol-92f0db0a-5d0b-46aa-9c45-eacd7eae6dac
## 5、Pod 重新调度时，对应的PVC一直绑定不上，报错说是已被进程占用
### 问题描述：

Pod创建在A节点，之后被重新调度到B节点，调度到B节点时一直处于```ContainerCreating```查看报错显示是PVC已被占用，到Ceph节点查看对应的image信息，显示被10.84.10.13所占用并有watcher锁，查看对应主机显示没有被占用
```shell
# 占用日志
Events:
  Type     Reason       Age    From               Message
  ----     ------       ----   ----               -------
  Normal   Scheduled    2m22s  default-scheduler  Successfully assigned lingshuchain/serving-56f679b7b-82p2z to node3
  Warning  FailedMount  20s    kubelet            Unable to attach or mount volumes: unmounted volumes=[volume-kf16n5], unattached volumes=[host-time volume-1x0122 volume-kf16n5 kube-api-access-v487t]: timed out waiting for the condition
  Warning  FailedMount  19s    kubelet            MountVolume.MountDevice failed for volume "pvc-2329c9ec-bfa3-4be8-8f70-a6a98e47b952" : rpc error: code = Internal desc = rbd image kubernetes/csi-vol-9bfc9e62-d507-4aac-b84e-21165433a318 is still being used

# image信息
root@ceph01:~# rbd status kubernetes/csi-vol-9bfc9e62-d507-4aac-b84e-21165433a318 -p kubernetes
Watchers:
	watcher=10.84.10.13:0/254249809 client.164878 cookie=18446462598732840978
	
# 查看10.84.10.13卷挂载信息
root@node1:~# mount | grep pvc-2329c9ec-bfa3-4be8-8f70-a6a98e47b952
root@node1:~# hostname -I
10.84.10.13 172.17.0.1 10.233.90.0
```
### 解决办法
把watcher ip加入到黑名单，然后再在黑名单中清除
```shell
# 把watcher ip信息（10.84.10.13:0/254249809）加入到黑名单
root@ceph01:~# ceph osd blacklist add 10.84.10.13:0/254249809
blocklisting 10.84.10.13:0/254249809 until 2025-07-03T02:32:05.399971+0000 (3600 sec)
root@ceph01:~# rbd status kubernetes/csi-vol-9bfc9e62-d507-4aac-b84e-21165433a318 -p kubernetes
Watchers: none

# 在黑名单中清除10.84.10.13:0/254249809
root@ceph01:~# ceph osd blacklist rm 10.84.10.13:0/254249809
un-blocklisting 10.84.10.13:0/254249809
root@ceph01:~# rbd status kubernetes/csi-vol-9bfc9e62-d507-4aac-b84e-21165433a318 -p kubernetes
Watchers: none
```
### 优化SC
可以在SC的配置文件中加个参数```recover_session=clean```
```yaml
mountOptions:
  - discard
  - recover_session=clean
```