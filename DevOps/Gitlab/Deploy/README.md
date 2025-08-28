# 食用方法
## 克隆项目
```shell
git clone https://github.com/shacklescn/Work-Notes.git
```
## 进入部署目录
```shell
cd Work-Notes/Gitlab/Deploy
```
## 下载compose
```shell
sudo curl -L "https://github.com/docker/compose/releases/download/v2.39.2/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose
```
## 启动服务
```shell
docker-compose -p gitlab up -d
```
## 验证服务状态
```shell
docker-compose -p gitlab ps -a
```

## 访问gitlab服务
浏览器访问 ```http://<gitlab IP>:880```
用户名: ```root```

密码：
```shell
root@devops:~# docker exec -it gitlab  cat /etc/gitlab/initial_root_password | grep "^Password"
Password: h8GDodXZOS9STTv0d7BCwm5o8Wy6KXRvydFPrr++jAQ=
```

