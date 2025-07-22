@echo off
cd /d "%~dp0"

set "MSYS2_DIR=C:\msys64"

echo "%MSYS2_DIR%\msys2_shell.cmd" -mingw32 -here -c "./build.sh"
call "%MSYS2_DIR%\msys2_shell.cmd" -mingw32 -here -c "./build.sh"
