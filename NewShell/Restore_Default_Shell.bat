@echo off
title Custom Shell Uninstaller
echo Restoring standard Windows Explorer shell...

:: Delete the custom shell override for the current user
reg delete "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /f

:: Restore .cpl file execution back to standard Windows defaults
reg delete "HKCU\Software\Classes\cplfile\shell\cplopen" /f
reg delete "HKCU\Software\Classes\cplfile\shell\open" /f

echo.
echo Success! The registry has been restored to default.
echo If your screen is currently empty, we will now attempt to start standard explorer.exe...
pause

:: Launch standard explorer to bring the desktop back immediately
start explorer.exe