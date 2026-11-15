// ignore_for_file: constant_identifier_names
//
// 色板令牌刻意用 snake_case，而不是 Dart 惯用的 lowerCamelCase ——
// 因为桌面端 `pet/theme.py` 的 `Palette` 必须与本文件**同名同值**：
// 两端共用一套色板、改一次配色两端同步，靠的就是名字对得上。
// Dart 的命名约定在这里要让位给跨端同源。

import 'package:flutter/material.dart';
import '../widgets/bouncy_touch_feedback.dart';

/// ============================================================================
/// 波可设计系统 (Poko Design System)
/// ----------------------------------------------------------------------------
/// 全局样式令牌: 配色 / 间距 / 圆角 / 字阶 / 阴影 / 通用组件。
///
/// 设计原则:
///  1. 单一主色 —— 靛蓝紫渐变承担"品牌"与"主操作", 其余色相只做功能区分,
///     不再出现"四个按钮四个底色"的彩虹感。
///  2. 有限圆角 —— 全 App 只允许 8 / 12 / 16 / 20 / 28 / 999 六种。
///  3. 统一描边 —— 常规 1px, 强调 1.5px, 不再有 0.8 / 1.0 / 1.4 混用。
///  4. 统一阴影 —— 三档 (浮层 / 卡片 / 轻浮), 不再随手写 blur/offset。
///  5. 字阶收敛 —— 8 / 10 / 11 / 12 / 13 / 15 / 17 / 20 / 24, 不再出现 8.0~40 连续乱写。
///
/// 昼夜: 本 App 的日夜由「昼夜节律 + 小窝主题」决定, 而非系统深色模式,
/// 因此令牌以 [PokoTokens.day] / [PokoTokens.night] 两套显式提供。
/// ============================================================================

/// 品牌与功能色板
///
/// ⚠️ 与桌面端 `pet/theme.py` 的 `Palette` **同名令牌必须同值** ——
/// 两端共用一套色板，改一次配色两端同步。
/// 由 `tests/test_design_tokens.py::TestCrossEndParity` 守着。
class PokoPalette {
  PokoPalette._();

  // ---- 品牌 —— 靛蓝 ----
  static const Color indigo_50 = Color(0xFFEEF2FF);
  static const Color indigo_100 = Color(0xFFE0E7FF);
  static const Color indigo_200 = Color(0xFFDDD6FE);
  static const Color indigo_300 = Color(0xFFA5B4FC);
  static const Color indigo_400 = Color(0xFF818CF8);
  static const Color indigo_500 = Color(0xFF6366F1);
  static const Color indigo_600 = Color(0xFF4F46E5);
  static const Color indigo_700 = Color(0xFF4338CA);
  static const Color indigo_shadow = Color(0xFF4C1D95);

  // ---- 品牌 —— 紫 ----
  static const Color violet_50 = Color(0xFFFAF5FF);
  static const Color violet_100 = Color(0xFFF3E8FF);
  static const Color violet_200 = Color(0xFFE9D5FF);
  static const Color violet_300 = Color(0xFFD8B4FE);
  static const Color violet_400 = Color(0xFFC084FC);
  static const Color violet_500 = Color(0xFFA855F7);
  static const Color violet_600 = Color(0xFF8B5CF6);
  static const Color violet_700 = Color(0xFF7C3AED);
  static const Color violet_800 = Color(0xFF7E22CE);
  static const Color violet_900 = Color(0xFF6D28D9);

  // ---- 中性 —— 石板灰 / 深空底 ----
  static const Color slate_50 = Color(0xFFF8FAFC);
  static const Color slate_100 = Color(0xFFF1F5F9);
  static const Color slate_200 = Color(0xFFE2E8F0);
  static const Color slate_300 = Color(0xFFCBD5E1);
  static const Color slate_400 = Color(0xFF94A3B8);
  static const Color slate_500 = Color(0xFF64748B);
  static const Color slate_600 = Color(0xFF475569);
  static const Color slate_700 = Color(0xFF334155);
  static const Color slate_800 = Color(0xFF1E293B);
  static const Color slate_900 = Color(0xFF0F172A);
  static const Color gray_800 = Color(0xFF1F2937);
  static const Color gray_900 = Color(0xFF111827);
  static const Color ink = Color(0xFF0B0F19);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);

  // ---- 功能色 —— 天青 ----
  static const Color sky_100 = Color(0xFFE0F2FE);
  static const Color sky_200 = Color(0xFFBAE6FD);
  static const Color sky_300 = Color(0xFF7DD3FC);
  static const Color sky_400 = Color(0xFF38BDF8);
  static const Color sky_500 = Color(0xFF0EA5E9);
  static const Color sky_600 = Color(0xFF0284C7);
  static const Color sky_700 = Color(0xFF0369A1);
  static const Color sky_800 = Color(0xFF075985);

  // ---- 功能色 —— 蓝 ----
  static const Color blue_50 = Color(0xFFEFF6FF);
  static const Color blue_100 = Color(0xFFDBEAFE);
  static const Color blue_200 = Color(0xFFBFDBFE);
  static const Color blue_500 = Color(0xFF3B82F6);
  static const Color blue_600 = Color(0xFF2563EB);
  static const Color blue_800 = Color(0xFF1E40AF);

  // ---- 功能色 —— 翠绿 ----
  static const Color emerald_50 = Color(0xFFF0FDF4);
  static const Color emerald_100 = Color(0xFFD1FAE5);
  static const Color emerald_200 = Color(0xFFA7F3D0);
  static const Color emerald_300 = Color(0xFF6EE7B7);
  static const Color emerald_400 = Color(0xFF34D399);
  static const Color emerald_500 = Color(0xFF10B981);
  static const Color emerald_600 = Color(0xFF059669);
  static const Color emerald_700 = Color(0xFF047857);

  // ---- 功能色 —— 薄荷（绿色家族） ----
  static const Color mint_100 = Color(0xFFDCFCE7);
  static const Color mint_200 = Color(0xFFBBF7D0);
  static const Color mint_800 = Color(0xFF166534);

  // ---- 功能色 —— 玫红 ----
  static const Color rose_50 = Color(0xFFFFF1F2);
  static const Color rose_100 = Color(0xFFFFE4E6);
  static const Color rose_200 = Color(0xFFFECDD3);
  static const Color rose_300 = Color(0xFFFDA4AF);
  static const Color rose_400 = Color(0xFFFB7185);
  static const Color rose_500 = Color(0xFFF43F5E);
  static const Color rose_600 = Color(0xFFE11D48);
  static const Color rose_700 = Color(0xFFBE123C);
  static const Color rose_900 = Color(0xFF9F1239);

  // ---- 功能色 —— 粉 ----
  static const Color pink_100 = Color(0xFFFCE7F3);
  static const Color pink_200 = Color(0xFFFBCFE8);
  static const Color pink_300 = Color(0xFFF9A8D4);
  static const Color pink_400 = Color(0xFFF472B6);
  static const Color pink_500 = Color(0xFFEC4899);
  static const Color pink_600 = Color(0xFFDB2777);

  // ---- 功能色 —— 琥珀 ----
  static const Color amber_50 = Color(0xFFFFFBEB);
  static const Color amber_100 = Color(0xFFFEF3C7);
  static const Color amber_200 = Color(0xFFFDE68A);
  static const Color amber_300 = Color(0xFFFCD34D);
  static const Color amber_400 = Color(0xFFFBBF24);
  static const Color amber_500 = Color(0xFFF59E0B);
  static const Color amber_600 = Color(0xFFD97706);
  static const Color amber_700 = Color(0xFFB45309);
  static const Color amber_800 = Color(0xFF854D0E);
  static const Color amber_900 = Color(0xFF78350F);

  // ---- 功能色 —— 橙 ----
  static const Color orange_100 = Color(0xFFFFEDD5);
  static const Color orange_200 = Color(0xFFFED7AA);
  static const Color orange_300 = Color(0xFFFDBA74);
  static const Color orange_400 = Color(0xFFFB923C);
  static const Color orange_500 = Color(0xFFEA580C);
  static const Color orange_600 = Color(0xFFE07A30);
  static const Color orange_700 = Color(0xFFC2410C);
  static const Color orange_800 = Color(0xFF92400E);
  static const Color orange_warm = Color(0xFFFFAA66);

  // ---- 功能色 —— 柠檬黄 ----
  static const Color yellow_100 = Color(0xFFFEF9C3);
  static const Color yellow_200 = Color(0xFFFEF08A);
  static const Color yellow_300 = Color(0xFFFDE047);
  static const Color yellow_400 = Color(0xFFFACC15);
  static const Color yellow_700 = Color(0xFFA16207);

  // ---- 功能色 —— 红 / 青 ----
  static const Color red_100 = Color(0xFFFEE2E2);
  static const Color red_200 = Color(0xFFFECACA);
  static const Color red_300 = Color(0xFFFCA5A5);
  static const Color red_400 = Color(0xFFF87171);
  static const Color red_500 = Color(0xFFEF4444);
  static const Color red_600 = Color(0xFFDC2626);
  static const Color red_700 = Color(0xFFB91C1C);
  static const Color cyan_100 = Color(0xFFCFFAFE);
  static const Color cyan_200 = Color(0xFFA5F3FC);
  static const Color cyan_500 = Color(0xFF06B6D4);

  // ---- 中性点缀 ----
  static const Color cream = Color(0xFFFFFDF9);
  static const Color neon_cyan = Color(0xFF00F0FF);

  // ---- 夜间主题 ----
  static const Color night_canvas = Color(0xFF1E1B4B);
  static const Color night_border = Color(0xFF3B356D);
  static const Color night_surface = Color(0xFF1E1838);
  static const Color night_surface_alt = Color(0xFF2A2560);
  static const Color night_deep = Color(0xFF1E1035);

  // ---- 桌面端泛光主题 ----
  static const Color glow_cream = Color(0xFFFFF9F2);
  static const Color glow_warm = Color(0xFFFEFCE8);
  static const Color glow_soft = Color(0xFFFFF7ED);
  static const Color glow_ink = Color(0xFF090D16);
  static const Color glow_deep = Color(0xFF0B132B);

  /// 主渐变 (品牌标识 / 主操作按钮)
  static const List<Color> brandGradient = [indigo_500, violet_500];
  static const List<Color> brandGradientDeep = [indigo_600, violet_800];
}

/// 间距刻度 (4 的倍数)
class PokoSpacing {
  const PokoSpacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

/// 圆角刻度
///
/// 卡片 / 面板 / 药丸 / 按钮的圆角**只允许**这六档：
/// `xs 8 / sm 12 / md 16 / lg 20 / xl 28 / pill 999`。
///
/// ⚠️ 小于 8 的圆角（发丝线、进度条轨道、极小胶囊）属于**微圆角**，
/// 不受这条刻度约束 —— 7px 高的进度条配 8 圆角会变成一根药丸。
/// 那类场景保留字面量即可。
class PokoRadius {
  PokoRadius._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// 字阶 (与 [PokoText] 配合使用)
///
/// **核心字阶**（新代码优先用这 9 档）:
/// `micro 8 / tiny 10 / caption 11 / small 12 / body 13 / bodyLg 15 /
///  title 17 / headline 20 / display 24`
///
/// **扩展字阶**（旧界面沿用的整档字号，同样收敛成令牌，避免裸数字漂移）:
/// `nano 7 / microSm 9 / bodyMd 14 / titleSm 16 / subtitle 18 /
///  subheadline 19 / displayMd 22 / displayLg 26 / huge 28`
///
/// ⚠️ 半档字号（8.5 / 9.5 / 10.5 …）已全部归整为整档 ——
/// 半档在小屏上会因字体回退而渲染成不同实际字号，是"看起来忽大忽小"的元凶。
class PokoFont {
  PokoFont._();
  static const double micro = 8;
  static const double tiny = 10;
  static const double caption = 11;
  static const double small = 12;
  static const double body = 13;
  static const double bodyLg = 15;
  static const double title = 17;
  static const double headline = 20;
  static const double display = 24;

  // ---- 扩展整档 ----
  static const double nano = 7;
  static const double microSm = 9;
  static const double bodyMd = 14;
  static const double titleSm = 16;
  static const double subtitle = 18;
  static const double subheadline = 19;
  static const double displayMd = 22;
  static const double displayLg = 26;
  static const double huge = 28;
}

/// 动效时长刻度（毫秒）
///
/// 只管**状态转场**（淡入、弹压、切换）。
/// 环境动画的"节拍长度"（900 / 1800 / 3800 …）是内容节奏而非样式，
/// 刻意不收进这里 —— 否则两种时间语义会混为一谈。
class PokoDuration {
  const PokoDuration._();
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration press = Duration(milliseconds: 110);
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration brisk = Duration(milliseconds: 140);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration settle = Duration(milliseconds: 220);
  static const Duration soft = Duration(milliseconds: 240);
  static const Duration smooth = Duration(milliseconds: 260);
  static const Duration swell = Duration(milliseconds: 280);
  static const Duration lazy = Duration(milliseconds: 320);
  static const Duration deliberate = Duration(milliseconds: 420);
  static const Duration steady = Duration(milliseconds: 600);
  static const Duration grand = Duration(milliseconds: 700);
}

/// 动效缓动曲线
///
/// - [standard] 主力曲线：起步快、收尾稳，通用转场用它。
/// - [playful]  带回弹的入场曲线，用在"东西出现"的场合。
/// - [enter]    纯入场；[exit] 纯退场（快进快出）。
class PokoCurves {
  PokoCurves._();
  static const Curve standard = Curves.easeOutCubic;
  static const Curve playful = Curves.easeOutBack;
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeInCubic;
  static const Curve balanced = Curves.easeInOutCubic;
  static const Curve gentle = Curves.easeInOut;
}

/// 阴影档位
class PokoShadow {
  const PokoShadow._();

  /// 轻浮 (贴边小控件)
  static List<BoxShadow> soft(Color shadow) => [
        BoxShadow(color: shadow.withValues(alpha: 0.10), blurRadius: 8, offset: const Offset(0, 2)),
      ];

  /// 卡片
  static List<BoxShadow> card(Color shadow) => [
        BoxShadow(color: shadow.withValues(alpha: 0.14), blurRadius: 16, offset: const Offset(0, 4)),
      ];

  /// 浮层 (底部弹层 / 大面板)
  static List<BoxShadow> layer(Color shadow) => [
        BoxShadow(color: shadow.withValues(alpha: 0.22), blurRadius: 28, offset: const Offset(0, -6)),
      ];
}

/// 语义色板 + 圆角 + 阴影的打包, 供各处统一取用
@immutable
class PokoTokens {
  final bool isNight;

  /// 页面/大面板底色
  final Color canvas;
  /// 卡片底色
  final Color surface;
  /// 次级填充 (输入框 / 胶囊)
  final Color surfaceAlt;
  /// 常规描边
  final Color border;
  /// 强调描边
  final Color borderStrong;
  /// 阴影基色
  final Color shadow;

  /// 主要文字
  final Color textPrimary;
  /// 次要文字
  final Color textSecondary;
  /// 弱化文字 / 占位
  final Color textMuted;

  /// 品牌主色
  final Color accent;
  /// 品牌渐变
  final List<Color> accentGradient;
  /// 品牌浅色底
  final Color accentSoft;
  /// 品牌深色文字
  final Color accentDeep;
  /// 渐变搭档色 (与品牌色搭配的第二个色相, 用于水晶/极光类视觉)
  final Color accentAlt;

  const PokoTokens({
    required this.isNight,
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.borderStrong,
    required this.shadow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentGradient,
    required this.accentSoft,
    required this.accentDeep,
    required this.accentAlt,
  });

  /// 日间
  static const PokoTokens day = PokoTokens(
    isNight: false,
    canvas: Color(0xFFFAF7FF),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF4F2FB),
    border: Color(0xFFEDE9FE),
    borderStrong: Color(0xFFDDD6FE),
    shadow: Color(0xFF4C1D95),
    textPrimary: Color(0xFF1E293B),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    accent: PokoPalette.indigo_500,
    accentGradient: PokoPalette.brandGradient,
    accentSoft: PokoPalette.indigo_50,
    accentDeep: PokoPalette.indigo_600,
    accentAlt: Color(0xFFF0F9FF),
  );

  /// 夜间
  static const PokoTokens night = PokoTokens(
    isNight: true,
    canvas: Color(0xFF16142E),
    surface: Color(0xFF1E1A3C),
    surfaceAlt: Color(0xFF282352),
    border: Color(0xFF322C5C),
    borderStrong: Color(0xFF443C7C),
    shadow: Color(0xFF08061A),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF64748B),
    accent: Color(0xFF818CF8),
    accentGradient: [Color(0xFF6366F1), Color(0xFFA855F7)],
    accentSoft: Color(0xFF262352),
    accentDeep: Color(0xFFC7D2FE),
    accentAlt: Color(0xFF162D4A),
  );

  /// 按昼夜取令牌
  static PokoTokens of(bool isNight) => isNight ? night : day;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PokoTokens &&
          other.isNight == isNight &&
          other.canvas == canvas &&
          other.surface == surface &&
          other.surfaceAlt == surfaceAlt &&
          other.border == border &&
          other.borderStrong == borderStrong &&
          other.shadow == shadow &&
          other.textPrimary == textPrimary &&
          other.textSecondary == textSecondary &&
          other.textMuted == textMuted &&
          other.accent == accent &&
          other.accentAlt == accentAlt;

  @override
  int get hashCode => Object.hash(isNight, canvas, surface, surfaceAlt, border,
      borderStrong, shadow, textPrimary, textSecondary, textMuted, accent,
      accentAlt);
}

/// 便捷取令牌
extension PokoTokensX on BuildContext {
  /// 本 App 昼夜由内部节律决定, 需显式传入
  PokoTokens poko(bool isNight) => PokoTokens.of(isNight);
}

/// ============================================================================
/// 通用组件
/// ============================================================================

/// 毛玻璃感浮层卡片 —— 全 App 的浮层容器统一用它
class PokoGlassCard extends StatelessWidget {
  final bool isNight;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double opacity;
  final bool bordered;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;

  const PokoGlassCard({
    super.key,
    required this.isNight,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: PokoSpacing.md, vertical: PokoSpacing.sm),
    this.radius = PokoRadius.lg,
    this.opacity = 0.95,
    this.bordered = true,
    this.onTap,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: bordered ? Border.all(color: t.border, width: 1) : null,
        boxShadow: shadows ?? PokoShadow.soft(t.shadow),
      ),
      child: child,
    );
    if (onTap == null) return content;
    // ⚠️ 统一走 BouncyTouchFeedback：与全 App 的"按下弹压、松手回弹"手感保持一致。
    // 这里曾是裸 GestureDetector，导致同一批弹层里的卡片有的有手感、有的没有。
    return BouncyTouchFeedback(
      scaleDown: 0.97,
      onTap: onTap!,
      child: content,
    );
  }
}

/// 底部弹层统一外壳 —— 所有底部弹层共用, 保证圆角/拖拽手柄/安全区一致
class PokoSheetShell extends StatelessWidget {
  final bool isNight;
  final Widget child;

  /// 最大高度占屏比例 (自适应高度时使用)
  final double maxHeightFactor;

  /// 固定高度占屏比例 (与 [maxHeightFactor] 二选一; 需要内部滚动区时用它)
  final double? heightFactor;

  /// 键盘弹起时额外抬起的底部距离
  final double bottomInset;

  const PokoSheetShell({
    super.key,
    required this.isNight,
    required this.child,
    this.maxHeightFactor = 0.88,
    this.heightFactor,
    this.bottomInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    final media = MediaQuery.of(context);
    return Container(
      height: heightFactor == null ? null : media.size.height * heightFactor!,
      margin: bottomInset > 0
          ? EdgeInsets.only(bottom: bottomInset)
          : EdgeInsets.zero,
      constraints: BoxConstraints(
        maxHeight: media.size.height * maxHeightFactor,
      ),
      decoration: BoxDecoration(
        color: t.isNight ? const Color(0xFF1E1B4B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(PokoRadius.xl)),
        boxShadow: PokoShadow.layer(t.shadow),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽手柄
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: t.isNight ? const Color(0xFF3B356D) : const Color(0xFFE2D3F7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// 小圆角胶囊按钮 (状态标签 / 次级操作)
class PokoChip extends StatelessWidget {
  final bool isNight;
  final String label;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool solid;

  const PokoChip({
    super.key,
    required this.isNight,
    required this.label,
    this.color,
    this.icon,
    this.onTap,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    final c = color ?? t.accent;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? c : c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(PokoRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: solid ? Colors.white : c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: PokoFont.tiny,
              height: 1.15,
              fontWeight: FontWeight.w600,
              color: solid ? Colors.white : c,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return body;
    // 与 PokoGlassCard 一致，统一弹压手感
    return BouncyTouchFeedback(
      scaleDown: 0.93,
      onTap: onTap!,
      child: body,
    );
  }
}

/// 文字层级工具
class PokoText {
  const PokoText._();

  static TextStyle title(PokoTokens t, {double size = PokoFont.title}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: t.textPrimary,
        height: 1.25,
      );

  static TextStyle body(PokoTokens t, {double size = PokoFont.body}) => TextStyle(
        fontSize: size,
        color: t.textSecondary,
        height: 1.4,
      );

  static TextStyle label(PokoTokens t, {double size = PokoFont.small}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: t.textPrimary,
      );

  static TextStyle muted(PokoTokens t, {double size = PokoFont.caption}) => TextStyle(
        fontSize: size,
        color: t.textMuted,
        height: 1.3,
      );
}
