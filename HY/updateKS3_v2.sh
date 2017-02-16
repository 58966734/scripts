#!/bin/bash

#检查参数1是否为空
if [ -z $1 ];then
    cat <<EOF

    ERROR,\$1 is missing

    for example:

      sh updateKS3_v2.sh 20170216_01.tar

EOF
    exit
fi
#检查文件是否存在
if [ ! -f $1 ];then
    echo "$1 not found"
    exit
fi

#检查包文件名的命名规则是否符合规定
echo $1|grep '2017[01][1234567890][123][1234567890][_][0123456789][1234567890]\.tar' >/dev/nul
if [ $? -ne 0 ];then
    echo "ERROR,$1 is Not in accordance with the provisions"
    echo -e "for example :\n\n\t 20170216_01.tar"
    exit
fi

#提取打包文件的名（规定的日期格式名称，去除后缀）
datedir=`echo "$1"|cut -d "." -f 1`
#在当前目录下创建这个规定的日期格式名称的目录
mkdir -p ./$datedir
if [ $? -ne 0 ];then
    echo "ERROR,./$datedir create failed"
    exit
fi
#将包文件解压至那个日期目录中
tar xf "$1" -C ./$datedir
#提取出包文件中tar包文件名
tarfile=`ls ./$datedir`
#进入到那个日期目录
cd ./$datedir
#解压刚才提取出来的tar包至当前目录
tar xf $tarfile
#删除掉这个tar包
rm $tarfile
#提取出二次解压出来的jar文件名
jarfile=`ls *.jar`
#确定是哪个环境的（测试？预发布还是正式？）
envdir=`echo ${jarfile/Main.jar/}`
#在那个环境文件夹创建此次更新文件的目录
if [ ! -d /data/dist/$envdir ];then
    echo "ERROR,/data/dist/$envdir is not exist"
    rm -rf ../$datedir
    exit
fi
if [ -d /data/dist/$envdir/$datedir ];then
    echo "ERROR,/data/dist/$envdir/$datedir already exist"
    rm -rf ../$datedir
    exit
fi
mkdir -p /data/dist/$envdir/$datedir
#将已经解压好的更新文件移动过去
mv ../$datedir/ /data/dist/$envdir/

#检查是否更新成功
if [ -f /data/dist/$envdir/$datedir/$jarfile ];then
    echo -e "\nINFO,/data/dist/$envdir/$datedir update sucess\n"
else
    echo "ERROR,/data/dist/$envdir/$datedir update failed"
fi

#停止当前运行的jar进程
jarpid=`ps -aux |grep $jarfile |grep -v grep|awk '{print $2}'`
if [ ! -z $jarpid ];then
    kill $jarpid
fi
ps -aux |grep $jarfile |grep -v grep
echo -e "\n/data/dist/$envdir/$datedir/$jarfile will restart\n"
echo -e "\nkill $jarpid ing,please wait...\n"
sleep 5
#启动此次更新的jar进程
java -jar /data/dist/$envdir/$datedir/$jarfile &
ps -aux |grep $jarfile |grep -v grep
