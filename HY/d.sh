#!/bin/bash
dockerrmfall(){
	docker ps -a |awk '{print $1}'|sed '1d'|xargs docker rm -f
}
dockerpsa(){
	docker ps -a
}

dockerimages(){
	docker images
}
menu(){
	cat <<eof
+---------------------------------------+
|	1 Remove all containers
|	2 list all images
|	3 list all contailners
|	0 exit
+---------------------------------------+
eof
}

#while true
#do
	menu
	read -p "please choice: " c
	case $c in
		1)
			dockerpsa
			dockerrmfall
			dockerpsa
			;;
		2)
			dockerimages
			;;
		3)
			dockerpsa
			;;
		0)
			exit 0
			;;
		*)	echo 1,2,3...
			;;
	esac
#done
