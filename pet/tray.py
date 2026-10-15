import os
import sys
from PyQt6.QtWidgets import QSystemTrayIcon, QMenu
from PyQt6.QtGui import QIcon, QPixmap, QPainter, QColor, QPen, QBrush
from PyQt6.QtCore import Qt, QRectF, QPointF
from pet.menus import StatusDialog, SettingsDialog, WardrobeDialog, FeedingDialog, ActionShowDialog
from pet.audio import sound_manager

def create_app_icon():
    """获取或动态生成高清晰度可爱的桌面萌宠托盘图标"""
    # 优先使用 assets 目录下生成的高清图标
    candidates = [
        getattr(sys, "_MEIPASS", ""),
        os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    ]
    for base in candidates:
        if base:
            ico_path = os.path.join(base, "assets", "app.ico")
            if os.path.exists(ico_path):
                return QIcon(ico_path)
            png_path = os.path.join(base, "assets", "app.png")
            if os.path.exists(png_path):
                return QIcon(png_path)

    # 矢量绘制备选图标
    pixmap = QPixmap(64, 64)
    pixmap.fill(Qt.GlobalColor.transparent)
    painter = QPainter(pixmap)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)

    # 萌萌橙色圆形背景
    painter.setBrush(QBrush(QColor("#FFAA66")))
    painter.setPen(QPen(QColor("#E07A30"), 2))
    painter.drawEllipse(QRectF(4, 4, 56, 56))

    # 白色小猫脸/柴犬脸轮廓
    painter.setBrush(QBrush(QColor("#FFF9F2")))
    painter.setPen(Qt.PenStyle.NoPen)
    painter.drawEllipse(QRectF(12, 16, 40, 38))

    # 两个小耳朵
    painter.setBrush(QBrush(QColor("#FFAA66")))
    painter.setPen(QPen(QColor("#E07A30"), 1.5))
    painter.drawPolygon([QPointF(16, 22), QPointF(24, 10), QPointF(30, 22)])
    painter.drawPolygon([QPointF(48, 22), QPointF(40, 10), QPointF(34, 22)])

    # 眼睛和鼻子
    painter.setBrush(QBrush(QColor("#3D2923")))
    painter.drawEllipse(QRectF(22, 28, 5, 7))
    painter.drawEllipse(QRectF(37, 28, 5, 7))
    painter.setBrush(QBrush(QColor("#FFA5A5")))
    painter.drawEllipse(QRectF(30, 36, 4, 3))

    painter.end()
    return QIcon(pixmap)


class PetTrayIcon(QSystemTrayIcon):
    """Windows 任务栏托盘图标控制器"""
    def __init__(self, model, pet_window, app):
        super().__init__(create_app_icon(), pet_window)
        self.model = model
        self.pet_window = pet_window
        self.app = app

        self.setToolTip(f"{self.model.name} · 桌面萌宠")
        self._init_menu()
        self.activated.connect(self._on_tray_activated)

    def _init_menu(self):
        menu = QMenu()
        menu.setStyleSheet("""
            QMenu {
                background-color: #FFFFFF;
                border: 1px solid #E2E4E8;
                border-radius: 8px;
                padding: 6px;
                font-family: "Microsoft YaHei UI";
                font-size: 13px;
            }
            QMenu::item {
                padding: 6px 24px;
                border-radius: 4px;
            }
            QMenu::item:selected {
                background-color: #EEF2FF;
                color: #4F46E5;
            }
            QMenu::separator {
                height: 1px;
                background: #E5E7EB;
                margin: 4px 8px;
            }
        """)

        # 状态概览标题
        self.status_action = menu.addAction(f"🐾 {self.model.name} (Lv.{self.model.level})")
        self.status_action.setEnabled(False)
        menu.addSeparator()

        # 显示 / 隐藏切换
        self.toggle_show_action = menu.addAction("👁️ 隐藏萌宠")
        self.toggle_show_action.triggered.connect(self._toggle_visibility)

        # 重置位置 (防止用户误把窗口拖出屏幕)
        reset_pos_action = menu.addAction("🎯 重置萌宠屏幕位置")
        reset_pos_action.triggered.connect(self._reset_position)

        # 置顶切换
        self.ontop_action = menu.addAction("📌 保持窗口置顶")
        self.ontop_action.setCheckable(True)
        self.ontop_action.setChecked(self.model.always_on_top)
        self.ontop_action.triggered.connect(self._toggle_ontop)

        # 音效切换
        self.sound_action = menu.addAction("🔊 萌宠音效")
        self.sound_action.setCheckable(True)
        self.sound_action.setChecked(self.model.sound_enabled)
        self.sound_action.triggered.connect(self._toggle_sound)

        menu.addSeparator()

        # 打开萌宠衣橱
        wardrobe_action = menu.addAction("👗 萌宠衣橱 & 换装")
        wardrobe_action.triggered.connect(self._open_wardrobe)

        # 打开喂食成长
        feed_action = menu.addAction("🍼 喂食成长中心")
        feed_action.triggered.connect(self._open_feed)

        # 打开动作才艺大赏
        talent_action = menu.addAction("🎭 萌宠动作才艺大赏")
        talent_action.triggered.connect(self._open_talents)

        # 打开状态面板
        stats_action = menu.addAction("📊 宠物状态档案")
        stats_action.triggered.connect(self._open_stats)

        # 偏好设置
        settings_action = menu.addAction("⚙️ 偏好设置")
        settings_action.triggered.connect(self._open_settings)

        menu.addSeparator()

        # 退出应用
        exit_action = menu.addAction("🚪 退出电子宠物")
        exit_action.triggered.connect(self._exit_app)

        self.setContextMenu(menu)

    def _toggle_visibility(self):
        if self.pet_window.isVisible():
            self.pet_window.hide()
            self.toggle_show_action.setText("👁️ 显示萌宠")
        else:
            self.pet_window.show()
            self.toggle_show_action.setText("👁️ 隐藏萌宠")

    def _reset_position(self):
        self.pet_window._init_initial_position()
        self.pet_window.show()
        self.pet_window.dialogue.say("波可回到默认位置啦！(ฅ'ω'ฅ)")

    def _toggle_ontop(self):
        self.model.always_on_top = self.ontop_action.isChecked()
        self.pet_window.apply_model_settings()
        self.model.save_to_disk()

    def _toggle_sound(self):
        self.model.sound_enabled = self.sound_action.isChecked()
        sound_manager.muted = not self.model.sound_enabled
        self.model.save_to_disk()

    def _open_wardrobe(self):
        dialog = WardrobeDialog(self.model, self.pet_window)
        dialog.exec()

    def _open_feed(self):
        dialog = FeedingDialog(self.model, self.pet_window)
        dialog.exec()

    def _open_talents(self):
        dialog = ActionShowDialog(self.model, self.pet_window)
        dialog.exec()

    def _open_stats(self):
        dialog = StatusDialog(self.model)
        dialog.exec()

    def _open_settings(self):
        dialog = SettingsDialog(self.model, self.pet_window)
        dialog.exec()

    def _on_tray_activated(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            if not self.pet_window.isVisible():
                self._toggle_visibility()
            else:
                self.pet_window.raise_()
                self.pet_window.activateWindow()
                self.pet_window.play_action("TILT_HEAD", custom_msg="主人在找波可吗？喵呜~ 🐾")
        elif reason == QSystemTrayIcon.ActivationReason.DoubleClick:
            self._toggle_visibility()

    def show_notification(self, title, message, duration_ms=4500):
        """调用 Windows 原生通知中心/气泡吐司提醒"""
        try:
            self.showMessage(title, message, QSystemTrayIcon.MessageIcon.Information, duration_ms)
        except Exception:
            pass

    def _exit_app(self):
        self.model.save_to_disk()
        self.app.quit()
