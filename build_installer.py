import os
import sys
import subprocess
import shutil
import zipfile

# 保证控制台即使在 GBK 编码下也不会因为 emoji 报错
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

def compress_payload(source_dir, output_zip):
    print(f"[Compressing] Packaging {source_dir} -> {output_zip}...")
    with zipfile.ZipFile(output_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for root, dirs, files in os.walk(source_dir):
            for f in files:
                full = os.path.join(root, f)
                rel = os.path.relpath(full, source_dir)
                zf.write(full, rel)
    size_mb = os.path.getsize(output_zip) / (1024 * 1024)
    print(f"[Compressed] payload.zip created successfully: {size_mb:.2f} MB")

def build_installer_only():
    """编译最新核心程序并封装单文件安装包 DesktopPet_Setup.exe"""
    dist_app = os.path.abspath("dist/DesktopPet")
    exe_app = os.path.join(dist_app, "DesktopPet.exe")

    # 默认重新编译核心程序，确保包含最新源码修复；传入 --quick 可复用已编译目录
    need_rebuild = "--quick" not in sys.argv
    if need_rebuild or not os.path.exists(exe_app):
        print("[Notice] 正在重新编译最新核心应用程序 (包含最新代码与界面修复)...")
        import build_exe
        build_exe.build()

    payload_zip = os.path.abspath("dist/payload.zip")
    compress_payload(dist_app, payload_zip)

    print("\n[Packaging] 封装生成单文件完全独立安装程序 DesktopPet_Setup.exe...")
    win7_dll = os.path.abspath("assets/api-ms-win-core-path-l1-1-0.dll")
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--name=DesktopPet_Setup",
        "--noconfirm",
        "--onefile",
        "--windowed",
        "--icon=assets/app.ico",
        f"--add-binary={win7_dll};.",
        f"--add-data={payload_zip};.",
        "--add-data=assets;assets",
        "installer_gui.py"
    ]
    print("Running:", " ".join(cmd))
    res = subprocess.run(cmd)
    if res.returncode != 0:
        print("Setup packaging failed!")
        sys.exit(res.returncode)

    setup_exe = os.path.abspath("dist/DesktopPet_Setup.exe")
    if os.path.exists(setup_exe):
        size_mb = os.path.getsize(setup_exe) / (1024 * 1024)
        print("\n" + "=" * 60)
        print("[SUCCESS] 单文件安装程序打包成功！")
        print(f"独立安装包路径: {setup_exe}")
        print(f"文件大小: {size_mb:.2f} MB")
        print("特性: 单个 exe 即可拷贝到任意没有 Python 环境的 Windows 电脑直接双击安装！")
        print("=" * 60)

if __name__ == "__main__":
    build_installer_only()
