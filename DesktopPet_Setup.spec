# -*- mode: python ; coding: utf-8 -*-
#
# 桌面萌宠 · 波可 —— 单文件安装包构建规格 (DesktopPet_Setup.exe)
#
# 路径约定：一律使用 SPECPATH（PyInstaller 注入的本 spec 文件所在目录）拼绝对路径。
# 不要写死任何机器绝对路径 —— 那会让构建只在某一台电脑上能跑通，换机 / 上 CI 必崩。
#
# 说明：仓库里的 build_installer.py 默认走命令行参数构建（不读本文件）；
#       本 spec 保留下来是为了「手工一条命令复现出同样的安装包」，并保证两套路径都机器无关。

import os

a = Analysis(
    ['installer_gui.py'],
    pathex=[],
    binaries=[(os.path.join(SPECPATH, 'assets', 'api-ms-win-core-path-l1-1-0.dll'), '.')],
    datas=[
        (os.path.join(SPECPATH, 'dist', 'payload.zip'), '.'),
        (os.path.join(SPECPATH, 'assets'), 'assets'),
    ],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='DesktopPet_Setup',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=[os.path.join(SPECPATH, 'assets', 'app.ico')],
)
