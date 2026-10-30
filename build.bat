@echo off
cd /d "%~dp0"
python tools\build_port.py %*
