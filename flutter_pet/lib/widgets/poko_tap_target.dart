import 'package:flutter/material.dart';

/// 图标按钮的**无障碍 + 触控友好**包装。
///
/// 为什么需要它：
///
///  * **无障碍**：这个 App 原本**零处 `Semantics`** —— 读屏用户拿到的是
///    一排没有名字的方块（🔊、✕、✨…），完全不知道按下去会发生什么。
///    文字按钮自带名字，图标按钮才是重灾区。
///  * **触控**：很多图标按钮只有 26~30 dp，手机上很容易误触相邻控件
///    （Material 与 Apple 的推荐值都是 44~48 dp）。
///
/// 设计取舍（重要）：
///
/// **图标本身的视觉尺寸完全不变** —— 只是把它放进一个
/// [minTapTarget] 见方的小槽位里居中，于是「手指能按到的区域」
/// 变大了，而「看起来多大」一点没变。
///
/// ⚠️ 用 [expandHitArea] 关掉扩展，用于**彼此紧挨着**的按钮组
/// （例如顶栏一排小珠子）：它们的命中区一旦扩展就会互相重叠，
/// 反而更难点准。
///
/// 用法：
/// ```dart
/// PokoTapTarget(
///   semanticLabel: '关闭扭蛋机',
///   onTap: () => Navigator.of(context).pop(),
///   child: const Icon(Icons.close_rounded, size: 17),
/// )
/// ```
class PokoTapTarget extends StatelessWidget {
  /// 读屏时念出来的名字。留空则不额外包一层 Semantics。
  final String? semanticLabel;

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 命中区的最小边长（逻辑像素）。
  static const double defaultMinTapTarget = 44.0;

  final double minTapTarget;

  /// 是否扩展命中区。密集排布的按钮组请传 false。
  final bool expandHitArea;

  const PokoTapTarget({
    super.key,
    required this.child,
    this.semanticLabel,
    this.onTap,
    this.onLongPress,
    this.expandHitArea = true,
    this.minTapTarget = defaultMinTapTarget,
  });

  @override
  Widget build(BuildContext context) {
    Widget inner = child;

    if (expandHitArea) {
      // 小图标放进一个更大的槽位里居中 ——
      // 视觉尺寸不变（Center 给的是松约束），但手指能按到的区域大了。
      inner = ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minTapTarget,
          minHeight: minTapTarget,
        ),
        child: Center(child: child),
      );
    }

    if (onTap != null || onLongPress != null) {
      inner = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: inner,
      );
    }

    if (semanticLabel != null) {
      inner = Semantics(
        button: onTap != null,
        label: semanticLabel,
        excludeSemantics: true,
        child: inner,
      );
    }

    return inner;
  }
}
