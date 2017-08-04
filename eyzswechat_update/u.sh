#!/bin/bash

###更新文件处理函数###
updateFile(){
	#文件名
	file=$1
	#源路径
	sDir=$2
	#目标路径
	dDir=$3
	#检查还是更新:0为检查1为更新
	checkOrDo=$4
	#若源文件有效
	if [ -f $sDir/$file ];then
		date_str=`date +%Y%m%d%H%M%S`
		#目标路径下不存在这个文件
		if [ ! -f $dDir/$file ];then
				echo -e "X\tfile\t$dDir/$file"
		#目标路径下存在这个文件
		else
			echo -e "Y\tfile\t$dDir/$file"
			if [ $checkOrDo -eq 1 ];then
				cp $dDir/$file $dDir/$file-$date_str.bak
				if [ ! -f $dDir/$file-$date_str.bak ];then
					echo "ERROR,$dDir/$file-$date_str.bak backup failed"
					exit
				else
					stat $dDir/$file-$date_str.bak
				fi
			fi
		fi
		if [ $checkOrDo -eq 1 ];then
			cp $sDir/$file $dDir/$file
			#ls -l $dDir/$file*
			stat $dDir/$file
		fi
	fi
}

###main###
src=`pwd`
if [ -z $src ];then
	echo \$! can not null
	exit
fi
#检查更新说明文件是否存在
if [ ! -f 更新说明.txt ];then
	echo "not found 更新说明.txt"
	exit
fi
#对更新说明文件进行编码转换，并在结尾追加一个空行
more 更新说明.txt
dos2unix 更新说明.txt
echo -e '\n' >>更新说明.txt
#更新说明文件逐行处理
cat $src/更新说明.txt | while read line;
do
	#过滤掉以#开头的及空行
	echo "$line" |grep -E '^[ ]*#|^$' && continue
	fd=`echo "$line" | awk -F\; '{print $1}'`
	dist=`echo "$line" | awk -F\; '{print $2}'`
	#判断目标路径是否存在
	[ ! -d $dist ] && echo -e "X\tdir\t$dist" || echo -e "Y\tdir\t$dist"
	#如果源是目录/，进行目录下面的文件检查
	if [ `echo $fd |rev|cut -c 1` == / ];then
		for l in `ls $fd`
		do
			
			if [ -f $fd/$l ];then
				updateFile $l $src $dist 0
			elif [ -d $fd/$l ];then
				[ ! -d $dist/$l ] && echo -e "X\tdir\t$dist/$l" || echo -e "Y\tdir\t$dist/$l"
			else
				echo -e "X\t\t:$fd/$l"
			fi

		done
		
	fi
	#如果源是文件，进行文件检查	
	if [ -f $src/$fd ];then
		updateFile $fd $src $dist 0
	#如果是目录，进行目标检查
	elif [ -d $fd -a `echo $fd |rev|cut -c 1` != / ];then
		[ ! -d $dist/$fd ] && echo -e "X\tdir\t$dist/$fd" || echo -e "Y\tdir\t$dist/$fd"
	fi
		

done

#输入y则进行更新操作否则退出
read -n1 -p "continue?" confirm
if [ "$confirm" == "y" ];then
	echo "y"
else
	echo -e "\nabort"
	exit
fi

cat $src/更新说明.txt | while read line;
do
        echo "$line" |grep -E '^[ ]*#|^$' && continue
        fd=`echo "$line" | awk -F\; '{print $1}'`
        dist=`echo "$line" | awk -F\; '{print $2}'`
        #判断目标路径是否存在
        [ ! -d $dist ] && echo -e "X\tdir\t$dist" || echo -e "Y\tdir\t$dist"

        if [ `echo $fd |rev|cut -c 1` == / ];then
                for l in `ls $fd`
                do

                        if [ -f $fd/$l ];then
							updateFile $l $src $dist 1
                        elif [ -d $fd/$l ];then
                                [ ! -d $dist/$l ] && echo -e "X\tdir\t$dist/$l" || echo -e "Y\tdir\t$dist/$l"
                        else
                                echo -e "X\t\t:$fd/$l"
                        fi

                done

        fi
		#如果源是文件，则进行备份替换
        if [ -f $src/$fd ];then
			updateFile $fd $src $dist 1
        elif [ -d $fd -a `echo $fd |rev|cut -c 1` != / ];then
                if [ ! -d $dist/$fd ];then
			echo -e "X\tdir\t$dist/$fd"
			#将目录拷贝至目录目录下
			cp -r $src/$fd $dist/
			ls -l $dist/$fd
		else
			echo -e "Y\tdir\t$dist/$fd"
		fi
        fi


done

