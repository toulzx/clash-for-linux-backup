#!/bin/bash

# 获取脚本工作目录绝对路径
export Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# 关闭 clash 相关服务
bash $Server_Dir/scripts/clash_server_killer.sh

# 清除环境变量
> /etc/profile.d/clash.sh
echo "/etc/profile.d/clash.sh 中环境变量配置已清除。"
echo "请手动执行\`proxy_off\`以清除本会话的环境变量！"
