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

    # Qt 6 默认自动启用高 DPI 缩放，无需手动设置环境变量
    setup_crash_logger()
    set_windows_app_id()

    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)  # 保持后台托盘驻留
    app.setApplicationName("DesktopElectricPet")
    app.setApplicationDisplayName("桌面萌宠 · 波可")

    # 单实例保护：检测是否已存在运行中的萌宠进程，避免重复启动与存档冲突
    from PyQt6.QtNetwork import QLocalServer, QLocalSocket
    server_id = "DesktopElectricPet_Instance_Server"
    probe_socket = QLocalSocket()
    probe_socket.connectToServer(server_id)
    if probe_socket.waitForConnected(400):
        probe_socket.write(b"WAKE_UP\n")
        probe_socket.waitForBytesWritten(800)
        probe_socket.disconnectFromServer()
        sys.exit(0)

    # 启动单实例本地服务器
    instance_server = QLocalServer()
    QLocalServer.removeServer(server_id)
    instance_server.listen(server_id)

    # 设置应用全局图标
    app_icon = create_app_icon()
    app.setWindowIcon(app_icon)

    # 初始化核心模型与主窗口
    model = PetModel()
    window = PetWindow(model)
    tray = PetTrayIcon(model, window, app)

    # 处理多开唤醒事件
    def _on_instance_message():
        client = instance_server.nextPendingConnection()
        if client:
            def _handle_read():
                msg = client.readAll().data().decode("utf-8", errors="ignore").strip()
                if "WAKE_UP" in msg:
                    if getattr(window, "is_boss_hidden", False):
                        return  # 老板键隐身中，静默忽略唤醒请求
                    if not window.isVisible():
                        window.show()
                    window.setWindowState(window.windowState() & ~Qt.WindowState.WindowMinimized | Qt.WindowState.WindowActive)
                    window.raise_()
                    window.activateWindow()
                    window.play_action("HAPPY_SPIN", custom_msg="主人，波可一直在这里陪着您呢！✨")
            client.readyRead.connect(_handle_read)
            if client.bytesAvailable() > 0:
                _handle_read()
    instance_server.newConnection.connect(_on_instance_message)

    # 退出前保存状态并释放单实例资源
    def _cleanup():
        try:
            window.unregister_boss_hotkey()
        except Exception:
            pass
        model.save_to_disk()
        instance_server.close()
        QLocalServer.removeServer(server_id)
    app.aboutToQuit.connect(_cleanup)

    # 显示窗口与托盘，并激活 Windows 全局老板键
    window.show()
    window.raise_()
    window.activateWindow()
    window.register_boss_hotkey()
    tray.show()

    # 升级提示回调绑定
    def on_level_up(new_lvl):
        window.dialogue.say(f"🎉 升级啦！波可升到了 Lv.{new_lvl}！和主人的感情更深厚了呢~ (✧ω✧)", duration=6.0)
    model.on_level_up = on_level_up

    # 番茄钟专注完成回调绑定 (系统托盘原生通知 + 萌宠撒花祝贺)
    def on_focus_finish():
        if getattr(window, "is_boss_hidden", False):
            tray.show_notification("⏰ 番茄钟专注完成！", "高效专注圆满达成！站起来伸伸懒腰、向远方眺望放松一下吧~ 🐾")
            return  # 老板键隐身中，只发送系统通知，不弹出窗口
        if not window.isVisible():
            window.show()
        window.raise_()
        window.dialogue.say("🎉 专注时间达成！主人辛苦啦，波可给您递上温水，快休息5分钟吧~ ✨", duration=8.0)
        tray.show_notification("⏰ 番茄钟专注完成！", "高效专注圆满达成！站起来伸伸懒腰、向远方眺望放松一下吧~ 🐾")
        window.play_action("HAPPY_SPIN")
    model.on_focus_finish = on_focus_finish

    sys.exit(app.exec())

if __name__ == "__main__":
    main()
