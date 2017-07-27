@echo off

title WINCHANNEL FOR YW_searchPort
color 0a
mode con cols=160 lines=200

set CYGWIN=nodosfilewarning
setlocal enabledelayedexpansion
:begin
set /p sstr= "请输入要查找的port:" 
FOR /F %%i IN (d:\scripts\server.xml.list) DO ( grep -H --color !sstr! %%~fi )
goto :begin