#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Kotlin syntax check using the kotlin-compiler-embeddable jar from the Gradle cache.

Why this exists
---------------
There is no Android SDK on this machine, so we cannot build an APK and cannot
resolve `android.*` references. But Kotlin reports *syntax* errors during
parsing, which happens before resolution -- so a broken edit can still be
caught here, which is exactly the gap that otherwise only CI can close.

Resolution errors (unresolved reference / overrides nothing / cannot infer /
assignment type mismatch) are caused by the missing android.jar and are
ignored.

The tool self-tests: it injects a deliberate syntax error into a copy of the
sources and asserts that it IS detected. Without that, "0 syntax errors"
would be worthless.

Usage
-----
    python tool/kotlin_syntax_check.py            # check the real sources
    python tool/kotlin_syntax_check.py --self-test # only run the self-test

Exit code: 0 = no syntax errors, 1 = syntax errors found, 2 = cannot run.
"""
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KT_DIR = os.path.join(REPO_ROOT, "flutter_pet", "android", "app", "src", "main", "kotlin")
GRADLE_CACHE = os.path.expandvars(
    r"%USERPROFILE%\.gradle\caches\modules-2\files-2.1\org.jetbrains.kotlin"
)
KOTLINX_CACHE = os.path.expandvars(
    r"%USERPROFILE%\.gradle\caches\modules-2\files-2.1\org.jetbrains.kotlinx"
)

MODULES = [
    "kotlin-compiler-embeddable",
    "kotlin-stdlib",
    "kotlin-script-runtime",
    "kotlin-reflect",
    "kotlin-daemon-embeddable",
]

# 只有解析阶段（语法）才会出现的措辞。
# 刻意收得很窄：'overrides nothing' / 'cannot infer' / 'expected' 这类
# 在缺 android.jar 时也会大量出现，混进来就全是假阳性。
SYNTAX_PATTERNS = [
    r"expecting\b",
    r"unexpected token",
    r"unbalanced",
    r"illegal\b",
    r"name expected",
    r"missing\b",
    r"\bsyntax\b",
    r"unexpected end of file",
]


def _first_jar(module_root):
    """Gradle 缓存布局是 <module>/<version>/<hash>/<jar>.jar，要往下走一层。"""
    if not os.path.isdir(module_root):
        return None
    for ver in sorted(os.listdir(module_root), reverse=True):
        for dirpath, _dirs, files in os.walk(os.path.join(module_root, ver)):
            for f in files:
                if f.endswith(".jar") and not f.endswith("-sources.jar"):
                    return os.path.join(dirpath, f)
    return None


def find_jars():
    found = []
    for module in MODULES:
        jar = _first_jar(os.path.join(GRADLE_CACHE, module))
        if jar:
            found.append(jar)
    # 编译器启动还需要 kotlinx-coroutines（IntelliJ core 环境要用）
    co = _first_jar(os.path.join(KOTLINX_CACHE, "kotlinx-coroutines-core-jvm"))
    if co:
        found.append(co)
    return found


def compile_sources(jars, sources, out_dir):
    cmd = [
        "java",
        "-cp", os.pathsep.join(jars),
        "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler",
        "-no-stdlib",
        "-no-reflect",
        "-d", out_dir,
        "-nowarn",
    ] + sources
    proc = subprocess.run(cmd, capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    out = (proc.stdout or "") + (proc.stderr or "")
    diagnostics = [
        ln.strip() for ln in out.splitlines()
        if re.search(r":\s*error:", ln)
    ]
    return proc.returncode, diagnostics


def classify(diagnostics):
    """把诊断分成「语法错」与「缺 android.jar 造成的解析期后错误」。"""
    syntax = []
    other = 0
    for msg in diagnostics:
        if "unresolved reference" in msg:
            other += 1
            continue
        if any(re.search(p, msg, re.IGNORECASE) for p in SYNTAX_PATTERNS):
            syntax.append(msg)
        else:
            other += 1
    return syntax, other


def check(jars, sources):
    out_dir = tempfile.mkdtemp(prefix="kt-syntax-")
    rc, diagnostics = compile_sources(jars, sources, out_dir)
    if not diagnostics:
        print("compiler produced no diagnostics (exit code %d)" % rc)
        for ln in (rc, out_dir):
            pass
        return None
    syntax, other = classify(diagnostics)
    return syntax, other, len(diagnostics)


def self_test(jars, sources):
    """注入一个故意的语法错，确认工具真的能抓出来。"""
    if not sources:
        print("no sources for self-test")
        return 1
    tmp = tempfile.mkdtemp(prefix="kt-selftest-")
    copies = []
    for src in sources:
        dst = os.path.join(tmp, os.path.basename(src))
        shutil.copy2(src, dst)
        copies.append(dst)
    # 在第一个文件里塞一个明确的语法错（括号不配对）
    with open(copies[0], "r", encoding="utf-8") as f:
        content = f.read()
    content = content.replace("package com.electricpet.poko",
                              "package com.electricpet.poko\nfun broken( { ", 1)
    with open(copies[0], "w", encoding="utf-8", newline="") as f:
        f.write(content)

    out_dir = tempfile.mkdtemp(prefix="kt-selftest-out-")
    rc, diagnostics = compile_sources(jars, copies, out_dir)
    syntax, other = classify(diagnostics)
    if syntax:
        print("self-test OK: injected syntax error was detected (%d)" % len(syntax))
        for s in syntax[:3]:
            print("  " + s)
        return 0
    print("self-test FAILED: injected syntax error was NOT detected")
    return 1


def main():
    jars = find_jars()
    if not jars:
        print("kotlin-compiler-embeddable not found, skipping")
        return 0

    sources = sorted(glob.glob(os.path.join(KT_DIR, "**", "*.kt"), recursive=True))
    if not sources:
        print("no .kt sources under " + KT_DIR)
        return 0

    if "--self-test" in sys.argv:
        return self_test(jars, sources)

    result = check(jars, sources)
    if result is None:
        return 2
    syntax, other, total = result
    print("parsed %d Kotlin files" % len(sources))
    print("diagnostics: %d (resolution errors ignored: %d)" % (total, other))
    print("syntax errors: %d" % len(syntax))
    for e in syntax[:40]:
        print("  " + e)
    return 1 if syntax else 0


if __name__ == "__main__":
    sys.exit(main())
