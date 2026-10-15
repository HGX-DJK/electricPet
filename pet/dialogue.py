import time
import random
from PyQt6.QtCore import Qt, QTimer, QPropertyAnimation, QEasingCurve, QRectF, QPointF
from PyQt6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QFrame,
    QGraphicsDropShadowEffect, QApplication
)
from PyQt6.QtGui import QFont, QColor, QPainter, QPainterPath, QBrush, QPen

class SpeechBalloonCard(QFrame):
    """
    可爱的卡通气泡卡片：纯白温润背景、平滑圆角、指示指向宠物身体的卡通气泡小尖角
    支持动态指向：
    - "bottom": 气泡位于宠物上方，小尖角在底部指向下方宠物
    - "top": 气泡位于宠物下方（如宠物停在屏幕最顶部时），小尖角在顶部指向上方宠物
    - "none": 侧边停靠，纯圆角胶囊卡片
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.tail_position = "bottom"  # "bottom", "top", "none"
        self.tail_x = None             # None 表示居中，或指定具体的局部 X 坐标

    def set_tail_mode(self, position: str, tail_x: float = None):
        changed = False
        if self.tail_position != position:
            self.tail_position = position
            changed = True
        if self.tail_x != tail_x:
            self.tail_x = tail_x
            changed = True
        if changed:
            self.update()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        rect = self.rect()
        w = float(rect.width())
        h = float(rect.height())

        tail_height = 8.0
        tail_width = 14.0
        radius = 16.0

        # 计算尖角在卡片内部的水平对齐点
        if self.tail_x is not None:
            tail_center_x = max(radius + tail_width / 2.0, min(w - radius - tail_width / 2.0, float(self.tail_x)))
        else:
            tail_center_x = w / 2.0

        tail_left = tail_center_x - tail_width / 2.0
        tail_right = tail_center_x + tail_width / 2.0

        path = QPainterPath()

        if self.tail_position == "bottom":
            body_h = h - tail_height
            body_rect = QRectF(1.0, 1.0, w - 2.0, body_h - 1.0)
            path.addRoundedRect(body_rect, radius, radius)

            tail_path = QPainterPath()
            tail_path.moveTo(tail_left, body_h - 1.0)
            tail_path.lineTo(tail_center_x, h - 1.5)
            tail_path.lineTo(tail_right, body_h - 1.0)
            tail_path.closeSubpath()
            united_path = path.united(tail_path)

        elif self.tail_position == "top":
            body_y = tail_height + 1.0
            body_h = h - tail_height - 2.0
            body_rect = QRectF(1.0, body_y, w - 2.0, body_h)
            path.addRoundedRect(body_rect, radius, radius)

            tail_path = QPainterPath()
            tail_path.moveTo(tail_left, body_y)
            tail_path.lineTo(tail_center_x, 1.5)
            tail_path.lineTo(tail_right, body_y)
            tail_path.closeSubpath()
            united_path = path.united(tail_path)

        else:  # "none"
            body_rect = QRectF(1.0, 1.0, w - 2.0, h - 2.0)
            path.addRoundedRect(body_rect, radius, radius)
            united_path = path

        # 纯白温润背景 + 细腻微浅灰边框
        painter.setBrush(QBrush(QColor(255, 255, 255, 252)))
        painter.setPen(QPen(QColor(226, 232, 240, 240), 1.5))
        painter.drawPath(united_path)

        # 右下角专属超淡萌爪水印印章 (Watermark Paw Stamp)
        wm_x = w - 25.0
        wm_y = (h - tail_height - 16.0) if self.tail_position == "bottom" else (h - 18.0)
        wm_color = QColor(203, 213, 225, 95)
        painter.setBrush(QBrush(wm_color))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(wm_x - 5, wm_y - 4, 10, 8))
        painter.drawEllipse(QRectF(wm_x - 6, wm_y - 8, 3.2, 3.2))
        painter.drawEllipse(QRectF(wm_x - 1.5, wm_y - 9.5, 3.2, 3.2))
        painter.drawEllipse(QRectF(wm_x + 3, wm_y - 8, 3.2, 3.2))

class SpeechBubbleWidget(QWidget):
    """
    全新独立浮动的超萌卡通对话气泡窗口
    完全脱离宠物本体窗口，浮于头顶上方，彻底避免耳朵与头饰遮挡！
    支持自适应文本换行、柔和渐变投影、平滑淡入淡出与点击即时关闭
    """
    def __init__(self, parent=None):
        super().__init__(parent, Qt.WindowType.FramelessWindowHint | Qt.WindowType.Tool | Qt.WindowType.WindowStaysOnTopHint)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        self.setFixedWidth(260)

        self._current_anim = None
        self.hide_timer = QTimer(self)
        self.hide_timer.setSingleShot(True)
        self.hide_timer.timeout.connect(self._do_fade_out)

        self._init_ui()

    def _init_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(8, 8, 8, 8)

        # 气泡主卡片（自绘带指向尾巴的温润圆角多边形）
        self.card = SpeechBalloonCard(self)

        # 柔和高阶环境阴影
        shadow = QGraphicsDropShadowEffect(self)
        shadow.setBlurRadius(20)
        shadow.setColor(QColor(15, 23, 42, 35))
        shadow.setOffset(0, 4)
        self.card.setGraphicsEffect(shadow)

        self.card_layout = QVBoxLayout(self.card)
        self.card_layout.setContentsMargins(14, 11, 14, 18)
        self.card_layout.setSpacing(6)

        # 特殊标签栏（仅在重要提醒如健康关怀、成长喜讯时展示，日常闲聊自动隐藏以保持极简萌感）
        self.top_bar_widget = QWidget()
        top_bar = QHBoxLayout(self.top_bar_widget)
        top_bar.setContentsMargins(0, 0, 0, 0)
        top_bar.setSpacing(4)

        self.badge_lbl = QLabel("")
        self.badge_lbl.setFont(QFont("Microsoft YaHei UI", 8, QFont.Weight.Bold))
        self.badge_lbl.setStyleSheet("""
            background-color: #EEF2FF;
            color: #4F46E5;
            padding: 2px 7px;
            border-radius: 6px;
        """)
        top_bar.addWidget(self.badge_lbl)
        top_bar.addStretch()

        self.card_layout.addWidget(self.top_bar_widget)
        self.top_bar_widget.hide()

        # 气泡文本内容
        self.text_lbl = QLabel("")
        self.text_lbl.setFont(QFont("Microsoft YaHei UI", 10))
        self.text_lbl.setWordWrap(True)
        self.text_lbl.setStyleSheet("color: #1E293B; line-height: 1.45; background: transparent;")
        self.card_layout.addWidget(self.text_lbl)

        main_layout.addWidget(self.card)

    def show_message(self, text, duration=5.0, badge="🐾 波可"):
        self.hide_timer.stop()
        self.text_lbl.setText(text)

        # 仅针对特殊系统提示显示小标签，普通闲聊或默认波可标签保持极简气泡外观
        if badge and badge not in ("🐾 波可", ""):
            self.badge_lbl.setText(badge)
            if "健康" in badge:
                self.badge_lbl.setStyleSheet("background-color: #ECFDF5; color: #059669; padding: 2px 7px; border-radius: 6px;")
            elif "喜讯" in badge or "成长" in badge:
                self.badge_lbl.setStyleSheet("background-color: #FEF3C7; color: #D97706; padding: 2px 7px; border-radius: 6px;")
            else:
                self.badge_lbl.setStyleSheet("background-color: #EEF2FF; color: #4F46E5; padding: 2px 7px; border-radius: 6px;")
            self.top_bar_widget.show()
        else:
            self.top_bar_widget.hide()

        self.adjustSize()

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

        # 启动自动隐藏倒计时
        self.hide_timer.start(int(duration * 1000))

    def dismiss(self):
        self.hide_timer.stop()
        self._do_fade_out()

    def _do_fade_out(self):
        if not self.isVisible():
            return
        anim = QPropertyAnimation(self, b"windowOpacity", self)
        anim.setDuration(220)
        anim.setStartValue(self.windowOpacity())
        anim.setEndValue(0.0)
        anim.setEasingCurve(QEasingCurve.Type.InCubic)
        anim.finished.connect(self.hide)
        anim.start()
        self._current_anim = anim

    def mousePressEvent(self, event):
        # 点击气泡任意位置快速关闭
        self.dismiss()
        super().mousePressEvent(event)

    def sync_position(self, pet_window, dock_widget=None):
        """精准根据宠物与快捷岛坐标对齐，紧贴头顶或足底，绝对不乱飘移或遮挡"""
        if not self.isVisible():
            return

        screen = QApplication.screenAt(pet_window.geometry().center())
        if not screen:
            screen = QApplication.primaryScreen()
        avail = screen.availableGeometry()

        pet_head_y = pet_window.get_head_screen_y()
        pet_foot_y = pet_window.get_foot_screen_y()
        pet_center_x = pet_window.get_center_screen_x()
        scale = pet_window.width() / 220.0

        self.adjustSize()
        bubble_w = self.width()
        bubble_h = self.height()

        # 优先度 1：头顶上方（常规状态）
        # 若快捷岛展开且位于宠物头部上方，则气泡停在快捷岛上方
        dock_is_above = bool(dock_widget and dock_widget.isVisible() and dock_widget.y() < pet_head_y)
        if dock_is_above:
            target_y_above = dock_widget.y() - bubble_h + 6
        else:
            target_y_above = pet_head_y - bubble_h + 4

        # 优先度 2：宠物正下方（当宠物停在屏幕最顶端、上方空间不足时，气泡居中沉到底部指向宠物腹部）
        dock_is_below = bool(dock_widget and dock_widget.isVisible() and dock_widget.y() >= pet_foot_y - 10)
        if dock_is_below:
            target_y_below = dock_widget.y() + dock_widget.height() - 4
        else:
            target_y_below = pet_foot_y + 6

        # 智能判定最佳停靠区域
        if target_y_above >= avail.top() + 8:
            # 上方空间充裕：默认置于头顶
            target_y = target_y_above
            target_x = pet_center_x - bubble_w / 2.0
            target_x = max(avail.left() + 10, min(target_x, avail.right() - bubble_w - 10))
            tail_mode = "bottom"
        elif target_y_below + bubble_h <= avail.bottom() - 8:
            # 顶部空间狭窄，但下方空间充裕：紧随宠物居中置于足底下方
            target_y = target_y_below
            target_x = pet_center_x - bubble_w / 2.0
            target_x = max(avail.left() + 10, min(target_x, avail.right() - bubble_w - 10))
            tail_mode = "top"
        else:
            # 极特殊极限小屏幕（上下空间均不足）：贴在宠物身旁（使用身体真实视觉半径，绝不飘逸出透明窗口）
            cat_radius = int(58 * scale)
            tail_mode = "none"
            # 优先右侧
            if pet_center_x + cat_radius + bubble_w + 10 <= avail.right():
                target_x = pet_center_x + cat_radius + 6
                target_y = max(avail.top() + 10, min(pet_y + 10, avail.bottom() - bubble_h - 10))
            elif pet_center_x - cat_radius - bubble_w - 10 >= avail.left():
                target_x = pet_center_x - cat_radius - bubble_w - 6
                target_y = max(avail.top() + 10, min(pet_y + 10, avail.bottom() - bubble_h - 10))
            else:
                target_x = max(avail.left() + 10, min(pet_center_x - bubble_w / 2.0, avail.right() - bubble_w - 10))
                target_y = max(avail.top() + 10, min(pet_y, avail.bottom() - bubble_h - 10))

        # 根据 tail_mode 动态更新卡片内边距与尖角布局
        if tail_mode == "top":
            self.card_layout.setContentsMargins(14, 18, 14, 11)
        elif tail_mode == "bottom":
            self.card_layout.setContentsMargins(14, 11, 14, 18)
        else:
            self.card_layout.setContentsMargins(14, 14, 14, 14)

        self.adjustSize()
        bubble_h = self.height()
        if tail_mode == "bottom" and not dock_is_above:
            target_y = pet_head_y - bubble_h + 4

        # 计算尖角在卡片局部坐标系中的 X 坐标 (对准宠物中心)
        card_offset_x = self.card.x() if hasattr(self, "card") and self.card else 8
        local_tail_x = pet_center_x - target_x - card_offset_x

        self.card.set_tail_mode(tail_mode, local_tail_x)
        self.move(int(target_x), int(target_y))

class DialogueManager:
    """
    智能对话与气泡提醒系统
    管理时间问候、健康提醒（喝水、久坐、护眼）、状态反馈与气泡控制
    """
    def __init__(self, model, pet_window=None):
        self.model = model
        self.pet_window = pet_window
        self.bubble = SpeechBubbleWidget()

        self.last_random_chat_time = time.time()
        self.last_health_reminder_time = time.time()

        # 随机闲聊语录库
        self.random_chats = [
            "今天工作/学习辛苦啦，波可一直陪着你呢~ (ฅ'ω'ฅ)",
            "代码写累了吗？写个 bug 玩玩吧... 哎呀不对，是休息一下！",
            "只要心里有阳光，到哪里都是晴天哦~ ☀️",
            "悄悄告诉你：主人是最棒的！加油！💪",
            "在想什么呢？要不要摸摸波可软乎乎的肚皮？",
            "今天的天气也很适合和主人待在一起呢~",
            "哼哼~ 摸我一下，我就送你一整天的好运！🍀",
            "工作再忙，也要记得保持微笑呀！(๑•̀ㅂ•́)و✧"
        ]

        # 初始问候
        self.say(self.get_time_greeting())

    def set_pet_window(self, pet_window):
        self.pet_window = pet_window

    @property
    def is_visible(self):
        return self.bubble.isVisible()

    def get_time_greeting(self):
        hour = time.localtime().tm_hour
        if 5 <= hour < 9:
            return "早上好呀！新的一天开始啦，记得吃一顿元气早餐哦~ 🍳"
        elif 9 <= hour < 11:
            return "上午好！精神饱满地投入工作和学习吧！✨"
        elif 11 <= hour < 14:
            return "中午到啦！午餐时间，吃饱肚子才有力气前行呢~ 🍱"
        elif 14 <= hour < 18:
            return "下午茶时光~ 伸个懒腰，喝口水，休息一下眼睛吧！☕"
        elif 18 <= hour < 22:
            return "傍晚好！辛苦了一整天，好好享受悠闲的晚间时光吧~ 🌙"
        else:
            return "夜深啦，波可提醒你：早点睡觉身体好，熬夜容易脱发哦💤"

    def say(self, text, duration=5.0, badge="🐾 波可"):
        """显示气泡对话，并自动与宠物对齐坐标"""
        # 判断类型选择标签
        if "💧" in text or "👀" in text or "🧘" in text:
            badge = "💧 健康关怀"
        elif "蜕变" in text or "进化" in text or "Lv" in text:
            badge = "🌟 成长喜讯"
        elif "【猜拳】" in text or "掷出" in text:
            badge = "🎮 趣味玩耍"

        self.bubble.show_message(text, duration, badge)
        if self.pet_window:
            dock = getattr(self.pet_window, "dock", None)
            self.bubble.sync_position(self.pet_window, dock)

    def dismiss(self):
        self.bubble.dismiss()

    def sync_position(self):
        if self.pet_window:
            dock = getattr(self.pet_window, "dock", None)
            self.bubble.sync_position(self.pet_window, dock)

    def update(self, delta_time):
        now = time.time()
        # 定期健康关怀与状态提醒
        if not self.bubble.isVisible() and not self.model.is_sleeping:
            # 状态告警优先
            if self.model.hunger < 25 and random.random() < 0.003:
                self.say("肚肚好饿呀...主人能给波可投喂一点小零食吗？🥺")
            elif self.model.cleanliness < 25 and random.random() < 0.003:
                self.say("身上有点灰尘啦，好想洗一个香喷喷的泡泡浴~ 🛁")
            elif self.model.mood < 30 and random.random() < 0.003:
                self.say("波可有点寂寞呢...主人摸摸我或者陪我玩会游戏嘛~")
            elif self.model.is_studying:
                mins = int(self.model.study_time_left // 60)
                if random.random() < 0.002:
                    self.say(f"专注中...加油主人！波可静静陪着你✨ (还剩 {mins} 分钟)")
            # 健康提醒 (每 30 分钟)
            elif self.model.health_reminders and (now - self.last_health_reminder_time > 1800):
                reminders = [
                    "💧 滴答~ 喝水小助手上线！记得喝一口温水滋润喉咙哦~",
                    "👀 眼睛看屏幕有一阵子啦，向远处眺望20秒放松睫状肌吧~",
                    "🧘 站起来活动一下肩膀与手腕，久坐伤身要常走动哦！"
                ]
                self.say(random.choice(reminders), duration=6.5)
                self.last_health_reminder_time = now
            # 普通日常闲聊 (每 3-4 分钟)
            elif (now - self.last_random_chat_time > 200) and random.random() < 0.01:
                self.say(random.choice(self.random_chats))
                self.last_random_chat_time = now

    def render(self, painter, pet_width, pet_height):
        # 气泡已升级为独立浮动窗口，此方法保留为空实现以保持接口完全兼容
        pass
