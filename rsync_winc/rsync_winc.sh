#!/bin/bash

#gen_password_file
gen_password_file(){
	passwd="$1"
	user="$2"
	src_ip="$3"
	[ -d /etc/rsyncd ] || mkdir -p /etc/rsyncd
	echo "$passwd" >"/etc/rsyncd/$user_$src_ip.sec"
	chmod 600 "/etc/rsyncd/$user_$src_ip.sec"
	echo "/etc/rsyncd/$user_$src_ip.sec"
}

#src_gen
src_gen(){
	user="$1"
	src_ip="$2"
	src_path="$3"
	echo "$user@$src_ip::$src_path"
}

#cron_task
cron_task(){
	flag=0
	M=$1
	h=$2
	d=$3
	m=$4
	w=$5
	nM=`date +%M`
	nh=`date +%H`
	nd=`date +%d`
	nm=`date +%m`
	nw=`date +%w`
	let flag+=`compare $M $nM`
	let flag+=`compare $h $nh`
	let flag+=`compare $d $nd`
	let flag+=`compare $m $nm`
	let flag+=`compare $w $nw`
	if [ $flag == 5 ];then
		echo 1
	else
		echo 0
	fi
}
#compare n nn
compare(){
	if [ $1 == '#' ];then
                echo 1
        elif [ $1 == $2 ];then
                echo 1
        else
                echo 0
        fi
}


#rsync_pull
rsync_pull(){
	port=$1
	password_file=$2
	src=$3
	dist_path=$4
	logfile=$5
	rsync_options=$6
	echo `date` >>./rsync_winc_log/$logfile
	if [ $DEBUG -eq 1 ];then
		rsync --port="$port" --password-file="$password_file" "$src" "$dist_path" $rsync_options
	else
		rsync --port="$port" --password-file="$password_file" "$src" "$dist_path" $rsync_options >>./rsync_winc_log/$logfile &
	fi
}

#main
DEBUG=1
if [ ! -f rsync_winc.conf ];then
	echo please cd /data/scripts
        exit
fi

cat rsync_winc.conf | while read line;
do
        echo "$line" |grep -E '^[ ]*#|^$' && continue

        port=`echo "$line" | awk -F\; '{print $1}'`
        rsync_options=`echo "$line" | awk -F\; '{print $2}'`
        passwd=`echo "$line" | awk -F\; '{print $3}'`
	user=`echo "$line" | awk -F\; '{print $4}'`
	src_ip=`echo "$line" | awk -F\; '{print $5}'`
	src_path=`echo "$line" | awk -F\; '{print $6}'`
	dist_path=`echo "$line" | awk -F\; '{print $7}'`
	cron=`echo "$line" | awk -F\; '{print $8}'`

	if [ $DEBUG -eq 1 ];then
		f=1
	else
		f=`cron_task $cron`
	fi

	[ $f -ne 1 ] && continue
	[ -z "$passwd" -o -z "$user" -o -z "$src_ip" ] && continue

	password_file=`gen_password_file $passwd $user $src_ip`
	src=`src_gen $user $src_ip $src_path`
	date_str=`date +%Y%m%d%H%M%S`


	case $rsync_options in
		app_backup):
			rsync_options="-avz --progress --exclude-from=app_backup.conf"
			dist=$dist_path/$src_ip/app/`echo $src_path|sed 's#/#_#g'`/$date_str
			;;
		photos_backup):
			rsync_options="-avz --delete --progress"
			dist=$dist_path/$src_ip/photos/`echo $src_path|sed 's#/#_#g'`
			;;
		DB_backup):
			rsync_options="-avz --delete --progress"
			dist=$dist_path/$src_ip/DB/`echo $src_path|sed 's#/#_#g'`
			;;
		*):
			dele=`echo "$rsync_options" |grep -c 'delete'`
			if [ $dele -eq 1 ];then
				dist=$dist_path/$src_ip/`echo $src_path|sed 's#/#_#g'`
			else
				dist=$dist_path/$src_ip/`echo $src_path|sed 's#/#_#g'`/$date_str
			fi
	esac

	logfile=`echo $dist|sed 's#\.#_#g'|sed 's#/#_#g'`_`date +%Y%m%d`.log

	if [ ! -f ./rsync_winc_log/$logfile ];then
		if [ ! -d "$dist" ];then
                	mkdir -p "$dist"
        	fi
		rsync_pull "$port" "$password_file" "$src" "$dist" "$logfile"  "$rsync_options"
	fi
	
done

exit
grep --color 'sent.*bytes.*received.*bytes/sec' /data/scripts/rsync_winc_log/* |awk -F: '{print $1}'
