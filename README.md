# opentack-install
## 简介 
部署环境：centos7
openstack版本：Train
架构 Controller + Compute

Core services:
* Keystone
* Glance
* Placement
* Nova
* Neutron
* Horizon
* Cinder

所有组件，可以单独部署

## 须知

运行脚本前，自行配置好静态IP及主机名

脚本中出现的，如RABBIT_PASS，自行输入想设置的密码

如PROVIDER_INTERFACE_NAME，则输入网卡名称

如小写的neutron_pass，则是openstack的neutron用户密码,大写的NEUTRON_DBPASS，则是NEUTRON数据库用户密码

## Installation

## Download

`git clone https://github.com/NWcat/openstack-install.git` 

### Switch to tool's directory

`cd openstack-install`

### Run script

`chmod +x install.sh && ./install.sh`
