# -*- coding: utf-8 -*-
"""
桌面萌宠 · 波可 —— Qt 槽函数安全调用层单元测试

设计约束（与 test_pet_model.py 保持一致）：
1. 只用标准库 unittest，不引入 pytest。
2. **本文件不需要 PyQt6**：pet/qt_safe.py 是纯标准库实现，
   所以可以在 ubuntu CI 上直接跑 —— 这也是把它单独拆成一个模块的原因
   （它专门解决「Qt 定时器回调打在已销毁对象上」这类问题，
   而那些问题恰恰是最需要被守住、又最难在无 Qt 环境里复现的）。
3. 无 Qt 的环境也能验证「RuntimeError 被吞、其它异常不被吞」这条关键契约。

运行：
    python -m unittest discover -s tests -t . -v
"""

import os
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from pet.qt_safe import safe_call, safe_slot  # noqa: E402


class TestSafeCall(unittest.TestCase):
    """safe_call：吞掉「C++ 对象已删除」的 RuntimeError，其余照常抛。"""

    def test_none_callable_returns_none(self):
        self.assertIsNone(safe_call(None))

    def test_returns_call_result(self):
        self.assertEqual(safe_call(lambda: 42), 42)

    def test_forwards_args_and_kwargs(self):
        self.assertEqual(safe_call(lambda a, b=0: a + b, 1, b=2), 3)

    def test_swallows_runtime_error(self):
        """Qt 场景的典型崩溃：对象已删除。"""
        def boom():
            raise RuntimeError("wrapped C/C++ object of type QDialog has been deleted")

        self.assertIsNone(safe_call(boom))

    def test_does_not_swallow_other_errors(self):
        """⚠️ 关键契约：其它异常必须照常抛出。

        如果这里也被吞掉，真正的逻辑错误就会变成「查不出来的静默失败」——
        那比原来的崩溃更糟。
        """
        def boom():
            raise ValueError("真的错了")

        with self.assertRaises(ValueError):
            safe_call(boom)

    def test_does_not_swallow_type_error(self):
        def boom():
            raise TypeError("签名不对")

        with self.assertRaises(TypeError):
            safe_call(boom)


class TestSafeSlot(unittest.TestCase):
    """safe_slot：把绑定方法包成可以安全挂到 QTimer 上的零参回调。"""

    def test_slot_returns_call_result(self):
        slot = safe_slot(lambda: "ok")
        self.assertEqual(slot(), "ok")

    def test_slot_swallows_runtime_error(self):
        def boom():
            raise RuntimeError("deleted")

        self.assertIsNone(safe_slot(boom)())

    def test_slot_does_not_swallow_other_errors(self):
        def boom():
            raise KeyError("k")

        with self.assertRaises(KeyError):
            safe_slot(boom)()

    def test_slot_is_zero_arg(self):
        """QTimer.timeout 只接受零参回调。"""
        import inspect
        slot = safe_slot(lambda: None)
        self.assertEqual(len(inspect.signature(slot).parameters), 0)


if __name__ == "__main__":
    unittest.main()
