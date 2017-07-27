@echo off
setlocal enabledelayedexpansion
if not exist d:\scripts md d:\scripts
set yyyy=%date:~0,4%
set mm=%date:~5,2%
set dd=%date:~8,2%
if exist d:\scripts\server.xml.list ren d:\scripts\server.xml.list server.xml.list_bak!yyyy!!mm!!dd!

find d:\ -maxdepth 5 -name server.xml  >>d:\scripts\server.xml.list
find f:\ -maxdepth 5 -name server.xml  >>d:\scripts\server.xml.list
find g:\ -maxdepth 5 -name server.xml  >>d:\scripts\server.xml.list