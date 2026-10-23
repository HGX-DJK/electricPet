#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
分析 kotlinc 的编译日志，区分「缺 android.jar 造成的连带报错」和「真正的写错了」。

背景
----
本机没有 Android SDK，kotlinc 编译 Android 工程时会把所有 android.* 引用
都报成 unresolved（因为没有 android.jar）。这些报错是**连带噪音**，
真正有价值的信息淹没在里面。

而下面这类错误恰恰也是 unresolved，却极易被漏看：

    e: .../MainActivity.kt:299:36 Unresolved reference 'CATEGORY_APP_WIDGET'.

    e: .../PokoPetView.kt:367:36 Unresolved reference 'FontMetrics'.

前者是常量名写错了（Intent 上根本没有 CATEGORY_APP_WIDGET），
后者是引入了本机验证不了的跨 API 依赖。
两次都是本地日志里明明写着、却因为"全是 unresolved 就全过滤了"而被漏掉，
最后由 CI 炸出来 —— 一次 CI 往返 5~6 分钟。

本脚本按符号名的形态把 unresolved 分级，把「高度可疑」的单独挑出来。

用法
----
    # 1. 先用 kotlinc 编译（注意 -Width 4000，否则日志被控制台折行截断）
    java -cp <kotlin-compiler.jar> org.jetbrains.kotlin.cli.jvm.K2JVMCompiler \
        <files...> -d <out> -nowarn 2>&1 \
        | ForEach-Object { "$_" } | Out-File -FilePath <log> -Encoding utf8 -Width 4000

    # 2. 再扫这份日志（第二个参数是 kotlin 源码目录，用来解析限定引用）
    python3 tool/kotlin_compile_log_lint.py <log> <kotlin 源码目录>

⚠️ 重要边界
------------
**没有 android.jar 时，本工具只能报出「本项目自己的符号 unresolved」，
无法判定「Android 常量名是否写错」。**

原因：缺 android.jar 时，宿主类（Intent / Paint / View ...）本身就 unresolved，
它下面的成员也一起 unresolved —— 两者在日志里长得一模一样，无法区分。
`Intent.CATEGORY_APP_WIDGET` 这种"常量名写错了"的错误，
正是在**有 android.jar 的环境**里才暴露得出来。

所以：
  - 无 android.jar 的机器上：靠 Dart 守护测试的「Android 静态常量」组
    （维护 Intent 常量白名单）来兜底；
  - 有 Android SDK 的机器上：本工具能自动区分，不需要维护白名单。

退出码：0 = 没有高度可疑项；1 = 有（很可能是真错误）。
"""

import os
import re
import sys

# 纯 Kotlin / JDK 自带、不会因为缺 android.jar 而 unresolved 的包前缀
LOCAL_PACKAGES = (
    'kotlin.', 'kotlinx.', 'java.', 'javax.', 'org.json.',
)

# 本项目自己的类：它们 unresolved 一定是真错误（不依赖 android.jar）
PROJECT_CLASS_HINTS = (
    'FloatingPetService', 'PokoPetView', 'PokoWidgetProvider',
    'OverlayChannel', 'MainActivity', 'HapticPattern', 'PetState',
)

UNRESOLVED_RE = re.compile(r"unresolved reference '([^']+)'")
# 日志行形如：  <path>\MainActivity.kt:299:36: error: unresolved reference 'X'.
ERROR_LINE_RE = re.compile(r'^(?P<file>.+?\.kt):(?P<line>\d+):(?P<col>\d+):\s*(?P<msg>.*)$')


def collect_qualified_refs(source_files):
    """扫描源码里 `Host.SYMBOL` 形式的限定引用，建立 宿主类 -> 成员名 的映射。

    用途：判断某个 unresolved 的全大写符号到底是不是"写错了名字"。
    """
    mapping = {}
    pattern = re.compile(r'\b([A-Z][A-Za-z0-9_]*)\.([A-Z][A-Z0-9_]{2,})\b')
    for path in source_files:
        try:
            with open(path, encoding='utf-8', errors='replace') as fh:
                content = fh.read()
        except OSError:
            continue
        for m in pattern.finditer(content):
            mapping.setdefault(m.group(2), set()).add(m.group(1))
    return mapping


def classify(symbol, unresolved_symbols, qualified_hosts):
    """把一个 unresolved 符号分级。

    返回 'suspicious' / 'project' / 'noise'。

    关键判据：**宿主类是不是也跟着 unresolved 了**。
    缺 android.jar 时 `Intent` 本身也解析不出来，于是
    `Intent.CATEGORY_APP_WIDGET` 里的成员和宿主一起报错 ——
    这时候无法区分"名字写错了"和"整个 android.jar 都没有"。

    只有当宿主类**能**解析（不在 unresolved 集合里）而成员不能时，
    那个成员才是真的写错了 —— 这需要机器上有 android.jar。
    """
    # 本项目自己的类：一定可疑
    if symbol in PROJECT_CLASS_HINTS:
        return 'project'

    # 本地包前缀：不该因为缺 android.jar 而 unresolved
    if any(symbol.startswith(p) for p in LOCAL_PACKAGES):
        return 'project'

    # 全大写（可含下划线）：常量形态。
    # Android 真正的类名是 PascalCase（Color / Paint / View），
    # 常量才是全大写 —— 两者混在一起时才有鉴别力。
    if symbol.upper() == symbol and re.match(r'^[A-Z][A-Z0-9_]*$', symbol):
        hosts = qualified_hosts.get(symbol, set())
        if not hosts:
            # 裸引用（如继承来的 START_STICKY）：宿主未知，保守当连带
            return 'noise'
        if all(h in unresolved_symbols for h in hosts):
            # 宿主类自己也解析不出来 -> 缺 android.jar 的连带，不是写错
            return 'noise'
        # 宿主类能解析，成员却不能 -> 名字真的写错了
        return 'suspicious'

    # PascalCase：类名，多半是缺 android.jar 的连带
    if re.match(r'^[A-Z][A-Za-z0-9]*$', symbol):
        return 'noise'

    # camelCase：小写开头，基本都是宿主类没解析出来导致的成员连带
    return 'noise'


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        print('用法: python3 tool/kotlin_compile_log_lint.py <kotlinc 日志文件> '
              '[kotlin 源码目录]')
        return 2

    log_path = argv[1]
    if not os.path.isfile(log_path):
        print('找不到日志文件: %s' % log_path)
        return 2

    source_files = []
    if len(argv) >= 3 and os.path.isdir(argv[2]):
        for root, _, names in os.walk(argv[2]):
            for nm in names:
                if nm.endswith('.kt'):
                    source_files.append(os.path.join(root, nm))
    qualified_hosts = collect_qualified_refs(source_files)

    with open(log_path, encoding='utf-8', errors='replace') as fh:
        lines = fh.read().split('\n')

    suspicious = []
    project_errors = []
    noise_count = 0
    unresolved_symbols = set()

    for raw in lines:
        m = ERROR_LINE_RE.match(raw.strip())
        if not m:
            continue
        msg = m.group('msg')
        um = UNRESOLVED_RE.search(msg)
        if not um:
            continue
        symbol = um.group(1)
        unresolved_symbols.add(symbol)
        level = classify(symbol, unresolved_symbols, qualified_hosts)
        if level == 'suspicious':
            suspicious.append((m.group('file'), m.group('line'), symbol))
        elif level == 'project':
            project_errors.append((m.group('file'), m.group('line'), symbol, msg))
        else:
            noise_count += 1

    print('== kotlinc 日志体检 ==')
    print('连带噪音（缺 android.jar 造成的 unresolved）: %d 条' % noise_count)

    if project_errors:
        print('\n⚠️  本项目符号 unresolved（一定是真错误）：')
        for f, l, s, msg in project_errors[:40]:
            print('  ! %s:%s  %s' % (f, l, msg))
    else:
        print('本项目符号 unresolved: 0 条 ✓')

    if suspicious:
        print('\n⚠️  高度可疑的 unresolved（宿主类能解析、成员不能 = 名字写错了）：')
        for f, l, s in suspicious[:40]:
            print('  ! %s:%s  unresolved reference \'%s\'' % (f, l, s))
    else:
        print('高度可疑的 unresolved: 0 条')
        if noise_count > 0:
            print('  ⚠️ 注意：当前结论受限于「本机没有 android.jar」——')
            print('     宿主类没解析出来时，它下面的成员也一起 unresolved，')
            print('     两者无法区分。只有在**有 android.jar 的环境**里跑本工具，')
            print('     才可能区分出"常量名写错了"。')
            print('     没有 android.jar 时，请依赖 Dart 守护测试的常量白名单。')

    if suspicious or project_errors:
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
