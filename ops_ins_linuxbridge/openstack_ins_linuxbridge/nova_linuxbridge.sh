#/bin/bash

#安装 OpenStack 客户端
yum install python-openstackclient -y
# 安装 openstack-selinux 软件包以便自动管理 OpenStack 服务的安全策略
yum install openstack-selinux -y

sed -i "/^# Please conside/aserver $controller iburst" /etc/chrony.conf
systemctl enable chronyd.service
systemctl restart chronyd.service

source ./pass.sh
source ./variable.sh

yum install openstack-nova-compute -y
yum install -y openstack-utils
[ -f   /etc/nova/nova.conf_bak  ] || cp -a  /etc/nova/nova.conf /etc/nova/nova.conf_bak
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host $controller
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid openstack
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password $RABBIT_PASS
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$controller:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_url http://$controller:35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken memcached_servers $controller:11211
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_type password
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/nova/nova.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken username nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken password $NOVA_PASS
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip $MANAGEMENT_INTERFACE_IP_ADDRESS
openstack-config --set /etc/nova/nova.conf DEFAULT use_neutron True
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf vnc enabled True
openstack-config --set /etc/nova/nova.conf vnc vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf vnc vncserver_proxyclient_address $my_ip_nova
openstack-config --set /etc/nova/nova.conf vnc novncproxy_base_url http://$controller:6080/vnc_auto.html
openstack-config --set /etc/nova/nova.conf glance api_servers http://controller:9292
openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path /var/lib/nova/tmp
HARDWARE=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ ${HARDWARE}  -eq 0 ]
then 
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu 
	openstack-config --set  /etc/nova/nova.conf DEFAULT  vif_plugging_is_fatal  False 
	openstack-config --set  /etc/nova/nova.conf  DEFAULT vif_plugging_timeout  0
else
	openstack-config --set  /etc/nova/nova.conf libvirt virt_type  kvm
	openstack-config --set  /etc/nova/nova.conf DEFAULT  vif_plugging_is_fatal  False 
	openstack-config --set  /etc/nova/nova.conf  DEFAULT vif_plugging_timeout  0
fi
systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service

#安装和配置计算节点FOR NEUTRON
yum install openstack-neutron-linuxbridge ebtables ipset -y
#在``[database]`` 部分，注释所有``connection`` 项，因为计算节点不直接访问数据库。
#配置 “RabbitMQ” 消息队列的连接
[ -f  /etc/neutron/neutron.conf_bak ]  ||  cp -a /etc/neutron/neutron.conf /etc/neutron/neutron.conf_bak
sed -i '/^connection/d' /etc/neutron/neutron.conf
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend rabbit
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host $controller
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid openstack
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password $RABBIT_PASS

#配置认证服务访问
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri http://$controller:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url http://$controller:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers $controller:11211
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_type password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password $NEUTRON_PASS

#配置锁路径
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path /var/lib/neutron/tmp

#在计算节点上配置网络组件
#配置Linuxbridge代理
#将公共虚拟网络和公共物理网络接口对应起来
[ -f  /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak ] || cp -a   /etc/neutron/plugins/ml2/linuxbridge_agent.ini   /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak 
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings provider:$PROVIDER_INTERFACE_NAME

#启用VXLAN覆盖网络，配置覆盖网络的物理网络接口的IP地址，启用layer－2 population
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip $OVERLAY_INTERFACE_IP_ADDRESS_nova
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population True

#启用安全组并配置 Linuxbridge iptables firewall driver
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

#为计算节点配置网络服务
openstack-config --set /etc/nova/nova.conf neutron url http://$controller:9696
openstack-config --set /etc/nova/nova.conf neutron auth_url http://$controller:35357
openstack-config --set /etc/nova/nova.conf neutron auth_type password
openstack-config --set /etc/nova/nova.conf neutron project_domain_name default
openstack-config --set /etc/nova/nova.conf neutron user_domain_name default
openstack-config --set /etc/nova/nova.conf neutron region_name RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service
openstack-config --set /etc/nova/nova.conf neutron username neutron
openstack-config --set /etc/nova/nova.conf neutron password $NEUTRON_PASS

systemctl restart openstack-nova-compute.service
systemctl enable neutron-linuxbridge-agent.service
systemctl restart neutron-linuxbridge-agent.service