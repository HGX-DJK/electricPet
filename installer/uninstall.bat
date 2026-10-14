@echo off
chcp 65001 >nul
title 桌面萌宠卸载程序
echo ========================================================
echo          桌面萌宠 · 波可 (Desktop Pet) 卸载程序
echo ========================================================
echo.

echo [1/4] 正在关闭萌宠运行进程...
taskkill /F /IM DesktopPet.exe >nul 2>nul

echo [2/4] 正在清理桌面与开始菜单快捷方式...
del /f /q "%USERPROFILE%\Desktop\*波可*.lnk" >nul 2>nul
del /f /q "%USERPROFILE%\Desktop\*DesktopPet*.lnk" >nul 2>nul
del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\*波可*.lnk" >nul 2>nul
del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\*DesktopPet*.lnk" >nul 2>nul

echo [3/4] 正在清理注册表项...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\DesktopPet" /f >nul 2>nul
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "DesktopElectricPet" /f >nul 2>nul

echo [4/4] 正在移除应用程序文件...
set "TARGET_DIR=%~dp0"
cd /d "%USERPROFILE%"
start /b "" cmd /c "timeout /t 1 /nobreak >nul && rd /s /q \"%TARGET_DIR%\""

echo.
echo ========================================================
echo          卸载完成！波可期待下次与您相遇~
echo ========================================================
echo.
pause
