#!/bin/bash

read -p "输入controller节点的管理ip:" controller_ip
read -p "输入controller节点的主机名:" controller_host
read -p "输入compute节点的管理ip:" compute_ip
read -p "输入nova_pass:" nova_pass
read -p "输入neutron_pass:" neutron_pass
read -p "输入placement_pass:" placement_pass
read -p "输入RABBIT_PASS:" RABBIT_PASS

yum -y install openstack-nova-compute
cp /etc/nova/nova.conf /etc/nova/nova.conf.bak

mkdir -p /usr/lib/python3.6/site-packages/instances
chmod +777 /usr/lib/python3.6/site-packages/instances

cat > /etc/nova/nova.conf << EOF
[DEFAULT]
enabled_apis = osapi_compute,metadata
transport_url = rabbit://openstack:$RABBIT_PASS@$controller_host
my_ip = $compute_ip
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
api_servers = http://$controller_host:9292
[guestfs]
[healthcheck]
[hyperv]
[ironic]
[key_manager]
[keystone]
[keystone_authtoken]
service_token_roles = service
service_token_roles_required = true
www_authenticate_uri = http://$controller_host:5000/
auth_url = http://$controller_host:5000/
memcached_servers = $controller_host:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = $nova_pass
[libvirt]
#virt_type = qemu
[metrics]
[mks]
[neutron]
auth_url = http://$controller_host:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = $neutron_pass
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
auth_url = http://$controller_host:5000/v3
username = placement
password = $placement_pass
[powervm]
[privsep]
[profiler]
[quota]
[rdp]
[remote_debug]
[scheduler]
[serial_console]
[service_user]
www_authenticate_uri = http://$controller_host:5000/
auth_url = http://$controller_host:5000/
memcached_servers = $controller_host:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = $nova_pass
send_service_user_token = True
[spice]
[upgrade_levels]
[vault]
[vendordata_dynamic_auth]
[vmware]
[vnc]
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = $compute_ip
novncproxy_base_url = http://$controller_ip:6080/vnc_auto.html
[workarounds]
[wsgi]
[xenserver]
[xvp]
[zvm]
EOF
systemctl enable --now libvirtd.service openstack-nova-compute.service
