#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Kotlin JVM 签名冲突扫描器（Platform declaration clash 等价检查）。

背景
----
CI 的 `compileReleaseKotlin` 阶段报过三次同类错误：

    Platform declaration clash: The following declarations have the same
    JVM signature (setNightMode(Z)V):
        fun `<set-isNightMode>`(value: Boolean): Unit defined in ...PokoPetView
        fun setNightMode(enabled: Boolean): Unit defined in ...PokoPetView

根因是 public 属性 `isNightMode` 的隐式 setter，其 JVM 签名就是
`setNightMode(Z)V`（Kotlin 会剥掉 is 前缀），和手写的同名函数完全撞车。

这类错误属于编译器 **backend 阶段** 的问题：开发机缺 android.jar 时，
frontend 阶段就已经报了一千多条 unresolved，根本走不到 backend，
所以本地 kotlinc 永远看不到它，只能等 CI 炸出来。

本脚本不依赖 android.jar，直接从源码推导 JVM 签名，在 CI 里抢在
Kotlin 编译之前把这类错误拦下来。

它和 Dart 守护测试
（`flutter_pet/test/floating_overlay_native_test.dart` 的
「Kotlin JVM 签名冲突」组）是**两套独立实现**，互为交叉验证：
任一套的解析漏洞都不会导致 CI 静默放行。

判据（对齐 Kotlin/JVM 编译器 backend 的行为）
-------------------------------------------
1. 只比较**同一个类**内部（嵌套类、companion object 各自成域）；
2. public / internal 之间会冲突；private 与非 private 不冲突；
3. 属性生成隐式访问器（JVM 完整描述符）：
     var x: T          -> setter  setX(LT;)V      getter  getX()LT;
     val x: T          ->                              getter  getX()LT;
     var isX: Boolean  -> setter  setX(Z)V          getter  isX()Z
     val isX: Boolean  ->                              getter  isX()Z
   （Boolean 且 is 前缀时 getter 保留 isX；非 Boolean 时 getter 叫 getX，
     setter 永远叫 setX）
4. 函数 f(a: A): R 的签名是 f(LA;)LR;；
5. 主构造函数的 val/var 参数也是属性，一并纳入。

用法
----
    python3 tool/kotlin_jvm_clash_scan.py flutter_pet/android/app/src/main/kotlin
    python3 tool/kotlin_jvm_clash_scan.py --self-test

退出码：0 = 无冲突；1 = 发现冲突或自检失败。
"""

import os
import re
import sys
from collections import defaultdict

# ---------------------------------------------------------------- 词法清洗


def strip_lits(src):
    """把注释和字符串字面量替换成等长空格，保持行结构与列位置不变。"""
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ''
        if c == '/' and nxt == '/':
            while i < n and src[i] != '\n':
                out.append(' ')
                i += 1
        elif c == '/' and nxt == '*':
            while i < n:
                out.append('\n' if src[i] == '\n' else ' ')
                if src[i] == '*' and i + 1 < n and src[i + 1] == '/':
                    out.append(' ')
                    i += 1
                    break
                i += 1
            i += 1
        elif c == '"':
            if src[i:i + 3] == '"""':
                out.append('   ')
                i += 3
                while i < n:
                    if src[i:i + 3] == '"""':
                        out.append('   ')
                        i += 3
                        break
                    out.append('\n' if src[i] == '\n' else ' ')
                    i += 1
            else:
                out.append(' ')
                i += 1
                while i < n and src[i] != '"':
                    if src[i] == '\\':
                        out.append(' ')
                        i += 1
                        if i < n:
                            out.append(' ')
                            i += 1
                        continue
                    out.append('\n' if src[i] == '\n' else ' ')
                    i += 1
                if i < n:
                    out.append(' ')
                    i += 1
        elif c == "'":
            out.append(' ')
            i += 1
            while i < n and src[i] != "'":
                if src[i] == '\\':
                    out.append(' ')
                    i += 1
                    if i < n:
                        out.append(' ')
                        i += 1
                    continue
                out.append(' ')
                i += 1
            if i < n:
                out.append(' ')
                i += 1
        else:
            out.append(c)
            i += 1
    return ''.join(out)


# ---------------------------------------------------------------- 类型擦除

PRIMS = {
    'Boolean': 'Z', 'Int': 'I', 'Long': 'J', 'Float': 'F', 'Double': 'D',
    'Char': 'C', 'Short': 'S', 'Byte': 'B',
}

ARRAY_PRIMS = {
    'IntArray': 'I', 'FloatArray': 'F', 'BooleanArray': 'Z', 'LongArray': 'J',
    'DoubleArray': 'D', 'ByteArray': 'B', 'CharArray': 'C', 'ShortArray': 'S',
}

STDLIB_JVM_NAMES = {
    'String': 'java/lang/String',
    'Any': 'java/lang/Object',
    'Nothing': 'java/lang/Object',
    'List': 'java/util/List',
    'MutableList': 'java/util/List',
    'ArrayList': 'java/util/ArrayList',
    'Map': 'java/util/Map',
    'MutableMap': 'java/util/Map',
    'HashMap': 'java/util/HashMap',
    'Set': 'java/util/Set',
    'MutableSet': 'java/util/Set',
    'HashSet': 'java/util/HashSet',
    'Pair': 'kotlin/Pair',
    'Triple': 'kotlin/Triple',
}


def erase(t):
    """Kotlin 类型 -> JVM 擦除描述符。"""
    t = (t or '').strip()
    if not t:
        return '?'
    t = re.sub(r'@\w+(\.[\w.]+)?(\([^)]*\))?', ' ', t).strip()
    t = t.replace('?', '')
    t = re.sub(r'\s+', ' ', t).strip()
    t = re.sub(r'^(out|in)\s+', '', t).strip()
    if '->' in t:
        return 'Lkotlin/jvm/functions/FunctionN;'
    if '<' in t:
        base = t[:t.index('<')]
        return erase(base)
    if t in PRIMS:
        return PRIMS[t]
    if t == 'Unit':
        return 'V'
    if t in ARRAY_PRIMS:
        return '[' + ARRAY_PRIMS[t]
    if t in STDLIB_JVM_NAMES:
        return 'L' + STDLIB_JVM_NAMES[t] + ';'
    if '.' in t:
        t = t.split('.')[-1]
    return 'L' + t + ';'


# ---------------------------------------------------------------- 结构扫描

CLASS_RE = re.compile(
    r'^(?:@\w+(?:\([^)]*\))?\s+)*'
    r'(?P<vis>public|private|internal|protected)?\s*'
    r'(?:(?:data|enum|sealed|annotation|value|open|abstract|inner|expect|actual)\s+)*'
    r'(?P<kind>class|object|interface)\s+'
    r'(?P<name>[A-Za-z_]\w*)'
)

COMPANION_RE = re.compile(
    r'^(?:@\w+(?:\([^)]*\))?\s+)*'
    r'(?P<vis>public|private|internal|protected)?\s*'
    r'(?:(?:data|enum|sealed|annotation|value|open|abstract|inner|expect|actual)\s+)*'
    r'companion\s+object\b'
)

MOD_PREFIX_RE = re.compile(
    r'^(?P<mods>(?:(?:@\w+(?:\([^)]*\))?\s+)'
    r'|(?:(?:public|private|internal|protected|override|open|final|suspend|inline|operator|'
    r'infix|tailrec|external|lateinit|const|abstract|expect|actual|companion|data|enum|sealed|'
    r'annotation|value|inner|vararg|crossinline|noinline)\s+))*)'
)


class ClassInfo:
    def __init__(self, name, kind='class'):
        self.name = name
        self.kind = kind
        self.props = []   # (name, type, vis, is_var)
        self.funs = []    # (name, [paramtypes], ret, vis)

    def report(self):
        return '   - %-46s 属性 %3d  函数 %3d' % (self.name, len(self.props), len(self.funs))


def find_matching(code, open_idx):
    """返回 code 中与 open_idx 处 '(' 配对的 ')' 下标；找不到返回 -1。"""
    depth = 0
    i = open_idx
    while i < len(code):
        if code[i] == '(':
            depth += 1
        elif code[i] == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def split_params(params):
    """按顶层逗号切分参数列表。"""
    parts = []
    depth = 0
    cur = ''
    for ch in params:
        if ch in '(<[':
            depth += 1
        elif ch in ')>]':
            depth = depth - 1 if depth > 0 else 0
        if ch == ',' and depth == 0:
            parts.append(cur)
            cur = ''
        else:
            cur += ch
    parts.append(cur)
    return parts


def _infer_type(init):
    """从初始化表达式粗略推断类型：Foo(...) -> Foo；否则 Any。"""
    if not init:
        return 'Any'
    m = re.match(r'^([A-Z]\w*)\s*\(', init.strip())
    return m.group(1) if m else 'Any'


def collect_one(line, cls):
    """从一行源码里抽出属性 / 函数，塞进所属类。"""
    if not line or line.startswith('//') or line.startswith('*'):
        return
    pm = MOD_PREFIX_RE.match(line)
    if not pm:
        return
    mods = pm.group('mods') or ''
    vis = 'public'
    for w in ('public', 'private', 'internal', 'protected'):
        if re.search(r'\b' + w + r'\b', mods):
            vis = w
    rest = line[pm.end():].strip()
    if not rest:
        return
    kw = rest.split()[0]

    if kw in ('var', 'val'):
        m = re.match(r'^(var|val)\s+([A-Za-z_]\w*)\s*(?::\s*(.+?))?(?:\s*=\s*(.*))?$', rest)
        if m:
            typ = (m.group(3) or '').strip() or _infer_type(m.group(4))
            cls.props.append((m.group(2), typ, vis, m.group(1) == 'var'))
        return

    if kw != 'fun':
        return
    # 扩展函数（带接收者）不属于宿主类的成员
    if re.match(r'^fun\s+(?:<[^>]*>\s*)?[A-Za-z_]\w*\.[A-Za-z_]\w*\s*\(', rest):
        return
    m = re.match(r'^fun\s+(?:<[^>]*>\s*)?([A-Za-z_]\w*)\s*\(([^)]*)\)\s*(?::\s*([^=]+?))?\s*(?:=|\{|$)', rest)
    if not m:
        return
    name = m.group(1)
    params = m.group(2).strip()
    ret = (m.group(3) or 'Unit').strip()
    types = []
    if params:
        for p in split_params(params):
            pt = re.match(
                r'^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:vararg\s+)?'
                r'(?:[A-Za-z_]\w*\s*:\s*)?(.+?)\s*(?:=.*)?$', p)
            if pt:
                types.append(pt.group(1).strip())
    cls.funs.append((name, types, ret, vis))


def _primary_ctor_params(code, lines, i, name_end_in_line):
    """取 class 声明后的主构造函数参数里的 val/var，返回 [(name, type)]。"""
    offset = sum(len(lines[k]) + 1 for k in range(i))
    open_idx = code.find('(', offset + name_end_in_line)
    if open_idx < 0:
        return []
    close_idx = find_matching(code, open_idx)
    if close_idx < 0:
        return []
    out = []
    for p in split_params(code[open_idx + 1:close_idx]):
        p = p.strip()
        pm = re.match(
            r'^(?:@\w+(?:\([^)]*\))?\s+)*(val|var)\s+([A-Za-z_]\w*)'
            r'\s*(?::\s*(.+?))?(?:\s*=.*)?$', p)
        if pm:
            out.append((pm.group(2), (pm.group(3) or 'Any').strip()))
    return out


def build_structure(code):
    """按花括号深度定位类体，收集其直接成员。"""
    lines = code.split('\n')
    n = len(lines)

    depth_before = []
    d = 0
    for raw in lines:
        depth_before.append(d)
        d += raw.count('{') - raw.count('}')

    classes = []
    class_at_base_depth = {}

    i = 0
    while i < n:
        line = lines[i].strip()
        base = depth_before[i]

        cm = COMPANION_RE.match(line)
        if cm:
            owner = class_at_base_depth.get(base - 1, 'Companion')
            cls = ClassInfo(owner + '.Companion', 'companion')
            body_end = i
            j = i + 1
            while j < n and depth_before[j] > base:
                body_end = j
                j += 1
            for k in range(i + 1, body_end + 1):
                if depth_before[k] == base + 1:
                    collect_one(lines[k].strip(), cls)
            classes.append(cls)
            i += 1
            continue

        m = CLASS_RE.match(line)
        if not m:
            i += 1
            continue

        name = m.group('name')
        class_at_base_depth[base] = name
        cls = ClassInfo(name, m.group('kind'))

        body_end = i
        j = i + 1
        while j < n and depth_before[j] > base:
            body_end = j
            j += 1

        for pname, ptype in _primary_ctor_params(code, lines, i, m.end()):
            cls.props.append((pname, ptype, 'public', True))

        for k in range(i + 1, body_end + 1):
            if depth_before[k] == base + 1:
                collect_one(lines[k].strip(), cls)

        classes.append(cls)
        i += 1
    return classes


# ---------------------------------------------------------------- 签名


def accessor_descriptors(name, typ, is_var):
    """返回属性生成的 JVM 方法：(jvmName, descriptor, 描述)。"""
    out = []
    setter_base = name[2:] if (name.startswith('is') and len(name) > 2 and name[2].isupper()) else name
    setter_name = 'set' + setter_base[0].upper() + setter_base[1:]
    getter_name = 'get' + name[0].upper() + name[1:]
    if erase(typ) == 'Z' and name.startswith('is') and len(name) > 2 and name[2].isupper():
        getter_name = name
    out.append((getter_name, '()' + erase(typ), 'getter of `%s`' % name))
    if is_var:
        out.append((setter_name, '(' + erase(typ) + ')V', 'setter of `%s`' % name))
    return out


def fun_descriptor(types, ret):
    return '(' + ','.join(erase(t) for t in types) + ')' + erase(ret)


def scan_source(source):
    """扫描一段 Kotlin 源码，返回所有类。"""
    return build_structure(strip_lits(source))


def find_clashes(classes):
    """在已扫描出的类里找 JVM 签名冲突，返回问题描述列表。"""
    problems = []
    for cls in classes:
        sigs = defaultdict(list)
        for name, typ, vis, is_var in cls.props:
            for jvmname, desc, desc_txt in accessor_descriptors(name, typ, is_var):
                sigs[(jvmname, desc)].append((desc_txt, vis))
        for name, types, ret, vis in cls.funs:
            sigs[(name, fun_descriptor(types, ret))].append(('fun `%s`' % name, vis))
        for key, items in sigs.items():
            if len(items) < 2:
                continue
            pub = [d for d, v in items if v in ('public', 'internal')]
            if len(pub) >= 2:
                problems.append('%s: %s -> 同一 JVM 签名 %s%s'
                                % (cls.name, ', '.join(pub), key[0], key[1]))
    return problems


# ---------------------------------------------------------------- 自检

SELF_TEST_SOURCES = {
    # 必须报出：public var isNightMode 与 fun setNightMode 撞车
    'must_report_setter': '''
class Clashy {
    var isNightMode: Boolean = false
    fun setNightMode(enabled: Boolean) {
        isNightMode = enabled
    }
}
''',
    # 必须报出：getter 撞 getter
    'must_report_getter': '''
class ClashyGetter {
    val petName: String = "x"
    fun getPetName(): String = petName
}
''',
    # 必须报出：companion object 内部也必须参与检查
    'must_report_companion': '''
class WithCompanion {
    companion object {
        var isNightMode: Boolean = false
        fun setNightMode(enabled: Boolean) {
        }
    }
}
''',
    # 不得报出：private 成员、参数类型不同、跨类同名、嵌套类作用域隔离
    'must_not_report': '''
class Safe1 {
    var isNightMode: Boolean = false
    private fun setNightMode(enabled: Boolean) {
    }
}
class Safe2 {
    private var isAnimationEnabled: Boolean = true
    fun setAnimationEnabled(enabled: Boolean) {
    }
}
class Safe3 {
    var nightMode: Boolean = false
    fun setNightMode(label: String) {
    }
}
class Safe4 {
    var currentAction: Int = 0
    inner class Inner {
        fun setCurrentAction(action: Int) {
        }
    }
}
class Safe5 {
    var isNightMode: Boolean = false
}
class Safe6 {
    fun setNightMode(enabled: Boolean) {
    }
}
''',
}


def self_test():
    """验证扫描器本身有效 —— 防止解析失效导致 CI 静默放行。"""
    failures = []
    for name, src in SELF_TEST_SOURCES.items():
        problems = find_clashes(scan_source(src))
        if name.startswith('must_report'):
            if not problems:
                failures.append('自检样本 `%s` 本应报出冲突，但扫描器什么都没报' % name)
            else:
                print('  自检通过（应报）: %s -> %s' % (name, problems[0]))
        else:
            if problems:
                failures.append('自检样本 `%s` 不应报冲突，但报了: %s' % (name, problems))
            else:
                print('  自检通过（不应报）: %s' % name)

    if failures:
        print('\n扫描器自检失败：')
        for f in failures:
            print('  ! ' + f)
        return 1
    print('扫描器自检全部通过')
    return 0


# ---------------------------------------------------------------- 入口


def collect_files(base):
    files = []
    if os.path.isfile(base):
        return [base]
    for root, _, names in os.walk(base):
        for nm in names:
            if nm.endswith('.kt'):
                files.append(os.path.join(root, nm))
    return files


def main(argv):
    if len(argv) >= 2 and argv[1] == '--self-test':
        print('== Kotlin JVM 冲突扫描器自检 ==')
        return self_test()

    if len(argv) < 2:
        print(__doc__)
        print('用法: python3 tool/kotlin_jvm_clash_scan.py <kotlin 源码目录> | --self-test')
        return 2

    base = argv[1]
    files = collect_files(base)
    if not files:
        print('在 %s 下没找到任何 .kt 文件' % base)
        return 2

    all_classes = []
    for f in files:
        with open(f, encoding='utf-8') as fh:
            all_classes += scan_source(fh.read())

    problems = find_clashes(all_classes)
    total_props = sum(len(c.props) for c in all_classes)
    total_funs = sum(len(c.funs) for c in all_classes)

    if problems:
        print('发现 %d 处潜在 Platform declaration clash：' % len(problems))
        for p in problems:
            print('  ! ' + p)
        return 1

    print('OK 未发现 JVM 签名冲突（%d 个文件 / %d 个类 / %d 属性 / %d 函数）'
          % (len(files), len(all_classes), total_props, total_funs))
    for cls in all_classes:
        if cls.props or cls.funs:
            print(cls.report())

    # 覆盖率自检：扫不出东西说明解析失效，等于假通过
    if total_props < 20 or total_funs < 10:
        print('\n! 扫描量异常偏低（%d 属性 / %d 函数），扫描器可能已失效'
              % (total_props, total_funs))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
