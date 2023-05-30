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
`git clone https://github.com/NWcat/openstack-install.git` 

`cd openstack-install`

`chmod +x install.sh && ./install.sh`
