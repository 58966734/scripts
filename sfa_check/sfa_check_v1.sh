#!/bin/bash

#winchannel sfa config parameter check script
#maintainer liuliguo 20170510

catalina(){
# $TOMCAT_DIR\bin\catalina.sh
# set TITLE=test 8080
# set "line=!line:kimberly sfa web 8080=%TITLE%!"
# ..&JAVAOPTS..
# jdk..
echo "$1"
echo "+------------------------begin"
grep --color "TITLE=" "$1"
grep --color "JAVA_OPTS=" "$1"
grep --color "CATALINA_OPTS=" "$1"
echo "+------------------------end"

}

server_xml(){
# $TOMCAT_DIR\conf\server.xml
# port
# appBase=
echo "$1"
echo "+-------------------------begin"
grep --color "shutdown=" "$1"
grep --color "Connector executor=" "$1"
grep --color "Connector port=" "$1"
grep --color "appBase" "$1"
echo "+-------------------------end"

}

sfa_properties(){
# $TOMCAT_DIR\webapps\ROOT\WEB-INF\classes\config\sfa.properties
# project=HenkelRetail_8880
# mediaPath=
# mediaServerUrl=
# mobile.cache.maxfiles=2
# mobile.cache.filepath=D:\app\SFA_HenkelRetail\app_root_mobile\mcache\ (.....)
# mobile.cacheType=2(1...,2.Mongo)
# mongodb.serverIp=127.0.0.1
# mongodb.port=27017
# mongodb.username=app_user
# mongodb.password=YyNu58NQdsxynbYPz52Z2g==
# mongodb.poolsize=200
echo "$1"
echo "+----------------------------begin"
grep --color "^project=" "$1"
grep --color "^mediaPath=" "$1"
grep --color "^mediaServerUrl=" "$1"
grep --color "^mobile.cache.maxfiles=" "$1"
grep --color "^mobile.cache.filepath=" "$1"
grep --color "^mobile.cacheType=" "$1"
grep --color "^mongodb.serverIp=" "$1"
grep --color "^mongodb.port=" "$1"
grep --color "^mongodb.username=" "$1"
grep --color "^mongodb.password=" "$1"
grep --color "^mongodb.poolsize=" "$1"
echo "+---------------------------end"


}
callPlanConfig_properties(){
# $TOMCAT_DIR\webapps\ROOT\WEB-INF\classes\config\callPlanConfig.properties
# ....
# tabKey=HenkelRetail_8880
echo "$1"
echo "+-------------------------begin"
grep --color "^tabKey=" "$1"
echo "+-------------------------end"


}

applicationContext_task_xml(){
# $TOMCAT_DIR\webapps\ROOT\WEB-INF\classes\spring\applicationContext-task.xml
# ..<!--  -->..........
# <!--<ref bean="dailyTransJobCronTrigger"/>-->  ..
# <!--<ref bean="refreshDataCronTrigger" />-->  ..
# <!--<ref bean="refreshCacheTrigger" /> --> ..
echo "$1"
echo "+-------------------------begin"
grep --color "dailyTransJobCronTrigger" "$1"
grep --color "refreshDataCronTrigger" "$1"
grep --color "refreshCacheTrigger" "$1"
echo "+-------------------------end"

}

task_properties(){
# $TOMCAT_DIR\webapps\ROOT\WEB-INF\classes\config\task.properties
# dailyTransJobCronTrigger.trigger.cronExpression=0 0 2 * * ?  .././././....
# refreshDataCronTrigger.trigger.cronExpression=0 0 4 * * ?
# refreshCacheTrigger.trigger.cronExpression=0 0 5 * * ?
echo "$1"
echo "+-------------------------begin"
grep --color "dailyTransJobCronTrigger.trigger.cronExpression=" "$1"
grep --color "refreshDataCronTrigger.trigger.cronExpression=" "$1"
grep --color "refreshCacheTrigger.trigger.cronExpression=" "$1"
echo "+------------------------end"

}
base_properties(){
# $TOMCAT_DIR\webapps\ROOT\WEB-INF\classes\config\base.properties
# job.baseJob=true
# server.type.value=UAT testing  ......
# security.property.placeholder=true	
echo "$1"
echo "+--------------------------begin"
grep --color "^job.baseJob=" "$1"
grep --color "^server.type.value=" "$1"
grep --color "^security.property.placeholder=" "$1"
echo "+--------------------------end"


}

dw_properties(){
# $TOMCAT_DIR\webapps\ROOT\WEB-INF\classes\config\dw.properties
# cache.persistent=true
# cache.persistent.dir=dw....
# ...tomcat..baseJob............................
echo "$1"
echo "+-------------------------begin"
grep --color "^cache.persistent=" "$1"
grep --color "^cache.persistent.dir=" "$1"
echo "+--------------------------end"

}
jdbc_properties(){
# $TOMCAT_DIR\webapps\ROOT\WEB-INF\classes\config\jdbc.properties
# jdbc.url=jdbc:jtds:sqlserver://192.168.1.17/dms_test2
# jdbc.username=sa
# jdbc.password=o5YLd9EWJBqKCQGFGlf6ibUtOz1Nfl1UkiaFdZS2Z0g=
echo "$1"
echo "+-------------------------begin"
grep --color "^jdbc.url=" "$1"
grep --color "^jdbc.username=" "$1"
grep --color "^jdbc.password=" "$1"
echo "+--------------------------end"
}

TOMCAT_DIR="$1"
if [ -z $TOMCAT_DIR ];then
	echo "tips:\$1 can not be NULL,usage:sfa_check_v1 /opt/app/sfa_liuliguo_exam/web_8041"
	exit 1
fi

if [ ! -d $TOMCAT_DIR ];then
	echo "$TOMCAT_DIR is not valid directory"
	exit 2
fi

if [ ! -f $TOMCAT_DIR/conf/server.xml ];then
	echo "$TOMCAT_DIR is not valid CATALINA_HOME directory"
	exit 3
fi


#TOMCAT_DIR="/opt/app/sfa_liuliguo_exam/web_8041"
echo "$TOMCAT_DIR/bin/catalina.sh" >filelists.txt
echo "$TOMCAT_DIR/conf/server.xml">>filelists.txt

appBase=`grep appBase "$TOMCAT_DIR/conf/server.xml" |awk -F= '{print $3}'|awk -F\" '{print $2}'`
if [ "$appBase" != "webapps" ];then
	echo "$appBase/ROOT/WEB-INF/classes/config/sfa.properties" >>filelists.txt
	echo "$appBase/ROOT/WEB-INF/classes/config/callPlanConfig.properties" >>filelists.txt
	echo "$appBase/ROOT/WEB-INF/classes/spring/applicationContext-task.xml" >>filelists.txt
	echo "$appBase/ROOT/WEB-INF/classes/config/task.properties" >>filelists.txt
	echo "$appBase/ROOT/WEB-INF/classes/config/base.properties" >>filelists.txt
	echo "$appBase/ROOT/WEB-INF/classes/config/dw.properties" >>filelists.txt
	echo "$TOMCAT_DIR/APP_HOME/config/jdbc.properties" >>filelists.txt
	echo "$appBase/ROOT/WEB-INF/classes/config/jdbc.properties" >>filelists.txt
else
	echo "$TOMCAT_DIR/webapps/ROOT/WEB-INF/classes/config/sfa.properties" >>filelists.txt
	echo "$TOMCAT_DIR/webapps/ROOT/WEB-INF/classes/config/callPlanConfig.properties" >>filelists.txt
	echo "$TOMCAT_DIR/webapps/ROOT/WEB-INF/classes/spring/applicationContext-task.xml" >>filelists.txt
	echo "$TOMCAT_DIR/webapps/ROOT/WEB-INF/classes/config/task.properties" >>filelists.txt
	echo "$TOMCAT_DIR/webapps/ROOT/WEB-INF/classes/config/base.properties" >>filelists.txt
	echo "$TOMCAT_DIR/webapps/ROOT/WEB-INF/classes/config/dw.properties" >>filelists.txt
	echo "$TOMCAT_DIR/APP_HOME/config/jdbc.properties" >>filelists.txt
	echo "$TOMCAT_DIR/webapps/ROOT/WEB-INF/classes/config/jdbc.properties" >>filelists.txt
fi

for filename in `cat filelists.txt`
do
	if [ ! -f $filename ];then
		echo "$filename not exist"
		continue
	fi
	file=`basename $filename`
	case $file in
	'catalina.sh')
		catalina $filename
		;;
	'server.xml')
		server_xml $filename
		;;
	'sfa.properties')
		sfa_properties $filename
		;;
	'callPlanConfig.properties')
		callPlanConfig_properties $filename
		;;
	'applicationContext-task.xml')
		applicationContext_task_xml $filename
		;;
	'task.properties')
		task_properties $filename
		;;
	'base.properties')
		base_properties $filename
		;;
	'dw.properties')
	    dw_properties $filename
		;;
	'jdbc.properties')
		jdbc_properties $filename
		;;
	*)
		echo "$filename not exist,please check"
		;;
	esac
done



