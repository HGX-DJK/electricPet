import 'package:flutter/material.dart';

/// 触感微反馈包装组件：按下缩放下沉，松手柔和弹性回弹 (Jelly Spring Press Feedback)
class BouncyTouchFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final void Function(DragEndDetails)? onVerticalDragEnd;
  final double scaleDown;

  const BouncyTouchFeedback({
    super.key,
    required this.child,
    required this.onTap,
    this.onDoubleTap,
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
      onVerticalDragEnd: widget.onVerticalDragEnd,
      child: AnimatedScale(
        scale: _isDown ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
