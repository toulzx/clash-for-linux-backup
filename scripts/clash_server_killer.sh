#!/bin/bash

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

# 函数，判断命令是否正常执行
if_success() {
  local ReturnStatus=$3
  if [ $ReturnStatus -eq 0 ]; then
          action "$1" /bin/true
  else
          action "$2" /bin/false
          exit 1
  fi
}

# 关闭 clash 相关服务
Text1="服务关闭成功！"
Text2="服务关闭失败！"

# 查询并关闭相关程序进程： ./bin/clash-linux-*
PID_NUM=`ps -ef | grep [c]lash-linux- | wc -l`
PID=`ps -ef | grep [c]lash-linux- | awk '{print $2}'`
ReturnStatus=0
if [ $PID_NUM -ne 0 ]; then
  kill -9 $PID
  ReturnStatus=$?
  # ps -ef | grep [c]lash-linux-a | awk '{print $2}' | xargs kill -9
fi
if_success $Text1 $Text2 $ReturnStatus
