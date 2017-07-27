#!/bin/bash

#请先在光驱中放入rhel6.8安装光盘再运行此脚本

#无人值守安装rhel6u8的kickstart文件
mkdir /ftp_root/ks -p
cat >/ftp_root/ks/rhel6u8.cfg <<eof
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Firewall configuration
firewall --enabled --http --ftp --ssh --telnet --smtp
# Install OS instead of upgrade
install
# Use network installation
url --url="ftp://192.168.1.25/rhel6u8"
# Root password
rootpw --plaintext 1
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use graphical install
graphical
firstboot --disable
# System keyboard
keyboard us
# System language
lang zh_CN
# SELinux configuration
selinux --enforcing
# Installation logging level
logging --level=info
# Reboot after installation
reboot
# System timezone
timezone  Asia/Shanghai
# Network information
network  --bootproto=dhcp --device=eth0 --onboot=on
# System bootloader configuration
bootloader --location=mbr
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all  
# Disk partitioning information
part /boot --fstype="ext4" --size=200
part swap --fstype="swap" --size=4096
part / --fstype="ext4" --grow --size=1

%packages
@basic-desktop
@chinese-support
@desktop-debugging
@desktop-platform
@fonts
@general-desktop
@graphical-admin-tools
@input-methods
@kde-desktop
@legacy-x
@remote-desktop-clients
@x11

%end

eof

#挂载ISO映像并实现开机自动
mkdir /ftp_root/rhel6u8
echo "/dev/cdrom1 /ftp_root/rhel6u8 iso9660 defaults,loop   0       0" >>/etc/fstab
mount -a

#配置YUM源
rm -rf /etc/yum.repos.d/*
cat >/etc/yum.repos.d/yum.repo <<eof
[yum]
name=petter
enabled=1
gpgcheck=0
baseurl=file:///ftp_root/rhel6u8
eof

#安装所需组件
yum -y install dhcp tftp-server vsftpd syslinux bind bind-chroot bind-utils

#配置静态IP
cat >/etc/sysconfig/network-scripts/ifcfg-eth0 <<eof
DEVICE=eth0
IPADDR=192.168.1.25
NETMASK=255.255.255.0
BOOTPROTO=static
ONBOOT=yes
eof
service network restart

#配置DHCP
#cp -rf /usr/share/doc/dhcp-4.1.1/dhcpd.conf.sample /etc/dhcp/dhcpd.conf 
cat > /etc/dhcp/dhcpd.conf << EOF
subnet 192.168.1.0 netmask 255.255.255.0 {
range dynamic-bootp 192.168.1.25 192.168.1.26;
next-server 192.168.1.25;
filename="pxelinux.0";
option domain-name-servers 192.168.1.25;
default-lease-time 600;
max-lease-time 7200;
}
EOF

service dhcpd restart
chkconfig dhcpd on

#配置DNS
cat > /etc/named.conf << EOF
options {
        directory "/var/named";		//数据库文件存放的位置
};

zone "example.com" {				//创建域example.com
        type master;
        file "example.com.zone";   //存放区域文件的文件名
};
zone "1.168.192.in-addr.arpa" {                    //声明反向区域
        type master;
        file "192.168.1.zone";
};
EOF

cp -rf /var/named/named.localhost  /var/named/chroot/var/named/example.com.zone
sed -i '/AAAA/d' /var/named/chroot/var/named/example.com.zone
for ((i=1;i<255;i++))
do
echo -e "client$i\tA\t192.168.1.$i" >>/var/named/chroot/var/named/example.com.zone
done
chown  named.named /var/named/chroot/var/named/example.com.zone


cp -rf /var/named/named.loopback  /var/named/chroot/var/named/192.168.1.zone
sed -i '/AAAA/d' /var/named/chroot/var/named/192.168.1.zone
for ((i=1;i<255;i++))
do
echo -e "$i\tPTR\tclient$i.example.com." >>/var/named/chroot/var/named/192.168.1.zone
done
chown  named.named /var/named/chroot/var/named/192.168.1.zone

service named start
chkconfig named on

#配置TFTP
sed -i '/disable/cdisable = no' /etc/xinetd.d/tftp
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
cp -rf /ftp_root/rhel6u8/isolinux/* /var/lib/tftpboot/

mkdir /var/lib/tftpboot/rhel6u8 -p
cp -rf /ftp_root/rhel6u8/isolinux/* /var/lib/tftpboot/rhel6u8

mkdir /var/lib/tftpboot/pxelinux.cfg
#cp /var/lib/tftpboot/isolinux.cfg /var/lib/tftpboot/pxelinux.cfg/default

cat > /var/lib/tftpboot/pxelinux.cfg/default <<EOF
default vesamenu.c32
#prompt 1
timeout 600 

display boot.msg

menu background splash.jpg
menu title Welcome to rhel6u8!
menu color border 0 #ffffffff #00000000
menu color sel 7 #ffffffff #ff000000
menu color title 0 #ffffffff #00000000
menu color tabmsg 0 #ffffffff #00000000
menu color unsel 0 #ffffffff #00000000
menu color hotsel 0 #ff000000 #ffffffff
menu color hotkey 7 #ffffffff #ff000000
menu color scrollbar 0 #ffffffff #00000000

label linux
  menu label ^Install rhel6.8
  menu default
  kernel rhel6u8/vmlinuz
  append initrd=rhel6u8/initrd.img
  
label linux
  menu label ^Install rhel6.8 auto
  menu default
  kernel rhel6u8/vmlinuz ks=ftp://192.168.1.25/ks/rhel6u8.cfg
  append initrd=rhel6u8/initrd.img
EOF

service xinetd restart
chkconfig xinetd on

#配置FTP
sed '/^anon_root=/d' /etc/vsftpd/vsftpd.conf
sed -i '12aanon_root=/ftp_root' /etc/vsftpd/vsftpd.conf
service vsftpd restart
chkconfig vsftpd on

setenforce 0
sed  -i '/^SELINUX=/cSELINUX=disabled' "/etc/selinux/config"
service iptables stop
chkconfig iptables off
