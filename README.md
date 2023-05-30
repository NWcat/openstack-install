# opentack-install
## 简介 
部署环境：centos7

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

运行脚本前，自行配置好静态IP及主机名

## Installation

## Download

`git clone https://github.com/NWcat/openstack-install.git` 

### Switch to tool's directory

`cd openstack-install`

### Run script

`chmod +x install.sh && ./install.sh`
