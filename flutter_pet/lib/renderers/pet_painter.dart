import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pet_model.dart';

/// 桌面萌宠 · 波可 (Poko) 纯矢量 CustomPainter 渲染引擎
/// 1:1 移植自 PyQt6 桌面版算法，支持骨骼呼吸、微颤立耳、动态瞳孔放大、眨眼形变与丰富动作
class PetPainter extends CustomPainter {
  final PetModel model;
  final double animTime; // 动画时间累计 (秒)
  final String state;    // IDLE, WALK_LEFT, WALK_RIGHT, DRAGGING, FALLING, CARDBOARD_BOX, PEEK_LEFT, PEEK_RIGHT, etc.
  final Offset? touchPos;
  final bool facingLeft;
  final double petProgress; // 0.0 ~ 1.0 (摸头兴奋度)

  PetPainter({
    required this.model,
    required this.animTime,
    required this.state,
    this.touchPos,
    this.facingLeft = false,
    this.petProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    final center = Offset(size.width / 2, size.height / 2);
    final skin = model.currentSkin;

    // 贴边探头模式特殊绘制
    if (state == 'PEEK_LEFT' || state == 'PEEK_RIGHT') {
      _drawEdgePeek(canvas, size, center, skin);
      canvas.restore();
      return;
    }

    // 纸箱藏猫猫模式特殊绘制
    if (state == 'CARDBOARD_BOX') {
      _drawCardboardBoxMode(canvas, size, center, skin);
      canvas.restore();
      return;
    }

    // 水平镜像翻转 (朝向控制)
    if (facingLeft) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    // 呼吸律动 (上下浮动与微小缩放)
    final breathY = math.sin(animTime * 3.2) * 2.5;
    final breathScale = 1.0 + math.sin(animTime * 3.2) * 0.015;

    canvas.translate(center.dx, center.dy + breathY);
    canvas.scale(breathScale, breathScale);

    // 绘制影子
    _drawShadow(canvas, size);

    // 绘制尾巴
    _drawTail(canvas, skin);

    // 绘制身体与背部花纹
    _drawBody(canvas, skin);

    // 绘制头部与面部五官
    _drawHead(canvas, skin);

    // 绘制前爪
    _drawPaws(canvas, skin);

    // 绘制配饰 (铃铛/蝴蝶结)
    _drawDecorations(canvas);

    // 绘制睡觉呼吸气泡 Zzz
    if (model.isSleeping) {
      _drawSleepZzz(canvas);
    }

    canvas.restore();
  }

  void _drawShadow(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = const Color(0x25000000)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 72), width: 110, height: 18),
      shadowPaint,
    );
  }

  void _drawTail(Canvas canvas, SkinConfig skin) {
    final tailPaint = Paint()
      ..color = Color(skin.primaryColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final tailWag = math.sin(animTime * 2.8) * 16.0;
    final path = Path()
      ..moveTo(25, 45)
      ..cubicTo(55, 35, 65 + tailWag, -5, 52 + tailWag, -25);
    canvas.drawPath(path, tailPaint);

    // 尾巴尖端重点色
    final tipPaint = Paint()
      ..color = Color(skin.secondaryColor)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(52 + tailWag, -25), 7, tipPaint);
  }

  void _drawBody(Canvas canvas, SkinConfig skin) {
    final bodyPaint = Paint()
      ..color = Color(skin.primaryColor)
      ..style = PaintingStyle.fill;

    // 圆润猫咪躯干
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 32), width: 94, height: 76),
      bodyPaint,
    );

    // 身体边缘浅浅高光轮廓
    final borderPaint = Paint()
      ..color = const Color(0x15000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 32), width: 94, height: 76),
      borderPaint,
    );

    // 身体花纹 (如果是三花或橘猫)
    if (skin.id == 'cat_calico' || skin.id == 'cat_orange') {
      final spotPaint = Paint()
        ..color = Color(skin.secondaryColor)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(24, 25), width: 28, height: 22),
        spotPaint,
      );
    }
  }

  void _drawHead(Canvas canvas, SkinConfig skin) {
    const headCenter = Offset(0, -18);

    // 耳朵绘制 (带微颤摇晃)
    final earTwitch = petProgress > 0 ? math.sin(animTime * 20.0) * 3.0 : 0.0;
    _drawEars(canvas, skin, headCenter, earTwitch);

    // 圆润大脑袋
    final headPaint = Paint()
      ..color = Color(skin.primaryColor)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: 116, height: 96),
      headPaint,
    );

    // 脑袋顶部三花斑块
    if (skin.id == 'cat_calico') {
      final patchPaint = Paint()
        ..color = Color(skin.secondaryColor)
        ..style = PaintingStyle.fill;
      final patchPath = Path()
        ..moveTo(headCenter.dx + 10, headCenter.dy - 48)
        ..quadraticBezierTo(headCenter.dx + 48, headCenter.dy - 35, headCenter.dx + 45, headCenter.dy - 5)
        ..quadraticBezierTo(headCenter.dx + 25, headCenter.dy - 20, headCenter.dx + 10, headCenter.dy - 48);
      canvas.drawPath(patchPath, patchPaint);
    }

    // 腮红
    final blushPaint = Paint()
      ..color = const Color(0x60F43F5E)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(headCenter.dx - 36, headCenter.dy + 14), width: 18, height: 11),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(headCenter.dx + 36, headCenter.dy + 14), width: 18, height: 11),
      blushPaint,
    );

    // 眼睛
    _drawEyes(canvas, skin, headCenter);

    // 鼻子与小嘴
    _drawNoseAndMouth(canvas, headCenter);

    // 胡须
    _drawWhiskers(canvas, headCenter);
  }

  void _drawEars(Canvas canvas, SkinConfig skin, Offset headCenter, double twitch) {
    final earBasePaint = Paint()
      ..color = Color(skin.primaryColor)
      ..style = PaintingStyle.fill;
    final earInnerPaint = Paint()
      ..color = const Color(0xFFFFB6C1)
      ..style = PaintingStyle.fill;

    // 左耳
    final leftEar = Path()
      ..moveTo(headCenter.dx - 45, headCenter.dy - 25)
      ..lineTo(headCenter.dx - 42 + twitch, headCenter.dy - 64)
      ..lineTo(headCenter.dx - 12, headCenter.dy - 44)
      ..close();
    canvas.drawPath(leftEar, earBasePaint);

    final leftEarInner = Path()
      ..moveTo(headCenter.dx - 38, headCenter.dy - 28)
      ..lineTo(headCenter.dx - 37 + twitch, headCenter.dy - 55)
      ..lineTo(headCenter.dx - 18, headCenter.dy - 42)
      ..close();
    canvas.drawPath(leftEarInner, earInnerPaint);

    // 右耳 (带重点花纹)
    final rightEarColor = (skin.id == 'cat_calico') ? Color(skin.secondaryColor) : Color(skin.primaryColor);
    final rightEarPaint = Paint()..color = rightEarColor;

    final rightEar = Path()
      ..moveTo(headCenter.dx + 45, headCenter.dy - 25)
      ..lineTo(headCenter.dx + 42 - twitch, headCenter.dy - 64)
      ..lineTo(headCenter.dx + 12, headCenter.dy - 44)
      ..close();
    canvas.drawPath(rightEar, rightEarPaint);

    final rightEarInner = Path()
      ..moveTo(headCenter.dx + 38, headCenter.dy - 28)
      ..lineTo(headCenter.dx + 37 - twitch, headCenter.dy - 55)
      ..lineTo(headCenter.dx + 18, headCenter.dy - 42)
      ..close();
    canvas.drawPath(rightEarInner, earInnerPaint);
  }

  void _drawEyes(Canvas canvas, SkinConfig skin, Offset headCenter) {
    // 眨眼计算：每 4.2 秒自然双重眨眼
    final blinkCycle = animTime % 4.2;
    final isBlinking = model.isSleeping || (blinkCycle > 3.9 && blinkCycle < 4.05) || (petProgress > 0.4);

    final leftEyeCenter = Offset(headCenter.dx - 22, headCenter.dy - 2);
    final rightEyeCenter = Offset(headCenter.dx + 22, headCenter.dy - 2);

    if (isBlinking) {
      // 开心弯弯笑眼弧线
      final closedEyePaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      final pLeft = Path()
        ..moveTo(leftEyeCenter.dx - 12, leftEyeCenter.dy)
        ..quadraticBezierTo(leftEyeCenter.dx, leftEyeCenter.dy - 8, leftEyeCenter.dx + 12, leftEyeCenter.dy);
      canvas.drawPath(pLeft, closedEyePaint);

      final pRight = Path()
        ..moveTo(rightEyeCenter.dx - 12, rightEyeCenter.dy)
        ..quadraticBezierTo(rightEyeCenter.dx, rightEyeCenter.dy - 8, rightEyeCenter.dx + 12, rightEyeCenter.dy);
      canvas.drawPath(pRight, closedEyePaint);
      return;
    }

    // 正常张开水灵大眼
    for (final eyeCenter in [leftEyeCenter, rightEyeCenter]) {
      // 眼白
      final eyeWhitePaint = Paint()..color = Colors.white;
      canvas.drawOval(Rect.fromCenter(center: eyeCenter, width: 22, height: 26), eyeWhitePaint);

      // 虹膜彩环
      final irisPaint = Paint()..color = Color(skin.eyeColor);
      canvas.drawOval(Rect.fromCenter(center: eyeCenter, width: 17, height: 21), irisPaint);

      // 动态瞳孔放大算法 (手势抚摸或捕猎状态瞳孔放大)
      double pupilScale = 1.0;
      if (touchPos != null) {
        pupilScale = 1.25;
      }
      if (petProgress > 0) {
        pupilScale = 1.32;
      }

      // 瞳孔
      final pupilPaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawOval(
        Rect.fromCenter(center: eyeCenter, width: 11 * pupilScale, height: 15 * pupilScale),
        pupilPaint,
      );

      // 萌系二次元大光斑
      final starPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(eyeCenter.dx - 3, eyeCenter.dy - 4), 3.5, starPaint);
      canvas.drawCircle(Offset(eyeCenter.dx + 3, eyeCenter.dy + 3), 1.8, starPaint);
    }
  }

  void _drawNoseAndMouth(Canvas canvas, Offset headCenter) {
    // 粉嫩小鼻子
    final nosePaint = Paint()..color = const Color(0xFFFB7185);
    final noseCenter = Offset(headCenter.dx, headCenter.dy + 11);
    final nosePath = Path()
      ..moveTo(noseCenter.dx - 3.5, noseCenter.dy - 2)
      ..lineTo(noseCenter.dx + 3.5, noseCenter.dy - 2)
      ..lineTo(noseCenter.dx, noseCenter.dy + 2)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    // 治愈 ω 微笑猫嘴
    final mouthPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final mouthLeft = Path()
      ..moveTo(noseCenter.dx, noseCenter.dy + 2)
      ..quadraticBezierTo(noseCenter.dx - 6, noseCenter.dy + 9, noseCenter.dx - 12, noseCenter.dy + 5);
    canvas.drawPath(mouthLeft, mouthPaint);

    final mouthRight = Path()
      ..moveTo(noseCenter.dx, noseCenter.dy + 2)
      ..quadraticBezierTo(noseCenter.dx + 6, noseCenter.dy + 9, noseCenter.dx + 12, noseCenter.dy + 5);
    canvas.drawPath(mouthRight, mouthPaint);
  }

  void _drawWhiskers(Canvas canvas, Offset headCenter) {
    final whiskerPaint = Paint()
      ..color = const Color(0x7094A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // 左侧胡须
    canvas.drawLine(Offset(headCenter.dx - 28, headCenter.dy + 9), Offset(headCenter.dx - 58, headCenter.dy + 5), whiskerPaint);
    canvas.drawLine(Offset(headCenter.dx - 28, headCenter.dy + 14), Offset(headCenter.dx - 56, headCenter.dy + 18), whiskerPaint);

    // 右侧胡须
    canvas.drawLine(Offset(headCenter.dx + 28, headCenter.dy + 9), Offset(headCenter.dx + 58, headCenter.dy + 5), whiskerPaint);
    canvas.drawLine(Offset(headCenter.dx + 28, headCenter.dy + 14), Offset(headCenter.dx + 56, headCenter.dy + 18), whiskerPaint);
  }

  void _drawPaws(Canvas canvas, SkinConfig skin) {
    final pawPaint = Paint()..color = Colors.white;
    final pawBorder = Paint()
      ..color = const Color(0x18000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 前爪
    canvas.drawOval(Rect.fromCenter(center: const Offset(-22, 60), width: 22, height: 16), pawPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(-22, 60), width: 22, height: 16), pawBorder);

    canvas.drawOval(Rect.fromCenter(center: const Offset(22, 60), width: 22, height: 16), pawPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(22, 60), width: 22, height: 16), pawBorder);
  }

  void _drawDecorations(Canvas canvas) {
    final neckDeco = model.decorations['neck'];
    if (neckDeco == 'bell') {
      // 红色小项圈
      final collarPaint = Paint()
        ..color = const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;
      final collarPath = Path()
        ..moveTo(-20, 20)
        ..quadraticBezierTo(0, 26, 20, 20);
      canvas.drawPath(collarPath, collarPaint);

      // 金色小铃铛
      final bellPaint = Paint()..color = const Color(0xFFFBBF24);
      canvas.drawCircle(const Offset(0, 25), 6.5, bellPaint);
      final bellHolePaint = Paint()..color = const Color(0xFF78350F);
      canvas.drawCircle(const Offset(0, 26), 1.8, bellHolePaint);
    }
  }

  void _drawSleepZzz(Canvas canvas) {
    final t = (animTime * 1.5) % 3.0;
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Zzz...',
        style: TextStyle(
          color: Color(0xFF6366F1),
          fontSize: 16,
          fontWeight: FontWeight.bold,
          fontFamily: 'sans-serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final alpha = (1.0 - (t / 3.0)).clamp(0.0, 1.0);
    final zPaint = Paint()..color = Color.fromRGBO(99, 102, 241, alpha);
    canvas.saveLayer(null, zPaint);
    textPainter.paint(canvas, Offset(25 + t * 6, -55 - t * 14));
    canvas.restore();
  }

  /// 纸箱藏猫猫模式渲染
  void _drawCardboardBoxMode(Canvas canvas, Size size, Offset center, SkinConfig skin) {
    canvas.translate(center.dx, center.dy);

    // 1. 快递箱后盖
    final boxBackPaint = Paint()..color = const Color(0xFFB48356);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-55, -20, 110, 80), const Radius.circular(8)), boxBackPaint);

    // 2. 探出的小脑袋与两只大眼睛
    canvas.save();
    canvas.translate(0, -18);
    _drawHead(canvas, skin);
    canvas.restore();

    // 3. 快递箱前挡板 (瓦楞纸色泽)
    final boxFrontPaint = Paint()..color = const Color(0xFFC89868);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-60, 5, 120, 65), const Radius.circular(6)), boxFrontPaint);

    // 胶带封装
    final tapePaint = Paint()..color = const Color(0x60FDE047);
    canvas.drawRect(Rect.fromLTWH(-16, 5, 32, 65), tapePaint);

    // 箱子印花 "📦 POKO"
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '📦 POKO BOX',
        style: TextStyle(color: Color(0xFF78350F), fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, const Offset(-34, 38));

    // 搭在箱子边沿的两只白色小猫爪
    final pawPaint = Paint()..color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: const Offset(-26, 8), width: 18, height: 13), pawPaint);
    canvas.drawOval(Rect.fromCenter(center: const Offset(26, 8), width: 18, height: 13), pawPaint);
  }

  /// 贴边探头偷看模式渲染
  void _drawEdgePeek(Canvas canvas, Size size, Offset center, SkinConfig skin) {
    canvas.translate(center.dx, center.dy);
    final isLeft = (state == 'PEEK_LEFT');

    if (!isLeft) {
      canvas.scale(-1, 1);
    }

    // 侧倾探头
    canvas.rotate(0.18);
    _drawHead(canvas, skin);

    // 单爪扣住边缘
    final pawPaint = Paint()..color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: const Offset(36, 12), width: 20, height: 14), pawPaint);
  }

  @override
  bool shouldRepaint(covariant PetPainter oldDelegate) => true;
}
