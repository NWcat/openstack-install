#!/bin/bash


read -p "输入controller节点的管理ip:" controller_ip
read -p "输入controller节点的主机名:" controller_host
read -p "输入compute节点的管理ip:" compute_ip
read -p "输入compute节点的主机名:" compute_host

rm -f /etc/yum.repos.d/*
centos_repo=`curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo`
epel_repo=`curl -o /etc/yum.repos.d/epel.repo https://mirrors.aliyun.com/repo/epel-7.repo`
echo "$centos_repo"
echo "$epel_repo"
cat > /etc/yum.repos.d/openstack.repo << EOF
[openstack]
name=openstack
baseurl=https://mirrors.aliyun.com/centos/7/cloud/x86_64/openstack-train/
gpgcheck=0
enabled=1
EOF
cat >> /etc/hosts << EOF
$controller_ip $controller_host
$compute_ip $compute_host
EOF
yum clean all
yum list
yum -y update
yum -y install openstack-utils openstack-selinux python-openstackclient
yum upgrade

