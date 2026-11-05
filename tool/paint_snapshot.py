#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""绘制快照：用固定动画时间 + 固定随机种子渲染若干状态，输出每个状态的 PNG 摘要。

用途：给「绘制性能优化」当安全网。
改 pet/renderer.py 的绘制代码之前先跑一次拿到基线，改完再跑一次，
两份摘要必须**逐字节一致** —— 一致就说明画面没变，只是少分配了对象。

用法：
    python tool/paint_snapshot.py               # 打印摘要
    python tool/paint_snapshot.py --save a.txt  # 存到文件，便于前后对比
    python tool/paint_snapshot.py --compare a.txt b.txt
"""
import hashlib
import os
import random
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtCore import QBuffer  # noqa: E402
from PyQt6.QtGui import QImage, QPainter  # noqa: E402

SIZE = 220
ANIM_TIME = 1.234
SKINS = ["cat_black", "cat_ragdoll", "cat_white"]
STATES = [
    "IDLE",
    "SIT_WAG_TAIL",
    "WASH_FACE",
    "STRETCH_YAWN",
    "CHASE_BUTTERFLY",
    "CATCH_MOUSE",
    "PLAY_YARN",
    "HAPPY_SPIN",
    "HEAD_BOB_MUSIC",
    "DOZE_OFF",
    "LOOK_AROUND",
    "DRAGGING",
]


def render_all():
    from pet.model import PetModel
    from pet.renderer import PetRenderer

    out = {}
    for skin in SKINS:
        model = PetModel()
        model.skin_id = skin
        r = PetRenderer(model)
        for state in STATES:
            # 固定动画时刻 + 固定随机种子 -> 同一状态每次渲染出来的像素完全一致
            r.anim_time = ANIM_TIME
            r.particles = []
            random.seed(12345)
            img = QImage(SIZE, SIZE, QImage.Format.Format_ARGB32_Premultiplied)
            img.fill(0)
            p = QPainter(img)
            try:
                r.render(p, SIZE, SIZE, state, False)
            except Exception as e:  # 某些状态在无头环境可能不支持
                # 必须先把 painter 关掉再走 —— 否则 QImage 被回收时 painter 还在画，
                # Qt 会直接 abort（"Cannot destroy paint device that is being painted"），
                # 把一个本该被记成 "ERROR" 的软失败变成进程崩溃。
                p.end()
                out["%s/%s" % (skin, state)] = "ERROR:%s" % type(e).__name__
                continue
            p.end()
            buf = QBuffer()
            buf.open(QBuffer.OpenModeFlag.WriteOnly)
            img.save(buf, "PNG")
            data = bytes(buf.data())
            buf.close()
            out["%s/%s" % (skin, state)] = hashlib.sha256(data).hexdigest()
    return out


def main():
    args = sys.argv[1:]
    snaps = render_all()

    if "--compare" in args:
        i = args.index("--compare")
        a_path, b_path = args[i + 1], args[i + 2]
        with open(a_path, encoding="utf-8") as f:
            a = dict(
                line.rstrip("\n").split("=", 1) for line in f
                if "=" in line
            )
        with open(b_path, encoding="utf-8") as f:
            b = dict(
                line.rstrip("\n").split("=", 1) for line in f
                if "=" in line
            )
        keys = sorted(set(a) | set(b))
        diff = [k for k in keys if a.get(k) != b.get(k)]
        print("对比 %d 个状态，差异 %d 个" % (len(keys), len(diff)))
        for k in diff:
            print("  %s\n    before=%s\n    after =%s" % (k, a.get(k), b.get(k)))
        return 1 if diff else 0

    lines = ["%s=%s" % (k, v) for k, v in sorted(snaps.items())]
    text = "\n".join(lines)
    if "--save" in args:
        path = args[args.index("--save") + 1]
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text + "\n")
        print("已写入 " + path + "（%d 个状态）" % len(lines))
    else:
        print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
