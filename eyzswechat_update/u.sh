#!/bin/bash
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
				[ ! -f $dist/$l ] && echo -e "X\tfile\t$dist/$l" || echo -e "Y\tfile\t$dist/$l"
			elif [ -d $fd/$l ];then
				[ ! -d $dist/$l ] && echo -e "X\tdir\t$dist/$l" || echo -e "Y\tdir\t$dist/$l"
			else
				echo -e "X\t\t:$fd/$l"
			fi

		done
		
	fi
	#如果源是目录，进行目录检查	
	if [ -f $src/$fd ];then
		[ ! -f $dist/$fd ] && echo -e "X\tfile\t$dist/$fd" || echo -e "Y\tfile\t$dist/$fd"
	elif [ -d $fd -a `echo $fd |rev|cut -c 1` != / ];then
		[ ! -d $dist/$fd ] && echo -e "X\tdir\t$dist/$fd" || echo -e "Y\tdir\t$dist/$fd"
	fi
		

done

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
                                if [ ! -f $dist/$l ];then
					echo -e "X\tfile\t$dist/$l"
				else
					echo -e "Y\tfile\t$dist/$l"
					date_str=`date +%Y%m%d%H%M%S`
					#备份原文件
			        	cp $dist/$l $dist/$l-$date_str.bak
				fi
				#将目录/下的文件拷贝至目录路径下
			        cp $src/$fd/$l $dist/$l
				#ls -l $dist/$l*
				stat $dist/$l-$date_str.bak
		                stat $dist/$l
	
                        elif [ -d $fd/$l ];then
                                [ ! -d $dist/$l ] && echo -e "X\tdir\t$dist/$l" || echo -e "Y\tdir\t$dist/$l"
                        else
                                echo -e "X\t\t:$fd/$l"
                        fi

                done

        fi
	#如果是文件，则进行备份替换
        if [ -f $src/$fd ];then
                if [ ! -f $dist/$fd ];then
			echo -e "X\tfile\t$dist/$fd"
		else
			echo -e "Y\tfile\t$dist/$fd"
			date_str=`date +%Y%m%d%H%M%S`
			cp $dist/$fd $dist/$fd-$date_str.bak
		fi
		cp $src/$fd $dist/$fd
		#ls -l $dist/$fd*
		stat $dist/$fd-$date_str.bak
		stat $dist/$fd

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
