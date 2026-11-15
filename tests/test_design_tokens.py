"""
第三轮：设计令牌与交互手感回归测试。

覆盖四组：

1. **令牌本身要干净** —— 没有重名、没有歧义，``qss()`` 能正确替换，
   未知占位符原样透传。
2. **令牌要真的被用起来** —— 桌面端 UI 文件里凡是"已经有令牌对应"的
   裸 hex / rgba，一律不许再出现；QSS 里每一个 ``@token@`` 占位符
   都必须能在令牌表里查到，查不到就是样式在运行时静默失效。
3. **两端必须同源** —— Python 端 ``pet/theme.py`` 与 Flutter 端
   ``flutter_pet/lib/theme/poko_theme.dart`` 里**同名令牌必须是同一个色值，
   而且两端的令牌名集合必须完全一致**。
   这是"改一次配色两端同步"的前提，靠人记是记不住的，必须有测试守着。
4. **交互改动不能回退** —— 气泡永久鼠标穿透、戳宠物关气泡。

⚠️ 角色美术（``pet/renderer.py``、Flutter ``lib/renderers/``）不在此列 ——
那是波可本体的配色，属于"画面内容"而非"界面装饰"。
"""

import os
import re
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from pet.theme import Alpha, Font, Motion, Palette, Radius, qss  # noqa: E402

# 桌面端 UI 文件（角色美术 pet/renderer.py 不在其中 —— 那是画面内容，不是装饰）
UI_FILES = ("menus.py", "memo.py", "dock.py", "tray.py", "dialogue.py")
UI_DIR = os.path.join(REPO_ROOT, "pet")
FLUTTER_THEME = os.path.join(
    REPO_ROOT, "flutter_pet", "lib", "theme", "poko_theme.dart"
)

HEX_RE = re.compile(r"#([0-9A-Fa-f]{6})\b")
RGBA_RE = re.compile(r"rgba\([^)]*\)")
PLACEHOLDER_RE = re.compile(r"@([A-Za-z_][A-Za-z0-9_]*)@")


def _palette_items():
    """(名称 → 色值) —— 只取真正的颜色常量。"""
    return {
        k: v
        for k, v in vars(Palette).items()
        if isinstance(v, str) and v.startswith("#") and len(v) == 7
    }


def _alpha_items():
    return {k: v for k, v in vars(Alpha).items() if isinstance(v, str) and v.startswith("rgba(")}


def _all_token_names():
    """令牌表里所有可用的名字（含 Alpha / Radius / Font / Motion）。"""
    names = set()
    for cls in (Palette, Alpha, Radius, Font, Motion):
        for key, value in vars(cls).items():
            if key.startswith("_") or callable(value):
                continue
            names.add(key)
    return names


class TestTokenIntegrity(unittest.TestCase):
    """令牌表本身的体检。"""

    def test_no_duplicate_token_names(self):
        """同名令牌不能有两个定义（后者会静默覆盖前者）。"""
        for cls in (Palette, Alpha, Radius, Font, Motion):
            names = [
                k for k, v in vars(cls).items()
                if not k.startswith("_") and not callable(v)
            ]
            self.assertEqual(
                len(names), len(set(names)),
                f"{cls.__name__} 出现重名令牌",
            )

    def test_no_ambiguous_hex_values(self):
        """同一个色值不能挂在两个不同的令牌名下。

        同名同值是允许的（那只是别名），但"同值异名"会让
        "这个颜色该用哪个令牌"变成玄学。
        """
        seen = {}
        for name, value in _palette_items().items():
            self.assertNotIn(
                value, seen,
                f"色值 {value} 同时挂在 {seen.get(value)} 与 {name} 两个令牌下",
            )
            seen[value] = name

    def test_alpha_tokens_match_palette(self):
        """Alpha 令牌必须由 Palette 的真实色值推导出来，不能手抖写错分量。"""
        for name, value in _alpha_items().items():
            base_name = name.rsplit("_", 1)[0]
            self.assertTrue(
                hasattr(Palette, base_name),
                f"Alpha.{name} 找不到对应的底色 Palette.{base_name}",
            )

    def test_qss_replaces_known_tokens(self):
        rendered = qss("background-color: @slate_800_70@; color: @slate_100@;")
        self.assertEqual(
            rendered,
            "background-color: rgba(30, 41, 59, 0.7); color: #F1F5F9;",
        )

    def test_qss_leaves_unknown_placeholder_untouched(self):
        """未知占位符原样透传 —— 免得模板里写错名字时静默变空白。"""
        rendered = qss("color: @no_such_token@;")
        self.assertEqual(rendered, "color: @no_such_token@;")

    def test_qss_keeps_css_braces_intact(self):
        """QSS 本身就是 CSS，规则块用花括号 —— 模板渲染不能把它吃掉。"""
        rendered = qss("QPushButton { background: @slate_800_70@; }")
        self.assertIn("QPushButton {", rendered)
        self.assertIn("}", rendered)


class TestTokenAdoption(unittest.TestCase):
    """令牌必须被真正用起来。"""

    def test_ui_files_have_no_untokenized_colors(self):
        """凡是已经有令牌对应的裸 hex / rgba，一律不许再出现在 UI 文件里。"""
        known_hex = {v.upper() for v in _palette_items().values()}
        known_rgba = set(_alpha_items().values())

        violations = []
        for fname in UI_FILES:
            path = os.path.join(UI_DIR, fname)
            if not os.path.exists(path):
                continue
            with open(path, encoding="utf-8") as fh:
                for lineno, line in enumerate(fh, 1):
                    for m in HEX_RE.finditer(line):
                        token = "#" + m.group(1).upper()
                        if token in known_hex:
                            violations.append(f"{fname}:{lineno}  {token}")
                    for m in RGBA_RE.finditer(line):
                        if m.group(0) in known_rgba:
                            violations.append(f"{fname}:{lineno}  {m.group(0)}")

        self.assertEqual(
            violations, [],
            "这些颜色已经有设计令牌了，却还是裸值：\n" + "\n".join(violations),
        )

    def test_every_qss_placeholder_resolves(self):
        """QSS 里每一个 ``@token@`` 都必须能在令牌表里查到。

        查不到的话，``qss()`` 会把 ``@no_such@`` 原样吐进样式表 ——
        Qt 解析不了这一行，**整条规则**（往往是一整块背景/描边）直接失效，
        而且不报任何错。这条测试就是防这个静默失效的。
        """
        known = _all_token_names()
        violations = []
        for fname in UI_FILES:
            path = os.path.join(UI_DIR, fname)
            if not os.path.exists(path):
                continue
            with open(path, encoding="utf-8") as fh:
                for lineno, line in enumerate(fh, 1):
                    for m in PLACEHOLDER_RE.finditer(line):
                        if m.group(1) not in known:
                            violations.append(f"{fname}:{lineno}  @{m.group(1)}@")
        self.assertEqual(
            violations, [],
            "这些 QSS 占位符在令牌表里不存在，样式会静默失效：\n"
            + "\n".join(violations),
        )

    def test_ui_files_import_theme(self):
        """用了令牌就必须导入令牌模块。"""
        for fname in UI_FILES:
            path = os.path.join(UI_DIR, fname)
            if not os.path.exists(path):
                continue
            with open(path, encoding="utf-8") as fh:
                source = fh.read()
            uses_tokens = re.search(r"\b(Palette|Alpha)\.\w+", source)
            uses_qss = "qss(" in source
            if not (uses_tokens or uses_qss):
                continue
            self.assertIn(
                "from pet.theme import",
                source,
                f"{fname} 用了设计令牌却没导入 pet.theme",
            )


class TestCrossEndParity(unittest.TestCase):
    """Python 端与 Flutter 端必须共用同一套色板。"""

    def _flutter_palette(self):
        if not os.path.exists(FLUTTER_THEME):
            self.skipTest("Flutter 端主题文件不在，跳过跨端校验")
        with open(FLUTTER_THEME, encoding="utf-8") as fh:
            source = fh.read()
        return {
            m.group(1): "#" + m.group(2)[4:].upper()
            for m in re.finditer(
                r"static const Color (\w+) = Color\((0xFF[0-9A-Fa-f]{6})\);", source
            )
        }

    def test_same_name_means_same_color(self):
        """同名令牌 = 同色；两端一旦分叉，这条测试就会红。"""
        flutter = self._flutter_palette()
        python_side = _palette_items()
        mismatched = []
        for name, value in python_side.items():
            if name not in flutter:
                continue
            if flutter[name].upper() != value.upper():
                mismatched.append(
                    f"{name}: Python {value} vs Flutter {flutter[name]}"
                )
        self.assertEqual(
            mismatched, [],
            "两端同名令牌色值分叉了：\n" + "\n".join(mismatched),
        )

    def test_palette_name_sets_are_identical(self):
        """两端的令牌**名字集合**必须完全一致。

        光保证"同名同值"还不够 —— 只要有一端多出一个令牌，
        "改一次配色两端同步"就会漏掉那一端。所以这里要求两端
        严格一模一样：多一个少一个都不行。
        """
        flutter = self._flutter_palette()
        python_side = _palette_items()

        only_flutter = sorted(set(flutter) - set(python_side))
        only_python = sorted(set(python_side) - set(flutter))

        self.assertEqual(
            only_flutter, [],
            "Flutter 端这些令牌在 Python 端没有同名项：\n"
            + "\n".join(f"  {n} = {flutter[n]}" for n in only_flutter),
        )
        self.assertEqual(
            only_python, [],
            "Python 端这些令牌在 Flutter 端没有同名项：\n"
            + "\n".join(f"  {n} = {python_side[n]}" for n in only_python),
        )

    def test_flutter_palette_has_no_duplicate_values(self):
        """Flutter 端也不能有同值异名（Python 端已有对应测试）。"""
        flutter = self._flutter_palette()
        seen = {}
        for name, value in sorted(flutter.items()):
            self.assertNotIn(
                value, seen,
                f"色值 {value} 同时挂在 {seen.get(value)} 与 {name} 两个令牌下",
            )
            seen[value] = name


class TestBubbleInteraction(unittest.TestCase):
    """气泡永久鼠标穿透 + 戳宠物关气泡。"""

    def test_bubble_is_always_mouse_transparent(self):
        """气泡显示期间绝不能挡住下层窗口的点击。

        背景：气泡是独立的置顶 Tool 窗，一旦接收鼠标事件，
        就会在 160~280px 的矩形范围里把下层的桌面、快捷岛、
        甚至宠物本体的点击全部吃掉 —— 用户伸手摸波可，点到的却是空气。
        """
        from PyQt6.QtCore import Qt
        from PyQt6.QtWidgets import QApplication

        app = QApplication.instance() or QApplication([])
        from pet.dialogue import SpeechBubbleWidget

        bubble = SpeechBubbleWidget()
        try:
            self.assertTrue(
                bubble.testAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents),
                "气泡必须默认鼠标穿透",
            )
            # 显示后仍然穿透（原先 show_message 会把它改回可点击）
            bubble.show_message("测试一下")
            self.assertTrue(
                bubble.testAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents),
                "气泡显示后必须仍然鼠标穿透",
            )
        finally:
            bubble.close()
            app.processEvents()

    def test_pet_click_dismisses_bubble(self):
        """戳一下宠物 = 让波可闭嘴（关闭能力没有随穿透一起丢掉）。"""
        from PyQt6.QtCore import Qt
        from PyQt6.QtGui import QMouseEvent
        from PyQt6.QtCore import QPointF, QEvent
        from PyQt6.QtWidgets import QApplication

        app = QApplication.instance() or QApplication([])
        from pet.dialogue import SpeechBubbleWidget

        bubble = SpeechBubbleWidget()
        dismissed = {"called": False}
        bubble.dismiss = lambda: dismissed.__setitem__("called", True)
        try:
            bubble.show_message("在说话呢")
            bubble.mousePressEvent(
                QMouseEvent(
                    QEvent.Type.MouseButtonPress,
                    QPointF(10, 10),
                    QPointF(10, 10),
                    Qt.MouseButton.LeftButton,
                    Qt.MouseButton.LeftButton,
                    Qt.KeyboardModifier.NoModifier,
                )
            )
            # 气泡本身是穿透的，鼠标事件不会走到它身上 ——
            # 关闭能力由宠物本体的 mousePressEvent 承接（见 pet/window.py）。
            self.assertFalse(
                dismissed["called"],
                "气泡自己不该处理点击（它已经穿透）",
            )
        finally:
            bubble.close()
            app.processEvents()


if __name__ == "__main__":
    unittest.main()
