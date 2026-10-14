import math
import random
import time
from PyQt6.QtCore import Qt, QTimer, QPoint, QRect, QRectF, QPropertyAnimation, QEasingCurve
from PyQt6.QtWidgets import QWidget, QApplication
from PyQt6.QtGui import QPainter, QCursor, QMouseEvent, QScreen

from pet.renderer import PetRenderer
from pet.dialogue import DialogueManager
from pet.menus import QuickActionMenu
from pet.dock import PetCompanionDock
from pet.audio import sound_manager

class PetWindow(QWidget):
    """
    桌面透明无边框宠物主窗口
    实现物理重力、拖拽掉落回弹、屏幕边缘碰撞、自由漫步巡逻与交互触发
    """
    def __init__(self, model):
        super().__init__()
        self.model = model
        self.renderer = PetRenderer(model)
        self.dock = PetCompanionDock(model, self)
        self.dialogue = DialogueManager(model, self)

        # 状态机：IDLE, WALK_LEFT, WALK_RIGHT, DRAGGING, FALLING, BOUNCE, 
        # 及多样动作：STRETCH_YAWN, WASH_FACE, CHASE_BUTTERFLY, HEAD_BOB_MUSIC, TILT_HEAD, HAPPY_SPIN, DOZE_OFF, DIZZY
        self.state = "IDLE"
        self.facing_left = False
        self.action_timer = 0.0

        # 物理重力与速度参数
        self.vx = 0.0
        self.vy = 0.0
        self.gravity = 1800.0  # 像素/秒^2
        self.bounce_damping = 0.38

        # 拖拽相关
        self.is_dragging = False
        self.drag_start_pos = QPoint()
        self.mouse_press_pos = QPoint()
        self.stroke_distance = 0.0
        self.anchor_y = None

        # 自主漫步AI
        self.walk_target_x = 0
        self.next_action_time = time.time() + 5.0

        # 初始化窗口特性
        self._setup_window_properties()

        # 绑定进化蜕变回调
        self.model.on_evolve = self._on_evolution_triggered

        # 60 FPS 物理与渲染动画定时器 (~16.6ms)
        self.anim_timer = QTimer(self)
        self.anim_timer.timeout.connect(self._on_animation_tick)
        self.anim_timer.start(16)
        self.last_tick_time = time.time()

        # 1秒宠物属性状态流逝定时器
        self.status_timer = QTimer(self)
        self.status_timer.timeout.connect(self._on_status_tick)
        self.status_timer.start(1000)

        # 恢复或初始化宠物在桌面上的摆放位置
        self._init_initial_position()

    def _setup_window_properties(self):
        # 无边框 + 保持置顶 + 工具窗口（不占任务栏）
        flags = Qt.WindowType.FramelessWindowHint | Qt.WindowType.Tool
        if self.model.always_on_top:
            flags |= Qt.WindowType.WindowStaysOnTopHint
        self.setWindowFlags(flags)
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground, True)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating, True)
        self.setMouseTracking(True)
        self.setCursor(Qt.CursorShape.PointingHandCursor)

        # 根据成长与进化缩放因子调整基础大小 (基准 220x220)
        base_size = int(220 * self.model.visual_scale)
        self.resize(base_size, base_size)

    def _init_initial_position(self):
        screen = QApplication.primaryScreen()
        avail = screen.availableGeometry() if screen else None
        if not avail:
            init_x, init_y = 100, 100
        else:
            default_x = avail.right() - self.width() - 80
            default_y = avail.bottom() - self.height()
            if self.model.last_pos_x is not None and self.model.last_pos_y is not None:
                init_x = max(avail.left(), min(int(self.model.last_pos_x), avail.right() - self.width()))
                init_y = max(avail.top(), min(int(self.model.last_pos_y), avail.bottom() - self.height()))
            else:
                init_x, init_y = default_x, default_y

        self.anchor_y = init_y
        self.move(init_x, init_y)

    def apply_model_settings(self):
        """重新应用设置参数（缩放、置顶、物理重力等），安全更新避免窗体句柄重构导致卡死"""
        self.check_resize_for_growth()

        current_ontop = bool(self.windowFlags() & Qt.WindowType.WindowStaysOnTopHint)
        if current_ontop != self.model.always_on_top:
            self.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, self.model.always_on_top)
            self.show()
            if hasattr(self, "dock"):
                self.dock.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, self.model.always_on_top)
                if self.dock.isVisible():
                    self.dock.show()
            if hasattr(self, "dialogue") and hasattr(self.dialogue, "bubble"):
                self.dialogue.bubble.setWindowFlag(Qt.WindowType.WindowStaysOnTopHint, self.model.always_on_top)
                if self.dialogue.bubble.isVisible():
                    self.dialogue.bubble.show()

        # 重力物理模式响应
        if self.model.enable_gravity:
            floor_y = self.get_floor_y()
            if self.y() < floor_y - 3:
                self.state = "FALLING"
        else:
            if self.state == "FALLING":
                self.state = "IDLE"
                self.vy = 0.0
                self.anchor_y = self.y()

    def check_resize_for_growth(self):
        """随投喂成长动态调整窗口大小，并保持足底贴地或贴悬浮锚点"""
        target_size = int(220 * self.model.visual_scale)
        if abs(self.width() - target_size) >= 2:
            old_h = self.height()
            old_x = self.x()
            old_y = self.y()
            diff = target_size - old_h
            self.resize(target_size, target_size)
            if self.state not in ("FALLING", "DRAGGING"):
                new_y = old_y - diff
                self.move(int(old_x - diff / 2), int(new_y))
                self.anchor_y = new_y

    def _on_evolution_triggered(self, new_stage, stage_name):
        """萌宠进化蜕变"""
        self.renderer.trigger_evolution()
        self.check_resize_for_growth()
        self.dialogue.say(f"🌟 奇迹蜕变！波可成长进阶到【{stage_name}】啦！体型变大、神采奕奕~ (✧ω✧)", duration=7.0)


    def get_floor_y(self):
        """获取当前所在屏幕的任务栏/底部地面 Y 坐标"""
        screen = QApplication.screenAt(self.geometry().center())
        if not screen:
            screen = QApplication.primaryScreen()
        avail = screen.availableGeometry()
        return avail.bottom() - self.height()

    # ================= 60 FPS 核心帧循环 =================
    def _on_animation_tick(self):
        now = time.time()
        dt = min(0.05, now - self.last_tick_time)
        self.last_tick_time = now

        # 更新渲染器与粒子
        self.renderer.update_animation(dt, self.state)
        # 更新气泡提醒
        self.dialogue.update(dt)

        # 物理与AI移动处理
        self._update_physics_and_ai(dt)

        # 动态吸附同步伴侣岛与对话气泡位置
        if hasattr(self, "dock") and self.dock.is_dock_visible:
            self.dock.sync_position()
        if hasattr(self, "dialogue") and self.dialogue.is_visible:
            self.dialogue.sync_position()

        # 触发重绘
        self.update()

    def play_action(self, action_name, custom_msg=None, duration=None):
        """播放特定多样化动作动画与对应专属音效、台词气泡"""
        if self.model.is_sleeping:
            self.model.wake_up()
        if self.model.is_studying:
            self.model.stop_focus_timer()

        self.state = action_name

        action_config = {
            "STRETCH_YAWN": {
                "duration": 3.8, "sound": "yawn",
                "lines": [
                    "呼啊~ 伸个大大的懒腰，浑身骨头都舒展开啦！(ฅ'ω'ฅ)",
                    "舒展四肢~ 伸懒腰是最舒服的事啦！🐾",
                    "喵呜~ 伸展一下，整个人都神清气爽！✨"
                ]
            },
            "WASH_FACE": {
                "duration": 4.2, "sound": "purr",
                "lines": [
                    "洗洗脸蛋、擦擦小胡须，做一只讲卫生的精致小可爱！✨",
                    "举起小肉垫擦呀擦~ 呼噜呼噜~ (๑╹◡╹๑)",
                    "梳洗干净，才能保持最萌的颜值面对主人！🐱"
                ]
            },
            "CHASE_BUTTERFLY": {
                "duration": 5.0, "sound": "pop",
                "lines": [
                    "哇！看这只扑闪扑闪的荧光彩蝶！看我无敌飞扑！🦋🐾",
                    "蝴蝶蝴蝶等等我~ 扑腾扑腾！抓到啦！(开心跳跃)",
                    "抓彩蝶大冒险启动！身法轻盈如燕~ 💨"
                ]
            },
            "HEAD_BOB_MUSIC": {
                "duration": 5.2, "sound": "dance",
                "lines": [
                    "戴上潮酷耳机~ 跟随动感节拍一起晃动脑袋！🎶🎧",
                    "动次打次~ 音乐响起来，心情嗨起来！♪(･ω･)ﾉ",
                    "戴着耳机的波可最帅气啦！左摇摇，右晃晃~ 🎵"
                ]
            },
            "TILT_HEAD": {
                "duration": 3.5, "sound": "curious",
                "lines": [
                    "歪头眨巴大眼睛：主人在写什么厉害的代码呀？波可也想康康！👀❓",
                    "好奇心爆棚~ 脑袋往右一歪，萌力瞬间翻倍！(✧ω✧)",
                    "这是在忙什么呢？歪歪头，认真凝望主人~ 🤔"
                ]
            },
            "HAPPY_SPIN": {
                "duration": 3.2, "sound": "sparkle",
                "lines": [
                    "太开心啦！看波可的360度超级旋转大招！原地起飞~ 🌟💃",
                    "快乐转圈圈！金光闪闪，幸运爆棚！✨(ฅ'ω'ฅ)",
                    "芜湖！开心到旋转飞升！耶~ 🎉"
                ]
            },
            "DOZE_OFF": {
                "duration": 4.5, "sound": "snore",
                "lines": [
                    "呼... 困意像小虫子爬上来了... 脑袋一点一点犯迷糊... 💤",
                    "站着站着眼皮就开始打架啦... 呼噜... 🥱",
                    "脑袋点呀点... 小憩一下下就好... 😴"
                ]
            },
            "DIZZY": {
                "duration": 3.6, "sound": "dizzy",
                "lines": [
                    "晕乎乎~ 天上的小星星都在脑袋顶上转圈圈啦！⭐🌀",
                    "眼花缭乱~ 世界怎么开始倒过来了？(@ @)",
                    "脚步轻飘飘... 晕头转向晃悠悠~ 💫"
                ]
            }
        }

        cfg = action_config.get(action_name, {"duration": 3.0, "sound": "meow", "lines": ["波可展示了可爱绝活！✨"]})
        self.action_timer = duration if duration is not None else cfg["duration"]
        if cfg.get("sound"):
            sound_manager.play(cfg["sound"])
        msg = custom_msg or random.choice(cfg["lines"])
        self.dialogue.say(msg, duration=self.action_timer + 0.8)

    def _update_physics_and_ai(self, dt):
        current_x = self.x()
        current_y = self.y()
        floor_y = self.get_floor_y()

        screen = QApplication.screenAt(self.geometry().center())
        if not screen:
            screen = QApplication.primaryScreen()
        avail = screen.availableGeometry()

        if self.anchor_y is None:
            self.anchor_y = current_y
        self.anchor_y = max(avail.top(), min(self.anchor_y, floor_y))

        target_ground_y = floor_y if self.model.enable_gravity else self.anchor_y

        # 1. 拖拽状态中
        if self.state == "DRAGGING":
            return

        # 2. 自由落体中 (仅在重力开启时生效)
        if self.state == "FALLING":
            if not self.model.enable_gravity:
                self.state = "IDLE"
                self.vy = 0.0
                return

            self.vy += self.gravity * dt
            new_y = current_y + self.vy * dt
            if new_y >= floor_y:
                new_y = floor_y
                self.anchor_y = floor_y
                # 落地反弹判断
                if abs(self.vy) > 280:
                    self.vy = -self.vy * self.bounce_damping
                    self.state = "BOUNCE"
                    QTimer.singleShot(220, self._finish_bounce)
                elif abs(self.vy) > 160:
                    # 跌落产生轻微眩晕
                    self.play_action("DIZZY", duration=2.6)
                    self.move(int(current_x), int(floor_y))
                    return
                else:
                    self.vy = 0
                    self.state = "IDLE"
            self.move(int(current_x), int(new_y))
            return

        # 3. 落地回弹轻微形变中
        if self.state == "BOUNCE":
            self.move(int(current_x), int(floor_y))
            self.anchor_y = floor_y
            return

        # 4. 如果开启了重力且悬空，自动进入掉落状态
        if self.model.enable_gravity and current_y < floor_y - 3:
            self.state = "FALLING"
            return

        # 5. 特殊多样化动作持续中
        if self.state in ("STRETCH_YAWN", "WASH_FACE", "CHASE_BUTTERFLY", "HEAD_BOB_MUSIC",
                          "TILT_HEAD", "HAPPY_SPIN", "DOZE_OFF", "DIZZY"):
            self.action_timer -= dt
            self.move(int(current_x), int(target_ground_y))
            if self.action_timer <= 0:
                self.state = "IDLE"
                self.next_action_time = time.time() + random.uniform(5.0, 12.0)
            return

        # 6. 自主漫步与多样动作 AI 行为决策
        if self.model.auto_roam and not self.model.is_sleeping and not self.model.is_studying:
            now = time.time()
            if self.state == "IDLE":
                if now >= self.next_action_time:
                    # 丰富多样的自主行为权重决策
                    roll = random.random()
                    if roll < 0.38:
                        # 挑选目标X坐标漫步
                        target = random.randint(avail.left() + 40, avail.right() - self.width() - 40)
                        self.walk_target_x = target
                        if target < current_x:
                            self.state = "WALK_LEFT"
                            self.facing_left = True
                        else:
                            self.state = "WALK_RIGHT"
                            self.facing_left = False
                        self.next_action_time = now + random.uniform(8.0, 18.0)
                    elif roll < 0.48:
                        self.play_action("STRETCH_YAWN")
                    elif roll < 0.60:
                        self.play_action("WASH_FACE")
                    elif roll < 0.70:
                        self.play_action("CHASE_BUTTERFLY")
                    elif roll < 0.80:
                        self.play_action("HEAD_BOB_MUSIC")
                    elif roll < 0.90:
                        self.play_action("TILT_HEAD")
                    elif roll < 0.96:
                        self.play_action("HAPPY_SPIN")
                    else:
                        self.play_action("DOZE_OFF")

            elif self.state in ("WALK_LEFT", "WALK_RIGHT"):
                speed = 55.0  # 走动速度 (像素/秒)
                dx = self.walk_target_x - current_x
                if abs(dx) < 4.0:
                    self.state = "IDLE"
                    self.next_action_time = now + random.uniform(4.0, 10.0)
                else:
                    step = speed * dt
                    if self.state == "WALK_LEFT":
                        new_x = max(avail.left() + 20, current_x - step)
                    else:
                        new_x = min(avail.right() - self.width() - 20, current_x + step)
                    self.move(int(new_x), int(target_ground_y))

    def _finish_bounce(self):
        if self.state == "BOUNCE":
            self.state = "IDLE"

    def _on_status_tick(self):
        """每秒更新一次宠物数值"""
        self.model.tick(1.0)

    # ================= 鼠标与交互事件 =================
    def enterEvent(self, event):
        """鼠标靠近/移入宠物，平滑浮现伴侣交互岛"""
        if hasattr(self, "dock"):
            self.dock.show_dock()
        super().enterEvent(event)

    def leaveEvent(self, event):
        """鼠标移出宠物，延迟平滑收起伴侣岛"""
        if hasattr(self, "dock"):
            self.dock.schedule_hide(1800)
        super().leaveEvent(event)

    def moveEvent(self, event):
        super().moveEvent(event)
        if hasattr(self, "dock") and self.dock.is_dock_visible:
            self.dock.sync_position()
        if hasattr(self, "dialogue") and self.dialogue.is_visible:
            self.dialogue.sync_position()

    def hideEvent(self, event):
        if hasattr(self, "dock"):
            self.dock.hide()
        if hasattr(self, "dialogue"):
            self.dialogue.dismiss()
        super().hideEvent(event)

    def mousePressEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.LeftButton:
            self.is_dragging = False
            self.mouse_press_pos = event.globalPosition().toPoint()
            self.drag_start_pos = event.globalPosition().toPoint() - self.frameGeometry().topLeft()
            self.stroke_distance = 0.0

        elif event.button() == Qt.MouseButton.RightButton:
            self._open_quick_menu()

    def _open_quick_menu(self):
        """智能边缘防遮挡与平滑淡入动画"""
        menu = QuickActionMenu(self.model, self)
        menu.adjustSize()
        menu_w = menu.width()
        menu_h = menu.height()

        screen = QApplication.screenAt(QCursor.pos())
        if not screen:
            screen = QApplication.primaryScreen()
        avail = screen.availableGeometry()

        cur = QCursor.pos()
        target_x = cur.x() - menu_w // 2
        target_y = cur.y() - menu_h - 15

        # 屏幕四周边界防溢出保护
        target_x = max(avail.left() + 14, min(target_x, avail.right() - menu_w - 14))
        if target_y < avail.top() + 14:
            target_y = cur.y() + 20
        target_y = max(avail.top() + 14, min(target_y, avail.bottom() - menu_h - 14))

        menu.move(int(target_x), int(target_y))

        # 优雅淡入展开
        menu.setWindowOpacity(0.0)
        menu.show()
        menu.raise_()
        anim = QPropertyAnimation(menu, b"windowOpacity", menu)
        anim.setDuration(160)
        anim.setStartValue(0.0)
        anim.setEndValue(1.0)
        anim.setEasingCurve(QEasingCurve.Type.OutCubic)
        anim.start()
        self._current_menu_anim = anim

    def mouseMoveEvent(self, event: QMouseEvent):
        if event.buttons() & Qt.MouseButton.LeftButton:
            current_pos = event.globalPosition().toPoint()
            move_delta = (current_pos - self.mouse_press_pos).manhattanLength()

            if move_delta > 8:
                if not self.is_dragging:
                    self.is_dragging = True
                    self.state = "DRAGGING"
                self.move(current_pos - self.drag_start_pos)
            else:
                # 鼠标在宠物头上轻微晃动视为“抚摸”
                self.stroke_distance += move_delta
                if self.stroke_distance > 40:
                    self.stroke_distance = 0.0
                    self.model.pet_head()
                    self.renderer.trigger_pet()

    def mouseReleaseEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.LeftButton:
            if self.is_dragging:
                self.is_dragging = False

                # 限制在屏幕可见工作区内
                screen = QApplication.screenAt(self.geometry().center())
                if not screen:
                    screen = QApplication.primaryScreen()
                avail = screen.availableGeometry() if screen else None

                if avail:
                    clamped_x = max(avail.left(), min(self.x(), avail.right() - self.width()))
                    clamped_y = max(avail.top(), min(self.y(), avail.bottom() - self.height()))
                    self.move(int(clamped_x), int(clamped_y))
                    self.anchor_y = clamped_y
                else:
                    self.anchor_y = self.y()

                self.model.last_pos_x = self.x()
                self.model.last_pos_y = self.y()
                self.model.save_to_disk()

                if self.model.enable_gravity:
                    self.vy = 0.0
                    self.state = "FALLING"
                else:
                    self.vy = 0.0
                    self.state = "IDLE"
            else:
                # 单击宠物触发抚摸并平滑浮现伴侣操作岛
                self.model.pet_head()
                self.renderer.trigger_pet()
                if hasattr(self, "dock"):
                    self.dock.show_dock()
                if random.random() < 0.4:
                    self.dialogue.say(random.choice([
                        "摸摸头好舒服呀~ (ฅ'ω'ฅ)",
                        "主人最温柔啦！呼噜呼噜~",
                        "被主人关爱的感觉真好~ ✨"
                    ]))

    def mouseDoubleClickEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.LeftButton:
            # 双击宠物互动：随机触发才艺绝活（旋转欢呼、歪头卖萌、抓蝴蝶、听歌摇摆）
            self.model.pet_head()
            self.renderer.trigger_pet()
            choice = random.choice(["HAPPY_SPIN", "TILT_HEAD", "CHASE_BUTTERFLY", "HEAD_BOB_MUSIC"])
            self.play_action(choice)

    def paintEvent(self, event):
        painter = QPainter(self)
        w = self.width()
        h = self.height()

        # 绘制宠物本体 (气泡已升级为独立浮动卡片窗口，彻底避免耳朵与头饰遮挡)
        self.renderer.render(painter, w, h, self.state, self.facing_left)

    def closeEvent(self, event):
        self.model.last_pos_x = self.x()
        self.model.last_pos_y = self.y()
        self.model.save_to_disk()
        if hasattr(self, "dock"):
            self.dock.close()
        if hasattr(self, "dialogue") and hasattr(self.dialogue, "bubble"):
            self.dialogue.bubble.close()
        super().closeEvent(event)
