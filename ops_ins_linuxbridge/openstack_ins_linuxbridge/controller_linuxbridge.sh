#/bin/bash

#安装 OpenStack 客户端
yum install python-openstackclient -y
# 安装 openstack-selinux 软件包以便自动管理 OpenStack 服务的安全策略
yum install openstack-selinux -y

sed -i '/#allow/aallow 10.0.0.0/24' /etc/chrony.conf
systemctl enable chronyd.service
systemctl start chronyd.service

source ./pass.sh
source ./variable.sh

#SQL database
yum install mariadb mariadb-server python2-PyMySQL -y
cat >/etc/my.cnf.d/openstack.cnf<<EOF
[mysqld]
bind-address = $MANAGEMENT_INTERFACE_IP_ADDRESS
default-storage-engine = innodb
innodb_file_per_table
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF
systemctl enable mariadb.service
systemctl start mariadb.service
mysql_secure_installation <<EOF

y
$DB_PASS
$DB_PASS
y
y
y
y
EOF

#NoSQL 数据库 Telemetry 服务使用 NoSQL 数据库来存储信息，典型地，这个数据库运行在控制节点上。向导中使用MongoDB
yum install mongodb-server mongodb -y
sed -i "/^bind_ip =/cbind_ip = $MANAGEMENT_INTERFACE_IP_ADDRESS" /etc/mongod.conf
#默认情况下，MongoDB会在``/var/lib/mongodb/journal`` 目录下创建几个 1 GB 大小的日志文件。如果你想将每个日志文件大小减小到128MB并且限制日志文件占用的总空间为512MB
sed -i '/^#smallfiles/csmallfiles = true' /etc/mongod.conf
systemctl enable mongod.service
systemctl start mongod.service

#Message queue OpenStack 使用 message queue 协调操作和各服务的状态信息。消息队列服务一般运行在控制节点上
yum install rabbitmq-server -y
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service
rabbitmqctl add_user openstack $RABBIT_PASS
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

#Memcached 认证服务认证缓存使用Memcached缓存令牌。缓存服务memecached运行在控制节点。在生产部署中，我们推荐联合启用防火墙、认证和加密保证它的安全。
yum install memcached python-memcached -y
systemctl enable memcached.service
systemctl start memcached.service

#Identity service
mysql -u root -p$DB_PASS -e "CREATE DATABASE keystone;"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';"
mysql -u root -p$DB_PASS -e "FLUSH PRIVILEGES;"

yum install openstack-keystone  -y
yum install -y openstack-utils

[ -f /etc/keystone/keystone.conf_bak ]  || cp -a /etc/keystone/keystone.conf /etc/keystone/keystone.conf_bak

openstack-config --set /etc/keystone/keystone.conf DEFAULT admin_token $ADMIN_TOKEN
openstack-config --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:$KEYSTONE_DBPASS@$controller/keystone
openstack-config --set /etc/keystone/keystone.conf token provider  fernet
openstack-config --set /etc/keystone/keystone.conf  DEFAULT  verbose  True
su -s /bin/sh -c "keystone-manage db_sync" keystone
#初始化Fernet keys
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone

#Apache HTTP server with mod_wsgi
yum install httpd mod_wsgi -y
sed  -i  "s/#ServerName www.example.com:80/ServerName $controller/" /etc/httpd/conf/httpd.conf
cat >/etc/httpd/conf.d/wsgi-keystone.conf <<EOF
Listen 5000
Listen 35357

<VirtualHost *:5000>
WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
WSGIProcessGroup keystone-public
WSGIScriptAlias / /usr/bin/keystone-wsgi-public
WSGIApplicationGroup %{GLOBAL}
WSGIPassAuthorization On
ErrorLogFormat "%{cu}t %M"
ErrorLog /var/log/httpd/keystone-error.log
CustomLog /var/log/httpd/keystone-access.log combined

<Directory /usr/bin>
Require all granted
</Directory>
</VirtualHost>

<VirtualHost *:35357>
WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
WSGIProcessGroup keystone-admin
WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
WSGIApplicationGroup %{GLOBAL}
WSGIPassAuthorization On
ErrorLogFormat "%{cu}t %M"
ErrorLog /var/log/httpd/keystone-error.log
CustomLog /var/log/httpd/keystone-access.log combined

<Directory /usr/bin>
Require all granted
</Directory>
</VirtualHost>
EOF
systemctl enable httpd.service
systemctl start httpd.service

export OS_TOKEN=$ADMIN_TOKEN
export OS_URL=http://$controller:35357/v3
export OS_IDENTITY_API_VERSION=3
#创建服务实体和API端点
openstack service create --name keystone --description "OpenStack Identity" identity
openstack endpoint create --region RegionOne identity public http://$controller:5000/v3
openstack endpoint create --region RegionOne identity internal http://$controller:5000/v3
openstack endpoint create --region RegionOne identity admin http://$controller:35357/v3

#创建域、项目、用户和角色
openstack domain create --description "Default Domain" default
openstack project create --domain default --description "Admin Project" admin
openstack user create --domain default  admin --password $ADMIN_PASS
openstack role create admin
openstack role add --project admin --user admin admin
openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" demo
openstack user create --domain default  demo  --password $DEMO_PASS
openstack role create user
openstack role add --project demo --user demo user

#验证
#因为安全性的原因，关闭临时认证令牌机制：编辑 /etc/keystone/keystone-paste.ini 文件，从``[pipeline:public_api]``，[pipeline:admin_api]``和``[pipeline:api_v3]``部分删除``admin_token_auth
unset OS_TOKEN OS_URL
openstack --os-auth-url http://$controller:35357/v3  --os-project-domain-name default --os-user-domain-name default   --os-project-name admin --os-username admin token issue --os-password $ADMIN_PASS
openstack --os-auth-url http://$controller:5000/v3   --os-project-domain-name default --os-user-domain-name default   --os-project-name demo --os-username demo token issue --os-password $DEMO_PASS

cat >admin-openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://$controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

cat >demo-openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=$DEMO_PASS
export OS_AUTH_URL=http://$controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

source ./admin-openrc
openstack token issue

#glance
mysql -u root -p$DB_PASS -e "CREATE DATABASE glance;"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';"
mysql -u root -p$DB_PASS -e "FLUSH PRIVILEGES;"

source ./admin-openrc
openstack user create --domain default  glance --password $GLANCE_PASS
#添加 admin 角色到 glance 用户和 service 项目上
openstack role add --project service --user glance admin
openstack service create --name glance   --description "OpenStack Image" image
openstack endpoint create --region RegionOne   image public http://$controller:9292
openstack endpoint create --region RegionOne   image internal http://$controller:9292
openstack endpoint create --region RegionOne   image admin http://$controller:9292

yum install openstack-glance -y
#配置数据库访问
[ -f /etc/glance/glance-api.conf_bak ] || cp -a /etc/glance/glance-api.conf /etc/glance/glance-api.conf_bak
openstack-config --set /etc/glance/glance-api.conf database connection  mysql+pymysql://glance:$GLANCE_DBPASS@$controller/glance
#配置认证服务访问
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri  http://$controller:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_url  http://$controller:35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers  $controller:11211
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name  default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name  default
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken project_name  service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken username  glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken password  $GLANCE_PASS
openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor  keystone
#配置本地文件系统存储和镜像文件位置
openstack-config --set /etc/glance/glance-api.conf glance_store stores file,http
openstack-config --set /etc/glance/glance-api.conf glance_store default_store file
openstack-config --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/
[ -f /etc/glance/glance-registry.conf_bak ] || cp -a /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf_bak
openstack-config --set /etc/glance/glance-registry.conf database connection mysql+pymysql://glance:$GLANCE_DBPASS@$controller/glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$controller:5000
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://$controller:35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken memcached_servers $controller:11211
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_type password
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_name default
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_name default
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken project_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken username glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken password $GLANCE_PASS
openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone

#写入镜像服务数据库
su -s /bin/sh -c "glance-manage db_sync" glance
systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service
#验证
source ./admin-openrc
wget ftp://10.0.0.1/cirros-0.3.4-x86_64-disk.img
openstack image create "cirros" --file cirros-0.3.4-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack image list

#nova
mysql -u root -p$DB_PASS -e "CREATE DATABASE nova_api;"
mysql -u root -p$DB_PASS -e "CREATE DATABASE nova;"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost'  IDENTIFIED BY '$NOVA_DBPASS';"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost'  IDENTIFIED BY '$NOVA_DBPASS';"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%'  IDENTIFIED BY '$NOVA_DBPASS';"
mysql -u root -p$DB_PASS -e "FLUSH PRIVILEGES;"

source ./admin-openrc
openstack user create --domain default  nova --password $NOVA_PASS
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
openstack endpoint create --region RegionOne compute public http://$controller:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne  compute internal http://$controller:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne  compute admin http://$controller:8774/v2.1/%\(tenant_id\)s
yum install openstack-nova-api openstack-nova-conductor  openstack-nova-console openstack-nova-novncproxy  openstack-nova-scheduler -y
[ -f   /etc/nova/nova.conf_bak  ] || cp -a  /etc/nova/nova.conf /etc/nova/nova.conf_bak
openstack-config --set /etc/nova/nova.conf DEFAULT enabled_apis  osapi_compute,metadata
openstack-config --set /etc/nova/nova.conf api_database connection  mysql+pymysql://nova:$NOVA_DBPASS@$controller/nova_api
openstack-config --set /etc/nova/nova.conf database connection  mysql+pymysql://nova:$NOVA_DBPASS@$controller/nova
openstack-config --set /etc/nova/nova.conf DEFAULT rpc_backend  rabbit
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host  $controller
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid  openstack
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password  $RABBIT_PASS
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy  keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://$controller:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_url  http://$controller:35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken memcached_servers  $controller:11211
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_type  password
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_domain_name  default
openstack-config --set /etc/nova/nova.conf keystone_authtoken user_domain_name  default
openstack-config --set /etc/nova/nova.conf keystone_authtoken project_name  service
openstack-config --set /etc/nova/nova.conf keystone_authtoken username  nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken password  $NOVA_PASS
openstack-config --set /etc/nova/nova.conf DEFAULT my_ip  $MANAGEMENT_INTERFACE_IP_ADDRESS
openstack-config --set /etc/nova/nova.conf DEFAULT use_neutron  True
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf vnc vncserver_listen  $MANAGEMENT_INTERFACE_IP_ADDRESS
openstack-config --set /etc/nova/nova.conf vnc vncserver_proxyclient_address  $MANAGEMENT_INTERFACE_IP_ADDRESS
openstack-config --set /etc/nova/nova.conf glance api_servers  http://$controller:9292
openstack-config --set /etc/nova/nova.conf oslo_concurrency lock_path  /var/lib/nova/tmp

HARDWARE=`egrep -c '(vmx|svm)' /proc/cpuinfo`
if [ ${HARDWARE}  -eq 0 ]
then
openstack-config --set  /etc/nova/nova.conf libvirt virt_type  qemu
else
openstack-config --set  /etc/nova/nova.conf libvirt virt_type  kvm
fi


su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage db sync" nova

systemctl enable openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
systemctl start openstack-nova-api.service openstack-nova-consoleauth.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service

#Networking
mysql -u root -p$DB_PASS -e "CREATE DATABASE neutron;"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost'   IDENTIFIED BY '$NEUTRON_DBPASS';"
mysql -u root -p$DB_PASS -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%'  IDENTIFIED BY '$NEUTRON_DBPASS';"
source ./admin-openrc
#创建``neutron``用户
openstack user create --domain default  neutron --password $NEUTRON_PASS
#添加``admin`` 角色到``neutron`` 用户
openstack role add --project service --user neutron admin
#创建``neutron``服务实体
openstack service create --name neutron  --description "OpenStack Networking" network
#创建网络服务API端点
openstack endpoint create --region RegionOne   network public http://$controller:9696
openstack endpoint create --region RegionOne   network internal http://$controller:9696
openstack endpoint create --region RegionOne   network admin http://$controller:9696
#controller节点上安装并配置网络组件
yum install openstack-neutron openstack-neutron-ml2   openstack-neutron-linuxbridge ebtables -y
#数据库访问
[ -f /etc/neutron/neutron.conf_bak ] || cp -a  /etc/neutron/neutron.conf /etc/neutron/neutron.conf_bak
openstack-config --set /etc/neutron/neutron.conf database connection  mysql+pymysql://neutron:$NEUTRON_DBPASS@$controller/neutron
#启用Modular Layer 2 (ML2)插件，路由服务和重叠的IP地址
openstack-config --set /etc/neutron/neutron.conf DEFAULT core_plugin  ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT service_plugins  router
openstack-config --set /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips  True
openstack-config --set  /etc/neutron/neutron.conf DEFAULT verbose  True

#配置 “RabbitMQ” 消息队列的连接
openstack-config --set /etc/neutron/neutron.conf DEFAULT rpc_backend  rabbit
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host  $controller
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack
openstack-config --set /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  $RABBIT_PASS
#配置认证服务访问
openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone

openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://$controller:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_url  http://$controller:35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken memcached_servers  $controller:11211
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken auth_type  password
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_domain_name  default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken user_domain_name  default
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken project_name  service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken username  neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken password  $NEUTRON_PASS
#配置网络服务来通知计算节点的网络拓扑变化
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes  True
openstack-config --set /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes  True

openstack-config --set /etc/neutron/neutron.conf nova auth_url  http://$controller:35357
openstack-config --set /etc/neutron/neutron.conf nova auth_type  password
openstack-config --set /etc/neutron/neutron.conf nova project_domain_name  default
openstack-config --set /etc/neutron/neutron.conf nova user_domain_name  default
openstack-config --set /etc/neutron/neutron.conf nova region_name  RegionOne
openstack-config --set /etc/neutron/neutron.conf nova project_name  service
openstack-config --set /etc/neutron/neutron.conf nova username  nova
openstack-config --set /etc/neutron/neutron.conf nova password  $NOVA_PASS
#配置锁路径
openstack-config --set /etc/neutron/neutron.conf oslo_concurrency lock_path  /var/lib/neutron/tmp
#配置 Modular Layer 2 (ML2) 插件,ML2插件使用Linuxbridge机制来为实例创建layer－2虚拟网络基础设施
#启用flat，VLAN以及VXLAN网络
[ -f  /etc/neutron/plugins/ml2/ml2_conf.ini_bak ] || cp -a   /etc/neutron/plugins/ml2/ml2_conf.ini  /etc/neutron/plugins/ml2/ml2_conf.ini_bak 
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers  flat,vlan,vxlan
#启用VXLAN私有网络
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types  vxlan
#启用Linuxbridge和layer－2机制
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers  linuxbridge,l2population
##在你配置完ML2插件之后，删除可能导致数据库不一致的``type_drivers``项的值
##Linuxbridge代理只支持VXLAN覆盖网络。

#启用端口安全扩展驱动
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 extension_drivers  port_security
#配置公共虚拟网络为flat网络
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_flat flat_networks  provider
#为私有网络配置VXLAN网络识别的网络范围
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini  ml2_type_vxlan vni_ranges  1:1000
#启用 ipset 增加安全组规则的高效性
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini  securitygroup enable_ipset  True

#配置Linuxbridge代理
#将公共虚拟网络和公共物理网络接口对应起来
[ -f  /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak ] || cp -a   /etc/neutron/plugins/ml2/linuxbridge_agent.ini   /etc/neutron/plugins/ml2/linuxbridge_agent.ini_bak 
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini linux_bridge physical_interface_mappings provider:$PROVIDER_INTERFACE_NAME
#启用VXLAN覆盖网络，配置覆盖网络的物理网络接口的IP地址，启用layer－2 population
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan enable_vxlan  True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan local_ip $OVERLAY_INTERFACE_IP_ADDRESS_controller
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini vxlan l2_population  True
##这个示例架构中使用管理网络接口与其他节点建立流量隧道。因此，将``OVERLAY_INTERFACE_IP_ADDRESS``替换为计算节点的管理网络的IP地址。
#启用安全组并配置 Linuxbridge iptables firewall driver
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup enable_security_group  True
openstack-config --set /etc/neutron/plugins/ml2/linuxbridge_agent.ini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

#配置layer－3代理 Layer-3代理为私有虚拟网络提供路由和NAT服务
#配置Linuxbridge接口驱动和外部网络网桥
[ -f   /etc/neutron/l3_agent.ini_bak ] || cp -a    /etc/neutron/l3_agent.ini    /etc/neutron/l3_agent.ini_bak
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT external_network_bridge
openstack-config --set  /etc/neutron/l3_agent.ini  DEFAULT     verbose  True
##``external_network_bridge``选项特意设置成缺省值，这样就可以在一个代理上允许多种外部网络
#配置DHCP代理 配置Linuxbridge驱动接口，DHCP驱动并启用隔离元数据，这样在公共网络上的实例就可以通过网络来访问元数据
[ -f   /etc/neutron/dhcp_agent.ini_bak ] || cp -a    /etc/neutron/dhcp_agent.ini    /etc/neutron/dhcp_agent.ini_bak
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT enable_isolated_metadata  True
openstack-config --set  /etc/neutron/dhcp_agent.ini  DEFAULT     verbose  True

#配置元数据代理

#配置元数据主机以及共享密码
[ -f /etc/neutron/metadata_agent.ini_bak-2 ] || cp -a  /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini_bak-2
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT nova_metadata_ip  $controller
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT metadata_proxy_shared_secret  $METADATA_SECRET
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT verbose  True
##用你为元数据代理设置的密码替换 METADATA_SECRET

#为计算节点配置网络服务
#配置访问参数，启用元数据代理并设置密码
openstack-config --set /etc/nova/nova.conf neutron url  http://$controller:9696
openstack-config --set /etc/nova/nova.conf neutron auth_url  http://$controller:35357
openstack-config --set /etc/nova/nova.conf neutron auth_type  password
openstack-config --set /etc/nova/nova.conf neutron project_domain_name  default
openstack-config --set /etc/nova/nova.conf neutron user_domain_name  default
openstack-config --set /etc/nova/nova.conf neutron region_name  RegionOne
openstack-config --set /etc/nova/nova.conf neutron project_name service
openstack-config --set /etc/nova/nova.conf neutron username neutron
openstack-config --set /etc/nova/nova.conf neutron password $NEUTRON_PASS
openstack-config --set /etc/nova/nova.conf neutron service_metadata_proxy True
openstack-config --set /etc/nova/nova.conf neutron metadata_proxy_shared_secret $METADATA_SECRET
#网络服务初始化脚本需要一个超链接 /etc/neutron/plugin.ini``指向ML2插件配置文件/etc/neutron/plugins/ml2/ml2_conf.ini``
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

#重启计算API 服务
systemctl restart openstack-nova-api.service
systemctl enable neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
systemctl restart neutron-server.service neutron-linuxbridge-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service
#对于网络选项2，同样启用layer－3服务并设置其随系统自启动
systemctl enable neutron-l3-agent.service
systemctl restart neutron-l3-agent.service

#Dashboard
yum install openstack-dashboard -y
KEY_DASHBOARD=`cat /etc/openstack-dashboard/local_settings | grep SECRET_KEY | grep "=" |awk -F "'" '{print$2}'`
mv /etc/openstack-dashboard/local_settings /etc/openstack-dashboard/local_settings.ori
cp -a $PWD/local_settings /etc/openstack-dashboard/local_settings
sed -i "s/a0ec3ee55c1b5d28f378/${KEY_DASHBOARD}/g" /etc/openstack-dashboard/local_settings
sed -i  "/^OPENSTACK_HOST/cOPENSTACK_HOST = '$controller'" /etc/openstack-dashboard/local_settings
systemctl enable httpd.service memcached.service &&  systemctl restart httpd.service memcached.service