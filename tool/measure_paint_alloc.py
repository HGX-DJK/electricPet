# -*- coding: utf-8 -*-
"""实测每帧的 Qt 对象分配量（不改动生产代码，只在运行时打点计数）。

用法：python tests/measure_paint_alloc.py
"""
import os
import sys
import time

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from pet.console_safe import harden_console  # noqa: E402

# 控制台编码兜底：Windows 控制台可能是 cp1252/cp936，
# 直接 print 中文会抛 UnicodeEncodeError，把「打印一条日志」变成崩溃源。
harden_console()

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtGui import (  # noqa: E402
    QColor, QPen, QBrush, QFont, QLinearGradient, QRadialGradient,
    QPainterPath, QPolygonF,
)
from PyQt6.QtCore import QPointF, QRectF  # noqa: E402

COUNTERS = {}
SITES = {}
_ORIGINALS = {
    "QColor": QColor,
    "QPen": QPen,
    "QBrush": QBrush,
    "QFont": QFont,
    "QPointF": QPointF,
    "QRectF": QRectF,
    "QLinearGradient": QLinearGradient,
    "QRadialGradient": QRadialGradient,
    "QPainterPath": QPainterPath,
    "QPolygonF": QPolygonF,
}
_COUNTERED = {}


def _make_counting(name):
    """造一个「会记账」的子类。

    ⚠️ 不能用普通函数去包：代码里会访问类属性（例如 QFont.Weight.Bold），
    普通函数没有这些属性，一换上去就 AttributeError 直接 abort。
    """
    if name in _COUNTERED:
        return _COUNTERED[name]
    base = _ORIGINALS[name]

    class Counted(base):  # type: ignore[misc, valid-type]
        def __init__(self, *args, **kwargs):
            COUNTERS[name] = COUNTERS.get(name, 0) + 1
            try:
                caller = sys._getframe(1)
                key = (name, os.path.basename(caller.f_code.co_filename), caller.f_lineno)
                SITES[key] = SITES.get(key, 0) + 1
            except Exception:
                pass
            super().__init__(*args, **kwargs)

    Counted.__name__ = name
    _COUNTERED[name] = Counted
    return Counted


def install(namespace):
    for name in list(_ORIGINALS):
        if name in namespace:
            namespace[name] = _make_counting(name)


def reset():
    COUNTERS.clear()
    SITES.clear()


def print_breakdown(frames, title):
    total = sum(COUNTERS.values())
    per_frame = total / float(frames)
    print(f"  单帧分配 {per_frame:.1f} 个 -> 每秒 {per_frame * 30:.0f} 个(按 30FPS 折算)")
    for k in sorted(COUNTERS, key=lambda x: -COUNTERS[x]):
        print(f"    {k:18} {COUNTERS[k]/frames:8.1f} 个/帧")
    print("  分配热点（次/帧）:")
    rows = sorted(SITES.items(), key=lambda kv: -kv[1])[:25]
    for (name, fn, line), n in rows:
        print(f"    {fn}:{line:<6} {name:<18} {n/frames:7.1f}")


def measure_renderer(seconds=1.0):
    from PyQt6.QtGui import QImage, QPainter

    from pet.model import PetModel
    from pet.renderer import PetRenderer

    install(sys.modules["pet.renderer"].__dict__)
    model = PetModel()
    model.skin_id = "cat_black"
    r = PetRenderer(model)

    # 预热：让懒加载的缓存先填上，测的是稳态
    img = QImage(220, 220, QImage.Format.Format_ARGB32_Premultiplied)
    p = QPainter(img)
    r.update_animation(0.016, "IDLE")
    r.render(p, 220, 220, "IDLE", False)
    p.end()

    reset()
    t0 = time.perf_counter()
    frames = 0
    while time.perf_counter() - t0 < seconds:
        img = QImage(220, 220, QImage.Format.Format_ARGB32_Premultiplied)
        p = QPainter(img)
        r.update_animation(0.016, "IDLE")
        r.render(p, 220, 220, "IDLE", False)
        p.end()
        frames += 1
    dt = time.perf_counter() - t0
    print(f"\n=== PetRenderer.render ===")
    print(f"  帧数 {frames}  耗时 {dt:.2f}s  单帧 {dt/frames*1000:.2f}ms  折合 {frames/dt:.0f} FPS")
    print_breakdown(frames, "renderer")


def measure_holo(seconds=1.0):
    from PyQt6.QtGui import QImage, QPainter
    from PyQt6.QtWidgets import QApplication

    app = QApplication.instance() or QApplication([])
    from pet.model import PetModel
    from pet.menus import CyberHoloChamberWidget

    install(sys.modules["pet.menus"].__dict__)
    model = PetModel()
    w = CyberHoloChamberWidget(model)

    # 预热
    img = QImage(240, 245, QImage.Format.Format_ARGB32_Premultiplied)
    p = QPainter(img)
    w.render(p)
    p.end()

    reset()
    t0 = time.perf_counter()
    frames = 0
    while time.perf_counter() - t0 < seconds:
        img = QImage(240, 245, QImage.Format.Format_ARGB32_Premultiplied)
        p = QPainter(img)
        w.render(p)
        p.end()
        frames += 1
    dt = time.perf_counter() - t0
    print(f"\n=== CyberHoloChamberWidget.paintEvent ===")
    print(f"  帧数 {frames}  耗时 {dt:.2f}s  单帧 {dt/frames*1000:.2f}ms  折合 {frames/dt:.0f} FPS")
    print_breakdown(frames, "holo")


def measure_microbench():
    """微基准：单个 Qt 对象的构造成本。

    有了这个数字才能判断「少分配 N 个对象/帧」到底值多少 CPU。
    """
    print("\n=== 单个 Qt 对象构造成本（微基准）===")

    def bench(label, fn, n=30000):
        for _ in range(2000):
            fn()
        t0 = time.perf_counter()
        for _ in range(n):
            fn()
        dt = (time.perf_counter() - t0) / n * 1e6
        print("  %-26s %7.3f us/ea" % (label, dt))
        return dt

    class Plain:
        __slots__ = ("a", "b")

        def __init__(self, a, b):
            self.a = a
            self.b = b

    bench("plain python object", lambda: Plain(1, 2))
    bench("QColor(r,g,b,a)", lambda: QColor(200, 100, 50, 180))
    bench("QColor(hex)", lambda: QColor("#FF8040"))
    bench("QBrush(QColor)", lambda: QBrush(QColor(200, 100, 50, 180)))
    bench("QPen(QColor,1.5)", lambda: QPen(QColor(1, 2, 3), 1.5))
    bench("QRectF", lambda: QRectF(1.0, 2.0, 3.0, 4.0))
    bench("QPointF", lambda: QPointF(1.0, 2.0))
    bench("QRadialGradient", lambda: QRadialGradient(1.0, 2.0, 3.0))
    bench("QPainterPath", lambda: QPainterPath())


if __name__ == "__main__":
    measure_microbench()
    measure_renderer()
    measure_holo()
