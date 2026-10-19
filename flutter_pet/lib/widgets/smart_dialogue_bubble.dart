import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'bouncy_touch_feedback.dart';

/// 智能对齐气泡：永不被猫挡住，附带指向小尾巴，支持昼夜温润自适应与弹润动效
class SmartDialogueBubble extends StatelessWidget {
  final Size screenSize;
  final bool isNight;
  final double petX;
  final double petY;
  final bool showFoodTray;
  final String currentDialogue;
  final VoidCallback onTap;

  const SmartDialogueBubble({
    super.key,
    required this.screenSize,
    required this.isNight,
    required this.petX,
    required this.petY,
    required this.showFoodTray,
    required this.currentDialogue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleWidth = math.min(236.0, screenSize.width - 96.0);
    // 水平居中对齐猫咪；当左侧食碗展开微气泡时，气泡自动靠右避让就餐角
    double bubbleLeft = (petX - bubbleWidth / 2).clamp(46.0, screenSize.width - bubbleWidth - 46.0);
    if (showFoodTray) {
      bubbleLeft = math.max(168.0, bubbleLeft).clamp(16.0, screenSize.width - bubbleWidth - 16.0);
    }

    // 垂直方向：如果猫咪在屏幕上方，气泡放猫咪下方；默认放猫咪头顶上方！
    final showAbove = petY > 210.0;
    final bubbleTop = showAbove ? (petY - 146.0) : (petY + 95.0);

    // 计算小尾巴水平位置（对齐猫头中央，限制在气泡左右边距以内）
    final tailX = (petX - bubbleLeft - 7.0).clamp(20.0, bubbleWidth - 34.0);

    return Positioned(
      left: bubbleLeft,
      top: bubbleTop,
      child: BouncyTouchFeedback(
        key: const ValueKey('smart_dialogue_bubble'),
        scaleDown: 0.96,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当气泡位于猫咪下方时，小尾巴朝上指向猫咪
            if (!showAbove)
              Padding(
                padding: EdgeInsets.only(left: tailX),
                child: CustomPaint(
                  size: const Size(14, 7),
                  painter: BubbleTailPainter(
                    isNight: isNight,
                    pointingUp: true,
                  ),
                ),
              ),

            // 主气泡容器 (附带文本切换弹性弹出动效)
            Container(
              width: bubbleWidth,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isNight
                    ? const Color(0xFF1B173E).withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isNight
                      ? const Color(0xFF6366F1).withValues(alpha: 0.45)
                      : const Color(0xFFE0E7FF),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isNight
                        ? const Color(0xFF3730A3).withValues(alpha: 0.28)
                        : const Color(0xFF6366F1).withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                transitionBuilder: (child, anim) {
                  return ScaleTransition(
                    scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                    child: FadeTransition(opacity: anim, child: child),
                  );
                },
                child: Row(
                  key: ValueKey(currentDialogue),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isNight ? '✨' : '💬', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        currentDialogue,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isNight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 当气泡位于头顶上方时，小尾巴朝下指向猫咪
            if (showAbove)
              Padding(
                padding: EdgeInsets.only(left: tailX),
                child: CustomPaint(
                  size: const Size(14, 7),
                  painter: BubbleTailPainter(
                    isNight: isNight,
                    pointingUp: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 对话气泡指向猫咪的自适应小尾巴绘制器 (Comic Bubble Tail)
class BubbleTailPainter extends CustomPainter {
  final bool isNight;
  final bool pointingUp;

  const BubbleTailPainter({required this.isNight, required this.pointingUp});

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = isNight
          ? const Color(0xFF1B173E).withValues(alpha: 0.92)
          : Colors.white.withValues(alpha: 0.96)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isNight
          ? const Color(0xFF6366F1).withValues(alpha: 0.45)
          : const Color(0xFFE0E7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    if (pointingUp) {
      path.moveTo(0, size.height + 0.5);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height + 0.5);
      canvas.drawPath(path, fillPaint);
      final borderPath = Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height);
      canvas.drawPath(borderPath, borderPaint);
    } else {
      path.moveTo(0, -0.5);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, -0.5);
      canvas.drawPath(path, fillPaint);
      final borderPath = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0);
      canvas.drawPath(borderPath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BubbleTailPainter oldDelegate) =>
      oldDelegate.isNight != isNight || oldDelegate.pointingUp != pointingUp;
}
