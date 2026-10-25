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
class PokoPalette {
  const PokoPalette._();

  /// 主色 (靛蓝)
  static const Color indigo = Color(0xFF6366F1);
  static const Color indigoDeep = Color(0xFF4F46E5);
  static const Color indigoSoft = Color(0xFFEEF2FF);

  /// 辅色 (紫)
  static const Color violet = Color(0xFFA855F7);
  static const Color violetDeep = Color(0xFF7E22CE);
  static const Color violetSoft = Color(0xFFFAF5FF);

  /// 功能色 (仅用于小面积点缀, 不做大面积底色)
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberDeep = Color(0xFFB45309);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color sky = Color(0xFF38BDF8);
  static const Color skyGlow = Color(0xFF0EA5E9);
  static const Color skyDeep = Color(0xFF2563EB);
  static const Color skySoft = Color(0xFFEFF6FF);
  static const Color rose = Color(0xFFF43F5E);
  static const Color roseDeep = Color(0xFFE11D48);
  static const Color roseSoft = Color(0xFFFFF1F2);
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldDeep = Color(0xFF047857);

  /// 自然/成功态 (昼夜节律自动模式标识)
  static const Color mintSoft = Color(0xFFDCFCE7);
  static const Color mintDeep = Color(0xFF166534);

  /// 主渐变 (品牌标识 / 主操作按钮)
  static const List<Color> brandGradient = [indigo, violet];
  static const List<Color> brandGradientDeep = [indigoDeep, violetDeep];
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
class PokoRadius {
  const PokoRadius._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;
}

/// 字阶 (与 [PokoText] 配合使用)
class PokoFont {
  const PokoFont._();
  static const double micro = 8;
  static const double tiny = 10;
  static const double caption = 11;
  static const double small = 12;
  static const double body = 13;
  static const double bodyLg = 15;
  static const double title = 17;
  static const double headline = 20;
  static const double display = 24;
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
    accent: PokoPalette.indigo,
    accentGradient: PokoPalette.brandGradient,
    accentSoft: PokoPalette.indigoSoft,
    accentDeep: PokoPalette.indigoDeep,
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
