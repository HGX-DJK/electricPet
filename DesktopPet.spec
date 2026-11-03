# -*- mode: python ; coding: utf-8 -*-
#
# 桌面萌宠 · 波可 —— 免安装独立版构建规格 (DesktopPet.exe)
#
# 路径约定：一律使用 SPECPATH（PyInstaller 注入的本 spec 文件所在目录）拼绝对路径。
# 不要写死任何机器绝对路径 —— 那会让构建只在某一台电脑上能跑通，换机 / 上 CI 必崩。
#
# 说明：仓库里的 build_exe.py 默认走命令行参数构建（不读本文件）；
#       本 spec 保留下来是为了「手工一条命令复现出同样的产物」，并保证两套路径都机器无关。

import os

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[],
    datas=[(os.path.join(SPECPATH, 'assets'), 'assets')],
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
    [],
    exclude_binaries=True,
    name='DesktopPet',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon=[os.path.join(SPECPATH, 'assets', 'app.ico')],
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='DesktopPet',
)
