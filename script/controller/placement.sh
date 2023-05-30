#!/bin/bash

read -p "输入dbpass:" dbpass
read -p "输入placement_pass:" placement_pass
read -p "输入PLACEMENT_DBPASS:" PLACEMENT_DBPASS

mysql -u root -p$dbpass -e "CREATE DATABASE placement"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' \
  IDENTIFIED BY '$PLACEMENT_DBPASS'"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' \
  IDENTIFIED BY '$PLACEMENT_DBPASS'"

. /root/admin-openrc
echo "等待出现User Password，输入placement_pass" 
openstack user create --domain default --password-prompt placement

openstack role add --project service --user placement admin
openstack service create --name placement \
  --description "Placement API" placement
openstack endpoint create --region RegionOne \
  placement public http://$HOSTNAME:8778
openstack endpoint create --region RegionOne \
  placement internal http://$HOSTNAME:8778
openstack endpoint create --region RegionOne \
  placement admin http://$HOSTNAME:8778

yum  -y install openstack-placement-api
cat > /etc/placement/placement.conf << EOF
[DEFAULT]
[api]
auth_strategy = keystone
[cors]
[keystone_authtoken]
auth_url = http://$HOSTNAME:5000/v3
memcached_servers = $HOSTNAME:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = placement
password = $placement_pass
[oslo_policy]
[placement]
[placement_database]
connection = mysql+pymysql://placement:$PLACEMENT_DBPASS@$HOSTNAME/placement
[profiler]
EOF
 
sed -i  "/^<\/VirtualHost/i<Directory /usr/bin> \
\n<IfVersion >= 2.4> \
\nRequire all granted \
\n</IfVersion> \
\n<IfVersion < 2.4> \
\nOrder allow,deny \
\nAllow from all \
\n</IfVersion> \
\n</Directory>" /etc/httpd/conf.d/00-placement-api.conf

su -s /bin/sh -c "placement-manage db sync" placement
systemctl restart httpd
