from pet.theme import Alpha, Palette
import os
import json
import time
from PyQt6.QtCore import Qt, QTimer, QPoint, QRectF, QEvent
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QTextEdit,
    QPushButton, QGraphicsDropShadowEffect, QApplication, QFrame,
    QSizeGrip, QMessageBox
)
from PyQt6.QtGui import QFont, QColor, QPainter, QBrush, QPen, QCursor
from pet.audio import sound_manager
from pet.console_safe import safe_print

# 便签柔和马卡龙色彩主题
MEMO_THEMES = {
    "yellow": {
        "name": "奶杏黄",
        "bg": Palette.glow_warm,
        "border": Palette.yellow_300,
        "header": Palette.yellow_200,
        "text": Palette.slate_800,
        "sub": Palette.amber_800
    },
    "peach": {
        "name": "暖蜜桃",
        "bg": Palette.glow_soft,
        "border": Palette.orange_300,
        "header": Palette.orange_100,
        "text": Palette.slate_800,
        "sub": Palette.orange_700
    },
    "pink": {
        "name": "落樱粉",
        "bg": Palette.rose_50,
        "border": Palette.rose_200,
        "header": Palette.rose_100,
        "text": Palette.slate_800,
        "sub": Palette.rose_900
    },
    "green": {
        "name": "薄荷绿",
        "bg": Palette.emerald_50,
        "border": Palette.mint_200,
        "header": Palette.mint_100,
        "text": Palette.slate_800,
        "sub": Palette.mint_800
    },
    "blue": {
        "name": "晴空蓝",
        "bg": Palette.blue_50,
        "border": Palette.blue_200,
        "header": Palette.blue_100,
        "text": Palette.slate_800,
        "sub": Palette.blue_800
    },
    "cyber": {
        "name": "赛博暗夜",
        "bg": Palette.ink,
        "border": Palette.sky_500,
        "header": Palette.slate_800,
        "text": Palette.slate_50,
        "sub": Palette.sky_400
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
        self.btn_time.setToolTip("插入当前时间戳 (Ctrl + T)")
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
        self.btn_close.setToolTip("收起便签 (Esc，自动保存)")
        self.btn_close.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_close.clicked.connect(self.hide_memo)
        header.addWidget(self.btn_close)

        card_layout.addLayout(header)

        # 2. 正文输入框
        self.text_edit = QTextEdit(self)
        self.text_edit.setPlaceholderText("在这里记下待办、灵感闪念或备忘...\n(自动即时保存，关闭不丢失)")
        self.text_edit.setFont(QFont("Microsoft YaHei UI", 10))
        self.text_edit.textChanged.connect(self._on_text_changed)
        self.text_edit.installEventFilter(self)
        card_layout.addWidget(self.text_edit)

        # 3. 底部工具栏 (字数统计与主题色切换)
        bottom_layout = QHBoxLayout()
        bottom_layout.setSpacing(6)

        self.char_lbl = QLabel("0 字")
        self.char_lbl.setFont(QFont("Microsoft YaHei UI", 9))
        bottom_layout.addWidget(self.char_lbl)

        bottom_layout.addStretch()

        # 6 个主题色圆点 (支持悬浮提示，含全新赛博暗夜)
        self.theme_dots = {}
        for t_key in ["yellow", "peach", "pink", "green", "blue", "cyber"]:
            dot_btn = QPushButton()
            dot_btn.setFixedSize(14, 14)
            dot_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            dot_btn.setToolTip(f"切换主题: {MEMO_THEMES[t_key]['name']}")
            dot_btn.clicked.connect(lambda checked, k=t_key: self.set_theme(k))
            self.theme_dots[t_key] = dot_btn
            bottom_layout.addWidget(dot_btn)

        # 右下角无缝调整大小手柄
        grip = QSizeGrip(self)
        grip.setFixedSize(12, 12)
        grip.setStyleSheet("background: transparent;")
        bottom_layout.addWidget(grip)

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
        is_dark = (self.current_theme == "cyber")

        self.card.setStyleSheet(f"""
            QFrame#MemoCard {{
                background-color: {bg};
                border: 1.5px solid {border};
                border-radius: 16px;
            }}
        """)
        self.title_lbl.setStyleSheet(f"color: {sub_col}; background: transparent; border: none;")
        self.char_lbl.setStyleSheet(f"color: {sub_col}; background: transparent; border: none; font-size: 10px;")

        btn_bg = Alpha.slate_800_85 if is_dark else Alpha.white_70
        btn_hover = Alpha.sky_500_25 if is_dark else Palette.white
        btn_pressed = Alpha.slate_900_95 if is_dark else Alpha.black_8

        btn_css = f"""
            QPushButton {{
                background-color: {btn_bg};
                border: 1px solid {border};
                border-radius: 12px;
                color: {sub_col};
                font-size: 11px;
                font-weight: bold;
                padding: 0px;
            }}
            QPushButton:hover {{
                background-color: {btn_hover};
                border-color: {sub_col};
            }}
            QPushButton:pressed {{
                background-color: {btn_pressed};
            }}
        """
        self.btn_time.setStyleSheet(btn_css)
        self.btn_clear.setStyleSheet(btn_css)
        self.btn_pin.setStyleSheet(btn_css)
        self.btn_close.setStyleSheet(btn_css)

        sb_handle = Palette.sky_500 if is_dark else Alpha.black_15
        sb_hover = Palette.sky_400 if is_dark else Alpha.black_25

        self.text_edit.setStyleSheet(f"""
            QTextEdit {{
                background-color: transparent;
                border: none;
                color: {text_col};
                font-family: "Microsoft YaHei UI";
                font-size: 13px;
                padding: 2px;
            }}
            QScrollBar:vertical {{
                width: 6px;
                background: transparent;
                margin: 2px 0;
            }}
            QScrollBar::handle:vertical {{
                background: {sb_handle};
                border-radius: 3px;
                min-height: 30px;
            }}
            QScrollBar::handle:vertical:hover {{
                background: {sb_hover};
            }}
            QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
                height: 0px;
            }}
            QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical {{
                background: transparent;
            }}
        """)

        # 更新色块圆点选中指示器
        if hasattr(self, "theme_dots"):
            for t_key, dot_btn in self.theme_dots.items():
                dot_color = MEMO_THEMES[t_key]["header"]
                dot_border = MEMO_THEMES[t_key]["border"]
                border_str = f"2px solid {Palette.slate_700}" if t_key == self.current_theme else f"2px solid {dot_border}"
                dot_btn.setStyleSheet(f"""
                    QPushButton {{
                        background-color: {dot_color};
                        border: {border_str};
                        border-radius: 7px;
                    }}
                    QPushButton:hover {{
                        border: 2px solid {Palette.slate_700};
                    }}
                """)

    def set_theme(self, theme_key):
        if theme_key in MEMO_THEMES:
            self.current_theme = theme_key
            self.apply_theme_style()
            self.save_data()
            sound_manager.play("click")

    def eventFilter(self, watched, event):
        if watched == self.text_edit and event.type() == QEvent.Type.KeyPress:
            if event.key() == Qt.Key.Key_Escape:
                self.hide_memo()
                return True
            if event.modifiers() & Qt.KeyboardModifier.ControlModifier:
                if event.key() == Qt.Key.Key_S:
                    self.save_data()
                    sound_manager.play("click")
                    return True
                elif event.key() == Qt.Key.Key_T:
                    self._insert_timestamp()
                    return True
        return super().eventFilter(watched, event)

    def keyPressEvent(self, event):
        if event.key() == Qt.Key.Key_Escape:
            self.hide_memo()
            event.accept()
            return
        if event.modifiers() & Qt.KeyboardModifier.ControlModifier:
            if event.key() == Qt.Key.Key_S:
                self.save_data()
                sound_manager.play("click")
                event.accept()
                return
            elif event.key() == Qt.Key.Key_T:
                self._insert_timestamp()
                event.accept()
                return
        super().keyPressEvent(event)

    def _insert_timestamp(self):
        t_str = time.strftime("[%m-%d %H:%M] ")
        cursor = self.text_edit.textCursor()
        cursor.insertText(t_str)
        sound_manager.play("click")

    def _clear_content(self):
        cur_text = self.text_edit.toPlainText().strip()
        if not cur_text:
            return
        reply = QMessageBox.question(
            self,
            "清空便签",
            "确定要清空当前的全部便签记录吗？此操作不可撤销哦~ 🐾",
            QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No
        )
        if reply == QMessageBox.StandardButton.Yes:
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
            # 限制仅在顶部标题栏区域（Y <= 45）拖拽窗口，避免干扰正文文本选择
            if event.position().y() <= 45:
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

    @staticmethod
    def _to_int(value, field=""):
        """把存档里的数值字段安全地转成 int；非法值返回 None 并留日志。

        ⚠️ 存档是磁盘上的外部数据，随时可能被改坏（手改 JSON、写入时被中断、
        旧版本残留的格式……）。直接 int() 抛 ValueError 会把整个加载流程带崩。
        """
        if value is None:
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            safe_print(f"[Memo] 便签存档字段 {field!r} 不是合法数字，已忽略: {value!r}")
            return None

    def load_data(self):
        """从本地磁盘读取便签内容与位置

        ⚠️ 以前这里是「一个 int() 抛 ValueError → 整个 try 块中止 →
        except Exception: pass 静默吞掉」。后果是：便签主题样式不生效、
        字数显示 0、窗口位置尺寸不恢复，而且**连一行日志都没有**。
        现在改成逐字段兜底：单个字段坏了只影响它自己，其余照常生效。
        """
        try:
            if not os.path.exists(self.memo_file):
                return
            with open(self.memo_file, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            safe_print(f"[Memo] 读取便签存档失败: {e}")
            return

        # ---------- 内容与状态：必须无条件生效 ----------
        self.text_edit.setPlainText(data.get("content", ""))
        self.current_theme = data.get("theme", "yellow")
        self.is_pinned = data.get("pinned", True)
        self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, self.is_pinned)
        self.btn_pin.setText("📌" if self.is_pinned else "📍")

        # ---------- 位置：单个字段非法就整块跳过，不影响其它 ----------
        saved_x = self._to_int(data.get("x"), "x")
        saved_y = self._to_int(data.get("y"), "y")
        if saved_x is not None and saved_y is not None:
            # 屏幕可见校验
            screen = QApplication.primaryScreen()
            avail = screen.availableGeometry() if screen else None
            if avail:
                clamped_x = max(avail.left(), min(saved_x, avail.right() - 200))
                clamped_y = max(avail.top(), min(saved_y, avail.bottom() - 150))
                self.move(clamped_x, clamped_y)
            else:
                self.move(saved_x, saved_y)

        # ---------- 尺寸 ----------
        saved_w = self._to_int(data.get("width"), "width")
        saved_h = self._to_int(data.get("height"), "height")
        if saved_w and saved_h:
            self.resize(max(220, saved_w), max(200, saved_h))

        # ---------- 主题样式与字数：永远要执行 ----------
        self.apply_theme_style()
        count = len(self.text_edit.toPlainText())
        self.char_lbl.setText(f"{count} 字")

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
            # 原子写：先写同目录的 .tmp，再 os.replace 覆盖正式存档。
            #
            # 为什么不直接覆盖写：便签是 500ms 防抖自动保存（打字时约 2 次/秒），
            # 直接 open(...,"w") 会**先清空原文件**再写 —— 写到一半崩了/断电了，
            # 便签就只剩半截 JSON，重启后内容全丢。pet/model.py 的存档
            # 早就是用 .tmp + os.replace 写的，这里对齐同一套写法。
            tmp_file = self.memo_file + ".tmp"
            try:
                with open(tmp_file, "w", encoding="utf-8") as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)
                    f.flush()
                    os.fsync(f.fileno())
                os.replace(tmp_file, self.memo_file)
            except Exception:
                # 清理半截临时文件，别把垃圾留在存档目录里
                try:
                    if os.path.exists(tmp_file):
                        os.remove(tmp_file)
                except Exception:
                    pass
                raise
        except Exception as e:
            # ⚠️ 以前这里是 except Exception: pass —— 写盘失败完全静默，
            # 用户以为便签存上了，其实重启就没了。至少要留一行日志。
            safe_print(f"[Memo] 保存便签失败: {e}")

    def hideEvent(self, event):
        self.save_data()
        super().hideEvent(event)

    def closeEvent(self, event):
        self.save_data()
        super().closeEvent(event)
