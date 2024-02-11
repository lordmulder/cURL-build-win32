@echo off
cd /d "%~dp0"

set "MSYS2_DIR=C:\msys64"

echo "%MSYS2_DIR%\msys2_shell.cmd" -mingw32 -where "%~dp0" -c "./build.sh"
call "%MSYS2_DIR%\msys2_shell.cmd" -mingw32 -where "%~dp0" -c "./build.sh"

TIMEOUT /T 30 /NOBREAK > NUL

echo "%MSYS2_DIR%\msys2_shell.cmd" -mingw64 -where "%~dp0" -c "./build.sh"
call "%MSYS2_DIR%\msys2_shell.cmd" -mingw64 -where "%~dp0" -c "./build.sh"
