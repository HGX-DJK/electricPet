import 'package:flutter/material.dart';

import '../../theme/poko_theme.dart';
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

/// 地板治愈微光小猫爪印渲染器 (根据 5 大家园主题智能呈现：温润原木/赛博青蓝荧光/电玩洋红/夏日金沙/禅意草编)
class FootprintPainter extends CustomPainter {
  final List<Footprint> footprints;
  final String habitat;

  FootprintPainter(this.footprints, {this.habitat = 'default'});

  @override
  void paint(Canvas canvas, Size size) {
    for (final fp in footprints) {
      if (fp.opacity <= 0.01) continue;
      canvas.save();
      canvas.translate(fp.position.dx, fp.position.dy);
      canvas.rotate(fp.angle);

      Color indentColor;
      Color glowColor;
      double indentAlphaMult;
      double glowAlphaMult;

      switch (habitat) {
        case 'neon_matrix':
          indentColor = PokoPalette.sky_600;
          glowColor = PokoPalette.neon_cyan;
          indentAlphaMult = 0.35;
          glowAlphaMult = 0.45;
          break;
        case 'retro_arcade':
          indentColor = PokoPalette.violet_800;
          glowColor = PokoPalette.pink_500;
          indentAlphaMult = 0.35;
          glowAlphaMult = 0.40;
          break;
        case 'summer_beach':
          indentColor = PokoPalette.amber_700;
          glowColor = PokoPalette.sky_400;
          indentAlphaMult = 0.30;
          glowAlphaMult = 0.30;
          break;
        case 'zen_tatami':
          indentColor = const Color(0xFF065F46);
          glowColor = PokoPalette.emerald_400;
          indentAlphaMult = 0.28;
          glowAlphaMult = 0.22;
          break;
        case 'default':
        default:
          indentColor = PokoPalette.amber_900;
          glowColor = PokoPalette.pink_400;
          indentAlphaMult = 0.26;
          glowAlphaMult = 0.20;
          break;
      }

      final woodIndentPaint = Paint()
        ..color = indentColor.withValues(alpha: (fp.opacity * indentAlphaMult).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      final glowBlushPaint = Paint()
        ..color = glowColor.withValues(alpha: (fp.opacity * glowAlphaMult).clamp(0.0, 1.0))
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
