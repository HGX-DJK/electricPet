# -*- coding: utf-8 -*-
"""
桌面萌宠 · 波可 —— 渲染器缓存回归测试

这一组测的是 pet/renderer.py 的「绘制缓存」行为，需要 PyQt6。
没有 PyQt6 的环境（比如 CI 的 ubuntu 任务）会自动跳过，
CI 的 Windows 任务会真跑它们（QT_QPA_PLATFORM=offscreen）。

为什么要有这一组：

之前 pet/renderer.py 只有一句「import 得进去」的冒烟检查，于是下面这个
缺陷能长期潜伏 —— 它不会让程序崩、不会让画面变丑，只是**悄悄**地：

  * 每帧重建一堆永远缓存不上的渐变（阴影半径、光环半径、爪爪位置…），
    纯浪费 CPU；
  * 每一次重建都往 _GRAD_BRUSH_CACHE 里塞一条**永不命中**的死条目，
    几十秒就把缓存塞满（实测 25 秒到 4096 条上限），
    之后连玩家刚换的新皮肤 / 新头饰的渐变都再也缓存不上了。

而且画面「看起来完全正常」，所以没人会发现。

这几个测试把「缓存必须命中」「缓存必须有界」钉死成可执行断言，
以后谁再把动画量写进缓存键，CI 会立刻指出来。
"""

import os
import sys
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

try:
    from PyQt6.QtCore import QPointF
    from PyQt6.QtGui import QImage, QPainter, QRadialGradient, QLinearGradient
    from PyQt6.QtWidgets import QApplication
    HAS_QT = True
except ImportError:                                   # pragma: no cover
    HAS_QT = False


# ⚠️ QApplication 必须用模块级强引用持有。
#    写成函数里的局部变量的话，函数一返回它就被 GC 回收了，
#    紧接着构造 QWidget 就会抛「Must construct a QApplication before a QWidget」。
_APP = None


def _ensure_app():
    global _APP
    app = QApplication.instance()
    if app is None:
        _APP = QApplication([])
        app = _APP
    return app


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestPaintCache(unittest.TestCase):
    """缓存助手本身的契约。"""

    def setUp(self):
        _ensure_app()
        from pet import renderer
        self.R = renderer
        # 缓存是模块级全局的，这里做快照/还原，避免用例之间互相干扰
        self._snapshot = {
            "COLOR": dict(renderer._COLOR_CACHE),
            "BRUSH": dict(renderer._BRUSH_CACHE),
            "PEN": dict(renderer._PEN_CACHE),
            "GRAD": dict(renderer._GRAD_BRUSH_CACHE),
        }

    def tearDown(self):
        R = self.R
        R._COLOR_CACHE.clear()
        R._COLOR_CACHE.update(self._snapshot["COLOR"])
        R._BRUSH_CACHE.clear()
        R._BRUSH_CACHE.update(self._snapshot["BRUSH"])
        R._PEN_CACHE.clear()
        R._PEN_CACHE.update(self._snapshot["PEN"])
        R._GRAD_BRUSH_CACHE.clear()
        R._GRAD_BRUSH_CACHE.update(self._snapshot["GRAD"])

    def test_solid_brush_is_cached(self):
        a = self.R._solid_brush(255, 0, 0, 200)
        b = self.R._solid_brush(255, 0, 0, 200)
        self.assertIs(a, b, "同参数的实心画刷必须复用同一个对象")
        c = self.R._solid_brush(255, 0, 0, 201)
        self.assertIsNot(a, c, "不同参数必须是不同对象")

    def test_color_is_cached(self):
        self.assertIs(self.R._color("#FF8040"), self.R._color("#FF8040"))
        self.assertIsNot(self.R._color("#FF8040"), self.R._color("#FF8041"))

    def test_pen_is_cached(self):
        a = self.R._pen("#123456", 1.5)
        b = self.R._pen("#123456", 1.5)
        self.assertIs(a, b)
        self.assertIsNot(a, self.R._pen("#123456", 2.0))

    def test_grad_brush_is_cached(self):
        stops = [(0.0, self.R._color(255, 0, 0)), (1.0, self.R._color(0, 0, 255))]
        a = self.R._grad_brush(QRadialGradient, (10, 20, 30), stops)
        b = self.R._grad_brush(QRadialGradient, (10, 20, 30), stops)
        self.assertIs(a, b, "同几何同色标的渐变画刷必须复用")

    def test_grad_brush_distinguishes_geometry(self):
        stops = [(0.0, self.R._color(255, 0, 0)), (1.0, self.R._color(0, 0, 255))]
        a = self.R._grad_brush(QRadialGradient, (10, 20, 30), stops)
        b = self.R._grad_brush(QRadialGradient, (11, 20, 30), stops)
        self.assertIsNot(a, b, "几何不同必须取到不同画刷")

    def test_grad_brush_handles_unhashable_geometry(self):
        """QPointF 不可哈希 —— 键里必须折算成坐标元组，不能直接抛 TypeError。"""
        stops = [(0.0, self.R._color(255, 0, 0)), (1.0, self.R._color(0, 0, 255))]
        a = self.R._grad_brush(QRadialGradient, (QPointF(5, 6), 12), stops)
        b = self.R._grad_brush(QRadialGradient, (QPointF(5, 6), 12), stops)
        self.assertIs(a, b)

    def test_dynamic_grad_brush_never_cached(self):
        """「几何逐帧会变」的渐变必须走不缓存通道，否则会污染缓存。"""
        R = self.R
        before = len(R._GRAD_BRUSH_CACHE)
        stops = [(0.0, R._color(255, 0, 0)), (1.0, R._color(0, 0, 255))]
        a = R._grad_brush_dynamic(QRadialGradient, (1, 2, 3), stops)
        b = R._grad_brush_dynamic(QRadialGradient, (1, 2, 3), stops)
        self.assertIsNot(a, b, "动态渐变每次都应当是新的对象")
        self.assertEqual(
            len(R._GRAD_BRUSH_CACHE), before,
            "动态渐变绝不能进缓存 —— 否则每次未命中都会塞一条永不命中的死条目",
        )

    def test_xshift_helper_routes_by_shift(self):
        """耳廓位移为 0 时走缓存，有位移时走不缓存通道。"""
        R = self.R
        stops = [(0.0, R._color(255, 0, 0)), (1.0, R._color(0, 0, 255))]
        a = R._grad_brush_xshift(QLinearGradient, (-46, -63, -14, -26), 0, stops)
        b = R._grad_brush_xshift(QLinearGradient, (-46, -63, -14, -26), 0, stops)
        self.assertIs(a, b, "没有位移时几何恒定，必须能命中缓存")

        before = len(R._GRAD_BRUSH_CACHE)
        c = R._grad_brush_xshift(QLinearGradient, (-46, -63, -14, -26), 3.5, stops)
        d = R._grad_brush_xshift(QLinearGradient, (-46, -63, -14, -26), 3.5, stops)
        self.assertIsNot(c, d, "有位移时几何在变，不能命中缓存")
        self.assertEqual(len(R._GRAD_BRUSH_CACHE), before, "有位移时不得进缓存")


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestRendererCacheStaysBounded(unittest.TestCase):
    """回归主测：长时间绘制不能让渐变缓存无限膨胀。

    这正是本次修复的那个缺陷 —— 动画量被写进缓存键，导致
    每帧都未命中、每帧都塞一条死条目。修复前几十秒就能把缓存塞满 4096 条，
    之后玩家换新皮肤 / 新头饰的渐变再也缓存不上。
    """

    STATES = [
        "IDLE", "WALK_LEFT", "HAPPY_SPIN", "CATCH_MOUSE", "PLAY_YARN",
        "DRAGGING", "CHASE_BUTTERFLY", "WASH_FACE", "TILT_HEAD", "HEAD_BOB_MUSIC",
    ]

    def setUp(self):
        _ensure_app()
        from pet import renderer
        self.R = renderer
        self._before = len(renderer._GRAD_BRUSH_CACHE)

    def _render_state(self, state, frames):
        from pet.model import PetModel
        model = PetModel()
        model.skin_id = "cat_black"
        r = self.R.PetRenderer(model)
        img = QImage(220, 220, QImage.Format.Format_ARGB32_Premultiplied)
        for _ in range(frames):
            p = QPainter(img)
            r.update_animation(0.016, state)
            r.render(p, 220, 220, state, False)
            p.end()
            img.fill(0)

    def test_cache_stays_bounded_across_states(self):
        """反复绘制各状态后，渐变缓存必须仍然有界。"""
        for state in self.STATES:
            self._render_state(state, 30)

        growth = len(self.R._GRAD_BRUSH_CACHE) - self._before
        self.assertLess(
            growth, 600,
            "渐变缓存增长了 %d 条 —— 动画量又被写进缓存键了？"
            "（未命中的渐变每次都会塞一条永不命中的死条目）" % growth,
        )

    def test_repeated_same_state_does_not_grow_cache(self):
        """同一个状态反复绘制，缓存应该早就稳定下来。"""
        self._render_state("HAPPY_SPIN", 30)
        settled = len(self.R._GRAD_BRUSH_CACHE)
        self._render_state("HAPPY_SPIN", 60)
        growth = len(self.R._GRAD_BRUSH_CACHE) - settled
        self.assertLess(
            growth, 120,
            "同一个状态继续绘制时缓存又涨了 %d 条 —— "
            "说明还有几何逐帧在变的渐变走了缓存通道" % growth,
        )


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestRendererSmoke(unittest.TestCase):
    """各状态都能画出来（别让重构把某个状态画崩了）。"""

    def test_all_states_render(self):
        _ensure_app()
        from pet.model import PetModel
        from pet.renderer import PetRenderer
        model = PetModel()
        model.skin_id = "cat_black"
        r = PetRenderer(model)
        states = [
            "IDLE", "SIT_WAG_TAIL", "WASH_FACE", "STRETCH_YAWN", "CHASE_BUTTERFLY",
            "CATCH_MOUSE", "PLAY_YARN", "HAPPY_SPIN", "HEAD_BOB_MUSIC",
            "DOZE_OFF", "LOOK_AROUND", "DRAGGING", "FALLING", "BOUNCE",
            "PEEK_LEFT", "PEEK_RIGHT", "TILT_HEAD", "DIZZY", "CARDBOARD_BOX",
        ]
        img = QImage(220, 220, QImage.Format.Format_ARGB32_Premultiplied)
        for state in states:
            with self.subTest(state=state):
                img.fill(0)
                p = QPainter(img)
                try:
                    r.update_animation(0.016, state)
                    r.render(p, 220, 220, state, False)
                finally:
                    p.end()

    def test_paws_render_with_local_origin(self):
        """爪子改成了「局部坐标 + painter 平移」绘制 —— 各状态都得画得出来。"""
        _ensure_app()
        from pet.model import PetModel
        from pet.renderer import PetRenderer
        model = PetModel()
        model.skin_id = "cat_black"
        r = PetRenderer(model)
        img = QImage(220, 220, QImage.Format.Format_ARGB32_Premultiplied)
        for state in ("WASH_FACE", "STRETCH_YAWN", "CHASE_BUTTERFLY",
                      "CATCH_MOUSE", "PLAY_YARN", "HAPPY_SPIN", "DRAGGING",
                      "WALK_LEFT"):
            with self.subTest(state=state):
                img.fill(0)
                p = QPainter(img)
                try:
                    r.update_animation(0.016, state)
                    r.render(p, 220, 220, state, False)
                finally:
                    p.end()


if __name__ == "__main__":
    unittest.main()
