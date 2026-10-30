@echo off
pushd "%~dp0\.."
python zelda\tools\build.py
if errorlevel 1 goto end
python zelda\tools\verify.py
if errorlevel 1 goto end
python zelda\tools\build.py --install
:end
popd
