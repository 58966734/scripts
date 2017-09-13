#!/bin/bash
cdir=`dirname $0`
echo $cdir

username=`whoami`
if [ "$username" != "root" ];then
  echo "You must run this script as root user !"
  exit 1
fi

cat <<EOF >/etc/sysconfig/i18n
#LANG="en_US.UTF-8"
#SYSFONT="latarcyrheb-sun16"

LANG="zh_CN.GB18030"
LANGUAGE="zh_CN.GB18030:zh_CN.GB2312:zh_CN"
SUPPORTED="zh_CN.GB18030:zh_CN:zh:en_US.UTF-8:en_US:en"
SYSFONT="lat0-sun16"
EOF

cat > /etc/security/limits.conf << EOF
*           soft   nofile       65536
*           hard   nofile       65536
EOF


echo "session    required  /lib64/security/pam_limits.so" >> /etc/pam.d/login

#disable selinux
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
echo 0 > /selinux/enforce
setenforce 0


#disbale iptables
#service iptables stop
#chkconfig iptables off
#service ip6tables stop
#chkconfig ip6tables off
echo "NETWORKING_IPV6=off" >> /etc/sysconfig/network

cat <<EOF>>/etc/modprobe.d/dist.conf
alias net-pf-10 off
alias ipv6 off
EOF

#turn off other stuff
service cups stop
chkconfig cups off

#tune kernel parametres
cat >> /etc/sysctl.conf << EOF
net.core.rmem_default = 1048576
net.core.rmem_max = 1048576
net.core.wmem_default = 262144
net.core.wmem_max = 262144
EOF
/sbin/sysctl -p
