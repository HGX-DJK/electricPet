import os
import sys
import shutil
import tempfile
import subprocess
import threading
import zipfile
import winreg
import ctypes
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

# 保证控制台即使在 GBK 编码下也不会因为字符报错
if sys.stdout and hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# 保证高分屏（DPI 缩放 125%、150%、200%）文字清晰细腻
try:
    ctypes.windll.shcore.SetProcessDpiAwareness(2)
except Exception:
    try:
        ctypes.windll.user32.SetProcessDPIAware()
    except Exception:
        pass

def get_bundle_resource(relative_path):
    """获取内嵌资源绝对路径（兼容 PyInstaller 单文件打包与源码调试）"""
    base_path = getattr(sys, "_MEIPASS", os.path.abspath(os.path.dirname(__file__)))
    target = os.path.join(base_path, relative_path)
    if os.path.exists(target):
        return target
    # 备选路径
    alt_target = os.path.join(os.path.abspath("."), relative_path)
    if os.path.exists(alt_target):
        return alt_target
    return target

def create_windows_shortcut(target_path, shortcut_path, working_dir, icon_path=None, description=""):
    """使用 Windows 原生 WScript.Shell 脚本创建快捷方式"""
    os.makedirs(os.path.dirname(shortcut_path), exist_ok=True)
    vbs_path = os.path.join(tempfile.gettempdir(), f"mk_lnk_{os.getpid()}_{id(shortcut_path)}.vbs")
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
        with open(vbs_path, "w", encoding="gbk", errors="replace") as f:
            f.write(vbs_content)
        subprocess.run(["cscript", "//nologo", vbs_path], check=True, capture_output=True)
    finally:
        if os.path.exists(vbs_path):
            try:
                os.remove(vbs_path)
            except Exception:
                pass

def do_core_install(target_dir, create_desktop, create_startmenu, autostart, launch_after, status_cb=None, progress_cb=None):
    """执行核心安装逻辑：解压 payload、建立快捷方式、注册表登记"""
    if status_cb: status_cb("正在检测并关闭旧版本运行进程...", 5)
    try:
        subprocess.run(["taskkill", "/F", "/IM", "DesktopPet.exe"], capture_output=True)
        import time
        time.sleep(1.0)
    except Exception:
        pass

    # 定位 payload 压缩包
    payload_zip = get_bundle_resource("payload.zip")
    if not os.path.exists(payload_zip):
        # 兼容开发环境从 dist 查找
        dev_zip = os.path.abspath("dist/payload.zip")
        if os.path.exists(dev_zip):
            payload_zip = dev_zip
        else:
            raise FileNotFoundError(f"未找到核心安装包组件 payload.zip！")

    os.makedirs(target_dir, exist_ok=True)

    if status_cb: status_cb("正在解压程序核心文件与运行环境...", 15)
    with zipfile.ZipFile(payload_zip, "r") as zf:
        file_list = zf.infolist()
        total = len(file_list)
        for idx, item in enumerate(file_list):
            zf.extract(item, target_dir)
            if idx % 10 == 0 or idx == total - 1:
                pct = 15 + int((idx + 1) / total * 60)
                if progress_cb: progress_cb(pct)

    target_exe = os.path.join(target_dir, "DesktopPet.exe")
    target_ico = os.path.join(target_dir, "assets", "app.ico")
    target_uninst = os.path.join(target_dir, "uninstall.bat")

    user_profile = os.environ.get("USERPROFILE", os.path.expanduser("~"))

    # 快捷方式
    if create_desktop:
        if status_cb: status_cb("正在生成桌面专属快捷方式...", 80)
        desktop_dir = os.path.join(user_profile, "Desktop")
        desktop_lnk = os.path.join(desktop_dir, "桌面萌宠 · 波可.lnk")
        create_windows_shortcut(target_exe, desktop_lnk, target_dir, target_ico, "桌面萌宠 · 波可")

    if create_startmenu:
        if status_cb: status_cb("正在配置 Windows 开始菜单项...", 85)
        programs_dir = os.path.join(os.environ.get("APPDATA", user_profile), r"Microsoft\Windows\Start Menu\Programs")
        start_lnk = os.path.join(programs_dir, "桌面萌宠 · 波可.lnk")
        create_windows_shortcut(target_exe, start_lnk, target_dir, target_ico, "桌面萌宠 · 波可")

    # 写入系统应用注册表
    if status_cb: status_cb("正在注册应用与卸载支持...", 90)
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

    # 开机自启
    if autostart:
        try:
            run_key = r"Software\Microsoft\Windows\CurrentVersion\Run"
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, run_key, 0, winreg.KEY_SET_VALUE) as key:
                winreg.SetValueEx(key, "DesktopElectricPet", 0, winreg.REG_SZ, f'"{target_exe}"')
        except Exception as e:
            print(f"Autostart notice: {e}")

    if status_cb: status_cb("[完成] 安装成功！波可已准备好与您相伴~", 100)

    if launch_after and os.path.exists(target_exe):
        subprocess.Popen([target_exe], cwd=target_dir, shell=True)

class SetupApp(tk.Tk):
    """现代风格独立单文件安装向导窗口"""
    def __init__(self):
        super().__init__()
        self.title("桌面萌宠 · 波可 安装向导")
        self.geometry("540x440")
        self.resizable(False, False)
        self.configure(bg="#F8FAFC")

        # 尝试设置窗口图标
        ico_path = get_bundle_resource("assets/app.ico")
        if not os.path.exists(ico_path):
            ico_path = os.path.abspath("assets/app.ico")
        if os.path.exists(ico_path):
            try:
                self.iconbitmap(ico_path)
            except Exception:
                pass

        # 居中显示
        self.update_idletasks()
        sw = self.winfo_screenwidth()
        sh = self.winfo_screenheight()
        x = (sw - 540) // 2
        y = (sh - 440) // 2
        self.geometry(f"540x440+{x}+{y}")

        self.default_install_dir = os.path.join(
            os.environ.get("LOCALAPPDATA", os.path.expanduser("~")),
            "Programs", "DesktopPet"
        )
        self.install_dir_var = tk.StringVar(value=self.default_install_dir)
        self.desktop_var = tk.BooleanVar(value=True)
        self.startmenu_var = tk.BooleanVar(value=True)
        self.autostart_var = tk.BooleanVar(value=False)
        self.launch_var = tk.BooleanVar(value=True)

        self.is_installed = False
        self._init_ui()

    def _init_ui(self):
        # 顶部品牌卡片
        top_frame = tk.Frame(self, bg="#4F46E5", height=90)
        top_frame.pack(fill="x", side="top")
        top_frame.pack_propagate(False)

        title_lbl = tk.Label(
            top_frame,
            text="🐾 桌面萌宠 · 波可 (Desktop Pet Poko)",
            font=("Microsoft YaHei UI", 15, "bold"),
            fg="#FFFFFF",
            bg="#4F46E5"
        )
        title_lbl.pack(anchor="w", padx=24, pady=(16, 2))

        sub_lbl = tk.Label(
            top_frame,
            text="版本 1.0.0 | 治愈系高颜值桌面电子宠物伴侣 · 一键安装包",
            font=("Microsoft YaHei UI", 9),
            fg="#C7D2FE",
            bg="#4F46E5"
        )
        sub_lbl.pack(anchor="w", padx=24)

        # 内容区
        content_frame = tk.Frame(self, bg="#F8FAFC", padx=24, pady=16)
        content_frame.pack(fill="both", expand=True)

        # 安装目录选择
        dir_lbl = tk.Label(
            content_frame,
            text="📁 安装目标目录（推荐使用默认个人目录，无需管理员权限）：",
            font=("Microsoft YaHei UI", 9, "bold"),
            fg="#334155",
            bg="#F8FAFC"
        )
        dir_lbl.pack(anchor="w", pady=(0, 6))

        dir_box = tk.Frame(content_frame, bg="#F8FAFC")
        dir_box.pack(fill="x", pady=(0, 14))

        self.entry_dir = tk.Entry(
            dir_box,
            textvariable=self.install_dir_var,
            font=("Microsoft YaHei UI", 9),
            relief="solid",
            bd=1,
            fg="#1E293B",
            bg="#FFFFFF"
        )
        self.entry_dir.pack(side="left", fill="x", expand=True, ipady=4, padx=(0, 8))

        btn_browse = tk.Button(
            dir_box,
            text="浏览...",
            command=self._on_browse,
            font=("Microsoft YaHei UI", 9),
            bg="#EEF2FF",
            fg="#4338CA",
            relief="flat",
            activebackground="#E0E7FF",
            bd=0,
            padx=12,
            pady=3,
            cursor="hand2"
        )
        btn_browse.pack(side="right")

        # 选项复选框
        opts_frame = tk.LabelFrame(
            content_frame,
            text=" 安装选项 ",
            font=("Microsoft YaHei UI", 9, "bold"),
            fg="#475569",
            bg="#F8FAFC",
            padx=12,
            pady=8
        )
        opts_frame.pack(fill="x", pady=(0, 14))

        row1 = tk.Frame(opts_frame, bg="#F8FAFC")
        row1.pack(fill="x", pady=2)
        tk.Checkbutton(row1, text="创建桌面快捷方式", variable=self.desktop_var, font=("Microsoft YaHei UI", 9), bg="#F8FAFC", activebackground="#F8FAFC").pack(side="left", padx=(0, 20))
        tk.Checkbutton(row1, text="添加至开始菜单", variable=self.startmenu_var, font=("Microsoft YaHei UI", 9), bg="#F8FAFC", activebackground="#F8FAFC").pack(side="left")

        row2 = tk.Frame(opts_frame, bg="#F8FAFC")
        row2.pack(fill="x", pady=2)
        tk.Checkbutton(row2, text="开机自动启动", variable=self.autostart_var, font=("Microsoft YaHei UI", 9), bg="#F8FAFC", activebackground="#F8FAFC").pack(side="left", padx=(0, 48))
        tk.Checkbutton(row2, text="安装完成后立即启动", variable=self.launch_var, font=("Microsoft YaHei UI", 9), bg="#F8FAFC", activebackground="#F8FAFC").pack(side="left")

        # 进度与状态
        self.status_lbl = tk.Label(
            content_frame,
            text="准备就绪，点击下方按钮一键极速安装",
            font=("Microsoft YaHei UI", 9),
            fg="#64748B",
            bg="#F8FAFC"
        )
        self.status_lbl.pack(anchor="w", pady=(0, 4))

        style = ttk.Style(self)
        style.theme_use("clam")
        style.configure("Accent.Horizontal.TProgressbar", foreground="#4F46E5", background="#4F46E5", troughcolor="#E2E8F0", borderwidth=0)

        self.progress = ttk.Progressbar(content_frame, style="Accent.Horizontal.TProgressbar", orient="horizontal", mode="determinate")
        self.progress.pack(fill="x", pady=(0, 14))

        # 底部操作按钮
        self.btn_action = tk.Button(
            content_frame,
            text="一键安装 桌面萌宠 · 波可",
            command=self._on_action_click,
            font=("Microsoft YaHei UI", 11, "bold"),
            bg="#4F46E5",
            fg="#FFFFFF",
            activebackground="#4338CA",
            activeforeground="#FFFFFF",
            relief="flat",
            bd=0,
            pady=8,
            cursor="hand2"
        )
        self.btn_action.pack(fill="x")

    def _on_browse(self):
        chosen = filedialog.askdirectory(initialdir=self.install_dir_var.get(), title="选择萌宠安装目录")
        if chosen:
            self.install_dir_var.set(os.path.normpath(chosen))

    def _on_action_click(self):
        if self.is_installed:
            self.destroy()
            return

        self.btn_action.config(state="disabled", text="正在安装中，请稍候...", bg="#94A3B8")
        self.entry_dir.config(state="disabled")

        t = threading.Thread(target=self._run_install_worker, daemon=True)
        t.start()

    def _run_install_worker(self):
        try:
            target_dir = self.install_dir_var.get().strip()
            do_core_install(
                target_dir=target_dir,
                create_desktop=self.desktop_var.get(),
                create_startmenu=self.startmenu_var.get(),
                autostart=self.autostart_var.get(),
                launch_after=self.launch_var.get(),
                status_cb=self._update_status,
                progress_cb=self._update_progress
            )
            self.after(0, self._on_install_success)
        except Exception as e:
            self.after(0, lambda: self._on_install_error(str(e)))

    def _update_status(self, text, pct=None):
        def _update():
            self.status_lbl.config(text=text)
            if pct is not None:
                self.progress["value"] = pct
        self.after(0, _update)

    def _update_progress(self, val):
        self.after(0, lambda: self.progress.configure(value=val))

    def _on_install_success(self):
        self.is_installed = True
        self.progress["value"] = 100
        self.status_lbl.config(text="🎉 安装成功！波可已来到您的桌面，开始陪伴您~", fg="#059669")
        self.btn_action.config(
            state="normal",
            text="完成并进入萌宠世界 ✨",
            bg="#059669",
            activebackground="#047857"
        )

    def _on_install_error(self, err_msg):
        self.status_lbl.config(text=f"❌ 安装发生错误: {err_msg}", fg="#DC2626")
        self.btn_action.config(state="normal", text="重试安装", bg="#EF4444")
        self.entry_dir.config(state="normal")
        messagebox.showerror("安装失败", f"安装过程中发生异常：\n{err_msg}")

def main():
    if "--silent" in sys.argv or "/S" in sys.argv or "/silent" in sys.argv:
        # 静默安装模式
        target = None
        for arg in sys.argv:
            if arg.startswith("--dir="):
                target = arg.split("=", 1)[1]
        if not target:
            target = os.path.join(os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Programs", "DesktopPet")
        print(f"[Silent Install] Installing to {target}...")
        do_core_install(
            target_dir=target,
            create_desktop=True,
            create_startmenu=True,
            autostart=False,
            launch_after=True,
            status_cb=lambda msg, pct: print(f"[{pct}%] {msg}")
        )
        print("[Silent Install] Completed successfully!")
        sys.exit(0)

    app = SetupApp()
    app.mainloop()

if __name__ == "__main__":
    main()
