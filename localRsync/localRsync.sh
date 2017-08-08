#!/bin/bash

localRsync(){
        #定义项目名称
        projectName=$1
        srcPath=$2
        #定义目标路径
        distPath=$3
        #定义是程序还是数据库
        dataType=$4
        #定义rsync参数
        rsyncOption=$5

        #检查参数均不为空
        if [ ! -z $projectName -a -d $srcPath -a -d $distPath -a ! -z $dataType ];then
		#定义备份目标路径
		distPath_1=$distPath/$projectName/$dataType/$projectName-$dataType
		if [ ! -d $distPath_1 ];then
			mkdir -p $distPath_1
		fi

		cd $srcPath
		#开始同步
		datestr=`date +%Y%m%d`
		logfile=$distPath/$projectName/$dataType/$projectName-$dataType-$datestr.log
		rsync $5 . $distPath_1 >>$logfile
		cd $distPath/$projectName/$dataType
		if [ ! -f $projectName-$dataType-$datestr.tar.gz ];then
			#对备份文件进行打包
			tar czf $projectName-$dataType-$datestr.tar.gz $distPath_1
		else
			echo "Error,$projectName-$dataType-$datestr.tar.gz already exist"
		fi
        fi
}
#main
if [ ! -f localRsync.conf ];then
        echo please cd /data/scripts
        exit
fi

cat localRsync.conf | while read line;
do
        echo "$line" |grep -E '^[ ]*#|^$' && continue
        projectName=`echo "$line" | awk -F\; '{print $1}'`
        srcPath=`echo "$line" | awk -F\; '{print $2}'`
        distPath=`echo "$line" | awk -F\; '{print $3}'`
        dataType=`echo "$line" | awk -F\; '{print $4}'`
        rsyncOption=`echo "$line" | awk -F\; '{print $5}'`
        localRsync "$projectName" "$srcPath" "$distPath" "$dataType" "$rsyncOption"
done

