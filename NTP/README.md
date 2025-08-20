
# Ubuntu 上部署 NTP 服务器与客户端指南

本指南介绍如何在 Ubuntu 系统上安装并配置 NTP（Network Time Protocol）服务器与客户端，以实现局域网内的时间同步。

---

## 一、NTP 服务器配置

### 1. 更新软件包索引
```bash
sudo apt-get update
```

### 2. 安装 NTP 服务
```bash
sudo apt-get install ntp
```

### 3. 验证安装（可选）
```bash
sntp --version
```

### 4. 修改配置文件，使用国内时间服务器

编辑 `/etc/ntp.conf` 文件，将默认的国外服务器替换为国内 NTP 源，例如阿里云：

```bash
sudo vim /etc/ntp.conf
```

确保包含以下内容（过滤注释和空行）：

```conf
driftfile /var/lib/ntp/ntp.drift
leapfile /usr/share/zoneinfo/leap-seconds.list

statistics loopstats peerstats clockstats
filegen loopstats file loopstats type day enable
filegen peerstats file peerstats type day enable
filegen clockstats file clockstats type day enable

# 使用阿里云 NTP 服务器
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst

# 权限设置
restrict -4 default kod notrap nomodify nopeer noquery limited
restrict -6 default kod notrap nomodify nopeer noquery limited
restrict 127.0.0.1
restrict ::1
restrict source notrap nomodify noquery
```

### 5. 重启 NTP 服务
```bash
sudo systemctl restart ntp.service
```

### 6. 验证 NTP 服务状态
```bash
sudo systemctl status ntp.service
```

### 7. 检查 NTP 服务监听端口
```bash
sudo netstat -unlp | grep ntpd
```

示例输出：
```
udp        0      0 10.84.10.6:123       0.0.0.0:*    898947/ntpd
udp        0      0 127.0.0.1:123        0.0.0.0:*    898947/ntpd
udp6       0      0 :::123               :::*         898947/ntpd
...
```

---

## 二、客户端配置：使用 `systemd-timesyncd` 同步时间

Ubuntu 默认已安装 `systemd-timesyncd`，无需安装额外软件。只需修改配置文件，指定时间服务器地址。

### 1. 设置客户端同步目标为 NTP 服务器地址（例如 10.84.10.6）
```bash
sudo sed -i 's/^#NTP=/NTP=10.84.10.6/' /etc/systemd/timesyncd.conf
```

或手动编辑：
```bash
sudo vim /etc/systemd/timesyncd.conf
```

将以下内容取消注释并修改：
```conf
#NTP=  #NTP=10.84.10.6
```

### 2. 重启 `systemd-timesyncd` 并查看状态
```bash
sudo systemctl restart systemd-timesyncd
sudo systemctl status systemd-timesyncd
```

示例输出：
```
● systemd-timesyncd.service - Network Time Synchronization
     Loaded: loaded (/lib/systemd/system/systemd-timesyncd.service; enabled; vendor preset: enabled)
     Active: active (running)
     Status: "Initial synchronization to time server 10.84.10.6:123 (10.84.10.6)."
```

---

## 三、验证时间同步状态

```bash
timedatectl status
```

输出应包含：
```
NTP synchronized: yes
NTP service: active
```

---

## 参考命令速查

| 操作                     | 命令                                         |
|--------------------------|--------------------------------------------|
| 更新系统包索引           | `sudo apt-get update`                      |
| 安装 NTP 服务            | `sudo apt-get install ntp`                 |
| 重启 NTP 服务            | `sudo systemctl restart ntp`               |
| 查看 NTP 状态            | `sudo systemctl status ntp`                |
| 查看监听端口             | `sudo netstat -unlp \| grep ntpd`          |
| 重启 timesyncd 服务      | `sudo systemctl restart systemd-timesyncd` |
| 查看时间同步状态         | `timedatectl status`                       |

---

部署完成后，客户端将与本地 NTP 服务器定期同步时间，从而实现整个网络时间的一致性。
