# -*- coding: utf-8 -*-
"""
桌面萌宠 · 波可 —— 主窗口帧率与定时器生命周期回归测试

这一组需要 PyQt6。没有 PyQt6 的环境（比如 CI 的 ubuntu 任务）会自动跳过，
CI 的 Windows 任务会真跑它们（QT_QPA_PLATFORM=offscreen）。

为什么要有这一组：

重绘是这只桌宠最贵的一项开销（实测约 2.9ms/帧）。以前主窗口**无条件**以
60 FPS 重绘 —— 哪怕宠物只是安静地呼吸、什么都不做。于是「一个常驻后台的
桌面挂件」白白占掉将近一个核的四分之一。

现在改成按状态自适应：慢动作（呼吸 / 摆尾 / 踱步 / 探头）30 FPS，
快动作（旋转 / 扑蝶 / 扑鼠 / 拖拽…）60 FPS。

另外还修了两个生命周期问题：
  * 窗口隐藏时帧定时器**照跑不误** —— 唤醒 GUI 线程却一帧都不画；
  * 隐藏后再显示，帧定时器没有重新拉起来。
"""

import os
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

try:
    from PyQt6.QtWidgets import QApplication
    HAS_QT = True
except ImportError:                                   # pragma: no cover
    HAS_QT = False


# ⚠️ QApplication 必须用模块级强引用持有（见 tests/test_qt_dialogs.py 的说明）
_APP = None


def _ensure_app():
    global _APP
    app = QApplication.instance()
    if app is None:
        _APP = QApplication([])
        app = _APP
    return app


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestAdaptiveFrameRate(unittest.TestCase):
    """慢动作 30 FPS / 快动作 60 FPS 的判定。"""

    def setUp(self):
        _ensure_app()
        from pet.window import PetWindow
        self.PetWindow = PetWindow

    def _make_window(self):
        from pet.model import PetModel
        w = self.PetWindow(PetModel())
        self.addCleanup(w.deleteLater)
        return w

    def test_ambient_states_use_30fps(self):
        w = self._make_window()
        for state in ("IDLE", "WALK_LEFT", "WALK_RIGHT", "SIT_WAG_TAIL",
                      "LOOK_AROUND", "PEEK_LEFT", "PEEK_RIGHT"):
            with self.subTest(state=state):
                w.state = state
                self.assertEqual(
                    w._desired_frame_ms(), self.PetWindow.AMBIENT_FRAME_MS,
                    "慢动作状态 %s 应当降到 30 FPS" % state,
                )

    def test_active_states_use_60fps(self):
        w = self._make_window()
        for state in ("HAPPY_SPIN", "CHASE_BUTTERFLY", "CATCH_MOUSE", "PLAY_YARN",
                      "WASH_FACE", "STRETCH_YAWN", "HEAD_BOB_MUSIC", "DRAGGING",
                      "FALLING", "BOUNCE", "TILT_HEAD", "DIZZY"):
            with self.subTest(state=state):
                w.state = state
                self.assertEqual(
                    w._desired_frame_ms(), self.PetWindow.ACTIVE_FRAME_MS,
                    "快动作状态 %s 必须保持 60 FPS" % state,
                )

    def test_sleeping_uses_30fps(self):
        w = self._make_window()
        w.state = "HAPPY_SPIN"
        w.model.is_sleeping = True
        self.assertEqual(w._desired_frame_ms(), self.PetWindow.AMBIENT_FRAME_MS)

    def test_apply_frame_rate_switches_timer(self):
        w = self._make_window()
        w.state = "IDLE"
        w._apply_frame_rate()
        self.assertEqual(w.anim_timer.interval(), self.PetWindow.AMBIENT_FRAME_MS)

        w.state = "HAPPY_SPIN"
        w._apply_frame_rate()
        self.assertEqual(w.anim_timer.interval(), self.PetWindow.ACTIVE_FRAME_MS)

    def test_play_action_switches_to_active_fps_immediately(self):
        """播动作后不该等下一个 tick 才提频 —— 动作本身就是快节奏。"""
        w = self._make_window()
        w.state = "IDLE"
        w._apply_frame_rate()
        self.assertEqual(w.anim_timer.interval(), self.PetWindow.AMBIENT_FRAME_MS)

        w.play_action("HAPPY_SPIN")
        self.assertEqual(w.anim_timer.interval(), self.PetWindow.ACTIVE_FRAME_MS)

    def test_ambient_set_excludes_fast_actions(self):
        """快动作绝不能被误放进慢动作表 —— 否则旋转/扑蝶会变成 30 FPS 的慢动作。"""
        fast = {
            "HAPPY_SPIN", "CHASE_BUTTERFLY", "CATCH_MOUSE", "PLAY_YARN",
            "WASH_FACE", "STRETCH_YAWN", "HEAD_BOB_MUSIC", "TILT_HEAD",
            "DIZZY", "DRAGGING", "FALLING", "BOUNCE",
        }
        self.assertEqual(
            self.PetWindow.AMBIENT_STATES & fast,
            set(),
            "这些快动作被放进了 AMBIENT_STATES —— 它们必须保持 60 FPS",
        )


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestTimerLifecycle(unittest.TestCase):
    """窗口不可见时，帧定时器必须停掉。"""

    def setUp(self):
        _ensure_app()
        from pet.window import PetWindow
        self.PetWindow = PetWindow

    def _make_window(self):
        from pet.model import PetModel
        w = self.PetWindow(PetModel())
        self.addCleanup(w.deleteLater)
        return w

    def test_hide_stops_anim_timer(self):
        w = self._make_window()
        w.show()
        w.anim_timer.start(16)
        self.assertTrue(w.anim_timer.isActive(), "前置条件：定时器应当在运行")

        w.hide()

        self.assertFalse(
            w.anim_timer.isActive(),
            "窗口隐藏后帧定时器必须停 —— 否则每次唤醒 GUI 线程却一帧都不画",
        )

    def test_show_restarts_anim_timer(self):
        w = self._make_window()
        w.show()
        w.hide()
        self.assertFalse(w.anim_timer.isActive())

        w.show()

        self.assertTrue(
            w.anim_timer.isActive(),
            "窗口重新显示后帧定时器必须重新拉起来，否则宠物会彻底不动",
        )

    def test_action_config_is_module_level_constant(self):
        """动作表必须是模块级常量 —— 以前它写在 play_action() 函数体里，
        每次播放动作都要现建一个 13 项 dict + 39 条中文字符串。"""
        from pet.window import ACTION_CONFIG, PetWindow
        self.assertTrue(len(ACTION_CONFIG) > 5, "动作表内容不应为空")
        for key in ("STRETCH_YAWN", "WASH_FACE", "HAPPY_SPIN"):
            self.assertIn(key, ACTION_CONFIG)
            self.assertIn("duration", ACTION_CONFIG[key])
            self.assertIn("sound", ACTION_CONFIG[key])
            self.assertTrue(ACTION_CONFIG[key]["lines"])

    def test_action_config_is_not_mutated_by_play(self):
        """动作表是只读常量 —— 播放动作不能把它改坏。"""
        from pet.window import ACTION_CONFIG
        before = {k: dict(v) for k, v in ACTION_CONFIG.items()}
        from pet.model import PetModel
        w = self.PetWindow(PetModel())
        self.addCleanup(w.deleteLater)
        w.play_action("HAPPY_SPIN")
        w.play_action("WASH_FACE")
        for key, cfg in before.items():
            self.assertEqual(ACTION_CONFIG[key], cfg, "动作表被改动了")


if __name__ == "__main__":
    unittest.main()
