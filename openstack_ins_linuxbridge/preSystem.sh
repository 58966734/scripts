#!/bin/bash

source ./variable.sh
#禁用SELINUX
sed  -i '/^SELINUX=/cSELINUX=disabled' /etc/sysconfig/selinux
#停用防火墙
systemctl stop firewalld
systemctl disable firewalld
#配置网卡

#配置hosts
cat >/etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
$OVERLAY_INTERFACE_IP_ADDRESS_controller $controller
$OVERLAY_INTERFACE_IP_ADDRESS_nova_compute1 $compute1
EOF
#检查网络连通性
ping -c 4 openstack.org

#配置yum源
[ -f /etc/yum.repos.d/bak ] || mkdir -p /etc/yum.repos.d/bak
mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bak -f
cat >/etc/yum.repos.d/mitaka.repo <<EOF
[base]
name=base
enabled=1
gpgcheck=0
baseurl=$yum_base

[mitaka]
name=mitaka
enabled=1
gpgcheck=0
baseurl=$yum_mitaka
EOF

yum repolist

#时间服务并验证 
yum clean all
yum install chrony -y
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

#系统更新
yum install vim -y
yum upgrade -y

#更新后重启系统
reboot
#安装 OpenStack 客户端
#yum install python-openstackclient -y
# 安装 openstack-selinux 软件包以便自动管理 OpenStack 服务的安全策略
#yum install openstack-selinux -y