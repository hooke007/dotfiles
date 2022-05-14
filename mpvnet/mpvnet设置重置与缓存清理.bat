@echo off
chcp 936

cd /D %~dp0\portable_config
echo ==================
del input.conf
del mpv.conf
del mpvnet.conf
del settings.xml
echo ==================
echo 全部执行完毕
pause
