@echo off
cd /d %~dp0\_root
Powershell -NoProfile -ExecutionPolicy Bypass -File maintenance.ps1 -Verb RunAs
exit
