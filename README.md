# 运维手册
## Ubuntu 运维手册
### 1 常见问题 FAQ
#### 1.1 apt 安装过程中出现交互提示
> 适用版本：Ubuntu 18.04+（使用 `needrestart` 场景）
##### 现象
1. **内核提示**  
   ![kernelhints.png](Images/kernelhints.png)
   > 检测到新内核，需手动确认是否重启。

2. **服务重启提示**  
   ![restart_service.png](Images/restart_service.png)
   > 安装完成后，列出需重启的服务并要求确认。

##### 影响
- 自动化脚本（CI/CD、Ansible、cloud-init）被中断。
- 远程批量部署时无法人工干预。

---

### 2 解决方案

#### 2.1 临时方案（一次性）
在安装命令前添加环境变量，立即生效，无需修改系统配置。

```bash
sudo NEEDRESTART_MODE=l apt install socat conntrack ebtables ipset -y
```
| 变量值 | 含义                        |
| --- | ------------------------- |
| `l` | list only，仅列出需重启项，不提示、不重启 |
#### 2.2 永久方案（推荐）
修改 needrestart 配置文件，彻底关闭交互提示。
```shell
sudo sed -i \
  -e 's/^#\?\$nrconf{kernelhints} = .*/$nrconf{kernelhints} = 0;/' \
  -e 's/^#\?\$nrconf{restart} = .*/$nrconf{restart} = '\''l'\'';/' \
  /etc/needrestart/needrestart.conf
```
| 配置项           | 新值  | 说明            |
| ------------- | --- | ------------- |
| `kernelhints` | `0` | 关闭内核升级提示      |
| `restart`     | `l` | 仅列出服务，不重启、不询问 |

验证修改结果：
```shell
grep -E '^\$nrconf{kernelhints}|^\$nrconf{restart}' /etc/needrestart/needrestart.conf
```
预期输出
```shell
$nrconf{restart} = 'l';
$nrconf{kernelhints} = 0;
```
## Ubuntu 22.04.5 搭建本地离线 APT 源
> 适用场景 
> 服务器无法访问互联网，需要在一台可联网服务器上提前下载软件包及其依赖，并在离线服务器上搭建本地 APT 源完成软件安装。
### 一、制作离线软件包（联网服务器）
#### 1. 安装依赖分析工具
> 用于递归解析软件包依赖关系
```shell
apt install -y apt-rdepends
```
#### 2. 下载离线软件包（包含依赖）
> 将 PACKAGENAME 替换为你需要离线安装的软件名称，例如 net-tools、vim、docker.io 等。
```shell
mkdir -p /data/offline_pkg && \
chown _apt /data/offline_pkg && \
cd /data/offline_pkg && \
apt-get download $(
  apt-rdepends PACKAGENAME \
  | grep -v "^ " \
  | sed 's/debconf-2.0/debconf/g'
)
```
说明：
- apt-rdepends：递归获取依赖包
- grep -v "^ "：过滤重复的子依赖
- apt-get download：只下载 .deb，不安装
#### 3. 生成 APT Packages 索引
> APT 本地源必须包含 Packages 索引文件：
```shell
cd /data/offline_pkg && \
dpkg-scanpackages binary /dev/null > binary/Packages && \
gzip -9c binary/Packages > binary/Packages.gz
```
#### 4. 打包离线源目录
```shell
cd /data && \
tar -zcvf offline_pkg.tar.gz offline_pkg
```
### 二、离线服务器配置本地 APT 源
#### 1. 解压离线包
这里把压缩包中的文件解压到```/data```目录下并修改apt配置文件
```shell
cd /data && \
tar -zxvf offline_pkg.tar.gz
```
#### 2. 配置 APT 本地源
直接覆盖系统源（仅使用离线源）
```shell
echo "deb [trusted=yes] file:/data/offline_pkg binary/" > /etc/apt/sources.list
```
更新索引
```shell
apt update
```
#### 3. APT 更新预期输出（示例）
```shell
root@base-os:/data/offline_pkg# apt update
Get:1 file:/data/offline_pkg binary/ InRelease
Ign:1 file:/data/offline_pkg binary/ InRelease
Get:2 file:/data/offline_pkg binary/ Release
Ign:2 file:/data/offline_pkg binary/ Release
Get:3 file:/data/offline_pkg binary/ Packages
Ign:3 file:/data/offline_pkg binary/ Packages
Get:4 file:/data/offline_pkg binary/ Translation-en_US
Ign:4 file:/data/offline_pkg binary/ Translation-en_US
Get:5 file:/data/offline_pkg binary/ Translation-en
Ign:5 file:/data/offline_pkg binary/ Translation-en
Get:3 file:/data/offline_pkg binary/ Packages
Ign:3 file:/data/offline_pkg binary/ Packages
Get:4 file:/data/offline_pkg binary/ Translation-en_US
Ign:4 file:/data/offline_pkg binary/ Translation-en_US
Get:5 file:/data/offline_pkg binary/ Translation-en
Ign:5 file:/data/offline_pkg binary/ Translation-en
Get:3 file:/data/offline_pkg binary/ Packages
Ign:3 file:/data/offline_pkg binary/ Packages
Get:4 file:/data/offline_pkg binary/ Translation-en_US
Ign:4 file:/data/offline_pkg binary/ Translation-en_US
Get:5 file:/data/offline_pkg binary/ Translation-en
Ign:5 file:/data/offline_pkg binary/ Translation-en
Get:3 file:/data/offline_pkg binary/ Packages [25.0 kB]
Get:4 file:/data/offline_pkg binary/ Translation-en_US
Ign:4 file:/data/offline_pkg binary/ Translation-en_US
Get:5 file:/data/offline_pkg binary/ Translation-en
Ign:5 file:/data/offline_pkg binary/ Translation-en
Get:4 file:/data/offline_pkg binary/ Translation-en_US
Ign:4 file:/data/offline_pkg binary/ Translation-en_US
Get:5 file:/data/offline_pkg binary/ Translation-en
Ign:5 file:/data/offline_pkg binary/ Translation-en
Get:4 file:/data/offline_pkg binary/ Translation-en_US
Ign:4 file:/data/offline_pkg binary/ Translation-en_US
Get:5 file:/data/offline_pkg binary/ Translation-en
Ign:5 file:/data/offline_pkg binary/ Translation-en
Get:4 file:/data/offline_pkg binary/ Translation-en_US
Ign:4 file:/data/offline_pkg binary/ Translation-en_US
Get:5 file:/data/offline_pkg binary/ Translation-en
Ign:5 file:/data/offline_pkg binary/ Translation-en
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
11 packages can be upgraded. Run 'apt list --upgradable' to see them.
```
### 三、离线安装验证
#### 1. 安装测试软件包
```shell
root@base-os:/data/offline_pkg# apt install net-tools
```
#### 2. 安装结果示例
```shell
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following NEW packages will be installed:
  net-tools
0 upgraded, 1 newly installed, 0 to remove and 11 not upgraded.
Need to get 0 B/204 kB of archives.
After this operation, 819 kB of additional disk space will be used.
Get:1 file:/data/offline_pkg binary/ net-tools 1.60+git20181103.0eebece-1ubuntu5.4 [204 kB]
Selecting previously unselected package net-tools.
(Reading database ... 75156 files and directories currently installed.)
Preparing to unpack .../net-tools_1.60+git20181103.0eebece-1ubuntu5.4_amd64.deb ...
Unpacking net-tools (1.60+git20181103.0eebece-1ubuntu5.4) ...
Setting up net-tools (1.60+git20181103.0eebece-1ubuntu5.4) ...
Processing triggers for man-db (2.10.2-1) ...
Scanning processes...                                                                                                                                                             
Scanning candidates...                                                                                                                                                            
Scanning linux images...                                                                                                                                                          

Running kernel seems to be up-to-date.

Restarting services...
 systemctl restart cron.service irqbalance.service multipathd.service open-vm-tools.service packagekit.service polkit.service rsyslog.service snapd.service ssh.service systemd-journald.service systemd-networkd.service systemd-resolved.service systemd-timesyncd.service systemd-udevd.service udisks2.service vgauth.service
Service restarts being deferred:
 systemctl restart ModemManager.service
 /etc/needrestart/restart.d/dbus.service
 systemctl restart networkd-dispatcher.service
 systemctl restart systemd-logind.service
 systemctl restart unattended-upgrades.service
 systemctl restart user@0.service
 systemctl restart user@1000.service

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host
```