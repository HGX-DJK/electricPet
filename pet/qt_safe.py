"""Qt 槽函数 / 定时器回调里的安全调用包装。

⚠️ 为什么要这个模块：

  1) PyQt6 里，槽函数中抛出**未捕获的异常**会走 ``qFatal()``，
     直接把整个进程 abort 掉 —— 不是打印一段 traceback 就完事。
     这意味着一个定时器回调的小失误就能让整个桌面萌宠闪退。

  2) Qt 定时器回调最容易踩这个坑：回调触发时，目标对象可能已经被销毁了。
     此时调用绑定方法会抛::

         RuntimeError: wrapped C/C++ object of type XXX has been deleted

  3) 这个模块**只依赖标准库**，所以在没有装 PyQt6 的环境
     （比如 CI 的 ubuntu 任务、纯逻辑单元测试）里也能被导入与测试。

只吞 RuntimeError —— 其它异常照常往上抛。
否则真正的逻辑错误会被一起吞掉，变成查不出来的静默失败。
"""


def safe_call(fn, *args, **kwargs):
    """调用 ``fn``，吞掉「底层 C++ 对象已被删除」引发的 RuntimeError。

    :param fn: 可调用对象（为 None 时直接返回 None）
    :return: fn 的返回值；若对象已销毁则返回 None
    """
    if fn is None:
        return None
    try:
        return fn(*args, **kwargs)
    except RuntimeError:
        return None


def safe_slot(fn):
    """把 ``fn`` 包成一个可以安全挂到 QTimer 上的零参回调。

    ⚠️ 用途：``QTimer.singleShot(ms, bound_method)`` 在目标对象被销毁后
    触发时，绑定方法会抛 RuntimeError；而 PyQt6 里槽函数抛出的未捕获异常
    会 abort 掉整个进程。用它包一层就安全了。

    >>> slot = safe_slot(lambda: None)
    >>> slot() is None
    True
    """
    def _slot():
        return safe_call(fn)
    return _slot
