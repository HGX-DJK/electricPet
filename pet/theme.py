"""
桌面端设计令牌 —— 配色 / 圆角 / 字阶 / 动效 / QSS 模板渲染。

为什么需要它
------------
桌面端此前把**同一套色值**散落在 ``menus.py`` / ``memo.py`` / ``dock.py`` /
``tray.py`` / ``dialogue.py`` 六十多处 QSS 字符串里：``#38BDF8`` 单独一个值
就散落 30 次，改一次配色要翻五个文件，还极易漏掉某个 ``rgba()`` 的 alpha 分量。

这里把它们收成**单一真源**，并与 Flutter 端
``flutter_pet/lib/theme/poko_theme.dart`` 共用同一套色板（同源同值）——
两端改色各改一处，不会跑偏。

用法
----
QSS 模板里用 ``@token@`` 占位，再交给 :func:`qss` 渲染：

.. code-block:: python

    self.setStyleSheet(qss(
        'QPushButton {'
        '    background-color: @slate_800_70@;'
        '    border: 1px solid @slate_700_80@;'
        '    border-radius: @md@;'
        '    color: @slate_100@;'
        '}'
    ))

⚠️ 角色美术（``pet/renderer.py``）**不在**此列 —— 那里的颜色是波可本体配色，
属于画面内容而非 UI 装饰，不受令牌约束，也不允许为了"统一"去动它。
"""

from __future__ import annotations

# ---------------------------------------------------------------------------
# 配色
# ---------------------------------------------------------------------------


class Palette:
    """十六进制色值（可直接写进 QSS）。命名沿用 Tailwind 色阶。

    ⚠️ 与 Flutter 端 ``PokoPalette`` **同名令牌必须同值** —— 两端共用
    一套色板，改一次配色两端同步，由 ``tests/test_design_tokens.py`` 守着。
    """

    # ---- 品牌 —— 靛蓝 ----
    indigo_50 = "#EEF2FF"
    indigo_100 = "#E0E7FF"
    indigo_200 = "#DDD6FE"
    indigo_300 = "#A5B4FC"
    indigo_400 = "#818CF8"
    indigo_500 = "#6366F1"
    indigo_600 = "#4F46E5"
    indigo_700 = "#4338CA"
    indigo_shadow = "#4C1D95"

    # ---- 品牌 —— 紫 ----
    violet_50 = "#FAF5FF"
    violet_100 = "#F3E8FF"
    violet_200 = "#E9D5FF"
    violet_300 = "#D8B4FE"
    violet_400 = "#C084FC"
    violet_500 = "#A855F7"
    violet_600 = "#8B5CF6"
    violet_700 = "#7C3AED"
    violet_800 = "#7E22CE"
    violet_900 = "#6D28D9"

    # ---- 中性 —— 石板灰 / 深空底 ----
    slate_50 = "#F8FAFC"
    slate_100 = "#F1F5F9"
    slate_200 = "#E2E8F0"
    slate_300 = "#CBD5E1"
    slate_400 = "#94A3B8"
    slate_500 = "#64748B"
    slate_600 = "#475569"
    slate_700 = "#334155"
    slate_800 = "#1E293B"
    slate_900 = "#0F172A"
    gray_800 = "#1F2937"
    gray_900 = "#111827"
    ink = "#0B0F19"
    white = "#FFFFFF"
    black = "#000000"

    # ---- 功能色 —— 天青 ----
    sky_100 = "#E0F2FE"
    sky_200 = "#BAE6FD"
    sky_300 = "#7DD3FC"
    sky_400 = "#38BDF8"
    sky_500 = "#0EA5E9"
    sky_600 = "#0284C7"
    sky_700 = "#0369A1"
    sky_800 = "#075985"

    # ---- 功能色 —— 蓝 ----
    blue_50 = "#EFF6FF"
    blue_100 = "#DBEAFE"
    blue_200 = "#BFDBFE"
    blue_500 = "#3B82F6"
    blue_600 = "#2563EB"
    blue_800 = "#1E40AF"

    # ---- 功能色 —— 翠绿 ----
    emerald_50 = "#F0FDF4"
    emerald_100 = "#D1FAE5"
    emerald_200 = "#A7F3D0"
    emerald_300 = "#6EE7B7"
    emerald_400 = "#34D399"
    emerald_500 = "#10B981"
    emerald_600 = "#059669"
    emerald_700 = "#047857"

    # ---- 功能色 —— 薄荷（绿色家族） ----
    mint_100 = "#DCFCE7"
    mint_200 = "#BBF7D0"
    mint_800 = "#166534"

    # ---- 功能色 —— 玫红 ----
    rose_50 = "#FFF1F2"
    rose_100 = "#FFE4E6"
    rose_200 = "#FECDD3"
    rose_300 = "#FDA4AF"
    rose_400 = "#FB7185"
    rose_500 = "#F43F5E"
    rose_600 = "#E11D48"
    rose_700 = "#BE123C"
    rose_900 = "#9F1239"

    # ---- 功能色 —— 粉 ----
    pink_100 = "#FCE7F3"
    pink_200 = "#FBCFE8"
    pink_300 = "#F9A8D4"
    pink_400 = "#F472B6"
    pink_500 = "#EC4899"
    pink_600 = "#DB2777"

    # ---- 功能色 —— 琥珀 ----
    amber_50 = "#FFFBEB"
    amber_100 = "#FEF3C7"
    amber_200 = "#FDE68A"
    amber_300 = "#FCD34D"
    amber_400 = "#FBBF24"
    amber_500 = "#F59E0B"
    amber_600 = "#D97706"
    amber_700 = "#B45309"
    amber_800 = "#854D0E"
    amber_900 = "#78350F"

    # ---- 功能色 —— 橙 ----
    orange_100 = "#FFEDD5"
    orange_200 = "#FED7AA"
    orange_300 = "#FDBA74"
    orange_400 = "#FB923C"
    orange_500 = "#EA580C"
    orange_600 = "#E07A30"
    orange_700 = "#C2410C"
    orange_800 = "#92400E"
    orange_warm = "#FFAA66"

    # ---- 功能色 —— 柠檬黄 ----
    yellow_100 = "#FEF9C3"
    yellow_200 = "#FEF08A"
    yellow_300 = "#FDE047"
    yellow_400 = "#FACC15"
    yellow_700 = "#A16207"

    # ---- 功能色 —— 红 / 青 ----
    red_100 = "#FEE2E2"
    red_200 = "#FECACA"
    red_300 = "#FCA5A5"
    red_400 = "#F87171"
    red_500 = "#EF4444"
    red_600 = "#DC2626"
    red_700 = "#B91C1C"
    cyan_100 = "#CFFAFE"
    cyan_200 = "#A5F3FC"
    cyan_500 = "#06B6D4"

    # ---- 中性点缀 ----
    cream = "#FFFDF9"
    neon_cyan = "#00F0FF"

    # ---- 夜间主题 ----
    night_canvas = "#1E1B4B"
    night_border = "#3B356D"
    night_surface = "#1E1838"
    night_surface_alt = "#2A2560"
    night_deep = "#1E1035"

    # ---- 桌面端泛光主题 ----
    glow_cream = "#FFF9F2"
    glow_warm = "#FEFCE8"
    glow_soft = "#FFF7ED"
    glow_ink = "#090D16"
    glow_deep = "#0B132B"


def _rgba(hex_color: str, alpha: float) -> str:
    """``#38BDF8`` + ``0.2`` → ``rgba(56, 189, 248, 0.2)``。"""
    r = int(hex_color[1:3], 16)
    g = int(hex_color[3:5], 16)
    b = int(hex_color[5:7], 16)
    return f"rgba({r}, {g}, {b}, {alpha})"


class Alpha:
    """半透明填充色 —— QSS 里用得最多的一批 ``rgba()``。

    命名规则：``<底色名>_<透明度×100>`` —— 底色名**保留**自己的下划线，
    例如 ``slate_800_70`` 就是 ``rgba(30, 41, 59, 0.7)``
    （底色 ``slate_800`` = ``#1E293B``）。
    """

    pass


# 桌面端 QSS 实际用到的全部 (底色, 透明度) 组合
_ALPHA_SPECS = (
    ("ink", 0.95),
    ("slate_900", 0.60), ("slate_900", 0.70), ("slate_900", 0.75),
    ("slate_900", 0.80), ("slate_900", 0.85), ("slate_900", 0.95),
    ("slate_800", 0.60), ("slate_800", 0.70), ("slate_800", 0.80), ("slate_800", 0.85),
    ("slate_700", 0.40), ("slate_700", 0.60), ("slate_700", 0.80), ("slate_700", 0.85),
    ("slate_700", 0.90), ("slate_700", 0.95),
    ("slate_500", 0.15), ("slate_500", 0.20),
    ("slate_400", 0.35),
    ("gray_900", 0.95),
    ("sky_400", 0.20), ("sky_400", 0.35), ("sky_400", 0.40),
    ("sky_500", 0.15), ("sky_500", 0.20), ("sky_500", 0.25), ("sky_500", 0.40),
    ("sky_600", 0.40), ("sky_700", 0.40),
    ("amber_500", 0.15), ("amber_500", 0.20), ("amber_700", 0.40),
    ("emerald_500", 0.15), ("emerald_500", 0.20),
    ("emerald_400", 0.20), ("emerald_400", 0.35), ("emerald_600", 0.40),
    ("rose_500", 0.15), ("rose_500", 0.30), ("rose_700", 0.40),
    ("violet_500", 0.15), ("violet_500", 0.20), ("violet_700", 0.40),
    ("indigo_400", 0.20), ("indigo_700", 0.40),
    ("red_500", 0.15), ("red_500", 0.20), ("red_700", 0.40),
    ("yellow_400", 0.20), ("yellow_700", 0.40),
    ("white", 0.70),
    ("black", 0.08), ("black", 0.15), ("black", 0.25),
)


def _install_alpha_tokens() -> None:
    for base, alpha in _ALPHA_SPECS:
        name = f"{base}_{int(round(alpha * 100))}"
        setattr(Alpha, name, _rgba(getattr(Palette, base), alpha))


_install_alpha_tokens()


# ---------------------------------------------------------------------------
# 圆角 / 字阶 / 动效
# ---------------------------------------------------------------------------


class Radius:
    """圆角刻度（像素）。与 Flutter 端 ``PokoRadius`` 同值。"""

    micro = 2
    xs = 8
    sm = 12
    md = 16
    lg = 20
    xl = 28
    pill = 999


class Font:
    """字阶（像素）。与 Flutter 端 ``PokoFont`` 同值。"""

    family = "Microsoft YaHei UI"

    micro = 8
    tiny = 10
    caption = 11
    small = 12
    body = 13
    body_lg = 15
    title = 17
    headline = 20
    display = 24


class Motion:
    """动效时长（毫秒）。

    淡入快、淡出略慢 —— 与 Flutter 端 ``PokoDuration`` 同值。
    """

    instant = 120
    fast = 160
    normal = 200
    slow = 220


# ---------------------------------------------------------------------------
# QSS 模板渲染
# ---------------------------------------------------------------------------

_TOKEN_SOURCES = (Palette, Alpha, Radius, Font, Motion)


def _build_registry() -> dict:
    registry = {}
    for source in _TOKEN_SOURCES:
        for key, value in vars(source).items():
            if key.startswith("_") or callable(value) or isinstance(value, (staticmethod, classmethod)):
                continue
            registry[key] = str(value)
    return registry


_TOKENS = _build_registry()


def qss(template: str) -> str:
    """把 QSS 模板里的 ``@token@`` 占位替换成设计令牌的实际值。

    为什么不用 f-string：QSS 本身就是 CSS 语法，规则块用的是 ``{ }``，
    和 f-string 的插值语法正面冲突 —— 每写一条规则都得把花括号转义成
    ``{{ }}``，可读性和出错率都很糟。这里换用 ``@token@`` 占位，
    绕开花括号地狱。
    """
    for name, value in _TOKENS.items():
        template = template.replace(f"@{name}@", value)
    return template
