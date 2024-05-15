#!/bin/bash

read -p "输入管理网卡的ip网段:" IPsection
read -p "输入管理网卡的ip:" myIP
read -p "输入RABBIT_PASS:" RABBIT_PASS
read -p "输入dbpass:" dbpass

timedatectl set-timezone Asia/Shanghai
yum install chrony -y
sed -i '3,6d' /etc/chrony.conf
sed -i '2a\server time1.aliyun.com iburst' /etc/chrony.conf
sed -i "3a\allow \\$IPsection" /etc/chrony.conf
systemctl enable chronyd.service
systemctl start chronyd.service

yum install mariadb mariadb-server python3-PyMySQL -y
cat > /etc/my.cnf.d/openstack.cnf << EOF
[mysqld]
bind-address = $myIP

default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF
systemctl enable mariadb.service
systemctl start mariadb.service
echo  -e "\ny \n$dbpass \n$dbpass \ny \nn \ny \ny" | mysql_secure_installation

yum install rabbitmq-server -y
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service
rabbitmqctl add_user openstack $RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

yum install memcached python3-memcached -y
cp /etc/sysconfig/memcached /etc/sysconfig/memcached.bak
echo $HOSTNAME | sed -i "s/OPTIONS=\"-l 127.0.0.1,::1\"/OPTIONS=\"-l 127.0.0.1,::1,$HOSTNAME\"/" /etc/sysconfig/memcached
systemctl enable memcached.service
systemctl start memcached.service

yum install etcd -y
cp /etc/etcd/etcd.conf /etc/etcd/etcd.conf.bak

echo $myIP | sed -i "s?\#ETCD_LISTEN_PEER_URLS=\"http://localhost:2380\"?ETCD_LISTEN_PEER_URLS=\"http://$myIP:2380\"?" /etc/etcd/etcd.conf 
echo $myIP | sed -i "s?ETCD_LISTEN_CLIENT_URLS=\"http://localhost:2379\"?ETCD_LISTEN_CLIENT_URLS=\"http://$myIP:2379\"?" /etc/etcd/etcd.conf 
echo $myIP | sed -i "s?ETCD_NAME=\"default\"?ETCD_NAME=\"$HOSTNAME\"?" /etc/etcd/etcd.conf 
echo $myIP | sed -i "s?\#ETCD_INITIAL_ADVERTISE_PEER_URLS=\"http://localhost:2380\"?ETCD_INITIAL_ADVERTISE_PEER_URLS=\"http://$myIP:2380\"?" /etc/etcd/etcd.conf
echo $myIP | sed -i "s?ETCD_ADVERTISE_CLIENT_URLS=\"http://localhost:2379\"?ETCD_ADVERTISE_CLIENT_URLS=\"http://$myIP:2379\"?" /etc/etcd/etcd.conf
echo $myIP | sed -i "s?\#ETCD_INITIAL_CLUSTER=\"default=http://localhost:2380\"?ETCD_INITIAL_CLUSTER=\"$HOSTNAME=http://$myIP:2380\"?" /etc/etcd/etcd.conf
sed -i 's?\#ETCD_INITIAL_CLUSTER_TOKEN=\"etcd-cluster\"?ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01\"?' /etc/etcd/etcd.conf
sed -i 's?\#ETCD_INITIAL_CLUSTER_STATE=\"new\"?ETCD_INITIAL_CLUSTER_STATE=\"new\"?' /etc/etcd/etcd.conf
systemctl enable etcd
systemctl start etcd

