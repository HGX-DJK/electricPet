import os
import sys
import subprocess
import shutil

# 仓库根目录（本文件所在目录）。
# ⚠️ 打包脚本必须以仓库根为工作目录：spec 里的 SPECPATH 由 PyInstaller 注入，
# 但 dist/ build/ 这些输出路径是相对 CWD 的。这里统一 chdir，
# 这样从任何目录调用脚本都能落到同一个位置。
ROOT = os.path.dirname(os.path.abspath(__file__))

def build():
    os.chdir(ROOT)

    print("[1/3] Preparing build directories...")
    os.makedirs("build/DesktopPet", exist_ok=True)
    os.makedirs("dist", exist_ok=True)

    print("[2/3] Building Windows Executable with PyInstaller...")
    # ⚠️ 直接用仓库里的 DesktopPet.spec，不走命令行参数。
    #
    #   以前这里写的是 --name=DesktopPet + main.py，PyInstaller 会把**自动生成的**
    #   同名 spec 写进当前目录，直接覆盖掉仓库里那份手写的 —— 也就是说每跑一次
    #   打包，git 工作区就被弄脏一次，手写 spec 里"不写死绝对路径"的约定也会
    #   被机器产物冲掉。
    #
    #   改用 spec 构建后 PyInstaller 不再生成 spec，覆盖问题从根上消失；
    #   同时 spec 成了打包配置的唯一事实来源，不再有"两处配置各自漂移"的问题。
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--noconfirm",
        os.path.join(ROOT, "DesktopPet.spec"),
    ]

    print("Running:", " ".join(cmd))
    res = subprocess.run(cmd)
    if res.returncode != 0:
        print("Build failed with return code:", res.returncode)
        sys.exit(res.returncode)

    print("[3/3] Injecting Windows 7 compatibility layer (api-ms-win-core-path-l1-1-0.dll)...")
    dist_dir = os.path.abspath("dist/DesktopPet")
    win7_dll = os.path.abspath("assets/api-ms-win-core-path-l1-1-0.dll")
    if os.path.exists(win7_dll):
        # 复制到应用根目录以及 _internal 目录（python314.dll 所在位置）
        shutil.copy2(win7_dll, os.path.join(dist_dir, "api-ms-win-core-path-l1-1-0.dll"))
        internal_dir = os.path.join(dist_dir, "_internal")
        if os.path.exists(internal_dir):
            shutil.copy2(win7_dll, os.path.join(internal_dir, "api-ms-win-core-path-l1-1-0.dll"))
        print("  -> Windows 7 compatibility DLL injected successfully!")

    exe_path = os.path.join(dist_dir, "DesktopPet.exe")
    print(f"Executable created at: {exe_path}")
    return exe_path

if __name__ == "__main__":
    build()
