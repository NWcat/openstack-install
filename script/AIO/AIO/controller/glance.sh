#!/bin/bash

read -p "输入dbpass:" dbpass
read -p "输入glance_pass:" glance_pass
read -p "输入GLANCE_DBPASS:" GLANCE_DBPASS

mysql -u root -p$dbpass -e "CREATE DATABASE glance"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' \
  IDENTIFIED BY '$GLANCE_DBPASS'"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' \
  IDENTIFIED BY '$GLANCE_DBPASS'"

. /root/admin-openrc
echo "等待出现User Password，输入glance_pass"
openstack user create --domain default --password-prompt glance

openstack role add --project service --user glance admin
openstack service create --name glance \
  --description "OpenStack Image" image
openstack endpoint create --region RegionOne \
  image public http://$HOSTNAME:9292
openstack endpoint create --region RegionOne \
  image internal http://$HOSTNAME:9292
openstack endpoint create --region RegionOne \
  image admin http://$HOSTNAME:9292


yum -y install openstack-glance
cp /etc/glance/glance-api.conf  /etc/glance/glance-api.conf.bak
cat > /etc/glance/glance-api.conf << EOF
[DEFAULT]
[cinder]
[cors]
[database]
connection = mysql+pymysql://glance:$GLANCE_DBPASS@$HOSTNAME/glance
[file]
[glance.store.http.store]
[glance.store.rbd.store]
[glance.store.sheepdog.store]
[glance.store.swift.store]
[glance.store.vmware_datastore.store]
[glance_store]
#stores = file,http
#default_store = file
default_backend = {'store_one': 'http', 'store_two': 'file'}
filesystem_store_datadir = /var/lib/glance/images/
[image_format]
[keystone_authtoken]
www_authenticate_uri  = http://$HOSTNAME:5000
auth_url = http://$HOSTNAME:5000
memcached_servers = $HOSTNAME:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = $glance_pass
[oslo_concurrency]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_middleware]
[oslo_policy]
[paste_deploy]
flavor = keystone
[profiler]
[store_type_location_strategy]
[task]
[taskflow_executor]
EOF

su -s /bin/sh -c "glance-manage db_sync" glance
systemctl enable openstack-glance-api.service
systemctl start openstack-glance-api.service
