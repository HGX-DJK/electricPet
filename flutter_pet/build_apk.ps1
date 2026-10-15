[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "          波可 (Poko) Android APK 自动打包工具          " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# 配置国内官方镜像，加速下载与依赖解析
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"

$flutterCmd = "flutter"
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Test-Path "D:\software\flutter\bin\flutter.bat") {
        $flutterCmd = "D:\software\flutter\bin\flutter.bat"
        $env:PATH = "D:\software\flutter\bin;" + $env:PATH
        Write-Host "已自动检测到 Flutter 路径：D:\software\flutter\bin！`n" -ForegroundColor Green
    } else {
        Write-Host "[提示] 未在系统 PATH 或 D:\software\flutter 中检测到 Flutter SDK。" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "[1/3] 正在获取依赖包 (pub get)..." -ForegroundColor Cyan
Set-Location -Path $PSScriptRoot
& $flutterCmd pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "获取依赖失败，请检查网络！" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n[2/3] 正在编译 Release 版本 APK (build apk --release)..." -ForegroundColor Cyan
& $flutterCmd build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "编译构建失败，请检查报错！" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "[3/3] 打包大功告成！" -ForegroundColor Green
Write-Host "APK 输出路径: $PSScriptRoot\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
