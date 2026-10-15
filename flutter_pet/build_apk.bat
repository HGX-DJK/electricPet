@echo off
chcp 65001 >nul
title Poko Android APK Builder
echo ========================================================
echo          Poko Android APK Build Tool
echo ========================================================
echo.

set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"

set "FLUTTER_CMD=flutter"
where flutter >nul 2>nul
if errorlevel 1 (
    if exist "D:\software\flutter\bin\flutter.bat" (
        set "FLUTTER_CMD=D:\software\flutter\bin\flutter.bat"
        set "PATH=D:\software\flutter\bin;%PATH%"
        echo [INFO] Detected Flutter at D:\software\flutter\bin!
        echo.
    ) else (
        goto no_flutter
    )
)

echo [1/3] Getting dependencies (%FLUTTER_CMD% pub get)...
cd /d "%~dp0"
call "%FLUTTER_CMD%" pub get
if errorlevel 1 goto err_pub

echo.
echo [2/3] Building Release APK (%FLUTTER_CMD% build apk --release)...
call "%FLUTTER_CMD%" build apk --release
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
echo [Notice] Flutter command not found in your system PATH or D:\software\flutter.
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
