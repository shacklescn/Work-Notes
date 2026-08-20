# EMR 中常用 YARN 与 HDFS 命令解析
在阿里云 EMR（Elastic MapReduce）或 AWS EMR 等托管 Hadoop 集群中，运维和开发人员经常需要监控资源、管理存储空间和清理临时数据。本文档详细说明四个常用命令的作用、输出解读及在 EMR 环境中的典型应用场景。
## yarn top
### 作用
实时监控 YARN 集群中正在运行和等待的应用程序资源使用情况（类似 Linux 的 top 命令）。以交互式界面动态展示每个应用占用的 CPU、内存、队列、用户等信息，帮助快速定位资源消耗大户。
### 命令格式
```shell
yarn top
```
### 输出解读
- ApplicationId：YARN 应用 ID
- User：提交作业的用户
- Queue：所属队列
- State：应用状态（RUNNING/ACCEPTED/FINISHED等）
- CPU：使用的虚拟 CPU 核数
- MEM：使用的内存（MB）
- VCores：申请的虚拟核数
- Memory：申请的内存
- %CPU：CPU 使用率（基于系统采样）
- %MEM：内存使用率
> 可按 P（按 CPU 排序）、M（按内存排序）等快捷键交互。yarn只能在master节点执行

## hdfs dfs -du -h /tmp/
### 作用
统计 HDFS 指定目录（此处为 /tmp/）下每个文件和子目录的磁盘占用大小，并以人类可读格式（KB/MB/GB）显示。-du 是 “disk usage” 的缩写，-h 表示人性化显示。
### 命令格式
```shell
hdfs dfs -du -h /tmp/
```
### 输出示例
```shell
1.2 G  /tmp/hive
456 M  /tmp/spark-events
2.3 M  /tmp/user1
0      /tmp/empty
```
- 第一列：实际占用的物理空间（考虑副本因子，默认显示总副本大小）
- 第二列：目录/文件路径
## hdfs dfsadmin --report
### 作用
报告 HDFS 集群的整体状态，包括总容量、已用空间、剩余空间、DataNode 数量、缺失块、副本数等关键健康指标。这是运维人员最常用的 HDFS 健康检查命令。
### 命令格式
```shell
hdfs dfsadmin --report
```
### 输出解读
- Configured Capacity：总配置存储容量
- Present Capacity：可用存储容量（扣除保留空间）
- DFS Remaining：剩余可用空间
- DFS Used：已使用空间
- DFS Used%：使用百分比
- Under-replicated blocks：副本数不足的块数（需关注）
- Blocks with corrupt replicas：损坏副本数
- Missing blocks：缺失块数（严重问题）
- DataNodes available：活着的 DataNode 数量
- DataNodes total：总 DataNode 数量

## hdfs dfs -rm -r -skipTrash hdfs:///tmp/xxxxxxx
### 作用
强制删除 HDFS 上的指定目录（此处为 /tmp/xxxxxxx）及其所有子内容，并跳过回收站，即删除后不可恢复，空间立即释放。参数说明：
- -r：递归删除（用于目录）
- -skipTrash：跳过用户回收站（.Trash），直接物理删除，释放空间。
### 命令格式
```shell
hdfs dfs -rm -r -skipTrash hdfs:///tmp/xxxxxxx
```
> 危险操作：删除后无法恢复，务必确认路径正确且数据已备份或不再需要。
> 若没有 -skipTrash，文件会先移到 /user/用户名/.Trash，可保留一段时间（由 fs.trash.interval 控制），但空间不会立即释放。

# 命令组合使用建议（EMR 运维流程）
## 查看整体健康状况
`hdfs dfsadmin --report` → 确认无 missing/corrupt 块，剩余空间充足。

## 定位大文件/目录
`hdfs dfs -du -h /tmp/ | sort -hr` → 按大小排序，找出最占空间的子目录。

## 检查资源占用
`yarn top` → 确认是否有作业异常消耗内存/CPU，可能产生大量临时数据。

## 安全清理
确认待删路径无误后，执行 `hdfs dfs -rm -r -skipTrash hdfs:///tmp/xxxxxxx`
执行后再运行 `hdfs dfsadmin --report` 确认空间已释放。
