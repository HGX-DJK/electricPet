import os
import json
import time
from PyQt6.QtCore import Qt, QTimer, QPoint, QRectF
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QTextEdit,
    QPushButton, QGraphicsDropShadowEffect, QApplication, QFrame
)
from PyQt6.QtGui import QFont, QColor, QPainter, QBrush, QPen, QCursor
from pet.audio import sound_manager

# 便签柔和马卡龙色彩主题
MEMO_THEMES = {
    "yellow": {
        "name": "奶杏黄",
        "bg": "#FEFCE8",
        "border": "#FDE047",
        "header": "#FEF08A",
        "text": "#1E293B",
        "sub": "#854D0E"
    },
    "pink": {
        "name": "落樱粉",
        "bg": "#FFF1F2",
        "border": "#FECDD3",
        "header": "#FFE4E6",
        "text": "#1E293B",
        "sub": "#9F1239"
    },
    "green": {
        "name": "薄荷绿",
        "bg": "#F0FDF4",
        "border": "#BBF7D0",
        "header": "#DCFCE7",
        "text": "#1E293B",
        "sub": "#166534"
    },
    "blue": {
        "name": "晴空蓝",
        "bg": "#EFF6FF",
        "border": "#BFDBFE",
        "header": "#DBEAFE",
        "text": "#1E293B",
        "sub": "#1E40AF"
    }
}

class PetStickyNote(QWidget):
    """
    桌面随手便签 (桌面便利贴)
    支持待办备忘、随时灵感记录、多款马卡龙便签配色、自动持久化保存与一键时间戳
    """
    def __init__(self, model, pet_window, parent=None):
        super().__init__(parent, Qt.WindowType.FramelessWindowHint | Qt.WindowType.Tool | Qt.WindowType.WindowStaysOnTopHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.model = model
        self.pet_window = pet_window

        self.memo_file = os.path.join(self.model.app_dir, "memo_data.json")
        self.current_theme = "yellow"
        self.is_pinned = True
        self.is_dragging = False
        self.drag_start = QPoint()

        # 防抖自动保存定时器 (输入停顿 500ms 后静默写入)
        self.save_timer = QTimer(self)
        self.save_timer.setSingleShot(True)
        self.save_timer.timeout.connect(self.save_data)

        self._init_ui()
        self.load_data()

    def _init_ui(self):
        self.resize(260, 290)
        self.setMinimumSize(220, 200)

        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(10, 10, 10, 10)

        # 核心卡片容器
        self.card = QFrame(self)
        self.card.setObjectName("MemoCard")
        
        # 柔和便签投影
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(15, 23, 42, 45))
        shadow.setOffset(0, 6)
        self.card.setGraphicsEffect(shadow)

        card_layout = QVBoxLayout(self.card)
        card_layout.setContentsMargins(12, 10, 12, 10)
        card_layout.setSpacing(8)

        # 1. 顶部标题控制栏
        header = QHBoxLayout()
        header.setSpacing(6)

        title_icon = QLabel("📝")
        title_icon.setFont(QFont("Segoe UI Emoji", 12))
        header.addWidget(title_icon)

        self.title_lbl = QLabel("随手便签")
        self.title_lbl.setFont(QFont("Microsoft YaHei UI", 10, QFont.Weight.Bold))
        header.addWidget(self.title_lbl)

        header.addStretch()

        # 时间戳按钮
        self.btn_time = QPushButton("🕒")
        self.btn_time.setFixedSize(24, 24)
        self.btn_time.setToolTip("插入当前时间戳")
        self.btn_time.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_time.clicked.connect(self._insert_timestamp)
        header.addWidget(self.btn_time)

        # 清空按钮
        self.btn_clear = QPushButton("🗑️")
        self.btn_clear.setFixedSize(24, 24)
        self.btn_clear.setToolTip("清空便签内容")
        self.btn_clear.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_clear.clicked.connect(self._clear_content)
        header.addWidget(self.btn_clear)

        # 置顶按钮
        self.btn_pin = QPushButton("📌")
        self.btn_pin.setFixedSize(24, 24)
        self.btn_pin.setToolTip("切换置顶显示")
        self.btn_pin.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_pin.clicked.connect(self._toggle_pin)
        header.addWidget(self.btn_pin)

        # 关闭按钮
        self.btn_close = QPushButton("✕")
        self.btn_close.setFixedSize(24, 24)
        self.btn_close.setToolTip("收起便签 (自动保存)")
        self.btn_close.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_close.clicked.connect(self.hide_memo)
        header.addWidget(self.btn_close)

        card_layout.addLayout(header)

        # 2. 正文输入框
        self.text_edit = QTextEdit(self)
        self.text_edit.setPlaceholderText("在这里记下待办、灵感闪念或备忘...\n(自动即时保存，关闭不丢失)")
        self.text_edit.setFont(QFont("Microsoft YaHei UI", 10))
        self.text_edit.textChanged.connect(self._on_text_changed)
        card_layout.addWidget(self.text_edit)

        # 3. 底部工具栏 (字数统计与主题色切换)
        bottom_layout = QHBoxLayout()
        bottom_layout.setSpacing(6)

        self.char_lbl = QLabel("0 字")
        self.char_lbl.setFont(QFont("Microsoft YaHei UI", 9))
        bottom_layout.addWidget(self.char_lbl)

        bottom_layout.addStretch()

        # 4 个马卡龙色圆点
        for t_key in ["yellow", "pink", "green", "blue"]:
            dot_btn = QPushButton()
            dot_btn.setFixedSize(14, 14)
            dot_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            dot_color = MEMO_THEMES[t_key]["header"]
            dot_border = MEMO_THEMES[t_key]["border"]
            dot_btn.setStyleSheet(f"""
                QPushButton {{
                    background-color: {dot_color};
                    border: 1.5px solid {dot_border};
                    border-radius: 7px;
                }}
                QPushButton:hover {{
                    border: 2px solid #334155;
                }}
            """)
            dot_btn.clicked.connect(lambda checked, k=t_key: self.set_theme(k))
            bottom_layout.addWidget(dot_btn)

        card_layout.addLayout(bottom_layout)
        main_layout.addWidget(self.card)

        self.apply_theme_style()

    def apply_theme_style(self):
        """根据当前选定主题刷新便签整体样式"""
        theme = MEMO_THEMES.get(self.current_theme, MEMO_THEMES["yellow"])
        bg = theme["bg"]
        border = theme["border"]
        text_col = theme["text"]
        sub_col = theme["sub"]

        self.card.setStyleSheet(f"""
            QFrame#MemoCard {{
                background-color: {bg};
                border: 1.5px solid {border};
                border-radius: 16px;
            }}
        """)
        self.title_lbl.setStyleSheet(f"color: {sub_col}; background: transparent; border: none;")
        self.char_lbl.setStyleSheet(f"color: {sub_col}; background: transparent; border: none; font-size: 10px;")

        btn_css = f"""
            QPushButton {{
                background-color: rgba(255, 255, 255, 0.7);
                border: 1px solid {border};
                border-radius: 12px;
                color: {sub_col};
                font-size: 11px;
                font-weight: bold;
                padding: 0px;
            }}
            QPushButton:hover {{
                background-color: #FFFFFF;
                border-color: {sub_col};
            }}
        """
        self.btn_time.setStyleSheet(btn_css)
        self.btn_clear.setStyleSheet(btn_css)
        self.btn_pin.setStyleSheet(btn_css)
        self.btn_close.setStyleSheet(btn_css)

        self.text_edit.setStyleSheet(f"""
            QTextEdit {{
                background-color: transparent;
                border: none;
                color: {text_col};
                font-family: "Microsoft YaHei UI";
                font-size: 13px;
                line-height: 1.4;
                padding: 2px;
            }}
        """)

    def set_theme(self, theme_key):
        if theme_key in MEMO_THEMES:
            self.current_theme = theme_key
            self.apply_theme_style()
            self.save_data()

    def _insert_timestamp(self):
        t_str = time.strftime("[%m-%d %H:%M] ")
        cursor = self.text_edit.textCursor()
        cursor.insertText(t_str)
        sound_manager.play("click")

    def _clear_content(self):
        if self.text_edit.toPlainText().strip():
            self.text_edit.clear()
            sound_manager.play("pop")
            self.save_data()

    def _toggle_pin(self):
        self.is_pinned = not self.is_pinned
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, self.is_pinned)
        self.show()
        self.btn_pin.setText("📌" if self.is_pinned else "📍")
        sound_manager.play("click")
        self.save_data()

    def _on_text_changed(self):
        count = len(self.text_edit.toPlainText())
        self.char_lbl.setText(f"{count} 字")
        # 500ms 防抖保存
        self.save_timer.start(500)

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            # 顶部拖拽
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
            self.save_data()
        super().mouseReleaseEvent(event)

    def show_memo(self):
        """展示便签，若首次打开则智能靠齐宠物右侧"""
        if not self.isVisible():
            if self.x() <= 10 and self.y() <= 10:
                # 初始自动贴靠在宠物右侧或左侧
                screen = QApplication.screenAt(self.pet_window.geometry().center())
                avail = screen.availableGeometry() if screen else QApplication.primaryScreen().availableGeometry()
                target_x = self.pet_window.x() + self.pet_window.width() + 12
                if target_x + self.width() > avail.right():
                    target_x = self.pet_window.x() - self.width() - 12
                target_y = max(avail.top() + 20, min(self.pet_window.y(), avail.bottom() - self.height() - 20))
                self.move(int(target_x), int(target_y))
            self.show()
            self.raise_()
            self.activateWindow()
            sound_manager.play("pop")

    def hide_memo(self):
        self.save_data()
        self.hide()

    def toggle_memo(self):
        if self.isVisible():
            self.hide_memo()
        else:
            self.show_memo()

    def load_data(self):
        """从本地磁盘读取便签内容与位置"""
        try:
            if os.path.exists(self.memo_file):
                with open(self.memo_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                self.text_edit.setPlainText(data.get("content", ""))
                self.current_theme = data.get("theme", "yellow")
                self.is_pinned = data.get("pinned", True)
                self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, self.is_pinned)
                self.btn_pin.setText("📌" if self.is_pinned else "📍")

                saved_x = data.get("x")
                saved_y = data.get("y")
                if saved_x is not None and saved_y is not None:
                    # 屏幕可见校验
                    screen = QApplication.primaryScreen()
                    avail = screen.availableGeometry() if screen else None
                    if avail:
                        clamped_x = max(avail.left(), min(int(saved_x), avail.right() - 200))
                        clamped_y = max(avail.top(), min(int(saved_y), avail.bottom() - 150))
                        self.move(int(clamped_x), int(clamped_y))
                    else:
                        self.move(int(saved_x), int(saved_y))

                self.apply_theme_style()
                count = len(self.text_edit.toPlainText())
                self.char_lbl.setText(f"{count} 字")
        except Exception:
            pass

    def save_data(self):
        """持久化保存便签至本地磁盘"""
        try:
            data = {
                "content": self.text_edit.toPlainText(),
                "theme": self.current_theme,
                "pinned": self.is_pinned,
                "x": self.x(),
                "y": self.y(),
                "width": self.width(),
                "height": self.height(),
                "updated_at": time.time()
            }
            with open(self.memo_file, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    def hideEvent(self, event):
        self.save_data()
        super().hideEvent(event)

    def closeEvent(self, event):
        self.save_data()
        super().closeEvent(event)
