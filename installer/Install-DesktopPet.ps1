# Windows 一键智能安装程序
param(
    [string]$SourceDir = "",
    [switch]$Silent = $false
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      桌面萌宠 · 波可 (Desktop Pet Poko) 安装程序        " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$installerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $installerDir

if (-not $SourceDir) {
    $distPath = Join-Path $projectRoot "dist\DesktopPet"
    if (Test-Path $distPath) {
        $SourceDir = $distPath
    } else {
        $SourceDir = $projectRoot
    }
}

Write-Host "[1/5] 安装源目录: $SourceDir" -ForegroundColor Green

$installDir = Join-Path $env:LOCALAPPDATA "Programs\DesktopPet"
Write-Host "[2/5] 目标安装路径: $installDir" -ForegroundColor Green

# 检查关闭旧进程
$proc = Get-Process -Name "DesktopPet" -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "检测到已运行的萌宠进程，正在更新前安全退出..." -ForegroundColor Yellow
    $proc | Stop-Process -Force
    Start-Sleep -Seconds 1
}

# 创建目标目录
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

Write-Host "[3/5] 正在复制程序文件..." -ForegroundColor Green
Copy-Item -Path "$SourceDir\*" -Destination $installDir -Recurse -Force

# 复制卸载脚本
$uninstSrc = Join-Path $installerDir "uninstall.bat"
if (Test-Path $uninstSrc) {
    Copy-Item -Path $uninstSrc -Destination $installDir -Force
}

$exePath = Join-Path $installDir "DesktopPet.exe"
if (-not (Test-Path $exePath)) {
    $batPath = Join-Path $installDir "run.bat"
    if (Test-Path $batPath) {
        $exePath = $batPath
    }
}

$iconPath = Join-Path $installDir "assets\app.ico"
if (-not (Test-Path $iconPath)) {
    $origIcon = Join-Path $projectRoot "assets\app.ico"
    $targetAssets = Join-Path $installDir "assets"
    New-Item -ItemType Directory -Path $targetAssets -Force | Out-Null
    Copy-Item -Path $origIcon -Destination $targetAssets -Force
    $iconPath = Join-Path $targetAssets "app.ico"
}

Write-Host "[4/5] 创建快捷方式..." -ForegroundColor Green
$wsh = New-Object -ComObject WScript.Shell

# 桌面快捷方式
$desktopDir = [Environment]::GetFolderPath("Desktop")
$desktopLnk = Join-Path $desktopDir "桌面萌宠 · 波可.lnk"
$sc1 = $wsh.CreateShortcut($desktopLnk)
$sc1.TargetPath = $exePath
$sc1.WorkingDirectory = $installDir
if (Test-Path $iconPath) {
    $sc1.IconLocation = "$iconPath,0"
}
$sc1.Description = "桌面萌宠 · 波可"
$sc1.Save()

# 开始菜单快捷方式
$programsDir = [Environment]::GetFolderPath("Programs")
$startMenuLnk = Join-Path $programsDir "桌面萌宠 · 波可.lnk"
$sc2 = $wsh.CreateShortcut($startMenuLnk)
$sc2.TargetPath = $exePath
$sc2.WorkingDirectory = $installDir
if (Test-Path $iconPath) {
    $sc2.IconLocation = "$iconPath,0"
}
$sc2.Description = "桌面萌宠 · 波可"
$sc2.Save()

Write-Host "[5/5] 注册至 Windows 控制面板与设置应用列表..." -ForegroundColor Green
$uninstallBat = Join-Path $installDir "uninstall.bat"
$regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DesktopPet"
if (-not (Test-Path $regKey)) {
    New-Item -Path $regKey -Force | Out-Null
}
Set-ItemProperty -Path $regKey -Name "DisplayName" -Value "桌面萌宠 · 波可 (Desktop Pet Poko)"
Set-ItemProperty -Path $regKey -Name "DisplayVersion" -Value "1.0.0"
Set-ItemProperty -Path $regKey -Name "Publisher" -Value "ElectricPet Studio"
Set-ItemProperty -Path $regKey -Name "InstallLocation" -Value $installDir
Set-ItemProperty -Path $regKey -Name "DisplayIcon" -Value $iconPath
Set-ItemProperty -Path $regKey -Name "UninstallString" -Value "`"$uninstallBat`""

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "            🎉 恭喜！桌面萌宠 · 波可 安装成功！            " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "桌面快捷方式已创建: $desktopLnk"
Write-Host ""

if (-not $Silent) {
    $ans = Read-Host "是否现在立刻启动萌宠？(Y/N) [默认: Y]"
    if ($ans -eq "" -or $ans -eq "Y" -or $ans -eq "y") {
        Start-Process -FilePath $exePath -WorkingDirectory $installDir
    }
}
