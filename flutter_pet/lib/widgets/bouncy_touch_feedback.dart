import 'package:flutter/material.dart';

import '../theme/poko_theme.dart';
/// 触感微反馈包装组件：按下缩放下沉，松手柔和弹性回弹 (Jelly Spring Press Feedback)
class BouncyTouchFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final void Function(DragEndDetails)? onVerticalDragEnd;
  final double scaleDown;

  const BouncyTouchFeedback({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onVerticalDragEnd,
    this.scaleDown = 0.93,
  });

  @override
  State<BouncyTouchFeedback> createState() => _BouncyTouchFeedbackState();
}

class _BouncyTouchFeedbackState extends State<BouncyTouchFeedback> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) => setState(() => _isDown = false),
      onTapCancel: () => setState(() => _isDown = false),
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.onLongPress,
      onVerticalDragEnd: widget.onVerticalDragEnd,
      child: AnimatedScale(
        scale: _isDown ? widget.scaleDown : 1.0,
        duration: PokoDuration.press,
        curve: PokoCurves.standard,
        child: widget.child,
      ),
    );
  }
}
