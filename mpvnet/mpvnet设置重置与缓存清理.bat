@echo off

cd /D %~dp0\portable_config
echo ==================
del input.conf
del mpv.conf
del mpvnet.conf
del settings.xml
echo ==================
echo �����棺Уɫ��
del icc_cache\*.*
echo �����棺��ɫ��
del shaders_cache\*.*
echo ���棺�ļ�״̬��¼
del watch_later\*.*
echo ==================
echo ȫ��ִ�����
pause
