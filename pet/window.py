import math
import random
import time
from PyQt6.QtCore import Qt, QTimer, QPoint, QRect, QRectF, QPropertyAnimation, QEasingCurve, QAbstractNativeEventFilter
from PyQt6.QtWidgets import QWidget, QApplication
from PyQt6.QtGui import QPainter, QCursor, QMouseEvent, QScreen

from pet.renderer import PetRenderer
from pet.dialogue import DialogueManager
from pet.menus import QuickActionMenu
from pet.dock import PetCompanionDock
from pet.memo import PetStickyNote
from pet.audio import sound_manager

class GlobalBossKeyFilter(QAbstractNativeEventFilter):
    """Windows 原生全局消息过滤器 (安全响应 Alt+P 全局老板键)"""
    def __init__(self, window):
        super().__init__()
        self.window = window

    def nativeEventFilter(self, eventType, message):
        try:
            if eventType == b"windows_generic_MSG":
                import ctypes.wintypes as wt
                msg = wt.MSG.from_address(int(message))
                if msg.message == 0x0312 and msg.wParam == getattr(self.window, "HOTKEY_BOSS_ID", 9527):
                    self.window.toggle_boss_mode()
                    return True, 0
        except Exception:
            pass
        return False, 0

class PetWindow(QWidget):
    """
    桌面透明无边框宠物主窗口
    实现物理重力、拖拽掉落回弹、屏幕边缘碰撞、自由漫步巡逻与交互触发
    """
    EDGE_PEEK_MARGIN = 38

    def __init__(self, model):
        super().__init__()
        self.model = model
        self.renderer = PetRenderer(model)
        self.dock = PetCompanionDock(model, self)
        self.dialogue = DialogueManager(model, self)
        self.memo = PetStickyNote(model, self)

        # 全局老板键隐身状态标志
        self.is_boss_hidden = False
        self._memo_was_visible = False
        self.HOTKEY_BOSS_ID = 9527
        self._boss_filter_installed = False
        self.click_through = False

        # 状态机：IDLE, WALK_LEFT, WALK_RIGHT, DRAGGING, FALLING, BOUNCE, 
        # 及多样动作：STRETCH_YAWN, WASH_FACE, CHASE_BUTTERFLY, HEAD_BOB_MUSIC, TILT_HEAD, HAPPY_SPIN, DOZE_OFF, DIZZY, CARDBOARD_BOX, PEEK_LEFT, PEEK_RIGHT
        self.state = "IDLE"
        self.facing_left = False
        self.action_timer = 0.0

        # 物理重力与速度参数
        self.vx = 0.0
        self.vy = 0.0
        self.gravity = 1800.0  # 像素/秒^2
        self.bounce_damping = 0.38

        # 拖拽与动态物理
        self.is_dragging = False
        self.drag_start_pos = QPoint()
        self.mouse_press_pos = QPoint()
        self._last_mouse_move_pos = QPoint()
        self._stroke_triggered = False
        self.stroke_distance = 0.0
        self.anchor_y = None
        self.drag_vx = 0.0
        self.drag_vy = 0.0
        self._last_drag_time = time.time()
        self.step_accum = 0.0

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
        self.setCursor(Qt.CursorShape.OpenHandCursor)

        # 根据成长与进化缩放因子调整基础大小 (基准 220x220)
        base_size = int(220 * self.model.visual_scale)
        self.resize(base_size, base_size)

        # 监听屏幕分辨率变更或多显示器热插拔，防止宠物掉出屏幕可见区域
        app = QApplication.instance()
        if app:
            try:
                app.screenAdded.connect(self._on_screen_changed)
                app.screenRemoved.connect(self._on_screen_changed)
                primary = app.primaryScreen()
                if primary:
                    primary.geometryChanged.connect(self._on_screen_changed)
            except Exception:
                pass

    def register_boss_hotkey(self):
        """窗口显式显示后安全注册 Windows 全局老板键 (Alt + P)"""
        try:
            import ctypes
            hwnd = int(self.winId())
            self._boss_hwnd = hwnd
            ctypes.windll.user32.RegisterHotKey(hwnd, self.HOTKEY_BOSS_ID, 0x0001 | 0x4000, 0x50)
            app = QApplication.instance()
            if app and not getattr(self, "_boss_filter_installed", False):
                self._boss_filter = GlobalBossKeyFilter(self)
                app.installNativeEventFilter(self._boss_filter)
                self._boss_filter_installed = True
        except Exception as e:
            print("RegisterHotKey error:", e)

    def unregister_boss_hotkey(self):
        """注销全局热键"""
        try:
            import ctypes
            if hasattr(self, "_boss_hwnd"):
                ctypes.windll.user32.UnregisterHotKey(self._boss_hwnd, self.HOTKEY_BOSS_ID)
        except Exception:
            pass

    def toggle_boss_mode(self):
        """全局老板键一键极速隐身 / 恢复显示 (Alt + P)"""
        self.is_boss_hidden = not getattr(self, "is_boss_hidden", False)
        if self.is_boss_hidden:
            # 极速隐身：隐藏窗口、伴侣岛、气泡、便签并静音，停用动画定时器彻底释放 CPU
            if hasattr(self, "anim_timer") and self.anim_timer.isActive():
                self.anim_timer.stop()
            self.hide()
            if hasattr(self, "dock"):
                self.dock.hide()
            if hasattr(self, "dialogue") and hasattr(self.dialogue, "bubble"):
                self.dialogue.bubble.hide()
            if hasattr(self, "memo") and self.memo.isVisible():
                self._memo_was_visible = True
                self.memo.hide()
            else:
                self._memo_was_visible = False
            sound_manager.muted = True
        else:
            # 恢复现身：重启帧定时器
            if hasattr(self, "anim_timer") and not self.anim_timer.isActive():
                self.last_tick_time = time.time()
                self.anim_timer.start(33 if self.model.is_sleeping else 16)
            sound_manager.muted = not getattr(self.model, "sound_enabled", True)
            self.show()
            self.setWindowState(self.windowState() & ~Qt.WindowState.WindowMinimized | Qt.WindowState.WindowActive)
            self.raise_()
            self.activateWindow()
            if getattr(self, "_memo_was_visible", False) and hasattr(self, "memo"):
                self.memo.show()
            if getattr(self.model, "sound_enabled", True):
                sound_manager.play("meow")
            self.dialogue.say("老板走啦？波可安全现身咯！🐾\n(按 Alt+P 随时隐身护体)", duration=3.8)

    def _on_screen_changed(self, *args):
        """屏幕拔插/分辨率调整时，自动校准位置至可视安全区域内"""
        screen = QApplication.screenAt(self.geometry().center())
        if not screen:
            screen = QApplication.primaryScreen()
        if not screen:
            return
        avail = screen.availableGeometry()

        cur_x = self.x()
        cur_y = self.y()

        clamped_x = max(avail.left() + 10, min(cur_x, avail.right() - self.width() - 10))
        clamped_y = max(avail.top() + 10, min(cur_y, avail.bottom() - self.height()))

        if clamped_x != cur_x or clamped_y != cur_y:
            self.move(int(clamped_x), int(clamped_y))
            self.anchor_y = clamped_y
            if hasattr(self, "dialogue"):
                self.dialogue.say("检测到屏幕环境变动，波可跳回眼前咯~ 🐾", duration=3.5)

    def _init_initial_position(self):
        screen = QApplication.primaryScreen()
        avail = screen.availableGeometry() if screen else None
        if not avail:
            init_x, init_y = 100, 100
        else:
            default_x = avail.right() - self.width() - 80
            default_y = avail.bottom() - self.height() - 15
            if (self.model.last_pos_x is not None and self.model.last_pos_y is not None and
                    not (self.model.last_pos_x == 0 and self.model.last_pos_y == 0)):
                # 如果历史记录的坐标贴顶 (<=15px) 或超出屏幕工作区，重置为右下角默认位置
                if self.model.last_pos_y <= 15 or self.model.last_pos_y > avail.bottom() - self.height() - 10:
                    init_x, init_y = default_x, default_y
                else:
                    init_x = max(avail.left() + 10, min(int(self.model.last_pos_x), avail.right() - self.width() - 10))
                    init_y = max(avail.top() + 10, min(int(self.model.last_pos_y), avail.bottom() - self.height() - 10))
            else:
                init_x, init_y = default_x, default_y

        self.anchor_y = init_y
        self.move(int(init_x), int(init_y))

    def set_click_through(self, enabled: bool):
        """开启/关闭鼠标穿透免打扰模式"""
        self.click_through = enabled
        self.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents, enabled)
        if enabled:
            if hasattr(self, "dock") and self.dock.isVisible():
                self.dock.hide()
            if hasattr(self, "dialogue"):
                self.dialogue.say("开启鼠标穿透啦！波可静静陪着您，不会遮挡任何点击哦~ (ฅ^ω^ฅ)", duration=3.5)
        else:
            if hasattr(self, "dialogue"):
                self.dialogue.say("已恢复正常鼠标互动~ 快来摸摸我吧！🐾", duration=3.5)

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
                screen = QApplication.screenAt(self.geometry().center())
                if screen:
                    avail = screen.availableGeometry()
                    new_x = max(avail.left(), min(int(old_x - diff / 2), avail.right() - target_size))
                    new_y = max(avail.top(), min(new_y, avail.bottom() - target_size))
                    self.move(int(new_x), int(new_y))
                self.anchor_y = new_y

    def _on_evolution_triggered(self, new_stage, stage_name):
        """萌宠进化蜕变"""
        self.renderer.trigger_evolution()
        self.check_resize_for_growth()
        self.dialogue.say(f"🌟 奇迹蜕变！波可成长进阶到【{stage_name}】啦！体型变大、神采奕奕~ (✧ω✧)", duration=7.0)


    def get_head_rel_y(self) -> float:
        """获取宠物头顶或头饰最上边缘相对于本窗口顶部的精确像素距离 (自适应所有形态与装扮)"""
        scale = self.width() / 220.0
        cy = 125.0 * scale
        
        # 基础头部高度 (相对于 cy = 125)
        pet_type = getattr(self.model, "pet_type", "cat")
        skin_id = getattr(self.model, "skin_id", "cat_calico")
        
        if skin_id.startswith("dog") or pet_type == "dog":
            base_top_offset = 78.0
        elif skin_id.startswith("slime") or pet_type == "slime":
            base_top_offset = 83.0
        elif skin_id.startswith("penguin") or pet_type == "penguin":
            base_top_offset = 50.0
        else: # cat
            base_top_offset = 63.0
            
        # 头部饰品高度补偿
        head_dec = self.model.decorations.get("head", "none")
        if head_dec == "hat_wizard":
            base_top_offset = max(base_top_offset, 108.0)
        elif head_dec == "hat_party":
            base_top_offset = max(base_top_offset, 98.0)
        elif head_dec == "chef":
            base_top_offset = max(base_top_offset, 85.0)
        elif head_dec in ("horns", "halo", "crown"):
            base_top_offset = max(base_top_offset, 75.0)
            
        head_rel = cy - base_top_offset * scale
        return max(0.0, head_rel)

    def get_head_screen_y(self) -> float:
        """获取宠物头顶在屏幕上的绝对全局 Y 坐标"""
        return self.y() + self.get_head_rel_y()

    def get_foot_screen_y(self) -> float:
        """获取宠物足底在屏幕上的绝对全局 Y 坐标"""
        scale = self.width() / 220.0
        return self.y() + 171.0 * scale

    def get_center_screen_x(self) -> float:
        """获取宠物身体中心在屏幕上的绝对全局 X 坐标"""
        return self.x() + self.width() / 2.0

    def get_floor_y(self):
        """获取当前所在屏幕的任务栏/底部地面 Y 坐标"""
        screen = QApplication.screenAt(self.geometry().center())
        if not screen:
            screen = QApplication.primaryScreen()
        avail = screen.availableGeometry()
        scale = self.width() / 220.0
        return int(avail.bottom() - 171.0 * scale)

    # ================= 60 FPS 核心帧循环 =================
    def _on_animation_tick(self):
        try:
            if getattr(self, "is_boss_hidden", False) or not self.isVisible():
                return
            now = time.time()
            dt = min(0.05, now - self.last_tick_time)
            self.last_tick_time = now

            # 计算鼠标光标相对宠物头部的空间方位，计算眼神注视跟踪与空间距离 (驱动动态瞳孔放大)
            cursor_pos = QCursor.pos()
            pet_center_x = self.get_center_screen_x()
            pet_center_y = self.get_head_screen_y() + 25.0 * (self.width() / 220.0)
            dx = cursor_pos.x() - pet_center_x
            dy = cursor_pos.y() - pet_center_y
            dist_px = math.hypot(dx, dy)
            if self.facing_left:
                dx = -dx
            gaze_x = max(-1.0, min(1.0, dx / 220.0))
            gaze_y = max(-1.0, min(1.0, dy / 180.0))
            self.renderer.set_cursor_gaze(gaze_x, gaze_y, dist_px)

            # 更新渲染器与粒子
            self.renderer.update_animation(dt, self.state)
            # 更新气泡提醒
            self.dialogue.update(dt)

            # 物理与AI移动处理
            self._update_physics_and_ai(dt)

            # 动态吸附同步伴侣岛与对话气泡位置 (内置坐标变更防抖)
            if hasattr(self, "dock") and self.dock.is_dock_visible:
                self.dock.sync_position()
            if hasattr(self, "dialogue") and self.dialogue.is_visible:
                self.dialogue.sync_position()

            # 触发重绘
            self.update()
        except Exception as e:
            now = time.time()
            if now - getattr(self, "_last_tick_err_time", 0.0) > 5.0:
                self._last_tick_err_time = now
                print(f"[PetWindow] Animation tick warning: {e}")

    def play_action(self, action_name, custom_msg=None, duration=None, show_dialogue=True):
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
                "duration": 3.4, "sound": "sparkle",
                "lines": [
                    "抓到了吗？抓到了吗！疯狂追自己的小尾巴转圈圈~ 💫(✧ω✧)🐾",
                    "看波可原地大漂移！小尾巴别跑，看爪！🌀🐾",
                    "原地超级大回旋！今天一定要咬到自己的毛茸茸尾巴尖！🎉(ฅ>ω<*ฅ)"
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
            },
            "LOOK_AROUND": {
                "duration": 3.6, "sound": "curious",
                "lines": [
                    "东瞅瞅、西看看~ 发现主人正专注地敲代码呢！👀✨",
                    "脑袋转转，警惕巡视桌面~ 报告主人，一切安全！🐾",
                    "四处张望~ 看看有没有小鱼干掉落呢？(ฅ'ω'ฅ)"
                ]
            },
            "SIT_WAG_TAIL": {
                "duration": 3.8, "sound": "purr",
                "lines": [
                    "乖乖坐下~ 小尾巴轻快摇晃，静静陪在主人身边！🐾💕",
                    "端坐卖萌中~ 蓬松尾巴晃呀晃，心情满分！✨",
                    "在主人脚边乖巧蹲坐~ 呼噜呼噜好安心~ (๑╹◡╹๑)"
                ]
            },
            "CATCH_MOUSE": {
                "duration": 4.5, "sound": "pop",
                "lines": [
                    "看我的喵影神捕！敏捷一扑，抓到机械小老鼠啦！🐭🐾",
                    "小老鼠别跑~ 喵呜飞扑！稳稳按在爪下！✨(ฅ'ω'ฅ)",
                    "本喵是抓鼠小冠军！身手矫健敏捷度拉满~ 💨"
                ]
            },
            "PLAY_YARN": {
                "duration": 4.6, "sound": "sparkle",
                "lines": [
                    "发现粉红毛线球！左爪拍拍，右爪拨拨~ 🧶🐾",
                    "毛线球滚呀滚~ 扑腾扑腾，好好玩呀！💕✨",
                    "抓线头大作战！滚来滚去，快乐无极限~ 🐱"
                ]
            },
            "CARDBOARD_BOX": {
                "duration": 6.5, "sound": "purr",
                "lines": [
                    "发现一个刚拆开的快递纸箱！钻进去也太舒服太有安全感啦~ 📦🐾",
                    "只要有纸箱，波可就能把自己装进去！露出一双好奇大眼睛~ (✧ω✧)",
                    "纸箱是猫咪永远的快乐老家！探头偷看~ 谁都不许抢我的箱子！📦✨"
                ]
            }
        }

        cfg = action_config.get(action_name, {"duration": 3.0, "sound": "meow", "lines": ["波可展示了可爱绝活！✨"]})
        self.action_timer = duration if duration is not None else cfg["duration"]
        if cfg.get("sound") and getattr(self.model, "sound_enabled", True):
            sound_manager.play(cfg["sound"])
        if show_dialogue:
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

        # 2. 自由落体与惯性抛物线物理 (仅在重力开启时生效)
        if self.state == "FALLING":
            if not self.model.enable_gravity:
                self.state = "IDLE"
                self.vy = 0.0
                self.vx = 0.0
                return

            self.vy += self.gravity * dt
            new_y = current_y + self.vy * dt

            # 水平惯性抛物线运动与空气阻力衰减
            new_x = current_x + getattr(self, "vx", 0.0) * dt
            self.vx *= max(0.0, 1.0 - dt * 1.6)

            # 屏幕左右侧壁弹性回弹碰撞
            if new_x <= avail.left():
                new_x = avail.left()
                self.vx = -self.vx * 0.55
                self.facing_left = False
                if abs(self.vx) > 120 and getattr(self.model, "sound_enabled", True):
                    sound_manager.play("pop")
            elif new_x >= avail.right() - self.width():
                new_x = avail.right() - self.width()
                self.vx = -self.vx * 0.55
                self.facing_left = True
                if abs(self.vx) > 120 and getattr(self.model, "sound_enabled", True):
                    sound_manager.play("pop")

            if new_y >= floor_y:
                new_y = floor_y
                self.anchor_y = floor_y
                self.renderer.trigger_landing_bounce()
                # 落地反弹判断
                if abs(self.vy) > 280:
                    self.vy = -self.vy * self.bounce_damping
                    self.vx = self.vx * 0.4
                    self.state = "BOUNCE"
                    QTimer.singleShot(220, self._finish_bounce)
                elif abs(self.vy) > 160:
                    # 跌落产生轻微眩晕
                    self.vx = 0.0
                    self.play_action("DIZZY", duration=2.6)
                    self.move(int(new_x), int(floor_y))
                    return
                else:
                    self.vy = 0.0
                    self.vx = 0.0
                    self.state = "IDLE"
            self.move(int(new_x), int(new_y))
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

        # 5. 贴边探头模式中 (静止停留在屏幕边沿等待交互)
        if self.state in ("PEEK_LEFT", "PEEK_RIGHT"):
            return

        # 5.5 特殊多样化动作持续中
        ALL_ACTIONS = (
            "STRETCH_YAWN", "WASH_FACE", "CHASE_BUTTERFLY", "HEAD_BOB_MUSIC",
            "TILT_HEAD", "HAPPY_SPIN", "DOZE_OFF", "DIZZY", "LOOK_AROUND", "SIT_WAG_TAIL",
            "CATCH_MOUSE", "PLAY_YARN", "CARDBOARD_BOX"
        )
        if self.state in ALL_ACTIONS:
            self.action_timer -= dt
            self.move(int(current_x), int(target_ground_y))
            if self.action_timer <= 0:
                self.state = "IDLE"
                self.next_action_time = time.time() + random.uniform(2.5, 5.0)
            return

        # 6. 自主漫步与多样动作 AI 行为决策 (活力巡视，彻底告别卡死与僵直)
        if not self.model.is_sleeping and not self.model.is_studying:
            now = time.time()
            min_x = avail.left() + 25
            max_x = avail.right() - self.width() - 25

            if self.state == "IDLE":
                if now >= self.next_action_time:
                    # 如果启用了自主漫步，有 38% 概率进行短途惬意溜达
                    if self.model.auto_roam and random.random() < 0.38:
                        # 挑选近距离漫步目标 (80~220px)，远离屏幕边缘防卡死
                        if current_x <= min_x + 80:
                            target = current_x + random.randint(100, 240)
                        elif current_x >= max_x - 80:
                            target = current_x - random.randint(100, 240)
                        else:
                            direction = -1 if random.random() < 0.5 else 1
                            target = current_x + direction * random.randint(90, 220)
                        target = max(min_x, min(target, max_x))

                        self.walk_target_x = target
                        self._walk_start_time = now
                        if target < current_x:
                            self.state = "WALK_LEFT"
                            self.facing_left = True
                        else:
                            self.state = "WALK_RIGHT"
                            self.facing_left = False
                        self.next_action_time = now + 6.0
                    else:
                        # 原地灵动才艺动作自主切换 (加权抽取，突出抓老鼠、玩毛线与纸箱躲猫猫的高光互动)
                        act_choices = [
                            "CATCH_MOUSE", "PLAY_YARN", "CARDBOARD_BOX", "WASH_FACE", "STRETCH_YAWN",
                            "TILT_HEAD", "LOOK_AROUND", "SIT_WAG_TAIL", "HEAD_BOB_MUSIC",
                            "CHASE_BUTTERFLY", "HAPPY_SPIN", "DOZE_OFF"
                        ]
                        weights = [0.16, 0.16, 0.15, 0.12, 0.10, 0.10, 0.07, 0.06, 0.04, 0.02, 0.01, 0.01]
                        selected = random.choices(act_choices, weights=weights)[0]
                        # 20% 概率轻声冒出台词气泡，避免频繁打扰工作
                        say_line = (random.random() < 0.20)
                        self.play_action(selected, show_dialogue=say_line)
                        self.next_action_time = now + self.action_timer + random.uniform(2.5, 5.5)

            elif self.state in ("WALK_LEFT", "WALK_RIGHT"):
                speed = 70.0  # 活泼的漫步速度 (像素/秒)
                if getattr(self.model, "personality", "") == "ATHLETE":
                    speed *= 1.25  # 元气运动喵敏捷提速 25%！
                step = speed * dt
                reached = False

                if self.state == "WALK_LEFT":
                    new_x = current_x - step
                    if new_x <= self.walk_target_x or new_x <= min_x:
                        new_x = max(min_x, self.walk_target_x)
                        reached = True
                else:
                    new_x = current_x + step
                    if new_x >= self.walk_target_x or new_x >= max_x:
                        new_x = min(max_x, self.walk_target_x)
                        reached = True

                # 到达目标或超时防卡死保护 (最长漫步 4.8 秒)
                walk_elapsed = now - getattr(self, "_walk_start_time", now)
                if reached or walk_elapsed > 4.8:
                    self.state = "IDLE"
                    self.step_accum = 0.0
                    self.model.add_personality_point("sport", 1)
                    self.next_action_time = now + random.uniform(2.5, 5.5)
                    self.move(int(new_x), int(target_ground_y))
                else:
                    self.move(int(new_x), int(target_ground_y))
                    # 步频微粒发射
                    self.step_accum += dt * 8.5
                    if self.step_accum >= math.pi:
                        self.step_accum -= math.pi
                        self.renderer.trigger_step_poof(self.facing_left)

    def _finish_bounce(self):
        if self.state == "BOUNCE":
            self.state = "IDLE"

    def _on_status_tick(self):
        """每秒更新一次宠物数值与自适应能耗调节，并进行硬件全息状态轮询"""
        try:
            self.model.tick(1.0)
            # 自适应能耗调节：休眠中降低帧率至 30 FPS 节约系统开销，醒来恢复 60 FPS
            if self.model.is_sleeping:
                if self.anim_timer.interval() != 33:
                    self.anim_timer.setInterval(33)
            else:
                if self.anim_timer.interval() != 16:
                    self.anim_timer.setInterval(16)

            # 硬件性能感知与高负载流汗彩蛋 (每 15 秒轮询一次)
            now = time.time()
            if now - getattr(self, "_last_hw_check_time", 0.0) >= 15.0:
                self._last_hw_check_time = now
                try:
                    from pet.system_monitor import get_system_stats
                    hw = get_system_stats()
                    if hw["cpu"] >= 85 and not getattr(self, "is_boss_hidden", False) and not self.model.is_sleeping:
                        if hasattr(self, "renderer"):
                            self.renderer.is_sweating = True
                        self.model.add_personality_point("tech", 1)
                        if now - getattr(self, "_last_cpu_warn_time", 0.0) > 120.0:  # 2 分钟防重复打扰
                            self._last_cpu_warn_time = now
                            self.dialogue.say(f"🔥 哎呀主人！CPU算力跑满啦 ({hw['cpu']}%)，波可热得直冒汗，快注意给电脑通风散热呀~ 💦", duration=5.5)
                    else:
                        if hasattr(self, "renderer"):
                            self.renderer.is_sweating = False
                except Exception:
                    pass
        except Exception as e:
            now = time.time()
            if now - getattr(self, "_last_status_err_time", 0.0) > 5.0:
                self._last_status_err_time = now
                print(f"[PetWindow] Status tick warning: {e}")

    # ================= 鼠标与交互事件 =================
    def enterEvent(self, event):
        """鼠标靠近/移入宠物，平滑浮现伴侣交互岛并触发全息生物扫描仪扫光"""
        if self.state in ("PEEK_LEFT", "PEEK_RIGHT"):
            self.pop_out_from_edge()
            super().enterEvent(event)
            return
        if hasattr(self, "renderer"):
            self.renderer.trigger_holo_scan()
            if getattr(self.model, "sound_enabled", True) and random.random() < 0.65:
                sound_manager.play("cyber_scan")
        if hasattr(self, "dock"):
            self.dock.show_dock()
        super().enterEvent(event)

    def leaveEvent(self, event):
        """鼠标移出宠物，延迟平滑收起伴侣岛 (若光标移入快捷岛，绝不误触发隐藏)"""
        if hasattr(self, "dock") and self.dock.isVisible():
            cursor_pos = QCursor.pos()
            if self.dock.frameGeometry().contains(cursor_pos):
                super().leaveEvent(event)
                return
            self.dock.schedule_hide(2000)
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
        if hasattr(self, "memo") and self.memo.isVisible():
            self._memo_was_open = True
            self.memo.hide()
        super().hideEvent(event)

    def showEvent(self, event):
        super().showEvent(event)
        if getattr(self, "_memo_was_open", False) and hasattr(self, "memo"):
            self.memo.show()
            self._memo_was_open = False

    def mousePressEvent(self, event: QMouseEvent):
        if self.state in ("PEEK_LEFT", "PEEK_RIGHT"):
            self.pop_out_from_edge()
            return

        if event.button() == Qt.MouseButton.LeftButton:
            self.is_dragging = False
            self.setCursor(Qt.CursorShape.ClosedHandCursor)
            self.mouse_press_pos = event.globalPosition().toPoint()
            self._last_mouse_move_pos = event.globalPosition().toPoint()
            self._stroke_triggered = False
            self.drag_start_pos = event.globalPosition().toPoint() - self.frameGeometry().topLeft()
            self.stroke_distance = 0.0
            self.drag_vx = 0.0
            self.drag_vy = 0.0
            self._last_drag_time = time.time()

        elif event.button() == Qt.MouseButton.MiddleButton:
            # 鼠标中键快捷哄睡/唤醒切换
            is_sleeping = self.model.toggle_sleep()
            self.state = "IDLE"
            if is_sleeping:
                self.dialogue.say("呼噜噜... 波可进入甜甜的梦乡啦，嘘~ 💤", duration=3.0)
            else:
                self.dialogue.say("喵呜~ 睡饱醒来啦！活力满满~ (ฅ'ω'ฅ)", duration=3.0)

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
                now_t = time.time()
                dt_drag = max(0.001, now_t - self._last_drag_time)
                new_pos = current_pos - self.drag_start_pos
                old_x, old_y = self.x(), self.y()
                # 平滑计算拖拽水平与垂直速度 (以获得生动风阻倾角与抓起蹬腿动效)
                vx_inst = (new_pos.x() - old_x) / dt_drag
                vy_inst = (new_pos.y() - old_y) / dt_drag
                self.drag_vx = self.drag_vx * 0.6 + vx_inst * 0.4
                self.drag_vy = self.drag_vy * 0.6 + vy_inst * 0.4
                self._last_drag_time = now_t

                if not self.is_dragging:
                    self.is_dragging = True
                    self.state = "DRAGGING"
                    if getattr(self.model, "sound_enabled", True):
                        sound_manager.play("pop")
                self.move(new_pos)
            else:
                # 鼠标在宠物头上轻微晃动视为“抚摸”
                incremental_delta = (current_pos - self._last_mouse_move_pos).manhattanLength()
                self._last_mouse_move_pos = current_pos
                self.stroke_distance += incremental_delta
                if self.stroke_distance > 40:
                    self.stroke_distance = 0.0
                    self._stroke_triggered = True
                    self.model.pet_head()
                    self.renderer.trigger_pet()

    def mouseReleaseEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.LeftButton:
            if self.is_dragging:
                self.is_dragging = False
                # 拖拽互动 / 快速抛掷累积运动活力点数
                sport_pts = 2 if abs(getattr(self, "drag_vx", 0.0)) > 180 else 1
                self.model.add_personality_point("sport", sport_pts)

                # 限制在屏幕可见工作区内
                screen = QApplication.screenAt(self.geometry().center())
                if not screen:
                    screen = QApplication.primaryScreen()
                avail = screen.availableGeometry() if screen else None

                # 贴边探头偷看 (Screen-edge peek-a-boo) 判定 (非重力下靠近左右边框35px自动贴边偷看)
                if avail and not self.model.enable_gravity:
                    if self.x() <= avail.left() + self.EDGE_PEEK_MARGIN:
                        self.start_edge_peek("PEEK_LEFT", avail.left())
                        return
                    elif self.x() >= avail.right() - self.width() - self.EDGE_PEEK_MARGIN:
                        self.start_edge_peek("PEEK_RIGHT", avail.right())
                        return

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

                floor_y = self.get_floor_y()
                if self.model.enable_gravity:
                    if self.y() < floor_y - 2:
                        self.state = "FALLING"
                        self.vy = max(0.0, self.drag_vy * 0.3)
                        # 抛掷水平惯性动力学初速度
                        self.vx = max(-1000.0, min(1000.0, self.drag_vx * 0.45))
                    else:
                        self.vy = 0.0
                        self.vx = 0.0
                        self.state = "IDLE"
                        self.renderer.trigger_landing_bounce()
                else:
                    self.vy = 0.0
                    self.vx = 0.0
                    self.state = "IDLE"
                    self.renderer.trigger_landing_bounce()

                # 贴边智能面朝屏幕内 (不把脸对着显示器边框)
                if avail:
                    if self.x() <= avail.left() + self.EDGE_PEEK_MARGIN:
                        self.facing_left = False
                    elif self.x() >= avail.right() - self.width() - self.EDGE_PEEK_MARGIN:
                        self.facing_left = True

                self.drag_vx = 0.0
                self.drag_vy = 0.0
                self.setCursor(Qt.CursorShape.OpenHandCursor)
                self.next_action_time = time.time() + random.uniform(2.0, 4.0)
            else:
                self.setCursor(Qt.CursorShape.OpenHandCursor)
                # 单击宠物触发抚摸并平滑浮现伴侣操作岛
                if not getattr(self, '_stroke_triggered', False):
                    self.model.pet_head()
                    self.renderer.trigger_pet()
                if self.model.sound_enabled and random.random() < 0.35:
                    sound_manager.play("meow")
                if hasattr(self, "dock"):
                    self.dock.show_dock()
                if random.random() < 0.4:
                    self.dialogue.say(random.choice([
                        "摸摸头好舒服呀~ (ฅ'ω'ฅ)",
                        "主人最温柔啦！呼噜呼噜~",
                        "被主人关爱的感觉真好~ ✨"
                    ]))

    def start_edge_peek(self, side, border_x):
        """贴边探头偷看模式 (Screen-Edge Peek-a-boo)"""
        self.state = side
        if side == "PEEK_LEFT":
            self.facing_left = False
            target_x = border_x - int(self.width() * 0.58)
        else:
            self.facing_left = True
            target_x = border_x - int(self.width() * 0.42)
        self.move(int(target_x), int(self.y()))
        self.anchor_y = self.y()
        self.drag_vx = 0.0
        self.drag_vy = 0.0
        self.setCursor(Qt.CursorShape.PointingHandCursor)
        if getattr(self.model, "sound_enabled", True):
            sound_manager.play("pop")
        self.dialogue.say("暗中观察中... (悬停或轻点抓我出来~ 🐾)", duration=3.2)

    def pop_out_from_edge(self):
        """从屏幕边缘跳回桌面正常位置"""
        if self.state not in ("PEEK_LEFT", "PEEK_RIGHT"):
            return
        was_left = (self.state == "PEEK_LEFT")
        screen = QApplication.screenAt(self.geometry().center())
        avail = screen.availableGeometry() if screen else QApplication.primaryScreen().availableGeometry()
        if was_left:
            target_x = avail.left() + 25
            self.facing_left = False
        else:
            target_x = avail.right() - self.width() - 25
            self.facing_left = True
        self.state = "IDLE"
        self.move(int(target_x), int(self.y()))
        self.anchor_y = self.y()
        self.setCursor(Qt.CursorShape.OpenHandCursor)
        self.renderer.trigger_landing_bounce()
        if getattr(self.model, "sound_enabled", True):
            sound_manager.play("meow")
        self.dialogue.say(random.choice([
            "抓到我啦！(ฅ'ω'ฅ) 原来主人一直在注意波可呢~",
            "探出小脑袋暗中观察，被主人一眼识破啦！🐾",
            "喵呜~ 贴边偷看被发现！抱抱主人~ ✨"
        ]), duration=3.5)

    def trigger_edge_peek(self):
        """主动命令波可移动至最近的屏幕边缘并探头偷看"""
        screen = QApplication.screenAt(self.geometry().center())
        avail = screen.availableGeometry() if screen else QApplication.primaryScreen().availableGeometry()
        dist_left = self.x() - avail.left()
        dist_right = avail.right() - (self.x() + self.width())
        if dist_left <= dist_right:
            self.start_edge_peek("PEEK_LEFT", avail.left())
        else:
            self.start_edge_peek("PEEK_RIGHT", avail.right())

    def toggle_memo(self):
        """切换随手便签展示"""
        if hasattr(self, "memo"):
            self.memo.toggle_memo()

    def mouseDoubleClickEvent(self, event: QMouseEvent):
        if event.button() == Qt.MouseButton.LeftButton:
            # 双击宠物互动：累积活力性格点数并奖励金币
            self.model.add_personality_point("sport", 1)
            self.model.coins += 1
            self.model.pet_head()
            self.renderer.trigger_pet()
            choice = random.choice([
                "CARDBOARD_BOX", "CATCH_MOUSE", "PLAY_YARN", "HAPPY_SPIN", "TILT_HEAD",
                "CHASE_BUTTERFLY", "HEAD_BOB_MUSIC", "SIT_WAG_TAIL", "LOOK_AROUND", "WASH_FACE"
            ])
            self.play_action(choice)

    def wheelEvent(self, event):
        """Ctrl + 鼠标滚轮即时缩放宠物大小 (0.75 ~ 1.35)"""
        if event.modifiers() & Qt.KeyboardModifier.ControlModifier:
            delta = event.angleDelta().y()
            if delta > 0:
                new_scale = min(1.35, self.model.user_scale_offset + 0.05)
            else:
                new_scale = max(0.75, self.model.user_scale_offset - 0.05)

            if abs(new_scale - self.model.user_scale_offset) >= 0.02:
                self.model.user_scale_offset = round(new_scale, 2)
                self.check_resize_for_growth()
                self.model.save_to_disk()
                pct = int(self.model.user_scale_offset * 100)
                self.dialogue.say(f"体型缩放已调节为: {pct}% 🐾", duration=1.6)
            event.accept()
        else:
            super().wheelEvent(event)

    def paintEvent(self, event):
        painter = QPainter(self)
        w = self.width()
        h = self.height()

        # 绘制宠物本体 (传入 drag_vx 驱动风阻倾角与抓起蹬腿动效)
        self.renderer.render(painter, w, h, self.state, self.facing_left, drag_vx=getattr(self, "drag_vx", 0.0))

    def closeEvent(self, event):
        try:
            import ctypes
            hwnd = int(self.winId())
            ctypes.windll.user32.UnregisterHotKey(hwnd, getattr(self, "HOTKEY_BOSS_ID", 9527))
        except Exception:
            pass
        if self.x() > 0 or self.y() > 0:
            self.model.last_pos_x = self.x()
            self.model.last_pos_y = self.y()
            self.model.save_to_disk()
        if hasattr(self, "dock"):
            self.dock.close()
        if hasattr(self, "dialogue") and hasattr(self.dialogue, "bubble"):
            self.dialogue.bubble.close()
        if hasattr(self, "memo"):
            self.memo.close()
        super().closeEvent(event)
