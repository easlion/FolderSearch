@echo off
title Folder Search V11 Launcher

echo ==========================================
echo Starting Folder Search V11...
echo ==========================================
echo.

if not exist "D:\Tools\FolderSearchV11.ps1" (
    echo [ERROR] Cannot find:
    echo D:\Tools\FolderSearchV11.ps1
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Tools\FolderSearchV11.ps1"

echo.
echo ==========================================
echo PowerShell has exited.
echo Exit Code: %ERRORLEVEL%
echo ==========================================
echo.

pause
