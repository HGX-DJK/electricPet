import os
import sys
import shutil
import tempfile
import subprocess
import winreg

# 保证控制台即使在 GBK 环境下也不会因为 Unicode 字符报错
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

def create_windows_shortcut(target_path, shortcut_path, working_dir, icon_path=None, description=""):
    """使用 Windows 原生 WScript.Shell 创建 .lnk 快捷方式"""
    os.makedirs(os.path.dirname(shortcut_path), exist_ok=True)
    vbs_path = os.path.join(tempfile.gettempdir(), f"mk_lnk_{os.getpid()}.vbs")
    
    icon_line = f'oLink.IconLocation = "{icon_path},0"' if icon_path and os.path.exists(icon_path) else ""
    vbs_content = f'''Set oWS = WScript.CreateObject("WScript.Shell")
sLinkFile = "{shortcut_path}"
Set oLink = oWS.CreateShortcut(sLinkFile)
oLink.TargetPath = "{target_path}"
oLink.WorkingDirectory = "{working_dir}"
oLink.Description = "{description}"
{icon_line}
oLink.Save
'''
    try:
        # 在中文 Windows 环境下，cscript 默认以系统 ANSI 代码页 (GBK) 解析 .vbs 脚本
        with open(vbs_path, "w", encoding="gbk", errors="replace") as f:
            f.write(vbs_content)
        subprocess.run(["cscript", "//nologo", vbs_path], check=True, capture_output=True)
    finally:
        if os.path.exists(vbs_path):
            try:
                os.remove(vbs_path)
            except Exception:
                pass

def install(silent=False, target_dir=None, create_desktop=True, create_startmenu=True, autostart=False, launch_after=True):
    print("=" * 60)
    print("        桌面萌宠 · 波可 (Desktop Pet Poko) 安装程序        ")
    print("=" * 60)

    # 确定项目根目录与打包源
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, ".."))
    dist_dir = os.path.join(project_root, "dist", "DesktopPet")

    if os.path.exists(dist_dir) and os.path.exists(os.path.join(dist_dir, "DesktopPet.exe")):
        source_dir = dist_dir
        is_binary = True
    else:
        source_dir = project_root
        is_binary = False

    print(f"[1/5] 安装源目录: {source_dir}")

    # 目标目录
    if not target_dir:
        local_appdata = os.environ.get("LOCALAPPDATA", os.path.expanduser("~"))
        target_dir = os.path.join(local_appdata, "Programs", "DesktopPet")

    print(f"[2/5] 目标安装路径: {target_dir}")

    # 尝试关闭正在运行的进程
    try:
        subprocess.run(["taskkill", "/F", "/IM", "DesktopPet.exe"], capture_output=True)
        import time
        time.sleep(1.2)
    except Exception:
        pass

    # 复制文件
    print("[3/5] 正在复制程序文件...")
    os.makedirs(target_dir, exist_ok=True)
    
    def ignore_patterns(path, names):
        ignored = []
        for name in names:
            if name in [".git", "build", "dist", "__pycache__", ".vscode"]:
                ignored.append(name)
        return ignored

    if is_binary:
        for item in os.listdir(source_dir):
            s = os.path.join(source_dir, item)
            d = os.path.join(target_dir, item)
            if os.path.isdir(s):
                if os.path.exists(d):
                    shutil.rmtree(d, ignore_errors=True)
                shutil.copytree(s, d)
            else:
                shutil.copy2(s, d)
    else:
        for item in os.listdir(source_dir):
            if item in ["build", "dist", ".git", ".gemini"]:
                continue
            s = os.path.join(source_dir, item)
            d = os.path.join(target_dir, item)
            if os.path.isdir(s):
                if os.path.exists(d):
                    shutil.rmtree(d, ignore_errors=True)
                shutil.copytree(s, d, ignore=ignore_patterns)
            else:
                shutil.copy2(s, d)

    # 复制 assets 图标
    assets_dir = os.path.join(target_dir, "assets")
    os.makedirs(assets_dir, exist_ok=True)
    orig_ico = os.path.join(project_root, "assets", "app.ico")
    target_ico = os.path.join(assets_dir, "app.ico")
    if os.path.exists(orig_ico) and not os.path.exists(target_ico):
        shutil.copy2(orig_ico, target_ico)

    # 复制卸载脚本
    orig_uninst = os.path.join(script_dir, "uninstall.bat")
    target_uninst = os.path.join(target_dir, "uninstall.bat")
    if os.path.exists(orig_uninst):
        shutil.copy2(orig_uninst, target_uninst)

    # 确定主执行文件路径
    target_exe = os.path.join(target_dir, "DesktopPet.exe")
    if not os.path.exists(target_exe):
        target_exe = os.path.join(target_dir, "run.bat")

    # 创建快捷方式
    print("[4/5] 正在创建快捷方式...")
    user_profile = os.environ.get("USERPROFILE", os.path.expanduser("~"))

    if create_desktop:
        desktop_dir = os.path.join(user_profile, "Desktop")
        desktop_lnk = os.path.join(desktop_dir, "桌面萌宠 · 波可.lnk")
        create_windows_shortcut(target_exe, desktop_lnk, target_dir, target_ico, "桌面萌宠 · 波可")
        print(f"  -> 已创建桌面快捷方式: {desktop_lnk}")

    if create_startmenu:
        programs_dir = os.path.join(os.environ.get("APPDATA", user_profile), r"Microsoft\Windows\Start Menu\Programs")
        start_lnk = os.path.join(programs_dir, "桌面萌宠 · 波可.lnk")
        create_windows_shortcut(target_exe, start_lnk, target_dir, target_ico, "桌面萌宠 · 波可")
        print(f"  -> 已创建开始菜单快捷方式: {start_lnk}")

    # 写入 Windows 已安装应用注册表
    print("[5/5] 注册至 Windows 系统已安装应用列表...")
    try:
        reg_path = r"Software\Microsoft\Windows\CurrentVersion\Uninstall\DesktopPet"
        with winreg.CreateKey(winreg.HKEY_CURRENT_USER, reg_path) as key:
            winreg.SetValueEx(key, "DisplayName", 0, winreg.REG_SZ, "桌面萌宠 · 波可 (Desktop Pet Poko)")
            winreg.SetValueEx(key, "DisplayVersion", 0, winreg.REG_SZ, "1.0.0")
            winreg.SetValueEx(key, "Publisher", 0, winreg.REG_SZ, "ElectricPet Studio")
            winreg.SetValueEx(key, "InstallLocation", 0, winreg.REG_SZ, target_dir)
            winreg.SetValueEx(key, "DisplayIcon", 0, winreg.REG_SZ, target_ico)
            winreg.SetValueEx(key, "UninstallString", 0, winreg.REG_SZ, f'"{target_uninst}"')
            winreg.SetValueEx(key, "NoModify", 0, winreg.REG_DWORD, 1)
            winreg.SetValueEx(key, "NoRepair", 0, winreg.REG_DWORD, 1)
    except Exception as e:
        print(f"Registry notice: {e}")

    # 开机自启设置
    if autostart:
        try:
            run_key = r"Software\Microsoft\Windows\CurrentVersion\Run"
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, run_key, 0, winreg.KEY_SET_VALUE) as key:
                winreg.SetValueEx(key, "DesktopElectricPet", 0, winreg.REG_SZ, f'"{target_exe}"')
        except Exception as e:
            print(f"Autostart notice: {e}")

    print("=" * 60)
    print("            [完成] 桌面萌宠 · 波可 安装成功！            ")
    print("=" * 60)

    if launch_after and not silent:
        print("正在启动萌宠...")
        subprocess.Popen([target_exe], cwd=target_dir, shell=True)

if __name__ == "__main__":
    silent_mode = "--silent" in sys.argv
    install(silent=silent_mode)
