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
    # 统一以仓库根为工作目录（dist/ build/ 这些路径是相对 CWD 的）
    root = os.path.dirname(os.path.abspath(__file__))
    os.chdir(root)

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
    # ⚠️ 直接用仓库里的 DesktopPet_Setup.spec，不走命令行参数。
    #   原因同 build_exe.py：命令行参数路径会让 PyInstaller 生成同名 spec
    #   并覆盖仓库里那份手写的，把 git 工作区弄脏。
    #   spec 里已经写好了 win7 兼容 DLL、payload.zip 与 assets 三项打包内容。
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--noconfirm",
        os.path.join(root, "DesktopPet_Setup.spec"),
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
