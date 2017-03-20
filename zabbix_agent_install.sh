#!/bin/bash

#zabbix agent 安装脚本，centos6/7测试通过
#maintainer liuliguo 20170320

#
yum install gcc gcc-c++ -y
yum install net-snmp-devel -y
yum install curl-devel -y
yum install wget -y
#
#源码包下载url
tarfileUrl="https://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/3.0.7/zabbix-3.0.7.tar.gz"
#源码包文件包
tarfile="zabbix-3.0.7.tar.gz"
#源码包解压后目录名
tarfileDir="zabbix-3.0.7"
#解包到哪的路径
downloadPath="/usr/local/src"
#agent安装目标路径
agentInstallPath="/usr/local/zabbix"

wget "$tarfileUrl" -P "$downloadPath"
if [ -f "$downloadPath/$tarfile" ];then
    tar xf "$downloadPath/$tarfile" -C "$downloadPath"
    cd "$downloadPath/$tarfileDir"
    ./configure --prefix=$agentInstallPath   --enable-agent  --with-net-snmp --with-libcurl
    if [ $? -eq 0 ];then
        make && make install
    else
        echo "error,configure failed"
        exit
    fi
else
    echo "error,$downloadPath/$tarfile no found"
    exit
fi
#
agent_conf_file="$agentInstallPath/etc/zabbix_agentd.conf"
#此处修改zabbix server的IP地址
ping -c2 172.16.1.180 && zabbix_server_ip='172.16.1.180'|| zabbix_server_ip='124.202.226.126'
if [ -f $agent_conf_file ];then
    sed -i "/^Server=/cServer=$zabbix_server_ip" $agent_conf_file
    sed -i "/^ServerActive=/cServerActive=$zabbix_server_ip" $agent_conf_file
    sed -i "/^Hostname=/cHostname=`hostname`" $agent_conf_file
    sed -i "/^LogFile=/cLogFile=/var/log/zabbix/zabbix_agentd.log" $agent_conf_file
    sed -i "/PidFile=/cPidFile=/var/log/zabbix/zabbix_agentd.pid" $agent_conf_file
else
    echo "error,$agent_conf_file no found"
    exit
fi
groupadd zabbix
useradd -g zabbix -M -s /sbin/nologin zabbix
mkdir /var/log/zabbix -p
touch /var/log/zabbix/zabbix_agentd.log
chown -R zabbix.zabbix /var/log/zabbix

if [ -f  $agentInstallPath/sbin/zabbix_agentd ];then
    cd "$downloadPath/$tarfileDir"
    cp misc/init.d/fedora/core/zabbix_agentd /etc/init.d/
	chmod a+x /etc/init.d/zabbix_*
	ln -s $agentInstallPath/sbin/* /usr/local/sbin/
	ln -s $agentInstallPath/bin/* /usr/local/bin/
	chkconfig --add /etc/init.d/zabbix_agentd
	chkconfig zabbix_agentd on
	service zabbix_agentd start
else
    echo "error, $agentInstallPath/sbin/zabbix_agentd no found"
    exit
fi
netstat -anpt |grep :10050
exit
