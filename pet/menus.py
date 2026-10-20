import os
import sys
import copy
import random
import winreg
import math
from PyQt6.QtCore import Qt, QTimer, QPropertyAnimation, QEasingCurve, QRectF, QEvent, QPoint, QPointF
from PyQt6.QtWidgets import (
    QWidget, QDialog, QVBoxLayout, QHBoxLayout, QLabel,
    QPushButton, QProgressBar, QSlider, QCheckBox, QComboBox,
    QFrame, QGridLayout, QTabWidget, QScrollArea, QGraphicsDropShadowEffect,
    QApplication, QStackedWidget
)
from PyQt6.QtGui import QFont, QIcon, QColor, QPainter, QCursor, QBrush, QPen, QLinearGradient, QRadialGradient
from pet.audio import sound_manager
from pet.renderer import PetRenderer

# 赛博高科技全息毛玻璃与霓虹全局 QSS
MODERN_STYLE = """
QDialog {
    background: transparent;
}
QScrollArea {
    background: transparent;
    border: none;
}
/* 赛博极窄霓虹青半透明滚动条 */
QScrollBar:vertical {
    border: none;
    background: rgba(15, 23, 42, 0.6);
    width: 6px;
    margin: 0px 0px 0px 0px;
    border-radius: 3px;
}
QScrollBar::handle:vertical {
    background: #0EA5E9;
    min-height: 24px;
    border-radius: 3px;
}
QScrollBar::handle:vertical:hover {
    background: #38BDF8;
}
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {
    height: 0px;
}
QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {
    background: transparent;
}
QScrollBar:horizontal {
    border: none;
    background: rgba(15, 23, 42, 0.6);
    height: 6px;
    margin: 0px 0px 0px 0px;
    border-radius: 3px;
}
QScrollBar::handle:horizontal {
    background: #0EA5E9;
    min-width: 24px;
    border-radius: 3px;
}
QScrollBar::handle:horizontal:hover {
    background: #38BDF8;
}
QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {
    width: 0px;
}
QScrollBar::add-page:horizontal, QScrollBar::sub-page:horizontal {
    background: transparent;
}
QLabel {
    font-family: "Microsoft YaHei UI", sans-serif;
    color: #F1F5F9;
}
QPushButton {
    font-family: "Microsoft YaHei UI", sans-serif;
    background-color: rgba(30, 41, 59, 0.7);
    border: 1px solid rgba(51, 65, 85, 0.8);
    border-radius: 12px;
    padding: 8px 16px;
    font-size: 13px;
    color: #F1F5F9;
    font-weight: 500;
}
QPushButton:hover {
    background-color: rgba(51, 65, 85, 0.95);
    border-color: #38BDF8;
    color: #FFFFFF;
}
QPushButton:pressed {
    background-color: rgba(14, 165, 233, 0.25);
}
QPushButton#PrimaryBtn {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0284C7, stop:1 #0EA5E9);
    color: #FFFFFF;
    border: 1px solid #38BDF8;
    font-weight: bold;
    border-radius: 12px;
}
QPushButton#PrimaryBtn:hover {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0369A1, stop:1 #38BDF8);
}
QPushButton#PrimaryBtn:pressed {
    background: #075985;
}
QPushButton#SelectedBtn {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 rgba(14, 165, 233, 0.25), stop:1 rgba(15, 23, 42, 0.85));
    border: 1.5px solid #38BDF8;
    color: #FFFFFF;
    font-weight: bold;
}
QProgressBar {
    border: 1px solid #1E293B;
    background-color: rgba(15, 23, 42, 0.8);
    border-radius: 6px;
    height: 12px;
    text-align: center;
    font-size: 9px;
    color: #94A3B8;
    font-weight: bold;
}
QProgressBar::chunk {
    border-radius: 6px;
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #06B6D4, stop:1 #3B82F6);
}
QTabWidget::pane {
    border: 1px solid #1E293B;
    border-radius: 16px;
    background: transparent;
    top: -1px;
}
QTabBar::tab {
    background: rgba(30, 41, 59, 0.6);
    border: 1px solid rgba(51, 65, 85, 0.6);
    padding: 8px 18px;
    margin-right: 6px;
    border-top-left-radius: 10px;
    border-top-right-radius: 10px;
    font-family: "Microsoft YaHei UI";
    font-size: 12px;
    color: #94A3B8;
}
QTabBar::tab:selected {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0284C7, stop:1 #0EA5E9);
    border-bottom: 2px solid #38BDF8;
    color: #FFFFFF;
    font-weight: bold;
}
QTabBar::tab:hover:!selected {
    background: rgba(51, 65, 85, 0.8);
    color: #F1F5F9;
    border: 1px solid #0EA5E9;
}
QSlider::groove:horizontal {
    height: 6px;
    background: #1E293B;
    border-radius: 3px;
}
QSlider::sub-page:horizontal {
    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0284C7, stop:1 #0EA5E9);
    border-radius: 3px;
}
QSlider::handle:horizontal {
    background: #F8FAFC;
    border: 2px solid #0EA5E9;
    width: 18px;
    margin-top: -6px;
    margin-bottom: -6px;
    border-radius: 9px;
}
QCheckBox {
    font-family: "Microsoft YaHei UI", sans-serif;
    font-size: 13px;
    color: #E2E8F0;
    spacing: 8px;
}
QCheckBox::indicator {
    width: 16px;
    height: 16px;
    border: 1.5px solid #475569;
    border-radius: 4px;
    background-color: rgba(30, 41, 59, 0.8);
}
QCheckBox::indicator:hover {
    border-color: #38BDF8;
}
QCheckBox::indicator:checked {
    background-color: #0EA5E9;
    border-color: #38BDF8;
    width: 16px;
    height: 16px;
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
    """具有赛博高科技微光质感的交互卡片按钮"""
    def __init__(self, icon_str, title, subtitle="", bg_color=None, border_color=None, parent=None):
        super().__init__(parent)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setMinimumHeight(54)

        if not bg_color or not border_color:
            bg_c, brd_c = PASTEL_PALETTE.get(icon_str, ("rgba(15, 23, 42, 0.7)", "#0EA5E9"))
            bg_color = bg_color or bg_c
            border_color = border_color or brd_c

        self.setStyleSheet("""
            QPushButton {
                background-color: rgba(30, 41, 59, 0.7);
                border: 1px solid rgba(51, 65, 85, 0.8);
                border-radius: 14px;
                padding: 0px;
                text-align: left;
            }
            QPushButton:hover {
                background-color: rgba(51, 65, 85, 0.95);
                border: 1.5px solid #38BDF8;
            }
            QPushButton:pressed {
                background-color: rgba(14, 165, 233, 0.25);
            }
        """)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(10, 6, 10, 6)
        layout.setSpacing(10)

        # 全息高科技图标徽章容器
        icon_box = QFrame()
        icon_box.setFixedSize(38, 38)
        icon_box.setStyleSheet("""
            QFrame {
                background-color: rgba(15, 23, 42, 0.7);
                border: 1.5px solid #0EA5E9;
                border-radius: 11px;
            }
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
        title_lbl.setStyleSheet("color: #F8FAFC; background: transparent; border: none;")
        text_layout.addWidget(title_lbl)

        if subtitle:
            sub_lbl = QLabel(subtitle)
            sub_lbl.setFont(QFont("Microsoft YaHei UI", 9))
            sub_lbl.setWordWrap(True)
            sub_lbl.setStyleSheet("color: #94A3B8; background: transparent; border: none;")
            text_layout.addWidget(sub_lbl)

        layout.addLayout(text_layout, stretch=1)

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
        self.setFixedWidth(410)

        # 主卡片背景容器
        outer_layout = QVBoxLayout(self)
        outer_layout.setContentsMargins(14, 14, 14, 14)

        card = QFrame()
        card.setObjectName("MainCard")
        card.setStyleSheet("""
            QFrame#MainCard {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #0B0F19, stop:1 #111827);
                border: 1.5px solid #0EA5E9;
                border-radius: 22px;
            }
        """)

        # 赛博天青全息多阶环境阴影
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(36)
        shadow.setColor(QColor(14, 165, 233, 50))
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
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #0369A1, stop:1 #0284C7);
                border-radius: 25px;
                border: 2px solid #38BDF8;
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

        mode_text = "🧲 重力" if model.enable_gravity else "📌 悬停"
        self.btn_mode_pill = QPushButton(mode_text)
        self.btn_mode_pill.setFont(QFont("Microsoft YaHei UI", 8, QFont.Weight.Bold))
        self.btn_mode_pill.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_mode_pill.setToolTip("点击切换定位模式：\n【悬停】自由停靠屏幕任意位置\n【重力】落回底部任务栏")
        self.btn_mode_pill.setStyleSheet("""
            QPushButton {
                background: rgba(30, 41, 59, 0.8);
                color: #94A3B8;
                padding: 1px 7px;
                border-radius: 6px;
                border: 1px solid #334155;
            }
            QPushButton:hover {
                background: rgba(14, 165, 233, 0.2);
                color: #38BDF8;
                border-color: #38BDF8;
            }
        """)
        self.btn_mode_pill.clicked.connect(self._toggle_gravity_mode)

        name_box = QVBoxLayout()
        name_box.setSpacing(4)
        top_name = QHBoxLayout()
        top_name.setSpacing(6)
        name_lbl = QLabel(model.name)
        name_lbl.setFont(QFont("Microsoft YaHei UI", 13, QFont.Weight.Bold))
        name_lbl.setStyleSheet("color: #F8FAFC; background: transparent; border: none;")

        stage_pill = QLabel(f"✨ {model.stage_info['name']}")
        stage_pill.setFont(QFont("Microsoft YaHei UI", 8, QFont.Weight.Bold))
        stage_pill.setStyleSheet("""
            background: rgba(14, 165, 233, 0.15);
            color: #38BDF8;
            padding: 2px 7px;
            border-radius: 8px;
            border: 1px solid #0EA5E9;
        """)
        top_name.addWidget(name_lbl)
        top_name.addWidget(stage_pill)

        pers_pill = QLabel(model.personality_info["name"])
        pers_pill.setFont(QFont("Microsoft YaHei UI", 8, QFont.Weight.Bold))
        pers_pill.setStyleSheet(f"""
            background: rgba(15, 23, 42, 0.8);
            color: {model.personality_info['color']};
            padding: 2px 7px;
            border-radius: 8px;
            border: 1px solid {model.personality_info['color']};
        """)
        top_name.addWidget(pers_pill)
        top_name.addWidget(self.btn_mode_pill)
        top_name.addStretch()
        name_box.addLayout(top_name)

        # 档案信息与系统硬件 HUD
        sub_row = QHBoxLayout()
        sub_row.setSpacing(8)
        sub_info = QLabel(f"Lv.{model.level} · {model.weight}kg · 第{model.total_days}天")
        sub_info.setStyleSheet("color: #94A3B8; font-size: 11px; background: transparent; border: none;")
        sub_row.addWidget(sub_info)

        # 硬件性能 HUD 状态药丸
        try:
            from pet.system_monitor import get_system_stats
            hw_stats = get_system_stats()
            hw_pill = QLabel(f"💻 {hw_stats['cpu']}% | 🧠 {hw_stats['memory']}%")
            hw_pill.setFont(QFont("Consolas", 8, QFont.Weight.Bold))
            hw_pill.setStyleSheet("""
                background: rgba(15, 23, 42, 0.8);
                color: #34D399;
                padding: 1px 6px;
                border-radius: 6px;
                border: 1px solid rgba(52, 211, 153, 0.35);
            """)
            hw_pill.setToolTip(f"开机运行: {hw_stats['uptime']} · 物理内存: {hw_stats['mem_total_gb']}GB")
            sub_row.addWidget(hw_pill)
        except Exception:
            pass

        sub_row.addStretch()
        name_box.addLayout(sub_row)
        profile_box.addLayout(name_box)

        # 关闭按钮
        btn_close = QPushButton("✕")
        btn_close.setFixedSize(26, 26)
        btn_close.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_close.setStyleSheet("""
            QPushButton {
                background: rgba(30, 41, 59, 0.8);
                border: 1px solid #334155;
                border-radius: 13px;
                color: #94A3B8;
                font-size: 11px;
                font-weight: bold;
                padding: 0px;
            }
            QPushButton:hover {
                background: #EF4444;
                color: #FFFFFF;
                border-color: #F87171;
            }
        """)
        btn_close.clicked.connect(self.close)
        profile_box.addWidget(btn_close, alignment=Qt.AlignmentFlag.AlignTop)
        layout.addLayout(profile_box)

        # 2. Bento 状态卡片网格 (2 列 x 2 行，解决截断与模糊问题)
        status_grid = QGridLayout()
        status_grid.setSpacing(8)
        status_grid.addWidget(self._create_status_bento_item(
            "🍗", "饱食度", int(model.hunger), "#F59E0B",
            "qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #F59E0B, stop:1 #D97706)"
        ), 0, 0)
        status_grid.addWidget(self._create_status_bento_item(
            "💖", "心情值", int(model.mood), "#EC4899",
            "qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #FB7185, stop:1 #E11D48)"
        ), 0, 1)
        status_grid.addWidget(self._create_status_bento_item(
            "⚡", "精力值", int(model.energy), "#38BDF8",
            "qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #38BDF8, stop:1 #0284C7)"
        ), 1, 0)
        status_grid.addWidget(self._create_status_bento_item(
            "🫧", "清洁度", int(model.cleanliness), "#34D399",
            "qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #34D399, stop:1 #059669)"
        ), 1, 1)
        layout.addLayout(status_grid)

        # 分割线
        line = QFrame()
        line.setFrameShape(QFrame.Shape.HLine)
        line.setStyleSheet("border: none; background-color: #1E293B; max-height: 1px;")
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

        btn_memo = ActionCardButton("📝", "随手便签", "待办灵感记事")
        btn_memo.clicked.connect(self._on_memo)
        grid.addWidget(btn_memo, 4, 0)

        btn_peek = ActionCardButton("👀", "贴边偷看", "暗中观察模式")
        btn_peek.clicked.connect(self._on_peek)
        grid.addWidget(btn_peek, 4, 1)

        layout.addLayout(grid)

        # 4. 底部系统偏好设置条 (整条通栏，赛博操作卡片)
        btn_settings = QPushButton()
        btn_settings.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_settings.setFixedHeight(46)
        btn_settings.setStyleSheet("""
            QPushButton {
                background-color: rgba(30, 41, 59, 0.6);
                border: 1px solid #334155;
                border-radius: 14px;
                padding: 0px 12px;
            }
            QPushButton:hover {
                background-color: rgba(51, 65, 85, 0.85);
                border: 1.5px solid #38BDF8;
            }
            QPushButton:pressed {
                background-color: rgba(15, 23, 42, 0.95);
            }
        """)
        s_layout = QHBoxLayout(btn_settings)
        s_layout.setContentsMargins(10, 0, 12, 0)
        s_layout.setSpacing(10)

        s_icon_box = QFrame()
        s_icon_box.setFixedSize(30, 30)
        s_icon_box.setStyleSheet("background-color: rgba(14, 165, 233, 0.2); border-radius: 8px; border: 1px solid #0EA5E9;")
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
        s_title.setStyleSheet("color: #F8FAFC; background: transparent; border: none;")
        s_title_box.addWidget(s_title)

        s_sub = QLabel("缩放调节 · 保持置顶 · 开机自启 · 音效")
        s_sub.setFont(QFont("Microsoft YaHei UI", 9))
        s_sub.setStyleSheet("color: #94A3B8; background: transparent; border: none;")
        s_title_box.addWidget(s_sub)
        s_layout.addLayout(s_title_box)

        s_layout.addStretch()

        s_arrow = QLabel("›")
        s_arrow.setFont(QFont("Microsoft YaHei UI", 16, QFont.Weight.Bold))
        s_arrow.setStyleSheet("color: #38BDF8; background: transparent; border: none;")
        s_layout.addWidget(s_arrow)

        btn_settings.clicked.connect(self._on_settings)
        layout.addWidget(btn_settings)

        outer_layout.addWidget(card)

    def keyPressEvent(self, event):
        """支持 Esc 键极速收起控制中心"""
        if event.key() == Qt.Key.Key_Escape:
            self.close()
            event.accept()
        else:
            super().keyPressEvent(event)

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
                background-color: rgba(15, 23, 42, 0.75);
                border: 1px solid #1E293B;
                border-radius: 12px;
            }
            QFrame:hover {
                border: 1px solid #0EA5E9;
            }
        """)
        layout = QVBoxLayout(card)
        layout.setContentsMargins(10, 6, 10, 6)
        layout.setSpacing(4)

        top_h = QHBoxLayout()
        top_h.setContentsMargins(0, 0, 0, 0)

        lbl = QLabel(f"{icon} {label}")
        lbl.setFont(QFont("Microsoft YaHei UI", 9, QFont.Weight.Bold))
        lbl.setStyleSheet("color: #94A3B8; background: transparent; border: none;")
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
                background-color: rgba(30, 41, 59, 0.8);
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
        QTimer.singleShot(30, lambda: FocusDialog(self.model, self.pet_window).exec())

    def _on_stats(self):
        sound_manager.play("click")
        self.close()
        QTimer.singleShot(30, lambda: StatusDialog(self.model).exec())

    def _on_memo(self):
        sound_manager.play("click")
        self.close()
        if hasattr(self.pet_window, "toggle_memo"):
            self.pet_window.toggle_memo()

    def _on_peek(self):
        sound_manager.play("click")
        self.close()
        if hasattr(self.pet_window, "trigger_edge_peek"):
            self.pet_window.trigger_edge_peek()

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

class CyberHoloChamberWidget(QWidget):
    """
    赛博全息试衣舱 (Cyber Holographic Chamber)
    - 具有透视投影地台网格、双层流光粒子全息发射环、HUD 高科技角标与状态读数
    - 具有视线跟随、点击触发欢庆与语音气泡互动
    """
    def __init__(self, model, parent=None):
        super().__init__(parent)
        self.setFixedSize(240, 245)
        self.setMouseTracking(True)
        self.model = model
        self.preview_model = copy.copy(model)
        self.preview_model.decorations = dict(model.decorations)
        self.preview_model.habitat = getattr(model, "habitat", "none")
        self.renderer = PetRenderer(self.preview_model)

        self.ring_angle = 0.0
        self.speech_text = "✨ 试衣舱全息链路已就绪！"
        self.speech_timer = 3.0

        # 30 FPS 刷新
        self.timer = QTimer(self)
        self.timer.timeout.connect(self._on_tick)
        self.timer.start(33)

    def set_speech(self, text, duration=3.0):
        self.speech_text = text
        self.speech_timer = duration
        self.update()

    def update_skin(self, skin_id):
        self.preview_model.set_skin(skin_id)
        self.set_speech(f"🧬 基因重组完成: {skin_id}")
        self.update()

    def update_decoration(self, slot, code):
        self.preview_model.set_decoration(slot, code)
        slot_names = {"head": "头部装配", "face": "面部目镜", "neck": "核心项圈", "back": "背部推进", "hand": "手持道具"}
        s_name = slot_names.get(slot, "装扮")
        if code == "none":
            self.set_speech(f"🚫 已卸下 {s_name}")
        else:
            self.set_speech(f"⚡ {s_name} 模块装载完毕！")
        self.update()

    def update_habitat(self, habitat_id):
        self.preview_model.set_habitat(habitat_id)
        hab_names = {
            "none": "默认无小窝", "neon_matrix": "暗夜霓虹极客房",
            "retro_arcade": "复古像素游戏机房", "summer_beach": "夏日阳光海滩",
            "zen_tatami": "佛系禅意蒲团室"
        }
        self.set_speech(f"🏠 小窝切换为: {hab_names.get(habitat_id, habitat_id)}")
        self.update()

    def _on_tick(self):
        self.ring_angle = (self.ring_angle + 2.5) % 360
        if self.speech_timer > 0:
            self.speech_timer -= 0.033
        self.renderer.update_animation(0.033, "IDLE")
        self.update()

    def mouseMoveEvent(self, event):
        cx = self.width() / 2.0
        cy = 135.0
        dx = (event.position().x() - cx) / cx
        dy = (event.position().y() - cy) / cy
        dist = math.hypot(event.position().x() - cx, event.position().y() - cy)
        self.renderer.set_cursor_gaze(max(-1.0, min(1.0, dx)), max(-1.0, min(1.0, dy)), dist)
        super().mouseMoveEvent(event)

    def mousePressEvent(self, event):
        self.renderer.anim_time = 0.0
        self.renderer.trigger_landing_bounce()
        quotes = [
            "✨ 喵呜！这套赛博装甲超合身~",
            "⚡ 萌力共鸣率 120% 突破！",
            "🐾 主人选的搭配永远最帅！",
            "🚀 推进系统全速运转中！",
            "🌟 能量过载，随时准备出击！"
        ]
        self.set_speech(random.choice(quotes), duration=3.5)
        sound_manager.play("sparkle")
        super().mousePressEvent(event)

    def paintEvent(self, event):
        painter = QPainter(self)
        try:
            painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
            w = self.width()
            h = self.height()

            # 1. 舱体深邃科技渐变背景
            bg_grad = QLinearGradient(0, 0, 0, h)
            bg_grad.setColorAt(0.0, QColor("#090D16"))
            bg_grad.setColorAt(0.7, QColor("#0F172A"))
            bg_grad.setColorAt(1.0, QColor("#0B132B"))
            painter.setBrush(QBrush(bg_grad))
            painter.setPen(QPen(QColor("#1E293B"), 1.5))
            painter.drawRoundedRect(QRectF(3, 3, w - 6, h - 6), 18, 18)

            # 2. 绘制全息透视网格地台 (Perspective Hologram Floor)
            pedestal_y = 178.0
            pedestal_w = 170.0
            pedestal_h = 52.0

            # 地台网格发射线
            grid_pen = QPen(QColor(14, 165, 233, 40), 1)
            painter.setPen(grid_pen)
            for i in range(-4, 5):
                fx = w / 2.0 + i * 22
                painter.drawLine(int(w / 2.0 + i * 10), int(pedestal_y - 12), int(fx), int(pedestal_y + 28))

            # 3. 动态旋转全息投影环 (Holographic Emitter Rings)
            glow_grad = QRadialGradient(w / 2.0, pedestal_y + 4, pedestal_w / 2.0)
            glow_grad.setColorAt(0.0, QColor(6, 182, 212, 70))
            glow_grad.setColorAt(0.6, QColor(14, 165, 233, 25))
            glow_grad.setColorAt(1.0, QColor(14, 165, 233, 0))
            painter.setBrush(QBrush(glow_grad))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(QPointF(w / 2.0, pedestal_y + 4), pedestal_w / 2.0, pedestal_h / 2.0)

            # 外圈全息刻度光环
            ring_pen = QPen(QColor(56, 189, 248, 160), 1.5, Qt.PenStyle.DashLine)
            ring_pen.setDashPattern([6, 6])
            ring_pen.setDashOffset(self.ring_angle / 10.0)
            painter.setPen(ring_pen)
            painter.setBrush(Qt.BrushStyle.NoBrush)
            painter.drawEllipse(QPointF(w / 2.0, pedestal_y + 4), pedestal_w / 2.0 - 4, pedestal_h / 2.0 - 2)

            # 内圈能量核心环
            inner_pen = QPen(QColor(168, 85, 247, 180), 1.2)
            painter.setPen(inner_pen)
            painter.drawEllipse(QPointF(w / 2.0, pedestal_y + 4), pedestal_w / 3.0, pedestal_h / 3.0)

            # 4. 绘制 HUD 高科技角标
            hud_pen = QPen(QColor(56, 189, 248, 160), 1.5)
            painter.setPen(hud_pen)
            # 左上
            painter.drawLine(12, 18, 12, 12)
            painter.drawLine(12, 12, 18, 12)
            # 右上
            painter.drawLine(w - 18, 12, w - 12, 12)
            painter.drawLine(w - 12, 12, w - 12, 18)
            # 左下
            painter.drawLine(12, h - 18, 12, h - 12)
            painter.drawLine(12, h - 12, 18, h - 12)
            # 右下
            painter.drawLine(w - 18, h - 12, w - 12, h - 12)
            painter.drawLine(w - 12, h - 12, w - 12, h - 18)

            # 5. 顶部高科技读数
            painter.setFont(QFont("Consolas", 8, QFont.Weight.Bold))
            painter.setPen(QColor("#06B6D4"))
            painter.drawText(QRectF(16, 10, 110, 16), Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter, "● HOLO-POD v3.2")
            painter.setPen(QColor("#94A3B8"))
            painter.drawText(QRectF(w - 95, 10, 80, 16), Qt.AlignmentFlag.AlignRight | Qt.AlignmentFlag.AlignVCenter, "SYNC 99.8%")

            # 6. 绘制高精度萌宠本体
            painter.save()
            scale = 0.95
            painter.translate((w - 220 * scale) / 2.0, (h - 220 * scale) / 2.0 - 4)
            painter.scale(scale, scale)
            self.renderer.render(painter, 220, 220, "IDLE", False)
            painter.restore()

            # 7. 语音气泡/互动反馈胶囊
            if self.speech_timer > 0 and self.speech_text:
                painter.setFont(QFont("Microsoft YaHei UI", 9, QFont.Weight.Bold))
                fm = painter.fontMetrics()
                text_w = fm.horizontalAdvance(self.speech_text) + 20
                bubble_rect = QRectF((w - text_w) / 2.0, 32, text_w, 24)
                painter.setBrush(QBrush(QColor(15, 23, 42, 220)))
                painter.setPen(QPen(QColor("#38BDF8"), 1))
                painter.drawRoundedRect(bubble_rect, 12, 12)
                painter.setPen(QColor("#E0F2FE"))
                painter.drawText(bubble_rect, Qt.AlignmentFlag.AlignCenter, self.speech_text)
        finally:
            painter.end()

# 保持类名兼容
PetLivePreviewWidget = CyberHoloChamberWidget


class ModernBaseDialog(QDialog):
    """
    全新升级的赛博全息科技无边框模态弹窗基类 (Cyber-Holo HUD)
    - 深邃太空微透渐变外壳与 22px 圆角
    - 赛博极光多阶微光阴影 (Cyan Glow & Deep Shadow)
    - 全息控制中枢 Header：全息晶片徽章、版本药丸、实时跳动的绿色脉冲信号灯、霓虹珊瑚红关闭按钮
    - 支持顶部按住拖拽、全键盘 Esc 极速关闭、活跃屏幕自动居中
    """
    def __init__(self, title="桌面萌宠", subtitle="", icon_emoji="🐾", parent=None, fixed_width=420, fixed_height=520, version_tag=""):
        super().__init__(parent, Qt.WindowType.FramelessWindowHint | Qt.WindowType.WindowStaysOnTopHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setStyleSheet(MODERN_STYLE)
        self.setFixedSize(fixed_width, fixed_height)
        self.is_dragging = False
        self.drag_start = QPoint()

        # 居中在主屏幕或当前关联窗口所在屏幕
        screen = QApplication.primaryScreen()
        if parent:
            screen = QApplication.screenAt(parent.geometry().center()) or screen
        if screen:
            avail = screen.availableGeometry()
            x = avail.center().x() - fixed_width // 2
            y = avail.center().y() - fixed_height // 2
            self.move(int(x), int(y))

        # 外层阴影容器 (预留 12px 边缘供柔和外发光阴影完整渲染)
        outer_layout = QVBoxLayout(self)
        outer_layout.setContentsMargins(12, 12, 12, 12)

        self.main_card = QFrame()
        self.main_card.setObjectName("ModernDialogCard")
        self.main_card.setStyleSheet("""
            QFrame#ModernDialogCard {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #0B0F19, stop:1 #111827);
                border: 1.5px solid #1E293B;
                border-radius: 20px;
            }
        """)

        # 赛博多阶深邃阴影
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(28)
        shadow.setColor(QColor(0, 0, 0, 160))
        shadow.setOffset(0, 6)
        self.main_card.setGraphicsEffect(shadow)

        self.card_layout = QVBoxLayout(self.main_card)
        self.card_layout.setContentsMargins(18, 14, 18, 16)
        self.card_layout.setSpacing(10)

        # 1. 顶部 Header 标题栏 (支持拖拽移动)
        self.header_bar = QWidget()
        self.header_bar.setObjectName("DialogHeaderBar")
        header_layout = QHBoxLayout(self.header_bar)
        header_layout.setContentsMargins(0, 0, 0, 0)
        header_layout.setSpacing(10)
        header_layout.setAlignment(Qt.AlignmentFlag.AlignVCenter)

        # 左侧全息晶片徽章
        self.header_icon_frame = QFrame()
        self.header_icon_frame.setFixedSize(38, 38)
        self.header_icon_frame.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:1, stop:0 #0369A1, stop:1 #0284C7);
                border: 1.5px solid #38BDF8;
                border-radius: 12px;
            }
        """)
        icon_layout = QVBoxLayout(self.header_icon_frame)
        icon_layout.setContentsMargins(0, 0, 0, 0)
        icon_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.header_icon_lbl = QLabel(icon_emoji)
        self.header_icon_lbl.setFont(QFont("Segoe UI Emoji", 17))
        self.header_icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.header_icon_lbl.setStyleSheet("background: transparent; border: none;")
        icon_layout.addWidget(self.header_icon_lbl)
        header_layout.addWidget(self.header_icon_frame)

        # 标题与副标题
        title_box = QVBoxLayout()
        title_box.setSpacing(1)
        title_box.setAlignment(Qt.AlignmentFlag.AlignVCenter)

        title_row = QHBoxLayout()
        title_row.setSpacing(8)
        self.header_title_lbl = QLabel(title)
        self.header_title_lbl.setFont(QFont("Microsoft YaHei UI", 12, QFont.Weight.Bold))
        self.header_title_lbl.setStyleSheet("color: #F8FAFC; background: transparent; border: none;")
        title_row.addWidget(self.header_title_lbl)

        if version_tag:
            self.header_ver_pill = QLabel(version_tag)
            self.header_ver_pill.setFont(QFont("Consolas", 8, QFont.Weight.Bold))
            self.header_ver_pill.setStyleSheet("""
                background: rgba(14, 165, 233, 0.15);
                color: #38BDF8;
                border: 1px solid #0EA5E9;
                border-radius: 4px;
                padding: 1px 6px;
            """)
            title_row.addWidget(self.header_ver_pill)
        title_row.addStretch()
        title_box.addLayout(title_row)

        if subtitle:
            self.header_sub_lbl = QLabel(subtitle)
            self.header_sub_lbl.setFont(QFont("Microsoft YaHei UI", 9))
            self.header_sub_lbl.setStyleSheet("color: #94A3B8; background: transparent; border: none;")
            title_box.addWidget(self.header_sub_lbl)
        header_layout.addLayout(title_box, stretch=1)

        # 脉冲绿色链路在线状态
        status_box = QHBoxLayout()
        status_box.setSpacing(5)
        dot_lbl = QLabel("●")
        dot_lbl.setFont(QFont("Microsoft YaHei UI", 8))
        dot_lbl.setStyleSheet("color: #10B981; background: transparent; border: none;")
        status_box.addWidget(dot_lbl)
        online_lbl = QLabel("量子链路")
        online_lbl.setFont(QFont("Microsoft YaHei UI", 9))
        online_lbl.setStyleSheet("color: #64748B; background: transparent; border: none;")
        status_box.addWidget(online_lbl)
        header_layout.addLayout(status_box)

        # 右上角圆形关闭按钮
        self.btn_close = QPushButton("✕")
        self.btn_close.setFixedSize(28, 28)
        self.btn_close.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_close.setToolTip("关闭窗口 (Esc)")
        self.btn_close.setStyleSheet("""
            QPushButton {
                background: rgba(30, 41, 59, 0.8);
                color: #94A3B8;
                border: 1px solid #334155;
                border-radius: 14px;
                font-size: 13px;
                font-weight: bold;
                padding: 0px;
            }
            QPushButton:hover {
                background: #EF4444;
                color: #FFFFFF;
                border: 1px solid #F87171;
            }
            QPushButton:pressed {
                background: #DC2626;
                color: #FFFFFF;
            }
        """)
        self.btn_close.clicked.connect(self.reject)
        header_layout.addWidget(self.btn_close)

        self.card_layout.addWidget(self.header_bar)

        # 标题栏下方细分隔线
        sep = QFrame()
        sep.setFixedHeight(1)
        sep.setStyleSheet("background-color: #1E293B; border: none;")
        self.card_layout.addWidget(sep)

        # 内容容器区域 (子类向 content_layout 中添加具体控件)
        self.content_widget = QWidget()
        self.content_widget.setStyleSheet("background: transparent;")
        self.content_layout = QVBoxLayout(self.content_widget)
        self.content_layout.setContentsMargins(0, 4, 0, 0)
        self.content_layout.setSpacing(10)
        self.card_layout.addWidget(self.content_widget)

        outer_layout.addWidget(self.main_card)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            if event.position().y() <= 65:
                self.is_dragging = True
                self.drag_start = event.globalPosition().toPoint() - self.frameGeometry().topLeft()
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self.is_dragging and event.buttons() & Qt.MouseButton.LeftButton:
            self.move(event.globalPosition().toPoint() - self.drag_start)
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.is_dragging = False
        super().mouseReleaseEvent(event)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key.Key_Escape:
            self.reject()
            event.accept()
        else:
            super().keyPressEvent(event)


class CyberGearCard(QFrame):
    """
    赛博装备卡片 (网格化矩阵架构)
    包含稀有度徽章、全息图标芯片、中英品质标签、装配状态与悬停霓虹流光
    """
    def __init__(self, code, name, desc, icon, rarity="SR", is_active=False, on_select=None):
        super().__init__()
        self.code = code
        self.on_select = on_select
        self.is_active = is_active
        self.setFixedHeight(68)
        self.setCursor(Qt.CursorShape.PointingHandCursor)

        rarity_colors = {
            "UR": ("#F59E0B", "rgba(245, 158, 11, 0.15)", "#FEF3C7", "UR·神话"),
            "SSR": ("#A855F7", "rgba(168, 85, 247, 0.15)", "#F3E8FF", "SSR·幻彩"),
            "SR": ("#0EA5E9", "rgba(14, 165, 233, 0.15)", "#E0F2FE", "SR·稀有"),
            "R": ("#10B981", "rgba(16, 185, 129, 0.15)", "#D1FAE5", "R·特装"),
            "BASE": ("#64748B", "rgba(100, 116, 139, 0.15)", "#F1F5F9", "原生")
        }
        self.border_color, self.badge_bg, self.badge_text, self.rarity_label = rarity_colors.get(
            rarity, rarity_colors["SR"]
        )

        layout = QHBoxLayout(self)
        layout.setContentsMargins(10, 8, 10, 8)
        layout.setSpacing(10)

        # 1. 左侧：全息图标芯片 (42x42)
        self.icon_frame = QFrame()
        self.icon_frame.setFixedSize(42, 42)
        icon_layout = QVBoxLayout(self.icon_frame)
        icon_layout.setContentsMargins(0, 0, 0, 0)
        icon_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lbl_icon = QLabel(icon)
        lbl_icon.setFont(QFont("Segoe UI Emoji", 18))
        lbl_icon.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lbl_icon.setStyleSheet("background: transparent; border: none;")
        icon_layout.addWidget(lbl_icon)
        layout.addWidget(self.icon_frame)

        # 2. 中间：标题 + 稀有度标签 + 描述
        mid_box = QVBoxLayout()
        mid_box.setSpacing(2)
        mid_box.setAlignment(Qt.AlignmentFlag.AlignVCenter)

        top_row = QHBoxLayout()
        top_row.setSpacing(6)
        lbl_name = QLabel(name)
        lbl_name.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        lbl_name.setStyleSheet("color: #F8FAFC; background: transparent; border: none;")
        top_row.addWidget(lbl_name)

        lbl_rarity = QLabel(self.rarity_label)
        lbl_rarity.setFont(QFont("Microsoft YaHei UI", 8, QFont.Weight.Bold))
        lbl_rarity.setStyleSheet(f"""
            background-color: {self.badge_bg};
            color: {self.border_color};
            border: 1px solid {self.border_color};
            border-radius: 4px;
            padding: 1px 5px;
        """)
        top_row.addWidget(lbl_rarity)
        top_row.addStretch()
        mid_box.addLayout(top_row)

        lbl_desc = QLabel(desc)
        lbl_desc.setFont(QFont("Microsoft YaHei UI", 8))
        lbl_desc.setStyleSheet("color: #CBD5E1; background: transparent; border: none;")
        mid_box.addWidget(lbl_desc)
        layout.addLayout(mid_box, stretch=1)

        # 3. 右侧：状态指示胶囊
        self.lbl_status = QLabel("✔ 已装配" if is_active else "试穿")
        self.lbl_status.setFont(QFont("Microsoft YaHei UI", 9, QFont.Weight.Bold))
        self.lbl_status.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.lbl_status.setFixedWidth(64)
        layout.addWidget(self.lbl_status)

        self.update_style()

    def set_active(self, active):
        self.is_active = active
        self.lbl_status.setText("✔ 已装配" if active else "试穿")
        self.update_style()

    def update_style(self):
        if self.is_active:
            self.setStyleSheet("""
                CyberGearCard {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 rgba(14, 165, 233, 0.25), stop:1 rgba(15, 23, 42, 0.85));
                    border: 1.5px solid #38BDF8;
                    border-radius: 12px;
                }
            """)
            self.icon_frame.setStyleSheet("""
                QFrame {
                    background: rgba(14, 165, 233, 0.2);
                    border: 1.5px solid #38BDF8;
                    border-radius: 10px;
                }
            """)
            self.lbl_status.setStyleSheet("""
                background: #0284C7;
                color: #FFFFFF;
                border-radius: 10px;
                padding: 4px 0px;
            """)
        else:
            self.setStyleSheet("""
                CyberGearCard {
                    background: rgba(30, 41, 59, 0.7);
                    border: 1px solid rgba(51, 65, 85, 0.8);
                    border-radius: 12px;
                }
                CyberGearCard:hover {
                    background: rgba(51, 65, 85, 0.85);
                    border: 1.5px solid #38BDF8;
                }
            """)
            self.icon_frame.setStyleSheet(f"""
                QFrame {{
                    background: rgba(15, 23, 42, 0.6);
                    border: 1px solid {self.border_color};
                    border-radius: 10px;
                }}
            """)
            self.lbl_status.setStyleSheet("""
                background: rgba(15, 23, 42, 0.6);
                color: #94A3B8;
                border: 1px solid #475569;
                border-radius: 10px;
                padding: 4px 0px;
            """)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton and self.on_select:
            sound_manager.play("pop")
            self.on_select(self.code)
        super().mousePressEvent(event)


class CyberTabButton(QPushButton):
    """赛博科技导航选项卡按钮"""
    def __init__(self, text, icon_str="", is_selected=False, parent=None):
        super().__init__(parent)
        self.setText(f"{icon_str} {text}" if icon_str else text)
        self.is_selected = is_selected
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFixedHeight(36)
        self.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        self.update_style()

    def set_selected(self, selected):
        self.is_selected = selected
        self.update_style()

    def update_style(self):
        if self.is_selected:
            self.setStyleSheet("""
                QPushButton {
                    background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0284C7, stop:1 #0EA5E9);
                    color: #FFFFFF;
                    border: 1px solid #38BDF8;
                    border-radius: 8px;
                    padding: 0 12px;
                }
            """)
        else:
            self.setStyleSheet("""
                QPushButton {
                    background: rgba(30, 41, 59, 0.6);
                    color: #94A3B8;
                    border: 1px solid rgba(51, 65, 85, 0.6);
                    border-radius: 8px;
                    padding: 0 12px;
                }
                QPushButton:hover {
                    background: rgba(51, 65, 85, 0.8);
                    color: #F1F5F9;
                    border: 1px solid #0EA5E9;
                }
            """)


class CyberGachaDialog(ModernBaseDialog):
    """
    赛博盲盒扭蛋机 (Cyber Gacha Pod)
    消耗金币或经验抽取限定发光装扮、手持道具与稀有家园小窝场景
    """
    def __init__(self, model, pet_window=None, parent=None):
        super().__init__(
            title="赛博盲盒 · 全息扭蛋机",
            subtitle="探寻未知装备矩阵 · 绝品发光神装与全息小窝场景解锁",
            icon_emoji="🎰",
            parent=pet_window or parent,
            fixed_width=560,
            fixed_height=580,
            version_tag="LUCKY MATRIX v3.2"
        )
        self.model = model
        self.pet_window = pet_window
        
        self.stack = QStackedWidget(self)
        self.content_layout.addWidget(self.stack)

        self._init_pod_page()
        self._init_results_page()
        self._refresh_pod_wallet()

    def _init_pod_page(self):
        self.page_pod = QWidget()
        layout = QVBoxLayout(self.page_pod)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(12)

        # 1. 顶部资产卡片
        wallet_bar = QHBoxLayout()
        self.coins_lbl = QLabel()
        self.coins_lbl.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        self.coins_lbl.setStyleSheet("""
            background: rgba(245, 158, 11, 0.15);
            color: #FBBF24;
            border: 1px solid #F59E0B;
            border-radius: 12px;
            padding: 4px 12px;
        """)
        self.exp_lbl = QLabel()
        self.exp_lbl.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        self.exp_lbl.setStyleSheet("""
            background: rgba(14, 165, 233, 0.15);
            color: #38BDF8;
            border: 1px solid #0EA5E9;
            border-radius: 12px;
            padding: 4px 12px;
        """)
        wallet_bar.addWidget(self.coins_lbl)
        wallet_bar.addStretch()
        wallet_bar.addWidget(self.exp_lbl)
        layout.addLayout(wallet_bar)

        # 2. 中间全息扭蛋仓展示区
        center_frame = QFrame()
        center_frame.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 #0F172A, stop:1 #0B0F19);
                border: 1.5px solid #0EA5E9;
                border-radius: 18px;
            }
        """)
        c_layout = QVBoxLayout(center_frame)
        c_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        c_layout.setSpacing(10)
        c_layout.setContentsMargins(20, 20, 20, 20)

        capsule_icon = QLabel("🔮")
        capsule_icon.setFont(QFont("Segoe UI Emoji", 48))
        capsule_icon.setAlignment(Qt.AlignmentFlag.AlignCenter)
        c_layout.addWidget(capsule_icon)

        banner = QLabel("CYBER REWARD MATRIX")
        banner.setFont(QFont("Consolas", 11, QFont.Weight.Bold))
        banner.setAlignment(Qt.AlignmentFlag.AlignCenter)
        banner.setStyleSheet("color: #38BDF8; letter-spacing: 2px;")
        c_layout.addWidget(banner)

        hint = QLabel("盲盒内含全套 5 插槽战术神装、手持道具及家园场景\n✨ 十连抽必得 SSR 或 UR 稀有配件！")
        hint.setFont(QFont("Microsoft YaHei UI", 10))
        hint.setAlignment(Qt.AlignmentFlag.AlignCenter)
        hint.setStyleSheet("color: #94A3B8; line-height: 1.4;")
        c_layout.addWidget(hint)

        layout.addWidget(center_frame, stretch=1)

        # 3. 抽奖控制按钮行
        btn_box = QHBoxLayout()
        btn_box.setSpacing(12)

        btn_single = QPushButton("🎲 单抽盲盒 (30 🪙)")
        btn_single.setFixedHeight(44)
        btn_single.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_single.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0284C7, stop:1 #0EA5E9);
                color: #FFFFFF;
                border: 1px solid #38BDF8;
                border-radius: 12px;
                font-weight: bold;
                font-size: 12px;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0369A1, stop:1 #38BDF8);
            }
        """)
        btn_single.clicked.connect(lambda: self._do_draw(1))
        btn_box.addWidget(btn_single, stretch=1)

        btn_ten = QPushButton("✨ 豪华十连抽 (270 🪙 必中SSR)")
        btn_ten.setFixedHeight(44)
        btn_ten.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_ten.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #7C3AED, stop:1 #EC4899);
                color: #FFFFFF;
                border: 1px solid #F472B6;
                border-radius: 12px;
                font-weight: bold;
                font-size: 12px;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #6D28D9, stop:1 #DB2777);
            }
        """)
        btn_ten.clicked.connect(lambda: self._do_draw(10))
        btn_box.addWidget(btn_ten, stretch=1)

        layout.addLayout(btn_box)
        self.stack.addWidget(self.page_pod)

    def _init_results_page(self):
        self.page_results = QWidget()
        layout = QVBoxLayout(self.page_results)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(10)

        # 顶部提示
        top_h = QHBoxLayout()
        self.res_title = QLabel("🎉 成功解构赛博奖励！")
        self.res_title.setFont(QFont("Microsoft YaHei UI", 12, QFont.Weight.Bold))
        self.res_title.setStyleSheet("color: #38BDF8;")
        top_h.addWidget(self.res_title)
        top_h.addStretch()
        self.res_coins_info = QLabel()
        self.res_coins_info.setStyleSheet("color: #FBBF24; font-weight: bold;")
        top_h.addWidget(self.res_coins_info)
        layout.addLayout(top_h)

        # 卡片滚动区
        self.res_scroll = QScrollArea()
        self.res_scroll.setWidgetResizable(True)
        self.res_scroll.setStyleSheet("background: transparent; border: none;")
        self.res_container = QWidget()
        self.res_container.setStyleSheet("background: transparent;")
        self.res_cards_layout = QVBoxLayout(self.res_container)
        self.res_cards_layout.setSpacing(8)
        self.res_cards_layout.setContentsMargins(0, 0, 8, 0)
        self.res_scroll.setWidget(self.res_container)
        layout.addWidget(self.res_scroll, stretch=1)

        # 底部返回操作
        bot_h = QHBoxLayout()
        btn_back = QPushButton("🔄 再来一发")
        btn_back.setFixedHeight(36)
        btn_back.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_back.setStyleSheet("""
            QPushButton {
                background: rgba(30, 41, 59, 0.8);
                color: #E2E8F0;
                border: 1px solid #475569;
                border-radius: 10px;
                font-weight: bold;
            }
            QPushButton:hover {
                background: rgba(51, 65, 85, 0.9);
                border: 1px solid #0EA5E9;
            }
        """)
        btn_back.clicked.connect(self._back_to_pod)
        bot_h.addWidget(btn_back)

        btn_close = QPushButton("✨ 收下奖励并返回")
        btn_close.setFixedHeight(36)
        btn_close.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_close.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0284C7, stop:1 #0EA5E9);
                color: #FFFFFF;
                border: 1px solid #38BDF8;
                border-radius: 10px;
                font-weight: bold;
            }
        """)
        btn_close.clicked.connect(self.accept)
        bot_h.addWidget(btn_close, stretch=1)

        layout.addLayout(bot_h)
        self.stack.addWidget(self.page_results)

    def _refresh_pod_wallet(self):
        self.coins_lbl.setText(f"🪙 赛博金币: {self.model.coins} 枚")
        self.exp_lbl.setText(f"✨ 经验备用池: {int(self.model.exp)} EXP")

    def _back_to_pod(self):
        self._refresh_pod_wallet()
        self.stack.setCurrentWidget(self.page_pod)

    def _do_draw(self, count):
        results = self.model.draw_gacha(count)
        self._show_results(results)

    def _show_results(self, results):
        self.res_title.setText(f"🎉 成功解构 {len(results)} 件赛博奖励！")
        self.res_coins_info.setText(f"剩余金币: {self.model.coins} 🪙")

        # 清空旧卡片
        while self.res_cards_layout.count():
            item = self.res_cards_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        rarity_colors = {
            "UR": "#F59E0B", "SSR": "#EC4899", "SR": "#38BDF8", "R": "#10B981"
        }

        slot_names = {
            "head": "头部装扮", "face": "面饰", "neck": "领饰",
            "back": "背饰神装", "hand": "手持道具", "habitat": "小窝背景"
        }

        for item in results:
            card = QFrame()
            card.setStyleSheet(f"""
                QFrame {{
                    background: rgba(15, 23, 42, 0.85);
                    border: 1.5px solid {rarity_colors.get(item['rarity'], '#38BDF8')};
                    border-radius: 12px;
                }}
            """)
            card_h = QHBoxLayout(card)
            card_h.setContentsMargins(12, 8, 12, 8)
            card_h.setSpacing(10)

            icon_lbl = QLabel(item["icon"])
            icon_lbl.setFont(QFont("Segoe UI Emoji", 20))
            icon_lbl.setFixedSize(36, 36)
            icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            icon_lbl.setStyleSheet(f"background: rgba(30, 41, 59, 0.8); border: 1px solid {rarity_colors.get(item['rarity'], '#38BDF8')}; border-radius: 8px;")
            card_h.addWidget(icon_lbl)

            info_v = QVBoxLayout()
            info_v.setSpacing(2)
            name_h = QHBoxLayout()
            name_h.setSpacing(6)
            name_lbl = QLabel(f"{item['name']} [{item['rarity']}]")
            name_lbl.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
            name_lbl.setStyleSheet(f"color: {rarity_colors.get(item['rarity'], '#38BDF8')};")
            name_h.addWidget(name_lbl)
            if item.get("is_new", False):
                new_badge = QLabel("NEW! ✨")
                new_badge.setFont(QFont("Microsoft YaHei UI", 8, QFont.Weight.Bold))
                new_badge.setStyleSheet("color: #F59E0B; background: rgba(245, 158, 11, 0.15); border: 1px solid #F59E0B; border-radius: 4px; padding: 1px 4px;")
                name_h.addWidget(new_badge)
            name_h.addStretch()
            info_v.addLayout(name_h)

            slot_str = slot_names.get(item["slot"], item["slot"])
            slot_lbl = QLabel(f"部位: {slot_str}")
            slot_lbl.setFont(QFont("Microsoft YaHei UI", 9))
            slot_lbl.setStyleSheet("color: #94A3B8;")
            info_v.addWidget(slot_lbl)
            card_h.addLayout(info_v, stretch=1)

            btn_equip = QPushButton("⚡ 立即穿戴/使用")
            btn_equip.setFixedHeight(28)
            btn_equip.setCursor(Qt.CursorShape.PointingHandCursor)
            btn_equip.setStyleSheet("""
                QPushButton {
                    background: rgba(14, 165, 233, 0.2);
                    color: #38BDF8;
                    border: 1px solid #0EA5E9;
                    border-radius: 6px;
                    padding: 0 10px;
                    font-size: 10px;
                    font-weight: bold;
                }
                QPushButton:hover {
                    background: rgba(14, 165, 233, 0.4);
                    color: #FFFFFF;
                }
            """)
            def _make_equip_func(slot=item['slot'], code=item['code'], b=btn_equip, nm=item['name']):
                def _eq():
                    if slot == "habitat":
                        self.model.set_habitat(code)
                    else:
                        self.model.set_decoration(slot, code)
                    self.model.save_to_disk()
                    sound_manager.play("sparkle")
                    if self.pet_window and hasattr(self.pet_window, "dialogue"):
                        self.pet_window.dialogue.say(f"✨ 已成功装备新获得的【{nm}】！")
                    b.setText("✓ 已装备")
                    b.setEnabled(False)
                return _eq
            btn_equip.clicked.connect(_make_equip_func())
            card_h.addWidget(btn_equip)

            self.res_cards_layout.addWidget(card)

        self.res_cards_layout.addStretch()
        self.stack.setCurrentWidget(self.page_results)


class WardrobeDialog(ModernBaseDialog):
    """
    全新赛博全息萌宠更衣舱与装备矩阵 (Cyber Holographic Wardrobe)
    左侧拥有旋转全息地台与视线追踪试衣舱，右侧平铺 7 大赛博分类导航与品质卡片矩阵
    """
    def __init__(self, model, pet_window=None, parent=None):
        super().__init__(
            title="萌宠衣橱 · 赛博换装舱",
            subtitle="全息投影实时试衣 · 11 款生物基因与 5 维微机甲装扮自由搭载 · 家园场景DIY",
            icon_emoji="👗",
            parent=pet_window or parent,
            fixed_width=840,
            fixed_height=590,
            version_tag="CYBER ARSENAL v3.2"
        )
        self.model = model
        self.pet_window = pet_window

        # 暂存当前试穿配置
        self.temp_skin = model.skin_id
        self.temp_decs = dict(model.decorations)
        self.temp_habitat = getattr(model, "habitat", "none")

        main_layout = QHBoxLayout()
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(18)
        self.content_layout.addLayout(main_layout, stretch=1)

        # ================= 左侧：全息试衣舱与操作面板 =================
        left_box = QVBoxLayout()
        left_box.setSpacing(8)

        # 赛博全息试衣舱
        self.preview_widget = CyberHoloChamberWidget(model, self)
        left_box.addWidget(self.preview_widget)

        # 装配插槽全息指示器 (6 个迷你芯片分两行展示)
        slots_col = QVBoxLayout()
        slots_col.setSpacing(4)
        slots_row1 = QHBoxLayout()
        slots_row1.setSpacing(4)
        slots_row2 = QHBoxLayout()
        slots_row2.setSpacing(4)
        self.slot_pills = {}

        pills_config = [
            ("head", "头饰", slots_row1),
            ("face", "面饰", slots_row1),
            ("neck", "领饰", slots_row1),
            ("back", "背饰", slots_row2),
            ("hand", "手持", slots_row2),
            ("habitat", "小窝", slots_row2),
        ]
        for s_key, s_name, row_target in pills_config:
            if s_key == "habitat":
                val = self.temp_habitat
            else:
                val = self.temp_decs.get(s_key, "none")
            txt = f"{s_name}: {val}" if val != "none" else f"{s_name}: 空"
            pill = QLabel(txt)
            pill.setFont(QFont("Microsoft YaHei UI", 8))
            pill.setAlignment(Qt.AlignmentFlag.AlignCenter)
            pill.setFixedHeight(22)
            pill.setStyleSheet("""
                background: rgba(15, 23, 42, 0.7);
                color: #38BDF8;
                border: 1px dashed #0284C7;
                border-radius: 6px;
                padding: 0 4px;
            """)
            row_target.addWidget(pill)
            self.slot_pills[s_key] = pill
        slots_col.addLayout(slots_row1)
        slots_col.addLayout(slots_row2)
        left_box.addLayout(slots_col)

        # 🎲 赛博随机穿搭按钮 (Lucky Cyber Shuffle)
        btn_random = QPushButton("🎲 赛博随机混搭 (Cyber Shuffle)")
        btn_random.setFixedHeight(32)
        btn_random.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_random.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #4F46E5, stop:1 #7C3AED);
                color: #FFFFFF;
                border: 1px solid #A78BFA;
                border-radius: 8px;
                font-weight: bold;
                font-size: 11px;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #6366F1, stop:1 #8B5CF6);
            }
        """)
        btn_random.clicked.connect(self._random_cyber_shuffle)
        left_box.addWidget(btn_random)

        # 🎰 赛博盲盒扭蛋抽奖入口
        btn_gacha = QPushButton("🎰 赛博盲盒扭蛋机 (Cyber Gacha)")
        btn_gacha.setFixedHeight(32)
        btn_gacha.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_gacha.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #EC4899, stop:1 #8B5CF6);
                color: #FFFFFF;
                border: 1px solid #F472B6;
                border-radius: 8px;
                font-weight: bold;
                font-size: 11px;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #DB2777, stop:1 #7C3AED);
            }
        """)
        btn_gacha.clicked.connect(self._open_gacha_dialog)
        left_box.addWidget(btn_gacha)

        left_box.addStretch()

        # 底部操作栏
        action_row = QHBoxLayout()
        action_row.setSpacing(8)

        btn_clear = QPushButton("🚫 卸下全部")
        btn_clear.setFixedHeight(36)
        btn_clear.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_clear.setStyleSheet("""
            QPushButton {
                background: rgba(30, 41, 59, 0.8);
                color: #94A3B8;
                border: 1px solid #334155;
                border-radius: 10px;
                font-size: 11px;
                font-weight: bold;
            }
            QPushButton:hover {
                background: rgba(51, 65, 85, 0.9);
                color: #F87171;
                border: 1px solid #EF4444;
            }
        """)
        btn_clear.clicked.connect(self._clear_all_decorations)
        action_row.addWidget(btn_clear)

        btn_save = QPushButton("✨ 保存并同步装配")
        btn_save.setFixedHeight(36)
        btn_save.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_save.setStyleSheet("""
            QPushButton {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0284C7, stop:1 #0EA5E9);
                color: #FFFFFF;
                border: 1px solid #38BDF8;
                border-radius: 10px;
                font-size: 12px;
                font-weight: bold;
            }
            QPushButton:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0369A1, stop:1 #38BDF8);
            }
        """)
        btn_save.clicked.connect(self._apply_and_close)
        action_row.addWidget(btn_save, stretch=1)
        left_box.addLayout(action_row)

        main_layout.addLayout(left_box)

        # ================= 右侧：赛博装备陈列室 =================
        right_box = QVBoxLayout()
        right_box.setSpacing(10)

        # 7 大赛博选项卡导航 (全平铺，无挤压)
        tab_bar = QHBoxLayout()
        tab_bar.setSpacing(4)
        self.tabs_meta = [
            ("skin", "🧬 基因"),
            ("head", "🎩 头部"),
            ("face", "👓 面部"),
            ("neck", "🧣 领饰"),
            ("back", "🪽 背部"),
            ("hand", "🎮 手持"),
            ("habitat", "🏠 小窝")
        ]
        self.tab_buttons = {}
        for key, title in self.tabs_meta:
            btn = CyberTabButton(title, is_selected=(key == "skin"))
            btn.clicked.connect(lambda checked, k=key: self._switch_tab(k))
            self.tab_buttons[key] = btn
            tab_bar.addWidget(btn)
        right_box.addLayout(tab_bar)

        # 装备展示滚动区
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")
        self.container = QWidget()
        self.container.setStyleSheet("QWidget { background: transparent; }")
        self.cards_layout = QVBoxLayout(self.container)
        self.cards_layout.setSpacing(8)
        self.cards_layout.setContentsMargins(0, 0, 8, 0)
        self.scroll.setWidget(self.container)
        right_box.addWidget(self.scroll, stretch=1)

        main_layout.addLayout(right_box, stretch=1)

        self.current_tab = "skin"
        self.card_widgets = {}
        self._populate_tab(self.current_tab)

    def _open_gacha_dialog(self):
        sound_manager.play("click")
        dlg = CyberGachaDialog(self.model, self.pet_window, self)
        if dlg.exec():
            self.temp_skin = self.model.skin_id
            self.temp_decs = dict(self.model.decorations)
            self.temp_habitat = getattr(self.model, "habitat", "none")
            self.preview_widget.update_skin(self.temp_skin)
            for s, c in self.temp_decs.items():
                self.preview_widget.update_decoration(s, c)
            self.preview_widget.update_habitat(self.temp_habitat)
            self._update_slot_pills()
            self._populate_tab(self.current_tab)

    def _switch_tab(self, tab_key):
        sound_manager.play("click")
        self.current_tab = tab_key
        for k, btn in self.tab_buttons.items():
            btn.set_selected(k == tab_key)
        self._populate_tab(tab_key)

    def _populate_tab(self, tab_key):
        # 清空当前卡片
        while self.cards_layout.count():
            item = self.cards_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        self.card_widgets = {}

        if tab_key == "skin":
            skins = [
                ("cat_golden_shaded", "👑 金渐层英短 (Ny25)", "暖金发腮包子脸与祖母绿宝石眸，尊贵优雅", "👑", "SSR"),
                ("cat_silver_shaded", "💎 银渐层英短 (Ns11)", "如银霜覆顶，天然纯黑眼线与薄荷碧玉眸", "💎", "SSR"),
                ("cat_ragdoll", "🌸 蓝双布偶仙女猫", "丝滑雪白被毛，柔雾蓝灰面具与海蓝宝石眸", "🌸", "SSR"),
                ("cat_tuxedo", "🎩 燕尾服奶牛警长", "经典黑白燕尾服、白围脖八字开脸、四蹄踏雪", "🎩", "SR"),
                ("cat_maine_coon", "🦁 霸气森林缅因", "猞猁耳尖羽、霸气狮鬃领圈与野生虎斑", "🦁", "SSR"),
                ("cat_sakura_peach", "🍡 樱花蜜桃粉晶猫", "春日梦幻柔粉渐变、樱花肉垫与玫瑰晶眸", "🍡", "UR"),
                ("cat_calico", "萌萌日系三花猫", "柔和杏色加墨灰花斑，粉嫩软萌肉垫", "🐱", "BASE"),
                ("cat_orange", "温暖大头橘猫", "金橘温暖虎斑毛色，圆润治愈", "🐱", "R"),
                ("cat_black", "暗夜黑曜猫", "玄黑优雅皮毛与明亮金黄大眼", "🐱", "SR"),
                ("cat_white", "纯白雪球猫", "纯白底色与梦幻异色双瞳 (左冰蓝/右翠绿)", "🐱", "SSR"),
                ("cat_british_blue", "经典英短蓝猫", "蓝灰缎面毛发，肉嘟嘟大包子脸与暖金琥珀眼", "🍊", "SSR"),
                ("cat_american_tabby", "美短银虎斑", "银白底色配灵动黑灰鱼骨斑，额头 M 纹活泼敏捷", "🐯", "SR"),
                ("cat_persian_white", "异瞳临清狮子猫", "雪白丝绸长毛配自带仙气的金银双色鸳鸯异瞳", "❄️", "SSR"),
                ("cat_siamese", "焦糖拿铁暹罗", "贵族重点色大尖耳与电光天青蓝宝石双眸", "☕", "SSR"),
                ("dog_shiba", "阳光赤柴", "元气金橙赤柴，经典白眉点", "🐶", "SR"),
                ("dog_black", "帅气黑柴", "俊俏黑柴，系着帅气蓝色领巾", "🐶", "SR"),
                ("dog_corgi", "软萌柯基", "暖金白领胸毛与呆萌大耳朵", "🐶", "R"),
                ("slime_blue", "海蓝果冻史莱姆", "清透海蓝通透渐变与星芒天线", "🫧", "SSR"),
                ("slime_pink", "草莓甜心史莱姆", "粉嫩果冻身躯与爱心天线", "🌸", "SR"),
                ("slime_gold", "欧皇黄金史莱姆", "金光闪闪尊贵身躯，吸金转运", "🌟", "UR"),
                ("penguin_tux", "燕尾服小企鹅", "呆萌企鹅幼崽，摇晃小脚丫", "🐧", "SSR")
            ]
            for code, name, desc, icon, rarity in skins:
                is_active = (self.temp_skin == code)
                card = CyberGearCard(
                    code, name, desc, icon, rarity, is_active,
                    on_select=lambda c: self._select_preview_skin(c)
                )
                self.card_widgets[code] = card
                self.cards_layout.addWidget(card)

        elif tab_key == "head":
            items = [
                ("none", "原生无头饰", "保持自然头顶，轻装无束缚", "🚫", "BASE"),
                ("crown", "黄金华贵王冠", "璀璨红宝石帝王冠，尊贵金辉", "👑", "UR"),
                ("halo", "金色天使光环", "头顶悬浮圣洁量子光晕", "😇", "SSR"),
                ("hat_wizard", "魔法巫师尖帽", "神秘紫罗兰尖顶帽，蕴含秘法", "🧙", "SSR"),
                ("band_sport", "热血运动发带", "元气红白绑带，燃起冲刺烈火", "🥊", "SSR"),
                ("horns", "俏皮小恶魔角", "火红可爱小尖角，捣蛋专属", "😈", "SR"),
                ("hat_party", "派对生日帽", "欢快粉色彩条毛绒球", "🥳", "R"),
                ("chef", "洁白厨师高帽", "米其林软萌主厨高帽", "👨‍🍳", "R")
            ]
            self._render_slot_items("head", items)

        elif tab_key == "face":
            items = [
                ("none", "清爽无面饰", "清澈大眼睛，纯粹灵动自然", "🚫", "BASE"),
                ("hacker_viser", "赛博战术全息目镜", "极客HUD准星与实时代码流透析", "🥽", "SSR"),
                ("sunglasses", "酷炫黑超战术墨镜", "街头潮牌霸气出街，边缘数据流", "🕶️", "SSR"),
                ("glasses", "金丝博士护目镜", "斯文博学圆框镜，搭载战术分析仪", "👓", "SR"),
                ("blush_hearts", "心动爱心面贴", "双颊粉红心动爱心，萌力迸发", "💖", "R")
            ]
            self._render_slot_items("face", items)

        elif tab_key == "neck":
            items = [
                ("none", "原生无领饰", "舒适自然脖颈", "🚫", "BASE"),
                ("bow", "优雅赤红蝴蝶结", "甜美艳红大蝴蝶结，绅士名媛典范", "🎀", "SSR"),
                ("tie", "绅士西装小领结", "优雅正式商务西装领结", "👔", "SR"),
                ("bell", "招财金小挂铃", "招财进宝叮咚小响铃，清脆动听", "🔔", "SR"),
                ("scarf", "温暖英伦围巾", "防寒保暖冬日毛线围巾", "🧣", "R")
            ]
            self._render_slot_items("neck", items)

        elif tab_key == "back":
            items = [
                ("none", "原生无背饰", "轻装出击，减免风阻零负荷", "🚫", "BASE"),
                ("wings", "反重力光子羽翼", "呼吸时伴随量子光辉轻颤扇动", "🪽", "UR"),
                ("cushion_zen", "禅意榻榻米软垫", "清香竹编蒲团，悠闲安歇发呆", "🍵", "SSR"),
                ("balloon", "浮动微引力爱心气球", "身后随风律动飘逸的粉红反物质气球", "🎈", "SR")
            ]
            self._render_slot_items("back", items)

        elif tab_key == "hand":
            items = [
                ("none", "空手无持物", "轻装上阵，双手保持自由", "🚫", "BASE"),
                ("keyboard", "赛博 RGB 机械键盘", "客制化发光按键，极客代码神器", "⌨️", "SSR"),
                ("fish_wand", "全息光纤逗猫棒", "超轻光纤握柄与发光激光游鱼", "🪄", "SR"),
                ("coffee", "极客外带纸杯咖啡", "天青芯片印花，杯口冒着温润热汽", "☕", "SR"),
                ("gamepad", "8-bit 复古荧光绿掌机", "经典掌上电玩，内置像素小游戏", "🎮", "SSR"),
                ("dumbbell", "能量健身哑铃", "高密度健身器材，元气力量充沛", "🏋️", "SR")
            ]
            self._render_slot_items("hand", items)

        elif tab_key == "habitat":
            habitats = [
                ("none", "原生透明小窝", "无多余背景，融入桌面原生工作流", "🖥️", "BASE"),
                ("neon_matrix", "暗夜霓虹极客房", "深蓝全息网格与自上而下的二进制流光代码雨", "🌃", "UR"),
                ("retro_arcade", "复古像素游戏机房", "Synthwave 霓虹洋红栅格与 8-bit 浮空星辰", "🕹️", "UR"),
                ("summer_beach", "夏日阳光海滩", "暖金落日余晖斜射光束与金色光斑光尘", "🏖️", "SSR"),
                ("zen_tatami", "佛系禅意蒲团室", "静谧抹茶清竹微光与徐徐慢速飘落的粉嫩樱花", "🌸", "SSR")
            ]
            for code, name, desc, icon, rarity in habitats:
                is_active = (self.temp_habitat == code)
                card = CyberGearCard(
                    code, name, desc, icon, rarity, is_active,
                    on_select=lambda c: self._select_preview_habitat(c)
                )
                self.card_widgets[code] = card
                self.cards_layout.addWidget(card)

        self.cards_layout.addStretch()

    def _render_slot_items(self, slot_name, items):
        current_val = self.temp_decs.get(slot_name, "none")
        for code, name, desc, icon, rarity in items:
            is_active = (current_val == code)
            card = CyberGearCard(
                code, name, desc, icon, rarity, is_active,
                on_select=lambda c, s=slot_name: self._select_preview_decoration(s, c)
            )
            self.card_widgets[code] = card
            self.cards_layout.addWidget(card)

    def _select_preview_skin(self, skin_id):
        self.temp_skin = skin_id
        for code, card in self.card_widgets.items():
            card.set_active(code == skin_id)
        self.preview_widget.update_skin(skin_id)

    def _select_preview_decoration(self, slot, code):
        self.temp_decs[slot] = code
        for c, card in self.card_widgets.items():
            card.set_active(c == code)
        self.preview_widget.update_decoration(slot, code)
        self._update_slot_pills()

    def _select_preview_habitat(self, code):
        self.temp_habitat = code
        for c, card in self.card_widgets.items():
            card.set_active(c == code)
        self.preview_widget.update_habitat(code)
        self._update_slot_pills()

    def _update_slot_pills(self):
        slot_names = {"head": "头饰", "face": "面饰", "neck": "领饰", "back": "背饰", "hand": "手持", "habitat": "小窝"}
        for s_key, pill in self.slot_pills.items():
            if s_key == "habitat":
                val = self.temp_habitat
            else:
                val = self.temp_decs.get(s_key, "none")
            pill.setText(f"{slot_names[s_key]}: {val}" if val != "none" else f"{slot_names[s_key]}: 空")

    def _random_cyber_shuffle(self):
        """赛博随机混搭"""
        all_skins = [
            "cat_calico", "cat_orange", "cat_black", "cat_white",
            "cat_golden_shaded", "cat_silver_shaded", "cat_ragdoll", "cat_tuxedo", "cat_maine_coon", "cat_sakura_peach",
            "cat_british_blue", "cat_american_tabby", "cat_persian_white", "cat_siamese",
            "dog_shiba", "dog_black", "dog_corgi",
            "slime_blue", "slime_pink", "slime_gold", "penguin_tux"
        ]
        head_items = ["none", "crown", "halo", "hat_wizard", "band_sport", "horns", "hat_party", "chef"]
        face_items = ["none", "hacker_viser", "sunglasses", "glasses", "blush_hearts"]
        neck_items = ["none", "bow", "tie", "bell", "scarf"]
        back_items = ["none", "wings", "balloon", "cushion_zen"]
        hand_items = ["none", "keyboard", "fish_wand", "coffee", "gamepad", "dumbbell"]
        habitat_items = ["none", "neon_matrix", "retro_arcade", "summer_beach", "zen_tatami"]

        self.temp_skin = random.choice(all_skins)
        self.temp_decs["head"] = random.choice(head_items)
        self.temp_decs["face"] = random.choice(face_items)
        self.temp_decs["neck"] = random.choice(neck_items)
        self.temp_decs["back"] = random.choice(back_items)
        self.temp_decs["hand"] = random.choice(hand_items)
        self.temp_habitat = random.choice(habitat_items)

        self.preview_widget.update_skin(self.temp_skin)
        for slot, code in self.temp_decs.items():
            self.preview_widget.update_decoration(slot, code)
        self.preview_widget.update_habitat(self.temp_habitat)

        self._update_slot_pills()
        self._populate_tab(self.current_tab)

        sound_manager.play("sparkle")
        self.preview_widget.set_speech("🎲 赛博算力为我混搭了全新装扮与小窝！", duration=3.5)

    def _clear_all_decorations(self):
        for slot in self.temp_decs:
            self.temp_decs[slot] = "none"
            self.preview_widget.update_decoration(slot, "none")
        self.temp_habitat = "none"
        self.preview_widget.update_habitat("none")
        self._update_slot_pills()
        self._populate_tab(self.current_tab)
        sound_manager.play("click")
        self.preview_widget.set_speech("🚫 已卸下所有外挂装配与小窝！", duration=3.0)

    def reject(self):
        if hasattr(self, "preview_widget") and hasattr(self.preview_widget, "timer"):
            self.preview_widget.timer.stop()
        super().reject()

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
        self.model.set_habitat(self.temp_habitat)
        self.model.save_to_disk()
        if self.pet_window and hasattr(self.pet_window, "dialogue"):
            self.pet_window.dialogue.say("⚡ 赛博装甲与小窝同步完毕！主人觉得帅气吗？(๑•̀ㅂ•́)و✧")
        self.accept()

class FeedingDialog(ModernBaseDialog):
    """美食投喂与成长进阶中心"""
    def __init__(self, model, pet_window, parent=None):
        super().__init__(
            title="投喂美食 · 培育成长",
            subtitle="丰富营养美食，加速萌宠发育与进阶蜕变",
            icon_emoji="🍼",
            parent=pet_window or parent,
            fixed_width=460,
            fixed_height=560
        )
        self.model = model
        self.pet_window = pet_window

        layout = self.content_layout
        layout.setSpacing(10)

        # 当前阶段与体重展示卡片 (使用精准 ID 作用域，彻底根治子标签样式污染)
        info_card = QFrame()
        info_card.setObjectName("FeedingInfoCard")
        info_card.setStyleSheet("""
            QFrame#FeedingInfoCard {
                background: rgba(30, 41, 59, 0.7);
                border-radius: 16px;
                border: 1px solid #334155;
            }
        """)
        info_layout = QVBoxLayout(info_card)
        info_layout.setContentsMargins(14, 12, 14, 12)
        info_layout.setSpacing(8)

        header_h = QHBoxLayout()
        stage_info = self.model.stage_info

        # 阶段与体重独立美化药丸
        self.stage_lbl = QLabel(f"🌟 当前阶梯: {stage_info['name']}")
        self.stage_lbl.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        self.stage_lbl.setStyleSheet("""
            background: rgba(14, 165, 233, 0.15);
            border: 1px solid #0EA5E9;
            border-radius: 11px;
            padding: 3px 10px;
            color: #38BDF8;
        """)

        self.weight_lbl = QLabel(f"⚖️ 体重: {self.model.weight} kg")
        self.weight_lbl.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        self.weight_lbl.setStyleSheet("""
            background: rgba(16, 185, 129, 0.15);
            border: 1px solid #10B981;
            border-radius: 11px;
            padding: 3px 10px;
            color: #34D399;
        """)

        header_h.addWidget(self.stage_lbl)
        header_h.addStretch()
        header_h.addWidget(self.weight_lbl)
        info_layout.addLayout(header_h)

        growth_h = QHBoxLayout()
        growth_title = QLabel("🌱 成长蜕变积累:")
        growth_title.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        growth_title.setStyleSheet("color: #94A3B8; background: transparent; border: none;")
        growth_h.addWidget(growth_title)

        target = stage_info["next_target"]
        curr_growth = int(self.model.growth)
        is_max = self.model.stage == "ULTIMATE" or curr_growth >= target
        display_growth = f"{curr_growth} (已达满阶星辉体 ✨)" if is_max else f"{curr_growth} / {target}"

        self.growth_val_lbl = QLabel(display_growth)
        self.growth_val_lbl.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        self.growth_val_lbl.setStyleSheet("color: #38BDF8; background: transparent; border: none;")
        growth_h.addWidget(self.growth_val_lbl, alignment=Qt.AlignmentFlag.AlignRight)
        info_layout.addLayout(growth_h)

        self.growth_bar = QProgressBar()
        self.growth_bar.setFixedHeight(12)
        self.growth_bar.setTextVisible(False)
        self.growth_bar.setMaximum(target)
        self.growth_bar.setValue(min(target, curr_growth))
        self.growth_bar.setStyleSheet("""
            QProgressBar {
                border: 1px solid #1E293B;
                background-color: rgba(15, 23, 42, 0.8);
                border-radius: 6px;
                height: 12px;
            }
            QProgressBar::chunk {
                border-radius: 6px;
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #06B6D4, stop:1 #3B82F6);
            }
        """)
        info_layout.addWidget(self.growth_bar)

        desc_lbl = QLabel(stage_info["desc"])
        desc_lbl.setStyleSheet("color: #94A3B8; font-size: 11px; background: transparent; border: none;")
        desc_lbl.setWordWrap(True)
        info_layout.addWidget(desc_lbl)
        layout.addWidget(info_card)

        # 营养美食列表
        title = QLabel("选择给萌宠投喂的营养美食：")
        title.setFont(QFont("Microsoft YaHei UI", 11, QFont.Weight.Bold))
        title.setStyleSheet("color: #F8FAFC; margin-top: 4px; background: transparent; border: none;")
        layout.addWidget(title)

        foods = [
            ("milk", "🍼", "幼宠温热奶粉", "成长 +12 · 饱食 +20 · 佛系大懒喵倾向 🍵"),
            ("cake", "🍰", "草莓鲜奶蛋糕", "成长 +18 · 饱食 +25 · 心情 +25 🍰"),
            ("cyber_chip", "⚡", "赛博能量芯片", "极客算力 +4 · 饱食 +25 · 极客黑客喵倾向 ⚡"),
            ("hacker_coffee", "☕", "极客黑客冷萃", "极客算力 +3 · 精力 +35 · 极客黑客喵倾向 💻"),
            ("fish", "🐟", "深海极品烤鱼", "成长 +26 · 饱食 +35 · 元气运动喵倾向 🏃"),
            ("steak", "🥩", "极品多汁厚牛排", "成长 +35 · 饱食 +45 · 元气运动喵倾向 🥩"),
            ("elixir", "🌟", "神奇仙灵仙果", "成长 +55 · 心情 +35 · 灵力爆发 ✨"),
            ("boba", "🧋", "珍珠温奶茶", "成长 +14 · 饱食 +18 · 佛系大懒喵倾向 🍵")
        ]

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setStyleSheet("border: none; background: transparent;")
        food_container = QWidget()
        food_layout = QVBoxLayout(food_container)
        food_layout.setContentsMargins(0, 0, 6, 0)
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

        target = stage_info["next_target"]
        curr_growth = int(self.model.growth)
        is_max = self.model.stage == "ULTIMATE" or curr_growth >= target
        display_growth = f"{curr_growth} (已达满阶星辉体 ✨)" if is_max else f"{curr_growth} / {target}"

        self.growth_val_lbl.setText(display_growth)
        self.growth_bar.setMaximum(target)
        self.growth_bar.setValue(min(target, curr_growth))

        self.pet_window.dialogue.say(f"啊呜！好香的【{food_name}】！成长值 +{int(growth_add)}，身体又长大啦~ (๑´ڡ`๑)")

class PlayDialog(ModernBaseDialog):
    """趣味小游戏互动"""
    def __init__(self, model, pet_window, parent=None):
        super().__init__(
            title="趣味玩耍 · 互动游乐",
            subtitle="猜拳对决、掷骰子比大小与逗趣互动",
            icon_emoji="🎲",
            parent=pet_window or parent,
            fixed_width=440,
            fixed_height=490
        )
        self.model = model
        self.pet_window = pet_window

        layout = self.content_layout
        layout.setSpacing(10)

        title = QLabel("选择好玩的娱乐活动：")
        title.setFont(QFont("Microsoft YaHei UI", 11, QFont.Weight.Bold))
        title.setStyleSheet("color: #F8FAFC; background: transparent; border: none;")
        layout.addWidget(title)

        # 猜拳游戏模块 (使用专用 ID 选择器，杜绝子标签边框污染)
        rps_group = QFrame()
        rps_group.setObjectName("RpsGroup")
        rps_group.setStyleSheet("""
            QFrame#RpsGroup {
                background: rgba(30, 41, 59, 0.7);
                border-radius: 14px;
                border: 1px solid #334155;
                padding: 10px;
            }
        """)
        rps_layout = QVBoxLayout(rps_group)
        rps_layout.setContentsMargins(10, 8, 10, 8)
        rps_layout.setSpacing(8)

        rps_lbl = QLabel("✂️ 猜拳大对决 (石头剪刀布)")
        rps_lbl.setFont(QFont("Microsoft YaHei UI", 11, QFont.Weight.Bold))
        rps_lbl.setStyleSheet("color: #38BDF8; background: transparent; border: none;")
        rps_layout.addWidget(rps_lbl)

        btn_box = QHBoxLayout()
        btn_box.setSpacing(8)
        for choice, emoji in [("rock", "✊ 石头"), ("scissors", "✌️ 剪刀"), ("paper", "🖐️ 布")]:
            btn = QPushButton(emoji)
            btn.setFixedHeight(36)
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
        btn_talents = ActionCardButton("🎭", "动作才艺大赏", "点播展示全部 14 项专属动作")
        btn_talents.clicked.connect(self._open_talents)
        layout.addWidget(btn_talents)

        # 实时对决结果徽章展示卡片
        self.result_lbl = QLabel("")
        self.result_lbl.setWordWrap(True)
        self.result_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.result_lbl.setStyleSheet("color: #38BDF8; font-size: 12px; font-weight: bold; background: rgba(14, 165, 233, 0.15); border: 1.5px solid #0EA5E9; border-radius: 10px; padding: 10px;")
        self.result_lbl.hide()
        layout.addWidget(self.result_lbl)

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
            sound_manager.play("pop")
        elif (user_choice == "rock" and pet_choice == "scissors") or \
             (user_choice == "scissors" and pet_choice == "paper") or \
             (user_choice == "paper" and pet_choice == "rock"):
            msg = f"波可出了【{names[pet_choice]}】，主人出了【{names[user_choice]}】！太厉害了，主人获胜！🎉"
            sound_manager.play("sparkle")
        else:
            msg = f"波可出了【{names[pet_choice]}】！嘿嘿，这局是波可赢啦~ 耶！✨"
            sound_manager.play("pop")

        self.result_lbl.setText(msg)
        self.result_lbl.show()
        self.model.play_minigame("rps")
        self.pet_window.dialogue.say(f"【猜拳】{msg}")
        QTimer.singleShot(1400, self.accept)

    def _play_dice(self):
        user_num = random.randint(1, 6)
        pet_num = random.randint(1, 6)
        dice_emojis = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
        msg = f"主人掷出 {dice_emojis[user_num-1]} ({user_num}点)，波可掷出 {dice_emojis[pet_num-1]} ({pet_num}点)！"
        if user_num > pet_num:
            msg += " 主人获胜！🎉"
            sound_manager.play("sparkle")
        elif pet_num > user_num:
            msg += " 波可点数更大，嘿嘿！✨"
            sound_manager.play("pop")
        else:
            msg += " 心有灵犀平局！🤝"
            sound_manager.play("pop")
        self.result_lbl.setText(msg)
        self.result_lbl.show()
        self.model.play_minigame("dice")
        self.pet_window.dialogue.say(msg)
        QTimer.singleShot(1400, self.accept)

    def _play_wand(self):
        self.result_lbl.setText("🪄 飞身扑击！波可欢快抓住了逗宠棒！(ฅ'ω'ฅ)")
        self.result_lbl.show()
        sound_manager.play("meow")
        self.model.play_minigame("wand")
        self.pet_window.renderer.trigger_pet()
        self.pet_window.dialogue.say("哇！看波可的飞身扑击！捉到逗宠棒啦！(扑腾🐾)")
        QTimer.singleShot(1200, self.accept)

class ActionShowDialog(ModernBaseDialog):
    """
    萌宠动作才艺大赏交互面板
    支持 14 种高精度专属动作随时点播与趣味演练
    """
    def __init__(self, model, pet_window, parent=None):
        super().__init__(
            title="才艺秀场 · 动作大赏",
            subtitle="点击任意卡片，波可将立即在桌面表演绝活",
            icon_emoji="🎭",
            parent=pet_window or parent,
            fixed_width=460,
            fixed_height=560
        )
        self.model = model
        self.pet_window = pet_window

        layout = self.content_layout
        layout.setSpacing(8)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.Shape.NoFrame)
        scroll.setStyleSheet("background: transparent; border: none;")

        container = QWidget()
        box = QVBoxLayout(container)
        box.setContentsMargins(0, 0, 6, 0)
        box.setSpacing(8)

        actions = [
            ("CARDBOARD_BOX", "📦", "纸箱藏猫猫 (新绝活)", "快递空纸箱是猫咪快乐老家，钻进箱子探头暗中观察"),
            ("PEEK_EDGE", "👀", "贴边探头偷看 (新技能)", "敏捷滑到屏幕最近边缘，两只小肉垫扒住边框探头暗中偷看"),
            ("CATCH_MOUSE", "🐭", "敏捷扑抓小老鼠", "机械发条小老鼠欢快乱窜，波可敏捷飞扑擒拿"),
            ("PLAY_YARN", "🧶", "欢快拨玩毛线球", "粉嫩毛线球弹跳滚动，左右肉垫欢畅轻拍玩耍"),
            ("STRETCH_YAWN", "🐱", "伸个懒腰打哈欠", "拉伸舒展身子骨，张开萌萌大口打哈欠"),
            ("WASH_FACE", "🐾", "萌爪洗脸理毛", "举起粉嫩小肉垫，规律轻揉脸颊胡须"),
            ("CHASE_BUTTERFLY", "🦋", "欢快抓扑彩蝶", "荧光彩蝶绕身飞舞，波可轻快挥爪扑腾"),
            ("HEAD_BOB_MUSIC", "🎧", "佩戴耳机律动", "佩戴酷潮头戴耳机，随动感音乐节奏摇摆"),
            ("TILT_HEAD", "❓", "歪头好奇卖萌", "大眼睛扑闪扑闪，歪头好奇观察主人的工作"),
            ("HAPPY_SPIN", "🌀", "追尾狂欢大回旋", "兴奋地原地追逐自己的尾巴狂转圈圈，眼神锁定尾尖小爪飞扑"),
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

    def _trigger_action(self, action_code):
        sound_manager.play("click")
        self.accept()
        if action_code == "PEEK_EDGE":
            if hasattr(self.pet_window, "trigger_edge_peek"):
                self.pet_window.trigger_edge_peek()
            return
        self.pet_window.play_action(action_code)

class FocusDialog(ModernBaseDialog):
    """赛博全息深度专注力场 (Cyber Focus Matrix)"""
    def __init__(self, model, pet_window, parent=None):
        super().__init__(
            title="深度专注 · 赛博心流力场",
            subtitle="设定专注时长，波可将开启静默心流守护",
            icon_emoji="🍅",
            parent=pet_window or parent,
            fixed_width=450,
            fixed_height=440
        )
        self.model = model
        self.pet_window = pet_window
        self.selected_minutes = 25

        self._refresh_timer = QTimer(self)
        self._refresh_timer.timeout.connect(self._on_tick_update)

        self._build_ui()

    def _build_ui(self):
        # 清空现有子控件
        while self.content_layout.count():
            item = self.content_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        if self.model.is_studying:
            self._build_active_view()
            self._refresh_timer.start(1000)
        else:
            self._build_setup_view()
            self._refresh_timer.stop()

    def _build_active_view(self):
        layout = self.content_layout
        layout.setSpacing(14)

        # 正在专注全息 HUD 卡片
        hud_card = QFrame()
        hud_card.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1, stop:0 rgba(11, 15, 25, 0.95), stop:1 rgba(15, 23, 42, 0.95));
                border: 1.5px solid #0EA5E9;
                border-radius: 16px;
            }
        """)
        card_l = QVBoxLayout(hud_card)
        card_l.setContentsMargins(18, 16, 18, 16)
        card_l.setAlignment(Qt.AlignmentFlag.AlignCenter)

        status_lbl = QLabel("🛡️ 深度心流守护力场已展开")
        status_lbl.setFont(QFont("Microsoft YaHei UI", 11, QFont.Weight.Bold))
        status_lbl.setStyleSheet("color: #38BDF8;")
        status_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card_l.addWidget(status_lbl)

        # 倒计时大字符
        self.time_lbl = QLabel(self._format_time_left())
        self.time_lbl.setFont(QFont("Consolas", 36, QFont.Weight.Bold))
        self.time_lbl.setStyleSheet("color: #F8FAFC; letter-spacing: 2px; padding: 10px 0;")
        self.time_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card_l.addWidget(self.time_lbl)

        # 全息进度条
        self.pbar = QProgressBar()
        self.pbar.setFixedHeight(8)
        self.pbar.setTextVisible(False)
        self.pbar.setStyleSheet("""
            QProgressBar {
                background-color: #1E293B;
                border: none;
                border-radius: 4px;
            }
            QProgressBar::chunk {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #0284C7, stop:1 #38BDF8);
                border-radius: 4px;
            }
        """)
        total = max(1, int(self.model.study_duration))
        left = max(0, int(self.model.study_time_left))
        elapsed = max(0, total - left)
        self.pbar.setRange(0, total)
        self.pbar.setValue(elapsed)
        card_l.addWidget(self.pbar)

        tip_lbl = QLabel(f"总时长: {int(total // 60)} 分钟 · 达成后自动奖励 50 EXP 与大量好心情 ✨")
        tip_lbl.setFont(QFont("Microsoft YaHei UI", 9))
        tip_lbl.setStyleSheet("color: #94A3B8; margin-top: 6px;")
        tip_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card_l.addWidget(tip_lbl)

        layout.addWidget(hud_card)
        layout.addStretch()

        # 底部操作按钮
        btn_box = QHBoxLayout()
        btn_cancel = QPushButton("⏹️ 提前结束专注")
        btn_cancel.setFixedHeight(38)
        btn_cancel.setStyleSheet("""
            QPushButton {
                background-color: rgba(244, 63, 94, 0.15);
                border: 1px solid #F43F5E;
                color: #FDA4AF;
                border-radius: 12px;
                font-weight: 500;
            }
            QPushButton:hover {
                background-color: rgba(244, 63, 94, 0.3);
                color: #FFFFFF;
            }
        """)
        btn_cancel.clicked.connect(self._stop_focus)
        btn_box.addWidget(btn_cancel)

        btn_keep = QPushButton("🛡️ 保持静默守护")
        btn_keep.setObjectName("PrimaryBtn")
        btn_keep.setFixedHeight(38)
        btn_keep.clicked.connect(self.accept)
        btn_box.addWidget(btn_keep)

        layout.addLayout(btn_box)

    def _format_time_left(self):
        secs = max(0, int(getattr(self.model, "study_time_left", 0)))
        m = secs // 60
        s = secs % 60
        return f"{m:02d}:{s:02d}"

    def _on_tick_update(self):
        if not self.model.is_studying:
            self._refresh_timer.stop()
            self._build_ui()
            return
        if hasattr(self, "time_lbl"):
            self.time_lbl.setText(self._format_time_left())
        if hasattr(self, "pbar"):
            total = max(1, int(self.model.study_duration))
            left = max(0, int(self.model.study_time_left))
            self.pbar.setValue(max(0, total - left))

    def _stop_focus(self):
        self.model.cancel_focus_timer()
        if self.pet_window:
            self.pet_window.dialogue.say("专注提前结束啦。随时欢迎开启下一次心流旅程！☕")
        self._build_ui()

    def _build_setup_view(self):
        layout = self.content_layout
        layout.setSpacing(10)

        title = QLabel("🎯 选择极客专注模式或滑动微调：")
        title.setFont(QFont("Microsoft YaHei UI", 11, QFont.Weight.Bold))
        title.setStyleSheet("color: #F8FAFC;")
        layout.addWidget(title)

        # 4 战术预设网格
        grid = QGridLayout()
        grid.setSpacing(8)

        presets = [
            (15, "⚡ 15m 灵感极速跑", "短促高能冲刺"),
            (25, "🍅 25m 经典番茄钟", "标准心流节拍"),
            (45, "💻 45m 深度工坊", "深度复杂任务"),
            (60, "🚀 60m 极客沉浸代码", "彻底心流模式"),
        ]

        self.preset_btns = []
        for idx, (m, name, desc) in enumerate(presets):
            btn = QPushButton(f"{name}\n{desc}")
            btn.setFixedHeight(54)
            btn.setFont(QFont("Microsoft YaHei UI", 9))
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            btn.clicked.connect(lambda checked, mins=m: self._select_preset(mins))
            grid.addWidget(btn, idx // 2, idx % 2)
            self.preset_btns.append((m, btn))

        layout.addLayout(grid)

        # 滑块自由微调
        slider_card = QFrame()
        slider_card.setStyleSheet("""
            QFrame {
                background: rgba(15, 23, 42, 0.7);
                border: 1px solid #334155;
                border-radius: 12px;
                padding: 6px;
            }
        """)
        sl_layout = QVBoxLayout(slider_card)
        sl_layout.setContentsMargins(10, 6, 10, 6)
        sl_layout.setSpacing(4)

        self.custom_val_lbl = QLabel(f"自定义时长调节: {self.selected_minutes} 分钟")
        self.custom_val_lbl.setFont(QFont("Microsoft YaHei UI", 9, QFont.Weight.Bold))
        self.custom_val_lbl.setStyleSheet("color: #38BDF8;")
        sl_layout.addWidget(self.custom_val_lbl)

        self.slider = QSlider(Qt.Orientation.Horizontal)
        self.slider.setRange(5, 120)
        self.slider.setValue(self.selected_minutes)
        self.slider.setStyleSheet("""
            QSlider::groove:horizontal {
                height: 6px;
                background: #1E293B;
                border-radius: 3px;
            }
            QSlider::sub-page:horizontal {
                background: #0EA5E9;
                border-radius: 3px;
            }
            QSlider::handle:horizontal {
                background: #38BDF8;
                width: 16px;
                margin-top: -5px;
                margin-bottom: -5px;
                border-radius: 8px;
            }
        """)
        self.slider.valueChanged.connect(self._on_slider_change)
        sl_layout.addWidget(self.slider)

        layout.addWidget(slider_card)
        layout.addStretch()

        # 底部操作栏
        btn_box = QHBoxLayout()
        btn_cancel = QPushButton("取消")
        btn_cancel.setFixedHeight(38)
        btn_cancel.clicked.connect(self.reject)
        btn_box.addWidget(btn_cancel)

        self.btn_start = QPushButton(f"🚀 启动专注 ({self.selected_minutes}分钟)", self)
        self.btn_start.setObjectName("PrimaryBtn")
        self.btn_start.setFixedHeight(38)
        self.btn_start.clicked.connect(self._start_focus)
        btn_box.addWidget(self.btn_start)

        layout.addLayout(btn_box)
        self._update_preset_button_styles()

    def _select_preset(self, mins):
        self.selected_minutes = mins
        self.slider.setValue(mins)
        self._update_preset_button_styles()

    def _on_slider_change(self, val):
        self.selected_minutes = val
        self.custom_val_lbl.setText(f"自定义时长调节: {val} 分钟")
        self.btn_start.setText(f"🚀 启动专注 ({val}分钟)")
        self._update_preset_button_styles()

    def _update_preset_button_styles(self):
        for m, btn in getattr(self, "preset_btns", []):
            if m == self.selected_minutes:
                btn.setStyleSheet("""
                    QPushButton {
                        background: rgba(14, 165, 233, 0.25);
                        border: 1.5px solid #38BDF8;
                        color: #FFFFFF;
                        border-radius: 12px;
                        font-weight: bold;
                    }
                """)
            else:
                btn.setStyleSheet("""
                    QPushButton {
                        background: rgba(30, 41, 59, 0.7);
                        border: 1px solid rgba(51, 65, 85, 0.8);
                        color: #94A3B8;
                        border-radius: 12px;
                    }
                    QPushButton:hover {
                        border-color: #0EA5E9;
                        color: #F8FAFC;
                    }
                """)

    def _start_focus(self):
        self.model.start_focus_timer(self.selected_minutes)
        if self.pet_window:
            self.pet_window.dialogue.say(f"🍅 全息专注力场启动！接下来的 {self.selected_minutes} 分钟，波可会认真陪伴主人专注工作哦~ 📖✏️")
        self.accept()

class StatusDialog(ModernBaseDialog):
    """宠物详细状态属性面板"""
    def __init__(self, model, parent=None):
        super().__init__(
            title="萌宠档案 · 状态体征",
            subtitle="波可的多维健康体征与成长档案",
            icon_emoji="📊",
            parent=parent,
            fixed_width=460,
            fixed_height=640
        )
        self.model = model

        layout = self.content_layout
        layout.setSpacing(8)

        # 头部等级与称号
        header = QHBoxLayout()
        avatar = QLabel("🐱" if model.pet_type == "cat" else ("🐶" if model.pet_type == "dog" else ("🫧" if model.pet_type == "slime" else "🐧")))
        avatar.setFont(QFont("Segoe UI Emoji", 30))
        avatar.setFixedSize(50, 50)
        avatar.setAlignment(Qt.AlignmentFlag.AlignCenter)
        avatar.setStyleSheet("background-color: rgba(30, 41, 59, 0.8); border-radius: 25px; border: 2px solid #38BDF8;")
        header.addWidget(avatar)

        title_info = QVBoxLayout()
        title_info.setSpacing(2)
        name_lbl = QLabel(f"{model.name}  Lv.{model.level}")
        name_lbl.setFont(QFont("Microsoft YaHei UI", 13, QFont.Weight.Bold))
        name_lbl.setStyleSheet("color: #F8FAFC; background: transparent; border: none;")
        stage_info = model.stage_info
        title_lbl = QLabel(f"{stage_info['name']} · 陪伴第 {model.total_days} 天 · 亲密度: {model.intimacy} 点 · 体重: {model.weight}kg")
        title_lbl.setStyleSheet("color: #38BDF8; font-weight: 500; font-size: 11px;")
        title_info.addWidget(name_lbl)
        title_info.addWidget(title_lbl)
        header.addLayout(title_info)
        layout.addLayout(header)

        # 成长进度条
        growth_box = QVBoxLayout()
        growth_box.setSpacing(3)
        growth_h = QHBoxLayout()
        growth_title = QLabel("🌱 成长蜕变积累")
        growth_title.setStyleSheet("font-size: 11px; font-weight: bold; color: #94A3B8;")
        growth_h.addWidget(growth_title)

        target = stage_info["next_target"]
        curr_growth = int(model.growth)
        is_max = model.stage == "ULTIMATE" or curr_growth >= target
        display_growth = f"{curr_growth} (已达满阶 ✨)" if is_max else f"{curr_growth} / {target}"

        g_val = QLabel(display_growth)
        g_val.setStyleSheet("color: #38BDF8; font-size: 11px; font-weight: bold;")
        growth_h.addWidget(g_val, alignment=Qt.AlignmentFlag.AlignRight)
        growth_box.addLayout(growth_h)

        growth_bar = QProgressBar()
        growth_bar.setFixedHeight(8)
        growth_bar.setTextVisible(False)
        growth_bar.setMaximum(target)
        growth_bar.setValue(min(target, curr_growth))
        growth_bar.setStyleSheet("""
            QProgressBar {
                border: 1px solid #1E293B;
                background-color: rgba(15, 23, 42, 0.8);
                border-radius: 4px;
            }
            QProgressBar::chunk {
                border-radius: 4px;
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #10B981, stop:1 #059669);
            }
        """)
        growth_box.addWidget(growth_bar)
        layout.addLayout(growth_box)

        # 经验条
        exp_box = QVBoxLayout()
        exp_box.setSpacing(3)
        exp_header = QHBoxLayout()
        exp_title = QLabel("陪伴经验值")
        exp_title.setStyleSheet("font-size: 11px; font-weight: bold; color: #94A3B8;")
        exp_header.addWidget(exp_title)
        exp_val = QLabel(f"{int(model.exp)} / {model.max_exp}")
        exp_val.setStyleSheet("color: #38BDF8; font-size: 11px; font-weight: bold;")
        exp_header.addWidget(exp_val, alignment=Qt.AlignmentFlag.AlignRight)
        exp_box.addLayout(exp_header)

        exp_bar = QProgressBar()
        exp_bar.setFixedHeight(8)
        exp_bar.setTextVisible(False)
        exp_bar.setMaximum(model.max_exp)
        exp_bar.setValue(min(model.max_exp, int(model.exp)))
        exp_bar.setStyleSheet("""
            QProgressBar {
                border: 1px solid #1E293B;
                background-color: rgba(15, 23, 42, 0.8);
                border-radius: 4px;
            }
            QProgressBar::chunk {
                border-radius: 4px;
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0, stop:0 #06B6D4, stop:1 #3B82F6);
            }
        """)
        exp_box.addWidget(exp_bar)
        layout.addLayout(exp_box)

        # 4大基础体征条
        self._add_stat_bar(layout, "🍗 饱食度", int(model.hunger), "#F59E0B")
        self._add_stat_bar(layout, "💖 心情值", int(model.mood), "#EC4899")
        self._add_stat_bar(layout, "⚡ 精力值", int(model.energy), "#3B82F6")
        self._add_stat_bar(layout, "🫧 清洁度", int(model.cleanliness), "#06B6D4")

        # 5. 性格树与行为塑造矩阵
        pers_info = model.personality_info
        pers_card = QFrame()
        pers_card.setStyleSheet("""
            QFrame {
                background: rgba(15, 23, 42, 0.85);
                border: 1.2px solid #0EA5E9;
                border-radius: 12px;
            }
        """)
        pers_layout = QVBoxLayout(pers_card)
        pers_layout.setContentsMargins(10, 8, 10, 8)
        pers_layout.setSpacing(4)

        p_header = QHBoxLayout()
        p_badge = QLabel(f"🧬 主导性格: {pers_info['name']}")
        p_badge.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        p_badge.setStyleSheet(f"color: {pers_info['color']}; background: transparent; border: none;")
        p_header.addWidget(p_badge)
        p_header.addStretch()
        p_coins = QLabel(f"🪙 赛博金币: {model.coins}")
        p_coins.setStyleSheet("color: #FBBF24; font-size: 10px; font-weight: bold; background: transparent; border: none;")
        p_header.addWidget(p_coins)
        pers_layout.addLayout(p_header)

        p_desc = QLabel(f"💡 {pers_info['desc']}\n✨ 特权: {pers_info['bonus']}")
        p_desc.setFont(QFont("Microsoft YaHei UI", 8))
        p_desc.setStyleSheet("color: #94A3B8; background: transparent; border: none; line-height: 1.3;")
        p_desc.setWordWrap(True)
        pers_layout.addWidget(p_desc)

        # 3维性格倾向条 (以 50 点为满槽参考)
        stats = model.personality_stats
        self._add_stat_bar(pers_layout, "⚡ 极客科技度 (Tech)", min(100, int(stats.get("tech", 0) * 2)), "#0EA5E9")
        self._add_stat_bar(pers_layout, "🏃 元气运动度 (Sport)", min(100, int(stats.get("sport", 0) * 2)), "#10B981")
        self._add_stat_bar(pers_layout, "🍵 佛系闲适度 (Lazy)", min(100, int(stats.get("lazy", 0) * 2)), "#F59E0B")

        layout.addWidget(pers_card)

    def _add_stat_bar(self, layout, label_text, value, color_hex):
        box = QVBoxLayout()
        box.setSpacing(3)
        h = QHBoxLayout()
        lbl = QLabel(label_text)
        lbl.setStyleSheet("font-size: 11px; font-weight: bold; color: #94A3B8;")
        h.addWidget(lbl)
        val_lbl = QLabel(f"{value}%")
        val_lbl.setStyleSheet("color: #E2E8F0; font-size: 11px; font-weight: bold;")
        h.addWidget(val_lbl, alignment=Qt.AlignmentFlag.AlignRight)
        box.addLayout(h)

        bar = QProgressBar()
        bar.setFixedHeight(10)
        bar.setTextVisible(False)
        bar.setMaximum(100)
        bar.setValue(value)
        bar.setStyleSheet(f"""
            QProgressBar {{
                border: 1px solid #1E293B;
                background-color: rgba(15, 23, 42, 0.8);
                border-radius: 5px;
            }}
            QProgressBar::chunk {{
                border-radius: 5px;
                background-color: {color_hex};
            }}
        """)
        box.addWidget(bar)
        layout.addLayout(box)

class SettingsDialog(ModernBaseDialog):
    """系统偏好设置面板"""
    def __init__(self, model, pet_window, parent=None):
        super().__init__(
            title="偏好设置 · 个性定制",
            subtitle="自定义体型大小、行为习惯与系统开机项",
            icon_emoji="⚙️",
            parent=pet_window or parent,
            fixed_width=460,
            fixed_height=530
        )
        self.model = model
        self.pet_window = pet_window
        self._initial_scale = model.user_scale_offset

        layout = self.content_layout
        layout.setSpacing(11)

        # 大小微调缩放调节
        scale_box = QVBoxLayout()
        scale_box.setSpacing(4)
        scale_title_box = QHBoxLayout()
        scale_lbl = QLabel("宠物微调缩放比例:")
        scale_lbl.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        scale_title_box.addWidget(scale_lbl)
        self.scale_val_lbl = QLabel(f"{int(model.user_scale_offset * 100)}%")
        self.scale_val_lbl.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        self.scale_val_lbl.setStyleSheet("color: #38BDF8;")
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

        self.cb_gravity = QCheckBox("启用桌面物理重力 (关闭可自由悬停在屏幕任意位置)")
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

        self.cb_click_through = QCheckBox("启用鼠标穿透 (免打扰模式，点击直接穿透至下层窗口)")
        self.cb_click_through.setChecked(getattr(pet_window, "click_through", False))
        layout.addWidget(self.cb_click_through)

        layout.addStretch()

        # 底部保存应用
        btn_box = QHBoxLayout()
        btn_cancel = QPushButton("取消")
        btn_cancel.setFixedHeight(38)
        btn_cancel.clicked.connect(self.reject)
        btn_box.addWidget(btn_cancel)

        btn_apply = QPushButton("保存设置", self)
        btn_apply.setObjectName("PrimaryBtn")
        btn_apply.setFixedHeight(38)
        btn_apply.clicked.connect(self._apply_settings)
        btn_box.addWidget(btn_apply)
        layout.addLayout(btn_box)

    def _on_scale_change(self, val):
        self.scale_val_lbl.setText(f"{val}%")
        self.model.user_scale_offset = val / 100.0
        if self.pet_window:
            if hasattr(self.pet_window, "check_resize_for_growth"):
                self.pet_window.check_resize_for_growth()
            self.pet_window.update()

    def reject(self):
        # 取消时回滚缩放至打开面板前的初始尺寸
        self.model.user_scale_offset = getattr(self, "_initial_scale", 1.0)
        if self.pet_window:
            if hasattr(self.pet_window, "check_resize_for_growth"):
                self.pet_window.check_resize_for_growth()
            self.pet_window.update()
        super().reject()

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

        new_ct = self.cb_click_through.isChecked()
        if self.pet_window and getattr(self.pet_window, "click_through", False) != new_ct:
            self.pet_window.set_click_through(new_ct)

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
            if getattr(sys, "frozen", False):
                app_path = f'"{sys.executable}"'
            else:
                main_py = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "main.py"))
                app_path = f'"{sys.executable}" "{main_py}"'
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
