import sys
import copy
import random
import winreg
from PyQt6.QtCore import Qt, QTimer, QPropertyAnimation, QEasingCurve, QRectF, QEvent
from PyQt6.QtWidgets import (
    QWidget, QDialog, QVBoxLayout, QHBoxLayout, QLabel,
    QPushButton, QProgressBar, QSlider, QCheckBox, QComboBox,
    QFrame, QGridLayout, QTabWidget, QScrollArea, QGraphicsDropShadowEffect
)
from PyQt6.QtGui import QFont, QIcon, QColor, QPainter, QCursor, QBrush, QPen
from pet.audio import sound_manager
from pet.renderer import PetRenderer

# 现代毛玻璃与卡片样式表
MODERN_STYLE = """
QDialog {
    background-color: #FAFAFD;
    border-radius: 20px;
}
QLabel {
    font-family: "Microsoft YaHei UI", sans-serif;
    color: #1F2937;
}
QPushButton {
    font-family: "Microsoft YaHei UI", sans-serif;
    background-color: #FFFFFF;
    border: 1px solid #E2E8F0;
    border-radius: 12px;
    padding: 8px 16px;
    font-size: 13px;
    color: #334155;
    font-weight: 500;
}
QPushButton:hover {
    background-color: #F8FAFC;
    border-color: #818CF8;
    color: #4338CA;
}
QPushButton:pressed {
    background-color: #EEF2FF;
}
QPushButton#PrimaryBtn {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #6366F1, stop:1 #4F46E5);
    color: #FFFFFF;
    border: none;
    font-weight: 600;
    border-radius: 12px;
}
QPushButton#PrimaryBtn:hover {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #4F46E5, stop:1 #4338CA);
}
QPushButton#SelectedBtn {
    background-color: #EEF2FF;
    border: 2px solid #6366F1;
    color: #4338CA;
    font-weight: 600;
}
QProgressBar {
    border: none;
    background-color: #F1F5F9;
    border-radius: 6px;
    height: 12px;
    text-align: center;
    font-size: 9px;
    color: #475569;
    font-weight: bold;
}
QProgressBar::chunk {
    border-radius: 6px;
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #6366F1, stop:1 #818CF8);
}
QTabWidget::pane {
    border: 1px solid #E2E8F0;
    border-radius: 16px;
    background-color: #FFFFFF;
    top: -1px;
}
QTabBar::tab {
    background: #F1F5F9;
    border: 1px solid #E2E8F0;
    padding: 8px 18px;
    margin-right: 6px;
    border-top-left-radius: 10px;
    border-top-right-radius: 10px;
    font-family: "Microsoft YaHei UI";
    font-size: 12px;
    color: #64748B;
}
QTabBar::tab:selected {
    background: #FFFFFF;
    border-bottom-color: #FFFFFF;
    color: #4F46E5;
    font-weight: bold;
}
QSlider::groove:horizontal {
    height: 6px;
    background: #E2E8F0;
    border-radius: 3px;
}
QSlider::sub-page:horizontal {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #6366F1, stop:1 #818CF8);
    border-radius: 3px;
}
QSlider::handle:horizontal {
    background: #FFFFFF;
    border: 2px solid #6366F1;
    width: 18px;
    margin-top: -6px;
    margin-bottom: -6px;
    border-radius: 9px;
}
QCheckBox {
    font-family: "Microsoft YaHei UI", sans-serif;
    font-size: 13px;
    color: #334155;
    spacing: 8px;
}
QCheckBox::indicator {
    width: 18px;
    height: 18px;
    border-radius: 5px;
    border: 1.5px solid #CBD5E1;
    background-color: #FFFFFF;
}
QCheckBox::indicator:hover {
    border-color: #818CF8;
}
QCheckBox::indicator:checked {
    background-color: #6366F1;
    border-color: #6366F1;
}
"""

PASTEL_PALETTE = {
    "🍼": ("#FEF3C7", "#FDE68A"),
    "🍰": ("#FCE7F3", "#FBCFE8"),
    "🐟": ("#E0F2FE", "#BAE6FD"),
    "🥩": ("#FEE2E2", "#FECACA"),
    "🌟": ("#FEF9C3", "#FEF08A"),
    "🧋": ("#FFEDD5", "#FED7AA"),
    "👗": ("#EEF2FF", "#E0E7FF"),
    "🎭": ("#F3E8FF", "#E9D5FF"),
    "🎮": ("#FFE4E6", "#FECDD3"),
    "🛁": ("#CFFAFE", "#A5F3FC"),
    "☀️": ("#FEF9C3", "#FEF08A"),
    "💤": ("#DBEAFE", "#BFDBFE"),
    "🍅": ("#FEE2E2", "#FECACA"),
    "📊": ("#D1FAE5", "#A7F3D0"),
    "⚙️": ("#F1F5F9", "#E2E8F0"),
    "🎲": ("#FEF3C7", "#FDE68A"),
    "🪄": ("#F5F3FF", "#DDD6FE"),
    "🐱": ("#FEF3C7", "#FDE68A"),
    "🐾": ("#EEF2FF", "#E0E7FF"),
    "🦋": ("#E0F2FE", "#BAE6FD"),
    "🎧": ("#F3E8FF", "#E9D5FF"),
    "❓": ("#FEF9C3", "#FEF08A"),
    "💃": ("#FCE7F3", "#FBCFE8"),
    "🥱": ("#DBEAFE", "#BFDBFE"),
    "💫": ("#FEF9C3", "#FEF08A"),
    "👀": ("#E0F2FE", "#BAE6FD"),
    "🐭": ("#F1F5F9", "#CBD5E1"),
    "🧶": ("#FFE4E6", "#FDA4AF"),
}

class ActionCardButton(QPushButton):
    """具有现代毛玻璃流光质感的交互卡片按钮"""
    def __init__(self, icon_str, title, subtitle="", bg_color=None, border_color=None, parent=None):
        super().__init__(parent)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFixedHeight(54)

        if not bg_color or not border_color:
            bg_c, brd_c = PASTEL_PALETTE.get(icon_str, ("#F8FAFC", "#E2E8F0"))
            bg_color = bg_color or bg_c
            border_color = border_color or brd_c

        self.setStyleSheet("""
            QPushButton {
                background-color: #FFFFFF;
                border: 1px solid #F1F5F9;
                border-radius: 14px;
                padding: 0px;
                text-align: left;
            }
            QPushButton:hover {
                background-color: #F8FAFC;
                border: 1.5px solid #818CF8;
            }
            QPushButton:pressed {
                background-color: #EEF2FF;
            }
        """)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(10, 6, 10, 6)
        layout.setSpacing(10)

        # 柔和底色图标徽章容器
        icon_box = QFrame()
        icon_box.setFixedSize(36, 36)
        icon_box.setStyleSheet(f"""
            QFrame {{
                background-color: {bg_color};
                border: 1px solid {border_color};
                border-radius: 11px;
            }}
        """)
        icon_box_layout = QVBoxLayout(icon_box)
        icon_box_layout.setContentsMargins(0, 0, 0, 0)
        icon_lbl = QLabel(icon_str)
        icon_lbl.setFont(QFont("Segoe UI Emoji", 16))
        icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        icon_lbl.setStyleSheet("background: transparent; border: none;")
        icon_box_layout.addWidget(icon_lbl)
        layout.addWidget(icon_box)

        # 标题与副标题纵向排列
        text_layout = QVBoxLayout()
        text_layout.setContentsMargins(0, 0, 0, 0)
        text_layout.setSpacing(2)
        text_layout.setAlignment(Qt.AlignmentFlag.AlignVCenter)

        title_lbl = QLabel(title)
        title_lbl.setFont(QFont("Microsoft YaHei UI", 11, QFont.Weight.Bold))
        title_lbl.setStyleSheet("color: #1E293B; background: transparent; border: none;")
        text_layout.addWidget(title_lbl)

        if subtitle:
            sub_lbl = QLabel(subtitle)
            sub_lbl.setFont(QFont("Microsoft YaHei UI", 9))
            sub_lbl.setStyleSheet("color: #64748B; background: transparent; border: none;")
            text_layout.addWidget(sub_lbl)

        layout.addLayout(text_layout)
        layout.addStretch()

class QuickActionMenu(QWidget):
    """
    全新升级的灵动岛 / 毛玻璃悬浮快捷控制中心 (macOS / Fluent 风格)
    拥有 Bento 风格高清晰度状态卡片网格、柔和高光投影、动态自适应布局与全面防遮挡置顶
    """
    def __init__(self, model, pet_window, parent=None):
        super().__init__(parent, Qt.WindowType.FramelessWindowHint | Qt.WindowType.Tool | Qt.WindowType.WindowStaysOnTopHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.model = model
        self.pet_window = pet_window
        self.setFixedWidth(384)

        # 主卡片背景容器
        outer_layout = QVBoxLayout(self)
        outer_layout.setContentsMargins(14, 14, 14, 14)

        card = QFrame()
        card.setObjectName("MainCard")
        card.setStyleSheet("""
            QFrame#MainCard {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 rgba(255, 255, 255, 0.98), stop:1 rgba(248, 250, 252, 0.96));
                border: 1px solid rgba(226, 232, 240, 0.95);
                border-radius: 22px;
            }
        """)

        # 柔和多阶环境阴影
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(36)
        shadow.setColor(QColor(15, 23, 42, 50))
        shadow.setOffset(0, 10)
        card.setGraphicsEffect(shadow)

        layout = QVBoxLayout(card)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(12)

        # 1. 顶部角色档案与微型状态卡片
        profile_box = QHBoxLayout()
        profile_box.setSpacing(12)

        avatar_frame = QFrame()
        avatar_frame.setFixedSize(50, 50)
        avatar_frame.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #EEF2FF, stop:1 #E0E7FF);
                border-radius: 25px;
                border: 2px solid #818CF8;
            }
        """)
        av_layout = QVBoxLayout(avatar_frame)
        av_layout.setContentsMargins(0, 0, 0, 0)
        avatar = QLabel("🐱" if model.pet_type == "cat" else ("🐶" if model.pet_type == "dog" else ("🫧" if model.pet_type == "slime" else "🐧")))
        avatar.setFont(QFont("Segoe UI Emoji", 26))
        avatar.setAlignment(Qt.AlignmentFlag.AlignCenter)
        avatar.setStyleSheet("background: transparent; border: none;")
        av_layout.addWidget(avatar)
        profile_box.addWidget(avatar_frame)

        name_box = QVBoxLayout()
        name_box.setSpacing(3)
        top_name = QHBoxLayout()
        name_lbl = QLabel(model.name)
        name_lbl.setFont(QFont("Microsoft YaHei UI", 13, QFont.Weight.Bold))
        name_lbl.setStyleSheet("color: #0F172A; background: transparent; border: none;")

        stage_pill = QLabel(f"✨ {model.stage_info['name']}")
        stage_pill.setFont(QFont("Microsoft YaHei UI", 9, QFont.Weight.Bold))
        stage_pill.setStyleSheet("""
            background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #EEF2FF, stop:1 #E0E7FF);
            color: #4338CA;
            padding: 2px 9px;
            border-radius: 9px;
            border: 1px solid rgba(99, 102, 241, 0.25);
        """)
        top_name.addWidget(name_lbl)
        top_name.addWidget(stage_pill)

        mode_text = "🧲 贴地重力" if model.enable_gravity else "📌 任意悬停"
        self.btn_mode_pill = QPushButton(mode_text)
        self.btn_mode_pill.setFont(QFont("Microsoft YaHei UI", 9, QFont.Weight.Bold))
        self.btn_mode_pill.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_mode_pill.setToolTip("点击切换定位模式：\n【任意悬停】可立在屏幕中间或顶部任意位置不掉落\n【贴地重力】受桌面物理重力自动落回底部任务栏")
        self.btn_mode_pill.setStyleSheet("""
            QPushButton {
                background: #F8FAFC;
                color: #475569;
                padding: 2px 8px;
                border-radius: 9px;
                border: 1px solid #CBD5E1;
            }
            QPushButton:hover {
                background: #EEF2FF;
                color: #4F46E5;
                border-color: #818CF8;
            }
        """)
        self.btn_mode_pill.clicked.connect(self._toggle_gravity_mode)
        top_name.addWidget(self.btn_mode_pill)
        top_name.addStretch()
        name_box.addLayout(top_name)

        sub_info = QLabel(f"Lv.{model.level} · 体重 {model.weight}kg · 陪伴第 {model.total_days} 天")
        sub_info.setStyleSheet("color: #64748B; font-size: 11px; background: transparent; border: none;")
        name_box.addWidget(sub_info)
        profile_box.addLayout(name_box)

        # 关闭按钮
        btn_close = QPushButton("✕")
        btn_close.setFixedSize(26, 26)
        btn_close.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_close.setStyleSheet("""
            QPushButton {
                background: #F1F5F9;
                border: none;
                border-radius: 13px;
                color: #94A3B8;
                font-size: 11px;
                font-weight: bold;
                padding: 0px;
            }
            QPushButton:hover {
                background: #FEE2E2;
                color: #EF4444;
            }
        """)
        btn_close.clicked.connect(self.close)
        profile_box.addWidget(btn_close, alignment=Qt.AlignmentFlag.AlignTop)
        layout.addLayout(profile_box)

        # 2. Bento 状态卡片网格 (2 列 x 2 行，解决截断与模糊问题)
        status_grid = QGridLayout()
        status_grid.setSpacing(8)
        status_grid.addWidget(self._create_status_bento_item(
            "🍗", "饱食度", int(model.hunger), "#D97706",
            "qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #F59E0B, stop:1 #D97706)"
        ), 0, 0)
        status_grid.addWidget(self._create_status_bento_item(
            "💖", "心情值", int(model.mood), "#E11D48",
            "qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #FB7185, stop:1 #E11D48)"
        ), 0, 1)
        status_grid.addWidget(self._create_status_bento_item(
            "⚡", "精力值", int(model.energy), "#2563EB",
            "qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #60A5FA, stop:1 #2563EB)"
        ), 1, 0)
        status_grid.addWidget(self._create_status_bento_item(
            "🫧", "清洁度", int(model.cleanliness), "#0891B2",
            "qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #22D3EE, stop:1 #0891B2)"
        ), 1, 1)
        layout.addLayout(status_grid)

        # 分割线
        line = QFrame()
        line.setFrameShape(QFrame.Shape.HLine)
        line.setStyleSheet("border: none; background-color: #F1F5F9; max-height: 1px;")
        layout.addWidget(line)

        # 3. 核心功能卡片网格 (2 列 x 4 行)
        grid = QGridLayout()
        grid.setSpacing(8)

        btn_feed = ActionCardButton("🍼", "喂食成长", "投喂长身体")
        btn_feed.clicked.connect(self._on_feed)
        grid.addWidget(btn_feed, 0, 0)

        btn_wardrobe = ActionCardButton("👗", "萌宠衣橱", "11款换装")
        btn_wardrobe.clicked.connect(self._on_wardrobe)
        grid.addWidget(btn_wardrobe, 0, 1)

        btn_talent = ActionCardButton("🎭", "动作才艺", "8大特技秀")
        btn_talent.clicked.connect(self._on_talents)
        grid.addWidget(btn_talent, 1, 0)

        btn_play = ActionCardButton("🎮", "互动玩耍", "猜拳掷骰子")
        btn_play.clicked.connect(self._on_play)
        grid.addWidget(btn_play, 1, 1)

        btn_bath = ActionCardButton("🛁", "香香沐浴", "泡泡浴焕新")
        btn_bath.clicked.connect(self._on_bath)
        grid.addWidget(btn_bath, 2, 0)

        sleep_icon = "☀️" if model.is_sleeping else "💤"
        sleep_title = "唤醒波可" if model.is_sleeping else "哄睡就寝"
        btn_sleep = ActionCardButton(sleep_icon, sleep_title, "恢复活力")
        btn_sleep.clicked.connect(self._on_sleep)
        grid.addWidget(btn_sleep, 2, 1)

        focus_title = "停止专注" if model.is_studying else "番茄专注"
        btn_focus = ActionCardButton("🍅", focus_title, "伴学番茄钟")
        btn_focus.clicked.connect(self._on_focus)
        grid.addWidget(btn_focus, 3, 0)

        btn_stats = ActionCardButton("📊", "状态档案", "成长与属性")
        btn_stats.clicked.connect(self._on_stats)
        grid.addWidget(btn_stats, 3, 1)

        layout.addLayout(grid)

        # 4. 底部系统偏好设置条 (整条通栏，类似 iOS / macOS 设置入口)
        btn_settings = QPushButton()
        btn_settings.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_settings.setFixedHeight(46)
        btn_settings.setStyleSheet("""
            QPushButton {
                background-color: #F8FAFC;
                border: 1px solid #E2E8F0;
                border-radius: 14px;
                padding: 0px 12px;
            }
            QPushButton:hover {
                background-color: #EEF2FF;
                border: 1.5px solid #818CF8;
            }
            QPushButton:pressed {
                background-color: #E0E7FF;
            }
        """)
        s_layout = QHBoxLayout(btn_settings)
        s_layout.setContentsMargins(10, 0, 12, 0)
        s_layout.setSpacing(10)

        s_icon_box = QFrame()
        s_icon_box.setFixedSize(30, 30)
        s_icon_box.setStyleSheet("background-color: #EEF2FF; border-radius: 8px;")
        s_ib_layout = QVBoxLayout(s_icon_box)
        s_ib_layout.setContentsMargins(0, 0, 0, 0)
        s_icon = QLabel("⚙️")
        s_icon.setFont(QFont("Segoe UI Emoji", 14))
        s_icon.setAlignment(Qt.AlignmentFlag.AlignCenter)
        s_icon.setStyleSheet("background: transparent; border: none;")
        s_ib_layout.addWidget(s_icon)
        s_layout.addWidget(s_icon_box)

        s_title_box = QVBoxLayout()
        s_title_box.setContentsMargins(0, 0, 0, 0)
        s_title_box.setSpacing(1)
        s_title = QLabel("偏好设置")
        s_title.setFont(QFont("Microsoft YaHei UI", 11, QFont.Weight.Bold))
        s_title.setStyleSheet("color: #1E293B; background: transparent; border: none;")
        s_title_box.addWidget(s_title)

        s_sub = QLabel("缩放调节 · 保持置顶 · 开机自启 · 音效")
        s_sub.setFont(QFont("Microsoft YaHei UI", 9))
        s_sub.setStyleSheet("color: #64748B; background: transparent; border: none;")
        s_title_box.addWidget(s_sub)
        s_layout.addLayout(s_title_box)

        s_layout.addStretch()

        s_arrow = QLabel("›")
        s_arrow.setFont(QFont("Microsoft YaHei UI", 16, QFont.Weight.Bold))
        s_arrow.setStyleSheet("color: #94A3B8; background: transparent; border: none;")
        s_layout.addWidget(s_arrow)

        btn_settings.clicked.connect(self._on_settings)
        layout.addWidget(btn_settings)

        outer_layout.addWidget(card)

    def changeEvent(self, event):
        """点击窗口外部失去焦点时自动平滑关闭"""
        if event.type() == QEvent.Type.ActivationChange and not self.isActiveWindow():
            self.close()
        super().changeEvent(event)

    def _create_status_bento_item(self, icon, label, val_int, color_hex, track_gradient):
        card = QFrame()
        card.setFixedHeight(46)
        card.setStyleSheet("""
            QFrame {
                background-color: #F8FAFC;
                border: 1px solid #F1F5F9;
                border-radius: 12px;
            }
        """)
        layout = QVBoxLayout(card)
        layout.setContentsMargins(10, 6, 10, 6)
        layout.setSpacing(4)

        top_h = QHBoxLayout()
        top_h.setContentsMargins(0, 0, 0, 0)

        lbl = QLabel(f"{icon} {label}")
        lbl.setFont(QFont("Microsoft YaHei UI", 9, QFont.Weight.Bold))
        lbl.setStyleSheet("color: #475569; background: transparent; border: none;")
        top_h.addWidget(lbl)
        top_h.addStretch()

        val_lbl = QLabel(f"{val_int}%")
        val_lbl.setFont(QFont("Microsoft YaHei UI", 9, QFont.Weight.Bold))
        val_lbl.setStyleSheet(f"color: {color_hex}; background: transparent; border: none;")
        top_h.addWidget(val_lbl)
        layout.addLayout(top_h)

        bar = QProgressBar()
        bar.setMaximum(100)
        bar.setValue(min(100, max(0, val_int)))
        bar.setFixedHeight(5)
        bar.setTextVisible(False)
        bar.setStyleSheet(f"""
            QProgressBar {{
                background-color: #E2E8F0;
                border: none;
                border-radius: 2px;
            }}
            QProgressBar::chunk {{
                background: {track_gradient};
                border-radius: 2px;
            }}
        """)
        layout.addWidget(bar)
        return card

    def _on_feed(self):
        sound_manager.play("click")
        self.close()
        QTimer.singleShot(30, lambda: FeedingDialog(self.model, self.pet_window).exec())

    def _on_wardrobe(self):
        sound_manager.play("click")
        self.close()
        QTimer.singleShot(30, lambda: WardrobeDialog(self.model, self.pet_window).exec())

    def _on_talents(self):
        sound_manager.play("click")
        self.close()
        QTimer.singleShot(30, lambda: ActionShowDialog(self.model, self.pet_window).exec())

    def _on_play(self):
        sound_manager.play("click")
        self.close()
        QTimer.singleShot(30, lambda: PlayDialog(self.model, self.pet_window).exec())

    def _on_bath(self):
        sound_manager.play("click")
        self.close()
        self.model.bath()
        self.pet_window.renderer.trigger_bath()
        self.pet_window.dialogue.say("哇！泡泡浴好舒服呀~ 波可现在香喷喷哒！🧼✨")

    def _on_sleep(self):
        sound_manager.play("click")
        self.close()
        is_sleeping = self.model.toggle_sleep()
        if hasattr(self.pet_window, "dock"):
            self.pet_window.dock.update_sleep_icon()
        if is_sleeping:
            self.pet_window.dialogue.say("晚安啦主人，波可去梦里捉小鱼干啦~ 呼呼💤")
        else:
            self.pet_window.dialogue.say("伸个懒腰~ 充满能量啦！今天也要加油哦！☀️")

    def _on_focus(self):
        sound_manager.play("click")
        self.close()
        if self.model.is_studying:
            self.model.cancel_focus_timer()
            self.pet_window.dialogue.say("专注模式已结束。休息一下吧！")
        else:
            QTimer.singleShot(30, lambda: FocusDialog(self.model, self.pet_window).exec())

    def _on_stats(self):
        sound_manager.play("click")
        self.close()
        QTimer.singleShot(30, lambda: StatusDialog(self.model).exec())

    def _on_settings(self):
        sound_manager.play("click")
        self.close()
        QTimer.singleShot(30, lambda: SettingsDialog(self.model, self.pet_window).exec())

    def _toggle_gravity_mode(self):
        sound_manager.play("pop")
        new_state = self.model.toggle_gravity()
        if new_state:
            self.btn_mode_pill.setText("🧲 贴地重力")
            self.pet_window.dialogue.say("已开启【贴地重力模式】！我会受重力降落到底部任务栏哦~ 🧲")
        else:
            self.btn_mode_pill.setText("📌 任意悬停")
            self.pet_window.dialogue.say("已开启【任意悬停模式】！现在把我拖到屏幕中间或顶部，就能稳稳立在那里啦~ ✨")
        self.pet_window.apply_model_settings()

class PetLivePreviewWidget(QWidget):
    """衣橱中的实时交互试穿预览画布"""
    def __init__(self, model, parent=None):
        super().__init__(parent)
        self.setFixedSize(170, 190)
        self.preview_model = copy.copy(model)
        # 复制独立装饰字典
        self.preview_model.decorations = dict(model.decorations)
        self.renderer = PetRenderer(self.preview_model)

        # 30 FPS 试穿预览动画
        self.timer = QTimer(self)
        self.timer.timeout.connect(self._on_tick)
        self.timer.start(33)

    def update_skin(self, skin_id):
        self.preview_model.set_skin(skin_id)
        self.update()

    def update_decoration(self, slot, code):
        self.preview_model.set_decoration(slot, code)
        self.update()

    def _on_tick(self):
        self.renderer.update_animation(0.033, "IDLE")
        self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        try:
            painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)

            # 浅色圆角展示台背景
            painter.setBrush(QBrush(QColor("#F8FAFC")))
            painter.setPen(QPen(QColor("#E2E8F0"), 1.5))
            painter.drawRoundedRect(QRectF(4, 4, self.width() - 8, self.height() - 8), 16, 16)

            # 绘制预览萌宠本体
            self.renderer.render(painter, self.width(), self.height(), "IDLE", False)
        finally:
            painter.end()

class WardrobeDialog(QDialog):
    """
    全新设计的萌宠衣橱 & 试穿更衣室
    左侧拥有专属实时试穿动态画布，右侧多标签自由切换 11 款皮肤与 4 大装扮插槽
    """
    def __init__(self, model, pet_window, parent=None):
        super().__init__(parent)
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, True)
        self.setWindowTitle("✨ 萌宠衣橱 & 换装试衣间")
        self.setFixedSize(620, 500)
        self.setStyleSheet(MODERN_STYLE)
        self.model = model
        self.pet_window = pet_window

        # 暂存当前试穿配置
        self.temp_skin = model.skin_id
        self.temp_decs = dict(model.decorations)

        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(18, 18, 18, 18)
        main_layout.setSpacing(16)

        # ================= 左侧：实时预览与操作栏 =================
        left_box = QVBoxLayout()
        left_box.setSpacing(10)

        preview_title = QLabel("👗 实时试衣间")
        preview_title.setFont(QFont("Microsoft YaHei UI", 12, QFont.Weight.Bold))
        left_box.addWidget(preview_title)

        self.preview_widget = PetLivePreviewWidget(model, self)
        left_box.addWidget(self.preview_widget)

        tip_lbl = QLabel("点击右侧皮肤或饰品\n左侧即可实时预览效果")
        tip_lbl.setStyleSheet("color: #64748B; font-size: 11px; text-align: center;")
        tip_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        left_box.addWidget(tip_lbl)

        left_box.addStretch()

        btn_clear = QPushButton("🚫 卸下全部配饰")
        btn_clear.clicked.connect(self._clear_all_decorations)
        left_box.addWidget(btn_clear)

        btn_save = QPushButton("✨ 保存并穿戴", self)
        btn_save.setObjectName("PrimaryBtn")
        btn_save.setFixedHeight(40)
        btn_save.clicked.connect(self._apply_and_close)
        left_box.addWidget(btn_save)

        main_layout.addLayout(left_box)

        # ================= 右侧：各部件装扮选项卡 =================
        right_box = QVBoxLayout()
        tabs = QTabWidget()

        # Tab 1: 皮肤
        tabs.addTab(self._create_skin_tab(), "🐾 角色皮肤")
        # Tab 2: 头部装扮
        tabs.addTab(self._create_slot_tab("head", [
            ("none", "🚫 无头饰", "保持自然头顶"),
            ("hat_wizard", "🧙 魔法巫师尖帽", "神秘紫罗兰尖顶帽"),
            ("hat_party", "🥳 派对生日帽", "欢快粉色彩条毛绒球"),
            ("halo", "😇 金色天使光环", "头顶悬浮圣洁光晕"),
            ("horns", "😈 俏皮小恶魔角", "火红可爱小尖角"),
            ("crown", "👑 黄金华贵王冠", "璀璨红宝石帝王冠"),
            ("chef", "👨‍🍳 洁白厨师高帽", "米其林软萌主厨帽")
        ]), "🎩 头部")
        # Tab 3: 面部配饰
        tabs.addTab(self._create_slot_tab("face", [
            ("none", "🚫 无面饰", "清爽大眼睛"),
            ("glasses", "👓 金丝博士眼镜", "斯文博学圆框镜"),
            ("sunglasses", "🕶️ 酷炫黑超墨镜", "街头潮牌霸气出街"),
            ("blush_hearts", "💖 心动爱心面贴", "双颊粉红心动爱心")
        ]), "👓 面部")
        # Tab 4: 领口脖饰
        tabs.addTab(self._create_slot_tab("neck", [
            ("none", "🚫 无领饰", "自然脖颈"),
            ("bow", "🎀 优雅红蝴蝶结", "甜美艳红大蝴蝶结"),
            ("scarf", "🧣 温暖英伦围巾", "防寒保暖冬日毛线围巾"),
            ("bell", "🔔 招财金小挂铃", "招财进宝叮咚小响铃"),
            ("tie", "👔 绅士西装小领结", "优雅正式商务西装领结")
        ]), "🧣 领饰")
        # Tab 5: 背部特效
        tabs.addTab(self._create_slot_tab("back", [
            ("none", "🚫 无背饰", "轻装上阵"),
            ("wings", "🪽 天使微颤羽翼", "呼吸时轻轻扇动的羽翼"),
            ("balloon", "🎈 浮动心形气球", "身后飘逸的粉红爱心气球")
        ]), "🪽 背部")

        right_box.addWidget(tabs)
        main_layout.addLayout(right_box, stretch=1)

    def _create_skin_tab(self):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("border: none;")
        container = QWidget()
        layout = QVBoxLayout(container)
        layout.setSpacing(6)

        skins = [
            ("cat_calico", "🐱 萌萌三花猫", "经典奶油色加橙黑花斑，粉肉垫"),
            ("cat_orange", "🐱 温暖大头橘猫", "金橘温暖虎斑毛色，圆润治愈"),
            ("cat_black", "🐱 暗夜黑曜猫", "玄黑优雅皮毛与明亮金黄大眼"),
            ("cat_white", "🐱 纯白雪球猫", "纯白底色与梦幻异色双瞳 (左冰蓝、右翠绿)"),
            ("dog_shiba", "🐶 阳光赤柴", "元气金橙赤柴，经典白眉点"),
            ("dog_black", "🐶 帅气黑柴", "俊俏黑柴，系着帅气蓝色领巾"),
            ("dog_corgi", "🐶 软萌柯基", "暖金白领胸毛与呆萌大耳朵"),
            ("slime_blue", "🫧 海蓝果冻史莱姆", "清透海蓝通透渐变与星芒天线"),
            ("slime_pink", "🌸 草莓甜心史莱姆", "粉嫩果冻身躯与爱心天线"),
            ("slime_gold", "🌟 欧皇黄金史莱姆", "金光闪闪尊贵身躯，吸金转运"),
            ("penguin_tux", "🐧 燕尾服小企鹅", "呆萌企鹅幼崽，摇晃小脚丫")
        ]

        for skin_id, name, desc in skins:
            btn = QPushButton(f"{name}\n{desc}")
            btn.setStyleSheet("text-align: left; padding: 8px 12px; font-size: 12px;")
            if self.temp_skin == skin_id:
                btn.setObjectName("SelectedBtn")
            btn.clicked.connect(lambda checked, s=skin_id: self._select_preview_skin(s))
            layout.addWidget(btn)

        scroll.setWidget(container)
        return scroll

    def _create_slot_tab(self, slot_name, items):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("border: none;")
        container = QWidget()
        layout = QVBoxLayout(container)
        layout.setSpacing(6)

        current_val = self.temp_decs.get(slot_name, "none")
        for code, label, desc in items:
            btn = QPushButton(f"{label}  ·  {desc}")
            btn.setStyleSheet("text-align: left; padding: 10px 14px; font-size: 12px;")
            if current_val == code:
                btn.setObjectName("SelectedBtn")
            btn.clicked.connect(lambda checked, s=slot_name, c=code: self._select_preview_decoration(s, c))
            layout.addWidget(btn)

        scroll.setWidget(container)
        return scroll

    def _select_preview_skin(self, skin_id):
        self.temp_skin = skin_id
        self.preview_widget.update_skin(skin_id)
        sound_manager.play("pop")

    def _select_preview_decoration(self, slot, code):
        self.temp_decs[slot] = code
        self.preview_widget.update_decoration(slot, code)
        sound_manager.play("pop")

    def _clear_all_decorations(self):
        for slot in self.temp_decs:
            self.temp_decs[slot] = "none"
            self.preview_widget.update_decoration(slot, "none")
        sound_manager.play("click")

    def closeEvent(self, event):
        if hasattr(self, "preview_widget") and hasattr(self.preview_widget, "timer"):
            self.preview_widget.timer.stop()
        super().closeEvent(event)

    def _apply_and_close(self):
        if hasattr(self, "preview_widget") and hasattr(self.preview_widget, "timer"):
            self.preview_widget.timer.stop()
        self.model.set_skin(self.temp_skin)
        for slot, code in self.temp_decs.items():
            self.model.set_decoration(slot, code)
        self.model.save_to_disk()
        self.pet_window.dialogue.say("新装扮已换上！主人觉得波可爱吗？✨ (ฅ'ω'ฅ)")
        self.accept()

class FeedingDialog(QDialog):
    """美食投喂与成长进阶中心"""
    def __init__(self, model, pet_window, parent=None):
        super().__init__(parent)
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, True)
        self.setWindowTitle("投喂美食 · 培育成长")
        self.setFixedSize(410, 520)
        self.setStyleSheet(MODERN_STYLE)
        self.model = model
        self.pet_window = pet_window

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(14)

        # 当前阶段与体重展示卡片
        info_card = QFrame()
        info_card.setStyleSheet("background-color: #F8FAFC; border-radius: 16px; border: 1px solid #E2E8F0; padding: 12px;")
        info_layout = QVBoxLayout(info_card)
        info_layout.setSpacing(8)

        header_h = QHBoxLayout()
        stage_info = self.model.stage_info
        self.stage_lbl = QLabel(f"🌟 当前阶梯: {stage_info['name']}")
        self.stage_lbl.setFont(QFont("Microsoft YaHei UI", 12, QFont.Weight.Bold))
        self.stage_lbl.setStyleSheet("color: #4F46E5;")
        self.weight_lbl = QLabel(f"⚖️ 体重: {self.model.weight} kg")
        self.weight_lbl.setFont(QFont("Microsoft YaHei UI", 11, QFont.Weight.Bold))
        self.weight_lbl.setStyleSheet("color: #059669;")
        header_h.addWidget(self.stage_lbl)
        header_h.addStretch()
        header_h.addWidget(self.weight_lbl)
        info_layout.addLayout(header_h)

        growth_h = QHBoxLayout()
        growth_h.addWidget(QLabel("🌱 成长蜕变积累:"))
        self.growth_val_lbl = QLabel(f"{int(self.model.growth)} / {stage_info['next_target']}")
        self.growth_val_lbl.setStyleSheet("color: #64748B; font-size: 11px; font-weight: bold;")
        growth_h.addWidget(self.growth_val_lbl, alignment=Qt.AlignmentFlag.AlignRight)
        info_layout.addLayout(growth_h)

        self.growth_bar = QProgressBar()
        self.growth_bar.setMaximum(stage_info["next_target"])
        self.growth_bar.setValue(int(self.model.growth))
        self.growth_bar.setStyleSheet("QProgressBar::chunk { background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #10B981, stop:1 #059669); }")
        info_layout.addWidget(self.growth_bar)

        desc_lbl = QLabel(stage_info["desc"])
        desc_lbl.setStyleSheet("color: #64748B; font-size: 11px;")
        desc_lbl.setWordWrap(True)
        info_layout.addWidget(desc_lbl)
        layout.addWidget(info_card)

        # 营养美食列表
        title = QLabel("选择给萌宠投喂的营养美食：")
        title.setFont(QFont("Microsoft YaHei UI", 11, QFont.Weight.Bold))
        layout.addWidget(title)

        foods = [
            ("milk", "🍼", "幼宠温热奶粉", "成长 +12 · 饱食 +20 · 体重 +0.06kg"),
            ("cake", "🍰", "草莓鲜奶蛋糕", "成长 +18 · 饱食 +25 · 心情 +25"),
            ("fish", "🐟", "深海极品烤鱼", "成长 +26 · 饱食 +35 · 体重 +0.12kg"),
            ("steak", "🥩", "极品多汁厚牛排", "成长 +35 · 饱食 +45 · 体重 +0.18kg"),
            ("elixir", "🌟", "神奇仙灵仙果", "成长 +55 · 心情 +35 · 灵力爆发"),
            ("boba", "🧋", "珍珠温奶茶", "成长 +14 · 饱食 +18 · 心情 +22")
        ]

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("border: none; background: transparent;")
        food_container = QWidget()
        food_layout = QVBoxLayout(food_container)
        food_layout.setContentsMargins(0, 0, 0, 0)
        food_layout.setSpacing(6)

        for code, emoji, name, desc in foods:
            btn = ActionCardButton(emoji, name, desc)
            btn.clicked.connect(lambda checked, c=code: self._feed_item(c))
            food_layout.addWidget(btn)

        scroll.setWidget(food_container)
        layout.addWidget(scroll)

    def _feed_item(self, food_code):
        food_name, growth_add = self.model.feed(food_code)
        self.pet_window.renderer.trigger_eat(food_code)
        self.pet_window.check_resize_for_growth()

        stage_info = self.model.stage_info
        self.stage_lbl.setText(f"🌟 当前阶梯: {stage_info['name']}")
        self.weight_lbl.setText(f"⚖️ 体重: {self.model.weight} kg")
        self.growth_val_lbl.setText(f"{int(self.model.growth)} / {stage_info['next_target']}")
        self.growth_bar.setMaximum(stage_info["next_target"])
        self.growth_bar.setValue(int(self.model.growth))

        self.pet_window.dialogue.say(f"啊呜！好香的【{food_name}】！成长值 +{int(growth_add)}，身体又长大啦~ (๑´ڡ`๑)")

class PlayDialog(QDialog):
    """趣味小游戏互动"""
    def __init__(self, model, pet_window, parent=None):
        super().__init__(parent)
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, True)
        self.setWindowTitle("和波可一起玩耍")
        self.setFixedSize(360, 420)
        self.setStyleSheet(MODERN_STYLE)
        self.model = model
        self.pet_window = pet_window

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        title = QLabel("选择好玩的娱乐活动：")
        title.setFont(QFont("Microsoft YaHei UI", 12, QFont.Weight.Bold))
        layout.addWidget(title)

        # 猜拳游戏模块
        rps_group = QFrame()
        rps_group.setStyleSheet("background-color: #F8FAFC; border-radius: 14px; border: 1px solid #E2E8F0; padding: 10px;")
        rps_layout = QVBoxLayout(rps_group)
        rps_lbl = QLabel("✂️ 猜拳大对决 (石头剪刀布)")
        rps_lbl.setFont(QFont("Microsoft YaHei UI", 11, QFont.Weight.Bold))
        rps_layout.addWidget(rps_lbl)

        btn_box = QHBoxLayout()
        for choice, emoji in [("rock", "✊ 石头"), ("scissors", "✌️ 剪刀"), ("paper", "🖐️ 布")]:
            btn = QPushButton(emoji)
            btn.setFixedHeight(38)
            btn.clicked.connect(lambda checked, c=choice: self._play_rps(c))
            btn_box.addWidget(btn)
        rps_layout.addLayout(btn_box)
        layout.addWidget(rps_group)

        # 掷骰子
        btn_dice = ActionCardButton("🎲", "掷骰子比大小", "看看谁的点数更高更有运气")
        btn_dice.clicked.connect(self._play_dice)
        layout.addWidget(btn_dice)

        # 逗宠棒
        btn_wand = ActionCardButton("🪄", "晃动逗宠棒", "欢快扑腾与追逐逗趣")
        btn_wand.clicked.connect(self._play_wand)
        layout.addWidget(btn_wand)

        # 动作才艺大赏入口
        btn_talents = ActionCardButton("🎭", "动作才艺大赏", "点播展示全部 8 项专属动作")
        btn_talents.clicked.connect(self._open_talents)
        layout.addWidget(btn_talents)

    def _open_talents(self):
        sound_manager.play("click")
        self.accept()
        dialog = ActionShowDialog(self.model, self.pet_window)
        dialog.exec()

    def _play_rps(self, user_choice):
        choices = ["rock", "scissors", "paper"]
        names = {"rock": "石头 ✊", "scissors": "剪刀 ✌️", "paper": "布 🖐️"}
        pet_choice = random.choice(choices)

        if user_choice == pet_choice:
            msg = f"波可出了【{names[pet_choice]}】，主人也出了【{names[user_choice]}】！平局，太有默契啦~"
        elif (user_choice == "rock" and pet_choice == "scissors") or \
             (user_choice == "scissors" and pet_choice == "paper") or \
             (user_choice == "paper" and pet_choice == "rock"):
            msg = f"波可出了【{names[pet_choice]}】，主人出了【{names[user_choice]}】！太厉害了，主人获胜！🎉"
        else:
            msg = f"波可出了【{names[pet_choice]}】！嘿嘿，这局是波可赢啦~ 耶！✨"

        self.model.play_minigame("rps")
        self.pet_window.dialogue.say(f"【猜拳】{msg}")
        self.accept()

    def _play_dice(self):
        user_num = random.randint(1, 6)
        pet_num = random.randint(1, 6)
        dice_emojis = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
        msg = f"主人掷出 {dice_emojis[user_num-1]} ({user_num}点)，波可掷出 {dice_emojis[pet_num-1]} ({pet_num}点)！"
        if user_num > pet_num:
            msg += " 主人获胜！"
        elif pet_num > user_num:
            msg += " 波可点数更大，嘿嘿！"
        else:
            msg += " 心有灵犀平局！"
        self.model.play_minigame("dice")
        self.pet_window.dialogue.say(msg)
        self.accept()

    def _play_wand(self):
        self.model.play_minigame("wand")
        self.pet_window.renderer.trigger_pet()
        self.pet_window.dialogue.say("哇！看波可的飞身扑击！捉到逗宠棒啦！(扑腾🐾)")
        self.accept()

class ActionShowDialog(QDialog):
    """
    萌宠动作才艺大赏交互面板
    支持 8 种高精度专属动作随时点播与趣味演练
    """
    def __init__(self, model, pet_window, parent=None):
        super().__init__(parent)
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, True)
        self.setWindowTitle("🎭 波可的才艺秀大赏")
        self.setFixedSize(400, 530)
        self.setStyleSheet(MODERN_STYLE)
        self.model = model
        self.pet_window = pet_window

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        header = QVBoxLayout()
        header.setSpacing(4)
        title = QLabel("🎭 萌宠动作才艺大赏")
        title.setFont(QFont("Microsoft YaHei UI", 13, QFont.Weight.Bold))
        header.addWidget(title)

        desc = QLabel("波可学会了 8 种超丰富的趣味动作！点击任意卡片即可命令波可立即展示独门绝活：")
        desc.setWordWrap(True)
        desc.setStyleSheet("color: #64748B; font-size: 11px;")
        header.addWidget(desc)
        layout.addLayout(header)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setStyleSheet("background: transparent;")

        container = QWidget()
        box = QVBoxLayout(container)
        box.setContentsMargins(0, 0, 4, 0)
        box.setSpacing(8)

        actions = [
            ("CATCH_MOUSE", "🐭", "敏捷扑抓小老鼠", "机械发条小老鼠欢快乱窜，波可敏捷飞扑擒拿"),
            ("PLAY_YARN", "🧶", "欢快拨玩毛线球", "粉嫩毛线球弹跳滚动，左右肉垫欢畅轻拍玩耍"),
            ("STRETCH_YAWN", "🐱", "伸个懒腰打哈欠", "拉伸舒展身子骨，张开萌萌大口打哈欠"),
            ("WASH_FACE", "🐾", "萌爪洗脸理毛", "举起粉嫩小肉垫，规律轻揉脸颊胡须"),
            ("CHASE_BUTTERFLY", "🦋", "欢快抓扑彩蝶", "荧光彩蝶绕身飞舞，波可轻快挥爪扑腾"),
            ("HEAD_BOB_MUSIC", "🎧", "佩戴耳机律动", "佩戴酷潮头戴耳机，随动感音乐节奏摇摆"),
            ("TILT_HEAD", "❓", "歪头好奇卖萌", "大眼睛扑闪扑闪，歪头好奇观察主人的工作"),
            ("HAPPY_SPIN", "💃", "快乐原地大旋转", "原地腾空360度大翻转，迸发灿烂金辉"),
            ("DOZE_OFF", "🥱", "站立打瞌睡点头", "困意悄悄袭来，小脑袋一点一点犯迷糊"),
            ("DIZZY", "💫", "晕头转向小星星", "眼花缭乱，金色螺旋小星星在头顶旋转环绕"),
            ("LOOK_AROUND", "👀", "四处好奇张望", "东瞅瞅西看看，扑闪大眼睛警惕巡视桌面"),
            ("SIT_WAG_TAIL", "🐾", "乖巧蹲坐摇尾", "乖巧在脚边蹲坐，轻快欢畅摇晃蓬松小尾巴")
        ]

        for code, icon, name, desc_text in actions:
            btn = ActionCardButton(icon, name, desc_text)
            btn.clicked.connect(lambda checked, c=code: self._trigger_action(c))
            box.addWidget(btn)

        scroll.setWidget(container)
        layout.addWidget(scroll)

        btn_close = QPushButton("关闭", self)
        btn_close.setObjectName("PrimaryBtn")
        btn_close.setFixedHeight(38)
        btn_close.clicked.connect(self.accept)
        layout.addWidget(btn_close)

    def _trigger_action(self, action_code):
        sound_manager.play("click")
        self.accept()
        self.pet_window.play_action(action_code)

class FocusDialog(QDialog):
    """番茄钟专注陪伴设置"""
    def __init__(self, model, pet_window, parent=None):
        super().__init__(parent)
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, True)
        self.setWindowTitle("开启番茄专注时钟")
        self.setFixedSize(320, 240)
        self.setStyleSheet(MODERN_STYLE)
        self.model = model
        self.pet_window = pet_window

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        title = QLabel("选择专注工作/学习时长：")
        title.setFont(QFont("Microsoft YaHei UI", 12, QFont.Weight.Bold))
        layout.addWidget(title)

        desc = QLabel("在专注期间，波可会佩戴眼镜安静守候在您身边不打扰。倒计时结束后会播放清脆闹铃提醒休息！")
        desc.setWordWrap(True)
        desc.setStyleSheet("color: #64748B; font-size: 12px; line-height: 1.4;")
        layout.addWidget(desc)

        btn_box = QHBoxLayout()
        for mins in [15, 25, 45]:
            btn = QPushButton(f"{mins} 分钟")
            btn.setFixedHeight(38)
            btn.clicked.connect(lambda checked, m=mins: self._start(m))
            btn_box.addWidget(btn)
        layout.addLayout(btn_box)

    def _start(self, minutes):
        self.model.start_focus_timer(minutes)
        self.pet_window.dialogue.say(f"番茄钟开启！接下来的 {minutes} 分钟，波可会认真陪伴主人专注工作哦~ 📖✏️")
        self.accept()

class StatusDialog(QDialog):
    """宠物详细状态属性面板"""
    def __init__(self, model, parent=None):
        super().__init__(parent)
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, True)
        self.setWindowTitle("波可的状态档案")
        self.setFixedSize(380, 500)
        self.setStyleSheet(MODERN_STYLE)
        self.model = model

        layout = QVBoxLayout(self)
        layout.setContentsMargins(22, 22, 22, 22)
        layout.setSpacing(12)

        # 头部等级与称号
        header = QHBoxLayout()
        avatar = QLabel("🐱" if model.pet_type == "cat" else ("🐶" if model.pet_type == "dog" else ("🫧" if model.pet_type == "slime" else "🐧")))
        avatar.setFont(QFont("Segoe UI Emoji", 32))
        avatar.setFixedSize(54, 54)
        avatar.setAlignment(Qt.AlignmentFlag.AlignCenter)
        avatar.setStyleSheet("background-color: #F1F5F9; border-radius: 27px; border: 2px solid #6366F1;")
        header.addWidget(avatar)

        title_info = QVBoxLayout()
        name_lbl = QLabel(f"{model.name}  Lv.{model.level}")
        name_lbl.setFont(QFont("Microsoft YaHei UI", 14, QFont.Weight.Bold))
        stage_info = model.stage_info
        title_lbl = QLabel(f"{stage_info['name']} · 亲密度: {model.intimacy} 点 · 体重: {model.weight}kg")
        title_lbl.setStyleSheet("color: #6366F1; font-weight: 500; font-size: 11px;")
        title_info.addWidget(name_lbl)
        title_info.addWidget(title_lbl)
        header.addLayout(title_info)
        layout.addLayout(header)

        # 成长进度条
        growth_box = QVBoxLayout()
        growth_h = QHBoxLayout()
        growth_h.addWidget(QLabel("🌱 成长蜕变积累"))
        g_val = QLabel(f"{int(model.growth)} / {stage_info['next_target']}")
        g_val.setStyleSheet("color: #888888; font-size: 11px;")
        growth_h.addWidget(g_val, alignment=Qt.AlignmentFlag.AlignRight)
        growth_box.addLayout(growth_h)

        growth_bar = QProgressBar()
        growth_bar.setMaximum(stage_info["next_target"])
        growth_bar.setValue(int(model.growth))
        growth_bar.setStyleSheet("QProgressBar::chunk { background-color: #10B981; }")
        growth_box.addWidget(growth_bar)
        layout.addLayout(growth_box)

        # 经验条
        exp_box = QVBoxLayout()
        exp_header = QHBoxLayout()
        exp_header.addWidget(QLabel("成长经验值"))
        exp_val = QLabel(f"{int(model.exp)} / {model.max_exp}")
        exp_val.setStyleSheet("color: #888888; font-size: 11px;")
        exp_header.addWidget(exp_val, alignment=Qt.AlignmentFlag.AlignRight)
        exp_box.addLayout(exp_header)

        exp_bar = QProgressBar()
        exp_bar.setMaximum(model.max_exp)
        exp_bar.setValue(int(model.exp))
        exp_bar.setStyleSheet("QProgressBar::chunk { background-color: #6366F1; }")
        exp_box.addWidget(exp_bar)
        layout.addLayout(exp_box)

        # 4大属性条
        self._add_stat_bar(layout, "🍗 饱食度", int(model.hunger), "#F59E0B")
        self._add_stat_bar(layout, "💖 心情值", int(model.mood), "#EC4899")
        self._add_stat_bar(layout, "⚡ 精力值", int(model.energy), "#3B82F6")
        self._add_stat_bar(layout, "🫧 清洁度", int(model.cleanliness), "#06B6D4")

        # 底部关闭按钮
        btn_ok = QPushButton("确认", self)
        btn_ok.setObjectName("PrimaryBtn")
        btn_ok.setFixedHeight(38)
        btn_ok.clicked.connect(self.accept)
        layout.addWidget(btn_ok)

    def _add_stat_bar(self, layout, label_text, value, color_hex):
        box = QVBoxLayout()
        box.setSpacing(3)
        h = QHBoxLayout()
        h.addWidget(QLabel(label_text))
        val_lbl = QLabel(f"{value}%")
        val_lbl.setStyleSheet("color: #666666; font-size: 11px;")
        h.addWidget(val_lbl, alignment=Qt.AlignmentFlag.AlignRight)
        box.addLayout(h)

        bar = QProgressBar()
        bar.setMaximum(100)
        bar.setValue(value)
        bar.setStyleSheet(f"QProgressBar::chunk {{ background-color: {color_hex}; }}")
        box.addWidget(bar)
        layout.addLayout(box)

class SettingsDialog(QDialog):
    """系统偏好设置面板"""
    def __init__(self, model, pet_window, parent=None):
        super().__init__(parent)
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, True)
        self.setWindowTitle("桌面萌宠偏好设置")
        self.setFixedSize(380, 475)
        self.setStyleSheet(MODERN_STYLE)
        self.model = model
        self.pet_window = pet_window

        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(13)

        title = QLabel("个性化与系统设置")
        title.setFont(QFont("Microsoft YaHei UI", 13, QFont.Weight.Bold))
        layout.addWidget(title)

        # 大小微调缩放调节
        scale_box = QVBoxLayout()
        scale_box.setSpacing(4)
        scale_title_box = QHBoxLayout()
        scale_title_box.addWidget(QLabel("宠物微调缩放比例:"))
        self.scale_val_lbl = QLabel(f"{int(model.user_scale_offset * 100)}%")
        scale_title_box.addWidget(self.scale_val_lbl, alignment=Qt.AlignmentFlag.AlignRight)
        scale_box.addLayout(scale_title_box)

        self.scale_slider = QSlider(Qt.Orientation.Horizontal)
        self.scale_slider.setRange(75, 135)
        self.scale_slider.setValue(int(model.user_scale_offset * 100))
        self.scale_slider.valueChanged.connect(self._on_scale_change)
        scale_box.addWidget(self.scale_slider)
        layout.addLayout(scale_box)

        # 勾选项
        self.cb_ontop = QCheckBox("保持窗口置顶 (始终浮在桌面最前方)")
        self.cb_ontop.setChecked(model.always_on_top)
        layout.addWidget(self.cb_ontop)

        self.cb_gravity = QCheckBox("启用桌面物理重力 (关闭可自由悬停在屏幕中间或顶部)")
        self.cb_gravity.setChecked(model.enable_gravity)
        layout.addWidget(self.cb_gravity)

        self.cb_sound = QCheckBox("启用萌宠音效 (叫声、咀嚼、呼噜声)")
        self.cb_sound.setChecked(model.sound_enabled)
        layout.addWidget(self.cb_sound)

        self.cb_roam = QCheckBox("允许宠物在屏幕边缘自由漫步走动")
        self.cb_roam.setChecked(model.auto_roam)
        layout.addWidget(self.cb_roam)

        self.cb_health = QCheckBox("开启健康关怀 (定时提醒喝水、护眼、久坐伸展)")
        self.cb_health.setChecked(model.health_reminders)
        layout.addWidget(self.cb_health)

        self.cb_autostart = QCheckBox("Windows 开机自动启动桌面萌宠")
        self.cb_autostart.setChecked(model.auto_start)
        layout.addWidget(self.cb_autostart)

        # 底部保存应用
        btn_box = QHBoxLayout()
        btn_apply = QPushButton("保存设置", self)
        btn_apply.setObjectName("PrimaryBtn")
        btn_apply.setFixedHeight(38)
        btn_apply.clicked.connect(self._apply_settings)
        btn_box.addWidget(btn_apply)
        layout.addLayout(btn_box)

    def _on_scale_change(self, val):
        self.scale_val_lbl.setText(f"{val}%")

    def _apply_settings(self):
        self.model.user_scale_offset = self.scale_slider.value() / 100.0
        self.model.always_on_top = self.cb_ontop.isChecked()
        self.model.enable_gravity = self.cb_gravity.isChecked()
        self.model.sound_enabled = self.cb_sound.isChecked()
        sound_manager.muted = not self.model.sound_enabled
        self.model.auto_roam = self.cb_roam.isChecked()
        self.model.health_reminders = self.cb_health.isChecked()
        
        auto_start = self.cb_autostart.isChecked()
        self._set_windows_autostart(auto_start)
        self.model.auto_start = auto_start

        self.model.save_to_disk()
        self.accept()
        # 弹窗完全关闭后异步应用设置，彻底避免 Windows 句柄重建冲突与卡死
        QTimer.singleShot(40, self.pet_window.apply_model_settings)

    def _set_windows_autostart(self, enable):
        try:
            key = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Run",
                0, winreg.KEY_SET_VALUE
            )
            app_path = f'"{sys.executable}"'
            if enable:
                winreg.SetValueEx(key, "DesktopElectricPet", 0, winreg.REG_SZ, app_path)
            else:
                try:
                    winreg.DeleteValue(key, "DesktopElectricPet")
                except FileNotFoundError:
                    pass
            winreg.CloseKey(key)
        except Exception as e:
            print(f"[Settings] Windows autostart reg error: {e}")
