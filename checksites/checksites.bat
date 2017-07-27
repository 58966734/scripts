@echo off
rem maintence liuliguo 20170707

setlocal enabledelayedexpansion
set pwd=%~dp0
set now=%DATE:~0,4%_%DATE:~5,2%_%DATE:~8,2%_%time:~0,2%_%time:~3,2%_%time:~6,2% 

set total=0
for /f %%i in (%pwd%\sites.txt) do set /a  total+=1

set flag=0
for /f %%i in (%pwd%\sites.txt) do ( 
	set site=%%i
	%pwd%\curl -ksI  --connect-timeout 3 -m 5  !site!  | findstr  "HTTP/1.1" >%pwd%\tmp~.tmp
	for /f "tokens=2 delims= " %%j in (%pwd%\tmp~.tmp) do set result=%%j
	if "!result!" equ "200" ( set /a flag+=1
	) else ( echo %now% !site! >>%pwd%\error~.log )
	set result=0
)
del /f /q %pwd%\tmp~.tmp
if %flag% neq %total% ( echo 0 
) else ( echo 1 )

rem @@@@@@@@@@@@@@@@@@@@@@@@@
rem zabbix_agentd.conf
rem Timeout=10

rem UserParameter=checksites C:\zabbix_agents\checksites\checksites.bat


