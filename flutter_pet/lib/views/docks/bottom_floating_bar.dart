import 'package:flutter/material.dart';
import '../../theme/poko_theme.dart';
import '../../widgets/bouncy_touch_feedback.dart';

/// 底部统一浮动坞 —— 单一容器承载多个入口。
///
/// 视觉层级明确、空间舒展大方的高阶灵动岛胶囊。
/// 拥有充裕舒适的横向与纵向间距呼吸感，大图标、清爽分隔留白以及专属高亮「AI语聊」胶囊。
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
      left: 10,
      right: 10,
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
            final double maxWidth = constraints.maxWidth;
            // 响应式间距阶梯：宽屏舒展展开，标准屏舒适通透，超窄屏精巧自适应
            final bool isLargeScreen = maxWidth >= 380;
            final bool isCompact = maxWidth < 340;

            final double iconSize = isCompact ? 16.5 : (isLargeScreen ? 19.0 : 18.0);
            final double fontSize = isCompact ? 10.5 : (isLargeScreen ? 11.5 : 11.0);
            final double hPad = isCompact ? 8.5 : (isLargeScreen ? 13.5 : 11.0);
            final double vPad = isCompact ? 5.5 : (isLargeScreen ? 7.5 : 6.5);
            final double primaryHPad = isCompact ? 10.5 : (isLargeScreen ? 16.0 : 13.5);
            final double dividerMargin = isCompact ? 3.5 : (isLargeScreen ? 6.0 : 4.5);
            final double iconTextGap = isCompact ? 2.5 : (isLargeScreen ? 4.0 : 3.5);

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
                iconSize: iconSize,
                fontSize: fontSize,
                hPad: hPad,
                vPad: vPad,
                iconTextGap: iconTextGap,
              ),
              _DockItem(
                isNight: isNight,
                icon: '👗',
                label: '装扮小窝',
                onTap: onWardrobeTap,
                iconSize: iconSize,
                fontSize: fontSize,
                hPad: hPad,
                vPad: vPad,
                iconTextGap: iconTextGap,
              ),
              _DockItem(
                isNight: isNight,
                icon: '✨',
                label: '专属绝活',
                onTap: onActionTap,
                iconSize: iconSize,
                fontSize: fontSize,
                hPad: hPad,
                vPad: vPad,
                iconTextGap: iconTextGap,
              ),
              if (onVoiceChatTap != null)
                _DockItem(
                  isNight: isNight,
                  icon: '🎙️',
                  label: 'AI语聊',
                  onTap: onVoiceChatTap!,
                  primary: true,
                  iconSize: iconSize,
                  fontSize: fontSize,
                  hPad: primaryHPad,
                  vPad: vPad,
                  iconTextGap: iconTextGap,
                ),
            ];

            // 入口之间配置高雅通透的分隔线，给予充足呼吸留白
            final children = <Widget>[];
            for (var i = 0; i < items.length; i++) {
              if (i > 0) {
                children.add(Container(
                  width: 1,
                  height: isCompact ? 18 : 22,
                  margin: EdgeInsets.symmetric(horizontal: dividerMargin),
                  color: t.border.withValues(alpha: isNight ? 0.35 : 0.6),
                ));
              }
              children.add(items[i]);
            }

            return Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 6 : (isLargeScreen ? 10 : 8),
                  vertical: isCompact ? 5.5 : (isLargeScreen ? 7 : 6),
                ),
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: isNight ? 0.92 : 0.96),
                  borderRadius: BorderRadius.circular(PokoRadius.pill),
                  border: Border.all(
                    color: t.border.withValues(alpha: isNight ? 0.45 : 0.7),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isNight ? 0.28 : 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
/// 竖排布局 (图标在上 / 文字在下), 提供充裕的呼吸留白与触摸舒适度。
class _DockItem extends StatelessWidget {
  final bool isNight;
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool showChevron;
  final void Function(DragEndDetails)? onVerticalDragEnd;
  final double iconSize;
  final double fontSize;
  final double hPad;
  final double vPad;
  final double iconTextGap;

  const _DockItem({
    required this.isNight,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.showChevron = false,
    this.onVerticalDragEnd,
    required this.iconSize,
    required this.fontSize,
    required this.hPad,
    required this.vPad,
    required this.iconTextGap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);

    // 顶部图标行 (背包入口额外挂一个"上滑打开"的小箭头)
    final iconRow = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(icon, style: TextStyle(fontSize: iconSize, height: 1.05)),
        if (showChevron) ...[
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_up_rounded,
            size: iconSize * 0.9,
            color: primary ? Colors.white70 : t.textMuted.withValues(alpha: 0.75),
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
            gradient: primary
                ? const LinearGradient(
                    colors: PokoPalette.brandGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: primary ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(primary ? PokoRadius.pill : PokoRadius.md),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: PokoPalette.indigo.withValues(alpha: isNight ? 0.38 : 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconRow,
              SizedBox(height: iconTextGap),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: primary ? FontWeight.bold : FontWeight.w600,
                  letterSpacing: 0.2,
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
