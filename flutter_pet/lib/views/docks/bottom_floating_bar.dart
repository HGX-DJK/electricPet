import 'package:flutter/material.dart';
import '../../theme/poko_theme.dart';
import '../../widgets/bouncy_touch_feedback.dart';

/// 底部统一浮动坞 —— 单一容器承载多个入口。
///
/// 之前是 4 个各自独立的彩色胶囊 (白/紫/琥珀/蓝), 彼此抢夺注意力;
/// 现在收敛为一个毛玻璃浮层, 用细分隔线区分入口, 并把「AI 语聊」做成
/// 唯一的主操作 (实心渐变), 视觉层级一眼分明。
///
/// 窄屏策略:
///  - 可用宽度不足时自动切换到紧凑密度 (更小的图标/字号/内边距), 而不是缩放整条栏;
///  - 每个入口按自然宽度占比分配 flex, 极端窄屏时标签等比省略, 绝不溢出。
class BottomFloatingBar extends StatelessWidget {
  final bool isNight;
  final VoidCallback onBackpackTap;
  final VoidCallback onWardrobeTap;
  final VoidCallback onActionTap;
  final VoidCallback? onVoiceChatTap;
  final VoidCallback? onHabitatTap;
  final VoidCallback? onGachaTap;

  const BottomFloatingBar({
    super.key,
    required this.isNight,
    required this.onBackpackTap,
    required this.onWardrobeTap,
    required this.onActionTap,
    this.onVoiceChatTap,
    this.onHabitatTap,
    this.onGachaTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);

    return Positioned(
      key: const ValueKey('bottom_floating_bar'),
      bottom: 16,
      left: 12,
      right: 12,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, animVal, child) {
          return Transform.translate(
            offset: Offset(0, (1.0 - animVal) * 16.0),
            child: Opacity(
              opacity: animVal.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 宽度不够时切紧凑密度, 而不是把整条栏等比缩小
            final bool compact = constraints.maxWidth < 348;

            final items = <Widget>[
              _DockItem(
                isNight: isNight,
                icon: '🎒',
                label: '奇妙背包',
                onTap: onBackpackTap,
                // 保留"上滑打开"的提示
                showChevron: true,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! < -50) {
                    onBackpackTap();
                  }
                },
                compact: compact,
              ),
              _DockItem(
                isNight: isNight,
                icon: '👗',
                label: '装扮小窝',
                onTap: onWardrobeTap,
                compact: compact,
              ),
              _DockItem(
                isNight: isNight,
                icon: '✨',
                label: '专属绝活',
                onTap: onActionTap,
                compact: compact,
              ),
              if (onVoiceChatTap != null)
                _DockItem(
                  isNight: isNight,
                  icon: '🎙️',
                  label: 'AI语聊',
                  onTap: onVoiceChatTap!,
                  primary: true,
                  compact: compact,
                ),
            ];

            // 入口之间用细分隔线, 替代原先各自独立的描边胶囊
            final children = <Widget>[];
            for (var i = 0; i < items.length; i++) {
              if (i > 0) {
                children.add(Container(
                  width: 1,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  color: t.border,
                ));
              }
              children.add(items[i]);
            }

            return Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 3 : 4,
                  vertical: compact ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: isNight ? 0.90 : 0.95),
                  borderRadius: BorderRadius.circular(PokoRadius.pill),
                  border: Border.all(color: t.border, width: 1),
                  boxShadow: PokoShadow.card(t.shadow),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 浮动坞内的单个入口
///
/// 竖排布局 (图标在上 / 文字在下), 这是移动端底栏的标准形态:
/// 横向排布时 4 个带文字的入口在 320~360px 窄屏上会把文字挤成省略号,
/// 竖排后每个入口只占 "文字宽度 + 一点内边距", 最窄到 320px 也不会截断。
class _DockItem extends StatelessWidget {
  final bool isNight;
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool showChevron;
  final void Function(DragEndDetails)? onVerticalDragEnd;
  final bool compact;

  const _DockItem({
    required this.isNight,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.showChevron = false,
    this.onVerticalDragEnd,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    final double iconSize = compact ? 15 : 16;
    final double fontSize = compact ? 10 : 10.5;
    final double hPad = compact ? 7 : 9;
    final double vPad = compact ? 4 : 5;

    // 顶部图标行 (背包入口额外挂一个"上滑打开"的小箭头)
    final iconRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: TextStyle(fontSize: iconSize, height: 1.05)),
        if (showChevron) ...[
          const SizedBox(width: 1),
          Icon(
            Icons.keyboard_arrow_up_rounded,
            size: iconSize,
            color: primary ? Colors.white70 : t.textMuted,
          ),
        ],
      ],
    );

    return Flexible(
      child: BouncyTouchFeedback(
        scaleDown: 0.93,
        onTap: onTap,
        onVerticalDragEnd: onVerticalDragEnd,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            // 主操作用品牌渐变实心, 其余保持同一张底色 —— 不再四种底色打架
            gradient: primary
                ? const LinearGradient(colors: PokoPalette.brandGradient)
                : null,
            color: primary ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(PokoRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconRow,
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: primary ? Colors.white : t.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
