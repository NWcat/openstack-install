#!/bin/bash

echo "安装neutron之前，compute节点要安装好nova"
read -p "输入controller节点的管理ip:" controller_ip
read -p "输入dbpass:" dbpass
read -p "输入neutron_pass:" neutron_pass
read -p "输入NEUTRON_DBPASS:" NEUTRON_DBPASS
read -p "输入nova_pass:" nova_pass
read -p "输入METADATA_SECRET:" METADATA_SECRET
read -p "输入RABBIT_PASS:" RABBIT_PASS
read -p "输入PROVIDER_INTERFACE_NAME:" PROVIDER_INTERFACE_NAME

mysql -u root -p$dbpass -e "CREATE DATABASE neutron"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' \
  IDENTIFIED BY '$NEUTRON_DBPASS'"
mysql -u root -p$dbpass -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' \
  IDENTIFIED BY '$NEUTRON_DBPASS'"

. /root/admin-openrc
echo "等待出现User Password，输入neutron_pass"
openstack user create --domain default --password-prompt neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron \
  --description "OpenStack Networking" network
openstack endpoint create --region RegionOne \
  network public http://$HOSTNAME:9696
openstack endpoint create --region RegionOne \
  network internal http://$HOSTNAME:9696
openstack endpoint create --region RegionOne \
  network admin http://$HOSTNAME:9696

#安装大二层网络
yum -y install openstack-neutron openstack-neutron-ml2 \
  openstack-neutron-linuxbridge ebtables

cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak

cat > /etc/neutron/neutron.conf << EOF
[DEFAULT]
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = true
transport_url = rabbit://openstack:$RABBIT_PASS@$HOSTNAME
auth_strategy = keystone
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true
[cors]
[database]
connection = mysql+pymysql://neutron:$NEUTRON_DBPASS@$HOSTNAME/neutron
[keystone_authtoken]
www_authenticate_uri = http://$HOSTNAME:5000
auth_url = http://$HOSTNAME:5000
memcached_servers = $HOSTNAME:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = $neutron_pass
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
auth_url = http://$HOSTNAME:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = $nova_pass
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
physical_interface_mappings = provider:$PROVIDER_INTERFACE_NAME
[vxlan]
enable_vxlan = true
local_ip = $controller_ip
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

sed -i "/^\[neutron/a auth_url = http://$HOSTNAME:5000 \
\nauth_type = password \
\nproject_domain_name = default \
\nuser_domain_name = default \
\nregion_name = RegionOne \
\nproject_name = service \
\nusername = neutron \
\npassword = $neutron_pass \
\nservice_metadata_proxy = true \
\nmetadata_proxy_shared_secret = $METADATA_SECRET" /etc/nova/nova.conf

cat > /etc/neutron/metadata_agent.ini << EOF
[DEFAULT]
nova_metadata_host = $HOSTNAME
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
