import os

uninstall_script = """@echo off
title 卸载桌面萌宠
echo ========================================================
echo          正在卸载 桌面萌宠 (Desktop Pet)...
echo ========================================================
echo.

echo [1/4] 正在关闭运行中的萌宠进程...
taskkill /F /IM DesktopPet.exe >nul 2>nul

echo [2/4] 正在清理桌面与开始菜单快捷方式...
del /f /q "%USERPROFILE%\\Desktop\\*波可*.lnk" >nul 2>nul
del /f /q "%USERPROFILE%\\Desktop\\*DesktopPet*.lnk" >nul 2>nul
del /f /q "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\*波可*.lnk" >nul 2>nul
del /f /q "%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\*DesktopPet*.lnk" >nul 2>nul

echo [3/4] 正在清除 Windows 注册表项...
reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\DesktopPet" /f >nul 2>nul
reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" /v "DesktopElectricPet" /f >nul 2>nul

echo [4/4] 正在清理程序安装文件夹...
set "TARGET_DIR=%LOCALAPPDATA%\\Programs\\DesktopPet"
start /b "" cmd /c "timeout /t 1 /nobreak >nul & rd /s /q \\"%TARGET_DIR%\\""

echo.
echo ========================================================
echo          卸载完成！波可期待下次与您相遇~
echo ========================================================
pause
"""

setup_script = """@echo off
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
"""

run_script = """@echo off
title 桌面萌宠
start pythonw main.py
exit
"""

# 写入 GBK / ANSI 格式
for path, content in [
    ("installer/uninstall.bat", uninstall_script),
    ("installer/setup.bat", setup_script),
    ("run.bat", run_script)
]:
    with open(path, "w", encoding="gbk", errors="replace") as f:
        f.write(content.replace("\r\n", "\n").replace("\n", "\r\n"))

installed_dir = os.path.expandvars(r"%LOCALAPPDATA%\Programs\DesktopPet")
if os.path.exists(installed_dir):
    inst_uninst = os.path.join(installed_dir, "uninstall.bat")
    with open(inst_uninst, "w", encoding="gbk", errors="replace") as f:
        f.write(uninstall_script.replace("\r\n", "\n").replace("\n", "\r\n"))

print("Fixed batch files and self-delete mechanism successfully!")
