import 'package:flutter/material.dart';

/// 实体物理毛线球组件 (支持手指轻点弹跳、自由拖拽甩动与猫咪疾速追球飞扑)
class YarnBallWidget extends StatelessWidget {
  final double rollAngle;
  final bool isNight;
  final bool isFlying;
  final VoidCallback onTap;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const YarnBallWidget({
    super.key,
    required this.rollAngle,
    required this.isNight,
    required this.isFlying,
    required this.onTap,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: CustomPaint(
        size: const Size(44, 44),
        painter: YarnBallPainter(
          rollAngle: rollAngle,
          isNight: isNight,
          isFlying: isFlying,
        ),
      ),
    );
  }
}

/// 逼真 3D 渐变实体物理毛线球绘制器 (具有真实经纬羊毛编织线圈、随位移滚转角、拖尾线绳与地面柔影)
class YarnBallPainter extends CustomPainter {
  final double rollAngle;
  final bool isNight;
  final bool isFlying;

  const YarnBallPainter({
    required this.rollAngle,
    required this.isNight,
    required this.isFlying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 2);
    const radius = 14.5;

    // 1. 地面动态接触阴影 (在飞行或抛起时阴影缩小淡化)
    final shadowScale = isFlying ? 0.65 : 1.0;
    final shadowAlpha = isFlying ? (isNight ? 24 : 32) : (isNight ? 80 : 64);
    final shadowPaint = Paint()..color = Color.fromARGB(shadowAlpha, 0, 0, 0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, size.height - 4),
        width: 32.0 * shadowScale,
        height: 7.5 * shadowScale,
      ),
      shadowPaint,
    );

    // 2. 拖尾解开的毛线小线头绳 (随滚动自然拖在身后地面上)
    final threadPaint = Paint()
      ..color = isNight ? const Color(0xFFFB7185) : const Color(0xFFF43F5E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final trailPath = Path()
      ..moveTo(center.dx - radius * 0.4, center.dy + radius * 0.8)
      ..quadraticBezierTo(center.dx - 12, size.height - 5, center.dx - 18, size.height - 6)
      ..quadraticBezierTo(center.dx - 24, size.height - 7, center.dx - 28, size.height - 4);
    canvas.drawPath(trailPath, threadPaint);

    // 3. 毛线球 3D 球体渐变 (深粉至绛红质感)
    final ballRect = Rect.fromCircle(center: center, radius: radius);
    final sphereShader = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 0.95,
      colors: isNight
          ? const [Color(0xFFFDA4AF), Color(0xFFF43F5E), Color(0xFF9F1239)]
          : const [Color(0xFFFFE4E6), Color(0xFFFB7185), Color(0xFFE11D48)],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(ballRect);

    canvas.drawCircle(center, radius, Paint()..shader = sphereShader);

    // 4. 毛线缠绕立体纹理 (随 rollAngle 物理滚动旋转)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rollAngle);

    final lineLight = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final lineDark = Paint()
      ..color = const Color(0xFF881337).withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    // 纬向与经向交叉缠绕毛线环
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius * 0.72), 0.2, 2.4, false, lineDark);
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius * 0.70), 0.2, 2.4, false, lineLight);

    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius * 0.85), 3.0, 2.2, false, lineDark);
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: radius * 0.83), 3.0, 2.2, false, lineLight);

    canvas.drawArc(Rect.fromCircle(center: const Offset(2, -2), radius: radius * 0.55), 1.6, 2.6, false, lineLight);

    // 散出的一小撮立体毛线绒头
    canvas.drawLine(
      const Offset(radius * 0.7, -radius * 0.3),
      const Offset(radius * 1.2, -radius * 0.55),
      lineLight..strokeWidth = 1.8,
    );

    canvas.restore();

    // 5. 球体高光点 (球面上方左侧环境光微反射)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx - 4.5, center.dy - 4.5), width: 6.5, height: 3.8),
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );
  }

  @override
  bool shouldRepaint(covariant YarnBallPainter oldDelegate) {
    return oldDelegate.rollAngle != rollAngle ||
        oldDelegate.isNight != isNight ||
        oldDelegate.isFlying != isFlying;
  }
}
