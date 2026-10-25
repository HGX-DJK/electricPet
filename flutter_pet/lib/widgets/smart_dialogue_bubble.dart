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

    // ⚠️ 气泡在猫头顶时必须锚定**底边**，不能锚定顶边。
    // 气泡高度随文案行数变化（1~5 行都可能出现），若顶边固定在 petY-146，
    // 文案一长底边就会往下沉，直接压到猫头和耳朵上（实测 3 行文案即压住头顶 13px）。
    // 锚定底边后，气泡始终向上生长，与猫头保持固定间距。
    //
    // 猫头顶(含耳朵)在 petY - 92 附近，这里留出 10px 呼吸间距。
    const double catHeadTop = 92.0;
    const double bubbleBottomGap = 10.0;
    final double bubbleBottom = petY - catHeadTop - bubbleBottomGap;

    // 计算小尾巴水平位置（对齐猫头中央，限制在气泡左右边距以内）
    final tailX = (petX - bubbleLeft - 7.0).clamp(20.0, bubbleWidth - 34.0);

    // Stack 内可用高度（SafeArea 已把状态栏/手势条从 MediaQuery.padding 里摘掉，
    // 但 viewPadding 仍是物理窗口内边距，据此还原 Stack 的真实高度，
    // 保证 bottom 锚点与宠物坐标处在同一坐标系）
    final media = MediaQuery.of(context);
    final double stackHeight =
        media.size.height - media.viewPadding.top - media.viewPadding.bottom;

    return Positioned(
      left: bubbleLeft,
      // showAbove 用 bottom 锚定（气泡向上生长），否则用 top 锚定（气泡在猫下方）
      bottom: showAbove ? (stackHeight - bubbleBottom) : null,
      top: showAbove ? null : (petY + 95.0),
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
                        // 最多 4 行：气泡高度有上限，才不会顶出屏幕顶部
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
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
