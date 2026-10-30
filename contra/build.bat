@echo off
cd /d "%~dp0.."
python contra/tools/native.py
if errorlevel 1 exit /b 1
python contra/tools/build.py
if errorlevel 1 exit /b 1
python contra/tools/verify.py
if errorlevel 1 exit /b 1
python contra/tools/build.py --install
