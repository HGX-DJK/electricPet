@echo off
title 桌面萌宠 - 安装向导
echo ========================================================
echo        正在启动 桌面萌宠 安装向导...
echo ========================================================
echo.

where.exe python >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    python "%~dp0install.py"
    goto end
)

where.exe py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    py "%~dp0install.py"
    goto end
)

echo [提示] 正在使用 PowerShell 运行安装程序...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-DesktopPet.ps1"

:end
echo.
pause
