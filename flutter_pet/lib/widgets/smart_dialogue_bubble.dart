import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/poko_theme.dart';
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
    final t = context.poko(isNight);
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
                    fillColor: t.surface.withValues(alpha: 0.96),
                    borderColor: t.border,
                  ),
                ),
              ),

            // 主气泡容器 (附带文本切换弹性弹出动效)
            Container(
              width: bubbleWidth,
              padding: const EdgeInsets.symmetric(
                  horizontal: PokoSpacing.lg, vertical: PokoSpacing.md),
              decoration: BoxDecoration(
                color: t.surface.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(PokoRadius.lg),
                border: Border.all(color: t.border, width: 1),
                boxShadow: PokoShadow.card(t.shadow),
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
                    const SizedBox(width: PokoSpacing.sm),
                    Expanded(
                      child: Text(
                        currentDialogue,
                        style: TextStyle(
                          fontSize: PokoFont.body,
                          color: t.textPrimary,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
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
                    fillColor: t.surface.withValues(alpha: 0.96),
                    borderColor: t.border,
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
  final Color fillColor;
  final Color borderColor;

  const BubbleTailPainter({
    required this.isNight,
    required this.pointingUp,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
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
      oldDelegate.isNight != isNight ||
      oldDelegate.pointingUp != pointingUp ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor;
}
