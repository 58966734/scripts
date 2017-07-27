@echo off
rem set ip=%1%
set ip= 192.168.211.62
rem set ip= 192.168.211.61
setlocal enabledelayedexpansion
set flag=0
for /l %%i in (1,1,4) do ping -n 1 %ip% >nul && set /a flag+=1
if !flag! equ 0 ( echo 0
) else ( echo 1 
)