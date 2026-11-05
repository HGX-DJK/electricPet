# -*- mode: python ; coding: utf-8 -*-
#
# 桌面萌宠 · 波可 —— 单文件安装包构建规格 (DesktopPet_Setup.exe)
#
# 路径约定：一律使用 SPECPATH（PyInstaller 注入的本 spec 文件所在目录）拼绝对路径。
# 不要写死任何机器绝对路径 —— 那会让构建只在某一台电脑上能跑通，换机 / 上 CI 必崩。
#
# 说明：本文件是打包配置的**唯一事实来源**。
#       build_installer.py 直接调用本 spec（不再用命令行参数），因为命令行参数路径会让
#       PyInstaller 生成同名 spec 并覆盖掉这份手写的，把 git 工作区弄脏。
#       手工复现同样产物：python -m PyInstaller --noconfirm DesktopPet_Setup.spec

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
