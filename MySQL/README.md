# MySQL 日常运维手册
## 1、主从复制异常
### 问题
在从库执行 SHOW SLAVE STATUS\G;时 报错
```sql
mysql> SHOW SLAVE STATUS\G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 10.84.3.47
                  Master_User: sync
                  Master_Port: 3306
                Connect_Retry: 30
              Master_Log_File: mysql-bin.000095
          Read_Master_Log_Pos: 218829116
               Relay_Log_File: relay-log.000002
                Relay_Log_Pos: 50607
        Relay_Master_Log_File: mysql-bin.000095
             Slave_IO_Running: Yes
            Slave_SQL_Running: No
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: 
                   Last_Errno: 1032
                   Last_Error: Could not execute Delete_rows event on table thermal-storage-dev.QRTZ_FIRED_TRIGGERS; Can't find record in 'QRTZ_FIRED_TRIGGERS', Error_code: 1032; handler error HA_ERR_KEY_NOT_FOUND; the event's master log mysql-bin.000095, end_log_pos 217748060
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 217746265
              Relay_Log_Space: 1134026
              Until_Condition: None
               Until_Log_File: 
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File: 
           Master_SSL_CA_Path: 
              Master_SSL_Cert: 
            Master_SSL_Cipher: 
               Master_SSL_Key: 
        Seconds_Behind_Master: NULL
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 1032
               Last_SQL_Error: Could not execute Delete_rows event on table thermal-storage-dev.QRTZ_FIRED_TRIGGERS; Can't find record in 'QRTZ_FIRED_TRIGGERS', Error_code: 1032; handler error HA_ERR_KEY_NOT_FOUND; the event's master log mysql-bin.000095, end_log_pos 217748060
  Replicate_Ignore_Server_Ids: 
             Master_Server_Id: 1
                  Master_UUID: b977649e-b5a1-11ee-9ccf-0242ac1b0003
             Master_Info_File: /var/lib/mysql/master.info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: 
           Master_Retry_Count: 86400
                  Master_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 241220 11:29:25
               Master_SSL_Crl: 
           Master_SSL_Crlpath: 
           Retrieved_Gtid_Set: 
            Executed_Gtid_Set: 
                Auto_Position: 0
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Master_TLS_Version: 
1 row in set (0.00 sec)
```
### 解决办法：（不管是主从的什么错，都能解决）
1、在主库 dump 数据库文件
```shell
mysqldump -u root -pSeca@2024... -h 10.84.3.47 --all-databases --master-data=2 --single-transaction --quick --lock-all-tables=false > full_backup.sql
```
2、在从库停掉slave线程
```sql
STOP SLAVE;
RESET SLAVE;
```

3、将从库"information_schema" "mysql" "performance_schema" "sys" 以外的所有库删除
```shell
#!/bin/bash

MYSQL_USER="root"
MYSQL_PASSWORD="Seca@2024..."
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="3306"

SYSTEM_DATABASES=("information_schema" "mysql" "performance_schema" "sys")

mysql_execute() {
  mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "$1"
}

DATABASES=$(mysql_execute "SHOW DATABASES;" | grep -v "Database" | grep -v "^$" | tr -d "| ")

for DB in $DATABASES; do
  is_system_db=false
  for SYS_DB in "${SYSTEM_DATABASES[@]}"; do
    if [[ "$DB" == "$SYS_DB" ]]; then
      is_system_db=true
      break
    fi
  done

  if ! $is_system_db; then
    echo "正在删除数据库: $DB"
    mysql_execute "DROP DATABASE IF EXISTS \`$DB\`;"
    if [[ $? -eq 0 ]]; then
      echo "数据库 $DB 删除成功。"
    else
      echo "删除数据库 $DB 失败！"
    fi
  fi
done

echo "操作完成。"
```

4、将刚才在主库dump的数据，导入至从库
```shell
mysql -u root -pSeca@2024... -h 10.84.3.46  < ./full_backup.sql
```

5、查看备份文件中最后记录的MASTER_LOG_POS点和binlog 文件名
```shell
root@ceshi7server:~/test# grep "CHANGE MASTER TO MASTER_LOG_FILE" full_backup.sql
-- CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.000095', MASTER_LOG_POS=255838294;
```

6、重新配置 从服务器从主服务器的二进制日志文件mysql-bin.000095的255838294位置开始复制数据。
```shell
change master to master_host='10.84.3.47',master_user='sync',master_password='Sec@2024...',master_port=3306,master_log_file='mysql-bin.000095', master_log_pos=255838294,master_connect_retry=30;
```
7、打开slave 进程
```shell
START SLAVE;
```

8、验证是否成功
```sql
mysql> SHOW SLAVE STATUS\G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: 10.84.3.47
                  Master_User: sync
                  Master_Port: 3306
                Connect_Retry: 30
              Master_Log_File: mysql-bin.000095
          Read_Master_Log_Pos: 367276799
               Relay_Log_File: relay-log.000002
                Relay_Log_Pos: 111438825
        Relay_Master_Log_File: mysql-bin.000095
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: 
                   Last_Errno: 0
                   Last_Error: 
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 367276799
              Relay_Log_Space: 111439026
              Until_Condition: None
               Until_Log_File: 
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File: 
           Master_SSL_CA_Path: 
              Master_SSL_Cert: 
            Master_SSL_Cipher: 
               Master_SSL_Key: 
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 0
               Last_SQL_Error: 
  Replicate_Ignore_Server_Ids: 
             Master_Server_Id: 1
                  Master_UUID: b977649e-b5a1-11ee-9ccf-0242ac1b0003
             Master_Info_File: /var/lib/mysql/master.info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
           Master_Retry_Count: 86400
                  Master_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 
               Master_SSL_Crl: 
           Master_SSL_Crlpath: 
           Retrieved_Gtid_Set: 
            Executed_Gtid_Set: 
                Auto_Position: 0
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Master_TLS_Version: 
1 row in set (0.00 sec)
```


