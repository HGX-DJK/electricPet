@echo off
chcp 65001 >nul
title Poko Android APK Builder
echo ========================================================
echo          Poko Android APK Build Tool
echo ========================================================
echo.

where flutter >nul 2>nul
if errorlevel 1 goto no_flutter

echo [1/3] Getting dependencies (flutter pub get)...
cd /d "%~dp0"
call flutter pub get
if errorlevel 1 goto err_pub

echo.
echo [2/3] Building Release APK (flutter build apk --release)...
call flutter build apk --release
if errorlevel 1 goto err_build

echo.
echo ========================================================
echo [3/3] Build succeeded! APK output:
echo %~dp0build\app\outputs\flutter-apk\app-release.apk
echo ========================================================
echo.
pause
exit /b 0

:no_flutter
echo [Notice] Flutter command not found in your system PATH.
echo.
echo [Method 1 - Recommended]: Use GitHub Actions Cloud Build
echo Simply push your code to GitHub, click the 'Actions' tab,
echo and download the compiled APK directly without installing any tools!
echo.
echo [Method 2]: Install Flutter SDK on your PC
echo 1. Download Flutter SDK for Windows
echo 2. Extract to D:\software\flutter and add D:\software\flutter\bin to PATH
echo 3. Run this script again
echo ========================================================
echo.
pause
exit /b 1

:err_pub
echo [ERROR] Failed to get dependencies! Please check network.
pause
exit /b 1

:err_build
echo [ERROR] Build failed! Please check error output.
pause
exit /b 1
