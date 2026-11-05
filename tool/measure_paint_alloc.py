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

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtGui import QColor, QPen, QBrush, QFont, QLinearGradient, QRadialGradient  # noqa: E402
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
    print(f"  单帧分配 {total} 个 -> 每秒 {total * frames / 1.0 * 30:.0f} 个(按 30FPS 折算)")
    for k in sorted(COUNTERS, key=lambda x: -COUNTERS[x]):
        print(f"    {k:18} {COUNTERS[k]/frames:8.1f} 个/帧")
    print("  分配热点（次/帧）:")
    rows = sorted(SITES.items(), key=lambda kv: -kv[1])[:12]
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


if __name__ == "__main__":
    measure_renderer()
    measure_holo()
