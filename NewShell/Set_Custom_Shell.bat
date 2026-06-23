@echo off
title Custom Shell Installer
echo Setting Custom Shell to CustomShell.exe...

:: Get the exact path to where this batch file is running from
set "SHELL_PATH=%~dp0CustomShell.exe"

:: Check if CustomShell.exe actually exists here before modifying the registry!
if not exist "%SHELL_PATH%" (
    echo ERROR: CustomShell.exe not found in %~dp0
    echo Please place this batch file in the exact same compiled folder as CustomShell.exe!
    pause
    exit /b
)

:: Set the Current User's Shell to our Custom Shell
reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v Shell /t REG_SZ /d "%SHELL_PATH%" /f

:: Hijack the .cpl file execution so Windows hands it to CustomShell.exe instead of control.exe
reg add "HKCU\Software\Classes\cplfile\shell\cplopen\command" /ve /t REG_SZ /d "\"%SHELL_PATH%\" \"%%1\"" /f
reg add "HKCU\Software\Classes\cplfile\shell\open\command" /ve /t REG_SZ /d "\"%SHELL_PATH%\" \"%%1\"" /f

echo.
echo Success! The registry has been updated.
echo Please restart the Virtual Machine or log out and log back in to see the changes.
pause