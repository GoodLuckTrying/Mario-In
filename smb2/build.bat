@echo off
cd /d "%~dp0.."
python smb2/tools/build.py
if errorlevel 1 exit /b 1
python smb2/tools/verify.py
if errorlevel 1 exit /b 1
python smb2/tools/build.py --install
