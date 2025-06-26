#!/bin/bash
# 启动 Clash 服务


#################### 变量设置 ####################

# 项目路径（由父脚本传入）
# Server_Dir=$Server_Dir

# 获取 CPU 架构信息
if [ -z "$CPU_ARCH" ]; then
    source $Server_Dir/scripts/get_cpu_arch.sh
    ReturnStatus=$?
    echo -ne "\033[1A\033[K"    # 清除脚本最后一个 echo 输出
    if [ $ReturnStatus -ne 0 ]; then
        exit 1
    fi
fi
CpuArch=$CPU_ARCH

# 定义路径变量
Conf_Dir="$Server_Dir/conf"
Log_Dir="$Server_Dir/logs"


#################### 访问权限 ####################

# 给二进制启动程序、脚本等添加可执行权限
chmod +x $Server_Dir/bin/*
chmod +x $Server_Dir/scripts/*
chmod +x $Server_Dir/tools/subconverter/subconverter

#################### 函数定义 ####################

# 自定义action函数，实现通用action功能
success() {
  echo -en "\\033[60G[\\033[1;32m  OK  \\033[0;39m]\r"
  return 0
}

failure() {
  local rc=$?
  echo -en "\\033[60G[\\033[1;31mFAILED\\033[0;39m]\r"
  [ -x /bin/plymouth ] && /bin/plymouth --details
  return $rc
}

action() {
  local STRING rc

  STRING=$1
  echo -n "$STRING "
  shift
  "$@" && success $"$STRING" || failure $"$STRING"
  rc=$?
  echo
  return $rc
}

#################### 任务执行 ####################

# 检查系统 clash 服务是否已在运行
PID_NUM=$(ps -ef | grep [c]lash-linux- | wc -l)
if [ $PID_NUM -gt 0 ]; then
    echo -e "\n系统存在 Clash 服务，停止相关服务..."
    bash $Server_Dir/scripts/clash_server_killer.sh
fi

# 启动 clash 服务
echo -e "\n启动服务中..."
if [[ $CpuArch =~ "x86_64" || $CpuArch =~ "amd64"  ]]; then
	nohup $Server_Dir/bin/clash-linux-amd64 -d $Conf_Dir &> $Log_Dir/clash.log &
elif [[ $CpuArch =~ "aarch64" ||  $CpuArch =~ "arm64" ]]; then
	nohup $Server_Dir/bin/clash-linux-arm64 -d $Conf_Dir &> $Log_Dir/clash.log &
elif [[ $CpuArch =~ "armv7" ]]; then
	nohup $Server_Dir/bin/clash-linux-armv7 -d $Conf_Dir &> $Log_Dir/clash.log &
else
    action "检测到不支持的 CPU 架构: $CpuArch" /bin/false
    exit 1
fi
ReturnStatus=$?
if [ $ReturnStatus -ne 0 ]; then
    action "服务启动失败！" /bin/false
fi

# 等待进程启动
sleep 2

# 检查进程是否存在
PID_NUM=$(ps -ef | grep [c]lash-linux- | wc -l)
if [ $PID_NUM -eq 0 ]; then
    action "检测到相关进程未运行！检查日志文件 ./logs/clash.log" /bin/false
    exit 1
fi

# 检查日志文件中的错误
if [ -f "$Log_Dir/clash.log" ]; then
    # 检查是否有致命或错误级别的日志
    if grep -q "level=\(fatal\|error\)" "$Log_Dir/clash.log"; then
        action "检测到日志中存在错误！检查日志文件 ./logs/clash.log" /bin/false
        exit 1
    fi
else
    action "找不到文件 ./logs/clash.log" /bin/false
    exit 1
fi

action "服务启动成功！" /bin/true