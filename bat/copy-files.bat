:: Copies files to a destination. Params (source, destination)

@echo off
cls

set @src=%1
set @dst=%2

echo Copying files to destination:
echo d | xcopy "%@src%" "%@dst%" /s /d /y

echo Files copied successfully

:: pause

exit