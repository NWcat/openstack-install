#!/bin/bash

read -p "输入controller节点的管理ip:" controller_ip
read -p "输入dbpass:" dbpass
read -p "输入CINDER_DBPASS:" CINDER_DBPASS
read -p "输入cinder_pass:" cinder_pass
read -p "输入RABBIT_PASS:" RABBIT_PASS

mysql -u root -p$dbpass -e "CREATE DATABASE cinder"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' \
  IDENTIFIED BY '$CINDER_DBPASS'"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' \
  IDENTIFIED BY '$CINDER_DBPASS'"

. /root/admin-openrc
echo "等待出现User Password，输入cinder_pass"
openstack user create --domain default --password-prompt cinder
openstack role add --project service --user cinder admin
openstack service create --name cinderv2 \
  --description "OpenStack Block Storage" volumev2
openstack service create --name cinderv3 \
  --description "OpenStack Block Storage" volumev3
openstack endpoint create --region RegionOne \
  volumev2 public http://$HOSTNAME:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne \
  volumev2 internal http://$HOSTNAME:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne \
  volumev2 admin http://$HOSTNAME:8776/v2/%\(project_id\)s
openstack endpoint create --region RegionOne \
  volumev3 public http://$HOSTNAME:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne \
  volumev3 internal http://$HOSTNAME:8776/v3/%\(project_id\)s
openstack endpoint create --region RegionOne \
  volumev3 admin http://$HOSTNAME:8776/v3/%\(project_id\)s

yum -y install openstack-cinder
cat > /etc/cinder/cinder.conf << EOF
[DEFAULT]
transport_url = rabbit://openstack:$RABBIT_PASS@$HOSTNAME
auth_strategy = keystone
my_ip = $controller_ip
[backend]
[backend_defaults]
[barbican]
[brcd_fabric_example]
[cisco_fabric_example]
[coordination]
[cors]
[database]
connection = mysql+pymysql://cinder:$CINDER_DBPASS@$HOSTNAME/cinder
[fc-zone-manager]
[healthcheck]
[key_manager]
[keystone_authtoken]
www_authenticate_uri = http://$HOSTNAME:5000
auth_url = http://$HOSTNAME:5000
memcached_servers = $HOSTNAME:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = cinder
password = $cinder_pass
[nova]
[oslo_concurrency]
lock_path = /var/lib/cinder/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_middleware]
[oslo_policy]
[oslo_reports]
[oslo_versionedobjects]
[privsep]
[profiler]
[sample_castellan_source]
[sample_remote_file_source]
[service_user]
[ssl]
[vault]
EOF

su -s /bin/sh -c "cinder-manage db sync" cinder
sed -i "/^\[cinder/a os_region_name = RegionOne" /etc/nova/nova.conf
systemctl restart openstack-nova-api.service
systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service

