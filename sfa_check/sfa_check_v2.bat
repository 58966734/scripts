@echo on
@echo off
setlocal enabledelayedexpansion
title WINCHANNEL FOR YW
mode con cols=120 lines=2000
color 0a

:BEGIN
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
echo "winchannel sfa �����ļ�����һ��(ע:·���в����пո�)
echo "���ò�����j:java/c:cls/n:netstat/o:notepad/oo:notepad++/q:exit"
echo "d:jmap/k:kill/p:path                                          "
echo "MAINTAINER LiuLiguo v2017070701(���Լ�Ԥ��������)             "
echo _______________________________________________________________
set TOMCAT_DIR=null
rem set TOMCAT_DIR=D:\APP\sfa_sanofirx
set /p TOMCAT_DIR= "�������ճ��tomcat��Ŀ¼·����س�: "

if "%TOMCAT_DIR%"=="null" echo The TOMCAT_DIR is null ?????? & goto :BEGIN
if "%TOMCAT_DIR%"=="c" cls & goto :BEGIN
if "%TOMCAT_DIR%"=="q" exit
rem if "%TOMCAT_DIR%"=="j" ( wmic process where name='java.exe'  get processid,commandline>javasnapshot.txt & start notepad.exe javasnapshot.txt & goto :BEGIN )
if "%TOMCAT_DIR%"=="j" ( wmic process where name='java.exe'  get processid,commandline>javasnapshot.txt & type javasnapshot.txt | sed -n -r "s/.*home=(.*)-D.*start[ ]*([0-9]+*) /\1\2/p" >js.txt & type js.txt & goto :BEGIN )

if "%TOMCAT_DIR%"=="p" ( set /p str= "�������ճ��Ҫ��ѯ�Ľ�����������" & wmic process |findstr -v findstr|findstr !str! & goto :BEGIN )
if "%TOMCAT_DIR%"=="n" ( set /p pid= "������PID��˿ںŻ�����״̬�ַ�������LISTEN�ȣ����Բ鿴��Ӧ������״̬:" & netstat -ano| findstr -v findstr | findstr "!pid!" & goto :BEGIN )
if "%TOMCAT_DIR%"=="k" ( set /p pid= "������Ҫ�����Ľ���PID:" & taskkill/f /pid "!pid!" & goto :BEGIN )
if "%TOMCAT_DIR%"=="d" ( set /p pid= "������Ҫdump�Ľ���PID:" & echo %jmap% -heap !pid! & %jmap% -heap !pid! >jmapheap!pid!.txt & start notepad jmapheap!pid!.txt & echo %jmap% -histo !pid! & %jmap% -histo !pid! >jmaphisto!pid!.txt & start jmaphisto!pid!.txt & echo %jstack% -F !pid! & %jstack% -F !pid! >jstackF!pid!.txt &start notepad jstackF!pid!.txt & echo %jstack% -l !pid! & %jstack% -l !pid! >jstackl!pid!.txt &start notepad jstackl!pid!.txt & echo %jmap% -dump:format=b,file=!pid!.dump !pid! & %jmap% -dump:format=b,file=!pid!.dump !pid! & goto :BEGIN )
if "%TOMCAT_DIR%"=="o" ( set /p file= "��ճ������·�����ļ��س�,���ü��±���:" & start notepad.exe "!file!" & goto :BEGIN )
if "%TOMCAT_DIR%"=="oo" ( set /p file= "��ճ������·�����ļ��س�,����notepad++��:" & "C:\Program Files (x86)\Notepad++\notepad++.exe" "!file!" & goto :BEGIN )
if not exist "%TOMCAT_DIR%" echo "%TOMCAT_DIR%" not exist ?????? & goto :BEGIN
if not exist "%TOMCAT_DIR%\bin\catalina.bat" echo {%TOMCAT_DIR%}:The TOMCAT_DIR not correct,please check ?????? & goto :BEGIN

echo %TOMCAT_DIR% >p.tmp
for /f %%i in (p.tmp) do set TOMCAT_DIR=%%~fi
del /f /q p.tmp
echo "%TOMCAT_DIR%\bin\catalina.bat">filelists.txt
echo "%TOMCAT_DIR%\conf\server.xml">>filelists.txt
echo "%TOMCAT_DIR%\APP_HOME\config\dms.properties">>filelists.txt
echo "%TOMCAT_DIR%\APP_HOME\config\jdbc.properties">>filelists.txt
echo "%TOMCAT_DIR%\APP_HOME\config\base.properties">>filelists.txt

findstr "appBase" "%TOMCAT_DIR%\conf\server.xml" >appBase_line.file
for /f "tokens=5 delims== " %%i in (appBase_line.file) do set appBase=%%~i
del appBase_line.file

if not "%appBase%"=="webapps" goto :new_appBase
echo "%TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\sfa.properties">>filelists.txt
echo "%TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\jdbc.properties">>filelists.txt
echo "%TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\base.properties">>filelists.txt
echo "%TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\callPlanConfig.properties">>filelists.txt
echo "%TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\spring\applicationContext-task.xml">>filelists.txt
echo "%TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\task.properties">>filelists.txt
echo "%TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\dw.properties">>filelists.txt
echo "%TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\sms_client.properties">>filelists.txt
goto :check

:new_appBase
echo "%appBase%\ROOT\WEB-INF\classes\config\sfa.properties">>filelists.txt
echo "%appBase%\ROOT\WEB-INF\classes\config\jdbc.properties">>filelists.txt
echo "%appBase%\ROOT\WEB-INF\classes\config\base.properties">>filelists.txt
echo "%appBase%\ROOT\WEB-INF\classes\config\callPlanConfig.properties">>filelists.txt
echo "%appBase%\ROOT\WEB-INF\classes\spring\applicationContext-task.xml">>filelists.txt
echo "%appBase%\ROOT\WEB-INF\classes\config\task.properties">>filelists.txt
echo "%appBase%\ROOT\WEB-INF\classes\config\dw.properties">>filelists.txt
echo "%appBase%\ROOT\WEB-INF\classes\config\sms_client.properties">>filelists.txt

:check

for /f %%i in (filelists.txt) do (
	set orifile=%%i
	set orifilename=%%~nxi
	if exist "!orifile!" echo %%~i & echo (((--------------------------------------------------

	if "!orifilename!"=="catalina.bat" (
		call :catalina_bat )
	if "!orifilename!"=="server.xml" (
		call :server_xml )
	if "!orifilename!"=="sfa.properties" (
		call :sfa_properties )
	if "!orifilename!"=="callPlanConfig.properties" (
		call :callPlanConfig_properties )
	if "!orifilename!"=="applicationContext-task.xml" (
		call :applicationContext-task_xml )
	if "!orifilename!"=="task.properties" (
		call :task_properties )
	if "!orifilename!"=="base.properties" (
		call :base_properties )
	if "!orifilename!"=="dw.properties" (
		call :dw_properties )
	if "!orifilename!"=="jdbc.properties" (
		call :jdbc_properties )
	if "!orifilename!"=="sms_client.properties" (
		call :sms_client_properties )
		
)
del filelists.txt
echo %TOMCAT_DIR%������Ϣ:
wmic process where name='java.exe'  get processid,commandline | findstr -v findstr |findstr %TOMCAT_DIR% 
goto :BEGIN


:catalina_bat
rem %TOMCAT_DIR%\bin\catalina.sh
rem set TITLE=test 8080
rem set "line=!line:kimberly sfa web 8080=%TITLE%!"
rem �ڴ�&JAVAOPTS����
rem jdk·��
findstr "JAVA_HOME=" "!orifile!" |findstr -v "rem"
findstr "JAVA_HOME=" "!orifile!" |findstr -v "rem" >jmappath.tmp
for /f "tokens=2 delims==" %%i in (jmappath.tmp) do set jmap=%%~si\bin\jmap &echo !jmap! &  set jstack=%%~si\bin\jstack &echo !jstack! 
del jmappath.tmp
findstr "JAVA_OPTS=" "!orifile!" |findstr -v "rem"
findstr "CATALINA_OPTS=" "!orifile!" |findstr -v "rem"
findstr "TITLE=" "!orifile!" |findstr -v "rem"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~)))
goto :eof

:server_xml
rem %TOMCAT_DIR%\conf\server.xml
rem port
rem appBase=
if not exist "!orifile!" goto :eof
findstr "port=" "!orifile!" |findstr -v "#"
findstr "appBase" "!orifile!" |findstr -v "#"
findstr "docBase" "!orifile!" |findstr -v "#"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~)))
goto :eof

:sfa_properties
rem %TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\sfa.properties
rem project=HenkelRetail_8880
rem mediaPath=
rem mediaServerUrl=
rem mobile.cache.maxfiles=2
rem mobile.cache.filepath=D:\app\SFA_HenkelRetail\app_root_mobile\mcache\ (ע���б��)
rem mobile.cacheType=2(1Ϊ�ڴ�,2ΪMongo)
rem mongodb.serverIp=127.0.0.1
rem mongodb.port=27017
rem mongodb.username=app_user
rem mongodb.password=YyNu58NQdsxynbYPz52Z2g==
rem mongodb.poolsize=200
if not exist "!orifile!" goto :eof
findstr "project=" "!orifile!" |findstr -v "#"
findstr "mediaServerUrl=" "!orifile!" |findstr -v "#"
findstr "mediaPath=" "!orifile!" |findstr -v "#"
findstr "mobile.cache.maxfiles=" "!orifile!" |findstr -v "#"
findstr "mobile.cache.filepath=" "!orifile!" |findstr -v "#"
findstr "mobile.cacheType=" "!orifile!" |findstr -v "#"
findstr "mongodb.serverIp=" "!orifile!" |findstr -v "#"
findstr "mongodb.port=" "!orifile!" |findstr -v "#"
findstr "mongodb.username=" "!orifile!" |findstr -v "#"
findstr "mongodb.password=" "!orifile!" |findstr -v "#"
findstr "mongodb.poolsize=" "!orifile!" |findstr -v "#"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~)))
goto :eof

:callPlanConfig_properties
rem %TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\callPlanConfig.properties
rem ��Ŀ����
rem tabKey=HenkelRetail_8880
if not exist "!orifile!" goto :eof
findstr "tabKey=" "!orifile!" |findstr -v "#"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~)))
goto :eof

:applicationContext-task_xml
rem %TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\spring\applicationContext-task.xml
rem ͨ��<!--  -->ע�Ͳ���Ҫ�������
rem <!--<ref bean="dailyTransJobCronTrigger"/>-->  ����
rem <!--<ref bean="refreshDataCronTrigger" />-->  �ս�
rem <!--<ref bean="refreshCacheTrigger" /> --> ����
if not exist "!orifile!" goto :eof
findstr "ref\ bean=" "!orifile!" |findstr -v "#"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~)))
goto :eof

:task_properties
rem %TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\task.properties
rem dailyTransJobCronTrigger.trigger.cronExpression=0 0 2 * * ?  ����/��/ʱ/��/�¡�����
rem refreshDataCronTrigger.trigger.cronExpression=0 0 4 * * ?
rem refreshCacheTrigger.trigger.cronExpression=0 0 5 * * ?
if not exist "!orifile!" goto :eof
findstr "dailyTransJobCronTrigger.trigger.cronExpression=" "!orifile!" |findstr -v "#"
findstr "refreshDataCronTrigger.trigger.cronExpression=" "!orifile!" |findstr -v "#"
findstr "refreshCacheTrigger.trigger.cronExpression=" "!orifile!" |findstr -v "#"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~)))
goto :eof

:base_properties
rem %TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\base.properties
rem job.baseJob=true
rem server.type.value=UAT testing  ��ȥ�����ɣ�
rem security.property.placeholder=true
if not exist "!orifile!" goto :eof
findstr "job.baseJob=" "!orifile!" |findstr -v "#"
findstr "server.type.value=" "!orifile!" |findstr -v "#"
findstr "security.property.placeholder=" "!orifile!" |findstr -v "#"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~)))
goto :eof

:dw_properties
rem %TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\dw.properties
rem cache.persistent=true
rem cache.persistent.dir=dw����·��
rem ���ڶ�tomcatִ��baseJob������������ã�һ�㲿����Ҫ��������Ҫ����Ŀ�з�ȷ�ϣ�
if not exist "!orifile!" goto :eof
findstr "cache.persistent=" "!orifile!" |findstr -v "#"
findstr "cache.persistent.dir=" "!orifile!" |findstr -v "#"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~)))
goto :eof

:jdbc_properties
rem %TOMCAT_DIR%\webapps\ROOT\WEB-INF\classes\config\jdbc.properties
rem jdbc.url=jdbc:jtds:sqlserver://192.168.1.17/dms_test2
rem jdbc.username=sa
rem jdbc.password=o5YLd9EWJBqKCQGFGlf6ibUtOz1Nfl1UkiaFdZS2Z0g=
if not exist "!orifile!" goto :eof
findstr /b "jdbc.url=" "!orifile!" |findstr -v "#"
findstr /b "jdbc.username=" "!orifile!" |findstr -v "#"
findstr /b "jdbc.password=" "!orifile!" |findstr -v "#"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~)))
goto :eof

:sms_client_properties
if not exist "!orifile!" goto :eof
findstr /b "send_url=" "!orifile!" |findstr -v "#"
findstr /b "revice_url=" "!orifile!" |findstr -v "#"
findstr /b "mail_send_url=" "!orifile!" |findstr -v "#"
echo ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~)))
goto :eof
