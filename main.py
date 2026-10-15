import sys
import os
import ctypes
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QIcon

from pet.model import PetModel
from pet.window import PetWindow
from pet.tray import PetTrayIcon, create_app_icon

def set_windows_app_id():
    """设置 Windows 任务栏应用组唯一 AppUserModelID"""
    try:
        app_id = "ElectricPet.Poko.Desktop.1.0"
        ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(app_id)
    except Exception:
        pass

def setup_crash_logger():
    """未捕获异常崩溃日志记录"""
    import traceback
    import time
    def handle_exception(exc_type, exc_value, exc_traceback):
        if issubclass(exc_type, KeyboardInterrupt):
            sys.__excepthook__(exc_type, exc_value, exc_traceback)
            return
        log_dir = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), "ElectricPet")
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, "crash.log")
        try:
            with open(log_file, "a", encoding="utf-8") as f:
                f.write(f"\n--- Crash at {time.ctime()} ---\n")
                traceback.print_exception(exc_type, exc_value, exc_traceback, file=f)
        except Exception:
            pass
    sys.excepthook = handle_exception

def main():
    # 确保运行工作目录始终对齐程序所在目录，防外部唤起相对路径丢失
    if getattr(sys, "frozen", False):
        base_dir = os.path.dirname(sys.executable)
    else:
        base_dir = os.path.dirname(os.path.abspath(__file__))
    try:
        os.chdir(base_dir)
    except Exception:
        pass

    # 启用高分屏清晰缩放与反锯齿
    os.environ["QT_AUTO_SCREEN_SCALE_FACTOR"] = "1"
    setup_crash_logger()
    set_windows_app_id()

    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)  # 保持后台托盘驻留
    app.setApplicationName("DesktopElectricPet")
    app.setApplicationDisplayName("桌面萌宠 · 波可")

    # 设置应用全局图标
    app_icon = create_app_icon()
    app.setWindowIcon(app_icon)

    # 初始化核心模型与主窗口
    model = PetModel()
    window = PetWindow(model)
    tray = PetTrayIcon(model, window, app)

    # 退出前保存状态
    app.aboutToQuit.connect(model.save_to_disk)

    # 显示窗口与托盘
    window.show()
    tray.show()

    # 升级提示回调绑定
    def on_level_up(new_lvl):
        window.dialogue.say(f"🎉 升级啦！波可升到了 Lv.{new_lvl}！和主人的感情更深厚了呢~ (✧ω✧)", duration=6.0)
    model.on_level_up = on_level_up

    sys.exit(app.exec())

if __name__ == "__main__":
    main()
