import 'package:flutter/material.dart';

import '../theme/poko_theme.dart';
/// ============================================================================
/// 纯观察式按压反馈 (Non-intrusive Press Feedback)
/// ----------------------------------------------------------------------------
/// 只观察原始指针事件，**不参与手势竞技场**，因此绝不会和宿主控件已有的
/// 手势（拖拽 / 长按 / 缩放）抢事件。
///
/// 与 [BouncyTouchFeedback] 的分工:
///  * [BouncyTouchFeedback] 自带 GestureDetector 并接管 onTap ——
///    适合「把一个裸的 GestureDetector 整个换成它」的场景。
///  * [PokoPressScale] 用 Listener 旁观指针 —— 适合给「已经带复杂手势」
///    的控件补一层按压手感（比如可拖拽的食物卡、可拖动的毛线球）。
///
/// 用法:
/// ```dart
/// PokoPressScale(
///   child: GestureDetector(
///     onPanUpdate: ...,
///     child: someCard,
///   ),
/// )
/// ```
/// ============================================================================
class PokoPressScale extends StatefulWidget {
  final Widget child;

  /// 按下时缩到的比例（1.0 = 不缩）。
  final double scaleDown;

  /// 缩放动画时长。
  final Duration duration;

  /// 缩放缓动曲线。
  final Curve curve;

  /// 是否启用。
  final bool enabled;

  const PokoPressScale({
    super.key,
    required this.child,
    this.scaleDown = 0.94,
    this.duration = PokoDuration.press,
    this.curve = PokoCurves.standard,
    this.enabled = true,
  });

  @override
  State<PokoPressScale> createState() => _PokoPressScaleState();
}

class _PokoPressScaleState extends State<PokoPressScale> {
  bool _isDown = false;

  void _setDown(bool value) {
    if (!widget.enabled || _isDown == value) return;
    setState(() => _isDown = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: (_) => _setDown(true),
      onPointerUp: (_) => _setDown(false),
      onPointerCancel: (_) => _setDown(false),
      child: AnimatedScale(
        scale: _isDown ? widget.scaleDown : 1.0,
        duration: widget.duration,
        curve: widget.curve,
        child: widget.child,
      ),
    );
  }
}
