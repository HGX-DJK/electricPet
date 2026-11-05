# -*- coding: utf-8 -*-
"""
桌面萌宠 · 波可 —— 控制台输出安全单元测试

设计约束（与 test_qt_safe.py 保持一致）：
1. 只用标准库 unittest，不引入 pytest。
2. **本文件不需要 PyQt6**：pet/console_safe.py 是纯标准库实现，
   所以可以在 ubuntu CI 上直接跑。
3. 测试方法名一律用 ASCII（中文放在 reason 与 docstring 里）——
   标识符里带空格会让 Python 直接语法报错。

背景（真实事故）：
    Windows 控制台的编码不是 UTF-8 —— 中文机器 cp936、西文机器 cp1252、
    CI runner（windows-latest）也是 cp1252。而 Python 的标准输出默认
    ``errors="strict"``：打印一条含中文的日志就会抛 ``UnicodeEncodeError``。

    后果特别糟糕：**「打印一条错误日志」这个动作本身会崩**。
    本该报出来的那个错被彻底盖掉 —— 错误处理器自己变成了故障源。

    真实案例：``pet/memo.py`` 的字段兜底逻辑本来是对的，
    但它那行中文日志在 cp1252 控制台上把整个加载流程带崩了，
    CI 上表现为「便签字段兜底」这条测试莫名其妙地 error，
    而真正的问题（存档字段非法）一个字都没打出来。

运行：
    python -m unittest discover -s tests -t . -v
"""

import ast
import io
import os
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from pet.console_safe import harden_console, safe_print  # noqa: E402


def _cp1252_stream():
    """造一个「只能装 ASCII」的输出流，模拟西文 Windows 控制台 / CI runner。"""
    buf = io.BytesIO()
    stream = io.TextIOWrapper(buf, encoding="cp1252", errors="strict")
    return buf, stream


class TestSafePrint(unittest.TestCase):
    """safe_print：控制台装不下消息时降级，而不是抛异常。"""

    def test_control_plain_print_really_breaks_on_cp1252(self):
        """⚠️ 先证明这个场景是真的 —— 否则后面的测试都在测一个不存在的问题。"""
        buf, stream = _cp1252_stream()
        with self.assertRaises(UnicodeEncodeError):
            print("[Memo] 便签存档字段 'x' 不是合法数字", file=stream)
        stream.flush()

    def test_safe_print_survives_cp1252(self):
        buf, stream = _cp1252_stream()
        safe_print("[Memo] 便签存档字段 'x' 不是合法数字，已忽略: 'abc'", file=stream)
        stream.flush()

        out = buf.getvalue().decode("cp1252")
        self.assertIn("Memo", out)
        # 装不下的字符用 \uXXXX 转义表示 —— 信息不丢
        self.assertIn("\\u", out)

    def test_ascii_message_is_unchanged(self):
        buf, stream = _cp1252_stream()
        safe_print("[Memo] field 'x' is not a valid number", file=stream)
        stream.flush()

        out = buf.getvalue().decode("cp1252")
        self.assertIn("[Memo] field 'x' is not a valid number", out)

    def test_chinese_exception_message_survives(self):
        """最常见的触发场景：把异常对象直接塞进消息里。"""
        buf, stream = _cp1252_stream()
        safe_print("[Memo] 读取便签存档失败: 文件名里有非法字符", file=stream)
        stream.flush()
        self.assertTrue(buf.getvalue())

    def test_defaults_to_stdout(self):
        """不传 file 时应该写到当前 stdout，而不是什么都不做。"""
        old = sys.stdout
        buf = io.StringIO()
        sys.stdout = buf
        try:
            safe_print("hello")
        finally:
            sys.stdout = old
        self.assertIn("hello", buf.getvalue())


class TestHardenConsole(unittest.TestCase):
    """harden_console：给整个进程的所有 print 一次性兜底。"""

    def test_print_of_chinese_no_longer_raises(self):
        old_errors = None
        try:
            old_errors = getattr(sys.stdout, "errors", None)
            harden_console()
            # 之前这一步在 cp1252 控制台上会抛 UnicodeEncodeError
            print("[Memo] 便签存档字段 'x' 不是合法数字，已忽略: 'abc'")
        finally:
            if old_errors is not None and hasattr(sys.stdout, "reconfigure"):
                try:
                    sys.stdout.reconfigure(errors=old_errors)
                except Exception:
                    pass

    def test_tolerates_stream_without_reconfigure(self):
        """被替换成普通对象的 stdout 也不能让 harden_console 自己崩掉。"""

        class _Fake:
            pass

        old = sys.stdout
        sys.stdout = _Fake()
        try:
            harden_console()  # 不能抛
        finally:
            sys.stdout = old

    def test_accepts_explicit_encoding(self):
        harden_console(encoding="utf-8")
        print("普通输出仍然是正常的")


class TestRepoHasNoRawNonAsciiPrint(unittest.TestCase):
    """全仓守护：运行期代码里不许再直接 print 非 ASCII。

    ⚠️ 这条守护的由来：pet/memo.py 曾经直接 print 中文，
    在 cp1252 控制台（CI runner 就是）上把整个测试进程带崩 ——
    而且崩的地方正好是「报错的代码」，真正的问题一个字都没打出来。

    规则：
      * ``pet/`` 包内（会打进 EXE 的运行期代码）：非 ASCII 必须走 ``safe_print``。
      * 仓库根的脚本（main.py / build_*.py / installer_gui.py）与 ``tool/``
        下的工具脚本：要么走 ``safe_print``，要么文件里必须调用过 ``harden_console()``。
    """

    RUNTIME_DIR = "pet"
    ROOT_SCRIPTS = ["main.py", "build_exe.py", "build_installer.py", "installer_gui.py"]
    TOOL_DIR = "tool"

    @staticmethod
    def _call_name(node):
        fn = node.func
        return getattr(fn, "id", None) or getattr(fn, "attr", None)

    @staticmethod
    def _has_non_ascii_literal(node):
        for n in ast.walk(node):
            if isinstance(n, ast.Constant) and isinstance(n.value, str):
                if any(ord(ch) > 127 for ch in n.value):
                    return True
        return False

    def _scan(self, path):
        """返回 [(行号, print种类)]，列出所有含非 ASCII 的打印调用。"""
        with io.open(path, encoding="utf-8") as f:
            source = f.read()
        tree = ast.parse(source)
        hits = []
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            name = self._call_name(node)
            if name not in ("print", "safe_print"):
                continue
            if self._has_non_ascii_literal(node):
                hits.append((node.lineno, name))
        return hits, source

    def test_pet_package_has_no_raw_non_ascii_print(self):
        pet_dir = os.path.join(REPO_ROOT, self.RUNTIME_DIR)
        offenders = []
        for fname in sorted(os.listdir(pet_dir)):
            if not fname.endswith(".py"):
                continue
            path = os.path.join(pet_dir, fname)
            hits, _ = self._scan(path)
            for lineno, name in hits:
                if name != "safe_print":
                    offenders.append("%s/%s:%d" % (self.RUNTIME_DIR, fname, lineno))

        self.assertEqual(
            offenders, [],
            msg="★ 运行期代码里出现了直接 print 非 ASCII：%s。"
                "控制台编码不是 UTF-8（cp1252/cp936）时会抛 UnicodeEncodeError，"
                "把「打印错误日志」这个动作本身变成崩溃源。请改用 safe_print()。" % offenders,
        )

    def test_root_scripts_must_harden_console(self):
        offenders = []
        for fname in self.ROOT_SCRIPTS:
            path = os.path.join(REPO_ROOT, fname)
            if not os.path.exists(path):
                continue
            hits, source = self._scan(path)
            if not hits:
                continue
            if "harden_console(" not in source:
                offenders.append("%s:%s" % (fname, [ln for ln, _ in hits]))

        self.assertEqual(
            offenders, [],
            msg="★ 这些脚本会打印非 ASCII，但入口没有调用 harden_console()：%s。"
                "在 cp1252 控制台（CI runner 就是）上会崩。" % offenders,
        )

    def test_tool_scripts_must_harden_console(self):
        """tool/ 下的工具脚本同样要加固 —— 它们也跑在开发机的 Windows 控制台上。"""
        tool_dir = os.path.join(REPO_ROOT, self.TOOL_DIR)
        if not os.path.isdir(tool_dir):
            self.skipTest("没有 tool 目录")
        offenders = []
        for fname in sorted(os.listdir(tool_dir)):
            if not fname.endswith(".py"):
                continue
            path = os.path.join(tool_dir, fname)
            hits, source = self._scan(path)
            if not hits:
                continue
            if "harden_console(" not in source:
                offenders.append("%s/%s:%s" % (self.TOOL_DIR, fname, [ln for ln, _ in hits]))

        self.assertEqual(
            offenders, [],
            msg="★ 这些工具脚本会打印非 ASCII，但没有调用 harden_console()：%s。"
                "在 cp1252 控制台上会崩。" % offenders,
        )

    def test_detector_itself_is_not_a_noop(self):
        """检测器不能空转 —— 造一个假的违规样本，确认它能抓到。"""
        sample = "print('便签字段非法')\n"
        tree = ast.parse(sample)
        hits = []
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and self._call_name(node) == "print":
                if self._has_non_ascii_literal(node):
                    hits.append(node.lineno)
        self.assertEqual(hits, [1], msg="检测器没抓到人为造的违规样本")


if __name__ == "__main__":
    unittest.main()
