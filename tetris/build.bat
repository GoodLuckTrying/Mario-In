@echo off
cd /d "%~dp0.."
python tetris/tools/native.py && python tetris/tools/build.py && python tetris/tools/verify.py && python tetris/tools/build.py --install
pause
