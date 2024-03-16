#!/bin/bash

systemctl disable --now firewalld
setenforce 0
sed -i "s:SELINUX=.*:SELINUX=disabled:g" /etc/selinux/config 

cat > /etc/yum.repos.d/CentOS-Stream-BaseOS.repo <<EOF
[baseos]
name=CentOS Stream $releasever - BaseOS
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=BaseOS&infra=$infra
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/8-stream/BaseOS/x86_64/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

cat > /etc/yum.repos.d/CentOS-Stream-AppStream.repo <<EOF
[appstream]
name=CentOS Stream $releasever - AppStream
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=AppStream&infra=$infra
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/8-stream/AppStream/x86_64/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

cat > /etc/yum.repos.d/CentOS-Stream-PowerTools.repo <<EOF
[powertools]
name=CentOS Stream $releasever - PowerTools
#mirrorlist=http://mirrorlist.centos.org/?release=$stream&arch=$basearch&repo=PowerTools&infra=$infra
baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos/8-stream/PowerTools/x86_64/os/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF


cat >> /etc/hosts << EOF
$HOST_IP $HOST_NAME
EOF
yum clean all
yum makecache
yum -y update
yum -y install centos-release-openstack-yoga yum-utils
yum config-manager --set-enabled powertools
yum -y upgrade
yum -y install python3-openstackclient openstack-selinux

timedatectl set-timezone Asia/Shanghai
yum install chrony -y
sed -i '3,6d' /etc/chrony.conf
sed -i '2a\server time1.aliyun.com iburst' /etc/chrony.conf
sed -i "3a\allow \\$NETWORK_SEGMENT" /etc/chrony.conf
systemctl enable chronyd.service
systemctl start chronyd.service

yum install mariadb mariadb-server python3-PyMySQL -y
cat > /etc/my.cnf.d/openstack.cnf << EOF
[mysqld]
bind-address = $HOST_IP

default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF
systemctl enable mariadb.service
systemctl start mariadb.service
echo  -e "\ny \n$DB_PASS \n$DB_PASS \ny \nn \ny \ny" | mysql_secure_installation

yum install rabbitmq-server -y
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service
rabbitmqctl add_user $RABBIT_USER $RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

yum install memcached python3-memcached -y
cp /etc/sysconfig/memcached /etc/sysconfig/memcached.bak
echo $HOST_NAME | sed -i "s/OPTIONS=\"-l 127.0.0.1,::1\"/OPTIONS=\"-l 127.0.0.1,::1,$HOST_NAME\"/" /etc/sysconfig/memcached
systemctl enable memcached.service
systemctl start memcached.service

yum install etcd -y
cp /etc/etcd/etcd.conf /etc/etcd/etcd.conf.bak

echo $HOST_IP | sed -i "s?\#ETCD_LISTEN_PEER_URLS=\"http://localhost:2380\"?ETCD_LISTEN_PEER_URLS=\"http://$HOST_IP:2380\"?" /etc/etcd/etcd.conf 
echo $HOST_IP | sed -i "s?ETCD_LISTEN_CLIENT_URLS=\"http://localhost:2379\"?ETCD_LISTEN_CLIENT_URLS=\"http://$HOST_IP:2379\"?" /etc/etcd/etcd.conf 
echo $HOST_IP | sed -i "s?ETCD_NAME=\"default\"?ETCD_NAME=\"$HOST_NAME\"?" /etc/etcd/etcd.conf 
echo $HOST_IP | sed -i "s?\#ETCD_INITIAL_ADVERTISE_PEER_URLS=\"http://localhost:2380\"?ETCD_INITIAL_ADVERTISE_PEER_URLS=\"http://$HOST_IP:2380\"?" /etc/etcd/etcd.conf
echo $HOST_IP | sed -i "s?ETCD_ADVERTISE_CLIENT_URLS=\"http://localhost:2379\"?ETCD_ADVERTISE_CLIENT_URLS=\"http://$HOST_IP:2379\"?" /etc/etcd/etcd.conf
echo $HOST_IP | sed -i "s?\#ETCD_INITIAL_CLUSTER=\"default=http://localhost:2380\"?ETCD_INITIAL_CLUSTER=\"$HOST_NAME=http://$HOST_IP:2380\"?" /etc/etcd/etcd.conf
sed -i 's?\#ETCD_INITIAL_CLUSTER_TOKEN=\"etcd-cluster\"?ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01\"?' /etc/etcd/etcd.conf
sed -i 's?\#ETCD_INITIAL_CLUSTER_STATE=\"new\"?ETCD_INITIAL_CLUSTER_STATE=\"new\"?' /etc/etcd/etcd.conf
systemctl enable etcd
systemctl start etcd

mysql -u root -p$DB_PASS -e "CREATE DATABASE keystone"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
IDENTIFIED BY '$KEYSTONE_DB_PASS'"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
IDENTIFIED BY '$KEYSTONE_DB_PASS'"

yum -y install openstack-keystone httpd python3-mod_wsgi

cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak
cat > /etc/keystone/keystone.conf <<EOF
[DEFAULT]
[application_credential]
[assignment]
[auth]
[cache]
[catalog]
[cors]
[credential]
[database]
connection = mysql+pymysql://keystone:$KEYSTONE_DB_PASS@$HOST_NAME/keystone
[domain_config]
[endpoint_filter]
[endpoint_policy]
[eventlet_server]
[federation]
[fernet_receipts]
[fernet_tokens]
[healthcheck]
[identity]
[identity_mapping]
[jwt_tokens]
[ldap]
[memcache]
[oauth1]
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_middleware]
[oslo_policy]
[policy]
[profiler]
[receipt]
[resource]
[revoke]
[role]
[saml]
[security_compliance]
[shadow_users]
[token]
provider = fernet
[tokenless_auth]
[totp]
[trust]
[unified_limit]
[wsgi]
EOF

su -s /bin/sh -c "keystone-manage db_sync" keystone
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone

keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
 keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
  --bootstrap-admin-url http://$HOST_NAME:5000/v3/ \
  --bootstrap-internal-url http://$HOST_NAME:5000/v3/ \
  --bootstrap-public-url http://$HOST_NAME:5000/v3/ \
  --bootstrap-region-id RegionOne

cp /etc/httpd/conf/httpd.conf{,.bak}
echo $HOST_NAME | sed -i "s?\#ServerName *?ServerName $HOST_NAME?" /etc/httpd/conf/httpd.conf 
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
systemctl enable httpd.service
systemctl start httpd.service
cat > /root/admin-openrc << EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://$HOST_NAME:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

. /root/admin-openrc
openstack project create --domain default \
  --description "Service Project" service

mysql -u root -p$DB_PASS -e "CREATE DATABASE glance"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' \
  IDENTIFIED BY '$GLANCE_DBPASS'"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' \
  IDENTIFIED BY '$GLANCE_DBPASS'"

. /root/admin-openrc
openstack user create glance --domain default --password  $GLANCE_PASS

openstack role add --project service --user glance admin
openstack service create --name glance \
  --description "OpenStack Image" image
openstack endpoint create --region RegionOne \
  image public http://$HOST_NAME:9292
openstack endpoint create --region RegionOne \
  image internal http://$HOST_NAME:9292
openstack endpoint create --region RegionOne \
  image admin http://$HOST_NAME:9292


yum -y install openstack-glance
cp /etc/glance/glance-api.conf  /etc/glance/glance-api.conf.bak
cat > /etc/glance/glance-api.conf << EOF
[DEFAULT]
[cinder]
[cors]
[database]
connection = mysql+pymysql://glance:$GLANCE_DBPASS@$HOST_NAME/glance
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
www_authenticate_uri  = http://$HOST_NAME:5000
auth_url = http://$HOST_NAME:5000
memcached_servers = $HOST_NAME:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = $GLANCE_PASS
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

mysql -u root -p$DB_PASS -e "CREATE DATABASE placement"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' \
  IDENTIFIED BY '$PLACEMENT_DBPASSS'"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' \
  IDENTIFIED BY '$PLACEMENT_DBPASSS'"

. /root/admin-openrc
openstack user create placement --domain default --password  $PLACEMENT_PASS

openstack role add --project service --user placement admin
openstack service create --name placement \
  --description "Placement API" placement
openstack endpoint create --region RegionOne \
  placement public http://$HOST_NAME:8778
openstack endpoint create --region RegionOne \
  placement internal http://$HOST_NAME:8778
openstack endpoint create --region RegionOne \
  placement admin http://$HOST_NAME:8778

yum  -y install openstack-placement-api
cp /etc/placement/placement.conf /etc/placement/placement.conf.bak
cat > /etc/placement/placement.conf << EOF
[DEFAULT]
[api]
auth_strategy = keystone
[cors]
[keystone_authtoken]
auth_url = http://$HOST_NAME:5000/v3
memcached_servers = $HOST_NAME:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = placement
password = $PLACEMENT_PASS
[oslo_policy]
[placement]
[placement_database]
connection = mysql+pymysql://placement:$PLACEMENT_DBPASSS@$HOST_NAME/placement
[profiler]
EOF

su -s /bin/sh -c "placement-manage db sync" placement
systemctl restart httpd

cp /etc/httpd/conf.d/00-placement-api.conf /etc/httpd/conf.d/00-placement-api.conf.bak
oslopolicy-convert-json-to-yaml --namespace placement --policy-file /etc/placement/policy.json --output-file /etc/placement/policy.yaml
mv /etc/placement/policy.json  /etc/placement/policy.json.bak
yum -y install python3-osc-placement

sed -i  "/^<\/VirtualHost/i<Directory /usr/bin> \
\n<IfVersion >= 2.4> \
\nRequire all granted \
\n</IfVersion> \
\n<IfVersion < 2.4> \
\nOrder allow,deny \
\nAllow from all \
\n</IfVersion> \
\n</Directory>" /etc/httpd/conf.d/00-placement-api.conf


systemctl restart httpd


mysql -u root -p$DB_PASS -e "CREATE DATABASE nova"
mysql -u root -p$DB_PASS -e "CREATE DATABASE nova_api"
mysql -u root -p$DB_PASS -e "CREATE DATABASE nova_cell0"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' \
  IDENTIFIED BY '$NOVA_DBPASS'"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' \
  IDENTIFIED BY '$NOVA_DBPASS'"

mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' \
  IDENTIFIED BY '$NOVA_DBPASS'"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' \
  IDENTIFIED BY '$NOVA_DBPASS'"

mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' \
  IDENTIFIED BY '$NOVA_DBPASS'"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' \
  IDENTIFIED BY '$NOVA_DBPASS'"

. /root/admin-openrc
openstack user create  nova  --domain default --password $NOVA_PASS
openstack role add --project service --user nova admin
openstack service create --name nova \
  --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne \
  compute public http://$HOST_NAME:8774/v2.1
openstack endpoint create --region RegionOne \
  compute internal http://$HOST_NAME:8774/v2.1
openstack endpoint create --region RegionOne \
  compute admin http://$HOST_NAME:8774/v2.1

yum install -y \
    openstack-nova-api \
    openstack-nova-scheduler \
    openstack-nova-conductor \
    openstack-nova-novncproxy \
    iptables

cp /etc/nova/nova.conf /etc/nova/nova.conf.bak

cat >  /etc/nova/nova.conf << EOF
[DEFAULT]
enabled_apis = osapi_compute,metadata
transport_url = rabbit://openstack:$RABBIT_PASS@$HOST_NAME:5672/
my_ip = $HOST_IP
log_file = /var/log/nova/nova-contoller.log
rootwrap_config = /etc/nova/rootwrap.conf
#auth_strategy = keystone
#rpc_backend = rabbit
[api]
auth_strategy = keystone
[api_database]
connection = mysql+pymysql://nova:$NOVA_DBPASS@$HOST_NAME/nova_api
[barbican]
[cache]
[cinder]
os_region_name = RegionOne
[compute]
[conductor]
[console]
[consoleauth]
[cors]
[database]
connection = mysql+pymysql://nova:$NOVA_DBPASS@$HOST_NAME/nova
[devices]
[ephemeral_storage_encryption]
[filter_scheduler]
[glance]
api_servers = http://$HOST_NAME:9292
[guestfs]
[healthcheck]
[hyperv]
[ironic]
[key_manager]
[keystone]
[keystone_authtoken]
service_token_roles = service
service_token_roles_required = true
www_authenticate_uri = http://$HOST_NAME:5000/
auth_url = http://$HOST_NAME:5000/
memcached_servers = $HOST_NAME:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = $NOVA_PASS
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
auth_url = http://$HOST_NAME:5000/v3
username = placement
password = $PLACEMENT_PASS
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
send_service_user_token = True
www_authenticate_uri = http://$HOST_NAME:5000/
auth_url = http://$HOST_NAME:5000/
memcached_servers = $HOST_NAME:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = $NOVA_PASS
[spice]
[upgrade_levels]
[vault]
[vendordata_dynamic_auth]
[vmware]
[vnc]
enabled = true
server_listen = $HOST_IP
server_proxyclient_address = $HOST_IP
[workarounds]
[wsgi]
[xenserver]
[xvp]
[zvm]
#[nova_api]
#api_version_select_status = enabled
EOF

su -s /bin/sh -c "nova-manage api_db sync" nova
cp /etc/nova/policy.json /etc/nova/policy.json.bak
oslopolicy-convert-json-to-yaml --namespace nova \
  --policy-file /etc/nova/policy.json \
  --output-file /etc/nova/policy.yaml

mv /etc/nova/policy.json /etc/nova/policy.json.bak

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


yum -y install openstack-nova-compute
cp /etc/nova/nova.conf /etc/nova/nova.conf.bak

mkdir -p /usr/lib/python3.6/site-packages/instances
chmod +777 /usr/lib/python3.6/site-packages/instances

cat > /etc/nova/nova-compute.conf << EOF
[DEFAULT]
enabled_apis = osapi_compute,metadata
transport_url = rabbit://openstack:$RABBIT_PASS@$HOST_NAME
my_ip = $HOST_IP
compute_driver = libvirt.LibvirtDriver
log_file = /var/log/nova/nova-compute.log
#vif_plugging_is_fatal=false
[api]
auth_strategy = keystone
[api_database]
[barbican]
[cache]
[cinder]
[compute]
[conductor]
[console]
[consoleauth]
[cors]
[database]
[devices]
[ephemeral_storage_encryption]
[filter_scheduler]
[glance]
api_servers = http://$HOST_NAME:9292
[guestfs]
[healthcheck]
[hyperv]
[ironic]
[key_manager]
[keystone]
[keystone_authtoken]
service_token_roles = service
service_token_roles_required = true
www_authenticate_uri = http://$HOST_NAME:5000/
auth_url = http://$HOST_NAME:5000/
memcached_servers = $HOST_NAME:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = $NOVA_PASS
[libvirt]
#virt_type = qemu
[metrics]
[mks]
[neutron]
auth_url = http://$HOST_NAME:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = $NEUTRON_PASS
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
auth_url = http://$HOST_NAME:5000/v3
username = placement
password = $PLACEMENT_PASS
[powervm]
[privsep]
[profiler]
[quota]
[rdp]
[remote_debug]
[scheduler]
[serial_console]
[service_user]
www_authenticate_uri = http://$HOST_NAME:5000/
auth_url = http://$HOST_NAME:5000/
memcached_servers = $HOST_NAME:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = $NOVA_PASS
send_service_user_token = True
[spice]
[upgrade_levels]
[vault]
[vendordata_dynamic_auth]
[vmware]
[vnc]
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = $HOST_IP
novncproxy_base_url = http://$HOST_IP:6080/vnc_auto.html
[workarounds]
[wsgi]
[xenserver]
[xvp]
[zvm]
EOF
systemctl enable --now libvirtd.service openstack-nova-compute.service

. /root/admin-openrc
openstack compute service list --service nova-compute
su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
nova-manage cell_v2 simple_cell_setup
nova-status upgrade check


mysql -u root -p$DB_PASS -e "CREATE DATABASE neutron"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' \
  IDENTIFIED BY '$NEUTRON_DBPASS'"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' \
  IDENTIFIED BY '$NEUTRON_DBPASS'"

. /root/admin-openrc
openstack user create neutron --domain default --password $NEUTRON_PASS
openstack role add --project service --user neutron admin
openstack service create --name neutron \
  --description "OpenStack Networking" network
openstack endpoint create --region RegionOne \
  network public http://$HOST_NAME:9696
openstack endpoint create --region RegionOne \
  network internal http://$HOST_NAME:9696
openstack endpoint create --region RegionOne \
  network admin http://$HOST_NAME:9696

#安装大二层网络
yum -y install openstack-neutron openstack-neutron-ml2 \
  openstack-neutron-linuxbridge ebtables ipset

cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak

cat > /etc/neutron/neutron.conf << EOF
[DEFAULT]
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = true
transport_url = rabbit://openstack:$RABBIT_PASS@$HOST_NAME
auth_strategy = keystone
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true
[cors]
[database]
connection = mysql+pymysql://neutron:$NEUTRON_DBPASS@$HOST_NAME/neutron
[keystone_authtoken]
www_authenticate_uri = http://$HOST_NAME:5000
auth_url = http://$HOST_NAME:5000
memcached_servers = $HOST_NAME:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = $NEUTRON_PASS
[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_middleware]
[oslo_policy]
[privsep]
[ssl]
[nova]
auth_url = http://$HOST_NAME:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = $NOVA_PASS
EOF

cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.bak
cat > /etc/neutron/plugins/ml2/ml2_conf.ini << EOF
[DEFAULT]
[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security
[ml2_type_flat]
flat_networks = provider
[ml2_type_vxlan]
vni_ranges = 1:1000
[securitygroup]
enable_ipset = true
EOF

cp /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.bak
cat > /etc/neutron/l3_agent.ini << EOF
[DEFAULT]
interface_driver = linuxbridge
EOF

cp /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.bak
cat > /etc/neutron/dhcp_agent.ini << EOF
[DEFAULT]
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true
EOF

cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak
cat > /etc/neutron/plugins/ml2/linuxbridge_agent.ini << EOF
[DEFAULT]
[linux_bridge]
physical_interface_mappings = provider:$INTERFACE_NAME
[vxlan]
enable_vxlan = true
local_ip = $HOST_IP
l2_population = true
[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
EOF

cat >> /etc/sysctl.conf << EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
modprobe br_netfilter
sysctl -p

sed -i "/^\[neutron/a auth_url = http://$HOST_NAME:5000 \
\nauth_type = password \
\nproject_domain_name = default \
\nuser_domain_name = default \
\nregion_name = RegionOne \
\nproject_name = service \
\nusername = neutron \
\npassword = $NEUTRON_PASS \
\nservice_metadata_proxy = true \
\nmetadata_proxy_shared_secret = $METADATA_SECRET" /etc/nova/nova.conf

cat > /etc/neutron/metadata_agent.ini << EOF
[DEFAULT]
nova_metadata_host = $HOST_NAME
metadata_proxy_shared_secret = $METADATA_SECRET
[cache]
EOF

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

echo "neutron ALL = (root) NOPASSWD: /usr/bin/privsep-helper *" >>/etc/sudoers.d/neutron

systemctl restart openstack-nova-api.service
systemctl enable neutron-server.service \
  neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
  neutron-metadata-agent.service
systemctl start neutron-server.service \
  neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
  neutron-metadata-agent.service
systemctl enable neutron-l3-agent.service
systemctl start neutron-l3-agent.service


cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak
cat > /etc/neutron/plugins/ml2/linuxbridge_agent.ini << EOF
[DEFAULT]
[linux_bridge]
physical_interface_mappings = provider:$INTERFACE_NAME
[vxlan]
enable_vxlan = true
local_ip = $HOST_IP
l2_population = true
[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
EOF

systemctl restart openstack-nova-compute.service

