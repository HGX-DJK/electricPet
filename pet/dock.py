import sys
from PyQt6.QtCore import Qt, QTimer, QPropertyAnimation, QEasingCurve, QRectF
from PyQt6.QtWidgets import (
    QWidget, QHBoxLayout, QPushButton, QLabel, QFrame,
    QGraphicsDropShadowEffect, QApplication
)
from PyQt6.QtGui import QFont, QColor, QCursor
from pet.audio import sound_manager
from pet.menus import FeedingDialog, WardrobeDialog, ActionShowDialog, PlayDialog, QuickActionMenu, FocusDialog

DOCK_PASTELS = {
    "feed": {
        "bg": "rgba(30, 41, 59, 0.8)", "border": "#F59E0B", "hover_bg": "rgba(245, 158, 11, 0.2)", "hover_border": "#FBBF24", "pressed": "rgba(180, 83, 9, 0.4)"
    },
    "wardrobe": {
        "bg": "rgba(30, 41, 59, 0.8)", "border": "#A855F7", "hover_bg": "rgba(168, 85, 247, 0.2)", "hover_border": "#C084FC", "pressed": "rgba(126, 34, 206, 0.4)"
    },
    "talent": {
        "bg": "rgba(30, 41, 59, 0.8)", "border": "#FB7185", "hover_bg": "rgba(251, 113, 133, 0.2)", "hover_border": "#FDA4AF", "pressed": "rgba(190, 18, 60, 0.4)"
    },
    "play": {
        "bg": "rgba(30, 41, 59, 0.8)", "border": "#38BDF8", "hover_bg": "rgba(56, 189, 248, 0.2)", "hover_border": "#7DD3FC", "pressed": "rgba(2, 132, 199, 0.4)"
    },
    "bath": {
        "bg": "rgba(30, 41, 59, 0.8)", "border": "#34D399", "hover_bg": "rgba(52, 211, 153, 0.2)", "hover_border": "#6EE7B7", "pressed": "rgba(5, 150, 105, 0.4)"
    },
    "sleep": {
        "bg": "rgba(30, 41, 59, 0.8)", "border": "#818CF8", "hover_bg": "rgba(129, 140, 248, 0.2)", "hover_border": "#A5B4FC", "pressed": "rgba(67, 56, 202, 0.4)"
    },
    "wake": {
        "bg": "rgba(30, 41, 59, 0.8)", "border": "#FACC15", "hover_bg": "rgba(250, 204, 21, 0.2)", "hover_border": "#FDE047", "pressed": "rgba(161, 98, 7, 0.4)"
    },
    "memo": {
        "bg": "rgba(30, 41, 59, 0.8)", "border": "#0EA5E9", "hover_bg": "rgba(14, 165, 233, 0.2)", "hover_border": "#38BDF8", "pressed": "rgba(3, 105, 161, 0.4)"
    },
    "focus": {
        "bg": "rgba(30, 41, 59, 0.8)", "border": "#EF4444", "hover_bg": "rgba(239, 68, 68, 0.2)", "hover_border": "#F87171", "pressed": "rgba(185, 28, 28, 0.4)"
    },
    "focus_active": {
        "bg": "rgba(14, 165, 233, 0.25)", "border": "#38BDF8", "hover_bg": "rgba(56, 189, 248, 0.35)", "hover_border": "#7DD3FC", "pressed": "rgba(2, 132, 199, 0.4)"
    },
    "more": {
        "bg": "rgba(30, 41, 59, 0.8)", "border": "#64748B", "hover_bg": "rgba(100, 116, 139, 0.2)", "hover_border": "#94A3B8", "pressed": "rgba(51, 65, 85, 0.4)"
    }
}

class DockIconButton(QPushButton):
    """灵动伴侣岛快捷图标按钮"""
    def __init__(self, icon_str, tooltip_text, callback, style_key="more", parent=None):
        super().__init__(icon_str, parent)
        self.setFixedSize(36, 36)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setToolTip(tooltip_text)
        self.setFont(QFont("Segoe UI Emoji", 15))
        self.update_style(style_key)

        def _on_clicked():
            sound_manager.play("click")
            callback()
        self.clicked.connect(_on_clicked)

    def update_style(self, style_key):
        pal = DOCK_PASTELS.get(style_key, DOCK_PASTELS["more"])
        self.setStyleSheet(f"""
            QPushButton {{
                background-color: {pal["bg"]};
                border: 1.5px solid {pal["border"]};
                border-radius: 18px;
                padding: 0px;
                color: #F8FAFC;
            }}
            QPushButton:hover {{
                background-color: {pal["hover_bg"]};
                border: 2px solid {pal["hover_border"]};
            }}
            QPushButton:pressed {{
                background-color: {pal["pressed"]};
                padding-top: 2px;
            }}
        """)

class PetCompanionDock(QWidget):
    """
    桌面萌宠灵动悬浮伴侣岛 (快捷交互栏)
    鼠标靠近/移入宠物或单击宠物时自动平滑浮现，无需右键即可一键执行：
    投喂、衣橱、才艺、玩耍、洗澡、哄睡、设置
    """
    def __init__(self, model, pet_window, parent=None):
        super().__init__(parent, Qt.WindowType.FramelessWindowHint | Qt.WindowType.Tool | Qt.WindowType.WindowStaysOnTopHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.model = model
        self.pet_window = pet_window
        self.is_dock_visible = False

        self.hide_timer = QTimer(self)
        self.hide_timer.setSingleShot(True)
        self.hide_timer.timeout.connect(self._do_fade_out)

        self._current_anim = None
        self._init_ui()

    def _init_ui(self):
        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(10, 10, 10, 10)

        # 赛博深空全息微透胶囊底座 (带天青霓虹微光反射)
        self.capsule = QFrame(self)
        self.capsule.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 rgba(11, 15, 25, 0.95), stop:1 rgba(17, 24, 39, 0.95));
                border: 1.5px solid #0EA5E9;
                border-top: 1.5px solid #38BDF8;
                border-radius: 24px;
            }
        """)

        # 赛博天青全息多阶环境阴影
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(28)
        shadow.setColor(QColor(14, 165, 233, 70))
        shadow.setOffset(0, 4)
        self.capsule.setGraphicsEffect(shadow)

        dock_layout = QHBoxLayout(self.capsule)
        dock_layout.setContentsMargins(8, 5, 8, 5)
        dock_layout.setSpacing(6)

        # 1. 投喂美食
        self.btn_feed = DockIconButton("🍼", "🍼 投喂美食 (蛋糕/烤鱼/牛排长身体)", self._on_feed, "feed", self)
        dock_layout.addWidget(self.btn_feed)

        # 2. 萌宠衣橱
        self.btn_wardrobe = DockIconButton("👗", "👗 萌宠衣橱 (11款皮肤与饰品换装)", self._on_wardrobe, "wardrobe", self)
        dock_layout.addWidget(self.btn_wardrobe)

        # 3. 动作才艺
        self.btn_talent = DockIconButton("🎭", "🎭 动作才艺秀 (点播8大绝活特技)", self._on_talent, "talent", self)
        dock_layout.addWidget(self.btn_talent)

        # 4. 互动玩耍
        self.btn_play = DockIconButton("🎮", "🎮 趣味互动 (猜拳/掷骰子/逗宠棒)", self._on_play, "play", self)
        dock_layout.addWidget(self.btn_play)

        # 5. 香香沐浴
        self.btn_bath = DockIconButton("🛁", "🛁 香香沐浴 (洗个泡泡浴清爽洁净)", self._on_bath, "bath", self)
        dock_layout.addWidget(self.btn_bath)

        # 6. 哄睡就寝
        sleep_icon = "☀️" if self.model.is_sleeping else "💤"
        sleep_style = "wake" if self.model.is_sleeping else "sleep"
        self.btn_sleep = DockIconButton(sleep_icon, "💤 就寝休养 / 唤醒", self._on_sleep, sleep_style, self)
        dock_layout.addWidget(self.btn_sleep)

        # 7. 桌面随手便签
        self.btn_memo = DockIconButton("📝", "📝 桌面便签 (随时记录待办与灵感闪念)", self._on_memo, "memo", self)
        dock_layout.addWidget(self.btn_memo)

        # 8. 深度专注力场 (番茄钟)
        self.btn_focus = DockIconButton("🍅", "🍅 赛博深度专注时钟 (心流守护)", self._on_focus, "focus", self)
        dock_layout.addWidget(self.btn_focus)

        # 竖向细微分割线
        sep = QFrame()
        sep.setFrameShape(QFrame.Shape.VLine)
        sep.setStyleSheet("background-color: #334155; min-width: 1px; max-width: 1px; margin: 4px 1px;")
        dock_layout.addWidget(sep)

        # 9. 全部菜单与设置
        self.btn_more = DockIconButton("⚙️", "⚙️ 快捷档案与偏好设置 (点击打开完整面板)", self._on_more, "more", self)
        dock_layout.addWidget(self.btn_more)

        main_layout.addWidget(self.capsule)
        self.adjustSize()

    def show_dock(self):
        """平滑浮现快捷岛"""
        if self._current_anim and self._current_anim.state() == QPropertyAnimation.State.Running:
            self._current_anim.stop()
            self._current_anim = None
        self.hide_timer.stop()
        self.update_sleep_icon()
        self.update_focus_state()
        self.sync_position()

        if not self.isVisible() or self.windowOpacity() < 0.9:
            self.show()
            self.setWindowOpacity(0.0)
            anim = QPropertyAnimation(self, b"windowOpacity", self)
            anim.setDuration(160)
            anim.setStartValue(0.0)
            anim.setEndValue(1.0)
            anim.setEasingCurve(QEasingCurve.Type.OutCubic)
            anim.start()
            self._current_anim = anim
        self.raise_()
        self.is_dock_visible = True
        if hasattr(self.pet_window, "dialogue") and self.pet_window.dialogue.is_visible:
            self.pet_window.dialogue.sync_position()

    def schedule_hide(self, delay_ms=2200):
        """延迟隐藏"""
        self.hide_timer.start(delay_ms)

    def cancel_hide(self):
        self.hide_timer.stop()

    def enterEvent(self, event):
        """鼠标滑入快捷岛：取消隐藏计时，持续保持操作面板展开"""
        self.cancel_hide()
        super().enterEvent(event)

    def leaveEvent(self, event):
        """鼠标滑出快捷岛：平滑延时收起"""
        self.schedule_hide(1600)
        super().leaveEvent(event)

    def keyPressEvent(self, event):
        """支持 Esc 键极速收起伴侣岛"""
        if event.key() == Qt.Key.Key_Escape:
            self._do_fade_out()
            event.accept()
        else:
            super().keyPressEvent(event)

    def _do_fade_out(self):
        if not self.isVisible():
            return
        anim = QPropertyAnimation(self, b"windowOpacity", self)
        anim.setDuration(200)
        anim.setStartValue(self.windowOpacity())
        anim.setEndValue(0.0)
        anim.setEasingCurve(QEasingCurve.Type.InCubic)
        anim.finished.connect(self._on_fade_finished)
        anim.start()
        self._current_anim = anim

    def _on_fade_finished(self):
        self.hide()
        self.is_dock_visible = False
        if hasattr(self.pet_window, "dialogue") and self.pet_window.dialogue.is_visible:
            self.pet_window.dialogue.sync_position()

    def sync_position(self):
        """智能随宠物吸附并防止越过屏幕边缘，紧密贴合头顶"""
        pet_x = self.pet_window.x()
        pet_y = self.pet_window.y()
        pet_w = self.pet_window.width()

        dock_w = self.width()
        dock_h = self.height()

        screen = QApplication.screenAt(self.pet_window.geometry().center())
        if not screen:
            screen = QApplication.primaryScreen()
        avail = screen.availableGeometry()

        # 精确获取宠物头部与足底绝对屏幕坐标，彻底消除跨分辨率/缩放的漂移
        pet_head_y = self.pet_window.get_head_screen_y()
        pet_foot_y = self.pet_window.get_foot_screen_y()
        pet_center_x = self.pet_window.get_center_screen_x()

        # 默认水平居中吸附在宠物正上方
        target_x = pet_center_x - dock_w / 2.0

        # 纵向：让胶囊底部距离宠物头部仅约 6 像素呼吸间距（dock 内部含有 10 像素阴影 margin）
        target_y = pet_head_y - dock_h + 4

        # 边界防溢出保护
        target_x = max(avail.left() + 8, min(target_x, avail.right() - dock_w - 8))
        if target_y < avail.top() + 6:
            # 顶部空间不足，翻转到宠物足底下方，同时防触底防遮挡
            target_y = pet_foot_y + 4
            target_y = min(target_y, avail.bottom() - dock_h - 6)

        self.move(int(target_x), int(target_y))

    def update_sleep_icon(self):
        if self.model.is_sleeping:
            self.btn_sleep.setText("☀️")
            self.btn_sleep.setToolTip("☀️ 唤醒波可")
            self.btn_sleep.update_style("wake")
        else:
            self.btn_sleep.setText("💤")
            self.btn_sleep.setToolTip("💤 哄睡就寝 (休养充沛活力)")
            self.btn_sleep.update_style("sleep")

    def update_focus_state(self):
        if hasattr(self, "btn_focus"):
            if getattr(self.model, "is_studying", False):
                mins = max(0, int(self.model.study_time_left // 60))
                secs = max(0, int(self.model.study_time_left % 60))
                self.btn_focus.setToolTip(f"🍅 专注心流守护中: {mins:02d}:{secs:02d} (点击查看力场/提前结束)")
                self.btn_focus.update_style("focus_active")
            else:
                self.btn_focus.setToolTip("🍅 赛博深度专注时钟 (开启静默心流守护)")
                self.btn_focus.update_style("focus")

    # ================= 按钮交互逻辑 =================
    def _on_feed(self):
        self.hide()
        QTimer.singleShot(30, lambda: FeedingDialog(self.model, self.pet_window).exec())

    def _on_wardrobe(self):
        self.hide()
        QTimer.singleShot(30, lambda: WardrobeDialog(self.model, self.pet_window).exec())

    def _on_talent(self):
        self.hide()
        QTimer.singleShot(30, lambda: ActionShowDialog(self.model, self.pet_window).exec())

    def _on_play(self):
        self.hide()
        QTimer.singleShot(30, lambda: PlayDialog(self.model, self.pet_window).exec())

    def _on_bath(self):
        self.model.bath()
        self.pet_window.renderer.trigger_bath()
        self.pet_window.dialogue.say("哇！泡泡浴好舒服呀~ 波可现在香喷喷哒！🧼✨")

    def _on_sleep(self):
        is_sleeping = self.model.toggle_sleep()
        self.update_sleep_icon()
        if is_sleeping:
            self.pet_window.dialogue.say("晚安啦主人，波可去梦里捉小鱼干啦~ 呼呼💤")
        else:
            self.pet_window.dialogue.say("伸个懒腰~ 充满能量啦！今天也要加油哦！☀️")

    def _on_memo(self):
        if hasattr(self.pet_window, "toggle_memo"):
            self.pet_window.toggle_memo()

    def _on_focus(self):
        self.hide()
        QTimer.singleShot(30, lambda: FocusDialog(self.model, self.pet_window).exec())

    def _on_more(self):
        self.hide()
        self.pet_window._open_quick_menu()
