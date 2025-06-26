#!/bin/bash


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

echo -e '\n判断订阅内容是否符合clash配置文件标准...'

# 加载clash配置文件内容
raw_content=$(cat ${Server_Dir}/temp/clash.yaml)

# 判断订阅内容是否符合clash配置文件标准
#if echo "$raw_content" | jq 'has("proxies") and has("proxy-groups") and has("rules")' 2>/dev/null; then
if echo "$raw_content" | awk '/^proxies:/{p=1} /^proxy-groups:/{g=1} /^rules:/{r=1} p&&g&&r{exit} END{if(p&&g&&r) exit 0; else exit 1}'; then
  action "订阅内容符合 clash 标准" /bin/true
  echo "$raw_content" > ${Server_Dir}/temp/clash_config.yaml
  exit 0
else
  # 判断订阅内容是否为base64编码
  if echo "$raw_content" | base64 -d &>/dev/null; then
    # 订阅内容为base64编码，进行解码
    decoded_content=$(echo "$raw_content" | base64 -d)

    # 判断解码后的内容是否符合clash配置文件标准
    #if echo "$decoded_content" | jq 'has("proxies") and has("proxy-groups") and has("rules")' 2>/dev/null; then
    if echo "$decoded_content" | awk '/^proxies:/{p=1} /^proxy-groups:/{g=1} /^rules:/{r=1} p&&g&&r{exit} END{if(p&&g&&r) exit 0; else exit 1}'; then
      action "解码后的内容符合 clash 标准" /bin/true
      echo "$decoded_content" > ${Server_Dir}/temp/clash_config.yaml
      exit 0
    else
      echo "解码后的内容不符合clash标准，尝试将其转换为标准格式"

      if [[ $CpuArch =~ "x86_64" || $CpuArch =~ "amd64" ]]; then
        ${Server_Dir}/tools/subconverter/subconverter -g &>> ${Server_Dir}/logs/subconverter.log
      elif [[ $CpuArch =~ "arm64" ]]; then
        ${Server_Dir}/tools/subconverter/subconverter_arm64 -g &>> ${Server_Dir}/logs/subconverter.log
      fi
      
      converted_file=${Server_Dir}/temp/clash_config.yaml
      # 判断转换后的内容是否符合clash配置文件标准
      if awk '/^proxies:/{p=1} /^proxy-groups:/{g=1} /^rules:/{r=1} p&&g&&r{exit} END{if(p&&g&&r) exit 0; else exit 1}' $converted_file; then
        action "配置文件已成功转换成 clash 标准格式" /bin/true
        exit 0
      else
        action "配置文件转换标准格式失败" /bin/false
	    exit 1
      fi
    fi
  else
    action "订阅内容不符合clash标准，无法转换为配置文件" /bin/false
    exit 1
  fi
fi
