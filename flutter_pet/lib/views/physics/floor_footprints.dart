import 'package:flutter/material.dart';

/// 地板治愈微光小猫爪印数据模型 (漫步巡视与追球冲刺时自然交替踩出)
class Footprint {
  final Offset position;
  final double angle;
  final bool isLeft;
  double opacity;

  Footprint({
    required this.position,
    required this.angle,
    required this.isLeft,
    this.opacity = 0.45,
  });
}

/// 地板治愈微光小猫爪印渲染器 (温润木质压痕 + 4 个萌态真实猫脚趾印 + 呼吸感微光淡隐)
class FootprintPainter extends CustomPainter {
  final List<Footprint> footprints;

  FootprintPainter(this.footprints);

  @override
  void paint(Canvas canvas, Size size) {
    for (final fp in footprints) {
      if (fp.opacity <= 0.01) continue;
      canvas.save();
      canvas.translate(fp.position.dx, fp.position.dy);
      canvas.rotate(fp.angle);

      // 1. 底层：木地板温润受力微压痕 (温和琥珀暖棕，柔和融入地板，告别假印油感)
      final woodIndentPaint = Paint()
        ..color = const Color(0xFF78350F).withValues(alpha: (fp.opacity * 0.26).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      // 2. 表层：猫咪体温留下的极淡粉嫩微光 (轻盈半透，温润治愈)
      final glowBlushPaint = Paint()
        ..color = const Color(0xFFF472B6).withValues(alpha: (fp.opacity * 0.20).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      // 掌心三瓣主肉垫 (真实猫咪肉垫底弧向上凹陷三叶造型)
      final mainPadRect = Rect.fromCenter(center: const Offset(0.0, 1.0), width: 7.6, height: 6.0);
      canvas.drawOval(mainPadRect, woodIndentPaint);
      canvas.drawOval(mainPadRect, glowBlushPaint);

      // 真实猫爪 4 个萌态脚趾印 (外低内高优美弧线分布，告别三趾机械假感)
      final toes = [
        const Offset(-4.6, -3.2), // 外左趾
        const Offset(-1.6, -5.4), // 内左趾
        const Offset(1.6, -5.4),  // 内右趾
        const Offset(4.6, -3.2),  // 外右趾
      ];
      final radii = [1.5, 1.7, 1.7, 1.5];

      for (int i = 0; i < 4; i++) {
        canvas.drawCircle(toes[i], radii[i], woodIndentPaint);
        canvas.drawCircle(toes[i], radii[i], glowBlushPaint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant FootprintPainter oldDelegate) => true;
}
