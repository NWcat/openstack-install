#!/bin/bash
clear
echo "[1] 安装controller节点" 
echo "[2] 安装compute节点"
echo "[3] 单节点部署"
echo "运行本脚本前，自行配置好主机名和IP地址"
read -p  " " next
  if [ $next = "1" ]; then
clear
    echo "[1] 安装keystone" 
    echo "[2] 安装glance" 
    echo "[3] 安装placement" 
    echo "[4] 安装nova" 
    echo "[5] 安装neutron" 
    echo "[6] 安装horizon"
    echo "[7] 安装cinder" 
    echo "[8] 一键安装全部" 
    echo "[9] 安装依赖环境" 
    read -p "请输入1~9：" choice
    case $choice in
     1 )
       echo "安装keystone"
       chmod +x ./script/controller/keystone.sh
       ./script/controller/keystone.sh
       ;;
     2 )
       echo "安装glance"
       chmod +x ./script/controller/glance.sh
       ./script/controller/glance.sh
       ;;
     3 )
       echo "安装placement"
       chmod +x ./script/controller/placement.sh
       ./script/controller/placement.sh
       ;; 
     4 )
       echo "安装nova" 
       chmod +x ./script/controller/nova.sh
       ./script/controller/nova.sh
       ;;
     5 )
       echo "安装neutron" 
       chmod +x ./script/controller/neutron.sh
       chmod +x ./script/controller/neutron_ovs.sh
       echo "[1] 安装大二层网络(linuxbrdge)" 
       echo "[2] 安装OVS网络(openvswitch)"
       read -p  " " neux
       case $neux in
        1 )
          echo "安装大二层网络(linuxbrdge)"
	  ./script/controller/neutron.sh
          ;;
	2 )
          echo "安装OVS网络(openvswitch)"
	  ./script/controller/neutron_ovs.sh
          ;;
	* )
          echo "请输入正确选项"
          ;;
       esac
       ;;
     6 )
       echo "安装horizon"
       chmod +x ./script/controller/horizon.sh
       ./script/controller/horizon.sh
       ;;
     7 )
       echo "安装cinder"
       chmod +x ./script/controller/cinder.sh
       ./script/controller/cinder.sh
       ;;
     8 )
       echo "一键安装全部"
       chmod +x ./base.sh
       chmod +x ./script/controller/depend.sh
       ./base.sh
       ./script/controller/depend.sh 
       chmod +x ./script/controller/keystone.sh
       ./script/controller/keystone.sh
       chmod +x ./script/controller/glance.sh
       ./script/controller/glance.sh
       chmod +x ./script/controller/placement.sh
       ./script/controller/placement.sh
       chmod +x ./script/controller/nova.sh
       ./script/controller/nova.sh
       chmod +x ./script/controller/neutron.sh
       ./script/controller/nova.sh
       ./script/controller/neutron.sh
       chmod +x ./script/controller/horizon.sh
       ./script/controller/horizon.sh
       chmod +x ./script/controller/cinder.sh
       ./script/controller/cinder.sh
       ;;
      9 )
       echo "安装依赖环境"
       chmod +x ./base.sh
       chmod +x ./script/controller/depend.sh
       ./base.sh
       ./script/controller/depend.sh
       ;; 
     * )
       echo "请输入正确选项"
        ;;
	esac
elif [ $next = "2" ]; then
clear
    echo "[1] 安装依赖环境"
    echo "[2] 安装nova" 
    echo "[3] 安装neutron"
    echo "[4] 安装cinder" 
    echo "[5] 一键安装全部"
    read -p "请输入1~5：" choice
    case $choice in
     1 )
       echo "安装依赖环境"
       chmod +x ./base.sh
       ./base.sh
       chmod +x ./script/compute/depend.sh
       ./script/compute/depend.sh
       ;;
     2 )
       echo "安装nova"
       chmod +x ./script/compute/nova.sh
       ./script/compute/nova.sh
       ;;
     3 )
       echo "安装neutron"
       chmod +x ./script/compute/neutron.sh
       chmod +x ./script/compute/neutron_ovs.sh
       echo "[1] 安装大二层网络(linuxbrdge)" 
       echo "[2] 安装OVS网络(openvswitch)"
       read -p  " " neux
       case $neux in
        1 )
          echo "安装大二层网络(linuxbrdge)"
	  ./script/compute/neutron.sh
          ;;
	2 )
          echo "安装OVS网络(openvswitch)"
	  ./script/compute/neutron_ovs.sh
          ;;
	* )
          echo "请输入正确选项"
          ;;
       esac
       ;;
     4 )
       echo "安装cinder"
       chmod +x ./script/compute/cinder.sh
       ./script/compute/cinder.sh
       ;;
     5 )
       echo "一键安装全部" 
       chmod +x ./base.sh
       ./base.sh
       chmod +x ./script/compute/depend.sh
       ./script/compute/depend.sh
       chmod +x ./script/compute/nova.sh
       ./script/compute/nova.sh
       chmod +x ./script/compute/neutron.sh
       ./script/compute/neutron.sh
       chmod +x ./script/compute/cinder.sh
       ./script/compute/cinder.sh
       ;;
     esac
elif [ $next = "3" ]; then
  echo "单节点部署"
  souce openrc.sh
  source ./script/AIO/AIO.sh 
fi
   

