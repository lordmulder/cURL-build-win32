@echo off
cd /d "%~dp0"

set "MSYS2_DIR=C:\msys64"

for %%m in (32,64) do (
	call "%MSYS2_DIR%\msys2_shell.cmd" -mingw%%m -where "%~dp0" -c "./build.sh"
	TIMEOUT /T 15 /NOBREAK > NUL
)

pause
