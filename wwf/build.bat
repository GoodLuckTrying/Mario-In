@echo off
cd /d "%~dp0.."
python wwf\tools\build.py
if errorlevel 1 exit /b 1
python wwf\tools\verify.py
if errorlevel 1 exit /b 1
python wwf\tools\build.py --install
