@echo off

cd /D %~dp0\portable_config
echo ==================
del input.conf
del mpv.conf
del mpvnet.conf
del settings.xml
echo ==================
echo 清理缓存：校色档
del icc_cache\*.*
echo 清理缓存：着色器
del shaders_cache\*.*
echo 缓存：文件状态记录
del watch_later\*.*
echo ==================
echo 全部执行完毕
pause
