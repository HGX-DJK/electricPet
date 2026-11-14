# -*- coding: utf-8 -*-
"""运行时诊断：把「被吞掉的异常」变成可查的日志。

⚠️ 背景：

桌面宠物有两处**高频热循环** —— 16ms 的帧循环
(``pet/window.py:_on_animation_tick``) 和 1s 的状态循环
(``pet/window.py:_on_status_tick``)。它们都必须**绝不能把 GUI 带崩**
（一个异常不应该让整个桌宠消失），所以外面都包了 try/except。

但如果 except 里只写 ``pass``、或者只打一句 ``str(e)``，出问题时用户看到的
现象就是「宠物不动了 / 不出声了 / 硬件读数全是 0」，而日志里一个字都没有 ——
排查时毫无线索，只能靠猜。

本模块提供两个东西：

  * :func:`log_exception` —— 带**完整堆栈**记录一条异常，并按时间窗限流
    （既不会刷屏，也不会把事件循环拖慢）；
  * :func:`append_crash_log` —— 往存档目录下的 ``crash.log`` 追加文本。

日志文件与 ``main.py`` 里未捕获异常用的 ``crash.log`` 是**同一个**，
用户只需要看一个地方。

本模块只依赖标准库，因此在没装 PyQt6 的环境里也能被导入与测试。
"""

import os
import sys
import time
import traceback

from pet.console_safe import safe_print

__all__ = ["log_exception", "append_crash_log", "crash_log_path"]

# 限流状态：context -> 上次记录的时间戳
_LAST_LOG_TIME = {}


def crash_log_path() -> str:
    """崩溃日志的绝对路径（%APPDATA%\\ElectricPet\\crash.log）。"""
    base = os.environ.get("APPDATA") or os.path.expanduser("~")
    return os.path.join(base, "ElectricPet", "crash.log")


def append_crash_log(text: str) -> bool:
    """往崩溃日志追加一段文本。返回是否写成功。

    写日志本身绝不能成为故障源 —— 任何异常都在内部吞掉。
    """
    try:
        path = crash_log_path()
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8") as f:
            f.write(text)
            f.write("\n")
            f.flush()
        return True
    except Exception:
        return False


def log_exception(context: str, exc=None, min_interval: float = 5.0) -> bool:
    """记录一条异常诊断信息（带完整堆栈），并做频率限流。

    :param context: 出错位置的标签，例如 ``"PetWindow.AnimationTick"``。
    :param exc: 要记录的异常；默认取当前正在处理的异常（``sys.exc_info()``）。
    :param min_interval: 同一条 context 的最小记录间隔（秒）。
    :return: 真正写入了日志返回 True，被限流挡掉返回 False。
    """
    if exc is None:
        exc = sys.exc_info()[1]

    now = time.time()
    last = _LAST_LOG_TIME.get(context, 0.0)
    if now - last < min_interval:
        return False
    _LAST_LOG_TIME[context] = now

    try:
        tb = traceback.format_exc()
    except Exception:
        tb = "<traceback unavailable>\n"

    header = "--- [%s] %s: %s @ %s ---" % (
        context,
        type(exc).__name__ if exc is not None else "UnknownError",
        exc,
        time.strftime("%Y-%m-%d %H:%M:%S"),
    )

    # 控制台一份（safe_print 保证不会因编码而崩），日志文件一份
    safe_print(header)
    safe_print(tb.rstrip())
    append_crash_log(header + "\n" + tb.rstrip())
    return True
