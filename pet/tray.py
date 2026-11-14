import os
import sys
from PyQt6.QtWidgets import QSystemTrayIcon, QMenu
from PyQt6.QtGui import QIcon, QPixmap, QPainter, QColor, QPen, QBrush
from PyQt6.QtCore import Qt, QTimer, QRectF, QPointF
from pet.menus import StatusDialog, SettingsDialog, WardrobeDialog, FeedingDialog, ActionShowDialog, FocusDialog, PlayDialog
from pet.audio import sound_manager
from pet.system_monitor import get_system_stats
from pet.diagnostics import log_exception

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

        self._single_click_timer = QTimer(self)
        self._single_click_timer.setSingleShot(True)
        self._single_click_timer.timeout.connect(self._on_single_click)

        # Windows 上双击托盘会先发 Trigger、再发 DoubleClick。
        # 这个标记用来记住「本次单击已经把宠物放出来了」，
        # 免得紧接着的 DoubleClick 又把它反向切回去（双击两下等于没点）。
        self._double_click_guard = False

        self._init_menu()
        self._sync_menu_state()
        self.activated.connect(self._on_tray_activated)

        # 监听模型状态变更以实时同步托盘选项与等级
        old_cb = self.model.on_state_change
        def _on_model_change():
            if old_cb:
                old_cb()
            self._sync_menu_state()
        self.model.on_state_change = _on_model_change

    def _init_menu(self):
        menu = QMenu()
        menu.setStyleSheet("""
            QMenu {
                background-color: #0B0F19;
                border: 1.5px solid #0EA5E9;
                border-radius: 10px;
                padding: 6px;
                font-family: "Microsoft YaHei UI";
                font-size: 13px;
                color: #F1F5F9;
            }
            QMenu::item {
                padding: 7px 26px 7px 22px;
                border-radius: 6px;
                background-color: transparent;
                color: #F1F5F9;
            }
            QMenu::item:selected {
                background: rgba(14, 165, 233, 0.25);
                color: #38BDF8;
                border: 1px solid rgba(56, 189, 248, 0.4);
            }
            QMenu::item:disabled {
                color: #38BDF8;
                font-weight: bold;
                background: rgba(15, 23, 42, 0.85);
                border: 1px solid rgba(14, 165, 233, 0.4);
                border-radius: 6px;
                padding: 7px 22px;
                margin-bottom: 2px;
            }
            QMenu::indicator {
                width: 14px;
                height: 14px;
                margin-left: 6px;
            }
            QMenu::indicator:checked {
                background-color: #0EA5E9;
                border: 2px solid #38BDF8;
                border-radius: 3px;
            }
            QMenu::indicator:unchecked {
                background-color: #1E293B;
                border: 1.5px solid #475569;
                border-radius: 3px;
            }
            QMenu::separator {
                height: 1px;
                background: #1E293B;
                margin: 5px 8px;
            }
        """)

        # 状态概览标题
        self.status_action = menu.addAction(f"🐾 {self.model.name} (Lv.{self.model.level})")
        self.status_action.setEnabled(False)
        menu.addSeparator()

        # ---------- 第一组：显隐与随身功能 ----------
        # 显示 / 隐藏切换
        self.toggle_show_action = menu.addAction("👁️ 隐藏萌宠")
        self.toggle_show_action.triggered.connect(self._toggle_visibility)

        # 全局老板键一键隐身/呼出（可勾选：用户能一眼看出当前是不是隐身态）
        self.boss_action = menu.addAction("🕶️ 全局老板键 (Alt + P)")
        self.boss_action.setCheckable(True)
        self.boss_action.triggered.connect(self._toggle_boss)

        # 随手便签
        memo_action = menu.addAction("📝 桌面随手便签")
        memo_action.triggered.connect(self._toggle_memo)

        menu.addSeparator()

        # ---------- 第二组：玩法 ----------
        # 赛博全息深度专注力场
        focus_action = menu.addAction("🍅 赛博深度专注时钟")
        focus_action.triggered.connect(self._open_focus)

        # 趣味互动与游乐
        play_action = menu.addAction("🎮 趣味互动与游乐")
        play_action.triggered.connect(self._open_play)

        # 贴边探头偷看
        peek_action = menu.addAction("👀 贴边探头偷看")
        peek_action.triggered.connect(self._trigger_peek)

        # 重置位置 (防止用户误把窗口拖出屏幕)
        reset_pos_action = menu.addAction("🎯 重置萌宠屏幕位置")
        reset_pos_action.triggered.connect(self._reset_position)

        menu.addSeparator()

        # ---------- 第三组：开关（可勾选的一律放一起）----------
        # 置顶切换
        self.ontop_action = menu.addAction("📌 保持窗口置顶")
        self.ontop_action.setCheckable(True)
        self.ontop_action.setChecked(self.model.always_on_top)
        self.ontop_action.triggered.connect(self._toggle_ontop)

        # 鼠标穿透免打扰模式
        self.click_through_action = menu.addAction("🖱️ 鼠标穿透 (免打扰模式)")
        self.click_through_action.setCheckable(True)
        self.click_through_action.setChecked(getattr(self.pet_window, "click_through", False))
        self.click_through_action.triggered.connect(self._toggle_click_through)

        # 音效切换
        self.sound_action = menu.addAction("🔊 萌宠音效")
        self.sound_action.setCheckable(True)
        self.sound_action.setChecked(self.model.sound_enabled)
        self.sound_action.triggered.connect(self._toggle_sound)

        menu.addSeparator()

        # ---------- 第四组：功能入口 ----------
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

        # ---------- 第五组：退出 ----------
        # 退出应用
        exit_action = menu.addAction("🚪 退出电子宠物")
        exit_action.triggered.connect(self._exit_app)
        menu.aboutToShow.connect(self._sync_menu_state)
        self.setContextMenu(menu)

    def _sync_menu_state(self):
        stage_name = self.model.stage_info.get("name", "萌宠") if hasattr(self.model, "stage_info") else "萌宠"
        if hasattr(self, "status_action") and self.status_action:
            self.status_action.setText(f"🐾 {self.model.name} (Lv.{self.model.level} · {stage_name})")
        if hasattr(self, "toggle_show_action") and self.toggle_show_action:
            # 文案必须和 _toggle_visibility 用同一套口径，否则菜单会说「显示萌宠」
            # 而点击后走的是另一套逻辑。
            is_vis = self._is_logically_visible()
            self.toggle_show_action.setText("👁️ 隐藏萌宠" if is_vis else "👁️ 显示萌宠")
        if hasattr(self, "ontop_action") and self.ontop_action:
            self.ontop_action.setChecked(self.model.always_on_top)
        if hasattr(self, "sound_action") and self.sound_action:
            self.sound_action.setChecked(self.model.sound_enabled)
        if hasattr(self, "click_through_action") and self.click_through_action:
            self.click_through_action.setChecked(getattr(self.pet_window, "click_through", False))
        if hasattr(self, "boss_action") and self.boss_action:
            # 勾选态 = 当前正处在隐身中，用户不用点一次才知道自己在隐身态
            self.boss_action.setChecked(
                bool(getattr(self.pet_window, "is_boss_hidden", False))
            )

        # 动态更新系统托盘丰富健康状态 Tooltip (注入 CPU、内存与系统运行时间)
        try:
            hw = get_system_stats()
            # 读数失败时显示「不可用」而不是 0% ——
            # 「CPU 0%」和「读不到 CPU」在用户眼里是两回事。
            cpu_s = f"{hw.get('cpu', 0)}%" if hw.get("cpu_ok") else "不可用"
            mem_s = f"{hw.get('memory', 0)}%" if hw.get("memory_ok") else "不可用"
            uptime_s = hw.get("uptime", "0m") if hw.get("uptime_ok") else "不可用"
            hw_line = f"\n💻 CPU: {cpu_s}  🧠 内存: {mem_s}  ⏱️ 运行: {uptime_s}"
        except Exception:
            hw_line = "\n💻 硬件读数暂不可用"

        self.setToolTip(
            f"🐾 {self.model.name} (Lv.{self.model.level} · 陪伴第{self.model.total_days}天 · {stage_name})\n"
            f"🍗 饱食: {int(self.model.hunger)}%  💖 心情: {int(self.model.mood)}%  ⚡ 精力: {int(self.model.energy)}%"
            f"{hw_line}"
        )

    def _is_logically_visible(self) -> bool:
        """宠物在用户心智里的「可见状态」。

        老板键隐身时窗口确实被 hide 了，但它和「用户主动关掉萌宠」是**两种**状态：
        前者是「藏起来，随时要能原样叫回来」，后者是「不显示了，我要自己再点开」。

        所以判断可见性不能只看 ``isVisible()`` —— 老板键隐身期间窗口也是隐藏的，
        但菜单文案必须显示「显示萌宠」，且点下去必须走**完整的现身流程**
        （重启帧定时器 + 解除静音 + 现身台词），而不是简单地 ``show()``。

        ⚠️ 以前这两个口径不一致，导致从托盘「显示萌宠」之后，
        宠物虽然出现在屏幕上，但帧定时器仍然是停的 —— 画面完全冻住不动。
        """
        return (
            self.pet_window.isVisible()
            and not getattr(self.pet_window, "is_boss_hidden", False)
        )

    def _toggle_visibility(self):
        if self._is_logically_visible():
            self.pet_window.hide()
            self.toggle_show_action.setText("👁️ 显示萌宠")
        elif getattr(self.pet_window, "is_boss_hidden", False):
            # 老板键隐身中 —— 走正规的恢复流程，而不是裸 show()。
            # toggle_boss_mode() 会把帧定时器拉起来、解除静音、抬升窗口并说一声。
            self.pet_window.toggle_boss_mode()
        else:
            self.pet_window.show()
            self.toggle_show_action.setText("👁️ 隐藏萌宠")

    def _toggle_boss(self):
        if hasattr(self.pet_window, "toggle_boss_mode"):
            self.pet_window.toggle_boss_mode()

    def _toggle_memo(self):
        if hasattr(self.pet_window, "toggle_memo"):
            self.pet_window.toggle_memo()

    def _trigger_peek(self):
        if hasattr(self.pet_window, "trigger_edge_peek"):
            self.pet_window.trigger_edge_peek()

    def _reset_position(self):
        # force=True —— 真的要回到右下角默认位。
        # 以前走的是「恢复上次拖拽坐标」，宠物几乎没动，
        # 气泡却写着「回到默认位置啦」，用户只会觉得这个按钮坏了。
        self.pet_window._init_initial_position(force=True)
        self.pet_window.show()
        self.pet_window.dialogue.say("波可回到默认位置啦！(ฅ'ω'ฅ)")

    def _toggle_ontop(self):
        self.model.always_on_top = self.ontop_action.isChecked()
        self.pet_window.apply_model_settings()
        self.model.save_to_disk()

    def _toggle_click_through(self):
        new_val = not getattr(self.pet_window, "click_through", False)
        self.pet_window.set_click_through(new_val)
        if hasattr(self, "click_through_action"):
            self.click_through_action.setChecked(new_val)

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

    def _open_focus(self):
        dialog = FocusDialog(self.model, self.pet_window)
        dialog.exec()

    def _open_play(self):
        dialog = PlayDialog(self.model, self.pet_window)
        dialog.exec()

    def _on_single_click(self):
        if self.pet_window.isVisible():
            self.pet_window.raise_()
            self.pet_window.activateWindow()
            self.pet_window.play_action("TILT_HEAD", custom_msg="主人在找波可吗？喵呜~ 🐾")

    def _on_tray_activated(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            if not self._is_logically_visible():
                # 宠物不在（被关掉了或老板键隐身中）—— 单击即唤回
                self._toggle_visibility()
                # 记住「这一次 Trigger 已经切过可见性」：
                # Windows 的双击会紧接着再补一个 DoubleClick，
                # 不做这个标记的话，双击就成了「显示 → 立刻隐藏」= 白点两下。
                self._double_click_guard = True
            else:
                # 已经在屏上了 —— 单击只是把窗口叫到前面 + 给个反应
                self._double_click_guard = False
                self._single_click_timer.start(240)
        elif reason == QSystemTrayIcon.ActivationReason.DoubleClick:
            self._single_click_timer.stop()
            if self._double_click_guard:
                # 刚才的 Trigger 已经把宠物放出来了，双击不应该再把它藏回去
                self._double_click_guard = False
                return
            self._toggle_visibility()

    def show_notification(self, title, message, duration_ms=4500):
        """调用 Windows 原生通知中心/气泡吐司提醒"""
        try:
            self.showMessage(title, message, QSystemTrayIcon.MessageIcon.Information, duration_ms)
        except Exception:
            # 气泡弹不出来不该让整条链路断掉，但也别静默吞掉 ——
            # 否则「提醒没出现」这件事永远查不到原因。
            log_exception("PetTrayIcon.show_notification")

    def _exit_app(self):
        self.model.save_to_disk()
        # ⚠️ 便签是 500ms 防抖保存的：用户刚打完字就退出会话，
        # 那 500ms 里的内容根本没落盘 —— 而且是**静默**丢失的。
        # 退出前把防抖定时器停掉并立刻强制写一次。
        memo = getattr(self.pet_window, "memo", None)
        if memo is not None:
            try:
                memo.save_timer.stop()
                memo.save_data()
            except Exception:
                log_exception("PetTrayIcon._exit_app")
        self.app.quit()
