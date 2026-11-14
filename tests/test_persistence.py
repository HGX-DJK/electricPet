# -*- coding: utf-8 -*-
"""
桌面萌宠 · 波可 —— 存档持久化与诊断日志回归测试

存档这一层的要求很简单，但一旦不满足，用户丢的是**几天的心血**：

  * 写盘必须是**原子**的 —— 先写 .tmp 再 os.replace。
    直接 open(path, "w") 是「先清空原文件再写」，
    写到一半崩了 / 断电了，存档就只剩半截 JSON，重启后内容全没。
  * 写盘失败必须留日志 —— 静默失败会让用户以为存上了，其实重启就没了。

这一组需要 PyQt6（便签是 QWidget）。没有 PyQt6 的环境会自动跳过，
CI 的 Windows 任务会真跑它们（QT_QPA_PLATFORM=offscreen）。
"""

import io
import json
import os
import shutil
import sys
import tempfile
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

try:
    from PyQt6.QtWidgets import QApplication
    HAS_QT = True
except ImportError:                                   # pragma: no cover
    HAS_QT = False


_APP = None


def _ensure_app():
    global _APP
    app = QApplication.instance()
    if app is None:
        _APP = QApplication([])
        app = _APP
    return app


class TestDiagnostics(unittest.TestCase):
    """诊断日志：必须带堆栈、必须限流、必须不依赖 PyQt6。"""

    def setUp(self):
        from pet import diagnostics
        self.diag = diagnostics
        self._saved = dict(diagnostics._LAST_LOG_TIME)
        diagnostics._LAST_LOG_TIME.clear()

    def tearDown(self):
        self.diag._LAST_LOG_TIME.clear()
        self.diag._LAST_LOG_TIME.update(self._saved)

    def test_log_exception_writes_traceback(self):
        """必须记录**完整堆栈**，不能只有一句 str(e)。"""
        captured = []
        original = self.diag.append_crash_log
        self.diag.append_crash_log = lambda text: captured.append(text) or True
        self.addCleanup(setattr, self.diag, "append_crash_log", original)

        try:
            raise ValueError("boom")
        except ValueError as e:
            self.assertTrue(self.diag.log_exception("Test.Ctx", e))

        self.assertEqual(len(captured), 1)
        text = captured[0]
        self.assertIn("ValueError", text)
        self.assertIn("boom", text)
        self.assertIn("Traceback", text, "必须带完整堆栈，否则排查时毫无线索")
        self.assertIn("Test.Ctx", text)

    def test_log_exception_is_rate_limited(self):
        """同一个 context 必须限流 —— 热循环里报错不能刷屏。"""
        captured = []
        original = self.diag.append_crash_log
        self.diag.append_crash_log = lambda text: captured.append(text) or True
        self.addCleanup(setattr, self.diag, "append_crash_log", original)

        err = ValueError("boom")
        first = self.diag.log_exception("Test.Ctx", err, min_interval=60.0)
        second = self.diag.log_exception("Test.Ctx", err, min_interval=60.0)
        third = self.diag.log_exception("Test.Other", err, min_interval=60.0)

        self.assertTrue(first)
        self.assertFalse(second, "限流窗口内的重复异常必须被挡掉")
        self.assertTrue(third, "不同 context 各自独立限流")
        self.assertEqual(len(captured), 2)

    def test_crash_log_path_under_appdata(self):
        path = self.diag.crash_log_path()
        self.assertTrue(path.endswith("crash.log"))
        self.assertIn("ElectricPet", path)

    def test_append_crash_log_never_raises(self):
        """写日志本身绝不能成为故障源。"""
        self.assertIsInstance(self.diag.append_crash_log("hello"), bool)


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestMemoAtomicSave(unittest.TestCase):
    """便签存档：原子写 + 不留临时文件。"""

    def setUp(self):
        _ensure_app()
        self.tmpdir = tempfile.mkdtemp(prefix="poko_memo_")
        self.addCleanup(shutil.rmtree, self.tmpdir, True)

    def _make_memo(self):
        from pet.model import PetModel
        from pet.memo import PetStickyNote
        model = PetModel()
        # 把存档重定向到临时目录，别碰用户真实的存档
        model.app_dir = self.tmpdir
        memo = PetStickyNote(model, None)
        self.addCleanup(memo.deleteLater)
        return memo

    def test_save_leaves_valid_json_and_no_tmp(self):
        memo = self._make_memo()
        memo.text_edit.setPlainText("波可的今日份小鱼干 🐟")
        memo.save_data()

        self.assertTrue(os.path.exists(memo.memo_file))
        with io.open(memo.memo_file, "r", encoding="utf-8") as f:
            data = json.load(f)          # 必须是完整可解析的 JSON
        self.assertEqual(data["content"], "波可的今日份小鱼干 🐟")

        self.assertFalse(
            os.path.exists(memo.memo_file + ".tmp"),
            "写盘完成后不能留下 .tmp 残骸",
        )

    def test_save_uses_tmp_then_replace(self):
        """存档必须先写 .tmp 再 os.replace —— 直接覆盖写会先清空原文件。"""
        memo = self._make_memo()
        memo.text_edit.setPlainText("first")
        memo.save_data()
        memo.text_edit.setPlainText("second")
        memo.save_data()

        with io.open(memo.memo_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        self.assertEqual(data["content"], "second")
        self.assertFalse(os.path.exists(memo.memo_file + ".tmp"))

    def test_source_uses_atomic_replace(self):
        """源码级守护：别把原子写改回直接覆盖。"""
        with io.open(os.path.join(REPO_ROOT, "pet", "memo.py"), "r", encoding="utf-8") as f:
            src = f.read()
        self.assertIn(
            "os.replace", src,
            "pet/memo.py 必须用 .tmp + os.replace 做原子写",
        )


if __name__ == "__main__":
    unittest.main()
