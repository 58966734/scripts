#!/bin/bash
#
yum install gcc gcc-c++ -y
yum install net-snmp-devel -y
yum install curl-devel -y
yum install wget -y
#
wget http://124.202.226.126:31099/zabbix/zabbix-3.0.3.tar.gz -P /usr/local/src
#wget "https://sourceforge.net/projects/zabbix/files/ZABBIX Latest Stable/3.0.5/zabbix-3.0.5.tar.gz" -P /usr/local/src
if [ -f /usr/local/src/zabbix-3.0.3.tar.gz ];then
    tar xf /usr/local/src/zabbix-3.0.3.tar.gz -C /usr/local/src
    cd /usr/local/src/zabbix-3.0.3
    ./configure --prefix=/usr/local/zabbix   --enable-agent  --with-net-snmp --with-libcurl
    if [ $? -eq 0 ];then
        make && make install
    else
        echo "error,configure failed"
        exit
    fi
else
    echo "error,/usr/local/src/zabbix-3.0.3.tar.gz no found"
    exit
fi
#
agent_conf_file="/usr/local/zabbix/etc/zabbix_agentd.conf"
ping -c2 172.16.1.180 && zabbix_server_ip='172.16.1.180'|| zabbix_server_ip='124.202.226.126' 
if [ -f $agent_conf_file ];then
    sed -i "/^Server=/cServer=$zabbix_server_ip" $agent_conf_file
    sed -i "/^ServerActive=/cServerActive=$zabbix_server_ip" $agent_conf_file
    sed -i "/^Hostname=/cHostname=`hostname`" $agent_conf_file
    sed -i "/^LogFile=/cLogFile=/var/log/zabbix/zabbix_agentd.log" $agent_conf_file
    sed -i "/PidFile=/cPidFile=/var/log/zabbix//zabbix_agentd.pid" $agent_conf_file
else
    echo "error,$agent_conf_file no found"
    exit
fi
groupadd zabbix
useradd -g zabbix -M -s /sbin/nologin zabbix
mkdir /var/log/zabbix -p
touch /var/log/zabbix/zabbix_agentd.log
chown -R zabbix.zabbix /var/log/zabbix

if [ -f  /usr/local/zabbix/sbin/zabbix_agentd ];then
     /usr/local/zabbix/sbin/zabbix_agentd
else
    echo "error, /usr/local/zabbix/sbin/zabbix_agentd no found"
    exit
fi
netstat -anpt |grep :10050
exit
curl http://124.202.226.126:31099/scripts/zabbix_agnet_install.sh |bash