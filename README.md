[TOC]

> 项目介绍、免责声明、使用须知参考[原仓库](https://github.com/Elegycloud/clash-for-linux-backup)。
>
> 本仓库及本分支内容仅供本人 Shell 编程的入门学习使用，不具备参考意义和使用价值...

---

```bash
git clone https://github.com/toulzx/clash-for-linux-backup.git clash-for-linux
cd clash-for-linux
git checkout dev
```

## 启动服务

编辑 `.env` 文件，填写订阅链接 `CLASH_URL`、`CLASH_SECRET`。（secret 值为空时，脚本将自动生成随机字符串）

获取/更新订阅链接（配置文件）：
```bash
sudo bash start.sh
```

proxy 开关随终端自启：
```bash
echo "source /etc/profile.d/clash.sh" >> ~/.bashrc
source ~/.bashrc
```

启动/关闭 proxy：
```bash
proxy_on
proxy_off
```

Ping 不通是正常的，可测试：
```
git clone https://github.com/AasishPokhrel/shit.git
# and
wget https://huggingface.co/deepseek-ai/DeepSeek-R1/resolve/main/README.md
```

## 重启服务

此操作不会获取/更新订阅链接（配置文件）。只会同步本地 `conf/config.yaml` 配置并重启服务。

```bash
sudo bash restart.sh
```

## 停止服务

```bash
sudo bash shutdown.sh
proxy_off
```


# 排查

检查服务端口（789* 是目前默认的服务端口）：

```
$ netstat -tln | grep -E '9090|789.'
tcp        0      0 127.0.0.1:9090          0.0.0.0:*               LISTEN     
tcp6       0      0 :::7890                 :::*                    LISTEN     
tcp6       0      0 :::7891                 :::*                    LISTEN     
tcp6       0      0 :::7892                 :::*                    LISTEN
```

检查环境变量：

```
$ env | grep -E 'http_proxy|https_proxy'
http_proxy=http://127.0.0.1:7890
https_proxy=http://127.0.0.1:7890
```

检查相关服务是否存在：
```
$ ps -ef | grep [c]lash-linux- | wc -l
1
```

有些应用有自己的 proxy 管理：
```bash
# Ubuntu 图形界面网络有个设置需要改

# git 设置 proxy 和系统变量保持一致
git config --global http.useEnvironmentVariables true	# 只管 http，sock5 还是需要单独配置
git config --global --get http.proxy
git config --global --get https.proxy
```

For more, refer to issues.

# 管理

## Dashboard

支持选择节点、修改流量端口等。

此 Clash Dashboard 使用的是[yacd](https://github.com/haishanh/yacd)项目，详细使用方法请移步该仓库。

1. 访问 Dashboard：
    1. 如果在 Linux 本机操作，且支持图形化界面，使用浏览器访问 `http://127.0.0.1:9090/ui` 即可。
    2. 如果是远程连接，可以考虑端口转发 9090，仍然是本机浏览器访问 `http://127.0.0.1:9090/ui` 即可。
    3. `./temp/template_config.yaml` 默认设置公网转发 `0.0.0.0:9090`，如果设备支持公网访问，此时可以公网 IP 访问 `http://[IP]:9090/ui`

2. 登录 Dashboard：在 `API Base URL` 填写上述访问链接（如 `http://localhost:9090`），在 `Secret` 一栏中输入启动成功后输出的 Secret。


## 终端界面选择节点

部分用户无法通过浏览器使用 Clash Dashboard 进行节点选择、代理模式修改等操作，为了方便用户可以在Linux终端进行操作，下面提供了一个功能简单的脚本以便用户可以临时通过终端界面进行配置。

脚本存放位置：`scripts/clash_proxy-selector.sh`
