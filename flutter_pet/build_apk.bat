@echo off
chcp 65001 >nul
title 桌面萌宠 · 波可 Android APK 一键构建工具
echo ========================================================
echo          波可 (Poko) Android APK 自动打包脚本
echo ========================================================
echo.

where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [提示] 未在系统 PATH 中检测到 flutter 命令。
    echo.
    echo 如果您想在本地电脑生成 APK，请按以下步骤操作：
    echo 1. 从国内镜像或官网下载 Flutter SDK (解压到如 D:\software\flutter)
    echo 2. 将 D:\software\flutter\bin 添加到系统环境变量 PATH
    echo 3. 再次双击运行此脚本即可一键打包！
    echo.
    echo --------------------------------------------------------
    echo [推荐免安装方案]
    echo 本项目已为您配置好了【GitHub Actions 免费云端打包】！
    echo 只要将代码 push 到 GitHub，点击 Actions 标签页，
    echo 2分钟内就会自动生成 APK 并提供下载链接，无需本地安装任何工具！
    echo --------------------------------------------------------
    echo.
    pause
    exit /b 1
)

echo [1/3] 正在获取依赖包 (flutter pub get)...
cd /d "%~dp0"
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo 获取依赖失败，请检查网络！
    pause
    exit /b 1
)

echo.
echo [2/3] 正在编译 Release 版本 APK (flutter build apk --release)...
call flutter build apk --release
if %ERRORLEVEL% NEQ 0 (
    echo 编译构建失败，请检查报错！
    pause
    exit /b 1
)

echo.
echo ========================================================
echo [3/3] 打包大功告成！
echo APK 输出路径:
echo %~dp0build\app\outputs\flutter-apk\app-release.apk
echo ========================================================
echo.
pause
