# -*- coding: utf-8 -*-
"""
桌面萌宠 · 波可 —— Qt 对话框生命周期回归测试

这一组测的是「Qt 模块的行为」，需要 PyQt6。
没有 PyQt6 的环境（比如 CI 的 ubuntu 任务）会自动跳过，
CI 的 Windows 任务会真跑它们（QT_QPA_PLATFORM=offscreen）。

为什么要有这一组：
  之前 pet/menus.py 3036 行只有一句「import 得进去」的冒烟检查，
  于是下面这些缺陷能长期潜伏，直到用户手动点开某个面板才暴露：
    * FocusDialog 关闭后 1 秒刷新定时器还在跑，每秒重建一遍隐藏的 UI；
      而且对话框是以「临时对象 + 父对象是主窗口」的方式打开的，
      Python 临时对象被回收后 C++ 对象还活着 —— 每开一次就漏一个。
    * QTimer.singleShot(ms, self.accept) 在对话框销毁后触发，
      回调到已删除的 C++ 对象上抛 RuntimeError；
      而 PyQt6 里槽函数抛出的未捕获异常会直接 abort 掉整个进程。

运行：
    python -m unittest discover -s tests -t . -v
    （Windows 无头环境请先设 QT_QPA_PLATFORM=offscreen）
"""

import os
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

try:
    from PyQt6.QtCore import QTimer
    from PyQt6.QtWidgets import QApplication
    HAS_QT = True
except ImportError:                                   # pragma: no cover
    HAS_QT = False


# ⚠️ QApplication 必须用模块级强引用持有。
#    写成函数里的局部变量的话，函数一返回它就被 GC 回收了，
#    紧接着构造 QWidget 就会抛「Must construct a QApplication before a QWidget」。
_APP = None


def _ensure_app():
    """拿到（或创建）QApplication。offscreen 平台下不需要真实显示器。"""
    global _APP
    app = QApplication.instance()
    if app is None:
        _APP = QApplication([])
        app = _APP
    return app


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestDialogTimerCleanup(unittest.TestCase):
    """基类统一收口：对话框关闭时必须停掉自己持有的定时器。"""

    def setUp(self):
        _ensure_app()
        from pet.menus import ModernBaseDialog
        self.dialog_cls = ModernBaseDialog

    def _make_dialog(self):
        dlg = self.dialog_cls(title="测试", subtitle="副标题", icon_emoji="🐾")
        self.addCleanup(dlg.deleteLater)
        return dlg

    def test_done_stops_child_timers(self):
        """accept / reject / close 三条路径最终都走 done()，所以停表只需一处。"""
        dlg = self._make_dialog()
        timer = QTimer(dlg)
        timer.timeout.connect(lambda: None)
        timer.start(50)
        self.assertTrue(timer.isActive(), "前置条件：定时器应当处于运行状态")

        dlg.done(0)

        self.assertFalse(
            timer.isActive(),
            "对话框关闭后子定时器必须停掉 —— 否则它会一直重建已经隐藏的 UI",
        )

    def test_accept_stops_child_timers(self):
        dlg = self._make_dialog()
        timer = QTimer(dlg)
        timer.timeout.connect(lambda: None)
        timer.start(50)

        dlg.accept()

        self.assertFalse(timer.isActive())

    def test_reject_stops_child_timers(self):
        dlg = self._make_dialog()
        timer = QTimer(dlg)
        timer.timeout.connect(lambda: None)
        timer.start(50)

        dlg.reject()

        self.assertFalse(timer.isActive())

    def test_schedule_close_uses_child_timer(self):
        """_schedule_close 建的定时器必须挂在对话框下，才能被 done() 收掉。

        用 QTimer.singleShot 建的定时器没有父对象 —— 对话框销毁后它照样触发，
        回调到已删除的 C++ 对象上会抛 RuntimeError。
        """
        dlg = self._make_dialog()
        timer = dlg._schedule_close(10000)
        self.assertIs(timer.parent(), dlg, "延时关闭定时器必须以对话框为父对象")
        self.assertTrue(timer.isSingleShot())
        self.assertTrue(timer.isActive())

        dlg.done(0)
        self.assertFalse(timer.isActive())


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestFocusDialogTimer(unittest.TestCase):
    """FocusDialog 的 1 秒刷新定时器：关闭后必须停。"""

    class _StubModel:
        """够用就行的模型替身。"""
        is_studying = True
        study_duration = 25 * 60
        study_time_left = 25 * 60

        def cancel_focus_timer(self):
            pass

        def __getattr__(self, name):
            return None

    def setUp(self):
        _ensure_app()

    def test_refresh_timer_stops_on_close(self):
        from pet.menus import FocusDialog
        # pet_window 传 None：QDialog 的 parent 必须是真正的 QWidget 或 None，
        # 而 FocusDialog 的构建过程并不依赖 pet_window（只有 _start_focus /
        # _stop_focus 会用到，而它们不在构造路径上）。
        dlg = FocusDialog(self._StubModel(), None)
        self.addCleanup(dlg.deleteLater)

        # 专注中才会启动刷新定时器
        if not dlg._refresh_timer.isActive():
            dlg._refresh_timer.start(1000)
        self.assertTrue(dlg._refresh_timer.isActive(), "前置条件：专注中定时器应在运行")

        dlg.reject()

        self.assertFalse(
            dlg._refresh_timer.isActive(),
            "关闭专注面板后刷新定时器必须停 —— "
            "否则它会每秒重建一遍已经隐藏的 UI，每开一次漏一个",
        )


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestMemoFieldCoercion(unittest.TestCase):
    """便签存档的数值字段：单个字段非法只能影响它自己。"""

    def test_valid_values(self):
        from pet.memo import PetStickyNote
        self.assertEqual(PetStickyNote._to_int(100), 100)
        self.assertEqual(PetStickyNote._to_int("120"), 120)
        self.assertEqual(PetStickyNote._to_int(80.7), 80)

    def test_none_returns_none(self):
        from pet.memo import PetStickyNote
        self.assertIsNone(PetStickyNote._to_int(None))

    def test_illegal_values_return_none(self):
        """以前这里 int() 会抛 ValueError，把整个 load_data 带崩。"""
        from pet.memo import PetStickyNote
        self.assertIsNone(PetStickyNote._to_int("abc", "x"))
        self.assertIsNone(PetStickyNote._to_int({"a": 1}, "x"))
        self.assertIsNone(PetStickyNote._to_int([], "x"))


class TestSourceGuards(unittest.TestCase):
    """源码级守护：防止上面这些修复被改回去。

    纯文本检查，不需要 PyQt6 —— 所以在 ubuntu CI 上也在跑。
    """

    def _read(self, rel):
        with open(os.path.join(REPO_ROOT, rel.replace("/", os.sep)), "r", encoding="utf-8") as f:
            return f.read()

    def test_no_bare_single_shot_accept(self):
        """QTimer.singleShot(ms, self.accept) 必须换成 _schedule_close(ms)。

        singleShot 建的定时器没有父对象，对话框销毁后照样触发，
        回调到已删除的 C++ 对象上抛 RuntimeError（PyQt6 会 abort 整个进程）。
        """
        src = self._read("pet/menus.py")
        self.assertNotIn(
            "QTimer.singleShot(1400, self.accept)",
            src,
            "PlayDialog 仍在用无父对象的 singleShot，必须换成 self._schedule_close(...)",
        )
        self.assertNotIn(
            "QTimer.singleShot(1200, self.accept)",
            src,
            "PlayDialog 仍在用无父对象的 singleShot，必须换成 self._schedule_close(...)",
        )

    def test_base_dialog_stops_timers_on_done(self):
        src = self._read("pet/menus.py")
        self.assertIn(
            "def done(self",
            src,
            "ModernBaseDialog 必须覆写 done()，统一停掉子定时器",
        )
        self.assertIn(
            "self.findChildren(QTimer)",
            src,
            "done() 里必须遍历并停掉所有子 QTimer",
        )

    def test_dialog_open_lambdas_are_wrapped(self):
        """菜单里「关掉菜单后再开对话框」的延时 lambda 必须包 safe_slot。"""
        for rel in ("pet/menus.py", "pet/dock.py"):
            src = self._read(rel)
            self.assertNotIn(
                "QTimer.singleShot(30, lambda:",
                src,
                f"{rel} 里还有裸的 singleShot(30, lambda) —— 主窗口被销毁时会 abort 进程",
            )

    def test_memo_load_data_is_not_silently_swallowed(self):
        """便签存档读失败必须有日志，不能 except: pass。"""
        src = self._read("pet/memo.py")
        self.assertIn(
            "[Memo] 读取便签存档失败",
            src,
            "load_data 的异常必须留日志，否则用户完全无感",
        )
        self.assertIn(
            "[Memo] 便签存档字段",
            src,
            "单个字段非法时必须有日志",
        )


if __name__ == "__main__":
    unittest.main()
