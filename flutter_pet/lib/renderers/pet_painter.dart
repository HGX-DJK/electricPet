import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pet_model.dart';

/// 桌面萌宠 · 波可 (Poko) 纯矢量 CustomPainter 渲染引擎
/// 支持 14 种才艺绝活特技、灵动生物呼吸、机敏偶发抖耳、动态瞳孔追焦、自然双眨眼与物理道具
class PetPainter extends CustomPainter {
  final PetModel model;
  final double animTime; // 动画时间累计 (秒)
  final String state;    // IDLE, DRAGGING, PEEK_LEFT, PEEK_RIGHT, CARDBOARD_BOX, HAPPY_SPIN, CATCH_MOUSE, PLAY_YARN, WASH_FACE, STRETCH_YAWN, TILT_HEAD, LOOK_AROUND, SIT_WAG_TAIL, HEAD_BOB_MUSIC, CHASE_BUTTERFLY, DOZE_OFF, DIZZY, GLASS_BOOP
  final Offset? touchPos;
  final bool facingLeft;
  final double petProgress; // 0.0 ~ 1.0 (摸头兴奋度)
  final bool isPurring;     // 挠下巴呼噜状态
  final String? twitchEar;  // 'LEFT' | 'RIGHT' 独立抖耳
  final bool isHunting;     // 捕猎/追球/追激光兴奋态 (曜石巨瞳)
  final bool isTailPuffed;  // 揪尾巴炸毛惊跳状态 (尾巴膨胀与毛刺)
  final bool isNight;       // 静谧星夜暗光环境 (瞳孔自然舒张)
  final bool isAirplaneEars;// 飞机耳警戒态 (受惊/开灯时双耳向两侧水平压平)
  final bool isBlep;         // 呆萌吐小舌头 (露粉嫩小舌尖)
  final String? winkEye;     // 'LEFT' | 'RIGHT' 俏皮单眼眨眼放电
  final bool isSlowBlink;    // 慢眨眼“猫咪之吻” (表达极致信任与爱意)

  PetPainter({
    required this.model,
    required this.animTime,
    required this.state,
    this.touchPos,
    this.facingLeft = false,
    this.petProgress = 0.0,
    this.isPurring = false,
    this.twitchEar,
    this.isHunting = false,
    this.isTailPuffed = false,
    this.isNight = false,
    this.isAirplaneEars = false,
    this.isBlep = false,
    this.winkEye,
    this.isSlowBlink = false,
  });

  /// 3D 光影自适应色彩提亮：模拟朝光面高光与次表面散射
  static Color _lighten(Color c, [double amount = 0.16]) {
    return Color.lerp(c, Colors.white, amount) ?? c;
  }

  /// 3D 光影自适应色彩加深：模拟背光面环境闭塞与下颌/关节阴影
  static Color _darken(Color c, [double amount = 0.18]) {
    return Color.lerp(c, const Color(0xFF0F172A), amount) ?? c;
  }

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

    // 4. 生动自然呼吸与骨骼形变系统 (告别机械活塞弹跳，升级为真实猫咪有机呼吸与重心摇摆)
    final breathCycle = animTime * 1.8;
    double breathY = math.sin(breathCycle) * 2.2;
    double scaleX = 1.0 - math.sin(breathCycle) * 0.015;
    double scaleY = 1.0 + math.sin(breathCycle) * 0.024;
    double bodySwayX = 0.0;

    bool isSpinBackView = false;
    double spinFeatureShiftX = 0.0;
    double spinTiltAngle = 0.0;

    if (state == 'GLASS_BOOP') {
      // 贴贴屏幕：大头贴近屏幕玻璃，可爱雀跃 (自然透视微前倾 1.06x，杜绝夸张畸变膨胀)
      scaleX = 1.06;
      scaleY = 1.06;
      breathY = math.sin(animTime * 4.0) * 3.0;
    } else if (state == 'IDLE') {
      // 待机时猫咪骨骼自然重心微摆动 (Body sway)
      bodySwayX = math.sin(animTime * 0.9) * 1.8;
      if (isPurring) {
        // 抓挠喉腔打呼噜时高频细腻喉腔有机起伏微颤
        bodySwayX += math.sin(animTime * 24.0) * 0.8;
        breathY += math.sin(animTime * 24.0) * 0.9;
      }
    } else if (state == 'EATING') {
      // 投喂进食欢快咀嚼微动
      breathY = math.sin(animTime * 14.0) * 2.5;
    } else if (state == 'HAPPY_SPIN') {
      // 3D 饱满旋空回旋跳 (彻底告别纸片式左右压扁翻折)
      final spinPhase = (animTime * 7.5) % (2 * math.pi);
      final cosVal = math.cos(spinPhase);
      final sinVal = math.sin(spinPhase);

      // 判定是否处于背对视线区间 (cos < 0 时为背影)
      isSpinBackView = (cosVal < 0);

      // 3D 圆润视宽：基于椭圆柱面投影，最窄 profile 仍保有 68% 饱满侧脸厚度，绝不塌陷为 0 像素直线！
      scaleX = math.sqrt(cosVal * cosVal + 0.46 * sinVal * sinVal);

      // 雀跃跳跃高度抛物线：凌空跃起最高达 26px
      final jumpProgress = math.sin(spinPhase).abs();
      breathY = -jumpProgress * 26.0;

      // 腾空与着陆的弹性形变 (Squash & Stretch)
      scaleY = 1.0 + (jumpProgress - 0.45) * 0.16;

      // 旋转动态倾角 (俏皮侧倾 7 度)
      spinTiltAngle = sinVal * 0.12;

      // 五官立体曲面滑动偏移 (呈现球形头部转动的立体视差)
      spinFeatureShiftX = sinVal * (isSpinBackView ? -15.0 : 15.0);

      bodySwayX = sinVal * 3.5;
    } else if (state == 'STRETCH_YAWN') {
      // 伸懒腰：身体纵向拉长，重心下沉
      scaleX = 1.18;
      scaleY = 0.86;
      breathY = 8.0;
    } else if (state == 'KNEADING_BISCUITS') {
      // 幸福踩奶：身体在温暖窝垫上微幅度左右轻缓摇曳起伏
      scaleX = 1.06;
      scaleY = 0.94;
      breathY = math.sin(animTime * 6.5).abs() * 3.0;
      bodySwayX = math.sin(animTime * 6.5) * 2.0;
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
    } else if (state == 'WALK') {
      // 漫步巡视小碎步：欢快轻盈起伏与重心交替
      breathY = -math.sin(animTime * 10.0).abs() * 4.0;
      scaleX = 1.0 + math.sin(animTime * 10.0) * 0.03;
      scaleY = 1.0 - math.sin(animTime * 10.0) * 0.02;
      bodySwayX = math.sin(animTime * 5.0) * 2.5;
    } else if (state == 'DRAGGING' || state == 'DANGLING') {
      // 方向一：物理悬空与被拎起体态 (身体受重力微拉长，四爪悬空)
      scaleX = 0.94;
      scaleY = 1.08;
      breathY = math.sin(animTime * 3.5) * 2.5;
      bodySwayX = math.sin(animTime * 2.5) * 2.0;
    } else if (state == 'HIGH_FIVE') {
      // 方向二：默契击掌 (身体微前倾)
      scaleX = 1.03;
      scaleY = 1.02;
      breathY = -2.0;
    } else if (state == 'ROLL_ON_BACK' || state == 'BUNNY_KICKS') {
      // 方向三：翻滚露肚皮与兔子蹬腿 (侧卧横躺下沉)
      scaleX = 1.12;
      scaleY = 0.92;
      breathY = 12.0;
      bodySwayX = math.sin(animTime * 4.0) * 1.5;
    } else if (state == 'DRINK_WATER') {
      // 方向四：就餐角小口舔水 (低头饮水)
      scaleX = 1.05;
      scaleY = 0.95;
      breathY = 14.0;
    } else if (state == 'SPRINT') {
      // 方向五：罐头召唤全速冲刺狂奔！
      scaleX = 1.18;
      scaleY = 0.84;
      breathY = -math.sin(animTime * 26.0).abs() * 8.0;
      bodySwayX = math.sin(animTime * 18.0) * 3.5;
    } else if (state == 'CAT_STRETCH') {
      // 方向六：猫式伸展拉伸瑜伽 (前爪贴地、屁股与尾巴高翘)
      scaleX = 1.25;
      scaleY = 0.84;
      breathY = 12.0;
    }

    // 独立地面阴影：绘制在脚底地板上，随跳跃高度柔和缩放与淡化，绝不随纸片翻折在半空中飘
    _drawGroundedShadow(canvas, center, (state == 'HAPPY_SPIN') ? breathY : 0.0);

    canvas.translate(center.dx + bodySwayX, center.dy + breathY);
    if (spinTiltAngle != 0.0) {
      canvas.rotate(spinTiltAngle);
    }
    canvas.scale(scaleX, scaleY);

    // 绘制尾巴 (背身时在身体前层欢快甩动，正面时在身体后层)
    if (!isSpinBackView) {
      _drawTail(canvas, skin);
    }

    // 绘制背部披风后摆 (挂在后背向两侧舒展，正面时在身体后层，绝不遮挡胸腹与猫爪)
    _drawBackCape(canvas, isBackView: isSpinBackView);

    // 绘制身体与背部花纹 (背身时呈现圆滚滚后背与背脊毛色)
    _drawBody(canvas, skin, isBackView: isSpinBackView);

    // 绘制头部与面部五官 (背身时展现后脑勺与耳背，隐去五官，彻底告别纸片感)
    _drawHead(canvas, skin, isBackView: isSpinBackView, featureShiftX: spinFeatureShiftX);

    // 绘制前爪 (背身时两只后爪在身体后侧支撑)
    _drawPaws(canvas, skin, isBackView: isSpinBackView);

    // 背身时尾巴在身体前层欢快甩动
    if (isSpinBackView) {
      _drawTail(canvas, skin);
    }

    // 绘制配饰 (背身时只展现颈圈系带与帽子后檐)
    _drawDecorations(canvas, isBackView: isSpinBackView);

    // 绘制绝活专属道具与特效层
    _drawActionProps(canvas, skin);

    // 绘制睡觉呼吸气泡 Zzz
    if (model.isSleeping) {
      _drawSleepZzz(canvas);
    }

    canvas.restore();
  }

  void _drawGroundedShadow(Canvas canvas, Offset center, double jumpY) {
    final jumpHeight = (-jumpY).clamp(0.0, 40.0);
    final scale = (1.0 - jumpHeight * 0.012).clamp(0.45, 1.0);
    final groundY = center.dy + 72;

    // 1. 半影漫反射柔和外晕 (Diffuse Penumbra) - 模拟空间环境光散射
    final penumbraWidth = 124.0 * scale;
    final penumbraHeight = 22.0 * scale;
    final penumbraAlpha = (0x1C * (1.0 - jumpHeight * 0.018)).clamp(4, 0x1C).toInt();
    final penumbraPaint = Paint()
      ..color = Color.fromARGB(penumbraAlpha, 0, 0, 0)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, groundY), width: penumbraWidth, height: penumbraHeight),
      penumbraPaint,
    );

    // 2. 本影接触暗核 (Contact Umbra) - 赋予猫爪与地面紧实有力的物理贴地感，跳跃腾空时自然淡化散开
    final umbraWidth = 86.0 * scale;
    final umbraHeight = 11.0 * scale;
    final umbraAlpha = (0x36 * (1.0 - jumpHeight * 0.032)).clamp(0, 0x36).toInt();
    if (umbraAlpha > 0) {
      final umbraPaint = Paint()
        ..color = Color.fromARGB(umbraAlpha, 0, 0, 0)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx, groundY + 1.0), width: umbraWidth, height: umbraHeight),
        umbraPaint,
      );
    }
  }

  void _drawTail(Canvas canvas, SkinConfig skin) {
    // 尾巴摆动速率：真实猫尾双正弦波涟漪摆动；若炸毛则受惊高频电波震颤 (Puffed tail tremor)
    double tailWag;
    if (isTailPuffed) {
      tailWag = math.sin(animTime * 35.0) * 16.0;
    } else if (state == 'SIT_WAG_TAIL') {
      tailWag = math.sin(animTime * 9.0) * 36.0 + math.sin(animTime * 18.0) * 8.0;
    } else if (state == 'STRETCH_YAWN' || state == 'CAT_STRETCH') {
      tailWag = -16.0 + math.sin(animTime * 14.0) * 6.0;
    } else if (state == 'DANGLING' || state == 'DRAGGING') {
      // 悬空时尾巴受自然重力垂直下垂微摆
      tailWag = math.sin(animTime * 4.0) * 8.0;
    } else if (state == 'ROLL_ON_BACK' || state == 'BUNNY_KICKS') {
      // 肚皮朝天时尾巴在侧边轻拍地面
      tailWag = 20.0 + math.sin(animTime * 6.0) * 10.0;
    } else if (state == 'SPRINT') {
      // 全速冲刺时尾巴向后舒展
      tailWag = -26.0 + math.sin(animTime * 24.0) * 6.0;
    } else if (state == 'HAPPY_SPIN') {
      tailWag = math.sin(animTime * 12.0) * 25.0;
    } else if (state == 'KNEADING_BISCUITS') {
      // 踩奶时尾尖微翘并惬意小幅颤动
      tailWag = 14.0 + math.sin(animTime * 6.5) * 8.0;
    } else if (state == 'WALK') {
      // 漫步巡视时尾巴轻快随动
      tailWag = 8.0 + math.sin(animTime * 10.0) * 16.0;
    } else {
      // IDLE 待机：轻缓而有韧性的猫尾涟漪摆动 (避免机械单摆)
      tailWag = math.sin(animTime * 1.6) * 14.0 + math.sin(animTime * 3.2) * 4.5;
    }

    final isLonghair = (skin.id == 'cat_ragdoll' || skin.id == 'cat_persian_white');
    final isSleek = (skin.id == 'cat_siamese' || skin.id == 'cat_black');
    final isOtter = (skin.id == 'cat_british_blue');
    final isRinged = (skin.id == 'cat_orange' || skin.id == 'cat_american_tabby');

    // 尾巴粗细形态：长毛大羽毛尾 (24) vs 粗圆水獭尾 (19) vs 纤细鞭尾 (9) vs 标准 (14)
    // 炸毛时尾巴瞬时膨大 1.65 倍！
    final double baseTailWidth;
    if (isLonghair) {
      baseTailWidth = 24.0;
    } else if (isOtter) {
      baseTailWidth = 19.0;
    } else if (isSleek) {
      baseTailWidth = 9.0;
    } else {
      baseTailWidth = 14.0;
    }
    final tailWidth = isTailPuffed ? (baseTailWidth * 1.65) : baseTailWidth;

    final tailColor = (skin.id == 'cat_siamese') ? Color(skin.secondaryColor) : Color(skin.primaryColor);
    final tailPaint = Paint()
      ..color = tailColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = tailWidth
      ..strokeCap = StrokeCap.round;

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

    // 炸毛微互动：沿尾巴向外爆出软萌锯齿毛刺 (Spiky Bristles)
    if (isTailPuffed) {
      final bristlePaint = Paint()
        ..color = tailColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      final bristles = [
        (const Offset(30, 42), const Offset(16, 48)),
        (const Offset(38, 34), const Offset(54, 40)),
        (const Offset(44, 24), const Offset(26, 18)),
        (Offset(50 + tailWag * 0.3, 12), Offset(68 + tailWag * 0.3, 18)),
        (Offset(55 + tailWag * 0.5, 0), Offset(38 + tailWag * 0.5, -6)),
        (Offset(56 + tailWag * 0.7, -12), Offset(74 + tailWag * 0.7, -8)),
        (Offset(52 + tailWag * 0.9, -22), Offset(36 + tailWag * 0.9, -30)),
        (Offset(52 + tailWag, -25), Offset(64 + tailWag, -35)),
      ];
      for (final b in bristles) {
        canvas.drawLine(b.$1, b.$2, bristlePaint);
      }
    }

    // 1. 布偶猫 & 临清狮子猫：大蓬松羽毛长毛层次
    if (isLonghair) {
      final fluffPaint = Paint()
        ..color = Color(skin.primaryColor)
        ..style = PaintingStyle.fill;
      // 沿尾巴外侧增加 2 簇蓬松羽毛波浪
      final f1 = Path()
        ..moveTo(48, 22)
        ..quadraticBezierTo(72 + tailWag * 0.4, 20, 62 + tailWag * 0.6, 5)
        ..close();
      canvas.drawPath(f1, fluffPaint);

      final f2 = Path()
        ..moveTo(56 + tailWag * 0.5, 8)
        ..quadraticBezierTo(80 + tailWag * 0.8, -8, 62 + tailWag * 0.9, -20)
        ..close();
      canvas.drawPath(f2, fluffPaint);
    }

    // 2. 中华大橘 & 美短银虎斑：环形条纹尾巴 (4 道深色环形斑纹)
    if (isRinged) {
      final ringPaint = Paint()
        ..color = Color(skin.secondaryColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(35, 36), const Offset(47, 44), ringPaint);
      canvas.drawLine(const Offset(46, 22), const Offset(58, 28), ringPaint);
      canvas.drawLine(Offset(55 + tailWag * 0.5, 6), Offset(66 + tailWag * 0.5, 11), ringPaint);
      canvas.drawLine(Offset(53 + tailWag * 0.8, -12), Offset(62 + tailWag * 0.8, -8), ringPaint);
    }

    // 尾巴尖端重点色
    final tipPaint = Paint()
      ..color = (skin.id == 'cat_siamese')
          ? Color(skin.secondaryColor)
          : (isLonghair && skin.id == 'cat_ragdoll'
              ? Color(skin.secondaryColor)
              : (skin.id == 'cat_calico' ? Color(skin.secondaryColor) : Color(skin.primaryColor)))
      ..style = PaintingStyle.fill;

    final tipOffset = (state == 'STRETCH_YAWN' || state == 'CAT_STRETCH')
        ? Offset(38 + tailWag, -70)
        : ((state == 'DANGLING' || state == 'DRAGGING')
            ? Offset(26 + tailWag, 28)
            : Offset(52 + tailWag, -25));
    final double tipRadius = isLonghair ? 12.0 : (isOtter ? 9.5 : (isSleek ? 4.5 : 7.0));
    canvas.drawCircle(tipOffset, tipRadius, tipPaint);
  }

  void _drawBody(Canvas canvas, SkinConfig skin, {bool isBackView = false}) {
    final baseColor = Color(skin.primaryColor);

    // 根据品种骨骼设定身材体型：
    // - 大橘猫：大肚子 (width 114, height 86)
    // - 暹罗/黑猫：修长流线身材 (width 82, height 72)
    // - 英短蓝猫：矮胖五短躯干 (width 104, height 78)
    // - 布偶/临清狮子：蓬松中型躯干 (width 98, height 78)
    final double bodyW;
    final double bodyH;
    final double bodyY;
    if (skin.id == 'cat_orange') {
      bodyW = 114;
      bodyH = 86;
      bodyY = 34;
    } else if (skin.id == 'cat_siamese' || skin.id == 'cat_black') {
      bodyW = 82;
      bodyH = 72;
      bodyY = 31;
    } else if (skin.id == 'cat_british_blue') {
      bodyW = 104;
      bodyH = 78;
      bodyY = 33;
    } else if (skin.id == 'cat_ragdoll' || skin.id == 'cat_persian_white') {
      bodyW = 98;
      bodyH = 78;
      bodyY = 32;
    } else {
      bodyW = 94;
      bodyH = 76;
      bodyY = 32;
    }

    final bodyRect = Rect.fromCenter(center: Offset(0, bodyY), width: bodyW, height: bodyH);

    // 3D 体积光影着色：左上方主光漫射朝光面，右下方环境阴影背光面，营造浑圆饱满的躯干体积感
    final bodyShader = RadialGradient(
      center: const Alignment(-0.24, -0.32),
      radius: 0.88,
      colors: [
        _lighten(baseColor, 0.16),
        baseColor,
        _darken(baseColor, 0.16),
      ],
      stops: const [0.0, 0.65, 1.0],
    ).createShader(bodyRect);

    final bodyPaint = Paint()
      ..shader = bodyShader
      ..style = PaintingStyle.fill;
    canvas.drawOval(bodyRect, bodyPaint);

    // 身体边缘自然毛色同色系柔和轮廓 (避免生硬人工黑线)
    final borderPaint = Paint()
      ..color = _darken(baseColor, 0.28).withOpacity(0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawOval(bodyRect, borderPaint);

    // 下巴在胸口投下的自然环境软阴影 (Chin Ambient Occlusion Shadow)
    final chinOcclusionRect = Rect.fromCenter(
      center: Offset(0, bodyY - bodyH * 0.35),
      width: bodyW * 0.66,
      height: 18,
    );
    final chinOcclusionPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _darken(baseColor, 0.38).withOpacity(0.38),
          _darken(baseColor, 0.38).withOpacity(0.0),
        ],
      ).createShader(chinOcclusionRect);
    canvas.drawOval(chinOcclusionRect, chinOcclusionPaint);

    // 如果处于 3D 旋转后背视角：呈现脊背虎斑/背部花纹，隐藏前腹白毛
    if (isBackView) {
      if (skin.id == 'cat_american_tabby' || skin.id == 'cat_orange') {
        final spinePaint = Paint()
          ..color = Color(skin.secondaryColor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(-18, 18), const Offset(18, 18), spinePaint);
        canvas.drawLine(const Offset(-22, 30), const Offset(22, 30), spinePaint);
        canvas.drawLine(const Offset(-18, 42), const Offset(18, 42), spinePaint);
      } else if (skin.id == 'cat_calico') {
        final patchOrange = Paint()..color = Color(skin.secondaryColor);
        canvas.drawOval(Rect.fromCenter(center: const Offset(-18, 28), width: 32, height: 24), patchOrange);
        final patchBlack = Paint()..color = const Color(0xFF1E293B);
        canvas.drawOval(Rect.fromCenter(center: const Offset(16, 38), width: 28, height: 22), patchBlack);
      } else if (skin.id == 'cat_siamese') {
        final backShade = Paint()..color = const Color(0x228D6E63);
        canvas.drawOval(Rect.fromCenter(center: const Offset(0, 32), width: 50, height: 40), backShade);
      }
      return;
    }

    // 1. 中华大橘：软萌大肚子浅色区域 + 侧腹经典橘红虎斑条纹
    if (skin.id == 'cat_orange') {
      final bellyPaint = Paint()..color = const Color(0xFFFFF7ED);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 44), width: 76, height: 48),
        bellyPaint,
      );
      final flankStripePaint = Paint()
        ..color = Color(skin.secondaryColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(30, 20), const Offset(50, 28), flankStripePaint);
      canvas.drawLine(const Offset(26, 30), const Offset(48, 38), flankStripePaint);
      canvas.drawLine(const Offset(22, 40), const Offset(44, 48), flankStripePaint);
    }

    // 2. 美短银虎斑：侧身经典大理石回旋涡流条纹
    if (skin.id == 'cat_american_tabby') {
      final tabbyPaint = Paint()
        ..color = Color(skin.secondaryColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;
      final swirlPath = Path()
        ..moveTo(26, 20)
        ..cubicTo(48, 22, 52, 42, 34, 46)
        ..cubicTo(20, 50, 18, 32, 30, 32);
      canvas.drawPath(swirlPath, tabbyPaint);
      canvas.drawLine(const Offset(-32, 22), const Offset(-46, 32), tabbyPaint);
      canvas.drawLine(const Offset(-28, 34), const Offset(-42, 44), tabbyPaint);
    }

    // 3. 中华三花：左黑斑 + 右橘斑大色块拼接
    if (skin.id == 'cat_calico') {
      final orangePatch = Paint()..color = Color(skin.secondaryColor);
      canvas.drawOval(Rect.fromCenter(center: const Offset(26, 26), width: 34, height: 26), orangePatch);
      final blackPatch = Paint()..color = const Color(0xFF1E293B);
      canvas.drawOval(Rect.fromCenter(center: const Offset(-24, 34), width: 28, height: 22), blackPatch);
    }

    // 4. 布偶猫 & 临清狮子猫：华丽蓬松胸毛领圈 (Lush Fluffy Chest Mane / Bib)
    if (skin.id == 'cat_ragdoll' || skin.id == 'cat_persian_white') {
      final manePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final maneShade = Paint()
        ..color = const Color(0x18000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      final manePath = Path()
        ..moveTo(-26, 10)
        ..quadraticBezierTo(-42, 24, -34, 36)
        ..quadraticBezierTo(-26, 48, -12, 46)
        ..quadraticBezierTo(0, 56, 12, 46)
        ..quadraticBezierTo(26, 48, 34, 36)
        ..quadraticBezierTo(42, 24, 26, 10)
        ..close();
      canvas.drawPath(manePath, manePaint);
      canvas.drawPath(manePath, maneShade);

      final ruffLine = Paint()
        ..color = const Color(0x22CBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(0, 22), const Offset(0, 48), ruffLine);
      canvas.drawLine(const Offset(-14, 26), const Offset(-10, 40), ruffLine);
      canvas.drawLine(const Offset(14, 26), const Offset(10, 40), ruffLine);
    }

    // 方向三：翻滚露肚皮与开心兔子蹬腿 (柔软棉花糖粉嫩大肚皮)
    if (state == 'ROLL_ON_BACK' || state == 'BUNNY_KICKS') {
      final bellyHighlight = Paint()..color = const Color(0xFFFFFBEB);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 36), width: 72, height: 50),
        bellyHighlight,
      );
      final bellyGlow = Paint()..color = const Color(0xFFFDE2E4).withOpacity(0.7);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 38), width: 44, height: 32),
        bellyGlow,
      );
    }
  }

  void _drawHead(Canvas canvas, SkinConfig skin, {bool isBackView = false, double featureShiftX = 0.0}) {
    canvas.save();

    Offset headCenter = const Offset(0, -18);

    if (isPurring) {
      // 挠下巴呼噜：下巴舒展向上仰，闭眼享受
      headCenter = const Offset(0, -22);
      canvas.rotate(-0.06);
    } else if (state == 'IDLE') {
      // 待机时灵动微倾斜与自然呼吸探视 (好奇微歪头，灵动机敏)
      final subtleTilt = math.sin(animTime * 0.7) * 0.035;
      canvas.rotate(subtleTilt);
      headCenter = Offset(math.sin(animTime * 0.6) * 1.6, -18 + math.cos(animTime * 1.2) * 0.8);
    } else if (state == 'TILT_HEAD') {
      // 歪头卖萌特技 (头部灵巧倾斜 18度)
      canvas.rotate(0.32 * math.sin(animTime * 3.5));
    } else if (state == 'LOOK_AROUND') {
      // 四处巡视时头部左右探视
      headCenter = Offset(math.sin(animTime * 2.5) * 8.0, -18);
    } else if (state == 'DOZE_OFF') {
      // 打瞌睡点头
      final nodAngle = math.max(0.0, math.sin(animTime * 2.0)) * 0.18;
      canvas.rotate(nodAngle);
    }

    // 耳朵绘制：每 5.5 秒自然机敏抖耳，摸头时高频微颤，触摸单耳独立高频弹颤
    final earCycle = animTime % 5.5;
    double earTwitch = 0.0;
    if (twitchEar != null) {
      earTwitch = math.sin(animTime * 35.0) * 6.5;
    } else if (petProgress > 0) {
      earTwitch = math.sin(animTime * 22.0) * 3.5;
    } else if (earCycle > 4.8 && earCycle < 5.15) {
      earTwitch = math.sin(animTime * 30.0) * 4.0;
    }
    final leftTwitch = (twitchEar == 'RIGHT') ? 0.0 : earTwitch;
    final rightTwitch = (twitchEar == 'LEFT') ? 0.0 : earTwitch;
    _drawEars(canvas, skin, headCenter, leftTwitch, rightTwitch, isBackView: isBackView);

    // 脑袋轮廓：不同品种差异化骨骼形态 (包子脸发腮 / 东方楔形V脸 / 长毛侧脸爆毛 / 橘猫大圆脸)
    final headBaseColor = Color(skin.primaryColor);
    final headBounds = Rect.fromCenter(center: headCenter, width: 136, height: 110);
    final headShader = RadialGradient(
      center: const Alignment(-0.22, -0.32),
      radius: 0.90,
      colors: [
        _lighten(headBaseColor, 0.18),
        headBaseColor,
        _darken(headBaseColor, 0.15),
      ],
      stops: const [0.0, 0.60, 1.0],
    ).createShader(headBounds);

    final headPaint = Paint()
      ..shader = headShader
      ..style = PaintingStyle.fill;

    if (skin.id == 'cat_british_blue') {
      // 英短蓝猫经典“包子脸”大发腮！
      canvas.drawOval(
        Rect.fromCenter(center: headCenter, width: 128, height: 92),
        headPaint,
      );
      // 左右圆滚滚饱满发腮颊肉 (Jowls)
      canvas.drawOval(
        Rect.fromCenter(center: Offset(headCenter.dx - 48, headCenter.dy + 14), width: 38, height: 38),
        headPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(headCenter.dx + 48, headCenter.dy + 14), width: 38, height: 38),
        headPaint,
      );
      // 双下巴圆润下唇弧线
      canvas.drawOval(
        Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy + 34), width: 52, height: 20),
        headPaint,
      );
    } else if (skin.id == 'cat_siamese') {
      // 暹罗猫东方楔形 V 脸 (Sleek Wedge Head - 尖锐贵气小下巴，无发腮)
      final wedgeHead = Path()
        ..moveTo(headCenter.dx - 48, headCenter.dy - 32)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy - 36, headCenter.dx + 48, headCenter.dy - 32)
        ..cubicTo(headCenter.dx + 48, headCenter.dy - 10, headCenter.dx + 38, headCenter.dy + 18, headCenter.dx + 12, headCenter.dy + 38)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy + 42, headCenter.dx - 12, headCenter.dy + 38)
        ..cubicTo(headCenter.dx - 38, headCenter.dy + 18, headCenter.dx - 48, headCenter.dy - 10, headCenter.dx - 48, headCenter.dy - 32)
        ..close();
      canvas.drawPath(wedgeHead, headPaint);
    } else if (skin.id == 'cat_ragdoll' || skin.id == 'cat_persian_white') {
      // 布偶猫 & 临清狮子猫：仙气长毛侧脸飞毛 (Fluffy Cheek Tufts)
      canvas.drawOval(
        Rect.fromCenter(center: headCenter, width: 114, height: 94),
        headPaint,
      );
      // 左侧脸颊 3 层飘逸向外爆出的长毛尖
      final leftTufts = Path()
        ..moveTo(headCenter.dx - 42, headCenter.dy - 8)
        ..lineTo(headCenter.dx - 66, headCenter.dy - 2)
        ..lineTo(headCenter.dx - 48, headCenter.dy + 8)
        ..lineTo(headCenter.dx - 68, headCenter.dy + 16)
        ..lineTo(headCenter.dx - 46, headCenter.dy + 24)
        ..lineTo(headCenter.dx - 60, headCenter.dy + 30)
        ..lineTo(headCenter.dx - 30, headCenter.dy + 38)
        ..close();
      canvas.drawPath(leftTufts, headPaint);

      // 右侧脸颊 3 层飘逸长毛尖
      final rightTufts = Path()
        ..moveTo(headCenter.dx + 42, headCenter.dy - 8)
        ..lineTo(headCenter.dx + 66, headCenter.dy - 2)
        ..lineTo(headCenter.dx + 48, headCenter.dy + 8)
        ..lineTo(headCenter.dx + 68, headCenter.dy + 16)
        ..lineTo(headCenter.dx + 46, headCenter.dy + 24)
        ..lineTo(headCenter.dx + 60, headCenter.dy + 30)
        ..lineTo(headCenter.dx + 30, headCenter.dy + 38)
        ..close();
      canvas.drawPath(rightTufts, headPaint);
    } else if (skin.id == 'cat_orange') {
      // 中华大橘：暖融融大圆头
      canvas.drawOval(
        Rect.fromCenter(center: headCenter, width: 122, height: 98),
        headPaint,
      );
    } else {
      // 标准圆润大脑袋
      canvas.drawOval(
        Rect.fromCenter(center: headCenter, width: 116, height: 96),
        headPaint,
      );
    }

    // 额头缎面微光 (Forehead Silk Sheen - 模拟光线在额穹的柔润高光)
    final foreheadGlowRect = Rect.fromCenter(
      center: Offset(headCenter.dx - 6, headCenter.dy - 18),
      width: 52,
      height: 24,
    );
    final foreheadGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(foreheadGlowRect);
    canvas.drawOval(foreheadGlowRect, foreheadGlowPaint);

    // 脑袋斑纹与皮肤特色 (三花/橘猫/暹罗/布偶/美短)
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
    } else if (skin.id == 'cat_ragdoll') {
      // 布偶猫经典海豹双色八字开脸面罩
      final maskPaint = Paint()
        ..color = Color(skin.secondaryColor).withOpacity(0.88)
        ..style = PaintingStyle.fill;
      // 左侧面罩 (围绕左眼与左脸颊)
      final leftMask = Path()
        ..moveTo(headCenter.dx - 6, headCenter.dy - 42)
        ..lineTo(headCenter.dx - 46, headCenter.dy - 24)
        ..quadraticBezierTo(headCenter.dx - 54, headCenter.dy + 12, headCenter.dx - 32, headCenter.dy + 32)
        ..quadraticBezierTo(headCenter.dx - 20, headCenter.dy + 16, headCenter.dx - 14, headCenter.dy - 8)
        ..close();
      canvas.drawPath(leftMask, maskPaint);
      // 右侧面罩 (对称围绕右眼与右脸颊)
      final rightMask = Path()
        ..moveTo(headCenter.dx + 6, headCenter.dy - 42)
        ..lineTo(headCenter.dx + 46, headCenter.dy - 24)
        ..quadraticBezierTo(headCenter.dx + 54, headCenter.dy + 12, headCenter.dx + 32, headCenter.dy + 32)
        ..quadraticBezierTo(headCenter.dx + 20, headCenter.dy + 16, headCenter.dx + 14, headCenter.dy - 8)
        ..close();
      canvas.drawPath(rightMask, maskPaint);
    } else if (skin.id == 'cat_american_tabby') {
      // 美短银虎斑额头经典 M 纹与脸颊鱼骨纹
      final tabbyPaint = Paint()
        ..color = Color(skin.secondaryColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final mPath = Path()
        ..moveTo(headCenter.dx - 15, headCenter.dy - 36)
        ..lineTo(headCenter.dx - 8, headCenter.dy - 44)
        ..lineTo(headCenter.dx, headCenter.dy - 37)
        ..lineTo(headCenter.dx + 8, headCenter.dy - 44)
        ..lineTo(headCenter.dx + 15, headCenter.dy - 36);
      canvas.drawPath(mPath, tabbyPaint);

      // 脸颊两道帅气鱼骨斑纹
      canvas.drawLine(Offset(headCenter.dx - 30, headCenter.dy + 2), Offset(headCenter.dx - 48, headCenter.dy - 1), tabbyPaint);
      canvas.drawLine(Offset(headCenter.dx - 28, headCenter.dy + 9), Offset(headCenter.dx - 45, headCenter.dy + 8), tabbyPaint);
      canvas.drawLine(Offset(headCenter.dx + 30, headCenter.dy + 2), Offset(headCenter.dx + 48, headCenter.dy - 1), tabbyPaint);
      canvas.drawLine(Offset(headCenter.dx + 28, headCenter.dy + 9), Offset(headCenter.dx + 45, headCenter.dy + 8), tabbyPaint);
    }

    // 如果处于 3D 旋转后背视角：呈现后脑勺斑纹与帽子，隐去面部五官！
    if (isBackView) {
      if (skin.id == 'cat_american_tabby' || skin.id == 'cat_orange') {
        final stripePaint = Paint()
          ..color = Color(skin.secondaryColor).withOpacity(0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(headCenter.dx - 14, headCenter.dy - 22), Offset(headCenter.dx + 14, headCenter.dy - 22), stripePaint);
        canvas.drawLine(Offset(headCenter.dx - 18, headCenter.dy - 12), Offset(headCenter.dx + 18, headCenter.dy - 12), stripePaint);
        canvas.drawLine(Offset(headCenter.dx - 12, headCenter.dy - 2), Offset(headCenter.dx + 12, headCenter.dy - 2), stripePaint);
      } else if (skin.id == 'cat_calico') {
        final patchPaint = Paint()..color = Color(skin.secondaryColor);
        canvas.drawOval(Rect.fromCenter(center: Offset(headCenter.dx - 16, headCenter.dy - 10), width: 26, height: 18), patchPaint);
      }
      _drawHeadDecorations(canvas, headCenter);
      canvas.restore();
      return;
    }

    // 正面视角：五官沿 3D 球形头面轻柔滑动
    final faceCenter = Offset(headCenter.dx + featureShiftX, headCenter.dy);

    // 腮红 (慢眨眼猫咪之吻时双颊泛起粉红微晕)
    final blushAlpha = (isSlowBlink || petProgress > 0 || state == 'HAPPY_SPIN' || state == 'KNEADING_BISCUITS') ? 0xA0 : 0x55;
    final blushPaint = Paint()
      ..color = Color.fromARGB(blushAlpha, 244, 63, 94)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(faceCenter.dx - 36, faceCenter.dy + 14), width: 18, height: 11),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(faceCenter.dx + 36, faceCenter.dy + 14), width: 18, height: 11),
      blushPaint,
    );

    // 眼睛与瞳孔
    _drawEyes(canvas, skin, faceCenter);

    // 鼻子与小嘴
    _drawNoseAndMouth(canvas, faceCenter);

    // 胡须
    _drawWhiskers(canvas, skin, faceCenter);

    // 头部帽子配饰 (随头部呼吸与歪头动态联动)
    _drawHeadDecorations(canvas, headCenter);

    canvas.restore();
  }

  void _drawEars(Canvas canvas, SkinConfig skin, Offset headCenter, double leftTwitch, double rightTwitch, {bool isBackView = false}) {
    final isPointCat = skin.id == 'cat_ragdoll' || skin.id == 'cat_siamese';

    void drawLeft(void Function() drawBlock) {
      canvas.save();
      if (isAirplaneEars) {
        final pivot = Offset(headCenter.dx - 32, headCenter.dy - 20);
        canvas.translate(pivot.dx, pivot.dy);
        canvas.rotate(-0.46);
        canvas.scale(1.16, 0.64);
        canvas.translate(-pivot.dx, -pivot.dy);
      }
      drawBlock();
      canvas.restore();
    }

    void drawRight(void Function() drawBlock) {
      canvas.save();
      if (isAirplaneEars) {
        final pivot = Offset(headCenter.dx + 32, headCenter.dy - 20);
        canvas.translate(pivot.dx, pivot.dy);
        canvas.rotate(0.46);
        canvas.scale(1.16, 0.64);
        canvas.translate(-pivot.dx, -pivot.dy);
      }
      drawBlock();
      canvas.restore();
    }

    // 辅助创建耳内透光血色渐变
    Paint createInnerEarPaint(Rect bounds, {bool isSiamese = false}) {
      if (isSiamese) {
        return Paint()
          ..shader = const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xFF3E2723), Color(0xFF5D4037), Color(0xFF795548)],
          ).createShader(bounds);
      }
      return Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Color(0xFFFB7185), // 耳根深处微血管血色
            Color(0xFFF472B6), // 耳廓饱满嫩粉
            Color(0xFFFFD5DC), // 耳尖薄软骨透光暖桃粉
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(bounds);
    }

    // 1. 暹罗猫：超大尖立耳 (Giant Tall Bat Ears，耳根极宽，高耸挺立)
    if (skin.id == 'cat_siamese') {
      final earPaint = Paint()..color = Color(skin.secondaryColor);

      // 左耳：高耸尖锐
      drawLeft(() {
        final leftEar = Path()
          ..moveTo(headCenter.dx - 50, headCenter.dy - 22)
          ..lineTo(headCenter.dx - 54 + leftTwitch, headCenter.dy - 84)
          ..lineTo(headCenter.dx - 8, headCenter.dy - 36)
          ..close();
        canvas.drawPath(leftEar, earPaint);

        if (!isBackView) {
          final leftBounds = Rect.fromLTRB(headCenter.dx - 48, headCenter.dy - 72, headCenter.dx - 14, headCenter.dy - 24);
          final leftInner = Path()
            ..moveTo(headCenter.dx - 44, headCenter.dy - 24)
            ..lineTo(headCenter.dx - 48 + leftTwitch, headCenter.dy - 72)
            ..lineTo(headCenter.dx - 14, headCenter.dy - 36)
            ..close();
          canvas.drawPath(leftInner, createInnerEarPaint(leftBounds, isSiamese: true));

          // 亨利小囊折痕 (Henry's Pocket)
          final notchPaint = Paint()
            ..color = const Color(0x35000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(headCenter.dx - 50, headCenter.dy - 28), Offset(headCenter.dx - 53, headCenter.dy - 33), notchPaint);
        }
      });

      // 右耳：高耸尖锐
      drawRight(() {
        final rightEar = Path()
          ..moveTo(headCenter.dx + 50, headCenter.dy - 22)
          ..lineTo(headCenter.dx + 54 - rightTwitch, headCenter.dy - 84)
          ..lineTo(headCenter.dx + 8, headCenter.dy - 36)
          ..close();
        canvas.drawPath(rightEar, earPaint);

        if (!isBackView) {
          final rightBounds = Rect.fromLTRB(headCenter.dx + 14, headCenter.dy - 72, headCenter.dx + 48, headCenter.dy - 24);
          final rightInner = Path()
            ..moveTo(headCenter.dx + 44, headCenter.dy - 24)
            ..lineTo(headCenter.dx + 48 - rightTwitch, headCenter.dy - 72)
            ..lineTo(headCenter.dx + 14, headCenter.dy - 36)
            ..close();
          canvas.drawPath(rightInner, createInnerEarPaint(rightBounds, isSiamese: true));

          // 亨利小囊折痕 (Henry's Pocket)
          final notchPaint = Paint()
            ..color = const Color(0x35000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(headCenter.dx + 50, headCenter.dy - 28), Offset(headCenter.dx + 53, headCenter.dy - 33), notchPaint);
        }
      });
      return;
    }

    // 2. 英短蓝猫：圆头小短耳 (宽间距，耳尖圆润温厚)
    if (skin.id == 'cat_british_blue') {
      final earPaint = Paint()..color = Color(skin.primaryColor);

      // 左耳：小巧圆润
      drawLeft(() {
        final leftEar = Path()
          ..moveTo(headCenter.dx - 48, headCenter.dy - 20)
          ..quadraticBezierTo(headCenter.dx - 44 + leftTwitch, headCenter.dy - 56, headCenter.dx - 38 + leftTwitch, headCenter.dy - 54)
          ..lineTo(headCenter.dx - 16, headCenter.dy - 38)
          ..close();
        canvas.drawPath(leftEar, earPaint);

        if (!isBackView) {
          final leftBounds = Rect.fromLTRB(headCenter.dx - 42, headCenter.dy - 48, headCenter.dx - 22, headCenter.dy - 24);
          final leftInner = Path()
            ..moveTo(headCenter.dx - 42, headCenter.dy - 24)
            ..lineTo(headCenter.dx - 36 + leftTwitch, headCenter.dy - 48)
            ..lineTo(headCenter.dx - 22, headCenter.dy - 36)
            ..close();
          canvas.drawPath(leftInner, createInnerEarPaint(leftBounds));

          // 亨利小囊折痕 (Henry's Pocket)
          final notchPaint = Paint()
            ..color = const Color(0x30000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(headCenter.dx - 47, headCenter.dy - 24), Offset(headCenter.dx - 50, headCenter.dy - 28), notchPaint);

          // 耳窝轻柔小微毛
          final microTuftPaint = Paint()
            ..color = Colors.white.withOpacity(0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(headCenter.dx - 32, headCenter.dy - 26), Offset(headCenter.dx - 38, headCenter.dy - 32), microTuftPaint);
          canvas.drawLine(Offset(headCenter.dx - 28, headCenter.dy - 28), Offset(headCenter.dx - 34, headCenter.dy - 36), microTuftPaint);
        }
      });

      // 右耳：小巧圆润
      drawRight(() {
        final rightEar = Path()
          ..moveTo(headCenter.dx + 48, headCenter.dy - 20)
          ..quadraticBezierTo(headCenter.dx + 44 - rightTwitch, headCenter.dy - 56, headCenter.dx + 38 - rightTwitch, headCenter.dy - 54)
          ..lineTo(headCenter.dx + 16, headCenter.dy - 38)
          ..close();
        canvas.drawPath(rightEar, earPaint);

        if (!isBackView) {
          final rightBounds = Rect.fromLTRB(headCenter.dx + 22, headCenter.dy - 48, headCenter.dx + 42, headCenter.dy - 24);
          final rightInner = Path()
            ..moveTo(headCenter.dx + 42, headCenter.dy - 24)
            ..lineTo(headCenter.dx + 36 - rightTwitch, headCenter.dy - 48)
            ..lineTo(headCenter.dx + 22, headCenter.dy - 36)
            ..close();
          canvas.drawPath(rightInner, createInnerEarPaint(rightBounds));

          // 亨利小囊折痕 (Henry's Pocket)
          final notchPaint = Paint()
            ..color = const Color(0x30000000)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(headCenter.dx + 47, headCenter.dy - 24), Offset(headCenter.dx + 50, headCenter.dy - 28), notchPaint);

          // 耳窝轻柔小微毛
          final microTuftPaint = Paint()
            ..color = Colors.white.withOpacity(0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(headCenter.dx + 32, headCenter.dy - 26), Offset(headCenter.dx + 38, headCenter.dy - 32), microTuftPaint);
          canvas.drawLine(Offset(headCenter.dx + 28, headCenter.dy - 28), Offset(headCenter.dx + 34, headCenter.dy - 36), microTuftPaint);
        }
      });
      return;
    }

    // 3. 中华三花 / 橘猫 / 美短 / 布偶 / 黑猫 / 临清狮子
    final leftEarBaseColor = (skin.id == 'cat_calico')
        ? const Color(0xFFE28743)
        : (isPointCat ? Color(skin.secondaryColor) : Color(skin.primaryColor));
    final rightEarBaseColor = (skin.id == 'cat_calico')
        ? const Color(0xFF1E293B)
        : (isPointCat ? Color(skin.secondaryColor) : Color(skin.primaryColor));

    // 左耳
    drawLeft(() {
      final leftEar = Path()
        ..moveTo(headCenter.dx - 45, headCenter.dy - 25)
        ..lineTo(headCenter.dx - 42 + leftTwitch, headCenter.dy - 64)
        ..lineTo(headCenter.dx - 12, headCenter.dy - 44)
        ..close();
      canvas.drawPath(leftEar, Paint()..color = leftEarBaseColor);

      if (!isBackView) {
        final leftBounds = Rect.fromLTRB(headCenter.dx - 38, headCenter.dy - 55, headCenter.dx - 18, headCenter.dy - 28);
        final leftEarInner = Path()
          ..moveTo(headCenter.dx - 38, headCenter.dy - 28)
          ..lineTo(headCenter.dx - 37 + leftTwitch, headCenter.dy - 55)
          ..lineTo(headCenter.dx - 18, headCenter.dy - 42)
          ..close();
        canvas.drawPath(leftEarInner, createInnerEarPaint(leftBounds));

        // 亨利小囊折痕 (Henry's Pocket)
        final notchPaint = Paint()
          ..color = _darken(leftEarBaseColor, 0.28).withOpacity(0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(headCenter.dx - 44, headCenter.dy - 27), Offset(headCenter.dx - 47, headCenter.dy - 32), notchPaint);

        // 基础耳窝微毛 (Base Ear Tufts)
        final microTuftPaint = Paint()
          ..color = Colors.white.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(headCenter.dx - 30, headCenter.dy - 30), Offset(headCenter.dx - 36, headCenter.dy - 38), microTuftPaint);
        canvas.drawLine(Offset(headCenter.dx - 26, headCenter.dy - 32), Offset(headCenter.dx - 32, headCenter.dy - 42), microTuftPaint);
      }
    });

    // 右耳
    drawRight(() {
      final rightEar = Path()
        ..moveTo(headCenter.dx + 45, headCenter.dy - 25)
        ..lineTo(headCenter.dx + 42 - rightTwitch, headCenter.dy - 64)
        ..lineTo(headCenter.dx + 12, headCenter.dy - 44)
        ..close();
      canvas.drawPath(rightEar, Paint()..color = rightEarBaseColor);

      if (!isBackView) {
        final rightBounds = Rect.fromLTRB(headCenter.dx + 18, headCenter.dy - 55, headCenter.dx + 38, headCenter.dy - 28);
        final rightEarInner = Path()
          ..moveTo(headCenter.dx + 38, headCenter.dy - 28)
          ..lineTo(headCenter.dx + 37 - rightTwitch, headCenter.dy - 55)
          ..lineTo(headCenter.dx + 18, headCenter.dy - 42)
          ..close();
        canvas.drawPath(rightEarInner, createInnerEarPaint(rightBounds));

        // 亨利小囊折痕 (Henry's Pocket)
        final notchPaint = Paint()
          ..color = _darken(rightEarBaseColor, 0.28).withOpacity(0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(headCenter.dx + 44, headCenter.dy - 27), Offset(headCenter.dx + 47, headCenter.dy - 32), notchPaint);

        // 基础耳窝微毛 (Base Ear Tufts)
        final microTuftPaint = Paint()
          ..color = Colors.white.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(headCenter.dx + 30, headCenter.dy - 30), Offset(headCenter.dx + 36, headCenter.dy - 38), microTuftPaint);
        canvas.drawLine(Offset(headCenter.dx + 26, headCenter.dy - 32), Offset(headCenter.dx + 32, headCenter.dy - 42), microTuftPaint);
      }
    });

    // 4. 布偶猫 & 临清狮子猫：耳内长长的仙气饰毛 (Wispy Ear Furnishings)
    if (skin.id == 'cat_ragdoll' || skin.id == 'cat_persian_white') {
      final furnishPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;

      // 左耳飘逸饰毛
      drawLeft(() {
        canvas.drawLine(
          Offset(headCenter.dx - 32, headCenter.dy - 34),
          Offset(headCenter.dx - 54 + leftTwitch * 0.4, headCenter.dy - 44),
          furnishPaint,
        );
        canvas.drawLine(
          Offset(headCenter.dx - 28, headCenter.dy - 30),
          Offset(headCenter.dx - 58 + leftTwitch * 0.4, headCenter.dy - 36),
          furnishPaint,
        );
        canvas.drawLine(
          Offset(headCenter.dx - 24, headCenter.dy - 26),
          Offset(headCenter.dx - 50 + leftTwitch * 0.4, headCenter.dy - 26),
          furnishPaint,
        );
      });

      // 右耳飘逸饰毛
      drawRight(() {
        canvas.drawLine(
          Offset(headCenter.dx + 32, headCenter.dy - 34),
          Offset(headCenter.dx + 54 - rightTwitch * 0.4, headCenter.dy - 44),
          furnishPaint,
        );
        canvas.drawLine(
          Offset(headCenter.dx + 28, headCenter.dy - 30),
          Offset(headCenter.dx + 58 - rightTwitch * 0.4, headCenter.dy - 36),
          furnishPaint,
        );
        canvas.drawLine(
          Offset(headCenter.dx + 24, headCenter.dy - 26),
          Offset(headCenter.dx + 50 - rightTwitch * 0.4, headCenter.dy - 26),
          furnishPaint,
        );
      });
    }
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

    // 2.5 慢眨眼“猫咪之吻” (Slow Blink - 极度深情的弯弯细眯笑眼与轻微睫毛，表达爱意与绝对信任)
    if (isSlowBlink) {
      final slowBlinkPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;

      for (final ec in [leftEyeCenter, rightEyeCenter]) {
        final p = Path()
          ..moveTo(ec.dx - 12, ec.dy + 1)
          ..quadraticBezierTo(ec.dx, ec.dy - 6, ec.dx + 12, ec.dy + 1);
        canvas.drawPath(p, slowBlinkPaint);
        // 上挑俏皮小睫毛
        final lashDir = (ec == leftEyeCenter) ? -1.0 : 1.0;
        canvas.drawLine(
          Offset(ec.dx + lashDir * 9, ec.dy - 1),
          Offset(ec.dx + lashDir * 13, ec.dy - 4),
          Paint()
            ..color = const Color(0xFF1E293B)
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round,
        );
      }
      return;
    }

    // 3. 闭眼/开心笑眼判断 (睡觉、洗脸理毛、伸懒腰、转圈欢喜、抚摸、双眨眼、挠下巴呼噜)
    final blinkCycle = animTime % 3.8;
    final isBlinking = model.isSleeping ||
        isPurring ||
        state == 'PEEK_A_BOO' ||
        state == 'WASH_FACE' ||
        state == 'STRETCH_YAWN' ||
        state == 'CAT_STRETCH' ||
        state == 'HAPPY_SPIN' ||
        state == 'SIT_WAG_TAIL' ||
        state == 'KNEADING_BISCUITS' ||
        state == 'ROLL_ON_BACK' ||
        state == 'BUNNY_KICKS' ||
        state == 'DRINK_WATER' ||
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

    if (touchPos != null) {
      // 眼神实时追随触碰点/移动毛线球道具
      final dx = (touchPos!.dx / 18.0).clamp(-4.5, 4.5);
      final dy = (touchPos!.dy / 18.0).clamp(-3.5, 3.5);
      gazeX = dx;
      gazeY = dy;
    } else if (state == 'IDLE') {
      // 待机眼神流转：四处好奇瞄看，宛如真实萌宠在看世界
      gazeX = math.sin(animTime * 0.85) * 2.8;
      gazeY = (math.cos(animTime * 0.45) * 1.4).clamp(-1.2, 1.8);
    } else if (state == 'LOOK_AROUND') {
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

    final eyeList = [
      (leftEyeCenter, skin.id == 'cat_persian_white' ? const Color(0xFFF59E0B) : Color(skin.eyeColor)),
      (rightEyeCenter, skin.id == 'cat_persian_white' ? const Color(0xFF0284C7) : Color(skin.eyeColor)),
    ];

    final isDilated = isHunting ||
        isNight ||
        touchPos != null ||
        petProgress > 0 ||
        state == 'CATCH_MOUSE' ||
        state == 'PLAY_YARN';

    for (final eye in eyeList) {
      final eyeCenter = eye.$1;
      final irisColor = eye.$2;

      // 俏皮单眼眨眼放电 (Wink)
      final isThisEyeWinking = (eyeCenter == leftEyeCenter && winkEye == 'LEFT') ||
          (eyeCenter == rightEyeCenter && winkEye == 'RIGHT');
      if (isThisEyeWinking) {
        final winkPaint = Paint()
          ..color = const Color(0xFF1E293B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round;
        final winkPath = Path()
          ..moveTo(eyeCenter.dx - 11, eyeCenter.dy)
          ..quadraticBezierTo(eyeCenter.dx, eyeCenter.dy - 7, eyeCenter.dx + 11, eyeCenter.dy);
        canvas.drawPath(winkPath, winkPaint);
        // 翘起的小睫毛
        canvas.drawLine(Offset(eyeCenter.dx + 10, eyeCenter.dy), Offset(eyeCenter.dx + 14, eyeCenter.dy - 4), winkPaint);
        continue;
      }

      // 眼白
      final eyeWhitePaint = Paint()..color = Colors.white;
      final eyeWhiteRect = Rect.fromCenter(center: eyeCenter, width: 22, height: 26);
      canvas.drawOval(eyeWhiteRect, eyeWhitePaint);

      // 内眼角微润感 (Inner Canthus Tear Glint)
      final isLeftEye = (eyeCenter == leftEyeCenter);
      final canthusX = isLeftEye ? eyeCenter.dx + 8.5 : eyeCenter.dx - 8.5;
      final canthusPaint = Paint()..color = const Color(0x35FB7185);
      canvas.drawCircle(Offset(canthusX, eyeCenter.dy + 3.0), 1.2, canthusPaint);

      final irisCenter = Offset(eyeCenter.dx + gazeX, eyeCenter.dy + gazeY);
      final irisRect = Rect.fromCenter(center: irisCenter, width: 17.5, height: 21.5);

      // 虹膜 3D 宝石凹面渐变 (Iris Gemstone Gradient)
      // 上方处于眼睑阴影呈现浓郁深宝石色，下方受凹面折射呈现清透焦散光泽
      final irisShader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _darken(irisColor, 0.40),
          irisColor,
          _lighten(irisColor, 0.38),
        ],
        stops: const [0.0, 0.52, 1.0],
      ).createShader(irisRect);

      // 角膜缘深色暗环 (Limbal Ring)
      final limbalPaint = Paint()
        ..color = _darken(irisColor, 0.55).withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawOval(irisRect, Paint()..shader = irisShader);
      canvas.drawOval(irisRect, limbalPaint);

      // 虹膜放射状微细肌理 (Radial Iris Fibers)
      final spokePaint = Paint()
        ..color = _lighten(irisColor, 0.45).withOpacity(0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;
      for (double angle = 0; angle < 2 * math.pi; angle += math.pi / 4) {
        final cosA = math.cos(angle);
        final sinA = math.sin(angle);
        canvas.drawLine(
          Offset(irisCenter.dx + cosA * 4.2, irisCenter.dy + sinA * 5.2),
          Offset(irisCenter.dx + cosA * 7.5, irisCenter.dy + sinA * 9.2),
          spokePaint,
        );
      }

      // 下缘焦散透光弧 (Bottom Caustic Crescent Glow)
      final causticPaint = Paint()
        ..color = _lighten(irisColor, 0.70).withOpacity(0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final causticPath = Path()
        ..moveTo(irisCenter.dx - 4.8, irisCenter.dy + 6.2)
        ..quadraticBezierTo(irisCenter.dx, irisCenter.dy + 8.8, irisCenter.dx + 4.8, irisCenter.dy + 6.2);
      canvas.drawPath(causticPath, causticPaint);

      if (isDilated) {
        // 捕猎/追光/黑夜/兴奋：黑曜石巨瞳 (曜石般圆滚大眼 + 双重璀璨大星芒高光)
        final huntPulse = isHunting ? (math.sin(animTime * 14.0) * 0.5) : 0.0;
        final pupilW = 15.2 + huntPulse;
        final pupilH = 17.8 + huntPulse;

        final pupilPaint = Paint()..color = const Color(0xFF070B14);
        canvas.drawOval(
          Rect.fromCenter(center: irisCenter, width: pupilW, height: pupilH),
          pupilPaint,
        );

        // 双重璀璨星芒高光 (主大高光 + 副小高光 + 卫星微光)
        final starPaint = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(irisCenter.dx - 3.2, irisCenter.dy - 4.2), 3.6, starPaint);
        canvas.drawCircle(Offset(irisCenter.dx + 3.4, irisCenter.dy + 3.2), 2.0, starPaint);
        canvas.drawCircle(Offset(irisCenter.dx - 0.4, irisCenter.dy - 6.2), 1.2, starPaint);
      } else {
        // 日常/清爽/白昼：灵动清透杏仁猫瞳 (Slender Almond Pupil)
        final pupilPaint = Paint()..color = const Color(0xFF090D16);
        final almondPupil = Path()
          ..moveTo(irisCenter.dx, irisCenter.dy - 8.2)
          ..quadraticBezierTo(irisCenter.dx - 3.8, irisCenter.dy, irisCenter.dx, irisCenter.dy + 8.2)
          ..quadraticBezierTo(irisCenter.dx + 3.8, irisCenter.dy, irisCenter.dx, irisCenter.dy - 8.2)
          ..close();
        canvas.drawPath(almondPupil, pupilPaint);

        // 清透晶莹多重高光
        final starPaint = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(irisCenter.dx - 2.4, irisCenter.dy - 4.0), 2.6, starPaint);
        canvas.drawCircle(Offset(irisCenter.dx + 2.0, irisCenter.dy + 2.8), 1.5, starPaint);
        canvas.drawCircle(Offset(irisCenter.dx - 0.2, irisCenter.dy - 6.0), 1.0, starPaint);
      }

      // 上眼睑眼窝自然嵌入立体投影 (Upper Eyelid Ambient Occlusion)
      final lidShadowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: const [
            Color(0x550F172A),
            Color(0x000F172A),
          ],
        ).createShader(eyeWhiteRect);
      canvas.save();
      canvas.clipPath(Path()..addOval(eyeWhiteRect));
      canvas.drawRect(eyeWhiteRect, lidShadowPaint);
      canvas.restore();

      // 精致上睫线外轮廓 (Tapered Lash Line)
      final lashLinePaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final lashPath = Path()
        ..moveTo(eyeCenter.dx - 11.0, eyeCenter.dy)
        ..quadraticBezierTo(eyeCenter.dx, eyeCenter.dy - 13.0, eyeCenter.dx + 11.0, eyeCenter.dy);
      canvas.drawPath(lashPath, lashLinePaint);
    }
  }

  void _drawNoseAndMouth(Canvas canvas, Offset headCenter) {
    final noseCenter = Offset(headCenter.dx, headCenter.dy + 11);

    // 1. 鼓鼓饱满的双侧胡须肉垫 (Puffy Muzzle Whisker Pads / 包子嘴)
    final padHighlight = Colors.white.withOpacity(0.18);
    final padShadow = const Color(0x16000000);

    // 左胡须垫
    final leftPadCenter = Offset(noseCenter.dx - 8.5, noseCenter.dy + 4.5);
    final leftPadRect = Rect.fromCenter(center: leftPadCenter, width: 17, height: 12.5);
    canvas.drawOval(leftPadRect, Paint()..color = padHighlight);
    canvas.drawOval(leftPadRect.shift(const Offset(0, 1.2)), Paint()..color = padShadow..style = PaintingStyle.stroke..strokeWidth = 0.9);

    // 右胡须垫
    final rightPadCenter = Offset(noseCenter.dx + 8.5, noseCenter.dy + 4.5);
    final rightPadRect = Rect.fromCenter(center: rightPadCenter, width: 17, height: 12.5);
    canvas.drawOval(rightPadRect, Paint()..color = padHighlight);
    canvas.drawOval(rightPadRect.shift(const Offset(0, 1.2)), Paint()..color = padShadow..style = PaintingStyle.stroke..strokeWidth = 0.9);

    // 肉垫微毛囊点 (Whisker Follicle Micro-dots)
    final folliclePaint = Paint()..color = const Color(0x3564748B);
    for (final dot in [
      Offset(leftPadCenter.dx - 3.5, leftPadCenter.dy - 1.5),
      Offset(leftPadCenter.dx + 1.2, leftPadCenter.dy - 2.2),
      Offset(leftPadCenter.dx - 1.0, leftPadCenter.dy + 1.8),
      Offset(leftPadCenter.dx - 4.5, leftPadCenter.dy + 2.0),
    ]) {
      canvas.drawCircle(dot, 0.75, folliclePaint);
    }
    for (final dot in [
      Offset(rightPadCenter.dx + 3.5, rightPadCenter.dy - 1.5),
      Offset(rightPadCenter.dx - 1.2, rightPadCenter.dy - 2.2),
      Offset(rightPadCenter.dx + 1.0, rightPadCenter.dy + 1.8),
      Offset(rightPadCenter.dx + 4.5, rightPadCenter.dy + 2.0),
    ]) {
      canvas.drawCircle(dot, 0.75, folliclePaint);
    }

    // 2. 立体皮革质感圆润心形小肉鼻 (Leather 3D Heart Nose)
    final noseRect = Rect.fromCenter(center: noseCenter, width: 9.0, height: 6.8);
    final noseShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFDA4AF),
        Color(0xFFFB7185),
        Color(0xFFE11D48),
      ],
      stops: [0.0, 0.45, 1.0],
    ).createShader(noseRect);

    final nosePath = Path()
      ..moveTo(noseCenter.dx - 4.4, noseCenter.dy - 2.2)
      ..quadraticBezierTo(noseCenter.dx, noseCenter.dy - 3.4, noseCenter.dx + 4.4, noseCenter.dy - 2.2)
      ..quadraticBezierTo(noseCenter.dx + 4.0, noseCenter.dy + 1.2, noseCenter.dx, noseCenter.dy + 3.4)
      ..quadraticBezierTo(noseCenter.dx - 4.0, noseCenter.dy + 1.2, noseCenter.dx - 4.4, noseCenter.dy - 2.2)
      ..close();
    canvas.drawPath(nosePath, Paint()..shader = noseShader);

    // 鼻梁湿润高光微斑 (Moist Bridge Specular Glint)
    final noseGlintPaint = Paint()..color = Colors.white.withOpacity(0.85);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(noseCenter.dx - 0.8, noseCenter.dy - 1.3), width: 3.2, height: 1.3),
      noseGlintPaint,
    );

    // 左右一对逼真月牙小鼻孔 (Nostril Slits / Nares)
    final nostrilPaint = Paint()
      ..color = const Color(0xFF881337)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(noseCenter.dx - 2.4, noseCenter.dy + 0.6),
      Offset(noseCenter.dx - 1.1, noseCenter.dy + 2.0),
      nostrilPaint,
    );
    canvas.drawLine(
      Offset(noseCenter.dx + 2.4, noseCenter.dy + 0.6),
      Offset(noseCenter.dx + 1.1, noseCenter.dy + 2.0),
      nostrilPaint,
    );

    // 人中中缝微垂直暗槽 (Philtrum Groove)
    final philtrumPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(noseCenter.dx, noseCenter.dy + 3.2), Offset(noseCenter.dx, noseCenter.dy + 5.2), philtrumPaint);

    // 嘴巴绘制
    if (state == 'STRETCH_YAWN' || state == 'CAT_STRETCH') {
      // 伸懒腰打大哈欠 (张大的圆嘴巴 + 粉红小舌头)
      final yawnPaint = Paint()..color = const Color(0xFF451A03);
      canvas.drawOval(Rect.fromCenter(center: Offset(noseCenter.dx, noseCenter.dy + 8), width: 14, height: 18), yawnPaint);
      final tonguePaint = Paint()..color = const Color(0xFFFB7185);
      canvas.drawOval(Rect.fromCenter(center: Offset(noseCenter.dx, noseCenter.dy + 12), width: 10, height: 9), tonguePaint);
      return;
    }

    if (state == 'DRINK_WATER') {
      // 小口舔水吧唧动画 (粉嫩小舌尖规律快速探出)
      final lapCycle = math.sin(animTime * 16.0);
      final openMouth = Paint()..color = const Color(0xFF451A03);
      canvas.drawOval(Rect.fromCenter(center: Offset(noseCenter.dx, noseCenter.dy + 5), width: 8, height: 5), openMouth);
      if (lapCycle > 0) {
        final tongue = Paint()..color = const Color(0xFFFB7185);
        canvas.drawOval(Rect.fromCenter(center: Offset(noseCenter.dx, noseCenter.dy + 7 + lapCycle * 2.5), width: 6, height: 5), tongue);
      }
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
          ..moveTo(noseCenter.dx - 8, noseCenter.dy + 5)
          ..quadraticBezierTo(noseCenter.dx, noseCenter.dy + 10, noseCenter.dx + 8, noseCenter.dy + 5);
        canvas.drawPath(p, happyMouth);
      }
      return;
    }

    if (state == 'GLASS_BOOP') {
      final happyMouth = Paint()
        ..color = const Color(0xFF334155)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      final p = Path()
        ..moveTo(noseCenter.dx - 8, noseCenter.dy + 5)
        ..quadraticBezierTo(noseCenter.dx, noseCenter.dy + 12, noseCenter.dx + 8, noseCenter.dy + 5);
      canvas.drawPath(p, happyMouth);
      return;
    }

    // 治愈 ω 微笑猫嘴
    final mouthPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final mouthLeft = Path()
      ..moveTo(noseCenter.dx, noseCenter.dy + 5.2)
      ..quadraticBezierTo(noseCenter.dx - 6, noseCenter.dy + 10.5, noseCenter.dx - 12, noseCenter.dy + 6.5);
    canvas.drawPath(mouthLeft, mouthPaint);

    final mouthRight = Path()
      ..moveTo(noseCenter.dx, noseCenter.dy + 5.2)
      ..quadraticBezierTo(noseCenter.dx + 6, noseCenter.dy + 10.5, noseCenter.dx + 12, noseCenter.dy + 6.5);
    canvas.drawPath(mouthRight, mouthPaint);

    // 下唇/小下巴自然环境凹影 (Lower Lip / Chin Crease Shadow)
    final chinShadowPaint = Paint()..color = const Color(0x18000000);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(noseCenter.dx, noseCenter.dy + 11.8), width: 12, height: 5),
      chinShadowPaint,
    );

    // 呆萌吐小舌头 (Blep)
    if (isBlep) {
      final blepPaint = Paint()..color = const Color(0xFFFB7185);
      final blepBorder = Paint()
        ..color = const Color(0xFFF43F5E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final blepPath = Path()
        ..moveTo(noseCenter.dx - 3.8, noseCenter.dy + 5.8)
        ..lineTo(noseCenter.dx + 3.8, noseCenter.dy + 5.8)
        ..quadraticBezierTo(noseCenter.dx + 3.8, noseCenter.dy + 11.2, noseCenter.dx, noseCenter.dy + 11.8)
        ..quadraticBezierTo(noseCenter.dx - 3.8, noseCenter.dy + 11.2, noseCenter.dx - 3.8, noseCenter.dy + 5.8)
        ..close();
      canvas.drawPath(blepPath, blepPaint);
      canvas.drawPath(blepPath, blepBorder);
      // 舌头中间微浅小中缝
      final groovePaint = Paint()
        ..color = const Color(0xFFF43F5E).withOpacity(0.6)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(noseCenter.dx, noseCenter.dy + 6.0), Offset(noseCenter.dx, noseCenter.dy + 10.2), groovePaint);
    }
  }

  void _drawWhiskers(Canvas canvas, SkinConfig skin, Offset headCenter) {
    final whiskerColor = (skin.id == 'cat_black') ? const Color(0xFFE2E8F0) : const Color(0x7594A3B8);
    final whiskerPaint = Paint()
      ..color = whiskerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // 1. 左侧自然重力悬垂 3 根胡须 (符合物理悬链线下垂弧度)
    // 上胡须：先微扬后舒缓外垂
    final leftTop = Path()
      ..moveTo(headCenter.dx - 18, headCenter.dy + 11)
      ..quadraticBezierTo(headCenter.dx - 38, headCenter.dy + 6, headCenter.dx - 58, headCenter.dy + 9);
    canvas.drawPath(leftTop, whiskerPaint);

    // 中胡须：优雅平舒主须
    final leftMid = Path()
      ..moveTo(headCenter.dx - 19, headCenter.dy + 14)
      ..quadraticBezierTo(headCenter.dx - 40, headCenter.dy + 15, headCenter.dx - 60, headCenter.dy + 18);
    canvas.drawPath(leftMid, whiskerPaint);

    // 下胡须：自然受重力下弧垂
    final leftBot = Path()
      ..moveTo(headCenter.dx - 18, headCenter.dy + 17)
      ..quadraticBezierTo(headCenter.dx - 38, headCenter.dy + 22, headCenter.dx - 55, headCenter.dy + 26);
    canvas.drawPath(leftBot, whiskerPaint);

    // 2. 右侧自然重力悬垂 3 根胡须
    // 上胡须
    final rightTop = Path()
      ..moveTo(headCenter.dx + 18, headCenter.dy + 11)
      ..quadraticBezierTo(headCenter.dx + 38, headCenter.dy + 6, headCenter.dx + 58, headCenter.dy + 9);
    canvas.drawPath(rightTop, whiskerPaint);

    // 中胡须
    final rightMid = Path()
      ..moveTo(headCenter.dx + 19, headCenter.dy + 14)
      ..quadraticBezierTo(headCenter.dx + 40, headCenter.dy + 15, headCenter.dx + 60, headCenter.dy + 18);
    canvas.drawPath(rightMid, whiskerPaint);

    // 下胡须
    final rightBot = Path()
      ..moveTo(headCenter.dx + 18, headCenter.dy + 17)
      ..quadraticBezierTo(headCenter.dx + 38, headCenter.dy + 22, headCenter.dx + 55, headCenter.dy + 26);
    canvas.drawPath(rightBot, whiskerPaint);

    // 3. 额头眉毛触觉须 (Superciliary Whiskers - 猫咪标志性超长纤细眉毛触须)
    final browPaint = Paint()
      ..color = whiskerColor.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    // 左眉须：从左眼上方优雅上扬外飘
    final leftBrow = Path()
      ..moveTo(headCenter.dx - 14, headCenter.dy - 14)
      ..quadraticBezierTo(headCenter.dx - 26, headCenter.dy - 26, headCenter.dx - 36, headCenter.dy - 32);
    canvas.drawPath(leftBrow, browPaint);

    // 右眉须：从右眼上方对称上扬外飘
    final rightBrow = Path()
      ..moveTo(headCenter.dx + 14, headCenter.dy - 14)
      ..quadraticBezierTo(headCenter.dx + 26, headCenter.dy - 26, headCenter.dx + 36, headCenter.dy - 32);
    canvas.drawPath(rightBrow, browPaint);
  }

  void _drawPlumpSegmentedPaw(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Color pawColor, {
    bool hasWhiteSock = false,
  }) {
    // 1. 掌心主基底轮廓 (3D 体积光照)
    final baseRect = Rect.fromCenter(center: center, width: width, height: height);
    final baseShader = RadialGradient(
      center: const Alignment(-0.20, -0.35),
      radius: 0.85,
      colors: [
        _lighten(pawColor, 0.16),
        pawColor,
        _darken(pawColor, 0.14),
      ],
      stops: const [0.0, 0.65, 1.0],
    ).createShader(baseRect);

    final basePaint = Paint()
      ..shader = baseShader
      ..style = PaintingStyle.fill;
    canvas.drawOval(baseRect, basePaint);

    // 2. 前方 3 瓣肉嘟嘟小脚趾 (山竹分瓣小爪：外趾、中趾、内趾)
    final toeRadius = height * 0.38;
    final toeY = center.dy + height * 0.22;
    final toeDx1 = center.dx - width * 0.26;
    final toeDx2 = center.dx;
    final toeDx3 = center.dx + width * 0.26;

    final toeHighlightPaint = Paint()..color = Colors.white.withOpacity(0.18);
    for (final tdx in [toeDx1, toeDx2, toeDx3]) {
      final toeCenter = Offset(tdx, toeY);
      canvas.drawCircle(toeCenter, toeRadius, basePaint);
      // 趾背立体缎面微光
      canvas.drawOval(
        Rect.fromCenter(center: Offset(tdx - 0.4, toeY - 1.2), width: toeRadius * 1.1, height: toeRadius * 0.8),
        toeHighlightPaint,
      );
    }

    // 3. 趾缝间微细自然阴影线 (Interdigital Creases)
    final creasePaint = Paint()
      ..color = _darken(pawColor, 0.32).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final cleft1X = (toeDx1 + toeDx2) / 2;
    final cleft2X = (toeDx2 + toeDx3) / 2;
    canvas.drawLine(Offset(cleft1X, toeY - toeRadius * 0.75), Offset(cleft1X, toeY + toeRadius * 0.85), creasePaint);
    canvas.drawLine(Offset(cleft2X, toeY - toeRadius * 0.75), Offset(cleft2X, toeY + toeRadius * 0.85), creasePaint);

    // 4. 爪边缘自然毛色同色系柔和轮廓
    final borderPaint = Paint()
      ..color = _darken(pawColor, 0.28).withOpacity(0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawOval(baseRect, borderPaint);

    // 5. 黑猫踏雪寻梅：纯白小手套雪花爪尖
    if (hasWhiteSock) {
      final whitePaint = Paint()..color = Colors.white;
      for (final tdx in [toeDx1, toeDx2, toeDx3]) {
        canvas.drawCircle(Offset(tdx, toeY + 1.0), toeRadius * 0.85, whitePaint);
      }
    }
  }

  void _drawPaws(Canvas canvas, SkinConfig skin, {bool isBackView = false}) {
    final pawPaint = Paint()..color = Color(skin.primaryColor);
    final pawBorder = Paint()
      ..color = const Color(0x15000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 背身视角：在身体后方两侧露出可爱后脚爪
    if (isBackView) {
      canvas.drawOval(Rect.fromCenter(center: const Offset(-24, 60), width: 22, height: 16), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(-24, 60), width: 22, height: 16), pawBorder);
      canvas.drawOval(Rect.fromCenter(center: const Offset(24, 60), width: 22, height: 16), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(24, 60), width: 22, height: 16), pawBorder);
      return;
    }

    // 贴贴屏幕：两只粉白小爪平贴在前方玻璃上，露出粉嫩肉垫
    if (state == 'GLASS_BOOP') {
      for (final px in [-38.0, 38.0]) {
        final pawCenter = Offset(px, 16);
        final pawRect = Rect.fromCenter(center: pawCenter, width: 28, height: 26);
        canvas.drawOval(pawRect, pawPaint);
        canvas.drawOval(pawRect, pawBorder);

        // 肉垫中心掌印 (3D 渐变心形肉垫)
        final padRect = Rect.fromCenter(center: pawCenter, width: 14, height: 11);
        final padShader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFDA4AF), Color(0xFFFB7185), Color(0xFFE11D48)],
        ).createShader(padRect);
        canvas.drawOval(padRect, Paint()..shader = padShader);
        // 掌心肉垫高光
        canvas.drawOval(
          Rect.fromCenter(center: Offset(pawCenter.dx - 1.0, pawCenter.dy - 1.5), width: 5.5, height: 2.8),
          Paint()..color = Colors.white.withOpacity(0.55),
        );

        // 四个可爱小脚趾肉球 (Toe Beans)
        final beanPaint = Paint()..color = const Color(0xFFFB7185);
        final beanGlint = Paint()..color = Colors.white.withOpacity(0.65);
        final toeBeans = [
          Offset(pawCenter.dx - 9, pawCenter.dy - 8),
          Offset(pawCenter.dx - 3.5, pawCenter.dy - 12),
          Offset(pawCenter.dx + 3.5, pawCenter.dy - 12),
          Offset(pawCenter.dx + 9, pawCenter.dy - 8),
        ];
        for (final tb in toeBeans) {
          canvas.drawCircle(tb, 3.2, beanPaint);
          canvas.drawCircle(Offset(tb.dx - 0.7, tb.dy - 0.7), 1.0, beanGlint);
        }
      }
      return;
    }

    // 遮眼躲猫猫：两只前爪抬起到眼睛前捂住脸颊
    if (state == 'PEEK_A_BOO') {
      canvas.save();
      canvas.translate(-16, -2);
      canvas.rotate(0.2);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 24, height: 20), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 24, height: 20), pawBorder);
      canvas.restore();

      canvas.save();
      canvas.translate(16, -2);
      canvas.rotate(-0.2);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 24, height: 20), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 24, height: 20), pawBorder);
      canvas.restore();
      return;
    }

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

    // 治愈踩奶特技 (Making Biscuits)：双前爪在松软窝垫中富有节奏地轮流深浅下踩，粉嫩肉垫张合
    if (state == 'KNEADING_BISCUITS') {
      final kneadCycle = animTime * 6.5;
      final leftPush = math.sin(kneadCycle) * 6.0;
      final rightPush = -math.sin(kneadCycle) * 6.0;

      final leftCenter = Offset(-24, 52 + leftPush);
      final rightCenter = Offset(24, 52 + rightPush);
      final leftSpread = leftPush > 1.2 ? 3.0 : 0.0;
      final rightSpread = rightPush > 1.2 ? 3.0 : 0.0;

      // 左爪与爪边
      canvas.drawOval(Rect.fromCenter(center: leftCenter, width: 24 + leftSpread, height: 18), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: leftCenter, width: 24 + leftSpread, height: 18), pawBorder);
      // 右爪与爪边
      canvas.drawOval(Rect.fromCenter(center: rightCenter, width: 24 + rightSpread, height: 18), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: rightCenter, width: 24 + rightSpread, height: 18), pawBorder);

      // 踩在垫子上受力时显现的粉嫩肉垫
      final padPaint = Paint()..color = const Color(0xFFFB7185).withOpacity(0.9);
      if (leftPush > 0.8) {
        canvas.drawOval(Rect.fromCenter(center: Offset(leftCenter.dx, leftCenter.dy + 1), width: 10, height: 8), padPaint);
      }
      if (rightPush > 0.8) {
        canvas.drawOval(Rect.fromCenter(center: Offset(rightCenter.dx, rightCenter.dy + 1), width: 10, height: 8), padPaint);
      }
      return;
    }

    // 方向一：悬空拎起体态：双前爪向中间收拢悬垂，双后脚爪自然垂下微晃
    if (state == 'DANGLING' || state == 'DRAGGING') {
      final dangleWiggle = math.sin(animTime * 5.0) * 2.5;
      // 前爪向中收拢悬垂
      canvas.drawOval(Rect.fromCenter(center: Offset(-14, 50 + dangleWiggle), width: 20, height: 16), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(-14, 50 + dangleWiggle), width: 20, height: 16), pawBorder);
      canvas.drawOval(Rect.fromCenter(center: Offset(14, 50 - dangleWiggle), width: 20, height: 16), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(14, 50 - dangleWiggle), width: 20, height: 16), pawBorder);
      // 后爪悬挂向下微摆
      canvas.drawOval(Rect.fromCenter(center: Offset(-20, 68 - dangleWiggle), width: 18, height: 14), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(-20, 68 - dangleWiggle), width: 18, height: 14), pawBorder);
      canvas.drawOval(Rect.fromCenter(center: Offset(20, 68 + dangleWiggle), width: 18, height: 14), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(20, 68 + dangleWiggle), width: 18, height: 14), pawBorder);
      return;
    }

    // 方向二：指尖击掌：左前爪稳稳撑地，右前爪向前高高抬起展示粉嫩肉垫
    if (state == 'HIGH_FIVE') {
      // 左前爪着地 (分瓣立体萌爪)
      _drawPlumpSegmentedPaw(canvas, const Offset(-22, 60), 22, 16, Color(skin.primaryColor), hasWhiteSock: skin.id == 'cat_black');

      // 右前爪抬起迎合击掌 (露出粉嫩 3D 肉垫与 4 颗外低内高脚趾)
      final highPawCenter = Offset(32, 16 + math.sin(animTime * 6.0) * 2.5);
      final highPawRect = Rect.fromCenter(center: highPawCenter, width: 26, height: 24);
      canvas.drawOval(highPawRect, pawPaint);
      canvas.drawOval(highPawRect, pawBorder);

      // 饱满掌心肉垫
      final padRect = Rect.fromCenter(center: highPawCenter, width: 13, height: 10);
      final padShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDA4AF), Color(0xFFFB7185), Color(0xFFE11D48)],
      ).createShader(padRect);
      canvas.drawOval(padRect, Paint()..shader = padShader);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(highPawCenter.dx - 0.8, highPawCenter.dy - 1.2), width: 5.0, height: 2.5),
        Paint()..color = Colors.white.withOpacity(0.55),
      );

      // 4 颗圆润粉嫩小肉球 (Toe Beans)
      final beanPaint = Paint()..color = const Color(0xFFFB7185);
      final beanGlint = Paint()..color = Colors.white.withOpacity(0.65);
      final toeBeans = [
        Offset(highPawCenter.dx - 8, highPawCenter.dy - 7),
        Offset(highPawCenter.dx - 3, highPawCenter.dy - 11),
        Offset(highPawCenter.dx + 3, highPawCenter.dy - 11),
        Offset(highPawCenter.dx + 8, highPawCenter.dy - 7),
      ];
      for (final tb in toeBeans) {
        canvas.drawCircle(tb, 3.0, beanPaint);
        canvas.drawCircle(Offset(tb.dx - 0.6, tb.dy - 0.6), 0.9, beanGlint);
      }
      return;
    }

    // 方向三：翻滚露肚皮与开心兔子蹬腿
    if (state == 'ROLL_ON_BACK' || state == 'BUNNY_KICKS') {
      // 前爪向胸口蜷起
      canvas.drawOval(Rect.fromCenter(center: const Offset(-20, 22), width: 20, height: 16), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(-20, 22), width: 20, height: 16), pawBorder);
      canvas.drawOval(Rect.fromCenter(center: const Offset(20, 22), width: 20, height: 16), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(20, 22), width: 20, height: 16), pawBorder);
      // 后爪在空中欢快踢踏 (兔子蹬腿则高频双向踩单车)
      final kickAmp = state == 'BUNNY_KICKS' ? 14.0 : 4.0;
      final kickSpeed = state == 'BUNNY_KICKS' ? 24.0 : 6.0;
      final kickL = math.sin(animTime * kickSpeed) * kickAmp;
      final kickR = -math.sin(animTime * kickSpeed) * kickAmp;
      final hindLPaw = Offset(-30, 52 + kickL);
      final hindRPaw = Offset(30, 52 + kickR);
      canvas.drawOval(Rect.fromCenter(center: hindLPaw, width: 22, height: 18), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: hindLPaw, width: 22, height: 18), pawBorder);
      canvas.drawOval(Rect.fromCenter(center: hindRPaw, width: 22, height: 18), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: hindRPaw, width: 22, height: 18), pawBorder);
      // 露出的后脚粉嫩小肉垫
      final padPaint = Paint()..color = const Color(0xFFFB7185);
      canvas.drawOval(Rect.fromCenter(center: hindLPaw, width: 9, height: 7), padPaint);
      canvas.drawOval(Rect.fromCenter(center: hindRPaw, width: 9, height: 7), padPaint);
      return;
    }

    // 方向四：就餐角小口饮水
    if (state == 'DRINK_WATER') {
      canvas.drawOval(Rect.fromCenter(center: const Offset(-18, 56), width: 22, height: 16), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(-18, 56), width: 22, height: 16), pawBorder);
      canvas.drawOval(Rect.fromCenter(center: const Offset(18, 56), width: 22, height: 16), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(18, 56), width: 22, height: 16), pawBorder);
      return;
    }

    // 方向五：全速冲刺狂奔 (罐头召唤)
    if (state == 'SPRINT') {
      final runCycle = animTime * 24.0;
      final leftStride = math.sin(runCycle) * 12.0;
      final rightStride = -math.sin(runCycle) * 12.0;
      canvas.drawOval(Rect.fromCenter(center: Offset(-20 + leftStride, 58), width: 24, height: 16), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(-20 + leftStride, 58), width: 24, height: 16), pawBorder);
      canvas.drawOval(Rect.fromCenter(center: Offset(20 + rightStride, 58), width: 24, height: 16), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: Offset(20 + rightStride, 58), width: 24, height: 16), pawBorder);
      return;
    }

    // 方向六：正宗猫式伸展拉伸 (双前爪前伸贴地)
    if (state == 'CAT_STRETCH') {
      canvas.drawOval(Rect.fromCenter(center: const Offset(-36, 68), width: 28, height: 14), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(-36, 68), width: 28, height: 14), pawBorder);
      canvas.drawOval(Rect.fromCenter(center: const Offset(36, 68), width: 28, height: 14), pawPaint);
      canvas.drawOval(Rect.fromCenter(center: const Offset(36, 68), width: 28, height: 14), pawBorder);
      return;
    }

    // 漫步小碎步踱步：双前爪交替抬落起伏 (分瓣萌态小肉爪)
    if (state == 'WALK') {
      final pawW = (skin.id == 'cat_orange') ? 26.0 : ((skin.id == 'cat_siamese') ? 19.0 : 22.0);
      final pawH = (skin.id == 'cat_orange') ? 18.0 : ((skin.id == 'cat_siamese') ? 14.0 : 16.0);
      final stepCycle = animTime * 10.0;
      final leftLift = math.sin(stepCycle).clamp(0.0, 1.0) * 8.0;
      final rightLift = (-math.sin(stepCycle)).clamp(0.0, 1.0) * 8.0;
      final leftShift = math.cos(stepCycle) * 3.5;
      final rightShift = -math.cos(stepCycle) * 3.5;

      _drawPlumpSegmentedPaw(
        canvas,
        Offset(-22 + leftShift, 60 - leftLift),
        pawW,
        pawH,
        Color(skin.primaryColor),
        hasWhiteSock: skin.id == 'cat_black',
      );
      _drawPlumpSegmentedPaw(
        canvas,
        Offset(22 + rightShift, 60 - rightLift),
        pawW,
        pawH,
        Color(skin.primaryColor),
        hasWhiteSock: skin.id == 'cat_black',
      );
      return;
    }

    // 普通静止前爪：不同品种爪爪肥瘦差异 (大橘厚爪 vs 暹罗细爪 vs 黑猫白手套)
    // 升级为肉嘟嘟 3 瓣分瓣山竹小爪 (立体缎面光泽 + 趾缝微阴影)
    final pawW = (skin.id == 'cat_orange') ? 26.0 : ((skin.id == 'cat_siamese') ? 19.0 : 22.0);
    final pawH = (skin.id == 'cat_orange') ? 18.0 : ((skin.id == 'cat_siamese') ? 14.0 : 16.0);
    _drawPlumpSegmentedPaw(
      canvas,
      const Offset(-22, 60),
      pawW,
      pawH,
      Color(skin.primaryColor),
      hasWhiteSock: skin.id == 'cat_black',
    );
    _drawPlumpSegmentedPaw(
      canvas,
      const Offset(22, 60),
      pawW,
      pawH,
      Color(skin.primaryColor),
      hasWhiteSock: skin.id == 'cat_black',
    );
  }

  void _drawDecorations(Canvas canvas, {bool isBackView = false}) {
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
        ..quadraticBezierTo(0, isBackView ? 16 : 26, 20, 20);
      canvas.drawPath(collarPath, collarPaint);

      if (isBackView) return; // 背面不画正面的铃铛

      // 金色小铃铛
      final bellPaint = Paint()..color = const Color(0xFFFBBF24);
      canvas.drawCircle(const Offset(0, 25), 6.5, bellPaint);
      final bellHolePaint = Paint()..color = const Color(0xFF78350F);
      canvas.drawCircle(const Offset(0, 26), 1.8, bellHolePaint);
    } else if (neckDeco == 'ribbon') {
      if (isBackView) {
        final ribbonBand = Paint()
          ..color = const Color(0xFFF43F5E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.6;
        canvas.drawLine(const Offset(-18, 20), const Offset(18, 20), ribbonBand);
        return;
      }
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
    } else if (neckDeco == 'bowtie') {
      // 英伦绅士深蓝小领结
      final bowPaint = Paint()..color = const Color(0xFF1E293B);
      final leftWing = Path()
        ..moveTo(0, 24)
        ..lineTo(-16, 18)
        ..lineTo(-16, 30)
        ..close();
      canvas.drawPath(leftWing, bowPaint);
      final rightWing = Path()
        ..moveTo(0, 24)
        ..lineTo(16, 18)
        ..lineTo(16, 30)
        ..close();
      canvas.drawPath(rightWing, bowPaint);
      // 中心金扣
      canvas.drawCircle(const Offset(0, 24), 4.0, Paint()..color = const Color(0xFFEAB308));
    } else if (neckDeco == 'scarf') {
      // 暖冬红围巾
      final scarfPaint = Paint()
        ..color = const Color(0xFFE11D48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7.0
        ..strokeCap = StrokeCap.round;
      final scarfNeck = Path()
        ..moveTo(-22, 21)
        ..quadraticBezierTo(0, 27, 22, 21);
      canvas.drawPath(scarfNeck, scarfPaint);

      // 下垂围巾下摆
      final tailPaint = Paint()
        ..color = const Color(0xFFBE123C)
        ..style = PaintingStyle.fill;
      final tailPath = Path()
        ..moveTo(5, 23)
        ..lineTo(15, 23)
        ..lineTo(16, 44)
        ..lineTo(4, 44)
        ..close();
      canvas.drawPath(tailPath, tailPaint);

      // 流苏白线
      final fringePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (int i = 6; i <= 14; i += 3) {
        canvas.drawLine(Offset(i.toDouble(), 44), Offset(i.toDouble(), 48), fringePaint);
      }
    } else if (neckDeco == 'royal_cape') {
      // 🦸‍♂️ 皇家丝绒披风前饰 (正面视角：仅绘制纯金领扣与双肩搭扣，披风主体在身后飘逸；背面视角：披风主体覆盖后背)
      if (isBackView) {
        // 背面视角：披风覆盖后背，展示威武金纹与丝绒褶皱
        final capePaint = Paint()
          ..color = const Color(0xFF581C87)
          ..style = PaintingStyle.fill;
        final goldTrim = Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;

        final capePath = Path()
          ..moveTo(-22, 18)
          ..quadraticBezierTo(-38, 44, -30, 68)
          ..quadraticBezierTo(0, 74, 30, 68)
          ..quadraticBezierTo(38, 44, 22, 18)
          ..close();
        canvas.drawPath(capePath, capePaint);
        canvas.drawPath(capePath, goldTrim);

        // 背部皇家金徽刺绣
        final emblemPaint = Paint()
          ..color = const Color(0xFFFBBF24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawCircle(const Offset(0, 42), 7.0, emblemPaint);
        canvas.drawLine(const Offset(-4, 42), const Offset(4, 42), emblemPaint);
        canvas.drawLine(const Offset(0, 38), const Offset(0, 46), emblemPaint);
      } else {
        // 正面视角：精致纯金领链与星辉红宝石胸扣，披风主体在身后的 _drawBackCape 绘制，胸腹与爪爪绝不遮挡！
        final chainPaint = Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
        final chainPath = Path()
          ..moveTo(-20, 20)
          ..quadraticBezierTo(0, 26, 20, 20);
        canvas.drawPath(chainPath, chainPaint);

        // 两侧纯金肩扣
        final goldBuckle = Paint()..color = const Color(0xFFF59E0B);
        canvas.drawCircle(const Offset(-19, 20), 3.2, goldBuckle);
        canvas.drawCircle(const Offset(19, 20), 3.2, goldBuckle);

        // 领口中央星辉皇家宝扣 (纯金底托配深红宝石与高光)
        canvas.drawCircle(const Offset(0, 24), 5.5, goldBuckle);
        final rubyPaint = Paint()..color = const Color(0xFFE11D48);
        canvas.drawCircle(const Offset(0, 24), 3.2, rubyPaint);
        canvas.drawCircle(const Offset(-1, 23), 1.0, Paint()..color = Colors.white);
      }
    }
  }

  /// 绘制背部披风后摆 (挂在后背，正面视角下垂于身体后侧向两翼自然舒展，绝不遮挡肚子和爪爪)
  void _drawBackCape(Canvas canvas, {bool isBackView = false}) {
    final neckDeco = model.decorations['neck'];
    if (neckDeco != 'royal_cape') return;
    if (isBackView) return; // 背面视角在 _drawDecorations 中绘制覆盖在背上的披风主体

    final capePaint = Paint()
      ..color = const Color(0xFF581C87)
      ..style = PaintingStyle.fill;
    final goldTrim = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    // 自然微风拂动飘逸波动
    final wave = math.sin(animTime * 3.2) * 3.5;
    final wave2 = math.cos(animTime * 3.2) * 2.0;

    // 披风后摆：从后肩向后背两侧舒展，宽于猫咪身体轮廓
    final capePath = Path()
      ..moveTo(-22, 22)
      ..cubicTo(-46 + wave, 44, -44 + wave, 62, -34 + wave, 72)
      ..quadraticBezierTo(0, 78 + wave2, 34 + wave, 72)
      ..cubicTo(44 + wave, 62, 46 + wave, 44, 22, 22)
      ..close();

    canvas.drawPath(capePath, capePaint);
    canvas.drawPath(capePath, goldTrim);

    // 披风内衬深紫丝绒阴影细节
    final innerFold = Paint()
      ..color = const Color(0xFF3B0764).withOpacity(0.4)
      ..style = PaintingStyle.fill;
    final innerPath = Path()
      ..moveTo(-18, 26)
      ..quadraticBezierTo(-34 + wave, 52, -26 + wave, 70)
      ..quadraticBezierTo(0, 74 + wave2, 26 + wave, 70)
      ..quadraticBezierTo(34 + wave, 52, 18, 26)
      ..close();
    canvas.drawPath(innerPath, innerFold);
  }

  /// 绘制头部帽子配饰
  void _drawHeadDecorations(Canvas canvas, Offset headCenter) {
    final headDeco = model.decorations['head'];
    if (headDeco == null || headDeco == 'none') return;

    if (headDeco == 'gold_crown_sparkle') {
      // 👑 专属·璀璨星辉皇冠 (羁绊4阶专属装扮：五峰纯金大王冠 + 红蓝星钻 + 环绕微光星尘)
      final crownCenter = Offset(headCenter.dx, headCenter.dy - 48);
      final goldPaint = Paint()..color = const Color(0xFFFBBF24);
      final crownBase = Path()
        ..moveTo(crownCenter.dx - 24, crownCenter.dy)
        ..lineTo(crownCenter.dx - 26, crownCenter.dy - 22)
        ..lineTo(crownCenter.dx - 12, crownCenter.dy - 10)
        ..lineTo(crownCenter.dx, crownCenter.dy - 28)
        ..lineTo(crownCenter.dx + 12, crownCenter.dy - 10)
        ..lineTo(crownCenter.dx + 26, crownCenter.dy - 22)
        ..lineTo(crownCenter.dx + 24, crownCenter.dy)
        ..close();
      canvas.drawPath(crownBase, goldPaint);

      final rimPaint = Paint()
        ..color = const Color(0xFFD97706)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(crownBase, rimPaint);

      // 顶峰三颗闪耀红钻
      canvas.drawCircle(Offset(crownCenter.dx, crownCenter.dy - 28), 3.6, Paint()..color = const Color(0xFFEF4444));
      canvas.drawCircle(Offset(crownCenter.dx - 26, crownCenter.dy - 22), 2.8, Paint()..color = const Color(0xFF3B82F6));
      canvas.drawCircle(Offset(crownCenter.dx + 26, crownCenter.dy - 22), 2.8, Paint()..color = const Color(0xFF3B82F6));

      // 皇冠环绕微光星尘
      final starAngle = animTime * 3.5;
      final starX = crownCenter.dx + math.cos(starAngle) * 28.0;
      final starY = crownCenter.dy - 16.0 + math.sin(starAngle) * 7.0;
      canvas.drawCircle(Offset(starX, starY), 2.2, Paint()..color = Colors.white);
    } else if (headDeco == 'crown') {
      // 👑 璀璨金冠
      final crownCenter = Offset(headCenter.dx, headCenter.dy - 46);
      final goldPaint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.fill;
      final crownBase = Path()
        ..moveTo(crownCenter.dx - 22, crownCenter.dy)
        ..lineTo(crownCenter.dx - 24, crownCenter.dy - 18)
        ..lineTo(crownCenter.dx - 10, crownCenter.dy - 8)
        ..lineTo(crownCenter.dx, crownCenter.dy - 24)
        ..lineTo(crownCenter.dx + 10, crownCenter.dy - 8)
        ..lineTo(crownCenter.dx + 24, crownCenter.dy - 18)
        ..lineTo(crownCenter.dx + 22, crownCenter.dy)
        ..close();
      canvas.drawPath(crownBase, goldPaint);

      final rimPaint = Paint()
        ..color = const Color(0xFFD97706)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawPath(crownBase, rimPaint);

      // 皇冠底圈饰带
      final bandPaint = Paint()..color = const Color(0xFFB45309);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(crownCenter.dx, crownCenter.dy - 1), width: 44, height: 5),
          const Radius.circular(2.5),
        ),
        bandPaint,
      );

      // 三颗宝石 (中红，左绿，右蓝)
      canvas.drawCircle(Offset(crownCenter.dx, crownCenter.dy - 23), 3.2, Paint()..color = const Color(0xFFEF4444));
      canvas.drawCircle(Offset(crownCenter.dx - 23, crownCenter.dy - 17), 2.5, Paint()..color = const Color(0xFF10B981));
      canvas.drawCircle(Offset(crownCenter.dx + 23, crownCenter.dy - 17), 2.5, Paint()..color = const Color(0xFF0284C7));
    } else if (headDeco == 'wizard_hat') {
      // 🧙‍♂️ 魔法巫师帽
      final baseCenter = Offset(headCenter.dx, headCenter.dy - 44);
      final hatPaint = Paint()..color = const Color(0xFF312E81);
      final hatGold = Paint()..color = const Color(0xFFFBBF24);

      // 帽檐
      canvas.drawOval(Rect.fromCenter(center: baseCenter, width: 56, height: 14), hatPaint);

      // 尖帽身 (向右微曲，生动灵秀)
      final cone = Path()
        ..moveTo(baseCenter.dx - 18, baseCenter.dy - 2)
        ..cubicTo(
          baseCenter.dx - 10, baseCenter.dy - 25,
          baseCenter.dx - 2, baseCenter.dy - 45,
          baseCenter.dx + 22, baseCenter.dy - 58,
        )
        ..cubicTo(
          baseCenter.dx + 12, baseCenter.dy - 40,
          baseCenter.dx + 8, baseCenter.dy - 25,
          baseCenter.dx + 18, baseCenter.dy - 2,
        )
        ..close();
      canvas.drawPath(cone, hatPaint);

      // 金色帽围缎带
      final ribbonPaint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawLine(Offset(baseCenter.dx - 17, baseCenter.dy - 3), Offset(baseCenter.dx + 17, baseCenter.dy - 3), ribbonPaint);

      // 尖端小星徽
      canvas.drawCircle(Offset(baseCenter.dx + 22, baseCenter.dy - 58), 3.2, hatGold);
    } else if (headDeco == 'straw_hat') {
      // 👒 田园草帽
      final baseCenter = Offset(headCenter.dx, headCenter.dy - 44);
      final strawColor = Paint()..color = const Color(0xFFFDE047);
      final strawDark = Paint()
        ..color = const Color(0xFFCA8A04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      // 宽帽檐
      canvas.drawOval(Rect.fromCenter(center: baseCenter, width: 62, height: 16), strawColor);
      canvas.drawOval(Rect.fromCenter(center: baseCenter, width: 62, height: 16), strawDark);

      // 帽顶半球
      final dome = Path()
        ..moveTo(baseCenter.dx - 18, baseCenter.dy)
        ..cubicTo(
          baseCenter.dx - 18, baseCenter.dy - 22,
          baseCenter.dx + 18, baseCenter.dy - 22,
          baseCenter.dx + 18, baseCenter.dy,
        )
        ..close();
      canvas.drawPath(dome, strawColor);
      canvas.drawPath(dome, strawDark);

      // 红色系带
      final ribbon = Paint()..color = const Color(0xFFEF4444);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(baseCenter.dx, baseCenter.dy - 2), width: 36, height: 4),
          const Radius.circular(2),
        ),
        ribbon,
      );
      // 飘动缎带小尾巴
      canvas.drawLine(Offset(baseCenter.dx + 18, baseCenter.dy), Offset(baseCenter.dx + 26, baseCenter.dy + 12), ribbon..style = PaintingStyle.stroke..strokeWidth = 2.5);
    } else if (headDeco == 'sailor_cap') {
      // ⚓ 蔚蓝水手帽
      final baseCenter = Offset(headCenter.dx, headCenter.dy - 44);
      final capPaint = Paint()..color = const Color(0xFFF8FAFC);

      // 帽子主体 (向上略微外扩的水手无檐帽)
      final bodyPath = Path()
        ..moveTo(baseCenter.dx - 22, baseCenter.dy)
        ..lineTo(baseCenter.dx - 26, baseCenter.dy - 20)
        ..quadraticBezierTo(baseCenter.dx, baseCenter.dy - 24, baseCenter.dx + 26, baseCenter.dy - 20)
        ..lineTo(baseCenter.dx + 22, baseCenter.dy)
        ..close();
      canvas.drawPath(bodyPath, capPaint);

      // 蓝色包边条纹
      final navyBand = Paint()
        ..color = const Color(0xFF1E3A8A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawLine(Offset(baseCenter.dx - 22, baseCenter.dy), Offset(baseCenter.dx + 22, baseCenter.dy), navyBand);

      // 帽子中心金黄小徽章
      final goldBadge = Paint()..color = const Color(0xFFEAB308);
      canvas.drawCircle(Offset(baseCenter.dx, baseCenter.dy - 12), 3.0, goldBadge);
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

    // 6. 欢喜转圈 (星光与金星 3D 环绕光环)
    else if (state == 'HAPPY_SPIN') {
      for (int i = 0; i < 6; i++) {
        final angle = animTime * 8.5 + i * (math.pi / 3);
        final sx = math.cos(angle) * 62.0;
        final sy = -14.0 + math.sin(angle) * 22.0;
        final depth = math.sin(angle);
        final starSize = depth > 0 ? 17.0 : 12.0;

        final spPainter = TextPainter(
          text: TextSpan(
            text: i % 2 == 0 ? '✨' : '⭐',
            style: TextStyle(fontSize: starSize),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        spPainter.paint(canvas, Offset(sx - starSize / 2, sy - starSize / 2));
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
