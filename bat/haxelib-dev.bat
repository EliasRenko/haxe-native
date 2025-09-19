@echo off

cd..

for /f "delims=" %%A in ('cd') do (
    
    set name=%%~nxA
)

echo Setting development directory for `%name%`:

echo.

haxelib dev %name% %CD%

pause