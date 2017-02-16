#!/bin/bash

#������1�Ƿ�Ϊ��
if [ -z $1 ];then
    cat <<EOF

    ERROR,\$1 is missing

    for example:

      sh updateKS3_v2.sh 20170216_01.tar

EOF
    exit
fi
#����ļ��Ƿ����
if [ ! -f $1 ];then
    echo "$1 not found"
    exit
fi

#�����ļ��������������Ƿ���Ϲ涨
echo $1|grep '2017[01][1234567890][123][1234567890][_][0123456789][1234567890]\.tar' >/dev/nul
if [ $? -ne 0 ];then
    echo "ERROR,$1 is Not in accordance with the provisions"
    echo -e "for example :\n\n\t 20170216_01.tar"
    exit
fi

#��ȡ����ļ��������涨�����ڸ�ʽ���ƣ�ȥ����׺��
datedir=`echo "$1"|cut -d "." -f 1`
#�ڵ�ǰĿ¼�´�������涨�����ڸ�ʽ���Ƶ�Ŀ¼
mkdir -p ./$datedir
if [ $? -ne 0 ];then
    echo "ERROR,./$datedir create failed"
    exit
fi
#�����ļ���ѹ���Ǹ�����Ŀ¼��
tar xf "$1" -C ./$datedir
#��ȡ�����ļ���tar���ļ���
tarfile=`ls ./$datedir`
#���뵽�Ǹ�����Ŀ¼
cd ./$datedir
#��ѹ�ղ���ȡ������tar������ǰĿ¼
tar xf $tarfile
#ɾ�������tar��
rm $tarfile
#��ȡ�����ν�ѹ������jar�ļ���
jarfile=`ls *.jar`
#ȷ�����ĸ������ģ����ԣ�Ԥ����������ʽ����
envdir=`echo ${jarfile/Main.jar/}`
#���Ǹ������ļ��д����˴θ����ļ���Ŀ¼
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
#���Ѿ���ѹ�õĸ����ļ��ƶ���ȥ
mv ../$datedir/ /data/dist/$envdir/

#����Ƿ���³ɹ�
if [ -f /data/dist/$envdir/$datedir/$jarfile ];then
    echo -e "\nINFO,/data/dist/$envdir/$datedir update sucess\n"
else
    echo "ERROR,/data/dist/$envdir/$datedir update failed"
fi

#ֹͣ��ǰ���е�jar����
jarpid=`ps -aux |grep $jarfile |grep -v grep|awk '{print $2}'`
if [ ! -z $jarpid ];then
    kill $jarpid
fi
ps -aux |grep $jarfile |grep -v grep
echo -e "\n/data/dist/$envdir/$datedir/$jarfile will restart\n"
echo -e "\nkill $jarpid ing,please wait...\n"
sleep 5
#�����˴θ��µ�jar����
java -jar /data/dist/$envdir/$datedir/$jarfile &
ps -aux |grep $jarfile |grep -v grep
