#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""画面对比安全网：拿当前 pet/renderer.py 与某个 git 版本**逐像素**对比。

用法：
    python tool/paint_regression_check.py                # 默认跟 git HEAD 比
    python tool/paint_regression_check.py --base v1.0.0  # 跟某个 tag/分支比
    python tool/paint_regression_check.py --base <commit> --path pet/renderer.py

它做的事：
  1. `git show <base>:<path>` 取出基线版本的源码；
  2. 把基线版本写回磁盘，跑一遍 tool/paint_snapshot.py 拿到基线像素摘要；
  3. 把当前版本写回磁盘，再跑一遍拿到当前像素摘要；
  4. 逐状态比对，任何一个像素哈希不同就算失败；
  5. 无论成功失败，最后一定把当前版本原样写回去（并校验字节一致）。

退出码：0 = 画面完全一致；1 = 有差异；2 = 用法/环境问题。
"""
import argparse
import os
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from pet.console_safe import harden_console  # noqa: E402

# 控制台编码兜底：Windows 控制台可能是 cp1252/cp936，
# 直接 print 中文会抛 UnicodeEncodeError，把「打印一条日志」变成崩溃源。
harden_console()

DEFAULT_PATH = "pet/renderer.py"


def run_git(args):
    proc = subprocess.run(
        ["git"] + args, cwd=REPO_ROOT, capture_output=True, text=True, encoding="utf-8"
    )
    if proc.returncode != 0:
        raise RuntimeError("git %s 失败: %s" % (" ".join(args), proc.stderr.strip()))
    return proc.stdout


def snapshot(target_path):
    """对当前磁盘上的 target_path 跑一次像素快照，返回 {状态: 哈希}。"""
    out_txt = os.path.join(tempfile.gettempdir(), "paint_snap_%d.txt" % os.getpid())
    proc = subprocess.run(
        [sys.executable, os.path.join("tool", "paint_snapshot.py"), "--save", out_txt],
        cwd=REPO_ROOT, capture_output=True, text=True, encoding="utf-8",
    )
    if proc.returncode != 0:
        raise RuntimeError("paint_snapshot.py 失败:\n%s\n%s" % (proc.stdout, proc.stderr))
    with open(out_txt, encoding="utf-8") as f:
        snaps = dict(
            line.rstrip("\n").split("=", 1) for line in f if "=" in line
        )
    return snaps


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="HEAD", help="git 基线版本（默认 HEAD）")
    ap.add_argument("--path", default=DEFAULT_PATH, help="要对比的文件")
    args = ap.parse_args()

    target = os.path.join(REPO_ROOT, args.path)
    if not os.path.exists(target):
        print("找不到 %s" % args.path)
        return 2

    with open(target, "rb") as f:
        current_bytes = f.read()

    try:
        baseline_bytes = run_git(["show", "%s:%s" % (args.base, args.path)]).encode("utf-8")
    except RuntimeError as e:
        print("取基线失败：%s" % e)
        return 2

    try:
        with open(target, "wb") as f:
            f.write(baseline_bytes)
        base_snaps = snapshot(args.path)
    finally:
        with open(target, "wb") as f:
            f.write(current_bytes)

    with open(target, "rb") as f:
        if f.read() != current_bytes:
            print("!! 还原后字节不一致，文件可能已被损坏，请立刻检查 git status")
            return 2

    cur_snaps = snapshot(args.path)

    keys = sorted(set(base_snaps) | set(cur_snaps))
    diff = [k for k in keys if base_snaps.get(k) != cur_snaps.get(k)]
    print("对比基线 %s 的 %s：%d 个状态，差异 %d 个" % (args.base, args.path, len(keys), len(diff)))
    for k in diff:
        print("  %s\n    base=%s\n    cur =%s" % (k, base_snaps.get(k), cur_snaps.get(k)))
    return 1 if diff else 0


if __name__ == "__main__":
    sys.exit(main())
