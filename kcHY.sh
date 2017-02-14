#!/bin/bash
#-------------------------------------------------------------------------------
#虚拟机模板初始化 $1 petter.qcow2
modcnf(){
yum install libguestfs-tools -y &
wait $!
[ ! -d /tmp/virtmp ]&& mkdir -p /tmp/virtmp
[ ! -d /tmp/virtmp ] &&echo "create mountpoint dir failed,please check" && exit
echo "挂载映像文件，请耐心等候..."
guestmount -i -a $stroagePool/$1 /tmp/virtmp
[ $? -ne 0 ] && echo "挂载映像文件失败，请检查"&&exit

sed  -i '1,$d' "/tmp/virtmp/etc/udev/rules.d/70-persistent-net.rules"
sed  -i '/HWADDR=/d' "/tmp/virtmp/etc/sysconfig/network-scripts/ifcfg-eth0"
sed  -i '/UUID=/d' "/tmp/virtmp/etc/sysconfig/network-scripts/ifcfg-eth0"
sed  -i '/^SELINUX=/cSELINUX=disabled' "/tmp/virtmp/etc/selinux/config"
yumcfg "/tmp/virtmp/etc/yum.repos.d/" "$yumsource"

#for ((i=2;i<255;i++))
#do
#echo "192.168.122.$i    h$i.up.com" >>/tmp/virtmp/etc/hosts
#done

sync
umount /tmp/virtmp
echo "虚拟机模板初始化完成 :)"
}

#-------------------------------------------------------------------------------
#修改新的配置文件，使其和模板的配置文件硬件信息不同
#$1 xml文件绝对路径		$2 主机名	$3 磁盘文件完整路径
modxml(){
sed -i "/<name>/c<name>$2<\/name>" "$1"
sed -i '/<uuid>/d' "$1"
sed -i '/<mac address=/d' "$1"
sed -i "/<source file=/c<source file=\'$3\'/>" "$1"
sed -i "/<driver name='qemu'/c<driver name=\'qemu\' type=\'qcow2\' cache=\'none\'/>" "$1"
sed -i '/bind/d' "$1"
}

#-------------------------------------------------------------------------------
#克隆几个虚拟机 $1 petter.xml	$2 petter.qcow2
clone(){
read -p "请输入克隆机名称前缀： " node
read -p "请输入克隆机名称的尾数的起始号:" b
read -p "请输入克隆机名称的尾数的结束号:" e
for ((i=$b;i<=$e;i++))
do
	c_hostname[$i]=$node$i
	clone1 $1 $2 ${c_hostname[$i]}
done
}

#-------------------------------------------------------------------------------
#克隆一个虚拟机 $1 petter.xml	$2 petter.qcow2 $3 c_hostname
clone1(){

[ ! -d $stroagePool ] && echo "no KVM"
c_hostname=$3
virsh dumpxml "$(echo $1 |awk -F. '{print $1}')" >/etc/libvirt/qemu/$c_hostname.xml
[ ! -f "/etc/libvirt/qemu/$c_hostname.xml" ] && echo "创建克隆机配置文件失败 ：（"&& exit 
[ -f "$stroagePool/$c_hostname.qcow2" ] && echo "$c_hostname已经存在"&& exit 
echo "分配克隆机空间，请耐心等待..."
qemu-img create -f qcow2 -b "$stroagePool/$2" "$stroagePool/$c_hostname.qcow2"	
if [ -f "/etc/libvirt/qemu/$c_hostname.xml" -a -f "$stroagePool/$c_hostname.qcow2" ];then
	modxml "/etc/libvirt/qemu/$c_hostname.xml"  $c_hostname  $stroagePool/$c_hostname.qcow2	
else
	echo "创建克隆机文件失败 ：（"
	exit
fi
virsh define /etc/libvirt/qemu/$c_hostname.xml

rpm -q libguestfs-tools || yum install libguestfs-tools -y &
[ ! -d /tmp/virtmp ]&& mkdir -p /tmp/virtmp
echo "Please wait a monment..."
guestmount -i -a "$stroagePool/$c_hostname.qcow2" /tmp/virtmp
wait $!
[ $? -ne 0 ] && echo "挂载映像文件失败，请检查"&&exit
read -p 'Please input the IP of the clone host, IPADDR=' ip
sed -i "/^IPADDR=/cIPADDR=$ip" /tmp/virtmp/etc/sysconfig/network-scripts/ifcfg-eth0
lastseg=`echo $ip|awk -F. '{print $4}'`
#echo "$c_hostname-$lastseg" >/tmp/virtmp/etc/hostname
echo "$c_hostname" >/tmp/virtmp/etc/hostname
sync
echo "The clone host is starting..."
sleep 5
umount /tmp/virtmp
sleep 5
virsh start $c_hostname
}

#-------------------------------------------------------------------------------
#删除克隆机群
undefclone(){
read -p "请输入要删除的克隆机名称前缀： " node
read -p "请输入要删除的克隆机名称的尾数起始号:" b;
read -p "请输入要删除的克隆机名称的尾数结束号:" e;
for ((i=$b;i<=$e;i++))
do
	undefclone1 $node$i
done

}

#-------------------------------------------------------------------------------
#删除一个克隆机 $1:c_hostname
undefclone1(){
	c_hostname=$1
	virsh destroy $c_hostname &>/dev/nul
	virsh undefine $c_hostname
	rm -rf "$stroagePool/$c_hostname.qcow2"
}

#-------------------------------------------------------------------------------
#安装centos6.6 $1系统安装源
virt_install(){
#LANG=en yum groupinstall "Virtualization*" -y
#service libvirtd start
#chkconfig libvirtd on
read -p "虚拟机起个名：" virtname
[ -z $virtname ] && echo "名字不能为空"&&exit
diskpath="$stroagePool/$virtname.qcow2"
qemu-img create -f qcow2 -o preallocation=metadata $diskpath  10G
[ ! -f $diskpath ] &&echo "映像文件创建失败，请检查" && exit
#virt-install --nographics -n $virtname  --os-type=linux --os-variant=rhel7 -r 2048 --arch=x86_64 --vcpus=1 -f $diskpath -w bridge=br0 -l $1 -x console=ttyS0

virt-install \
--name $virtname \
--ram 8192 \
--disk path=$diskpath,size=10 \
--vcpus 4 \
--os-type linux \
--os-variant rhel7 \
--network bridge=br0 \
--graphics none \
--console pty,target_type=serial \
--location $1 \
--extra-args "console=ttyS0,115200n8 serial"
}


#-------------------------------------------------------------------------------
#配置YUM源 $1 /etc/yum.repos.d/  $2 ftp://172.16.8.100/centos6.6 
yumcfg(){
rm -rf $1/*
yumfile=$1/yum.repo
echo "[base]">$yumfile
echo "name=base">>$yumfile
echo "enabled=1">>$yumfile
echo "gpgcheck=0">>$yumfile
echo "baseurl=$2">>$yumfile
echo ""
[ ! -s $yumfile ] && echo "创建yum配置文件失败"&&exit
cat $yumfile
}

#main-----------------------主脚本------------------------------main#
cat <<MENUDISPALY
		+-------------------+
		1  显示全部虚拟机
		2  克隆几个虚拟机
		3  删除几个克隆机
		4  克隆1个虚拟机
		5  删除1个虚拟机
		6  配置本机YUM源
		7  虚拟机模板初始化
		8  安装 centos71511
		9  删除全部克隆机
		0  退出
		+-------------------+

MENUDISPALY
read -p "请选择:  " c

#存储池
if [ ! -d /data/var/lib/libvirt/images ]
then
	mkdir /data/var/lib/libvirt/images -p
fi
stroagePool="/data/var/lib/libvirt/images"
#模板机映像文件名（根据实际文件名修改）
modeldiskfilename="centos71511.qcow2"
#modeldiskfilename="centos71511.qcow2"
#模板机配置文件名（根据实际文件名修改）
modelxmlfilename="centos71511.xml"
#modelxmlfilename="centos71511.xml"
#yum源地址（根据实际地址修改）
yumsource="ftp://172.16.2.181/centos71511"
#系统安装源（根据实际地址修改）
ossource="ftp://172.16.2.181/centos71511"

umount /tmp/virtmp &>/dev/null

case $c in
1)
	virsh list --all;;
2)
	[ ! -f "/etc/libvirt/qemu/$modelxmlfilename" ] &&echo "模板机配置文件不存在，请检查" && exit
	virsh list --all
	clone $modelxmlfilename $modeldiskfilename
	virsh list --all;;
3)
	virsh list --all

	undefclone $b $e $node
	virsh list --all;;	
4)
	[ ! -f "/etc/libvirt/qemu/$modelxmlfilename" ] &&echo "模板机配置文件不存在，请检查" && exit
	virsh list --all
	read -p "给克隆的虚拟机起个名: " c_hostname
	clone1 $modelxmlfilename $modeldiskfilename $c_hostname
	virsh list --all;;
5)
	virsh list --all
	read -p "删除哪个虚拟机?请输入名称: " c_hostname
	undefclone1 $c_hostname
	virsh list --all;;
6)
	if [ -z $yumsource ];then
		echo "YUM源错误，请检查"
	else
		yumcfg "/etc/yum.repos.d/" $yumsource
	fi;;
7)
	[ ! -f "$stroagePool/$modeldiskfilename" ] &&echo "模板机映像文件不存在，请检查" && exit
	modcnf $modeldiskfilename;;	
8)
	if [ -z $ossource ];then
		echo "系统安装源错误，请检查"
	else	
		virt_install $ossource
	fi;;
9)
	virsh list --all
	for c_hostname in `virsh list --all |sed '1,2d;$d'|awk '{print $2}'|grep -v $(echo $modeldiskfilename|awk -F. '{print $1}')`
	do
	        echo "undefclone1 $c_hostname"
	done
	virsh list --all
	;;
0)
	exit;;
	
	*) 
		echo "1 or 2 or ...6，0";exit;;
esac
