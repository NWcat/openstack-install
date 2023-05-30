#!/bin/bash

read -p "输入controller节点的管理ip:" controller_ip
read -p "输入controller节点的主机名:" controller_host
read -p "输入compute节点的管理ip:" compute_ip
read -p "输入neutron_pass:" neutron_pass
read -p "输入RABBIT_PASS:" RABBIT_PASS
read -p "输入PROVIDER_INTERFACE_NAME:" PROVIDER_INTERFACE_NAME

yum -y install openstack-neutron-linuxbridge ebtables ipset
cat > /etc/neutron/neutron.conf << EOF
[DEFAULT]
transport_url = rabbit://openstack:$RABBIT_PASS@$controller_host
auth_strategy = keystone
[cors]
[database]
[keystone_authtoken]
www_authenticate_uri = http://$controller_host:5000
auth_url = http://$controller_host:5000
memcached_servers = $controller_host:11211
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
EOF

cat > /etc/neutron/plugins/ml2/linuxbridge_agent.ini << EOF
[DEFAULT]
[linux_bridge]
physical_interface_mappings = provider:$PROVIDER_INTERFACE_NAME
[vxlan]
enable_vxlan = true
local_ip = $compute_ip
l2_population = true
[securitygroup]
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
EOF

echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables=1" >> /etc/sysctl.conf
modprobe br_netfilter
sysctl -p

systemctl restart openstack-nova-compute.service
systemctl enable neutron-linuxbridge-agent.service
systemctl start neutron-linuxbridge-agent.service

