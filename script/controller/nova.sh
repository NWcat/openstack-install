#!/bin/bash
echo "[1] 首次安装"
echo "[2] 同步cell数据库(安装完compute节点Nova,运行)"
read -p " " fn
if [ $fn = "1" ]; then
read -p "输入controller节点的管理ip:" controller_ip
read -p "输入dbpass:" dbpass
read -p "输入nova_pass:" nova_pass
read -p "输入NOVA_DBPASS:" NOVA_DBPASS
read -p "输入placement_pass:" placement_pass
read -p "输入RABBIT_PASS:" RABBIT_PASS


mysql -u root -p$dbpass -e "CREATE DATABASE nova"
mysql -u root -p$dbpass -e "CREATE DATABASE nova_api"
mysql -u root -p$dbpass -e "CREATE DATABASE nova_cell0"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' \
  IDENTIFIED BY '$NOVA_DBPASS'"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' \
  IDENTIFIED BY '$NOVA_DBPASS'"

mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' \
  IDENTIFIED BY '$NOVA_DBPASS'"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' \
  IDENTIFIED BY '$NOVA_DBPASS'"

mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' \
  IDENTIFIED BY '$NOVA_DBPASS'"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' \
  IDENTIFIED BY '$NOVA_DBPASS'"

. /root/admin-openrc
echo "等待出现User Password，输入nova_pass" 
openstack user create --domain default --password-prompt nova
openstack role add --project service --user nova admin
openstack service create --name nova \
  --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne \
  compute public http://$HOSTNAME:8774/v2.1
openstack endpoint create --region RegionOne \
  compute internal http://$HOSTNAME:8774/v2.1
openstack endpoint create --region RegionOne \
  compute admin http://$HOSTNAME:8774/v2.1

yum -y install openstack-nova-api openstack-nova-conductor \
  openstack-nova-novncproxy openstack-nova-scheduler

cat >  /etc/nova/nova.conf << EOF
[DEFAULT]
enabled_apis = osapi_compute,metadata
transport_url = rabbit://openstack:$RABBIT_PASS@$HOSTNAME:5672/
my_ip = $controller_ip
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver
[api]
auth_strategy = keystone
[api_database]
connection = mysql+pymysql://nova:$NOVA_DBPASS@$HOSTNAME/nova_api
[barbican]
[cache]
[cinder]
[compute]
[conductor]
[console]
[consoleauth]
[cors]
[database]
connection = mysql+pymysql://nova:$NOVA_DBPASS@$HOSTNAME/nova
[devices]
[ephemeral_storage_encryption]
[filter_scheduler]
[glance]
api_servers = http://$HOSTNAME:9292
[guestfs]
[healthcheck]
[hyperv]
[ironic]
[key_manager]
[keystone]
[keystone_authtoken]
www_authenticate_uri = http://$HOSTNAME:5000/
auth_url = http://$HOSTNAME:5000/
memcached_servers = $HOSTNAME:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = $nova_pass
[libvirt]
[metrics]
[mks]
[neutron]
[notifications]
[osapi_v21]
[oslo_concurrency]
lock_path = /var/lib/nova/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_middleware]
[oslo_policy]
[pci]
[placement]
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://$HOSTNAME:5000/v3
username = placement
password = $placement_pass
[powervm]
[privsep]
[profiler]
[quota]
[rdp]
[remote_debug]
[scheduler]
discover_hosts_in_cells_interval = 300
[serial_console]
[service_user]
[spice]
[upgrade_levels]
[vault]
[vendordata_dynamic_auth]
[vmware]
[vnc]
enabled = true
server_listen = $controller_ip
server_proxyclient_address = $controller_ip
[workarounds]
[wsgi]
[xenserver]
[xvp]
[zvm]
EOF

su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
su -s /bin/sh -c "nova-manage db sync" nova
su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
systemctl enable \
    openstack-nova-api.service \
    openstack-nova-scheduler.service \
    openstack-nova-conductor.service \
    openstack-nova-novncproxy.service
systemctl start \
    openstack-nova-api.service \
    openstack-nova-scheduler.service \
    openstack-nova-conductor.service \
    openstack-nova-novncproxy.service

elif [ $fn = "2" ]; then
read -p "如果已经安装了计算节点的NOVA服务，那么请输入y继续" yn
if [ $yn = "y" ]; then
  echo "继续执行，将计算节点添加到cell数据库" 
  . /root/admin-openrc
  openstack compute service list --service nova-compute
  su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
else
  echo "停止执行"
fi
fi

