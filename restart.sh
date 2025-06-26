#!/bin/bash

# 获取脚本工作目录绝对路径
export Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# 给脚本添加可执行权限
chmod +x $Server_Dir/scripts/*

# 关闭 clash 相关服务
bash $Server_Dir/scripts/clash_server_killer.sh

# 重新启动 clash 相关服务
bash $Server_Dir/scripts/clash_server_start.sh
