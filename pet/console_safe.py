# -*- coding: utf-8 -*-
"""控制台输出安全：打印诊断信息本身绝不能把进程带崩。

⚠️ 为什么要这个模块：

Windows 控制台的编码**不是** UTF-8 —— 中文机器是 cp936、西文机器是 cp1252、
CI runner（windows-latest）也是 cp1252。而 Python 的标准输出默认
``errors="strict"``：打印一条含中文的日志就会抛 ``UnicodeEncodeError``。

后果特别糟糕：**「打印一条错误日志」这个动作本身会崩**。
本该报出来的那个错（比如「存档里某个字段不是合法数字」）被彻底盖掉，
调用方只看到一个毫无线索的 UnicodeEncodeError —— 错误处理器自己变成了故障源。

真实案例：``pet/memo.py`` 的字段兜底逻辑本来是对的，
但它那行中文日志在 cp1252 控制台上把整个加载流程带崩了，
CI 上表现为「便签字段兜底」这条测试莫名其妙地 error。

本模块只依赖标准库，因此在没装 PyQt6 的环境里也能被导入与测试。

两把武器：

  * :func:`safe_print` —— 打印单条诊断信息；控制台装不下时降级成
    ``\\uXXXX`` 转义（信息不丢，也不会崩）。
  * :func:`harden_console` —— 把 stdout/stderr 的 ``errors`` 调成
    ``backslashreplace``，一次性给整个进程的所有 print 兜底。
    应用与构建脚本在入口调用一次即可。
"""

import sys

__all__ = ["safe_print", "harden_console"]


def safe_print(*args, **kwargs):
    """打印一条诊断信息，**绝不**因为控制台编码而抛异常。

    控制台编码装不下消息里的字符时（例如 cp1252 碰上中文），
    降级成「装得下的部分 + ``\\uXXXX`` 转义」：信息不丢，也不会崩。

    参数与内置 ``print`` 一致；额外支持 ``file=`` 指定输出流。
    """
    stream = kwargs.pop("file", None)
    if stream is None:
        stream = sys.stdout
    try:
        print(*args, file=stream, **kwargs)
        return
    except UnicodeEncodeError:
        pass

    # 走到这里说明控制台编码装不下 —— 转义后再打一次。
    text = " ".join(str(a) for a in args)
    enc = getattr(stream, "encoding", None) or "ascii"
    try:
        text = text.encode(enc, "backslashreplace").decode(enc, "replace")
    except Exception:
        try:
            text = text.encode("ascii", "backslashreplace").decode("ascii")
        except Exception:
            text = repr(text)
    try:
        print(text, file=stream, **kwargs)
    except Exception:
        # 连降级输出都失败（例如流已关闭）—— 宁可什么都不打，也不能再崩一次。
        pass


def harden_console(encoding=None):
    """把 stdout / stderr 调成「遇到装不下的字符也不报错」。

    默认只改 ``errors``、不改 ``encoding`` —— 保持控制台本来的编码，
    装不下的字符用 ``\\uXXXX`` 转义表示，信息不丢。

    :param encoding: 可选，强制指定编码（如构建脚本用 ``"utf-8"``）。
    """
    for stream in (sys.stdout, sys.stderr):
        if stream is None:
            continue
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            # 不是 TextIOWrapper（例如被替换成了别的流）—— 跳过，不强行改
            continue
        kwargs = {"errors": "backslashreplace"}
        if encoding:
            kwargs["encoding"] = encoding
        try:
            reconfigure(**kwargs)
        except Exception:
            pass
