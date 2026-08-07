# 基于keeper部署clickhouse
## 环境配置信息
| 系统版本             | IP地址         | 主机名      | clickhouse版本       |
|---------------------|--------------|-------------|----------------------|
| Ubuntu 24.04.4 LTS  | 10.186.48.133 | ck-node01  | Version: 24.8.1.2684 |
| Ubuntu 24.04.4 LTS  | 10.186.48.138 | ck-node02  | Version: 24.8.1.2684 |
| Ubuntu 24.04.4 LTS  | 10.186.48.139 | ck-node03  | Version: 24.8.1.2684 |

## 部署ClickHouse
### 配置主机解析文件（三台机器都要执行）
```shell
cat >> /etc/hosts << EOF


# ClickHouse Cluster
10.186.48.133    ck-node01
10.186.48.138    ck-node02
10.186.48.139    ck-node03
EOF
```
### 下载ClickHouse制品文件（三台机器都要执行）
```shell
mkdir  /opt/clickhouse
cd /opt/clickhouse
curl -O https://packages.clickhouse.com/tgz/stable/clickhouse-common-static-24.8.1.2684-amd64.tgz
curl -O https://packages.clickhouse.com/tgz/stable/clickhouse-server-24.8.1.2684-amd64.tgz
curl -O https://packages.clickhouse.com/tgz/stable/clickhouse-client-24.8.1.2684-amd64.tgz
tar -xzf clickhouse-common-static-*.tgz -C /opt/clickhouse
tar -xzf clickhouse-server-*.tgz       -C /opt/clickhouse
tar -xzf clickhouse-client-*.tgz       -C /opt/clickhouse
```

### 修改config配置文件（三台机器都要执行）
```shell
mkdir -p /etc/clickhouse-server/config.d
cp  /opt/clickhouse/clickhouse-server-24.8.1.2684/etc/clickhouse-server/config.xml   /etc/clickhouse-server
cp /opt/clickhouse/clickhouse-server-24.8.1.2684/etc/clickhouse-server/users.xml   /etc/clickhouse-server

#编辑配置文件，
vim /etc/clickhouse-server/config.xml
<!-- 将下面行注释去掉 --> 
<listen_host>::</listen_host> 

<!--修改存放缓存文件的位置--> 
<custom_cached_disks_base_directory>/var/lib/clickhouse/caches/</custom_cached_disks_base_directory>
<!--修改如下--> 
<custom_cached_disks_base_directory>/data/clickhouse/caches/</custom_cached_disks_base_directory>

<!-- 修改默认数据存储目录，比如在/home下创建目录clickhouse --> 
<path>/var/lib/clickhouse/</path> 
<!-- 修改为如下 --> 
<path>/data/clickhouse/</path> 
```
### 修改users配置文件（三台机器都要执行）
```shell
vim /etc/clickhouse-server/users.xml
<clickhouse>
    <!-- See also the files in users.d directory where the settings can be overridden. -->

    <!-- Profiles of settings. -->
    <profiles>
        <!-- Default settings. -->
        <default>
            <max_memory_usage>2800000000000</max_memory_usage>  <!-- 新增 -->
        </default>

        <!-- Profile that allows only read queries. -->
        <readonly>
            <readonly>1</readonly>
        </readonly>
    </profiles>

    <!-- Users and ACL. -->
    <users>
        <!-- If user name was not specified, 'default' user is used. -->
        <default>
            <!-- See also the files in users.d directory where the password can be overridden.

                 Password could be specified in plaintext or in SHA256 (in hex format).

                 If you want to specify password in plaintext (not recommended), place it in 'password' element.
                 Example: <password>qwerty</password>.
                 Password could be empty.

                 If you want to specify SHA256, place it in 'password_sha256_hex' element.
                 Example: <password_sha256_hex>65e84be33532fb784c48129675f9eff3a682b27168c0ea744b2cf58ee02337c5</password_sha256_hex>
                 Restrictions of SHA256: impossibility to connect to ClickHouse using MySQL JS client (as of July 2019).

                 If you want to specify double SHA1, place it in 'password_double_sha1_hex' element.
                 Example: <password_double_sha1_hex>e395796d6546b1b65db9d665cd43f0e858dd4303</password_double_sha1_hex>

                 If you want to specify a previously defined LDAP server (see 'ldap_servers' in the main config) for authentication,
                  place its name in 'server' element inside 'ldap' element.
                 Example: <ldap><server>my_ldap_server</server></ldap>

                 If you want to authenticate the user via Kerberos (assuming Kerberos is enabled, see 'kerberos' in the main config),
                  place 'kerberos' element instead of 'password' (and similar) elements.
                 The name part of the canonical principal name of the initiator must match the user name for authentication to succeed.
                 You can also place 'realm' element inside 'kerberos' element to further restrict authentication to only those requests
                  whose initiator's realm matches it.
                 Example: <kerberos />
                 Example: <kerberos><realm>EXAMPLE.COM</realm></kerberos>

                 How to generate decent password:
                 Execute: PASSWORD=$(base64 < /dev/urandom | head -c8); echo "$PASSWORD"; echo -n "$PASSWORD" | sha256sum | tr -d '-'
                 In first line will be password and in second - corresponding SHA256.

                 How to generate double SHA1:
                 Execute: PASSWORD=$(base64 < /dev/urandom | head -c8); echo "$PASSWORD"; echo -n "$PASSWORD" | sha1sum | tr -d '-' | xxd -r -p | sha1sum | tr -d '-'
                 In first line will be password and in second - corresponding double SHA1.
            -->
            <password></password>

            <!-- List of networks with open access.

                 To open access from everywhere, specify:
                    <ip>::/0</ip>

                 To open access only from localhost, specify:
                    <ip>::1</ip>
                    <ip>127.0.0.1</ip>

                 Each element of list has one of the following forms:
                 <ip> IP-address or network mask. Examples: 213.180.204.3 or 10.0.0.1/8 or 10.0.0.1/255.255.255.0
                      2a02:6b8::3 or 2a02:6b8::3/64 or 2a02:6b8::3/ffff:ffff:ffff:ffff::.
                 <host> Hostname. Example: server01.clickhouse.com.
                      To check access, DNS query is performed, and all received addresses compared to peer address.
                 <host_regexp> Regular expression for host names. Example, ^server\d\d-\d\d-\d\.clickhouse\.com$
                      To check access, DNS PTR query is performed for peer address and then regexp is applied.
                      Then, for result of PTR query, another DNS query is performed and all received addresses compared to peer address.
                      Strongly recommended that regexp is ends with $
                 All results of DNS requests are cached till server restart.
            -->
            <networks>
                <ip>::/0</ip>
            </networks>

            <!-- Settings profile for user. -->
            <profile>default</profile>

            <!-- Quota for user. -->
            <quota>default</quota>

            <!-- User can create other users and grant rights to them. -->
            <access_management>1</access_management>

            <!-- User can manipulate named collections. -->
            <named_collection_control>1</named_collection_control>

            <!-- User permissions can be granted here -->
            <!--
            <grants>
                <query>GRANT ALL ON *.*</query>
            </grants>
            -->
        </default>

        <admin_user>   <!-- 新增 -->
            <password_sha256_hex>26747abdb94efa0490fb1a34cf8430b536146964d55bb35835cc9b6265cc6c90</password_sha256_hex>   <!-- 新增 -->
            <networks incl="networks" replace="replace">   <!-- 新增 -->
                <ip>::/0</ip>   <!-- 新增 -->
            </networks>   <!-- 新增 -->
            <profile>default</profile>   <!-- 新增 -->
            <quota>default</quota>   <!-- 新增 -->
        </admin_user>   <!-- 新增 -->
    </users>

    <!-- Quotas. -->
    <quotas>
        <!-- Name of quota. -->
        <default>
            <!-- Limits for time interval. You could specify many intervals with different limits. -->
            <interval>
                <!-- Length of interval. -->
                <duration>3600</duration>

                <!-- No limits. Just calculate resource usage for time interval. -->
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </default>
    </quotas>
</clickhouse>
```
### 新增systemd服务文件（三台机器都要执行）
```shell
cat >>  /etc/systemd/system/clickhouse-server.service << EOF
[Unit]
Description=ClickHouse Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=clickhouse
RuntimeDirectory=clickhouse-server
RuntimeDirectoryMode=0755
Group=clickhouse
ExecStart=/usr/bin/clickhouse server --config-file=/etc/clickhouse-server/config.xml
Restart=always
RestartSec=3
# 关闭所有 systemd 保护/隔离
PrivateTmp=false
PrivateDevices=false
ProtectSystem=false
ProtectHome=false
ProtectKernelTunables=false
ProtectKernelModules=false
RestrictRealtime=false
RestrictNamespaces=false
NoNewPrivileges=false
ReadWritePaths=-/ -/data -/var/log -/var/lib -/run

[Install]
WantedBy=multi-user.target
EOF
```
### 配置带 Keeper (需要到三台服务器上操作)
```shell
# 第一台节点上操作
cat > /etc/clickhouse-server/config.d/keeper.xml  << EOF
<clickhouse>
    <keeper_server>
        <tcp_port>9181</tcp_port>
        <server_id>1</server_id>
        <log_storage_path>/data/clickhouse/coordination/log</log_storage_path>
        <snapshot_storage_path>/data/clickhouse/coordination/snapshots</snapshot_storage_path>

        <coordination_settings>
            <operation_timeout_ms>10000</operation_timeout_ms>
            <session_timeout_ms>30000</session_timeout_ms>
            <raft_logs_level>warning</raft_logs_level>
        </coordination_settings>

        <raft_configuration>
            <server><id>1</id><hostname>ck-node01</hostname><port>9234</port></server>
            <server><id>2</id><hostname>ck-node02</hostname><port>9234</port></server>
            <server><id>3</id><hostname>ck-node03</hostname><port>9234</port></server>
        </raft_configuration>
    </keeper_server>

    <zookeeper>
        <node><host>ck-node01</host><port>9181</port></node>
        <node><host>ck-node02</host><port>9181</port></node>
        <node><host>ck-node03</host><port>9181</port></node>
    </zookeeper>
</clickhouse>
EOF

# 第二台节点上操作
cat > /etc/clickhouse-server/config.d/keeper.xml  << EOF
<clickhouse>
    <keeper_server>
        <tcp_port>9181</tcp_port>
        <server_id>2</server_id>
        <log_storage_path>/data/clickhouse/coordination/log</log_storage_path>
        <snapshot_storage_path>/data/clickhouse/coordination/snapshots</snapshot_storage_path>

        <coordination_settings>
            <operation_timeout_ms>10000</operation_timeout_ms>
            <session_timeout_ms>30000</session_timeout_ms>
            <raft_logs_level>warning</raft_logs_level>
        </coordination_settings>

        <raft_configuration>
            <server><id>1</id><hostname>ck-node01</hostname><port>9234</port></server>
            <server><id>2</id><hostname>ck-node02</hostname><port>9234</port></server>
            <server><id>3</id><hostname>ck-node03</hostname><port>9234</port></server>
        </raft_configuration>
    </keeper_server>

    <zookeeper>
        <node><host>ck-node01</host><port>9181</port></node>
        <node><host>ck-node02</host><port>9181</port></node>
        <node><host>ck-node03</host><port>9181</port></node>
    </zookeeper>
</clickhouse>
EOF

# 第三台节点上操作
cat > /etc/clickhouse-server/config.d/keeper.xml  << EOF
<clickhouse>
    <keeper_server>
        <tcp_port>9181</tcp_port>
        <server_id>3</server_id>
        <log_storage_path>/data/clickhouse/coordination/log</log_storage_path>
        <snapshot_storage_path>/data/clickhouse/coordination/snapshots</snapshot_storage_path>

        <coordination_settings>
            <operation_timeout_ms>10000</operation_timeout_ms>
            <session_timeout_ms>30000</session_timeout_ms>
            <raft_logs_level>warning</raft_logs_level>
        </coordination_settings>

        <raft_configuration>
            <server><id>1</id><hostname>ck-node01</hostname><port>9234</port></server>
            <server><id>2</id><hostname>ck-node02</hostname><port>9234</port></server>
            <server><id>3</id><hostname>ck-node03</hostname><port>9234</port></server>
        </raft_configuration>
    </keeper_server>

    <zookeeper>
        <node><host>ck-node01</host><port>9181</port></node>
        <node><host>ck-node02</host><port>9181</port></node>
        <node><host>ck-node03</host><port>9181</port></node>
    </zookeeper>
</clickhouse>
EOF
```
### 配置集群拓扑文件(三个节点配置一致)
```shell
cat > /etc/clickhouse-server/config.d/cluster.xml << EOF
<clickhouse>
    <!-- 集群拓扑配置 -->
    <remote_servers>
        <cluster_1S_3R>
            <shard>
                <!-- true 表示底层引擎(如 ReplicatedMergeTree)自己负责副本同步，而不是靠 Distributed 表去双写 -->
                <internal_replication>true</internal_replication>
                <weight>1</weight>

                <!-- 主副本（优先读写） -->
                <replica>
                    <host>ck-node01</host>
                    <port>9000</port>
                    <user>admin_user</user>
                    <password>13Carson#250</password>
                    <priority>3</priority>
                </replica>

                <!-- 备用副本1 -->
                <replica>
                    <host>ck-node02</host>
                    <port>9000</port>
                    <user>admin_user</user>
                    <password>13Carson#250</password>
                    <priority>2</priority>
                </replica>

                <!-- 备用副本2 -->
                <replica>
                    <host>ck-node03</host>
                    <port>9000</port>
                    <user>admin_user</user>
                    <password>13Carson#250</password>
                    <priority>1</priority>
                </replica>
            </shard>
        </cluster_1S_3R>
    </remote_servers>
</clickhouse>
EOF
```

### 配置宏文件（三台节点都要配置）
```shell
# 第一台节点配置
cat > /etc/clickhouse-server/config.d/macros.xml << EOF
<clickhouse>
    <macros>
        <cluster>cluster_1S_3R</cluster>
        <shard>1</shard>
        <replica>ck-node01</replica>
    </macros>
</clickhouse>
EOF

# 第二台节点配置
cat > /etc/clickhouse-server/config.d/macros.xml << EOF
<clickhouse>
    <macros>
        <cluster>cluster_1S_3R</cluster>
        <shard>1</shard>
        <replica>ck-node02</replica>
    </macros>
</clickhouse>
EOF

# 第三台节点配置
cat > /etc/clickhouse-server/config.d/macros.xml << EOF
<clickhouse>
    <macros>
        <cluster>cluster_1S_3R</cluster>
        <shard>1</shard>
        <replica>ck-node03</replica>
    </macros>
</clickhouse>
EOF
```

### 创建目录并给予权限（三台机器都要执行）
```shell
groupadd clickhouse
useradd -r -s /bin/false -g clickhouse clickhouse
sudo mkdir -p /var/lib/clickhouse /var/log/clickhouse-server /var/run/clickhouse-server   /data/clickhouse
sudo chown -R clickhouse:clickhouse /etc/clickhouse-server /var/lib/clickhouse /var/log/clickhouse-server /var/run/clickhouse-server /data/clickhouse
sudo chmod -R 755 /var/lib/clickhouse /var/log/clickhouse-server /var/run/clickhouse-server  /data/clickhouse
sudo chmod +x /usr/bin/clickhouse
```
### 安装客户端
```shell
# 安装 Common 依赖
sudo /opt/clickhouse/clickhouse-common-static-24.8.1.2684/install/doinst.sh

# 安装Client
sudo /opt/clickhouse/clickhouse-client-24.8.1.2684/install/doinst.sh
```


### 启动clickhouse服务
```shell
sudo systemctl enable --now clickhouse-server
sudo systemctl status clickhouse-server
```

### 验证集群状态
登录任意节点，执行：
```sql
SELECT cluster, shard_num, replica_num, host_name FROM system.clusters WHERE cluster = 'cluster_1S_3R';
```