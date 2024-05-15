#!/bin/bash

read -p "输入controller节点的管理ip:" controller_ip
read -p "输入controller节点的主机名:" controller_host
read -p "输入compute节点的管理ip:" compute_ip
read -p "输入neutron_pass:" neutron_pass
read -p "输入RABBIT_PASS:" RABBIT_PASS
read -p "输入PROVIDER_INTERFACE_NAME:" PROVIDER_INTERFACE_NAME

yum -y install openstack-neutron-linuxbridge ebtables ipset
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf.bak
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

cp /etc/neutron/plugins/ml2/openvswitch_agent.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini.bak
cat > /etc/neutron/plugins/ml2/openvswitch_agent.ini << EOF
[DEFAULT]
[agent]
l2_population = True
tunnel_types = vxlan
prevent_arp_spoofing = True
[dhcp]
[network_log]
[ovs]
local_ip = $compute_ip
bridge_mappings = physnet1:$PROVIDER_INTERFACE_NAME
[securitygroup]
enable_security_group = True
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
EOF

echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-ip6tables=1" >> /etc/sysctl.conf
modprobe br_netfilter
sysctl -p

sed -i "6alinuxnet_interface_driver = nova.network.linux_net.LinuxOVSlnterfaceDriver" /etc/nova/nova.conf

echo "neutron ALL = (root) NOPASSWD: /usr/bin/privsep-helper *" >>/etc/sudoers.d/neutron

systemctl restart openstack-nova-compute.service
systemctl enable neutron-linuxbridge-agent.service
systemctl start neutron-linuxbridge-agent.service

