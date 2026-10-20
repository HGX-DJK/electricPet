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
  final double userScale;    // 双指捏合无级缩放 (0.75x ~ 1.45x)
  final double tiltX;        // 手机加速度计/陀螺仪倾角 (-1.0 ~ 1.0)

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
    this.userScale = 1.0,
    this.tiltX = 0.0,
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

    // 0. 绘制家园小窝场景 (Habitat: 代码雨 / 像素电玩 / 夏日海滩 / 榻榻米樱花)
    _drawHabitatEffects(canvas, size, center);

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

    // 双指捏合无级缩放 (以宠物中心为锚点)
    if (userScale != 1.0) {
      canvas.translate(center.dx, center.dy);
      canvas.scale(userScale, userScale);
      canvas.translate(-center.dx, -center.dy);
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
      // 🐱 真实猫咪原地追尾巴大回旋 (Chasing Own Tail Vortex!)
      // 真实猫咪追尾巴是身体弓曲呈圆环，在地面小步急促奔跑狂转，脑袋向内盯住尾尖，尾巴甩在身前撩拨
      final chasePhase = (animTime * 6.5) % (2 * math.pi);
      final cosVal = math.cos(chasePhase);
      final sinVal = math.sin(chasePhase);

      // 地面 2.5D 透视环形追击圆周运动 (沿地面椭圆急促狂奔)
      const orbitRadiusX = 18.0;
      const orbitRadiusY = 8.0;
      bodySwayX = cosVal * orbitRadiusX;
      breathY = sinVal * orbitRadiusY;

      // 处于后半圆弧度时呈现追击背影，处于前半圆时呈现追击正面
      isSpinBackView = (sinVal < -0.2);

      // 追尾弓身月牙形变与离心力侧倾 (漂移压弯体态)
      spinTiltAngle = cosVal * 0.18;
      scaleX = 1.04 + math.sin(chasePhase * 2.0).abs() * 0.05;
      scaleY = 0.96 - math.sin(chasePhase * 2.0).abs() * 0.04;

      // 头部向内侧拧转盯尾巴
      spinFeatureShiftX = cosVal * 12.0;
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
    } else if (state == 'PLAY_YARN') {
      // 玩毛线球：身体压低低重心伏地扑球，左右欢快起伏轻摇，与双爪拍击节奏共振
      scaleX = 1.06 + math.sin(animTime * 7.0) * 0.03;
      scaleY = 0.96 - math.sin(animTime * 7.0) * 0.02;
      breathY = 4.5 + math.sin(animTime * 14.0).abs() * 2.0;
      bodySwayX = math.sin(animTime * 7.0) * 3.5;
    }

    // 手机重力/陀螺仪倾角动态融入待机与巡视重心
    if (state == 'IDLE' || state == 'WALK' || state == 'LOOK_AROUND') {
      bodySwayX += (tiltX * 8.0);
    }

    // 禅意蒲团软垫 (佛系大懒喵或榻榻米房专属地毯软垫)
    _drawZenCushion(canvas, center);

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

    // 绘制背部披风后摆与背部配饰 (挂在后背向两侧舒展，正面时在身体后层，绝不遮挡胸腹与猫爪)
    _drawBackDecorations(canvas, isBackView: isSpinBackView);

    // 绘制身体与背部花纹 (背身时呈现圆滚滚后背与背脊毛色)
    _drawBody(canvas, skin, isBackView: isSpinBackView);

    // 绘制头部与面部五官 (背身时展现后脑勺与耳背，隐去五官，彻底告别纸片感)
    _drawHead(canvas, skin, isBackView: isSpinBackView, featureShiftX: spinFeatureShiftX);

    // 绘制前爪 (背身时两只后爪在身体后侧支撑)
    _drawPaws(canvas, skin, isBackView: isSpinBackView);

    // 绘制前爪手持道具 (RGB机械键盘、全息逗猫棒、极客冷萃、像素掌机、能量哑铃)
    if (!isSpinBackView) {
      _drawHandDecorations(canvas);
    }

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
      tailWag = math.sin(animTime * 14.0) * 10.0;
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

    final isLonghair = (skin.id == 'cat_ragdoll' || skin.id == 'cat_persian_white' || skin.id == 'cat_maine_coon' || skin.id == 'cat_sakura_peach');
    final isSleek = (skin.id == 'cat_siamese' || skin.id == 'cat_black' || skin.id == 'cat_tuxedo');
    final isOtter = (skin.id == 'cat_british_blue' || skin.id == 'cat_golden_shaded' || skin.id == 'cat_silver_shaded');
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

    final tailColor = (skin.id == 'cat_siamese')
        ? Color(skin.secondaryColor)
        : ((skin.id == 'cat_tuxedo') ? const Color(0xFF1E293B) : Color(skin.primaryColor));
    final tailPaint = Paint()
      ..color = tailColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = tailWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (state == 'HAPPY_SPIN') {
      // 🐱 追尾巴：尾巴向前环抱卷曲到身侧，尾尖在面颊与小爪爪前方疯狂摇晃诱惑！
      path.moveTo(25, 42);
      path.cubicTo(50 + tailWag * 0.3, 16, 26 + tailWag, -18, -6 + tailWag * 0.7, -6);
    } else if (state == 'STRETCH_YAWN') {
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
    final Color tipCol;
    if (skin.id == 'cat_tuxedo') {
      tipCol = Colors.white;
    } else if (skin.id == 'cat_siamese' || skin.id == 'cat_ragdoll' || skin.id == 'cat_calico' || skin.id == 'cat_golden_shaded' || skin.id == 'cat_silver_shaded' || skin.id == 'cat_maine_coon') {
      tipCol = Color(skin.secondaryColor);
    } else if (skin.id == 'cat_sakura_peach') {
      tipCol = const Color(0xFFF472B6);
    } else {
      tipCol = Color(skin.primaryColor);
    }
    final tipPaint = Paint()
      ..color = tipCol
      ..style = PaintingStyle.fill;

    final tipOffset = (state == 'HAPPY_SPIN')
        ? Offset(-6 + tailWag * 0.7, -6)
        : ((state == 'STRETCH_YAWN' || state == 'CAT_STRETCH')
            ? Offset(38 + tailWag, -70)
            : ((state == 'DANGLING' || state == 'DRAGGING')
                ? Offset(26 + tailWag, 28)
                : Offset(52 + tailWag, -25)));
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
    if (skin.id == 'cat_orange' || skin.id == 'cat_maine_coon') {
      bodyW = 114;
      bodyH = 86;
      bodyY = 34;
    } else if (skin.id == 'cat_siamese' || skin.id == 'cat_black') {
      bodyW = 84;
      bodyH = 74;
      bodyY = 31;
    } else if (skin.id == 'cat_british_blue' || skin.id == 'cat_golden_shaded' || skin.id == 'cat_silver_shaded') {
      bodyW = 106;
      bodyH = 80;
      bodyY = 33;
    } else if (skin.id == 'cat_ragdoll' || skin.id == 'cat_persian_white' || skin.id == 'cat_sakura_peach') {
      bodyW = 98;
      bodyH = 78;
      bodyY = 32;
    } else if (skin.id == 'cat_tuxedo') {
      bodyW = 96;
      bodyH = 76;
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
      ..color = _darken(baseColor, 0.28).withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawOval(bodyRect, borderPaint);

    // 躯干柔和边缘微绒毛流光 (Soft Fur Rim Lighting - 模拟逆光与真实生物毛绒边缘感)
    final rimPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.24, -0.32),
        radius: 0.98,
        colors: [
          Colors.transparent,
          _lighten(baseColor, 0.28).withValues(alpha: 0.0),
          _lighten(baseColor, 0.28).withValues(alpha: 0.32),
        ],
        stops: const [0.0, 0.82, 1.0],
      ).createShader(bodyRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawOval(bodyRect, rimPaint);

    // 下巴在胸口投下的自然环境软阴影 (Chin Ambient Occlusion Shadow)
    final chinOcclusionRect = Rect.fromCenter(
      center: Offset(0, bodyY - bodyH * 0.35),
      width: bodyW * 0.66,
      height: 18,
    );
    final chinOcclusionPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _darken(baseColor, 0.38).withValues(alpha: 0.38),
          _darken(baseColor, 0.38).withValues(alpha: 0.0),
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

    // 3. 中华三花：温柔日系软杏 + 暖灰斑
    if (skin.id == 'cat_calico') {
      final orangePatch = Paint()..color = const Color(0xFFFF9E7D);
      canvas.drawOval(Rect.fromCenter(center: const Offset(26, 26), width: 34, height: 26), orangePatch);
      final blackPatch = Paint()..color = const Color(0xFF64748B).withValues(alpha: 0.85);
      canvas.drawOval(Rect.fromCenter(center: const Offset(-24, 34), width: 28, height: 22), blackPatch);
    }

    // 3.1 黑白奶牛猫：笔挺雪白燕尾衬衣胸脯
    if (skin.id == 'cat_tuxedo') {
      final bibPaint = Paint()..color = Colors.white;
      final bibPath = Path()
        ..moveTo(-18, 12)
        ..quadraticBezierTo(-32, 28, -20, 50)
        ..quadraticBezierTo(0, 60, 20, 50)
        ..quadraticBezierTo(32, 28, 18, 12)
        ..close();
      canvas.drawPath(bibPath, bibPaint);
    }

    // 3.2 金渐层 & 银渐层：柔和雪白软萌肚腹
    if (skin.id == 'cat_golden_shaded' || skin.id == 'cat_silver_shaded') {
      final bibPaint = Paint()..color = const Color(0xFFFFFDF8);
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, 42), width: 68, height: 46), bibPaint);
    }

    // 3.3 森林缅因猫：侧身森林野性斑纹
    if (skin.id == 'cat_maine_coon') {
      final stripePaint = Paint()
        ..color = Color(skin.secondaryColor).withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(28, 22), const Offset(48, 30), stripePaint);
      canvas.drawLine(const Offset(24, 34), const Offset(45, 42), stripePaint);
      canvas.drawLine(const Offset(-28, 22), const Offset(-48, 30), stripePaint);
      canvas.drawLine(const Offset(-24, 34), const Offset(-45, 42), stripePaint);
    }

    // 3.4 樱花蜜桃猫：柔粉蜜桃大肚腩
    if (skin.id == 'cat_sakura_peach') {
      final peachPaint = Paint()..color = const Color(0xFFFFEEF4);
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, 42), width: 64, height: 44), peachPaint);
    }

    // 4. 布偶猫 & 临清狮子猫 & 缅因猫 & 樱花猫：华丽蓬松胸毛领圈 (Lush Fluffy Chest Mane / Bib)
    if (skin.id == 'cat_ragdoll' || skin.id == 'cat_persian_white' || skin.id == 'cat_maine_coon' || skin.id == 'cat_sakura_peach') {
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
      final bellyGlow = Paint()..color = const Color(0xFFFDE2E4).withValues(alpha: 0.7);
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
    } else if (state == 'PLAY_YARN') {
      // 专注盯球：小脑瓜灵巧低头并随爪爪扑球节奏微幅歪头注视
      final yarnHeadTilt = math.sin(animTime * 7.0) * 0.08;
      canvas.rotate(yarnHeadTilt);
      headCenter = Offset(math.sin(animTime * 7.0) * 1.5, -15);
    } else if (state == 'HAPPY_SPIN') {
      // 🐱 追尾巴：小脑瓜聚精会神向内下倾，眼神紧锁侧前方的尾巴尖！
      headCenter = const Offset(-6, -14);
      canvas.rotate(-0.18);
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

    if (skin.id == 'cat_british_blue' || skin.id == 'cat_golden_shaded' || skin.id == 'cat_silver_shaded') {
      // 英短蓝猫/金渐层/银渐层经典“包子脸”大发腮！
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
    } else if (skin.id == 'cat_ragdoll' || skin.id == 'cat_persian_white' || skin.id == 'cat_maine_coon' || skin.id == 'cat_sakura_peach') {
      // 布偶/临清狮子/缅因/樱花：仙气长毛侧脸飞毛 (Fluffy Cheek Tufts)
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
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(foreheadGlowRect);
    canvas.drawOval(foreheadGlowRect, foreheadGlowPaint);

    // 头部轮廓柔和微绒光 (Head Silhouette Rim Glow - 逼真绒毛微光层)
    final headRimPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.22, -0.32),
        radius: 0.98,
        colors: [
          Colors.transparent,
          _lighten(headBaseColor, 0.28).withValues(alpha: 0.0),
          _lighten(headBaseColor, 0.28).withValues(alpha: 0.30),
        ],
        stops: const [0.0, 0.85, 1.0],
      ).createShader(headBounds)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(headBounds, headRimPaint);

    // 脑袋斑纹与皮肤特色 (三花/橘猫/暹罗/布偶/美短/奶牛/金渐层/银渐层/缅因/樱花)
    if (skin.id == 'cat_tuxedo') {
      final blazePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      // 洁白开脸八字鼻梁与白胡须口套 (White Blaze & Muzzle)
      final blazePath = Path()
        ..moveTo(headCenter.dx, headCenter.dy - 22)
        ..lineTo(headCenter.dx - 12, headCenter.dy + 8)
        ..quadraticBezierTo(headCenter.dx - 28, headCenter.dy + 18, headCenter.dx - 24, headCenter.dy + 38)
        ..quadraticBezierTo(headCenter.dx, headCenter.dy + 42, headCenter.dx + 24, headCenter.dy + 38)
        ..quadraticBezierTo(headCenter.dx + 28, headCenter.dy + 18, headCenter.dx + 12, headCenter.dy + 8)
        ..close();
      canvas.drawPath(blazePath, blazePaint);
    } else if (skin.id == 'cat_golden_shaded') {
      final goldShader = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFDE68A).withValues(alpha: 0.45),
            const Color(0xFFD97706).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy - 16), width: 64, height: 36));
      canvas.drawOval(Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy - 16), width: 64, height: 36), goldShader);
    } else if (skin.id == 'cat_silver_shaded') {
      final silverShader = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.65),
            const Color(0xFF94A3B8).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy - 16), width: 64, height: 36));
      canvas.drawOval(Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy - 16), width: 64, height: 36), silverShader);
    } else if (skin.id == 'cat_maine_coon') {
      final tabbyPaint = Paint()
        ..color = Color(skin.secondaryColor).withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8
        ..strokeCap = StrokeCap.round;
      final mPath = Path()
        ..moveTo(headCenter.dx - 14, headCenter.dy - 34)
        ..lineTo(headCenter.dx - 7, headCenter.dy - 42)
        ..lineTo(headCenter.dx, headCenter.dy - 36)
        ..lineTo(headCenter.dx + 7, headCenter.dy - 42)
        ..lineTo(headCenter.dx + 14, headCenter.dy - 34);
      canvas.drawPath(mPath, tabbyPaint);
    } else if (skin.id == 'cat_sakura_peach') {
      final petalPaint = Paint()
        ..color = const Color(0xFFF472B6).withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(headCenter.dx + 28, headCenter.dy - 24), 5.5, petalPaint);
      canvas.drawCircle(Offset(headCenter.dx + 35, headCenter.dy - 18), 4.0, petalPaint);
    } else if (skin.id == 'cat_calico') {
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
        ..color = Color(skin.secondaryColor).withValues(alpha: 0.90)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(headCenter.dx, headCenter.dy + 8), width: 56, height: 44),
        maskPaint,
      );
    } else if (skin.id == 'cat_ragdoll') {
      // 布偶猫经典海豹双色八字开脸面罩
      final maskPaint = Paint()
        ..color = Color(skin.secondaryColor).withValues(alpha: 0.88)
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
          ..color = Color(skin.secondaryColor).withValues(alpha: 0.65)
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

    // 面部配饰 (黑框眼镜、酷炫墨镜、极客全息战术目镜)
    _drawFaceDecorations(canvas, faceCenter);

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
            ..color = Colors.white.withValues(alpha: 0.55)
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
            ..color = Colors.white.withValues(alpha: 0.55)
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
          ..color = _darken(leftEarBaseColor, 0.28).withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(headCenter.dx - 44, headCenter.dy - 27), Offset(headCenter.dx - 47, headCenter.dy - 32), notchPaint);

        // 基础耳窝微毛 (Base Ear Tufts)
        final microTuftPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
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
          ..color = _darken(rightEarBaseColor, 0.28).withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(headCenter.dx + 44, headCenter.dy - 27), Offset(headCenter.dx + 47, headCenter.dy - 32), notchPaint);

        // 基础耳窝微毛 (Base Ear Tufts)
        final microTuftPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(headCenter.dx + 30, headCenter.dy - 30), Offset(headCenter.dx + 36, headCenter.dy - 38), microTuftPaint);
        canvas.drawLine(Offset(headCenter.dx + 26, headCenter.dy - 32), Offset(headCenter.dx + 32, headCenter.dy - 42), microTuftPaint);
      }
    });

    // 4. 布偶猫 & 临清狮子猫 & 樱花猫：耳内长长的仙气饰毛 (Wispy Ear Furnishings)
    if (skin.id == 'cat_ragdoll' || skin.id == 'cat_persian_white' || skin.id == 'cat_sakura_peach') {
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

    // 5. 森林缅因猫：威风凛凛的猞猁耳尖羽 (Lynx Ear Tips)
    if (skin.id == 'cat_maine_coon') {
      final tuftPaint = Paint()
        ..color = Color(skin.secondaryColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;

      drawLeft(() {
        canvas.drawLine(Offset(headCenter.dx - 42 + leftTwitch, headCenter.dy - 64), Offset(headCenter.dx - 49 + leftTwitch, headCenter.dy - 78), tuftPaint);
        canvas.drawLine(Offset(headCenter.dx - 42 + leftTwitch, headCenter.dy - 64), Offset(headCenter.dx - 45 + leftTwitch, headCenter.dy - 82), tuftPaint);
        canvas.drawLine(Offset(headCenter.dx - 42 + leftTwitch, headCenter.dy - 64), Offset(headCenter.dx - 40 + leftTwitch, headCenter.dy - 77), tuftPaint);
      });

      drawRight(() {
        canvas.drawLine(Offset(headCenter.dx + 42 - rightTwitch, headCenter.dy - 64), Offset(headCenter.dx + 49 - rightTwitch, headCenter.dy - 78), tuftPaint);
        canvas.drawLine(Offset(headCenter.dx + 42 - rightTwitch, headCenter.dy - 64), Offset(headCenter.dx + 45 - rightTwitch, headCenter.dy - 82), tuftPaint);
        canvas.drawLine(Offset(headCenter.dx + 42 - rightTwitch, headCenter.dy - 64), Offset(headCenter.dx + 40 - rightTwitch, headCenter.dy - 77), tuftPaint);
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
    } else if (state == 'HAPPY_SPIN') {
      // 🐱 追尾巴：眼神死死锁定身侧前方疯狂摇晃挑逗的尾尖！
      gazeX = 3.8 + math.sin(animTime * 14.0) * 1.0;
      gazeY = 2.8;
    } else if (state == 'IDLE') {
      // 待机眼神流转：四处好奇瞄看，手机倾斜时随重力感应偏转
      gazeX = (math.sin(animTime * 0.85) * 2.8 + tiltX * 2.5).clamp(-4.5, 4.5);
      gazeY = (math.cos(animTime * 0.45) * 1.4).clamp(-1.2, 1.8);
    } else if (state == 'LOOK_AROUND') {
      // 四处巡视眼神移动
      gazeX = (math.sin(animTime * 2.5) * 4.5 + tiltX * 2.0).clamp(-5.0, 5.0);
    } else if (state == 'CHASE_BUTTERFLY') {
      // 抬头盯蝴蝶
      gazeX = math.sin(animTime * 3.2) * 3.0;
      gazeY = -4.0;
    } else if (state == 'CATCH_MOUSE') {
      // 俯视盯小老鼠
      gazeX = math.sin(animTime * 4.5) * 4.0;
      gazeY = 3.5;
    } else if (state == 'PLAY_YARN') {
      // 玩毛线球：专注低头盯球，瞳孔随球在双爪间快速晃动
      gazeX = math.sin(animTime * 7.0) * 3.5;
      gazeY = 4.2;
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
        state == 'PLAY_YARN' ||
        state == 'HAPPY_SPIN';

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
      canvas.drawOval(Rect.fromCenter(center: eyeCenter, width: 22, height: 26), eyeWhitePaint);

      // 1. 内眼角微粉泪阜 (Inner Canthus / Caruncle - 生物级自然红润)
      final isLeftEye = (eyeCenter == leftEyeCenter);
      final canthusX = isLeftEye ? eyeCenter.dx + 10.8 : eyeCenter.dx - 10.8;
      final canthusPaint = Paint()..color = const Color(0x75F472B6);
      canvas.drawCircle(Offset(canthusX, eyeCenter.dy + 3.5), 1.8, canthusPaint);

      // 金渐层 & 银渐层标志性天然浓密眼线 (Distinctive Natural Eyeliner)
      if (skin.id == 'cat_golden_shaded' || skin.id == 'cat_silver_shaded') {
        final eyelinerPaint = Paint()
          ..color = const Color(0xFF1E293B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawOval(Rect.fromCenter(center: eyeCenter, width: 22.8, height: 26.8), eyelinerPaint);
      }

      final irisCenter = Offset(eyeCenter.dx + gazeX, eyeCenter.dy + gazeY);
      final irisRect = Rect.fromCenter(center: irisCenter, width: 17.5, height: 21.5);

      // 2. 角膜缘柔和深色暗环 (Limbal Ring)
      final limbalPaint = Paint()
        ..color = (skin.id == 'cat_golden_shaded' || skin.id == 'cat_silver_shaded')
            ? const Color(0x75000000)
            : const Color(0x38000000);
      canvas.drawOval(Rect.fromCenter(center: irisCenter, width: 18.5, height: 22.5), limbalPaint);

      // 3. 虹膜 3D 宝石凹面渐变 (Iris Gemstone Gradient)
      final irisShader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _darken(irisColor, 0.38),
          irisColor,
          _lighten(irisColor, 0.40),
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(irisRect);
      canvas.drawOval(irisRect, Paint()..shader = irisShader);

      // 4. 虹膜放射状微晶体肌理线条 (Radial Iris Striations - 真实宝石与猫眼晶状体光泽)
      final striationLight = Paint()
        ..color = _lighten(irisColor, 0.50).withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85
        ..strokeCap = StrokeCap.round;
      final striationDark = Paint()
        ..color = _darken(irisColor, 0.45).withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 8; i++) {
        final a = i * (math.pi / 4.0) + 0.18;
        final cosA = math.cos(a);
        final sinA = math.sin(a);
        final p1 = Offset(irisCenter.dx + cosA * 4.0, irisCenter.dy + sinA * 5.0);
        final p2 = Offset(irisCenter.dx + cosA * 7.6, irisCenter.dy + sinA * 9.5);
        canvas.drawLine(p1, p2, (i % 2 == 0) ? striationLight : striationDark);
      }

      // 5. 下缘焦散透光弧 (Bottom Caustic Crescent Glow - 琉璃通透感)
      final causticPaint = Paint()
        ..color = _lighten(irisColor, 0.75).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      final causticPath = Path()
        ..moveTo(irisCenter.dx - 4.5, irisCenter.dy + 6.0)
        ..quadraticBezierTo(irisCenter.dx, irisCenter.dy + 8.4, irisCenter.dx + 4.5, irisCenter.dy + 6.0);
      canvas.drawPath(causticPath, causticPaint);

      // 6. 瞳孔绘制
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

      // 7. 上眼睑投射到眼球的深邃环境阴影 (Upper Eyelid Ambient Shadow)
      final eyelidShadowShader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0x55000000),
          Color(0x00000000),
        ],
        stops: [0.0, 1.0],
      ).createShader(Rect.fromLTWH(eyeCenter.dx - 11, eyeCenter.dy - 13, 22, 10));
      canvas.drawOval(Rect.fromLTWH(eyeCenter.dx - 11, eyeCenter.dy - 13, 22, 10), Paint()..shader = eyelidShadowShader);

      // 8. 下眼睑湿润水光反射弧 (Lower Eyelid Wet Tear Film Meniscus)
      final tearFilmPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.95
        ..strokeCap = StrokeCap.round;
      final tearFilmPath = Path()
        ..moveTo(eyeCenter.dx - 8.5, eyeCenter.dy + 11.2)
        ..quadraticBezierTo(eyeCenter.dx, eyeCenter.dy + 13.0, eyeCenter.dx + 8.5, eyeCenter.dy + 11.2);
      canvas.drawPath(tearFilmPath, tearFilmPaint);
    }

    // 9. 眉上灵动感知触须 (Superciliary Vibrissae - 猫咪逼真灵魂微触须)
    final browWhiskerColor = (skin.id == 'cat_black' || skin.id == 'cat_tuxedo') ? const Color(0xC0F1F5F9) : const Color(0x6064748B);
    final browWhiskerPaint = Paint()
      ..color = browWhiskerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;

    // 左眉上触须 (2 根上扬外卷微触须)
    final leftBrow1 = Path()
      ..moveTo(leftEyeCenter.dx - 2, leftEyeCenter.dy - 14)
      ..quadraticBezierTo(leftEyeCenter.dx - 8, leftEyeCenter.dy - 23, leftEyeCenter.dx - 16, leftEyeCenter.dy - 28);
    final leftBrow2 = Path()
      ..moveTo(leftEyeCenter.dx + 2, leftEyeCenter.dy - 15)
      ..quadraticBezierTo(leftEyeCenter.dx - 1, leftEyeCenter.dy - 26, leftEyeCenter.dx - 8, leftEyeCenter.dy - 33);
    canvas.drawPath(leftBrow1, browWhiskerPaint);
    canvas.drawPath(leftBrow2, browWhiskerPaint);

    // 右眉上触须 (2 根对称上扬外卷微触须)
    final rightBrow1 = Path()
      ..moveTo(rightEyeCenter.dx + 2, rightEyeCenter.dy - 14)
      ..quadraticBezierTo(rightEyeCenter.dx + 8, rightEyeCenter.dy - 23, rightEyeCenter.dx + 16, rightEyeCenter.dy - 28);
    final rightBrow2 = Path()
      ..moveTo(rightEyeCenter.dx - 2, rightEyeCenter.dy - 15)
      ..quadraticBezierTo(rightEyeCenter.dx + 1, rightEyeCenter.dy - 26, rightEyeCenter.dx + 8, rightEyeCenter.dy - 33);
    canvas.drawPath(rightBrow1, browWhiskerPaint);
    canvas.drawPath(rightBrow2, browWhiskerPaint);
  }

  void _drawNoseAndMouth(Canvas canvas, Offset headCenter) {
    final noseCenter = Offset(headCenter.dx, headCenter.dy + 11);

    // 1. 鼓鼓饱满的双侧胡须肉垫 (Puffy Muzzle Whisker Pads / 包子嘴)
    final padHighlight = Colors.white.withValues(alpha: 0.18);
    const padShadow = Color(0x16000000);

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
    final noseGlintPaint = Paint()..color = Colors.white.withValues(alpha: 0.85);
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

    if (state == 'HAPPY_SPIN') {
      // 🐱 追尾巴：兴奋开心地张开小圆嘴，吐出粉嫩小舌头快速喘气
      final happyMouth = Paint()..color = const Color(0xFF451A03);
      canvas.drawOval(Rect.fromCenter(center: Offset(noseCenter.dx, noseCenter.dy + 7), width: 9, height: 7.5), happyMouth);
      final tongue = Paint()..color = const Color(0xFFFB7185);
      canvas.drawOval(Rect.fromCenter(center: Offset(noseCenter.dx + 0.4, noseCenter.dy + 8.5), width: 6.5, height: 5.0), tongue);
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
        ..color = const Color(0xFFF43F5E).withValues(alpha: 0.6)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(noseCenter.dx, noseCenter.dy + 6.0), Offset(noseCenter.dx, noseCenter.dy + 10.2), groovePaint);
    }
  }

  void _drawWhiskers(Canvas canvas, SkinConfig skin, Offset headCenter) {
    final whiskerColor = (skin.id == 'cat_black' || skin.id == 'cat_tuxedo') ? const Color(0xFFF1F5F9) : const Color(0x7594A3B8);
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

    final toeHighlightPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
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
      ..color = _darken(pawColor, 0.32).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final cleft1X = (toeDx1 + toeDx2) / 2;
    final cleft2X = (toeDx2 + toeDx3) / 2;
    canvas.drawLine(Offset(cleft1X, toeY - toeRadius * 0.75), Offset(cleft1X, toeY + toeRadius * 0.85), creasePaint);
    canvas.drawLine(Offset(cleft2X, toeY - toeRadius * 0.75), Offset(cleft2X, toeY + toeRadius * 0.85), creasePaint);

    // 4. 爪边缘自然毛色同色系柔和轮廓
    final borderPaint = Paint()
      ..color = _darken(pawColor, 0.28).withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawOval(baseRect, borderPaint);

    // 4.5 爪尖微隐晶莹半透明白爪刃 (Retracted Claw Sheaths - 生动逼真微细节)
    final clawPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.round;
    for (final tdx in [toeDx1, toeDx2, toeDx3]) {
      canvas.drawLine(
        Offset(tdx, toeY + toeRadius * 0.42),
        Offset(tdx, toeY + toeRadius * 0.86),
        clawPaint,
      );
    }

    // 5. 黑猫/警长踏雪寻梅：纯白小手套雪花爪尖
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
          Paint()..color = Colors.white.withValues(alpha: 0.55),
        );

        // 四个可爱小脚趾肉球 (Toe Beans)
        final beanPaint = Paint()..color = const Color(0xFFFB7185);
        final beanGlint = Paint()..color = Colors.white.withValues(alpha: 0.65);
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
      final padPaint = Paint()..color = const Color(0xFFFB7185).withValues(alpha: 0.9);
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
    final hasWhiteSock = (skin.id == 'cat_black' || skin.id == 'cat_tuxedo' || skin.id == 'cat_ragdoll' || skin.id == 'cat_golden_shaded' || skin.id == 'cat_silver_shaded');
    final double pawW;
    final double pawH;
    if (skin.id == 'cat_orange' || skin.id == 'cat_maine_coon') {
      pawW = 26.0;
      pawH = 18.0;
    } else if (skin.id == 'cat_british_blue' || skin.id == 'cat_golden_shaded' || skin.id == 'cat_silver_shaded') {
      pawW = 24.0;
      pawH = 17.0;
    } else if (skin.id == 'cat_siamese') {
      pawW = 19.0;
      pawH = 14.0;
    } else {
      pawW = 22.0;
      pawH = 16.0;
    }

    if (state == 'HAPPY_SPIN') {
      // 🐱 追尾巴：双前爪交替向前猛扑拨抓尾尖，小爪爪急促踩地狂奔！
      final swatCycle = animTime * 18.0;
      final swat1 = math.sin(swatCycle) * 6.5;
      final swat2 = math.cos(swatCycle) * 6.5;
      _drawPlumpSegmentedPaw(
        canvas,
        Offset(-20 + swat1 * 0.5, 52 + swat1),
        pawW,
        pawH,
        Color(skin.primaryColor),
        hasWhiteSock: hasWhiteSock,
      );
      _drawPlumpSegmentedPaw(
        canvas,
        Offset(20 - swat2 * 0.5, 52 + swat2),
        pawW,
        pawH,
        Color(skin.primaryColor),
        hasWhiteSock: hasWhiteSock,
      );
      return;
    }

    if (state == 'HIGH_FIVE') {
      // 左前爪着地 (分瓣立体萌爪)
      _drawPlumpSegmentedPaw(canvas, const Offset(-22, 60), pawW, pawH, Color(skin.primaryColor), hasWhiteSock: hasWhiteSock);

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
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );

      // 4 颗圆润粉嫩小肉球 (Toe Beans)
      final beanPaint = Paint()..color = const Color(0xFFFB7185);
      final beanGlint = Paint()..color = Colors.white.withValues(alpha: 0.65);
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

    // 玩毛线球：两只圆润山竹肉爪真实交替拍打拨弄 (Alternating Swat & Bat)
    if (state == 'PLAY_YARN') {
      final playCycle = animTime * 7.0;

      // 左爪与右爪交替抬起下拍 (反相拍击)
      final leftSlap = math.sin(playCycle).clamp(0.0, 1.0) * 12.0;
      final rightSlap = (-math.sin(playCycle)).clamp(0.0, 1.0) * 12.0;
      final leftNudgeX = math.cos(playCycle) * 4.0;
      final rightNudgeX = -math.cos(playCycle) * 4.0;

      // 左爪
      canvas.save();
      final leftPawPos = Offset(-18.0 + leftNudgeX, 54.0 - leftSlap);
      canvas.translate(leftPawPos.dx, leftPawPos.dy);
      canvas.rotate(0.12 - leftSlap * 0.015);
      _drawPlumpSegmentedPaw(
        canvas,
        Offset.zero,
        pawW,
        pawH,
        Color(skin.primaryColor),
        hasWhiteSock: hasWhiteSock,
      );
      canvas.restore();

      // 右爪
      canvas.save();
      final rightPawPos = Offset(18.0 + rightNudgeX, 54.0 - rightSlap);
      canvas.translate(rightPawPos.dx, rightPawPos.dy);
      canvas.rotate(-0.12 + rightSlap * 0.015);
      _drawPlumpSegmentedPaw(
        canvas,
        Offset.zero,
        pawW,
        pawH,
        Color(skin.primaryColor),
        hasWhiteSock: hasWhiteSock,
      );
      canvas.restore();
      return;
    }

    // 漫步小碎步踱步：双前爪交替抬落起伏 (分瓣萌态小肉爪)
    if (state == 'WALK') {
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
        hasWhiteSock: hasWhiteSock,
      );
      _drawPlumpSegmentedPaw(
        canvas,
        Offset(22 + rightShift, 60 - rightLift),
        pawW,
        pawH,
        Color(skin.primaryColor),
        hasWhiteSock: hasWhiteSock,
      );
      return;
    }

    // 普通静止前爪：不同品种爪爪肥瘦差异 (大橘厚爪 vs 暹罗细爪 vs 踏雪白手套)
    // 升级为肉嘟嘟 3 瓣分瓣山竹小爪 (立体缎面光泽 + 趾缝微阴影)
    _drawPlumpSegmentedPaw(
      canvas,
      const Offset(-22, 60),
      pawW,
      pawH,
      Color(skin.primaryColor),
      hasWhiteSock: hasWhiteSock,
    );
    _drawPlumpSegmentedPaw(
      canvas,
      const Offset(22, 60),
      pawW,
      pawH,
      Color(skin.primaryColor),
      hasWhiteSock: hasWhiteSock,
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
      // 🦸‍♂️ 皇家丝绒披风前饰 (正面视角：纯金领扣、肩部丝绒搭扣与星辉宝扣；背面视角：披风主体覆盖后背展示金纹刺绣)
      if (isBackView) {
        // 背面视角：披风覆盖后背，展示威武金纹与丝绒褶皱
        final capePaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A044E), Color(0xFF581C87), Color(0xFF7E22CE)],
          ).createShader(const Rect.fromLTRB(-42, 16, 42, 74));
        final goldTrim = Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6;

        final capePath = Path()
          ..moveTo(-24, 16)
          ..quadraticBezierTo(-44, 42, -34, 70)
          ..quadraticBezierTo(0, 76, 34, 70)
          ..quadraticBezierTo(44, 42, 24, 16)
          ..close();
        canvas.drawPath(capePath, capePaint);
        canvas.drawPath(capePath, goldTrim);

        // 背部皇家金徽刺绣 (Royal Crest Sunburst)
        final emblemPaint = Paint()
          ..color = const Color(0xFFFBBF24)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(const Offset(0, 42), 8.5, emblemPaint);
        canvas.drawCircle(const Offset(0, 42), 4.5, Paint()..color = const Color(0xFFFDE047));
        for (int i = 0; i < 8; i++) {
          final rad = i * math.pi / 4;
          canvas.drawLine(
            Offset(9.5 * math.cos(rad), 42 + 9.5 * math.sin(rad)),
            Offset(14.0 * math.cos(rad), 42 + 14.0 * math.sin(rad)),
            emblemPaint,
          );
        }
      } else {
        // 正面视角：精致纯金领链与星辉红宝石胸扣，披风主体在身后飘逸
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

    // --- 背部配饰的前胸构件 (皮质双肩背带/赛博肩甲) 与背身视角覆盖 (3D 浮雕龟壳/赛博披风后背) ---
    final backDeco = model.decorations['back'];
    if (backDeco == 'shell_turtle') {
      if (isBackView) {
        // 🐢 背面视角：完整 3D 浮雕六边形翡翠乌龟壳背包
        const shellCenter = Offset(0, 38);
        const shellW = 98.0;
        const shellH = 80.0;

        // 1. 软萌龟爪与小尾巴 (Tiny cute flippers & tail)
        final limbPaint = Paint()..color = const Color(0xFF22C55E);
        // 小尾巴
        final tailPath = Path()
          ..moveTo(-4, 76)
          ..quadraticBezierTo(0, 84, 0, 85)
          ..quadraticBezierTo(0, 84, 4, 76)
          ..close();
        canvas.drawPath(tailPath, limbPaint);
        canvas.drawPath(tailPath, Paint()
          ..color = const Color(0xFF166534)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

        // 四个小龟爪 (从龟壳下伸出)
        canvas.drawCircle(const Offset(-42, 24), 6.0, limbPaint);
        canvas.drawCircle(const Offset(42, 24), 6.0, limbPaint);
        canvas.drawCircle(const Offset(-38, 62), 6.0, limbPaint);
        canvas.drawCircle(const Offset(38, 62), 6.0, limbPaint);

        // 2. 龟壳底层阴影
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, 41), width: shellW + 2, height: shellH + 2),
          Paint()..color = const Color(0x44000000),
        );

        // 3. 3D 金绿波浪卷边 (Scalloped Bevel Rim)
        final rimPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFEF08A), Color(0xFF84CC16), Color(0xFF15803D)],
          ).createShader(Rect.fromCenter(center: shellCenter, width: shellW, height: shellH))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.2;
        canvas.drawOval(Rect.fromCenter(center: shellCenter, width: shellW, height: shellH), rimPaint);

        // 4. 翡翠球体主甲 (Emerald Spherical Dome)
        final domePaint = Paint()
          ..shader = const RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 0.85,
            colors: [Color(0xFF4ADE80), Color(0xFF22C55E), Color(0xFF15803D), Color(0xFF14532D)],
            stops: [0.0, 0.45, 0.8, 1.0],
          ).createShader(Rect.fromCenter(center: shellCenter, width: shellW, height: shellH));
        canvas.drawOval(Rect.fromCenter(center: shellCenter, width: shellW, height: shellH), domePaint);

        // 5. 立体浮雕六边形背甲蜂窝花纹 (Hexagonal Embossed Scutes)
        void drawHexScute(Offset center, double radius) {
          final path = Path();
          for (int i = 0; i < 6; i++) {
            final angle = (i * 60 + 30) * math.pi / 180;
            final pt = Offset(center.dx + radius * math.cos(angle), center.dy + radius * math.sin(angle));
            if (i == 0) {
              path.moveTo(pt.dx, pt.dy);
            } else {
              path.lineTo(pt.dx, pt.dy);
            }
          }
          path.close();

          canvas.drawPath(path, Paint()..color = const Color(0xFF16A34A).withValues(alpha: 0.65));
          canvas.drawPath(path, Paint()
            ..color = const Color(0xFF14532D)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2);
          canvas.drawPath(path, Paint()
            ..color = const Color(0xFF86EFAC).withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0);
        }

        drawHexScute(const Offset(0, 22), 10.0);
        drawHexScute(const Offset(0, 38), 11.5);
        drawHexScute(const Offset(0, 54), 10.0);
        drawHexScute(const Offset(-24, 29), 9.0);
        drawHexScute(const Offset(24, 29), 9.0);
        drawHexScute(const Offset(-24, 47), 9.0);
        drawHexScute(const Offset(24, 47), 9.0);

        // 6. 3D 球形玻璃高光
        final shinePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.28)
          ..style = PaintingStyle.fill;
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(-16, 24), width: 22, height: 12),
          shinePaint,
        );
      } else {
        // 🐢 正面视角：精致焦糖皮革双肩背带 + 黄铜日字调节扣 + 胸口小乌龟萌趣徽章
        final strapPaint = Paint()
          ..color = const Color(0xFFB45309)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..strokeCap = StrokeCap.round;
        final strapStitch = Paint()
          ..color = const Color(0xFFFDE68A).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round;

        // 左肩背带
        final leftStrap = Path()
          ..moveTo(-22, 12)
          ..quadraticBezierTo(-24, 28, -17, 48);
        canvas.drawPath(leftStrap, strapPaint);
        canvas.drawPath(leftStrap, strapStitch);

        // 右肩背带
        final rightStrap = Path()
          ..moveTo(22, 12)
          ..quadraticBezierTo(24, 28, 17, 48);
        canvas.drawPath(rightStrap, strapPaint);
        canvas.drawPath(rightStrap, strapStitch);

        // 胸前防滑横置固定胸带
        final chestStrap = Path()
          ..moveTo(-20, 30)
          ..quadraticBezierTo(0, 33, 20, 30);
        canvas.drawPath(chestStrap, Paint()
          ..color = const Color(0xFF92400E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round);

        // 双肩黄铜日字调节扣
        final brassBuckle = Paint()..color = const Color(0xFFFBBF24);
        final brassHole = Paint()..color = const Color(0xFF78350F);
        for (final bx in [-21.0, 21.0]) {
          final bRect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(bx, 22), width: 7.0, height: 5.5),
            const Radius.circular(1.5),
          );
          canvas.drawRRect(bRect, brassBuckle);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(bx, 22), width: 3.2, height: 2.2),
              const Radius.circular(0.8),
            ),
            brassHole,
          );
        }

        // 胸口中央可爱小乌龟徽章
        canvas.drawCircle(const Offset(0, 32), 6.5, Paint()..color = const Color(0xFFFBBF24));
        canvas.drawCircle(const Offset(0, 32), 5.0, Paint()..color = const Color(0xFF16A34A));
        canvas.drawCircle(const Offset(-1.5, 30.5), 1.2, Paint()..color = Colors.white.withValues(alpha: 0.8));
      }
    } else if (backDeco == 'cape_cyber') {
      if (isBackView) {
        // 🦸‍♂️ 赛博披风背身视角：覆盖后背的战术纳米护甲斗篷与能量脊椎
        final backMantle = Path()
          ..moveTo(-24, 18)
          ..lineTo(-36, 42)
          ..lineTo(-26, 68)
          ..lineTo(0, 74)
          ..lineTo(26, 68)
          ..lineTo(36, 42)
          ..lineTo(24, 18)
          ..close();
        canvas.drawPath(backMantle, Paint()..color = const Color(0xFF0F172A));
        canvas.drawPath(backMantle, Paint()
          ..color = const Color(0xFF00F0FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

        // 赛博脊椎能量光轨 (Cyber Spine Vertebrae)
        final spinePaint = Paint()
          ..color = const Color(0xFF00F0FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round;
        for (int y = 28; y <= 58; y += 8) {
          canvas.drawLine(Offset(-6, y.toDouble()), Offset(6, y.toDouble()), spinePaint);
        }
        canvas.drawLine(const Offset(0, 24), const Offset(0, 64), Paint()
          ..color = const Color(0xFFEC4899)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
      } else {
        // 🦸‍♂️ 赛博披风正面视角：两肩碳纤维高科技肩甲 + 青蓝能量灯 + 领口全息能量核心反应堆
        canvas.drawPath(
          Path()..moveTo(-24, 20)..quadraticBezierTo(0, 26, 24, 20),
          Paint()
            ..color = const Color(0xFF1E293B)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.6
            ..strokeCap = StrokeCap.round,
        );

        // 左肩战术碳纤肩甲
        final leftShoulder = Path()
          ..moveTo(-26, 14)
          ..lineTo(-18, 17)
          ..lineTo(-20, 26)
          ..lineTo(-29, 23)
          ..close();
        canvas.drawPath(leftShoulder, Paint()..color = const Color(0xFF0F172A));
        canvas.drawPath(leftShoulder, Paint()
          ..color = const Color(0xFF38BDF8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        canvas.drawCircle(const Offset(-23, 20), 1.8, Paint()..color = const Color(0xFF00F0FF));

        // 右肩战术碳纤肩甲
        final rightShoulder = Path()
          ..moveTo(26, 14)
          ..lineTo(18, 17)
          ..lineTo(20, 26)
          ..lineTo(29, 23)
          ..close();
        canvas.drawPath(rightShoulder, Paint()..color = const Color(0xFF0F172A));
        canvas.drawPath(rightShoulder, Paint()
          ..color = const Color(0xFF38BDF8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        canvas.drawCircle(const Offset(23, 20), 1.8, Paint()..color = const Color(0xFF00F0FF));

        // 领口中央全息能量反应堆 (Cyan Arc Core)
        final coreGlow = Paint()
          ..color = const Color(0x6600F0FF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawCircle(const Offset(0, 23), 5.5, coreGlow);
        canvas.drawCircle(const Offset(0, 23), 4.2, Paint()..color = const Color(0xFF00F0FF));
        canvas.drawCircle(const Offset(0, 23), 2.0, Paint()..color = Colors.white);
      }
    }
  }

  /// 绘制背部配饰 (挂在后背向两侧舒展，正面时在身体后层，绝不遮挡胸腹与猫爪)
  void _drawBackDecorations(Canvas canvas, {bool isBackView = false}) {
    final neckDeco = model.decorations['neck'];
    final backDeco = model.decorations['back'];

    // 1. 皇家丝绒披风后摆 (宽体大摆 132dp，双层丝绒暗褶与纯金麦穗流苏)
    if (neckDeco == 'royal_cape' && !isBackView) {
      final t = animTime;
      final waveL = math.sin(t * 3.2) * 4.5;
      final waveR = math.cos(t * 3.2 + 0.6) * 4.5;
      final waveMid = math.sin(t * 2.2) * 2.8;

      final leftX = -64.0 + waveL;
      final rightX = 64.0 + waveR;
      final bottomY = 76.0 + waveMid;

      // 内层丝绒深暗阴影褶皱 (Ambient Shadow Fold)
      final innerVelvetPath = Path()
        ..moveTo(-20, 20)
        ..cubicTo(-46 + waveL * 0.6, 42, -54 + waveL * 0.8, 58, leftX + 5, bottomY - 3)
        ..quadraticBezierTo(0, bottomY + 5, rightX - 5, bottomY - 3)
        ..cubicTo(54 + waveR * 0.8, 58, 46 + waveR * 0.6, 42, 20, 20)
        ..close();
      canvas.drawPath(innerVelvetPath, Paint()..color = const Color(0xFF2E0854));

      // 外层勃艮第与皇家紫丝绒渐变 (Imperial Velvet Gradient)
      final capePath = Path()
        ..moveTo(-22, 18)
        ..cubicTo(-48 + waveL * 0.7, 40, -58 + waveL * 0.9, 56, leftX, bottomY)
        ..quadraticBezierTo(0, bottomY + 6, rightX, bottomY)
        ..cubicTo(58 + waveR * 0.9, 56, 48 + waveR * 0.7, 40, 22, 18)
        ..close();

      final velvetGradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4A044E), Color(0xFF581C87), Color(0xFF7E22CE)],
      ).createShader(const Rect.fromLTRB(-66, 18, 66, 84));
      canvas.drawPath(capePath, Paint()..shader = velvetGradient);

      // 纯金双层麦穗流苏滚边 (Gold Bullion Fringe & Trim)
      final goldTrim = Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(capePath, goldTrim);

      // 底边华丽金珠麦穗流苏点缀
      final goldBead = Paint()..color = const Color(0xFFFEF08A);
      for (double step = 0.15; step <= 0.85; step += 0.14) {
        final bx = leftX + (rightX - leftX) * step;
        final by = bottomY + math.sin(step * math.pi) * 6.0;
        canvas.drawCircle(Offset(bx, by), 2.0, goldBead);
        canvas.drawLine(Offset(bx, by), Offset(bx, by + 4), Paint()
          ..color = const Color(0xFFF59E0B)
          ..strokeWidth = 1.4);
      }
    }

    if (backDeco == null || backDeco == 'none') return;

    if (backDeco == 'cape_cyber') {
      // 🦸‍♂️ 赛博霓虹披风 (Cyberpunk Neon Cape)
      // 真实布料多频谐波风浪物理仿真 (Primary wave + High-frequency flutter)
      final t = animTime;
      final waveL = math.sin(t * 3.6) * 5.0 + math.cos(t * 5.2 + 0.4) * 2.5;
      final waveR = math.cos(t * 3.6 + 0.9) * 5.0 + math.sin(t * 5.2 + 1.2) * 2.5;
      final waveMid = math.sin(t * 2.6) * 3.0;

      // 宽体大摆外扩：翼展大幅扩展至 134dp (从 -67 到 +67)，两翼自如外扩翻飞，气势威武
      final leftWingX = -67.0 + waveL;
      final rightWingX = 67.0 + waveR;
      final leftWingY = 74.0 + waveL * 0.4;
      final rightWingY = 74.0 + waveR * 0.4;
      final midTailY = 84.0 + waveMid;

      // --- 第 1 层：环境遮蔽与内衬暗褶 (Deep Ambient Shadow & Inner Cloth Fold) ---
      final innerShadowPath = Path()
        ..moveTo(-20, 18)
        ..cubicTo(-46 + waveL * 0.6, 38, -58 + waveL * 0.8, 56, leftWingX + 6, leftWingY)
        ..lineTo(-28 + waveL * 0.3, 72 + waveMid * 0.5)
        ..lineTo(0, midTailY - 3)
        ..lineTo(28 + waveR * 0.3, 72 + waveMid * 0.5)
        ..lineTo(rightWingX - 6, rightWingY)
        ..cubicTo(58 + waveR * 0.8, 56, 46 + waveR * 0.6, 38, 20, 18)
        ..close();
      canvas.drawPath(innerShadowPath, Paint()..color = const Color(0xFF080C16));

      // --- 第 2 层：外层披风主体 (战术午夜深紫渐变，立体布料质感) ---
      final outerCapePath = Path()
        ..moveTo(-22, 16)
        ..cubicTo(-48 + waveL * 0.7, 36, -62 + waveL * 0.9, 54, leftWingX, leftWingY)
        // 燕尾锯齿战术多边形切割
        ..lineTo(-32 + waveL * 0.4, 73 + waveMid * 0.6)
        ..lineTo(0, midTailY)
        ..lineTo(32 + waveR * 0.4, 73 + waveMid * 0.6)
        ..lineTo(rightWingX, rightWingY)
        ..cubicTo(62 + waveR * 0.9, 54, 48 + waveR * 0.7, 36, 22, 16)
        ..close();

      final capeGradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(const Rect.fromLTRB(-70, 16, 70, 88));
      canvas.drawPath(outerCapePath, Paint()..shader = capeGradient);

      // --- 第 3 层：立体面料流线光泽折痕 (Volumetric Fabric Highlights) ---
      final creasePaint = Paint()
        ..color = const Color(0xFF6366F1).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-16, 20), Offset(-32 + waveL * 0.4, 73 + waveMid * 0.6), creasePaint);
      canvas.drawLine(const Offset(16, 20), Offset(32 + waveR * 0.4, 73 + waveMid * 0.6), creasePaint);
      canvas.drawLine(const Offset(0, 20), Offset(0, midTailY - 2), creasePaint);

      // --- 第 4 层：青蓝全息激光发光滚边 (Luminous Cyber Cyan Laser Bloom & Core) ---
      final laserGlow = Paint()
        ..color = const Color(0x6600F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawPath(outerCapePath, laserGlow);

      final laserCore = Paint()
        ..color = const Color(0xFF00F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(outerCapePath, laserCore);

      // --- 第 5 层：流动赛博回路与荧光脉冲节点 (Pulsing Cyber Circuits) ---
      final pulse = (math.sin(t * 5.0) * 0.5 + 0.5);
      final circuitMagenta = Paint()
        ..color = Color.lerp(const Color(0xFFEC4899), const Color(0xFFF43F5E), pulse)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;

      // 左翼电路流
      final leftCircuit = Path()
        ..moveTo(-26 + waveL * 0.3, 36)
        ..lineTo(-44 + waveL * 0.6, 52)
        ..lineTo(-44 + waveL * 0.6, 62)
        ..lineTo(leftWingX + 8, leftWingY - 6);
      canvas.drawPath(leftCircuit, circuitMagenta);

      // 右翼电路流
      final rightCircuit = Path()
        ..moveTo(26 + waveR * 0.3, 36)
        ..lineTo(44 + waveR * 0.6, 52)
        ..lineTo(44 + waveR * 0.6, 62)
        ..lineTo(rightWingX - 8, rightWingY - 6);
      canvas.drawPath(rightCircuit, circuitMagenta);

      // 脉冲发光能量节点
      final nodeGlow = Paint()..color = const Color(0xFF00F0FF);
      canvas.drawCircle(Offset(-44 + waveL * 0.6, 52), 2.5 + pulse * 1.2, nodeGlow);
      canvas.drawCircle(Offset(44 + waveR * 0.6, 52), 2.5 + pulse * 1.2, nodeGlow);
      canvas.drawCircle(Offset(0, midTailY - 10), 2.8 + pulse * 1.0, Paint()..color = const Color(0xFFEC4899));

    } else if (backDeco == 'wings_angel') {
      // 🪽 天使羽翼 (Radiant Angel Wings)
      final flap = math.sin(animTime * 4.0) * 0.12;
      final wingPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.92)
        ..style = PaintingStyle.fill;
      final wingBorder = Paint()
        ..color = const Color(0xFFFDE68A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;

      // 左翼
      canvas.save();
      canvas.translate(-20, 32);
      canvas.rotate(-0.35 + flap);
      final leftWing = Path()
        ..moveTo(0, 0)
        ..cubicTo(-26, -18, -48, -12, -56, 12)
        ..cubicTo(-46, 26, -24, 22, 0, 8)
        ..close();
      canvas.drawPath(leftWing, wingPaint);
      canvas.drawPath(leftWing, wingBorder);
      canvas.restore();

      // 右翼
      canvas.save();
      canvas.translate(20, 32);
      canvas.rotate(0.35 - flap);
      final rightWing = Path()
        ..moveTo(0, 0)
        ..cubicTo(26, -18, 48, -12, 56, 12)
        ..cubicTo(46, 26, 24, 22, 0, 8)
        ..close();
      canvas.drawPath(rightWing, wingPaint);
      canvas.drawPath(rightWing, wingBorder);
      canvas.restore();

    } else if (backDeco == 'shell_turtle') {
      // 🐢 萌趣龟壳背包：身后饱满隆起的翡翠小龟壳 (左右各露出 16dp，两翼圆润饱满，无论正面或侧身均极其醒目)
      if (!isBackView) {
        const shellCenter = Offset(0, 36);
        const shellW = 126.0;
        const shellH = 88.0;

        // 1. 龟壳底层环境阴影 (Soft Ambient Occlusion)
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, 40), width: shellW + 4, height: shellH + 4),
          Paint()..color = const Color(0x33000000),
        );

        // 2. 3D 立体金绿边缘裙边 (Golden Lime Bevel Rim)
        final rimPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFDE047), Color(0xFF84CC16), Color(0xFF166534)],
          ).createShader(Rect.fromCenter(center: shellCenter, width: shellW, height: shellH))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.8;
        canvas.drawOval(Rect.fromCenter(center: shellCenter, width: shellW, height: shellH), rimPaint);

        // 3. 翡翠天然龟甲球形主甲 (Emerald Dome with Volumetric Gradient)
        final domePaint = Paint()
          ..shader = const RadialGradient(
            center: Alignment(0.0, -0.2),
            radius: 0.85,
            colors: [Color(0xFF4ADE80), Color(0xFF22C55E), Color(0xFF15803D), Color(0xFF14532D)],
            stops: [0.0, 0.45, 0.8, 1.0],
          ).createShader(Rect.fromCenter(center: shellCenter, width: shellW, height: shellH));
        canvas.drawOval(Rect.fromCenter(center: shellCenter, width: shellW, height: shellH), domePaint);

        // 4. 猫咪身侧清晰可见的两侧蜂窝龟甲纹理 (Flank Hexagonal Scutes)
        final flankScuteFill = Paint()..color = const Color(0xFF86EFAC).withValues(alpha: 0.45);
        final flankScuteBorder = Paint()
          ..color = const Color(0xFF14532D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;

        // 左侧翼露出龟板 (3 块错落蜂窝鳞片)
        final leftScutes = [
          const Offset(-52, 22),
          const Offset(-56, 38),
          const Offset(-50, 54),
        ];
        for (final pos in leftScutes) {
          canvas.drawCircle(pos, 8.5, flankScuteFill);
          canvas.drawCircle(pos, 8.5, flankScuteBorder);
        }

        // 右侧翼露出龟板 (3 块错落蜂窝鳞片)
        final rightScutes = [
          const Offset(52, 22),
          const Offset(56, 38),
          const Offset(50, 54),
        ];
        for (final pos in rightScutes) {
          canvas.drawCircle(pos, 8.5, flankScuteFill);
          canvas.drawCircle(pos, 8.5, flankScuteBorder);
        }

        // 顶部小背包提手挂环 (Backpack Loop peeking over neck)
        final loopPaint = Paint()
          ..color = const Color(0xFFB45309)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round;
        final loopPath = Path()
          ..moveTo(-10, -3)
          ..quadraticBezierTo(0, -11, 10, -3);
        canvas.drawPath(loopPath, loopPaint);
      }
    }
  }

  /// 绘制头部帽子配饰
  void _drawHeadDecorations(Canvas canvas, Offset headCenter) {
    var headDeco = model.decorations['head'];
    // 觉醒特性：元气运动喵未佩戴头饰时，自动觉醒佩戴运动发带
    if ((headDeco == null || headDeco == 'none') && model.personality == 'ATHLETE') {
      headDeco = 'band_sport';
    }
    if (headDeco == null || headDeco == 'none') return;

    if (headDeco == 'band_sport') {
      // 🏃 元气运动发带 (Athletic Headband)
      final bandCenter = Offset(headCenter.dx, headCenter.dy - 26);
      final bandRect = Rect.fromCenter(center: bandCenter, width: 64, height: 13);

      // 发带主体活力橙红
      final bandPaint = Paint()..color = const Color(0xFFEF4444);
      canvas.drawRRect(RRect.fromRectAndRadius(bandRect, const Radius.circular(5)), bandPaint);

      // 上下双白运动纹
      final stripePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawLine(Offset(bandCenter.dx - 28, bandCenter.dy - 3), Offset(bandCenter.dx + 28, bandCenter.dy - 3), stripePaint);
      canvas.drawLine(Offset(bandCenter.dx - 28, bandCenter.dy + 3), Offset(bandCenter.dx + 28, bandCenter.dy + 3), stripePaint);

      // 中央金色极速闪电 ⚡
      final boltPaint = Paint()..color = const Color(0xFFFBBF24);
      final boltPath = Path()
        ..moveTo(bandCenter.dx + 1, bandCenter.dy - 5)
        ..lineTo(bandCenter.dx - 4, bandCenter.dy)
        ..lineTo(bandCenter.dx - 1, bandCenter.dy)
        ..lineTo(bandCenter.dx - 2, bandCenter.dy + 5)
        ..lineTo(bandCenter.dx + 4, bandCenter.dy - 1)
        ..lineTo(bandCenter.dx + 1, bandCenter.dy - 1)
        ..close();
      canvas.drawPath(boltPath, boltPaint);

      // 左侧发带系带随风飘扬
      final flutter = math.sin(animTime * 6.0) * 2.5;
      final knotPaint = Paint()..color = const Color(0xFFDC2626);
      canvas.drawCircle(Offset(bandCenter.dx - 29, bandCenter.dy), 3.2, knotPaint);
      final ribbonTail = Path()
        ..moveTo(bandCenter.dx - 29, bandCenter.dy)
        ..quadraticBezierTo(bandCenter.dx - 36, bandCenter.dy + 4 + flutter, bandCenter.dx - 40, bandCenter.dy + 12 + flutter)
        ..lineTo(bandCenter.dx - 36, bandCenter.dy + 12 + flutter)
        ..close();
      canvas.drawPath(ribbonTail, knotPaint);

    } else if (headDeco == 'gold_crown_sparkle') {
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

      // 尖帽身
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

      final ribbonPaint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      canvas.drawLine(Offset(baseCenter.dx - 17, baseCenter.dy - 3), Offset(baseCenter.dx + 17, baseCenter.dy - 3), ribbonPaint);
      canvas.drawCircle(Offset(baseCenter.dx + 22, baseCenter.dy - 58), 3.2, hatGold);
    } else if (headDeco == 'straw_hat') {
      // 👒 田园草帽
      final baseCenter = Offset(headCenter.dx, headCenter.dy - 44);
      final strawColor = Paint()..color = const Color(0xFFFDE047);
      final strawDark = Paint()
        ..color = const Color(0xFFCA8A04)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawOval(Rect.fromCenter(center: baseCenter, width: 62, height: 16), strawColor);
      canvas.drawOval(Rect.fromCenter(center: baseCenter, width: 62, height: 16), strawDark);

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

      final ribbon = Paint()..color = const Color(0xFFEF4444);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(baseCenter.dx, baseCenter.dy - 2), width: 36, height: 4),
          const Radius.circular(2),
        ),
        ribbon,
      );
      canvas.drawLine(Offset(baseCenter.dx + 18, baseCenter.dy), Offset(baseCenter.dx + 26, baseCenter.dy + 12), ribbon..style = PaintingStyle.stroke..strokeWidth = 2.5);
    } else if (headDeco == 'sailor_cap') {
      // ⚓ 蔚蓝水手帽
      final baseCenter = Offset(headCenter.dx, headCenter.dy - 44);
      final capPaint = Paint()..color = const Color(0xFFF8FAFC);

      final bodyPath = Path()
        ..moveTo(baseCenter.dx - 22, baseCenter.dy)
        ..lineTo(baseCenter.dx - 26, baseCenter.dy - 20)
        ..quadraticBezierTo(baseCenter.dx, baseCenter.dy - 24, baseCenter.dx + 26, baseCenter.dy - 20)
        ..lineTo(baseCenter.dx + 22, baseCenter.dy)
        ..close();
      canvas.drawPath(bodyPath, capPaint);

      final navyBand = Paint()
        ..color = const Color(0xFF1E3A8A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawLine(Offset(baseCenter.dx - 22, baseCenter.dy), Offset(baseCenter.dx + 22, baseCenter.dy), navyBand);

      final goldBadge = Paint()..color = const Color(0xFFEAB308);
      canvas.drawCircle(Offset(baseCenter.dx, baseCenter.dy - 12), 3.0, goldBadge);
    }
  }

  /// 绘制面部配饰 (黑框眼镜、酷炫墨镜、战术全息目镜)
  void _drawFaceDecorations(Canvas canvas, Offset faceCenter) {
    var faceDeco = model.decorations['face'];
    // 觉醒特性：极客黑客喵未佩戴面饰时，自动觉醒战术全息目镜
    if ((faceDeco == null || faceDeco == 'none') && model.personality == 'HACKER') {
      faceDeco = 'hacker_viser';
    }
    if (faceDeco == null || faceDeco == 'none') return;

    if (faceDeco == 'glasses_black') {
      // 🤓 经典黑框智能平光镜
      final framePaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4;
      final bridgePaint = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final leftFrame = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(faceCenter.dx - 22, faceCenter.dy - 2), width: 24, height: 18),
        const Radius.circular(5),
      );
      final rightFrame = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(faceCenter.dx + 22, faceCenter.dy - 2), width: 24, height: 18),
        const Radius.circular(5),
      );
      canvas.drawRRect(leftFrame, framePaint);
      canvas.drawRRect(rightFrame, framePaint);

      canvas.drawLine(Offset(faceCenter.dx - 10, faceCenter.dy - 2), Offset(faceCenter.dx + 10, faceCenter.dy - 2), bridgePaint);
      canvas.drawLine(Offset(faceCenter.dx - 34, faceCenter.dy - 2), Offset(faceCenter.dx - 42, faceCenter.dy - 4), bridgePaint);
      canvas.drawLine(Offset(faceCenter.dx + 34, faceCenter.dy - 2), Offset(faceCenter.dx + 42, faceCenter.dy - 4), bridgePaint);

      final glintPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(faceCenter.dx - 28, faceCenter.dy - 8), Offset(faceCenter.dx - 24, faceCenter.dy - 4), glintPaint);
      canvas.drawLine(Offset(faceCenter.dx + 16, faceCenter.dy - 8), Offset(faceCenter.dx + 20, faceCenter.dy - 4), glintPaint);

    } else if (faceDeco == 'sunglasses_cool') {
      // 😎 炫酷飞行员墨镜
      final shadePaint = Paint()
        ..color = const Color(0xEE0F172A)
        ..style = PaintingStyle.fill;
      final goldRim = Paint()
        ..color = const Color(0xFFFBBF24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final leftLens = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(faceCenter.dx - 22, faceCenter.dy - 2), width: 26, height: 20),
        const Radius.circular(7),
      );
      final rightLens = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(faceCenter.dx + 22, faceCenter.dy - 2), width: 26, height: 20),
        const Radius.circular(7),
      );

      canvas.drawRRect(leftLens, shadePaint);
      canvas.drawRRect(leftLens, goldRim);
      canvas.drawRRect(rightLens, shadePaint);
      canvas.drawRRect(rightLens, goldRim);

      canvas.drawLine(Offset(faceCenter.dx - 18, faceCenter.dy - 10), Offset(faceCenter.dx + 18, faceCenter.dy - 10), goldRim);
      canvas.drawLine(Offset(faceCenter.dx - 9, faceCenter.dy - 2), Offset(faceCenter.dx + 9, faceCenter.dy - 2), goldRim);

      final sheenPaint = Paint()
        ..color = const Color(0x6638BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawLine(Offset(faceCenter.dx - 30, faceCenter.dy + 4), Offset(faceCenter.dx - 16, faceCenter.dy - 8), sheenPaint);
      canvas.drawLine(Offset(faceCenter.dx + 14, faceCenter.dy + 4), Offset(faceCenter.dx + 28, faceCenter.dy - 8), sheenPaint);

    } else if (faceDeco == 'hacker_viser') {
      // 🕶️ 赛博黑客全息战术目镜 (HUD Visor)
      final visorRect = Rect.fromCenter(center: Offset(faceCenter.dx, faceCenter.dy - 2), width: 78, height: 22);
      final visorRRect = RRect.fromRectAndRadius(visorRect, const Radius.circular(6));

      final visorBg = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xDD0EA5E9), Color(0xAA0284C7), Color(0xDD06B6D4)],
        ).createShader(visorRect);
      canvas.drawRRect(visorRRect, visorBg);

      final visorBorder = Paint()
        ..color = const Color(0xFF00F0FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(visorRRect, visorBorder);

      final scanY = visorRect.top + ((animTime * 28.0) % visorRect.height);
      final scanPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(visorRect.left + 4, scanY), Offset(visorRect.right - 4, scanY), scanPaint);

      final hudPaint = Paint()
        ..color = const Color(0xFF22C55E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      final targetCenter = Offset(faceCenter.dx + 22, faceCenter.dy - 2);
      canvas.drawCircle(targetCenter, 4.0, hudPaint);
      canvas.drawLine(Offset(targetCenter.dx - 6, targetCenter.dy), Offset(targetCenter.dx + 6, targetCenter.dy), hudPaint);
      canvas.drawCircle(Offset(visorRect.left + 5, faceCenter.dy - 2), 2.0, Paint()..color = const Color(0xFF22C55E));
      canvas.drawRect(Rect.fromLTWH(visorRect.right - 4, visorRect.top + 5, 5, 12), Paint()..color = const Color(0xFF0F172A));
    }
  }

  /// 绘制前爪手持道具
  void _drawHandDecorations(Canvas canvas) {
    final handDeco = model.decorations['hand'];
    if (handDeco == null || handDeco == 'none') return;

    if (handDeco == 'keyboard_rgb') {
      // ⌨️ 极客 RGB 机械键盘 (捧在胸前，轻微敲击微颤)
      final typeBounce = math.sin(animTime * 14.0) * 1.0;
      final kbCenter = Offset(0, 52 + typeBounce);
      final kbRect = Rect.fromCenter(center: kbCenter, width: 56, height: 22);

      final casePaint = Paint()..color = const Color(0xFF1E293B);
      final caseBorder = Paint()
        ..color = const Color(0xFF475569)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(RRect.fromRectAndRadius(kbRect, const Radius.circular(4)), casePaint);
      canvas.drawRRect(RRect.fromRectAndRadius(kbRect, const Radius.circular(4)), caseBorder);

      final colors = [
        const Color(0xFFEF4444),
        const Color(0xFFF59E0B),
        const Color(0xFF10B981),
        const Color(0xFF06B6D4),
        const Color(0xFF3B82F6),
        const Color(0xFF8B5CF6),
      ];
      const colW = 7.0;
      for (int row = 0; row < 2; row++) {
        for (int col = 0; col < 6; col++) {
          final colorIdx = (col + row + (animTime * 4.0).toInt()) % colors.length;
          final keyPaint = Paint()..color = colors[colorIdx];
          final kx = kbCenter.dx - 20 + col * colW;
          final ky = kbCenter.dy - 6 + row * 8.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(kx, ky, 5.5, 6), const Radius.circular(1.5)),
            keyPaint,
          );
        }
      }
    } else if (handDeco == 'teaser_laser') {
      // 🪄 全息逗猫棒
      final stickAngle = -0.65 + math.sin(animTime * 4.0) * 0.15;
      const stickStart = Offset(18, 48);
      final stickEnd = Offset(
        stickStart.dx + math.cos(stickAngle) * 44,
        stickStart.dy + math.sin(stickAngle) * 44,
      );

      final stickPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(stickStart, stickEnd, stickPaint);

      final sparkPaint = Paint()..color = const Color(0xFFEC4899);
      canvas.drawCircle(stickEnd, 5.0, sparkPaint);
      canvas.drawCircle(stickEnd, 2.5, Paint()..color = Colors.white);
      for (int i = 0; i < 3; i++) {
        final a = animTime * 5.0 + i * 2.1;
        canvas.drawCircle(
          Offset(stickEnd.dx + math.cos(a) * 8.0, stickEnd.dy + math.sin(a) * 8.0),
          1.8,
          Paint()..color = const Color(0xFFF472B6).withValues(alpha: 0.8),
        );
      }
    } else if (handDeco == 'coffee_cyber') {
      // ☕ 极客黑客冷萃杯
      const mugCenter = Offset(-18, 50);
      final mugRect = Rect.fromCenter(center: mugCenter, width: 18, height: 24);
      canvas.drawRRect(RRect.fromRectAndRadius(mugRect, const Radius.circular(3)), Paint()..color = const Color(0xFF0F172A));
      canvas.drawRect(Rect.fromLTWH(mugRect.left, mugCenter.dy - 3, mugRect.width, 7), Paint()..color = const Color(0xFF0EA5E9));
      canvas.drawLine(Offset(mugRect.left, mugRect.top), Offset(mugRect.right, mugRect.top), Paint()..color = const Color(0xFF64748B)..strokeWidth = 2);
      final steamY = math.sin(animTime * 3.5) * 3.0;
      canvas.drawCircle(Offset(mugCenter.dx - 2, mugRect.top - 6 + steamY), 1.8, Paint()..color = const Color(0x8838BDF8));
      canvas.drawCircle(Offset(mugCenter.dx + 3, mugRect.top - 11 + steamY), 2.2, Paint()..color = const Color(0x6638BDF8));
    } else if (handDeco == 'gamepad_retro') {
      // 🕹️ 8-bit 复古像素掌机
      const padCenter = Offset(0, 52);
      final padRect = Rect.fromCenter(center: padCenter, width: 38, height: 26);
      canvas.drawRRect(RRect.fromRectAndRadius(padRect, const Radius.circular(5)), Paint()..color = const Color(0xFFE2E8F0));
      canvas.drawRRect(RRect.fromRectAndRadius(padRect, const Radius.circular(5)), Paint()..color = const Color(0xFF94A3B8)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      final screenRect = Rect.fromCenter(center: Offset(padCenter.dx, padCenter.dy - 3), width: 22, height: 13);
      canvas.drawRect(screenRect, Paint()..color = const Color(0xFF86EFAC));
      canvas.drawRect(Rect.fromLTWH(screenRect.left + 5, screenRect.top + 4, 3, 3), Paint()..color = const Color(0xFF15803D));
      canvas.drawCircle(Offset(padCenter.dx - 10, padCenter.dy + 6), 2.5, Paint()..color = const Color(0xFF334155));
      canvas.drawCircle(Offset(padCenter.dx + 9, padCenter.dy + 6), 2.2, Paint()..color = const Color(0xFFEF4444));
    } else if (handDeco == 'dumbbell_power') {
      // 🏋️ 能量哑铃
      const dbCenter = Offset(0, 54);
      canvas.drawLine(Offset(dbCenter.dx - 18, dbCenter.dy), Offset(dbCenter.dx + 18, dbCenter.dy), Paint()..color = const Color(0xFF94A3B8)..strokeWidth = 4.0..strokeCap = StrokeCap.round);
      final ringPaint = Paint()..color = const Color(0xFF0EA5E9);
      final glowPaint = Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.5);
      for (final side in [-1, 1]) {
        final cx = dbCenter.dx + side * 16.0;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, dbCenter.dy), width: 8, height: 22), const Radius.circular(3)), ringPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, dbCenter.dy), width: 10, height: 24), const Radius.circular(4)), glowPaint);
      }
    }
  }

  /// 绘制禅意蒲团软垫 (佛系大懒喵或榻榻米房专属)
  void _drawZenCushion(Canvas canvas, Offset center) {
    final isZenNeeded = model.personality == 'LAZY' || model.habitat == 'zen_tatami' || model.decorations['back'] == 'cushion_zen';
    if (!isZenNeeded) return;

    final cushionCenter = Offset(center.dx, center.dy + 66);
    final cushionRect = Rect.fromCenter(center: cushionCenter, width: 130, height: 32);

    final matPaint = Paint()..color = const Color(0xFFFDE68A);
    final borderPaint = Paint()
      ..color = const Color(0xFFD97706)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    canvas.drawOval(cushionRect, matPaint);
    canvas.drawOval(cushionRect, borderPaint);

    final weavePaint = Paint()
      ..color = const Color(0xFFB45309).withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    for (double x = cushionRect.left + 16; x < cushionRect.right - 16; x += 12) {
      canvas.drawLine(Offset(x, cushionCenter.dy - 8), Offset(x, cushionCenter.dy + 8), weavePaint);
    }
    canvas.drawCircle(cushionCenter, 4.0, Paint()..color = const Color(0xFFDC2626));
    canvas.drawLine(Offset(cushionRect.right - 4, cushionCenter.dy), Offset(cushionRect.right + 12, cushionCenter.dy + 8), Paint()..color = const Color(0xFFDC2626)..strokeWidth = 2.0);
  }

  /// 绘制家园小窝场景特效 (Habitat Effects)
  void _drawHabitatEffects(Canvas canvas, Size size, Offset center) {
    final habitat = model.habitat;
    if (habitat == 'default') return;

    if (habitat == 'neon_matrix') {
      // 💻 暗夜霓虹极客房：赛博矩阵代码雨与全息地面
      const streamCount = 8;
      for (int i = 0; i < streamCount; i++) {
        final x = (size.width / (streamCount + 1)) * (i + 1);
        final speed = 40.0 + (i * 12.0);
        final yHead = ((animTime * speed) + (i * 35.0)) % (size.height + 60) - 30;

        final streamPath = Path()
          ..moveTo(x, yHead - 45)
          ..lineTo(x, yHead);
        final trailPaint = Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x000EA5E9), Color(0x6600F0FF)],
          ).createShader(Rect.fromLTWH(x - 2, yHead - 45, 4, 45))
          ..strokeWidth = 2.0;
        canvas.drawPath(streamPath, trailPaint);
        canvas.drawCircle(Offset(x, yHead), 2.2, Paint()..color = const Color(0xFF38BDF8));
      }

      final gridPaint = Paint()
        ..color = const Color(0x1800F0FF)
        ..strokeWidth = 1.2;
      final groundY = center.dy + 72;
      for (double gy = groundY; gy < size.height; gy += 14) {
        canvas.drawLine(Offset(0, gy), Offset(size.width, gy), gridPaint);
      }
      for (double gx = 0; gx < size.width; gx += 32) {
        canvas.drawLine(Offset(gx, groundY), Offset(center.dx + (gx - center.dx) * 1.5, size.height), gridPaint);
      }

    } else if (habitat == 'retro_arcade') {
      // 🕹️ 复古像素游戏机房：Synthwave 霓虹脉冲与 8-bit 星星
      const starCount = 6;
      for (int i = 0; i < starCount; i++) {
        final sx = (size.width * 0.15) + (i * (size.width * 0.7 / starCount));
        final sy = 30.0 + math.sin(animTime * 2.5 + i) * 14.0;
        final starSize = 3.5 + math.sin(animTime * 4.0 + i) * 1.5;

        final starPaint = Paint()..color = (i % 2 == 0) ? const Color(0xFFF472B6) : const Color(0xFF38BDF8);
        canvas.drawRect(Rect.fromCenter(center: Offset(sx, sy), width: starSize, height: starSize * 2.5), starPaint);
        canvas.drawRect(Rect.fromCenter(center: Offset(sx, sy), width: starSize * 2.5, height: starSize), starPaint);
      }

      final scanY = (animTime * 35.0) % size.height;
      canvas.drawLine(
        Offset(0, scanY),
        Offset(size.width, scanY),
        Paint()..color = const Color(0x15EC4899)..strokeWidth = 3.0,
      );

    } else if (habitat == 'summer_beach') {
      // 🏖️ 夏日海滩：暖阳金晕、动态舒缓海浪
      final sunCenter = Offset(center.dx, center.dy - 40);
      final sunGlow = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x22FBBF24), Color(0x00F59E0B)],
        ).createShader(Rect.fromCircle(center: sunCenter, radius: 90));
      canvas.drawCircle(sunCenter, 90, sunGlow);

      final wavePaint = Paint()
        ..color = const Color(0x2838BDF8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final wavePath = Path();
      final waveY = center.dy + 62;
      wavePath.moveTo(0, waveY);
      for (double x = 0; x <= size.width; x += 15) {
        final y = waveY + math.sin(animTime * 2.5 + x * 0.04) * 4.5;
        wavePath.lineTo(x, y);
      }
      canvas.drawPath(wavePath, wavePaint);

    } else if (habitat == 'zen_tatami') {
      // 🍵 佛系禅意蒲团室：柔和暖光与樱花花瓣
      final lanternGlow = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x18F59E0B), Color(0x00D97706)],
        ).createShader(Rect.fromCircle(center: center, radius: 100));
      canvas.drawCircle(center, 100, lanternGlow);

      for (int i = 0; i < 5; i++) {
        final px = (size.width * 0.1) + ((animTime * 22.0 + i * 50.0) % (size.width * 0.85));
        final py = 20.0 + ((animTime * 18.0 + i * 40.0) % (size.height * 0.75));
        final petalRot = animTime * 1.5 + i;

        canvas.save();
        canvas.translate(px, py);
        canvas.rotate(petalRot);
        canvas.drawOval(const Rect.fromLTWH(-4, -2, 8, 4), Paint()..color = const Color(0xAAF472B6));
        canvas.restore();
      }
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

    // 2. 玩毛线球 (粉红毛线团在双爪间真实滚动受力反弹，解开拖尾毛线绳蜿蜒于地面)
    else if (state == 'PLAY_YARN') {
      final ballSwayX = math.sin(animTime * 7.0) * 8.5;
      final ballBounceY = 54.0 - math.sin(animTime * 14.0).abs() * 5.0;
      final ballCenter = Offset(ballSwayX, ballBounceY);
      const ballRadius = 13.5;

      // 1. 地面柔和接触阴影
      final shadowPaint = Paint()..color = const Color(0x35000000);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ballSwayX, 64.0), width: 26.0, height: 7.0),
        shadowPaint,
      );

      // 2. 解开蜿蜒于猫咪身前地面的毛线拖尾
      final threadPaint = Paint()
        ..color = const Color(0xFFF43F5E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      final tPath = Path()
        ..moveTo(ballCenter.dx, ballCenter.dy + 8)
        ..cubicTo(ballCenter.dx - 14, ballCenter.dy + 12, ballCenter.dx - 24, 62, ballCenter.dx - 42, 62)
        ..quadraticBezierTo(ballCenter.dx - 52, 62, ballCenter.dx - 56, 56);
      canvas.drawPath(tPath, threadPaint);

      // 3. 毛线球 3D 球体渐变
      final ballRect = Rect.fromCircle(center: ballCenter, radius: ballRadius);
      final sphereShader = const RadialGradient(
        center: Alignment(-0.35, -0.35),
        radius: 0.95,
        colors: [Color(0xFFFFE4E6), Color(0xFFFB7185), Color(0xFFBE123C)],
        stops: [0.0, 0.55, 1.0],
      ).createShader(ballRect);
      canvas.drawCircle(ballCenter, ballRadius, Paint()..shader = sphereShader);

      // 4. 毛线缠绕立体纹理 (随爪爪拨弄节奏高速自转)
      canvas.save();
      canvas.translate(ballCenter.dx, ballCenter.dy);
      canvas.rotate(animTime * 10.0);

      final lineLight = Paint()
        ..color = Colors.white.withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final lineDark = Paint()
        ..color = const Color(0xFF881337).withValues(alpha: 0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: ballRadius * 0.70), 0.2, 2.4, false, lineDark);
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: ballRadius * 0.68), 0.2, 2.4, false, lineLight);

      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: ballRadius * 0.85), 3.0, 2.2, false, lineDark);
      canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: ballRadius * 0.83), 3.0, 2.2, false, lineLight);

      canvas.drawArc(Rect.fromCircle(center: const Offset(2, -2), radius: ballRadius * 0.55), 1.6, 2.6, false, lineLight);

      // 散开的羊毛小绒毛
      canvas.drawLine(
        const Offset(ballRadius * 0.7, -ballRadius * 0.3),
        const Offset(ballRadius * 1.2, -ballRadius * 0.55),
        lineLight..strokeWidth = 1.6,
      );

      canvas.restore();

      // 5. 球体高光点
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ballCenter.dx - 4, ballCenter.dy - 4), width: 5.5, height: 3.2),
        Paint()..color = Colors.white.withValues(alpha: 0.70),
      );

      // 6. 爪爪拍球激起的欢快微绒毛粒子 (Playful fluff puffs)
      final fluffPaint = Paint()..color = const Color(0xFFFBCFE8).withValues(alpha: 0.65);
      canvas.drawCircle(Offset(ballCenter.dx - 12 + math.sin(animTime * 12.0) * 3, ballCenter.dy - 10), 1.6, fluffPaint);
      canvas.drawCircle(Offset(ballCenter.dx + 14 + math.cos(animTime * 12.0) * 3, ballCenter.dy - 8), 1.4, fluffPaint);
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
          style: TextStyle(fontSize: 16, color: Colors.indigo.withValues(alpha: (1.0 - t / 2.0).clamp(0.0, 1.0))),
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
