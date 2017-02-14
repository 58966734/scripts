#!/bin/bash

source ./variable.sh
#����SELINUX
sed  -i '/^SELINUX=/cSELINUX=disabled' /etc/sysconfig/selinux
#ͣ�÷���ǽ
systemctl stop firewalld
systemctl disable firewalld
#��������

#����hosts
cat >/etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
$OVERLAY_INTERFACE_IP_ADDRESS_controller $controller
$OVERLAY_INTERFACE_IP_ADDRESS_nova_compute1 $compute1
EOF
#���������ͨ��
ping -c 4 openstack.org

#����yumԴ
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

#ʱ�������֤ 
yum clean all
yum install chrony -y
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

#ϵͳ����
yum install vim -y
yum upgrade -y

#���º�����ϵͳ
reboot
#��װ OpenStack �ͻ���
#yum install python-openstackclient -y
# ��װ openstack-selinux ������Ա��Զ����� OpenStack ����İ�ȫ����
#yum install openstack-selinux -y