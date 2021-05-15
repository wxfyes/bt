#!/bin/bash

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}

if [[ -f /etc/redhat-release ]]; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
    systemPackage="apt-get"
    systempwd="/lib/systemd/system/"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
    systemPackage="yum"
    systempwd="/usr/lib/systemd/system/"
fi

$systemPackage -y install wget curl

vps_superspeed(){
	bash <(curl -Lso- https://git.io/superspeed)
}

vps_zbench(){
	wget -N --no-check-certificate https://raw.githubusercontent.com/FunctionClub/ZBench/master/ZBench-CN.sh && bash ZBench-CN.sh
}

vps_testrace(){
	wget -O huichong.sh https://raw.githubusercontent.com/wxfyes/bt/master/huichong.sh && bash huichong.sh
}

vps_LemonBenchIntl(){
    curl -fsL https://ilemonra.in/LemonBenchIntl | bash -s fast
}

vps_Cn2GIA(){
    wget -O huichong.sh https://raw.githubusercontent.com/wxfyes/bt/master/huichong.sh && bash huichong.sh
}

vps_make-a(){
    wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
}

vps_wulabing1(){
    wget -N --no-check-certificate -q -O install.sh "https://raw.githubusercontent.com/wulabing/V2Ray_ws-tls_bash_onekey/master/install.sh" && chmod +x install.sh && bash install.sh
}

vps_wulabing2(){
    wget -N --no-check-certificate -q -O install.sh "https://raw.githubusercontent.com/wulabing/V2Ray_ws-tls_bash_onekey/dev/install.sh" && chmod +x install.sh && bash install.sh
}

vps_bt1(){
   yum install -y wget && wget -O install.sh http://download.bt.cn/install/install_6.0.sh && sh install.sh
}

vps_bt2(){
   wget -O install.sh http://download.bt.cn/install/install-ubuntu_6.0.sh && bash install.sh
}

vps_bt3(){
   wget -O install.sh http://download.bt.cn/install/install-ubuntu_6.0.sh && sudo bash install.sh
}

vps_bt4(){
   wget -O /home/update7.sh http://www.hostcli.com/install/update7.sh && bash /home/update7.sh
}
vps_bbr1(){
   wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}

vps_bbr2(){
  wget -N --no-check-certificate "https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh && ./tcp.sh
}
vps_nf(){
  yum install -y curl 2> /dev/null || apt install -y curl && bash <(curl -sSL https://raw.githubusercontent.com/wxfyes/nf/main/nfcs.sh)
}
vps_v2-ui(){
  bash <(curl -Ls https://raw.githubusercontent.com/wxfyes/nf/main/v2-ui.sh)
}
start_menu(){
    clear
	green "=========================================================="
         yellow " 本脚本支持：CentOS7+ / Debian9+ / Ubuntu16.04+"
	 yellow " 网站：https://wxf2088.xyz "
	 yellow " YouTube频道：王晓峰"
	 yellow " TG频道：https://t.me/buluoge "
     yellow " 此脚本源于网络，仅仅只是汇聚脚本功能，方便大家使用而已！"
	green "=========================================================="
      red " 脚本测速会大量消耗 VPS 流量，请悉知！"
    green "==========VPS测速========================================="
     blue " 1. VPS 三网纯测速    （各取部分节点 - 中文显示）"
     blue " 2. VPS 综合性能测试  （包含测速 - 英文显示）"
	 blue " 3. VPS 回程路由     （四网测试 - 英文显示）"
	 blue " 4. VPS 快速全方位测速（包含性能、回程、速度 - 英文显示）"
	 blue " 5. VPS 回程线路测试 （假CN2线路，脚本无法测试）"
	green "==========科学上网一键脚本==============================="
	 blue " 6. xray8合1一键安装脚本 "
	 blue " 7. wulabing-v2ray一键安装脚本 "
	 blue " 8. wulabing-xray一键安装脚本 "
	 blue " 9. v2-ui面板一键安装 "
	green "==========宝塔面板官方脚本==============================="
	 blue " 10. centos系统一键安装 "
	 blue " 11. debian系统一键安装 "
	 blue " 12. ubuntu系统一键安装 "
	green "=======宝塔面板破解，需先安装官方版再运行此脚本========="
	 blue " 13. 宝塔破解企业版 一键破解 "
	green "===================BBR加速=============================="
	 blue " 14. BBR一键加速（稳定版）"
	 blue " 15. BBR一键加速（最新版）"
	green "===================解锁Netflix检测======================"
	 blue " 16. 启动Netflix检测脚本 "
        yellow " 0. 退出脚本 "
    echo
    read -p "请输入数字:" num
    case "$num" in
    	1)
		vps_superspeed
		;;
		2)
		vps_zbench
		;;
		3)
		vps_testrace
		;;
		4)
		vps_LemonBenchIntl
		;;
		5)
		vps_Cn2GIA
		;;
		6)
		vps_make-a
		;;
		7)
		vps_wulabing1
		;;
		8)
		vps_wulabing2
		;;
		9)
		vps_v2-ui
		;;
		10)
		vps_bt1
		;;
		11)
		vps_bt2
		;;
		12)
		vps_bt3
		;;
		13)
		vps_bt4
		;;
		14)
		vps_bbr1
		;;
		15)
		vps_bbr2
		;;
		16)
		vps_nf
		;;
		0)
		exit 0
		;;
		*)
	clear
	echo "请输入正确数字"
	sleep 2s
	start_menu
	;;
    esac
}

start_menu
