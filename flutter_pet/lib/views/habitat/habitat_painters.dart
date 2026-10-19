import 'package:flutter/material.dart';

/// 全息赛博与合成波立体透视地面网格绘制器
class CyberPerspectiveGridPainter extends CustomPainter {
  final Color gridColor;
  final Color accentColor;

  CyberPerspectiveGridPainter({required this.gridColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final vanishingPoint = Offset(size.width * 0.5, -40.0);

    // 纵向向远景地平线汇聚的透视辐射线
    const int rayCount = 12;
    for (int i = 0; i <= rayCount; i++) {
      final bottomX = (size.width / rayCount) * i;
      final bottomPt = Offset(bottomX, size.height);
      canvas.drawLine(vanishingPoint, bottomPt, paint);
    }

    // 横向等比加速景深线
    const int numLines = 8;
    for (int i = 1; i <= numLines; i++) {
      final t = i / numLines;
      final y = size.height * (t * t);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // 几颗脉冲亮点
    final dotPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.4), 2.5, dotPaint);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.6), 2.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CyberPerspectiveGridPainter oldDelegate) =>
      oldDelegate.gridColor != gridColor || oldDelegate.accentColor != accentColor;
}

/// 日式障子和室木格隔断绘制器
class ShojiLatticePainter extends CustomPainter {
  final Color frameColor;

  ShojiLatticePainter({required this.frameColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = frameColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;

    // 绘制 3 条垂直木楞
    for (int i = 1; i <= 3; i++) {
      final x = (size.width / 4) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // 绘制 3 条水平木楞
    for (int i = 1; i <= 3; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ShojiLatticePainter oldDelegate) =>
      oldDelegate.frameColor != frameColor;
}
