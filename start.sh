#!/bin/bash

# 加载系统函数库(Only for RHEL Linux)
# [ -f /etc/init.d/functions ] && source /etc/init.d/functions

#################### 变量设置 ####################

# 获取脚本工作目录绝对路径
export Server_Dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# 获取 CPU 架构信息
if [ -z "$CPU_ARCH" ]; then
    source $Server_Dir/scripts/get_cpu_arch.sh
    ReturnStatus=$?
    if [ $ReturnStatus -ne 0 ]; then
        exit 1
    fi
fi
CpuArch=$CPU_ARCH

# 加载.env变量文件
source $Server_Dir/.env

Conf_Dir="$Server_Dir/conf"
Temp_Dir="$Server_Dir/temp"
Log_Dir="$Server_Dir/logs"

# 将 CLASH_URL 变量的值赋给 URL 变量，并检查 CLASH_URL 是否为空
URL=${CLASH_URL:?Error: CLASH_URL variable is not set or empty}

# 获取 CLASH_SECRET 值，如果不存在则生成一个随机数
Secret=${CLASH_SECRET:-$(openssl rand -hex 32)}

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

# 判断命令是否正常执行 函数
if_success() {
	local ReturnStatus=$3
	if [ $ReturnStatus -eq 0 ]; then
		action "$1" /bin/true
	else
		action "$2" /bin/false
		exit 1
	fi
}



#################### 任务执行 ####################

## 临时取消环境变量
unset http_proxy
unset https_proxy
unset no_proxy
unset HTTP_PROXY
unset HTTPS_PROXY
unset NO_PROXY

# 预置多个 User-Agent headers 供尝试
Headers=(
    "User-Agent: clash"
    "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    "User-Agent: ClashX/1.118.0 (com.west2online.ClashX; build:1.118.0; macOS 14.0.0) Alamofire/5.8.1"
)

## Clash 订阅地址检测及配置文件下载
# 检查url是否有效
echo -e '\n正在检测订阅地址...'
Text1="Clash订阅地址可访问！"
Text2="Clash订阅地址不可访问！"

# 尝试不同的 User-Agent 来检测订阅地址可访问性
ReturnStatus=1
WorkingHeader=""

for Header in "${Headers[@]}"; do
    
    curl -o /dev/null -L -k -sS --retry 5 -m 10 --connect-timeout 10 \
         -H "$Header" \
         -w "%{http_code}" $URL | grep -E '^[23][0-9]{2}$' &>/dev/null
    ReturnStatus=$?
    
    if [ $ReturnStatus -eq 0 ]; then
        WorkingHeader="$Header"
        echo $WorkingHeader
        break
    fi
done

if [ -z "$WorkingHeader" ]; then
    WorkingHeader="${Headers[0]}"
    echo "预置的 User-Agent 均不可用。"
fi

if_success $Text1 $Text2 $ReturnStatus

# 拉取更新config.yml文件
echo -e '\n正在下载Clash配置文件...'
Text3="配置文件config.yaml下载成功！"
Text4="配置文件config.yaml下载失败，退出启动！"

# 使用在检测时找到的有效 Header 进行下载
curl -L -k -sS --retry 5 -m 10 \
     -H "$WorkingHeader" \
     -o $Temp_Dir/clash.yaml $URL
ReturnStatus=$?
if [ $ReturnStatus -ne 0 ]; then
	# 如果使用curl下载失败，尝试使用wget进行下载
	for i in {1..10}
	do
        wget -q --no-check-certificate \
             --header "$WorkingHeader" \
             -O $Temp_Dir/clash.yaml $URL
		ReturnStatus=$?
		if [ $ReturnStatus -eq 0 ]; then
			break
		else
			continue
		fi
	done
fi
if_success $Text3 $Text4 $ReturnStatus

# 重命名clash配置文件
\cp -a $Temp_Dir/clash.yaml $Temp_Dir/clash_config.yaml


## 判断订阅内容是否符合 clash 配置文件标准，尝试转换（当前仅支持部分 CPU 架构的 clas 配置文件检测和转换）
if [[ ($CpuArch =~ "x86_64" || $CpuArch =~ "amd64") || ($CpuArch =~ "arm64" || $CpuArch =~ "aarch64")  ]]; then
	bash $Server_Dir/scripts/clash_profile_conversion.sh
	ReturnStatus=$?
	sleep 2
fi



## Clash 配置文件重新格式化及配置
# 取出代理相关配置 
#sed -n '/^proxies:/,$p' $Temp_Dir/clash.yaml > $Temp_Dir/proxy.txt
sed -n '/^proxies:/,$p' $Temp_Dir/clash_config.yaml |\
sed -e '/^port:/d'\
    -e '/^socks-port:/d'\
    -e '/^redir-port:/d'\
    -e '/^allow-lan"/d'\
    -e '/^mode:/d'\
    -e '/^log-level:/d'\
    -e '/^external-controller:/d'\
    -e '/^secret:/d' > $Temp_Dir/proxy.txt

# 合并形成新的config.yaml
cat $Temp_Dir/templete_config.yaml > $Temp_Dir/config.yaml
cat $Temp_Dir/proxy.txt >> $Temp_Dir/config.yaml
\cp $Temp_Dir/config.yaml $Conf_Dir/

# Configure Clash Dashboard
Work_Dir=$(cd $(dirname $0); pwd)
Dashboard_Dir="${Work_Dir}/dashboard/public"
sed -ri "s@^# external-ui:.*@external-ui: ${Dashboard_Dir}@g" $Conf_Dir/config.yaml
sed -r -i '/^secret: /s@(secret: ).*@\1'${Secret}'@g' $Conf_Dir/config.yaml

# 启动 clash 服务
bash $Server_Dir/scripts/clash_server_start.sh

# Output Dashboard access address and Secret
echo ''
echo -e "Clash Dashboard 访问地址: http://<ip>:9090/ui"
echo -e "Secret: ${Secret}"
echo ''

# 添加环境变量(root权限)
cat>/etc/profile.d/clash.sh<<EOF
# 开启系统代理
proxy_on() {
	export http_proxy=http://127.0.0.1:7890
	export https_proxy=http://127.0.0.1:7890
	export no_proxy=127.0.0.1,localhost
    export HTTP_PROXY=http://127.0.0.1:7890
    export HTTPS_PROXY=http://127.0.0.1:7890
 	export NO_PROXY=127.0.0.1,localhost
	echo -e "\033[32m[√] 已开启代理\033[0m"
}

# 关闭系统代理
proxy_off(){
	unset http_proxy
	unset https_proxy
	unset no_proxy
  	unset HTTP_PROXY
	unset HTTPS_PROXY
	unset NO_PROXY
	echo -e "\033[31m[×] 已关闭代理\033[0m"
}
EOF
echo -e "     く__,.ヘヽ.        /  ,ー､ 〉"
echo -e "           ＼ ', !-─‐-i  /  /´"
echo -e "          ／｀ｰ'       L/／｀ヽ､"
echo -e "         /   ／,   /|   ,   ,       ',"
echo -e "        ｲ   / /-‐/  ｉ  L_ ﾊ ヽ!   i"
echo -e "        ﾚ ﾍ 7ｲ｀ﾄ   ﾚ'ｧ-ﾄ､!ハ|   |"
echo -e "          !,/7 '0'     ´0iソ|    |"
echo -e "          |.从     _     ,,,, / |./    |"
echo -e "          ﾚ'| i＞.､,,__  _,.イ /   .i   |"
echo -e "           ﾚ'| | / k_７_/ﾚ'ヽ,  ﾊ.  |"
echo -e "             | |/i 〈|/   i  ,.ﾍ |  i  |"
echo -e "            .|/ /  ｉ：    ﾍ!    ＼  |"
echo -e "             kヽ>､ﾊ    _,.ﾍ､    /､!"
echo -e "             !'〈//｀Ｔ´', ＼ ｀'7'ｰr'"
echo -e "             ﾚ'ヽL__|___i,___,ンﾚ|ノ"
echo -e "                  ﾄ-,/  |___./"
echo -e "                  'ｰ'    !_,.:"
echo -e "本项目完全免费，若你是收费买的，恭喜您，您被骗了！"
echo -e "项目地址：https://github.com/Elegycloud/clash-for-linux-backup"
echo -e "项目随时会寄，且行且珍惜！"
echo -e "请执行以下命令加载环境变量: source /etc/profile.d/clash.sh\n"
echo -e "请执行以下命令开启系统代理: proxy_on\n"
echo -e "若要临时关闭系统代理，请执行: proxy_off\n"
