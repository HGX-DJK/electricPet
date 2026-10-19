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
from tkinter import filedialog, messagebox
from PIL import Image, ImageTk, ImageDraw, ImageColor

# 保证控制台即使在 GBK 编码下也不会因为特殊字符报错
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

def launch_installed_app(target_exe, target_dir):
    """安全独立唤起已安装的萌宠主程序，彻底脱离 PyInstaller 打包环境的干扰"""
    if not target_exe or not os.path.exists(target_exe):
        return False
    # 清理 PyInstaller 打包环境下传递给子进程的特殊环境变量，防止引导 DLL/模块寻址错乱
    clean_env = dict(os.environ)
    for key in ("_MEIPASS2", "_MEIPASS", "PYTHONPATH", "PYTHONHOME", "PYTHONEXECUTABLE"):
        clean_env.pop(key, None)

    # 优先使用 Windows subprocess 独立分离进程组拉起 (明确工作目录与纯净环境)
    try:
        flags = 0x00000008 | 0x00000200  # DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP
        subprocess.Popen([target_exe], cwd=target_dir, env=clean_env, creationflags=flags)
        return True
    except Exception as e:
        print("subprocess launch notice:", e)

    # 备选使用 Windows 原生 ShellExecute (os.startfile)
    if hasattr(os, "startfile"):
        try:
            os.startfile(target_exe)
            return True
        except Exception as e:
            print("os.startfile launch notice:", e)

    return False

def do_core_install(target_dir, create_desktop, create_startmenu, autostart, launch_after, status_cb=None, progress_cb=None):
    """执行核心安装逻辑：解压 payload、建立快捷方式、注册表登记"""
    if status_cb: status_cb("正在检测并安全关闭旧版本运行进程...", 5)
    try:
        import time
        # 先发送温和关闭请求，允许主程序触发 save_to_disk() 完整保存当前成长进度与便签
        subprocess.run(["taskkill", "/IM", "DesktopPet.exe"], capture_output=True)
        time.sleep(1.2)
        # 若仍有顽固残留进程再强制终止
        subprocess.run(["taskkill", "/F", "/IM", "DesktopPet.exe"], capture_output=True)
        time.sleep(0.4)
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
            raise FileNotFoundError("未找到核心安装包组件 payload.zip！")

    os.makedirs(target_dir, exist_ok=True)

    if status_cb: status_cb("正在解压程序核心文件与运行环境...", 15)
    with zipfile.ZipFile(payload_zip, "r") as zf:
        file_list = zf.infolist()
        total = len(file_list)
        for idx, item in enumerate(file_list):
            zf.extract(item, target_dir)
            if idx % 8 == 0 or idx == total - 1:
                pct = 15 + int((idx + 1) / total * 65)
                if progress_cb: progress_cb(pct)

    target_exe = os.path.join(target_dir, "DesktopPet.exe")
    target_ico = os.path.join(target_dir, "assets", "app.ico")
    target_uninst = os.path.join(target_dir, "uninstall.bat")
    uninst_script = (
        "@echo off\r\n"
        "chcp 65001 >nul\r\n"
        "title 桌面萌宠 · 波可 卸载程序\r\n"
        "echo ========================================================\r\n"
        "echo          桌面萌宠 · 波可 (Desktop Pet) 卸载程序\r\n"
        "echo ========================================================\r\n"
        "echo.\r\n"
        "echo [1/4] 正在关闭萌宠后台运行进程...\r\n"
        "taskkill /F /IM DesktopPet.exe >nul 2>nul\r\n"
        "echo [2/4] 正在清理桌面与开始菜单快捷方式...\r\n"
        "del /f /q \"%USERPROFILE%\\Desktop\\*波可*.lnk\" >nul 2>nul\r\n"
        "del /f /q \"%USERPROFILE%\\Desktop\\*DesktopPet*.lnk\" >nul 2>nul\r\n"
        "del /f /q \"%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\*波可*.lnk\" >nul 2>nul\r\n"
        "del /f /q \"%APPDATA%\\Microsoft\\Windows\\Start Menu\\Programs\\*DesktopPet*.lnk\" >nul 2>nul\r\n"
        "echo [3/4] 正在清理系统控制面板与开机注册项...\r\n"
        "reg delete \"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\DesktopPet\" /f >nul 2>nul\r\n"
        "reg delete \"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\" /v \"DesktopElectricPet\" /f >nul 2>nul\r\n"
        "echo [4/4] 正在移除应用程序文件...\r\n"
        "set \"TARGET_DIR=%~dp0\"\r\n"
        "if \"%TARGET_DIR:~-1%\"==\"\\\" set \"TARGET_DIR=%TARGET_DIR:~0,-1%\"\r\n"
        "cd /d \"%USERPROFILE%\"\r\n"
        "echo.\r\n"
        "echo ========================================================\r\n"
        "echo          卸载完成！波可期待下次与您相遇~\r\n"
        "echo ========================================================\r\n"
        "echo.\r\n"
        "timeout /t 2 /nobreak >nul\r\n"
        "start \"\" /b cmd /c \"timeout /t 1 /nobreak >nul & rd /s /q \"\"%TARGET_DIR%\"\"\"\r\n"
        "exit\r\n"
    )
    try:
        with open(target_uninst, "w", encoding="utf-8") as f:
            f.write(uninst_script)
    except Exception:
        pass

    user_profile = os.environ.get("USERPROFILE", os.path.expanduser("~"))

    # 快捷方式
    if create_desktop:
        if status_cb: status_cb("正在生成桌面专属快捷方式...", 85)
        desktop_dir = os.path.join(user_profile, "Desktop")
        desktop_lnk = os.path.join(desktop_dir, "桌面萌宠 · 波可.lnk")
        create_windows_shortcut(target_exe, desktop_lnk, target_dir, target_ico, "桌面萌宠 · 波可")

    if create_startmenu:
        if status_cb: status_cb("正在配置 Windows 开始菜单项...", 90)
        programs_dir = os.path.join(os.environ.get("APPDATA", user_profile), r"Microsoft\Windows\Start Menu\Programs")
        start_lnk = os.path.join(programs_dir, "桌面萌宠 · 波可.lnk")
        create_windows_shortcut(target_exe, start_lnk, target_dir, target_ico, "桌面萌宠 · 波可")

    # 写入系统应用注册表
    if status_cb: status_cb("正在注册应用与卸载支持...", 95)
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

    if status_cb: status_cb("安装完成！波可已准备好与您相伴~", 100)

    if launch_after and os.path.exists(target_exe):
        launch_installed_app(target_exe, target_dir)

# ----------------- 现代 UI 渲染辅助方法 -----------------

def make_rounded_rect_image(w, h, r, color1, color2=None, outline=None, outline_w=1):
    """生成抗锯齿圆角矩形/渐变位图（超采样 2x 缩放）"""
    scale = 2
    sw, sh, sr = w * scale, h * scale, r * scale
    
    if color2 and color1 != color2:
        c1 = ImageColor.getrgb(color1)
        c2 = ImageColor.getrgb(color2)
        base = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
        for y in range(sh):
            ratio = y / max(1, sh - 1)
            r_c = int(c1[0] + (c2[0] - c1[0]) * ratio)
            g_c = int(c1[1] + (c2[1] - c1[1]) * ratio)
            b_c = int(c1[2] + (c2[2] - c1[2]) * ratio)
            ImageDraw.Draw(base).line([(0, y), (sw, y)], fill=(r_c, g_c, b_c, 255))
        mask = Image.new("L", (sw, sh), 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], radius=sr, fill=255)
        base.putalpha(mask)
        res = base
    else:
        img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([0, 0, sw - 1, sh - 1], radius=sr, fill=color1)
        res = img
        
    if outline:
        d_out = ImageDraw.Draw(res)
        d_out.rounded_rectangle([0, 0, sw - 1, sh - 1], radius=sr, outline=outline, width=outline_w * scale)
        
    return res.resize((w, h), Image.Resampling.LANCZOS)

def create_header_banner(w, h, icon_path):
    """绘制顶部 Hero 渐变横幅与萌宠徽章"""
    scale = 2
    sw, sh = w * scale, h * scale
    banner = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    d = ImageDraw.Draw(banner)
    
    # 暖阳蜜桃落日渐变 (#FF885A -> #FFA06A -> #FF7E92)，温润治愈，与波可猫咪原画色调自然融合
    c_start = (255, 136, 90)   # #FF885A 暖杏珊瑚
    c_mid   = (255, 160, 106)  # #FFA06A 暖阳蜜桃
    c_end   = (255, 126, 146)  # #FF7E92 柔粉花瓣
    
    for x in range(sw):
        ratio = x / max(1, sw - 1)
        if ratio < 0.5:
            sub_r = ratio * 2
            r = int(c_start[0] + (c_mid[0] - c_start[0]) * sub_r)
            g = int(c_start[1] + (c_mid[1] - c_start[1]) * sub_r)
            b = int(c_start[2] + (c_mid[2] - c_start[2]) * sub_r)
        else:
            sub_r = (ratio - 0.5) * 2
            r = int(c_mid[0] + (c_end[0] - c_mid[0]) * sub_r)
            g = int(c_mid[1] + (c_end[1] - c_mid[1]) * sub_r)
            b = int(c_mid[2] + (c_end[2] - c_mid[2]) * sub_r)
        d.line([(x, 0), (x, sh)], fill=(r, g, b, 255))
        
    # 装饰性微光圆环（右上角）
    glow = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    d_glow = ImageDraw.Draw(glow)
    d_glow.ellipse((sw - 200 * scale, -50 * scale, sw + 80 * scale, 220 * scale), fill=(255, 255, 255, 22))
    d_glow.ellipse((sw - 150 * scale, -10 * scale, sw + 30 * scale, 170 * scale), outline=(255, 255, 255, 45), width=2 * scale)
    banner = Image.alpha_composite(banner, glow)
    
    # 叠加萌宠圆形头像徽章
    if icon_path and os.path.exists(icon_path):
        try:
            av_size = 78 * scale
            border_w = 4 * scale
            cat_raw = Image.open(icon_path).convert("RGBA")
            
            # 柔和白色微光晕圈
            badge_halo = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
            d_halo = ImageDraw.Draw(badge_halo)
            pos_x = 22 * scale
            pos_y = int((sh - av_size) / 2)
            d_halo.ellipse((pos_x - 2 * scale, pos_y - 2 * scale, pos_x + av_size + 2 * scale, pos_y + av_size + 2 * scale), fill=(255, 255, 255, 55))
            banner = Image.alpha_composite(banner, badge_halo)
            
            av_img = Image.new("RGBA", (av_size, av_size), (0, 0, 0, 0))
            d_av = ImageDraw.Draw(av_img)
            d_av.ellipse((0, 0, av_size - 1, av_size - 1), fill=(255, 255, 255, 255))
            
            inner_s = av_size - border_w * 2
            cat_inner = cat_raw.resize((inner_s, inner_s), Image.Resampling.LANCZOS)
            inner_mask = Image.new("L", (inner_s, inner_s), 0)
            ImageDraw.Draw(inner_mask).ellipse((0, 0, inner_s - 1, inner_s - 1), fill=255)
            av_img.paste(cat_inner, (border_w, border_w), inner_mask)
            
            banner.paste(av_img, (pos_x, pos_y), av_img)
        except Exception as e:
            print("Avatar error:", e)
            
    # 版本气泡胶囊 (半透明白色背景)
    pill_img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    d_pill = ImageDraw.Draw(pill_img)
    pill_x1 = 282 * scale
    pill_y1 = 22 * scale
    pill_x2 = 416 * scale
    pill_y2 = 46 * scale
    d_pill.rounded_rectangle([pill_x1, pill_y1, pill_x2, pill_y2], radius=11 * scale, fill=(255, 255, 255, 55), outline=(255, 255, 255, 110), width=scale)
    banner = Image.alpha_composite(banner, pill_img)
    
    return banner.resize((w, h), Image.Resampling.LANCZOS)

def make_checkbox_icons():
    """生成抗锯齿高精度现代复选框位图"""
    scale = 3
    s = 20 * scale
    r = 5 * scale
    
    # Checked - 温暖活力珊瑚橙
    img_c = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dc = ImageDraw.Draw(img_c)
    dc.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, fill="#F97316")
    coords = [(s * 0.26, s * 0.52), (s * 0.44, s * 0.70), (s * 0.74, s * 0.30)]
    dc.line(coords, fill="#FFFFFF", width=int(2.4 * scale), joint="curve")
    checked_img = img_c.resize((20, 20), Image.Resampling.LANCZOS)
    
    # Unchecked - 简洁柔和浅灰边框
    img_u = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    du = ImageDraw.Draw(img_u)
    du.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, fill="#FFFFFF", outline="#CBD5E1", width=int(1.6 * scale))
    unchecked_img = img_u.resize((20, 20), Image.Resampling.LANCZOS)
    
    # Hover Checked - 浓郁焦糖暖橙
    img_ch = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dch = ImageDraw.Draw(img_ch)
    dch.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, fill="#EA580C")
    dch.line(coords, fill="#FFFFFF", width=int(2.4 * scale), joint="curve")
    hover_checked_img = img_ch.resize((20, 20), Image.Resampling.LANCZOS)

    # Hover Unchecked - 悬停时柔和暖橙边框
    img_uh = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    duh = ImageDraw.Draw(img_uh)
    duh.rounded_rectangle([0, 0, s - 1, s - 1], radius=r, fill="#FFFFFF", outline="#FB923C", width=int(1.8 * scale))
    hover_unchecked_img = img_uh.resize((20, 20), Image.Resampling.LANCZOS)
    
    return checked_img, unchecked_img, hover_checked_img, hover_unchecked_img

class ModernOptionCard(tk.Frame):
    """现代质感卡片式选项组件，带悬浮光效与平滑边框变化"""
    def __init__(self, master, title, subtitle, variable, icon_checked, icon_unchecked, icon_h_checked, icon_h_unchecked, command=None, **kwargs):
        super().__init__(master, bg="#F1F5F9", highlightbackground="#E2E8F0", highlightthickness=1, bd=0, cursor="hand2", **kwargs)
        self.var = variable
        self.command = command
        self.icon_c = icon_checked
        self.icon_u = icon_unchecked
        self.icon_hc = icon_h_checked
        self.icon_hu = icon_h_unchecked
        self.is_hover = False
        self.is_disabled = False
        
        self.inner = tk.Frame(self, bg="#FFFFFF", padx=12, pady=7)
        self.inner.pack(fill="both", expand=True)
        
        self.lbl_icon = tk.Label(self.inner, bg="#FFFFFF", image=self.icon_c if self.var.get() else self.icon_u)
        self.lbl_icon.pack(side="left", padx=(0, 10))
        
        txt_box = tk.Frame(self.inner, bg="#FFFFFF")
        txt_box.pack(side="left", fill="both", expand=True)
        
        self.lbl_title = tk.Label(txt_box, text=title, font=("Microsoft YaHei UI", 9, "bold"), fg="#1E293B", bg="#FFFFFF")
        self.lbl_title.pack(anchor="w")
        
        self.lbl_sub = tk.Label(txt_box, text=subtitle, font=("Microsoft YaHei UI", 8), fg="#64748B", bg="#FFFFFF")
        self.lbl_sub.pack(anchor="w")
        
        for w in (self, self.inner, self.lbl_icon, txt_box, self.lbl_title, self.lbl_sub):
            w.bind("<Button-1>", self._on_click)
            w.bind("<Enter>", self._on_enter)
            w.bind("<Leave>", self._on_leave)
            
    def set_enabled(self, enabled):
        self.is_disabled = not enabled
        if self.is_disabled:
            self.config(cursor="arrow")
        else:
            self.config(cursor="hand2")
        self._update_view()
            
    def _update_view(self):
        val = self.var.get()
        if self.is_disabled:
            self.config(highlightbackground="#E2E8F0")
            self.inner.config(bg="#F8FAFC")
            self.lbl_icon.config(bg="#F8FAFC")
            self.lbl_title.master.config(bg="#F8FAFC")
            self.lbl_title.config(bg="#F8FAFC", fg="#94A3B8")
            self.lbl_sub.config(bg="#F8FAFC", fg="#CBD5E1")
            return
            
        if self.is_hover:
            img = self.icon_hc if val else self.icon_hu
            bg_col = "#FFFBF7"       # 极柔和暖杏乳白
            border_col = "#FDBA74"   # 温暖琥珀橙边框
            t_col = "#C2410C"        # 焦糖暖橙标题
        else:
            img = self.icon_c if val else self.icon_u
            bg_col = "#FFFFFF"
            border_col = "#E2E8F0"
            t_col = "#1E293B"
            
        self.config(highlightbackground=border_col)
        self.inner.config(bg=bg_col)
        self.lbl_icon.config(bg=bg_col, image=img)
        self.lbl_title.master.config(bg=bg_col)
        self.lbl_title.config(bg=bg_col, fg=t_col)
        self.lbl_sub.config(bg=bg_col, fg="#64748B")
        
    def _on_click(self, event=None):
        if self.is_disabled:
            return
        self.var.set(not self.var.get())
        self._update_view()
        if self.command:
            self.command()
            
    def _on_enter(self, event=None):
        if self.is_disabled:
            return
        self.is_hover = True
        self._update_view()
        
    def _on_leave(self, event=None):
        if self.is_disabled:
            return
        # Check if mouse is still within the widget bounds
        try:
            x, y = self.winfo_pointerxy()
            widget_x = self.winfo_rootx()
            widget_y = self.winfo_rooty()
            widget_w = self.winfo_width()
            widget_h = self.winfo_height()
            if widget_x <= x <= widget_x + widget_w and widget_y <= y <= widget_y + widget_h:
                return  # Mouse is still inside the card, ignore the leave event
        except Exception:
            pass
        self.is_hover = False
        self._update_view()

class CapsuleProgressBar(tk.Canvas):
    """胶囊形状平滑进度条"""
    def __init__(self, master, width=504, height=10, **kwargs):
        super().__init__(master, width=width, height=height, bg="#FFFFFF", highlightthickness=0, bd=0, **kwargs)
        self.w = width
        self.h = height
        self.pct = 0
        self._draw()
        
    def set_progress(self, pct):
        self.pct = max(0, min(100, pct))
        self._draw()
        
    def _draw(self):
        self.delete("all")
        cy = self.h / 2
        pad = self.h / 2
        # 底色轨道
        self.create_line(pad, cy, self.w - pad, cy, width=self.h, capstyle=tk.ROUND, fill="#F1F5F9")
        # 进度填充 - 温暖活力珊瑚橙
        if self.pct > 0:
            fill_w = pad + (self.w - pad * 2) * (self.pct / 100.0)
            fill_w = max(pad * 1.5, fill_w)
            self.create_line(pad, cy, fill_w, cy, width=self.h, capstyle=tk.ROUND, fill="#FF6B4A")

class RoundedButton(tk.Canvas):
    """现代高质感圆角渐变主按钮"""
    def __init__(self, master, width=504, height=44, radius=8, command=None, **kwargs):
        super().__init__(master, width=width, height=height, bg="#FFFFFF", highlightthickness=0, bd=0, cursor="hand2", **kwargs)
        self.w = width
        self.h = height
        self.radius = radius
        self.command = command
        self.is_hover = False
        self.state_mode = "normal"
        self.text = "🚀 立即一键安装 (极速解压)"
        
        # 预先生成各种状态纹理 - 温暖夕阳珊瑚主按钮 (超柔和质感与立体微渐变)
        self.img_normal = ImageTk.PhotoImage(make_rounded_rect_image(width, height, radius, "#FF7A55", "#EA580C"))
        self.img_hover  = ImageTk.PhotoImage(make_rounded_rect_image(width, height, radius, "#FF8A6B", "#D9480F"))
        self.img_dis    = ImageTk.PhotoImage(make_rounded_rect_image(width, height, radius, "#CBD5E1"))
        self.img_succ   = ImageTk.PhotoImage(make_rounded_rect_image(width, height, radius, "#10B981", "#059669"))
        self.img_succ_h = ImageTk.PhotoImage(make_rounded_rect_image(width, height, radius, "#059669", "#047857"))
        
        self.bind("<Button-1>", self._on_click)
        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
        self._render()
        
    def set_state(self, mode, text):
        self.state_mode = mode
        self.text = text
        if mode == "disabled":
            self.config(cursor="arrow")
        else:
            self.config(cursor="hand2")
        self._render()
        
    def _render(self):
        self.delete("all")
        if self.state_mode == "disabled":
            img = self.img_dis
        elif self.state_mode == "success":
            img = self.img_succ_h if self.is_hover else self.img_succ
        else:
            img = self.img_hover if self.is_hover else self.img_normal
            
        self.create_image(self.w // 2, self.h // 2, image=img)
        self.create_text(
            self.w // 2, self.h // 2,
            text=self.text,
            fill="#FFFFFF",
            font=("Microsoft YaHei UI", 11, "bold")
        )
        
    def _on_enter(self, e):
        if self.state_mode != "disabled":
            self.is_hover = True
            self._render()
            
    def _on_leave(self, e):
        if self.state_mode != "disabled":
            self.is_hover = False
            self._render()
            
    def _on_click(self, e):
        if self.state_mode != "disabled" and self.command:
            self.command()

# ----------------- 现代独立安装向导主窗体 -----------------

class SetupApp(tk.Tk):
    """现代精品卡片风格单文件安装向导窗口"""
    def __init__(self):
        super().__init__()
        self.title("桌面萌宠 · 波可 安装向导")
        self.geometry("580x605")
        self.resizable(False, False)
        self.configure(bg="#FAF9F6")

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
        x = (sw - 580) // 2
        y = (sh - 605) // 2
        self.geometry(f"580x605+{x}+{y}")

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
        self._already_launched = False
        self.protocol("WM_DELETE_WINDOW", self._on_window_close)
        self._init_ui()

    def _init_ui(self):
        # 1. 顶部 Hero Banner (118px)
        icon_path = get_bundle_resource("assets/app.png")
        if not os.path.exists(icon_path):
            icon_path = os.path.abspath("assets/app.png")
            
        self.banner_img = ImageTk.PhotoImage(create_header_banner(580, 118, icon_path))
        
        banner_canvas = tk.Canvas(self, width=580, height=118, highlightthickness=0, bd=0)
        banner_canvas.pack(fill="x", side="top")
        banner_canvas.create_image(290, 59, image=self.banner_img)
        
        banner_canvas.create_text(
            116, 35,
            anchor="w",
            text="桌面萌宠 · 波可",
            fill="#FFFFFF",
            font=("Microsoft YaHei UI", 16, "bold")
        )
        banner_canvas.create_text(
            349, 34,
            anchor="center",
            text="v1.0.0 官方正式版",
            fill="#FFFFFF",
            font=("Microsoft YaHei UI", 8, "bold")
        )
        banner_canvas.create_text(
            116, 66,
            anchor="w",
            text="超治愈 3D 桌面萌宠伙伴 · 智能互动桌面宠物",
            fill="#FFF7ED",
            font=("Microsoft YaHei UI", 9)
        )
        banner_canvas.create_text(
            116, 88,
            anchor="w",
            text="✦ 灵动交互   ✦ 丰富动作   ✦ 轻量极速低占用",
            fill="#FFEDD5",
            font=("Microsoft YaHei UI", 8)
        )
        
        # 2. 居中白色主卡片区
        card_outer = tk.Frame(self, bg="#FAF9F6", padx=18, pady=12)
        card_outer.pack(fill="both", expand=True)
        
        main_card = tk.Frame(card_outer, bg="#FFFFFF", highlightbackground="#EAE5DF", highlightthickness=1, bd=0)
        main_card.pack(fill="both", expand=True)
        
        card_inner = tk.Frame(main_card, bg="#FFFFFF", padx=18, pady=14)
        card_inner.pack(fill="both", expand=True)
        
        # --- A. 安装路径 ---
        dir_header = tk.Frame(card_inner, bg="#FFFFFF")
        dir_header.pack(fill="x", pady=(0, 6))
        
        tk.Label(
            dir_header,
            text="📁 安装目标目录",
            font=("Microsoft YaHei UI", 9, "bold"),
            fg="#1E293B",
            bg="#FFFFFF"
        ).pack(side="left")
        
        tk.Label(
            dir_header,
            text="（推荐使用默认用户目录，无需管理员权限）",
            font=("Microsoft YaHei UI", 8),
            fg="#94A3B8",
            bg="#FFFFFF"
        ).pack(side="left", padx=(6, 0))
        
        # 输入条边框容器 (高亮聚焦微交互)
        self.entry_box = tk.Frame(card_inner, bg="#FAFAF9", highlightbackground="#E2E8F0", highlightthickness=1, bd=0)
        self.entry_box.pack(fill="x", pady=(0, 6))
        
        entry_inner = tk.Frame(self.entry_box, bg="#FAFAF9", padx=10, pady=5)
        entry_inner.pack(fill="both", expand=True)
        
        self.entry_dir = tk.Entry(
            entry_inner,
            textvariable=self.install_dir_var,
            font=("Microsoft YaHei UI", 9),
            bg="#FAFAF9",
            fg="#1E293B",
            bd=0,
            relief="flat",
            highlightthickness=0
        )
        self.entry_dir.pack(side="left", fill="x", expand=True)
        
        self.entry_dir.bind("<FocusIn>", lambda e: self.entry_box.config(highlightbackground="#FB923C"))
        self.entry_dir.bind("<FocusOut>", lambda e: self.entry_box.config(highlightbackground="#E2E8F0"))
        
        self.btn_browse = tk.Button(
            entry_inner,
            text=" 浏览... ",
            command=self._on_browse,
            font=("Microsoft YaHei UI", 9, "bold"),
            bg="#FFF7ED",
            fg="#EA580C",
            activebackground="#FFEDD5",
            activeforeground="#C2410C",
            relief="flat",
            bd=0,
            padx=14,
            pady=3,
            cursor="hand2"
        )
        self.btn_browse.pack(side="right", padx=(6, 0))
        
        # 磁盘空间指示
        self.space_lbl = tk.Label(
            card_inner,
            text=self._get_space_text(),
            font=("Microsoft YaHei UI", 8),
            fg="#64748B",
            bg="#FFFFFF"
        )
        self.space_lbl.pack(anchor="w", pady=(0, 12))
        
        # --- B. 选项卡片区 ---
        tk.Label(
            card_inner,
            text="⚙️ 安装偏好",
            font=("Microsoft YaHei UI", 9, "bold"),
            fg="#1E293B",
            bg="#FFFFFF"
        ).pack(anchor="w", pady=(0, 6))
        
        c_img, u_img, hc_img, hu_img = make_checkbox_icons()
        self.ic_c = ImageTk.PhotoImage(c_img)
        self.ic_u = ImageTk.PhotoImage(u_img)
        self.ic_hc = ImageTk.PhotoImage(hc_img)
        self.ic_hu = ImageTk.PhotoImage(hu_img)
        
        grid_frame = tk.Frame(card_inner, bg="#FFFFFF")
        grid_frame.pack(fill="x", pady=(0, 14))
        grid_frame.columnconfigure(0, weight=1)
        grid_frame.columnconfigure(1, weight=1)
        
        self.opt1 = ModernOptionCard(grid_frame, "创建桌面快捷方式", "在桌面生成波可萌宠图标", self.desktop_var, self.ic_c, self.ic_u, self.ic_hc, self.ic_hu)
        self.opt1.grid(row=0, column=0, sticky="ew", padx=(0, 5), pady=3)
        
        self.opt2 = ModernOptionCard(grid_frame, "添加至开始菜单", "在 Windows 程序组中登记", self.startmenu_var, self.ic_c, self.ic_u, self.ic_hc, self.ic_hu)
        self.opt2.grid(row=0, column=1, sticky="ew", padx=(5, 0), pady=3)
        
        self.opt3 = ModernOptionCard(grid_frame, "开机自动启动", "登录系统后波可自动现身", self.autostart_var, self.ic_c, self.ic_u, self.ic_hc, self.ic_hu)
        self.opt3.grid(row=1, column=0, sticky="ew", padx=(0, 5), pady=3)
        
        self.opt4 = ModernOptionCard(grid_frame, "安装完成后立即启动", "解压完成后即刻开启陪伴", self.launch_var, self.ic_c, self.ic_u, self.ic_hc, self.ic_hu)
        self.opt4.grid(row=1, column=1, sticky="ew", padx=(5, 0), pady=3)
        
        # --- C. 进度与状态 ---
        status_row = tk.Frame(card_inner, bg="#FFFFFF")
        status_row.pack(fill="x", pady=(0, 4))
        
        self.status_lbl = tk.Label(
            status_row,
            text="✨ 准备就绪，点击下方按钮一键安装",
            font=("Microsoft YaHei UI", 9),
            fg="#475569",
            bg="#FFFFFF"
        )
        self.status_lbl.pack(side="left")
        
        self.pct_lbl = tk.Label(
            status_row,
            text="0%",
            font=("Microsoft YaHei UI", 9, "bold"),
            fg="#EA580C",
            bg="#FFFFFF"
        )
        self.pct_lbl.pack(side="right")
        
        # 胶囊进度条 (504px 宽度)
        self.progress_bar = CapsuleProgressBar(card_inner, width=504, height=10)
        self.progress_bar.pack(fill="x", pady=(0, 12))
        
        # --- D. 底部操作按钮 ---
        self.btn_action = RoundedButton(
            card_inner,
            width=504,
            height=44,
            radius=8,
            command=self._on_action_click
        )
        self.btn_action.pack(fill="x", pady=(0, 10))
        
        # 纯净安全保障标识
        tk.Label(
            card_inner,
            text="🛡️ 纯净安全 · 无广告弹窗 · 支持 Windows 7 / 10 / 11 · 随时控制面板一键卸载",
            font=("Microsoft YaHei UI", 8),
            fg="#94A3B8",
            bg="#FFFFFF"
        ).pack(side="top", pady=(2, 0))

    def _get_space_text(self):
        try:
            drive = os.path.splitdrive(self.install_dir_var.get())[0]
            if not drive:
                drive = "C:"
            usage = shutil.disk_usage(drive)
            free_gb = usage.free / (1024 ** 3)
            return f"所需磁盘空间: 约 120 MB    |    当前盘符可用空间: {free_gb:.1f} GB ({drive})"
        except Exception:
            return "所需磁盘空间: 约 120 MB"

    def _on_browse(self):
        chosen = filedialog.askdirectory(initialdir=self.install_dir_var.get(), title="选择萌宠安装目录")
        if chosen:
            self.install_dir_var.set(os.path.normpath(chosen))
            self.space_lbl.config(text=self._get_space_text())

    def _on_window_close(self):
        if self.is_installed and self.launch_var.get() and not getattr(self, "_already_launched", False):
            target_dir = self.install_dir_var.get().strip()
            target_exe = os.path.join(target_dir, "DesktopPet.exe")
            launch_installed_app(target_exe, target_dir)
            self._already_launched = True
        self.destroy()

    def _on_action_click(self):
        if self.is_installed:
            if self.launch_var.get() and not getattr(self, "_already_launched", False):
                target_dir = self.install_dir_var.get().strip()
                target_exe = os.path.join(target_dir, "DesktopPet.exe")
                launch_installed_app(target_exe, target_dir)
                self._already_launched = True
            self.destroy()
            return

        self.btn_action.set_state("disabled", "⏳ 正在极速解压安装中...")
        self.entry_dir.config(state="disabled")
        self.btn_browse.config(state="disabled")
        for opt in (self.opt1, self.opt2, self.opt3, self.opt4):
            opt.set_enabled(False)

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
                launch_after=False,
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
                self.progress_bar.set_progress(pct)
                self.pct_lbl.config(text=f"{pct}%")
        self.after(0, _update)

    def _update_progress(self, val):
        def _update():
            self.progress_bar.set_progress(val)
            self.pct_lbl.config(text=f"{val}%")
        self.after(0, _update)

    def _on_install_success(self):
        self.is_installed = True
        self.progress_bar.set_progress(100)
        self.pct_lbl.config(text="100%", fg="#059669")
        self.status_lbl.config(text="🎉 安装成功！波可已来到您的桌面，开始陪伴您~", fg="#059669")
        self.btn_action.set_state("success", "🎉 安装完成！进入萌宠世界 ✨")

    def _on_install_error(self, err_msg):
        self.progress_bar.set_progress(0)
        self.pct_lbl.config(text="0%", fg="#DC2626")
        self.status_lbl.config(text=f"❌ 安装发生错误: {err_msg}", fg="#DC2626")
        self.btn_action.set_state("normal", "重试安装")
        self.entry_dir.config(state="normal")
        self.btn_browse.config(state="normal")
        for opt in (self.opt1, self.opt2, self.opt3, self.opt4):
            opt.set_enabled(True)
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
