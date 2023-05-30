#!/bin/bash

read -p "输入controller节点的主机名：" controller_host
yum install chrony -y
sed -i '3,6d' /etc/chrony.conf
echo "$controller_host" | sed -i "2a\server $controller_host iburst" /etc/chrony.conf
systemctl enable chronyd.service
systemctl start chronyd.service
