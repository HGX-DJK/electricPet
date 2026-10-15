import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pet_model.dart';

/// 桌面萌宠 · 波可 (Poko) 纯矢量 CustomPainter 渲染引擎
/// 支持 14 种才艺绝活特技、灵动生物呼吸、机敏偶发抖耳、动态瞳孔追焦、自然双眨眼与物理道具
class PetPainter extends CustomPainter {
  final PetModel model;
  final double animTime; // 动画时间累计 (秒)
  final String state;    // IDLE, DRAGGING, PEEK_LEFT, PEEK_RIGHT, CARDBOARD_BOX, HAPPY_SPIN, CATCH_MOUSE, PLAY_YARN, WASH_FACE, STRETCH_YAWN, TILT_HEAD, LOOK_AROUND, SIT_WAG_TAIL, HEAD_BOB_MUSIC, CHASE_BUTTERFLY, DOZE_OFF, DIZZY
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

    // 1. 贴边探头模式特殊绘制
    if (state == 'PEEK_LEFT' || state == 'PEEK_RIGHT') {
      _drawEdgePeek(canvas, size, center, skin);
      canvas.restore();
      return;
    }

    // 2. 纸箱藏猫猫模式特殊绘制
    if (state == 'CARDBOARD_BOX') {
      _drawCardboardBoxMode(canvas, size, center, skin);
      canvas.restore();
      return;
    }

    // 3. 水平镜像翻转 (朝向控制)
    if (facingLeft) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    // 4. 生动呼吸与骨骼形变系统
    // 强化呼吸起伏：提升至 5.0px 并伴随水平-垂直微小拉伸，确保在手机端肉眼清晰可见
    double breathY = math.sin(animTime * 3.2) * 5.0;
    double scaleX = 1.0 - math.sin(animTime * 3.2) * 0.02;
    double scaleY = 1.0 + math.sin(animTime * 3.2) * 0.035;

    // 绝活特殊形变逻辑
    if (state == 'HAPPY_SPIN') {
      // 欢喜转圈：水平 3D 旋转缩放 + 向上小雀跃跳动
      final spinCycle = math.cos(animTime * 8.0);
      scaleX = spinCycle.abs() < 0.2 ? (spinCycle < 0 ? -0.2 : 0.2) : spinCycle;
      breathY = -math.sin(animTime * 8.0).abs() * 16.0;
    } else if (state == 'STRETCH_YAWN') {
      // 伸懒腰：身体纵向拉长，重心下沉
      scaleX = 1.18;
      scaleY = 0.86;
      breathY = 8.0;
    } else if (state == 'HEAD_BOB_MUSIC') {
      // 听歌点头：跟着节奏踩点上下摇摆
      breathY = -math.sin(animTime * 8.0).abs() * 14.0;
    } else if (state == 'DOZE_OFF') {
      // 犯困打瞌睡：身体下沉
      breathY = math.max(0.0, math.sin(animTime * 2.0)) * 12.0;
    } else if (state == 'DIZZY') {
      // 眩晕打转晃悠
      canvas.translate(math.sin(animTime * 6.0) * 8.0, math.cos(animTime * 6.0) * 4.0);
      canvas.rotate(math.sin(animTime * 6.0) * 0.08);
    } else if (state == 'DRAGGING') {
      // 拖拽抱起：身体受重力拉长悬空
      scaleX = 0.90;
      scaleY = 1.12;
      breathY = 0.0;
    }

    canvas.translate(center.dx, center.dy + breathY);
    canvas.scale(scaleX, scaleY);

    // 绘制影子
    _drawShadow(canvas, size);

    // 绘制尾巴
    _drawTail(canvas, skin);

    // 绘制身体与背部花纹
    _drawBody(canvas, skin);

    // 绘制头部与面部五官 (根据状态绘制生动表情)
    _drawHead(canvas, skin);

    // 绘制前爪 (洗脸或玩耍时动态位置)
    _drawPaws(canvas, skin);

    // 绘制配饰 (铃铛/项圈)
    _drawDecorations(canvas);

    // 绘制绝活专属道具与特效层
    _drawActionProps(canvas, skin);

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

    // 尾巴摆动速率：端坐摇尾巴特技状态下狂摇！
    double tailWag;
    if (state == 'SIT_WAG_TAIL') {
      tailWag = math.sin(animTime * 10.0) * 38.0;
    } else if (state == 'STRETCH_YAWN') {
      tailWag = 5.0 + math.sin(animTime * 15.0) * 6.0;
    } else {
      tailWag = math.sin(animTime * 2.8) * 18.0;
    }

    final path = Path();
    if (state == 'STRETCH_YAWN') {
      // 伸懒腰时尾巴向上翘直
      path.moveTo(25, 45);
      path.cubicTo(45, 10, 48, -35, 40 + tailWag, -65);
    } else {
      path.moveTo(25, 45);
      path.cubicTo(55, 35, 65 + tailWag, -5, 52 + tailWag, -25);
    }
    canvas.drawPath(path, tailPaint);

    // 尾巴尖端重点色
    final tipPaint = Paint()
      ..color = Color(skin.secondaryColor)
      ..style = PaintingStyle.fill;
    final tipOffset = state == 'STRETCH_YAWN'
        ? Offset(40 + tailWag, -65)
        : Offset(52 + tailWag, -25);
    canvas.drawCircle(tipOffset, 7, tipPaint);
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
    canvas.save();

    Offset headCenter = const Offset(0, -18);

    // 歪头卖萌特技 (头部灵巧倾斜 18度)
    if (state == 'TILT_HEAD') {
      canvas.rotate(0.32 * math.sin(animTime * 3.5));
    } else if (state == 'LOOK_AROUND') {
      // 四处巡视时头部左右探视
      headCenter = Offset(math.sin(animTime * 2.5) * 8.0, -18);
    } else if (state == 'DOZE_OFF') {
      // 打瞌睡点头
      final nodAngle = math.max(0.0, math.sin(animTime * 2.0)) * 0.18;
      canvas.rotate(nodAngle);
    }

    // 耳朵绘制：每 5.5 秒自然机敏抖耳，摸头时高频微颤
    final earCycle = animTime % 5.5;
    double earTwitch = 0.0;
    if (petProgress > 0) {
      earTwitch = math.sin(animTime * 22.0) * 3.5;
    } else if (earCycle > 4.8 && earCycle < 5.15) {
      earTwitch = math.sin(animTime * 30.0) * 4.0;
    }
    _drawEars(canvas, skin, headCenter, earTwitch);

    // 圆润大脑袋
    final headPaint = Paint()
      ..color = Color(skin.primaryColor)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: 116, height: 96),
      headPaint,
    );

    // 脑袋斑纹与皮肤特色 (三花/橘猫/暹罗)
    if (skin.id == 'cat_calico') {
      final patchPaint = Paint()
        ..color = Color(skin.secondaryColor)
        ..style = PaintingStyle.fill;
      final patchPath = Path()
        ..moveTo(headCenter.dx + 10, headCenter.dy - 48)
        ..quadraticBezierTo(headCenter.dx + 48, headCenter.dy - 35, headCenter.dx + 45, headCenter.dy - 5)
        ..quadraticBezierTo(headCenter.dx + 25, headCenter.dy - 20, headCenter.dx + 10, headCenter.dy - 48);
      canvas.drawPath(patchPath, patchPaint);
    } else if (skin.id == 'cat_orange') {
      // 橘猫额头活力虎斑 M 纹
      final stripePaint = Paint()
        ..color = Color(skin.secondaryColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(headCenter.dx - 12, headCenter.dy - 42), Offset(headCenter.dx - 4, headCenter.dy - 26), stripePaint);
      canvas.drawLine(Offset(headCenter.dx, headCenter.dy - 45), Offset(headCenter.dx, headCenter.dy - 25), stripePaint);
      canvas.drawLine(Offset(headCenter.dx + 12, headCenter.dy - 42), Offset(headCenter.dx + 4, headCenter.dy - 26), stripePaint);
    } else if (skin.id == 'cat_siamese') {
      // 暹罗猫经典重点色渐变面罩
      final maskPaint = Paint()
        ..color = Color(skin.secondaryColor).withOpacity(0.90)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy + 8), width: 56, height: 44),
        maskPaint,
      );
    }

    // 腮红
    final blushAlpha = (petProgress > 0 || state == 'HAPPY_SPIN') ? 0x90 : 0x55;
    final blushPaint = Paint()
      ..color = Color.fromARGB(blushAlpha, 244, 63, 94)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(headCenter.dx - 36, headCenter.dy + 14), width: 18, height: 11),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(headCenter.dx + 36, headCenter.dy + 14), width: 18, height: 11),
      blushPaint,
    );

    // 眼睛与瞳孔
    _drawEyes(canvas, skin, headCenter);

    // 鼻子与小嘴
    _drawNoseAndMouth(canvas, headCenter);

    // 胡须
    _drawWhiskers(canvas, skin, headCenter);

    canvas.restore();
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
    final leftEyeCenter = Offset(headCenter.dx - 22, headCenter.dy - 2);
    final rightEyeCenter = Offset(headCenter.dx + 22, headCenter.dy - 2);

    // 1. 眩晕螺旋眼 (@_@)
    if (state == 'DIZZY') {
      final swirlPaint = Paint()
        ..color = const Color(0xFF4338CA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (final ec in [leftEyeCenter, rightEyeCenter]) {
        final path = Path();
        for (double a = 0; a < 4 * math.pi; a += 0.2) {
          final r = a * 1.5;
          final x = ec.dx + math.cos(a + animTime * 8.0) * r;
          final y = ec.dy + math.sin(a + animTime * 8.0) * r;
          if (a == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        canvas.drawPath(path, swirlPaint);
      }
      return;
    }

    // 2. 犯困瞌睡眯缝眼 (-.-)
    if (state == 'DOZE_OFF') {
      final sleepyPaint = Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(leftEyeCenter.dx - 10, leftEyeCenter.dy), Offset(leftEyeCenter.dx + 10, leftEyeCenter.dy), sleepyPaint);
      canvas.drawLine(Offset(rightEyeCenter.dx - 10, rightEyeCenter.dy), Offset(rightEyeCenter.dx + 10, rightEyeCenter.dy), sleepyPaint);
      return;
    }

    // 3. 闭眼/开心笑眼判断 (睡觉、洗脸理毛、伸懒腰、转圈欢喜、抚摸、双眨眼)
    final blinkCycle = animTime % 3.8;
    final isBlinking = model.isSleeping ||
        state == 'WASH_FACE' ||
        state == 'STRETCH_YAWN' ||
        state == 'HAPPY_SPIN' ||
        state == 'SIT_WAG_TAIL' ||
        (blinkCycle > 3.55 && blinkCycle < 3.75) ||
        (petProgress > 0.35);

    if (isBlinking) {
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

    // 4. 正常水灵大眼与动态视线追踪
    double gazeX = 0.0;
    double gazeY = 0.0;

    if (state == 'LOOK_AROUND') {
      // 四处巡视眼神移动
      gazeX = math.sin(animTime * 2.5) * 4.5;
    } else if (state == 'CHASE_BUTTERFLY') {
      // 抬头盯蝴蝶
      gazeX = math.sin(animTime * 3.2) * 3.0;
      gazeY = -4.0;
    } else if (state == 'CATCH_MOUSE') {
      // 俯视盯小老鼠
      gazeX = math.sin(animTime * 4.5) * 4.0;
      gazeY = 3.5;
    }

    for (final eyeCenter in [leftEyeCenter, rightEyeCenter]) {
      // 眼白
      final eyeWhitePaint = Paint()..color = Colors.white;
      canvas.drawOval(Rect.fromCenter(center: eyeCenter, width: 22, height: 26), eyeWhitePaint);

      // 虹膜彩环
      final irisCenter = Offset(eyeCenter.dx + gazeX, eyeCenter.dy + gazeY);
      final irisPaint = Paint()..color = Color(skin.eyeColor);
      canvas.drawOval(Rect.fromCenter(center: irisCenter, width: 17, height: 21), irisPaint);

      // 瞳孔放大
      double pupilScale = 1.0;
      if (touchPos != null || state == 'CATCH_MOUSE') pupilScale = 1.25;
      if (petProgress > 0) pupilScale = 1.35;

      final pupilPaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawOval(
        Rect.fromCenter(center: irisCenter, width: 11 * pupilScale, height: 15 * pupilScale),
        pupilPaint,
      );

      // 闪耀高光斑
      final starPaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(irisCenter.dx - 3, irisCenter.dy - 4), 3.5, starPaint);
      canvas.drawCircle(Offset(irisCenter.dx + 3, irisCenter.dy + 3), 1.8, starPaint);
    }
  }

  void _drawNoseAndMouth(Canvas canvas, Offset headCenter) {
    final noseCenter = Offset(headCenter.dx, headCenter.dy + 11);

    // 粉嫩小鼻子
    final nosePaint = Paint()..color = const Color(0xFFFB7185);
    final nosePath = Path()
      ..moveTo(noseCenter.dx - 3.5, noseCenter.dy - 2)
      ..lineTo(noseCenter.dx + 3.5, noseCenter.dy - 2)
      ..lineTo(noseCenter.dx, noseCenter.dy + 2)
      ..close();
    canvas.drawPath(nosePath, nosePaint);

    // 嘴巴绘制
    if (state == 'STRETCH_YAWN') {
      // 伸懒腰打大哈欠 (张大的圆嘴巴 + 粉红小舌头)
      final yawnPaint = Paint()..color = const Color(0xFF451A03);
      canvas.drawOval(Rect.fromCenter(center: Offset(noseCenter.dx, noseCenter.dy + 8), width: 14, height: 18), yawnPaint);
      final tonguePaint = Paint()..color = const Color(0xFFFB7185);
      canvas.drawOval(Rect.fromCenter(center: Offset(noseCenter.dx, noseCenter.dy + 12), width: 10, height: 9), tonguePaint);
      return;
    }

    if (state == 'EATING') {
      // 投喂进食咀嚼动画 (嘴巴一开一合 嚼嚼嚼)
      final chewCycle = math.sin(animTime * 14.0);
      if (chewCycle > 0) {
        final openMouth = Paint()..color = const Color(0xFF451A03);
        canvas.drawOval(Rect.fromCenter(center: Offset(noseCenter.dx, noseCenter.dy + 6), width: 10, height: 8), openMouth);
        final tongue = Paint()..color = const Color(0xFFFB7185);
        canvas.drawOval(Rect.fromCenter(center: Offset(noseCenter.dx, noseCenter.dy + 8), width: 7, height: 5), tongue);
      } else {
        final happyMouth = Paint()
          ..color = const Color(0xFF334155)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round;
        final p = Path()
          ..moveTo(noseCenter.dx - 8, noseCenter.dy + 4)
          ..quadraticBezierTo(noseCenter.dx, noseCenter.dy + 9, noseCenter.dx + 8, noseCenter.dy + 4);
        canvas.drawPath(p, happyMouth);
      }
      return;
    }

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

  void _drawWhiskers(Canvas canvas, SkinConfig skin, Offset headCenter) {
    final whiskerColor = (skin.id == 'cat_black') ? const Color(0xFFE2E8F0) : const Color(0x7094A3B8);
    final whiskerPaint = Paint()
      ..color = whiskerColor
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
    final pawPaint = Paint()..color = Color(skin.primaryColor);
    final pawBorder = Paint()
      ..color = const Color(0x15000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 洗脸理毛绝活特技：一只爪子抬起在脸庞画圈理毛
    if (state == 'WASH_FACE') {
      final washX = 26.0 + math.cos(animTime * 9.0) * 8.0;
      final washY = -8.0 + math.sin(animTime * 9.0) * 8.0;
      canvas.drawOval(Rect.fromCenter(center: const Offset(-22, 60), width: 22, height: 16), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(-22, 60), width: 22, height: 16), pawBorder);

      canvas.drawOval(Rect.fromCenter(center: Offset(washX, washY), width: 20, height: 20), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(washX, washY), width: 20, height: 20), pawBorder);
      return;
    }

    // 扑老鼠或玩毛线特技：双爪前探捕抓
    if (state == 'CATCH_MOUSE' || state == 'PLAY_YARN') {
      final reachX = math.sin(animTime * 6.0) * 8.0;
      canvas.drawOval(Rect.fromCenter(center: Offset(-18 + reachX, 50), width: 22, height: 18), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(-18 + reachX, 50), width: 22, height: 18), pawBorder);

      canvas.drawOval(Rect.fromCenter(center: Offset(22 + reachX, 50), width: 22, height: 18), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(22 + reachX, 50), width: 22, height: 18), pawBorder);
      return;
    }

    // 普通静止前爪
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
    } else if (neckDeco == 'ribbon') {
      // 俏皮粉红蝴蝶结
      final bowPaint = Paint()..color = const Color(0xFFF43F5E);
      // 左蝴蝶翼
      final leftWing = Path()
        ..moveTo(0, 24)
        ..lineTo(-15, 17)
        ..quadraticBezierTo(-18, 24, -15, 31)
        ..close();
      canvas.drawPath(leftWing, bowPaint);
      // 右蝴蝶翼
      final rightWing = Path()
        ..moveTo(0, 24)
        ..lineTo(15, 17)
        ..quadraticBezierTo(18, 24, 15, 31)
        ..close();
      canvas.drawPath(rightWing, bowPaint);
      // 蝴蝶结中心结
      canvas.drawCircle(const Offset(0, 24), 4.5, Paint()..color = const Color(0xFFBE123C));
      // 飘带
      final ribbonPaint = Paint()
        ..color = const Color(0xFFF43F5E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-3, 27), const Offset(-7, 36), ribbonPaint);
      canvas.drawLine(const Offset(3, 27), const Offset(7, 36), ribbonPaint);
    }
  }

  /// 绘制绝活专属物理道具与视觉特效
  void _drawActionProps(Canvas canvas, SkinConfig skin) {
    // 1. 喵影神捕 (发条机械小老鼠在地上乱窜)
    if (state == 'CATCH_MOUSE') {
      final mouseX = math.sin(animTime * 4.5) * 56.0;
      const mouseY = 64.0;
      final movingLeft = math.cos(animTime * 4.5) < 0;

      canvas.save();
      canvas.translate(mouseX, mouseY);
      if (movingLeft) canvas.scale(-1, 1);

      // 机械鼠身
      final mouseBody = Paint()..color = const Color(0xFF94A3B8);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 24, height: 14), mouseBody);
      // 小耳朵
      final mouseEar = Paint()..color = const Color(0xFFF472B6);
      canvas.drawCircle(const Offset(-4, -6), 3.5, mouseEar);
      // 黑眼睛
      final mouseEye = Paint()..color = Colors.black;
      canvas.drawCircle(const Offset(8, -2), 1.5, mouseEye);
      // 发条钥匙
      final keyPaint = Paint()
        ..color = const Color(0xFFFACC15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(const Offset(-2, -7), const Offset(-2, -12), keyPaint);
      canvas.drawCircle(const Offset(-2, -13), 3, keyPaint);
      // 尾巴
      final tailPaint = Paint()
        ..color = const Color(0xFFF472B6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(const Offset(-12, 0), const Offset(-20, -4), tailPaint);

      canvas.restore();
    }

    // 2. 玩毛线球 (粉红毛线团在地板蹦跳滚动)
    else if (state == 'PLAY_YARN') {
      final yarnX = math.sin(animTime * 3.5) * 46.0;
      final yarnY = 56.0 - math.sin(animTime * 7.0).abs() * 20.0;

      canvas.save();
      canvas.translate(yarnX, yarnY);

      // 散开的毛线线圈
      final threadPaint = Paint()
        ..color = const Color(0xFFF472B6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final tPath = Path()
        ..moveTo(-35, 10)
        ..quadraticBezierTo(-20, 18, -8, 2)
        ..lineTo(0, 0);
      canvas.drawPath(tPath, threadPaint);

      // 毛线球本体
      final ballPaint = Paint()..color = const Color(0xFFEC4899);
      canvas.drawCircle(Offset.zero, 14, ballPaint);
      // 毛线纹理
      final linePaint = Paint()
        ..color = const Color(0xFFFBCFE8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 10), 0.2, 2.5, false, linePaint);
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 11), 3.2, 2.2, false, linePaint);

      canvas.restore();
    }

    // 3. 听歌点头 (戴着酷酷的 DJ 大耳机 + 音符漂浮)
    else if (state == 'HEAD_BOB_MUSIC') {
      const hCenter = Offset(0, -18);

      // 耳机横梁
      final bandPaint = Paint()
        ..color = const Color(0xFF4F46E5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCenter(center: Offset(hCenter.dx, hCenter.dy - 12), width: 96, height: 80), math.pi, math.pi, false, bandPaint);

      // 左右耳罩
      final cupPaint = Paint()..color = const Color(0xFF6366F1);
      final padPaint = Paint()..color = const Color(0xFF818CF8);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(hCenter.dx - 48, hCenter.dy - 10), width: 14, height: 28), const Radius.circular(6)), cupPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(hCenter.dx - 44, hCenter.dy - 10), width: 8, height: 24), const Radius.circular(4)), padPaint);

      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(hCenter.dx + 48, hCenter.dy - 10), width: 14, height: 28), const Radius.circular(6)), cupPaint);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(hCenter.dx + 44, hCenter.dy - 10), width: 8, height: 24), const Radius.circular(4)), padPaint);

      // 飞舞的音符
      final t = (animTime * 2.0) % 2.0;
      final notePainter = TextPainter(
        text: TextSpan(
          text: t > 1.0 ? '🎶' : '🎵',
          style: TextStyle(fontSize: 16, color: Colors.indigo.withOpacity((1.0 - t / 2.0).clamp(0.0, 1.0))),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      notePainter.paint(canvas, Offset(28 + t * 12, -50 - t * 20));
    }

    // 4. 扑捉蝴蝶 (彩光蝴蝶在头顶回旋飞舞)
    else if (state == 'CHASE_BUTTERFLY') {
      final bfX = math.sin(animTime * 3.2) * 52.0;
      final bfY = -68.0 + math.sin(animTime * 6.4) * 16.0;
      final flap = math.sin(animTime * 20.0).abs();

      canvas.save();
      canvas.translate(bfX, bfY);

      // 蝴蝶翅膀
      final wingPaint = Paint()..color = const Color(0xFF38BDF8);
      canvas.drawOval(Rect.fromCenter(center: Offset(-6 * flap, -4), width: 12 * flap, height: 16), wingPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(6 * flap, -4), width: 12 * flap, height: 16), wingPaint);

      final bodyPaint = Paint()..color = const Color(0xFF0369A1);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 3, height: 12), bodyPaint);

      canvas.restore();
    }

    // 5. 眩晕星星 (3颗金色五角星环绕头顶旋转)
    else if (state == 'DIZZY') {
      for (int i = 0; i < 3; i++) {
        final angle = animTime * 6.0 + i * (2 * math.pi / 3);
        final sx = math.cos(angle) * 45.0;
        final sy = -40.0 + math.sin(angle) * 14.0;

        final starPainter = TextPainter(
          text: const TextSpan(text: '⭐', style: TextStyle(fontSize: 15)),
          textDirection: TextDirection.ltr,
        )..layout();
        starPainter.paint(canvas, Offset(sx - 7, sy - 7));
      }
    }

    // 6. 欢喜转圈 (星光环绕光环)
    else if (state == 'HAPPY_SPIN') {
      for (int i = 0; i < 4; i++) {
        final angle = animTime * 10.0 + i * (math.pi / 2);
        final sx = math.cos(angle) * 58.0;
        final sy = 10.0 + math.sin(angle) * 20.0;

        final spPainter = TextPainter(
          text: const TextSpan(text: '✨', style: TextStyle(fontSize: 16)),
          textDirection: TextDirection.ltr,
        )..layout();
        spPainter.paint(canvas, Offset(sx - 8, sy - 8));
      }
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
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-55, -20, 110, 80), const Radius.circular(8)), boxBackPaint);

    // 2. 探出的小脑袋与两只大眼睛
    canvas.save();
    canvas.translate(0, -18);
    _drawHead(canvas, skin);
    canvas.restore();

    // 3. 快递箱前挡板 (瓦楞纸色泽)
    final boxFrontPaint = Paint()..color = const Color(0xFFC89868);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-60, 5, 120, 65), const Radius.circular(6)), boxFrontPaint);

    // 胶带封装
    final tapePaint = Paint()..color = const Color(0x60FDE047);
    canvas.drawRect(const Rect.fromLTWH(-16, 5, 32, 65), tapePaint);

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
