import os
import sys
import subprocess
import shutil

def build():
    print("[1/3] Preparing build directories...")
    os.makedirs("build/DesktopPet", exist_ok=True)
    os.makedirs("dist", exist_ok=True)

    print("[2/3] Building Windows Executable with PyInstaller...")
    cmd = [
        sys.executable, "-m", "PyInstaller",
        "--name=DesktopPet",
        "--noconfirm",
        "--onedir",
        "--windowed",
        "--icon=assets/app.ico",
        "--add-data=assets;assets",
        "main.py"
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
