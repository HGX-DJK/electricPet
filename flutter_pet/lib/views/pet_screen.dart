import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pet_model.dart';
import '../models/memo_model.dart';
import '../renderers/pet_painter.dart';
import 'backpack_drawer.dart';
import 'dialogs/feeding_dialog.dart';
import 'dialogs/wardrobe_dialog.dart';
import 'dialogs/action_dialog.dart';
import 'dialogs/memory_album_dialog.dart';
import 'memo_screen.dart';
import '../services/overlay_service.dart';
import '../services/sound_service.dart';

/// 触摸产生的飘浮爱心与星光特效粒子
class _Particle {
  final Key id = UniqueKey();
  Offset position;
  final String text;
  final Color? color;
  final double fontSize;
  double progress = 0.0; // 0.0 -> 1.0

  _Particle({
    required this.position,
    required this.text,
    this.color,
    this.fontSize = 22,
  });
}

/// 地板治愈微光小猫爪印数据模型 (漫步巡视与追球冲刺时自然交替踩出)
class _Footprint {
  final Offset position;
  final double angle;
  final bool isLeft;
  double opacity;

  _Footprint({
    required this.position,
    required this.angle,
    required this.isLeft,
    this.opacity = 0.45,
  });
}

/// 地板治愈微光小猫爪印渲染器 (温润木质压痕 + 4 个萌态真实猫脚趾印 + 呼吸感微光淡隐)
class _FootprintPainter extends CustomPainter {
  final List<_Footprint> footprints;

  _FootprintPainter(this.footprints);

  @override
  void paint(Canvas canvas, Size size) {
    for (final fp in footprints) {
      if (fp.opacity <= 0.01) continue;
      canvas.save();
      canvas.translate(fp.position.dx, fp.position.dy);
      canvas.rotate(fp.angle);

      // 1. 底层：木地板温润受力微压痕 (温和琥珀暖棕，柔和融入地板，告别假印油感)
      final woodIndentPaint = Paint()
        ..color = const Color(0xFF78350F).withOpacity((fp.opacity * 0.26).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      // 2. 表层：猫咪体温留下的极淡粉嫩微光 (轻盈半透，温润治愈)
      final glowBlushPaint = Paint()
        ..color = const Color(0xFFF472B6).withOpacity((fp.opacity * 0.20).clamp(0.0, 1.0))
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
  bool shouldRepaint(covariant _FootprintPainter oldDelegate) => true;
}

/// 移动端沉浸式互动乐园主界面
class PetScreen extends StatefulWidget {
  final PetModel petModel;
  final MemoModel memoModel;

  const PetScreen({
    super.key,
    required this.petModel,
    required this.memoModel,
  });

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _idleAnimController;
  late AnimationController _squishController; // 点击戳戳 Q 弹形变控制器
  late Animation<double> _squishScaleX;
  late Animation<double> _squishScaleY;

  Timer? _decayTimer;
  Timer? _dialogueTimer;
  Timer? _particleTimer;

  // 萌宠坐标 (默认在屏幕居中偏上舒适视线区域)
  double _petX = 200.0;
  double _petY = 320.0;
  bool _initializedPos = false;
  bool _isDragging = false;
  String _state = 'IDLE';
  bool _facingLeft = false;
  int _idleSeconds = 0; // 待机计时器，驱动自主小萌点
  Timer? _actionTimer;
  Timer? _idleActionTimer;
  Timer? _boopTimer;
  Timer? _scratcherMeowTimer;

  // 维度一：部位差异化感知 & 打呼噜状态
  bool _isPurring = false;
  Timer? _purrTimer;
  Timer? _purrHapticTimer;
  String? _twitchEar;
  Timer? _earTwitchTimer;

  // 揪尾巴炸毛微互动与高频电波甩尾
  bool _isTailPuffed = false;
  Timer? _tailPuffTimer;

  // 方向一：神态与微表情 (飞机耳 + 吐舌头 Blep + 单眼眨眼放电 Wink)
  bool _isAirplaneEars = false;
  Timer? _airplaneEarsTimer;
  bool _isBlep = false;
  String? _winkEye;
  Timer? _winkTimer;
  bool _isSlowBlink = false; // 慢眨眼“猫咪之吻”
  Timer? _slowBlinkTimer;
  bool _isWaterRippling = false; // 水碗波光粼粼涟漪
  Timer? _waterRippleTimer;

  // 方向二：沉浸式养宠仪式感 (拖拽投喂 + 睡垫盖小被子)
  bool _showFoodTray = false;
  String? _draggingFoodId;
  String? _draggingFoodName;
  String? _draggingFoodIcon;
  Offset? _draggingFoodPos;
  bool _isCoveredWithBlanket = false;

  // 方向三：空间环境与天象治愈 (法式拱形观景窗 + 阳光光斑晒太阳)
  int _windowWeather = 0; // 0: ☀️ 阳光暖阳, 1: 🌧️ 细雨水滴, 2: 🌸 春日落樱, 3: 🌙 浪漫星空

  // 地板粉嫩小猫爪印系统
  final List<_Footprint> _footprints = [];
  Offset? _lastFootprintPos;
  bool _footprintLeft = false;

  // 维度二：毛线球物理与小鱼碗弹射
  double _yarnX = 0.0;
  double _yarnY = 0.0;
  double _yarnVx = 0.0;
  double _yarnVy = 0.0;
  bool _isYarnDragging = false;
  bool _isYarnFlying = false;
  bool _isChasingYarn = false;
  bool _yarnInitialized = false;

  bool _fishPopping = false;
  Offset? _poppingFishPos;

  // 维度三：晃动眩晕检测
  int _dragDirectionReversals = 0;
  double _lastDragDirection = 0.0;
  DateTime _lastDragTime = DateTime.now();

  // 维度五：抚摸 Combo 与贴贴屏幕
  int _petCombo = 0;
  Timer? _comboResetTimer;
  bool _hasGlassPawPrints = false;
  List<Offset> _pawPrints = [];

  // 抚摸与手势
  double _strokeDistance = 0.0;
  double _petProgress = 0.0;
  Offset? _touchPos;
  Offset? _lookTargetPos; // 视线追踪目标坐标 (实时注视手指/光标)

  // 飘浮爱心粒子列表
  final List<_Particle> _particles = [];

  // 对话气泡系统
  String _currentDialogue = '喵呜~ 戳戳我或者摸摸我的小脑瓜吧！(ฅ\'ω\'ฅ)';
  bool _showDialogue = true;

  // 画布级无遮挡换装模式 (免弹窗、零遮挡、实时全景预览)
  bool _isWardrobeMode = false;
  int _wardrobeTab = 0; // 0: 猫咪品种, 1: 头部帽子, 2: 颈部配饰

  // 画布级无遮挡专属绝活模式 (免弹窗、零遮挡、实时全景表演点播)
  bool _isActionMode = false;

  // 趣味交互：神奇激光笔逗猫模式 (指尖红点，小猫疯狂追扑)
  bool _isLaserMode = false;
  Offset? _laserPos;

  // 趣味家具交互状态 (猫草微晃、猫抓板震颤、夜灯开关、相框摇摆)
  bool _isNightLampOn = true;
  double _plantTilt = 0.0;
  double _postWiggle = 0.0;
  double _photoAngle = -0.06;
  Timer? _plantAnimTimer;
  Timer? _postAnimTimer;
  Timer? _photoAnimTimer;

  // 自主生活与房间 2.5D 全向漫步系统 (Autonomous Living & 2.5D Roaming)
  double? _targetWalkX;
  double? _targetWalkY;
  String? _roamTargetName;
  bool _isRoaming = false;
  Timer? _roamTimer;
  Size _lastScreenSize = const Size(360, 640);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 呼吸律动主循环
    _idleAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // 触碰 Q 弹形变动画
    _squishController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _squishScaleX = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.94).chain(CurveTween(curve: Curves.easeInOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
    ]).animate(_squishController);

    _squishScaleY = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.06).chain(CurveTween(curve: Curves.easeInOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 30),
    ]).animate(_squishController);

    // 粒子飞升与物理帧驱动定时器 (60fps)
    _particleTimer = Timer.periodic(const Duration(milliseconds: 24), (timer) {
      bool needRepaint = false;
      if (_particles.isNotEmpty) {
        _particles.removeWhere((p) {
          p.progress += 0.035;
          p.position = Offset(p.position.dx, p.position.dy - 1.8);
          return p.progress >= 1.0;
        });
        needRepaint = true;
      }

      // 地板温润小猫爪印渐隐消退 (左右脚印在约 1.2 秒内如体温散去般优雅淡化消散)
      if (_footprints.isNotEmpty) {
        _footprints.removeWhere((fp) {
          fp.opacity -= 0.022;
          return fp.opacity <= 0.0;
        });
        needRepaint = true;
      }

      // 毛线球物理运动与猫咪追逐飞扑驱动
      if (_isYarnFlying || _isChasingYarn) {
        if (_isYarnFlying) {
          _yarnX += _yarnVx;
          _yarnY += _yarnVy;
          _yarnVx *= 0.95;
          _yarnVy = (_yarnVy + 0.42) * 0.96;

          final minX = 24.0;
          final maxX = _lastScreenSize.width > 100 ? (_lastScreenSize.width - 24.0) : 340.0;
          final floorTop = (_lastScreenSize.height * 0.28).clamp(195.0, 245.0);
          final minY = floorTop + 20.0;
          final maxY = _lastScreenSize.height > 200 ? (_lastScreenSize.height - 110.0) : 600.0;

          // 左右墙壁弹性反弹
          if (_yarnX <= minX) {
            _yarnX = minX;
            _yarnVx = -_yarnVx * 0.75;
          } else if (_yarnX >= maxX) {
            _yarnX = maxX;
            _yarnVx = -_yarnVx * 0.75;
          }

          // 剑麻猫抓柱实体物理碰撞反弹 (右上角障碍物自然反弹)
          final postCenterX = _lastScreenSize.width - 48.0;
          final postCenterY = floorTop + 42.0;
          if ((_yarnX - postCenterX).abs() < 28.0 && (_yarnY - postCenterY).abs() < 38.0) {
            _yarnVx = -_yarnVx.abs() * 0.82; // 弹向左侧
            _yarnVy = -_yarnVy * 0.72;
            _spawnParticles(Offset(postCenterX, postCenterY), emoji: '🪵', count: 2);
            SoundService.playClick();
          }

          // 地板与踢脚线弹性反弹
          if (_yarnY >= maxY) {
            _yarnY = maxY;
            _yarnVy = -_yarnVy * 0.65;
          } else if (_yarnY <= minY) {
            _yarnY = minY;
            _yarnVy = -_yarnVy * 0.70;
          }

          if (_yarnVx.abs() < 0.25 && _yarnVy.abs() < 0.25) {
            _isYarnFlying = false;
            _yarnVx = 0.0;
            _yarnVy = 0.0;
          }
        }

        // 猫咪主动飞奔追球、翻转朝向与扑球逻辑
        if (!_isDragging && !_isLaserMode && !_isWardrobeMode && !_isActionMode && !widget.petModel.isSleeping) {
          final catPos = Offset(_petX, _petY);
          final ballPos = Offset(_yarnX, _yarnY);
          final diff = ballPos - catPos;
          final dist = diff.distance;

          // 实时翻转朝向对准毛线球
          if (diff.dx.abs() > 6) {
            _facingLeft = diff.dx < 0;
          }

          if (dist > 45.0) {
            // 未抓住时：猫咪迈动小碎步疾速奔跑追赶！
            if (_state != 'WALK' && _state != 'PLAY_YARN') {
              _state = 'WALK';
            }
            final speed = math.min(dist * 0.18, 9.5);
            final norm = diff / dist;
            _petX += norm.dx * speed;
            _petY += norm.dy * speed;
            final floorTop = (_lastScreenSize.height * 0.28).clamp(195.0, 245.0);
            _petX = _petX.clamp(35.0, _lastScreenSize.width - 35.0);
            _petY = _petY.clamp(floorTop + 25.0, _lastScreenSize.height - 115.0);
            _maybeAddFootprint(Offset(_petX, _petY));
          } else {
            // 飞扑捕获成功瞬间！(Pounce & Catch)
            _isYarnFlying = false;
            _isChasingYarn = false;
            _yarnVx = 0.0;
            _yarnVy = 0.0;

            _yarnX = _petX + (_facingLeft ? -25.0 : 25.0);
            _yarnY = _petY + 48.0;

            _playAction('PLAY_YARN');
            SoundService.playMeow();
            if (widget.petModel.enableHaptics) {
              HapticFeedback.heavyImpact();
            }

            _squishController.forward(from: 0.0);
            _spawnParticles(ballPos, emoji: '🧶', count: 4);
            _spawnParticles(ballPos, emoji: '✨', count: 3);
            _spawnParticles(Offset(_petX, _petY - 20), emoji: '🐾', count: 3);
            _spawnTextParticle(Offset(_petX - 35, _petY - 55), '扑到毛线球啦！🐾🧶', const Color(0xFFF43F5E));
            _spawnTextParticle(Offset(_petX + 25, _petY - 75), '+8 经验 ✨', const Color(0xFF6366F1));
            widget.petModel.addExp(8.0);
            _showDialogueBubble('哇！猛虎飞扑抓住毛线球啦！抱紧紧滚来滚去~ 🧶🐾💕', duration: const Duration(seconds: 4));

            _actionTimer?.cancel();
            _actionTimer = Timer(const Duration(milliseconds: 3500), () {
              if (mounted && _state == 'PLAY_YARN') {
                setState(() => _state = 'SIT_WAG_TAIL');
              }
            });
          }
        }
        needRepaint = true;
      }

      // 小鱼跳跃吃食动画更新
      if (_fishPopping && _poppingFishPos != null) {
        final target = Offset(_petX, _petY - 20);
        final current = _poppingFishPos!;
        final delta = target - current;
        if (delta.distance < 18) {
          _fishPopping = false;
          _poppingFishPos = null;
          widget.petModel.feed('fish');
          _playAction('EATING');
          _spawnParticles(Offset(_petX, _petY - 20), emoji: '🐟', count: 4);
          _spawnTextParticle(Offset(_petX - 30, _petY - 50), '+12 饱腹 ❤️', const Color(0xFFF59E0B));
          _showDialogueBubble('嗷呜！波可一口接住了小碗里跳出来的小鲜鱼！(๑´ڡ`๑)🐟');
        } else {
          _poppingFishPos = current + delta * 0.22;
        }
        needRepaint = true;
      }

      // 激光笔逗猫物理驱动：猫咪追光飞扑
      if (_isLaserMode && _laserPos != null) {
        final catPos = Offset(_petX, _petY);
        final diff = _laserPos! - catPos;
        final dist = diff.distance;

        // 猫咪朝向随激光点实时左右翻转
        if (diff.dx.abs() > 8) {
          _facingLeft = diff.dx < 0;
        }

        if (dist > 35) {
          // 猫咪迈动爪爪向激光点快速奔跑
          final step = math.min(dist * 0.14, 8.5);
          final norm = diff / dist;
          _petX += norm.dx * step;
          _petY += norm.dy * step;
          _maybeAddFootprint(Offset(_petX, _petY));
          needRepaint = true;
        } else {
          // 扑到激光点瞬间！
          _squishController.forward(from: 0.0);
          if (widget.petModel.enableHaptics) {
            HapticFeedback.mediumImpact();
          }
          _spawnParticles(_laserPos!, emoji: '💥', count: 3);
          _spawnTextParticle(Offset(_petX - 25, _petY - 45), '扑到啦！🐾', const Color(0xFFEF4444));
          // 激光点受惊随机跳向旁边（模拟真实手抖跳跃）
          final randomAngle = math.Random().nextDouble() * 2 * math.pi;
          final jumpDist = 90.0 + math.Random().nextDouble() * 70.0;
          final nextX = (_laserPos!.dx + math.cos(randomAngle) * jumpDist).clamp(40.0, 340.0);
          final nextY = (_laserPos!.dy + math.sin(randomAngle) * jumpDist).clamp(160.0, 520.0);
          _laserPos = Offset(nextX, nextY);
          needRepaint = true;
        }
      }

      // 自主漫步巡视运动驱动 (猫咪 2.5D 全向小碎步有机踱步，自由穿梭于家具之间)
      if (_isRoaming && _state == 'WALK' && _targetWalkX != null && _targetWalkY != null) {
        final dx = _targetWalkX! - _petX;
        final dy = _targetWalkY! - _petY;
        final dist = math.sqrt(dx * dx + dy * dy);

        if (dist > 3.0) {
          // 猫咪优雅小碎步：每帧沿矢量平滑行进约 1.8px
          final step = math.min(dist, 1.8);
          _petX += (dx / dist) * step;
          _petY += (dy / dist) * step;
          _maybeAddFootprint(Offset(_petX, _petY));

          // 转向自然对齐横向运动分量
          if (dx.abs() > 0.8) {
            _facingLeft = (dx < 0);
          }
          needRepaint = true;
        } else {
          _petX = _targetWalkX!;
          _petY = _targetWalkY!;
          _isRoaming = false;
          final target = _roamTargetName;
          _targetWalkX = null;
          _targetWalkY = null;
          _roamTargetName = null;
          _onArrivedAtDestination(target);
          needRepaint = true;
        }
      }

      if (needRepaint && mounted) {
        setState(() {});
      }
    });

    // 状态自然衰减与自言自语及自主微动作定时器
    _decayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      widget.petModel.tickDecay(1.0);
      _checkAutoDialogue();

      // 自主生活与房间漫步引擎：待机 3~4 秒即刻活跃生活起来！
      if ((_state == 'IDLE' || _state == 'WALK') && !_isDragging && !_isLaserMode && !_isWardrobeMode && !_isActionMode && !widget.petModel.isSleeping) {
        _idleSeconds++;
        if (_idleSeconds >= 4 && !_isRoaming) {
          _idleSeconds = 0;
          _triggerAutonomousLiving(_lastScreenSize);
        }
      } else {
        _idleSeconds = 0;
      }
    });

    // 监听 PetModel 属性变更
    widget.petModel.addListener(_onModelUpdated);

    // 启动初始对话 (根据当前真实时段问候)
    final circadian = _getCircadianTheme();
    _showDialogueBubble(circadian['greeting'] as String);
  }

  void _onModelUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      widget.petModel.saveToDisk();
      widget.memoModel.saveToDisk();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.petModel.saveToDisk();
    widget.memoModel.saveToDisk();
    widget.petModel.removeListener(_onModelUpdated);
    _idleAnimController.dispose();
    _squishController.dispose();
    _decayTimer?.cancel();
    _dialogueTimer?.cancel();
    _particleTimer?.cancel();
    _purrTimer?.cancel();
    _purrHapticTimer?.cancel();
    _earTwitchTimer?.cancel();
    _comboResetTimer?.cancel();
    _tailPuffTimer?.cancel();
    _airplaneEarsTimer?.cancel();
    _winkTimer?.cancel();
    _actionTimer?.cancel();
    _idleActionTimer?.cancel();
    _boopTimer?.cancel();
    _scratcherMeowTimer?.cancel();
    _plantAnimTimer?.cancel();
    _postAnimTimer?.cancel();
    _photoAnimTimer?.cancel();
    _roamTimer?.cancel();
    _slowBlinkTimer?.cancel();
    _waterRippleTimer?.cancel();
    SoundService.dispose();
    super.dispose();
  }

  /// 触发俏皮单眼眨眼放电 (Wink 😉)
  void _triggerWink({String? eye}) {
    if (_winkEye != null) return;
    setState(() {
      _winkEye = eye ?? (math.Random().nextBool() ? 'LEFT' : 'RIGHT');
    });
    _winkTimer?.cancel();
    _winkTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _winkEye = null);
    });
  }

  /// 睡垫盖小被子 / 掀开被子微互动 (Tuck-in Blanket 🛏️)
  void _toggleBlanket() {
    _idleSeconds = 0;
    SoundService.playPop();
    if (widget.petModel.enableHaptics) HapticFeedback.mediumImpact();
    setState(() {
      _isCoveredWithBlanket = !_isCoveredWithBlanket;
    });
    if (_isCoveredWithBlanket) {
      widget.petModel.addIntimacy(3);
      _spawnParticles(Offset(_petX, _petY - 15), emoji: '🛏️', count: 3);
      _spawnTextParticle(Offset(_petX - 35, _petY - 50), '盖好小被子 💤 +3亲密', const Color(0xFFF43F5E));
      _showDialogueBubble('盖好暖和的小被子啦~ 呼噜噜好舒服 (ฅ˘ω˘ฅ)🛌💕');
    } else {
      _showDialogueBubble('掀开小被子起床伸个大懒腰啦~ 🥱🐾');
    }
  }

  /// 拖拽小食投喂结算 (Drag-to-Feed Finish 🥣)
  void _finishDragToFeed(int hungerGain, int intimacyGain) {
    if (_draggingFoodPos == null) return;
    final petHeadPos = Offset(_petX, _petY - 20);
    final dist = (_draggingFoodPos! - petHeadPos).distance;
    final foodName = _draggingFoodName ?? '美味零食';
    final foodIcon = _draggingFoodIcon ?? '🐟';

    if (dist < 110.0) {
      // 投喂成功！嗷呜飞扑吞食
      SoundService.playMeow(tone: MeowTone.short);
      if (widget.petModel.enableHaptics) HapticFeedback.heavyImpact();
      _squishController.forward(from: 0.0);
      widget.petModel.feed(_draggingFoodId ?? 'dried_fish');
      widget.petModel.addIntimacy(intimacyGain);
      _spawnParticles(petHeadPos, emoji: foodIcon, count: 5);
      _spawnParticles(petHeadPos, emoji: '💖', count: 3);
      _spawnTextParticle(Offset(_petX - 35, _petY - 55), '+$hungerGain 饱腹  +$intimacyGain 亲密 💖', const Color(0xFFF43F5E));
      _triggerWink();
      if (math.Random().nextBool()) {
        setState(() => _isBlep = true);
      }
      _showDialogueBubble('嗷呜一大口！吃掉了$foodName，最喜欢主人啦~ 😋💕');
      setState(() {
        _showFoodTray = false;
        _draggingFoodPos = null;
        _lookTargetPos = null;
      });
    } else {
      _showDialogueBubble('小零食拿近一点嘛，波可够不着啦~ 🐾');
      setState(() {
        _draggingFoodPos = null;
        _lookTargetPos = null;
      });
    }
  }

  /// 循环切换法式观景窗天象 (Cycle Window Weather 🪟)
  void _cycleWindowWeather() {
    _idleSeconds = 0;
    SoundService.playPop();
    if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
    setState(() {
      _windowWeather = (_windowWeather + 1) % 4;
    });

    // 0: ☀️ 暖阳晴空, 1: 🌧️ 治愈雨季, 2: 🌸 春日落樱, 3: 🌙 浪漫星空
    if (_windowWeather == 1) {
      // 联动开启治愈自然雨声 ASMR 白噪音
      SoundService.setAmbientMode('rain');
    } else {
      // 切换至其他天象时停止雨声
      if (SoundService.ambientMode == 'rain') {
        SoundService.stopAmbient();
      }
    }

    final names = ['暖阳晴空 ☀️', '治愈雨季 🌧️', '春日落樱 🌸', '浪漫星空 🌙'];
    final quotes = [
      '推开法式拱形窗~ 窗外是暖洋洋的晴空万里！☀️',
      '窗外下起淅淅沥沥的小雨啦~ 听着雨声好治愈 🌧️',
      '微风吹拂，粉嫩的樱花瓣飘进房间里来啦~ 🌸',
      '星光闪烁，浪漫星空与静谧月牙升起啦~ 🌙✨',
    ];
    _spawnParticles(Offset(MediaQuery.of(context).size.width - 70, 100), emoji: ['☀️', '🌧️', '🌸', '⭐'][_windowWeather], count: 4);
    _spawnTextParticle(Offset(MediaQuery.of(context).size.width - 95, 75), names[_windowWeather], const Color(0xFF6366F1));
    _showDialogueBubble(quotes[_windowWeather]);
  }

  /// 弹出亲密度羁绊详情成就卡片 (Intimacy Bond Modal 💖)
  void _showIntimacyBondModal() {
    _idleSeconds = 0;
    SoundService.playPop();
    if (widget.petModel.enableHaptics) HapticFeedback.selectionClick();

    final bondInfo = widget.petModel.intimacyBondInfo;
    final stage = bondInfo['stage'] as int;
    final title = bondInfo['title'] as String;
    final icon = bondInfo['icon'] as String;
    final color = Color(bondInfo['color'] as int);
    final ownerTitle = bondInfo['ownerTitle'] as String;
    final desc = bondInfo['desc'] as String;
    final progress = (bondInfo['progress'] as double).clamp(0.0, 1.0);
    final nextThreshold = bondInfo['nextThreshold'] as int;
    final isNight = _windowWeather == 3;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF1E1B4B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -6)),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isNight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text(
                        '波可与你的亲密羁绊',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isNight ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isNight ? const Color(0xFF332D73) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 18, color: isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.18), color.withOpacity(0.06)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '第 $stage 阶段 · $title',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '亲密值: ${widget.petModel.intimacy}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '波可对你的专属称谓：',
                      style: TextStyle(fontSize: 11, color: isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '「$ownerTitle」',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: isNight ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: isNight ? const Color(0xFF332D73) : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage < 5 ? '距下一阶段还需 ${nextThreshold - widget.petModel.intimacy} 点亲密值' : '已达成最高灵魂羁绊！✨',
                      style: TextStyle(fontSize: 10, color: isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '💎 羁绊阶段专属特权',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isNight ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              _buildBondPrivilegeItem('🌱 阶段 1 · 陌生萌新', '解锁房间全向 2.5D 自主漫步视察', stage >= 1, isNight),
              _buildBondPrivilegeItem('🐾 阶段 2 · 熟悉玩伴', '解锁波可主动奔跑贴贴屏幕与击掌', stage >= 2, isNight),
              _buildBondPrivilegeItem('💖 阶段 3 · 亲密依恋', '解锁专属配饰【皇家丝绒披风】', stage >= 3, isNight),
              _buildBondPrivilegeItem('⭐ 阶段 4 · 形影不离', '解锁专属帽子【璀璨星辉皇冠】', stage >= 4, isNight),
              _buildBondPrivilegeItem('👑 阶段 5 · 灵魂羁绊', '解锁终极专属称谓与灵魂心意相通', stage >= 5, isNight),
              const SizedBox(height: 12),
              if (stage >= 3 || stage >= 4)
                Row(
                  children: [
                    if (stage >= 3)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              final cur = widget.petModel.decorations['neck'];
                              widget.petModel.setDecoration('neck', cur == 'royal_cape' ? 'none' : 'royal_cape');
                            });
                            _spawnParticles(Offset(_petX, _petY - 20), emoji: '🦸‍♂️', count: 4);
                            _showDialogueBubble('披上帅气的皇家丝绒披风啦！威风凛凛~ ✨');
                          },
                          icon: const Text('🦸‍♂️', style: TextStyle(fontSize: 16)),
                          label: Text(widget.petModel.decorations['neck'] == 'royal_cape' ? '卸下披风' : '穿上披风'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B21A8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    if (stage >= 3 && stage >= 4) const SizedBox(width: 10),
                    if (stage >= 4)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              final cur = widget.petModel.decorations['head'];
                              widget.petModel.setDecoration('head', cur == 'gold_crown_sparkle' ? 'none' : 'gold_crown_sparkle');
                            });
                            _spawnParticles(Offset(_petX, _petY - 20), emoji: '👑', count: 4);
                            _showDialogueBubble('戴上闪闪发光的璀璨星辉皇冠啦！波可是全世界最棒的小猫~ 👑✨');
                          },
                          icon: const Text('✨', style: TextStyle(fontSize: 16)),
                          label: Text(widget.petModel.decorations['head'] == 'gold_crown_sparkle' ? '摘下皇冠' : '戴上星冠'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBondPrivilegeItem(String title, String desc, bool unlocked, bool isNight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            size: 16,
            color: unlocked ? const Color(0xFF10B981) : (isNight ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$title: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: unlocked
                      ? (isNight ? Colors.white : const Color(0xFF1E293B))
                      : (isNight ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
                children: [
                  TextSpan(
                    text: desc,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.normal,
                      color: unlocked
                          ? (isNight ? const Color(0xFFCBD5E1) : const Color(0xFF475569))
                          : (isNight ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDialogueBubble(String text, {Duration duration = const Duration(seconds: 4)}) {
    if (!mounted) return;
    setState(() {
      _currentDialogue = text;
      _showDialogue = true;
    });
    _dialogueTimer?.cancel();
    _dialogueTimer = Timer(duration, () {
      if (mounted) {
        setState(() {
          _showDialogue = false;
        });
      }
    });
  }

  void _checkAutoDialogue() {
    if (_isDragging || widget.petModel.isSleeping || _state != 'IDLE') return;

    // 随机微表情：俏皮单眼放电 (Wink)
    if (_winkEye == null && math.Random().nextDouble() < 0.12) {
      _triggerWink();
    }

    // 随机微表情：呆萌吐小舌头 (Blep)
    if (!_isBlep && math.Random().nextDouble() < 0.14) {
      setState(() => _isBlep = true);
    }

    if (_showDialogue) return;
    if (math.Random().nextDouble() < 0.20) {
      final lines = [
        '主人看屏幕累了吗？眨眨眼睛休息一下吧~ 🐾',
        '咕噜噜... 只要在主人身边就最安心了~ ✨',
        '今天的空气甜甜的，想吃一块草莓小蛋糕！🍰',
        '波可偷偷在草稿纸上画了主人的笑脸！💕',
        '伸个大懒腰~ 准备好和主人一起冲鸭！🚀',
      ];
      _showDialogueBubble(lines[math.Random().nextInt(lines.length)]);
    }
  }

  /// 释放粒子特效 (爱心、星星、爪印)
  void _spawnParticles(Offset pos, {String? emoji, int count = 3}) {
    final emojis = [emoji ?? '❤️', '✨', '🐾', '💕'];
    final rnd = math.Random();
    for (int i = 0; i < count; i++) {
      final offsetX = (rnd.nextDouble() - 0.5) * 60;
      final offsetY = (rnd.nextDouble() - 0.5) * 30;
      _particles.add(_Particle(
        position: Offset(pos.dx + offsetX, pos.dy + offsetY),
        text: emojis[rnd.nextInt(emojis.length)],
      ));
    }
  }

  /// 释放属性增加浮动文字飘字 (+饱腹、+经验)
  void _spawnTextParticle(Offset pos, String text, Color color) {
    _particles.add(_Particle(
      position: pos,
      text: text,
      color: color,
      fontSize: 13,
    ));
  }

  void _stopRoaming() {
    _isRoaming = false;
    _targetWalkX = null;
    _targetWalkY = null;
    _roamTargetName = null;
    _roamTimer?.cancel();
  }

  /// 触碰/戳戳萌宠
  void _onPetTap(Offset globalPos) {
    _idleSeconds = 0;
    _stopRoaming();
    SoundService.playMeow();
    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    _squishController.forward(from: 0.0);
    _spawnParticles(Offset(_petX, _petY - 30), count: 4);

    widget.petModel.petHead();

    // 连续轻抚摸头连击判定 (连续轻抚 5 次触发贴贴屏幕惊喜，仅在地面非拖拽时触发)
    _petCombo++;
    _comboResetTimer?.cancel();
    _comboResetTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        setState(() => _petCombo = 0);
      }
    });

    if (_petCombo >= 5 && _state != 'GLASS_BOOP' && !_isDragging) {
      _petCombo = 0;
      _triggerGlassBoop(_lastScreenSize);
      return;
    }

    final petLines = [
      '喵呜~ 蹭蹭主人的手心！好喜欢主人~ (ฅ\'ω\'ฅ)',
      '咕噜咕噜... 被主人戳得好舒服呀！💕',
      '波可的小脑袋随时供主人随意揉揉~ ✨',
      '嘿嘿！元气+100，主人今天也是最棒的！🐾',
    ];
    _showDialogueBubble(petLines[math.Random().nextInt(petLines.length)]);
  }

  /// 双击触发开心旋转绝活
  void _onPetDoubleTap() {
    _idleSeconds = 0;
    _stopRoaming();
    SoundService.playMeow();
    if (widget.petModel.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    _playAction('HAPPY_SPIN');
    _spawnParticles(Offset(_petX, _petY - 40), emoji: '⭐', count: 6);
  }

  void _playAction(String actionId) {
    _idleSeconds = 0;
    _stopRoaming();
    if (actionId != 'PLAY_YARN') {
      _isChasingYarn = false;
    }
    if (actionId == 'DOZE_OFF' || actionId == 'KNEADING_BISCUITS') {
      SoundService.startPurr();
    } else {
      SoundService.playMeow();
    }
    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _state = actionId;
    });

    final actionLines = {
      'CARDBOARD_BOX': '钻进快递纸箱啦！好有安全感，探头偷看~ 📦✨',
      'CATCH_MOUSE': '看我的喵影神捕！敏捷一扑抓住机械小老鼠啦！🐭💨',
      'PLAY_YARN': '粉红毛线球滚呀滚~ 抱紧滚来滚去！🧶🐾',
      'PEEK_EDGE': '悄悄趴在屏幕边上偷看主人写代码~ 👀💕',
      'WASH_FACE': '爪爪沾沾温水，认真洗脸理毛变帅帅~ 🫧✨',
      'STRETCH_YAWN': '哈欠连天~ 伸个大大的懒腰，浑身舒畅！🥱',
      'KNEADING_BISCUITS': '呼噜噜~ 波可正在软软窝垫上幸福踩奶做小面包呢！(ฅ˘ω˘ฅ)🥐💕',
      'TILT_HEAD': '歪头好奇打量~ 主人在看什么有趣的内容呢？❓',
      'LOOK_AROUND': '左瞅瞅右看看，波可认真保卫主人手机！🔍🐾',
      'SIT_WAG_TAIL': '乖乖端坐，蓬松大尾巴兴奋晃来晃去~ 🐈💕',
      'HEAD_BOB_MUSIC': '戴上潮流大耳机！动次打次跟着节拍摇头晃脑~ 🎵🎧',
      'CHASE_BUTTERFLY': '哇！彩光小蝴蝶飞来啦~ 灵巧一扑！🦋✨',
      'HAPPY_SPIN': '开心到飞起！旋转跳跃转圈圈~ 💫(✧ω✧)',
      'DOZE_OFF': '小脑瓜一点一点... 困意来袭，打个小瞌睡~ 💤',
      'DIZZY': '小星星在头上转呀转~ 晕乎乎晃悠悠~ ⭐🌀',
    };

    final actionEmojis = {
      'CARDBOARD_BOX': '📦',
      'CATCH_MOUSE': '🐭',
      'PLAY_YARN': '🧶',
      'PEEK_EDGE': '👀',
      'WASH_FACE': '🫧',
      'STRETCH_YAWN': '🥱',
      'KNEADING_BISCUITS': '🥐',
      'TILT_HEAD': '❓',
      'LOOK_AROUND': '🔍',
      'SIT_WAG_TAIL': '🐾',
      'HEAD_BOB_MUSIC': '🎵',
      'CHASE_BUTTERFLY': '🦋',
      'HAPPY_SPIN': '💫',
      'DOZE_OFF': '💤',
      'DIZZY': '⭐',
    };

    final msg = actionLines[actionId] ?? '波可展现了独家才艺！✨';
    _showDialogueBubble(msg, duration: const Duration(seconds: 5));
    _spawnParticles(Offset(_petX, _petY - 40), emoji: actionEmojis[actionId], count: 5);

    _actionTimer?.cancel();
    _actionTimer = Timer(const Duration(milliseconds: 5200), () {
      if (mounted && _state == actionId) {
        if (actionId == 'DOZE_OFF') {
          SoundService.stopPurr();
        }
        setState(() {
          _state = 'IDLE';
        });
      }
    });
  }

  /// 自主生活与房间 2.5D 深度漫步系统 (Autonomous Living & 2.5D Roaming)
  /// 猫咪待机 3~4 秒即刻自主决策：45% 概率在房间内全向漫步视察家具，55% 概率做原地萌趣小动作
  void _triggerAutonomousLiving(Size screenSize) {
    if (!mounted || _isDragging || _isLaserMode || _isWardrobeMode || _isActionMode || widget.petModel.isSleeping) return;
    if (_isRoaming) return;

    final floorTop = (screenSize.height * 0.28).clamp(195.0, 245.0);
    final nestX = screenSize.width / 2;
    final nestY = floorTop + 130.0;
    final rnd = math.Random();

    // 45% 概率在 2.5D 房间内自由漫步穿梭视察家具
    if (rnd.nextDouble() < 0.45) {
      final targets = <Map<String, dynamic>>[
        // 目标 A: 左上方木地板角落 · 猫草盆栽 (深层空间)
        {
          'x': 82.0,
          'y': floorTop + 42.0,
          'name': 'CAT_GRASS',
          'msg': '迈着轻快小碎步，去左上方视察猫草盆栽~ 🌿',
        },
        // 目标 B: 右上方木地板角落 · 原木剑麻猫抓柱 (深层空间)
        {
          'x': (screenSize.width - 82.0).clamp(nestX + 40.0, screenSize.width - 45.0),
          'y': floorTop + 42.0,
          'name': 'SCRATCHING_POST',
          'msg': '溜达去右上方的剑麻猫抓柱，准备磨磨爪爪~ 🪵',
        },
        // 目标 C: 左下前侧地板 · 精致小猫碗 (前景开阔区)
        {
          'x': 85.0,
          'y': (nestY + 95.0).clamp(floorTop + 60.0, screenSize.height - 120.0),
          'name': 'FOOD_BOWL',
          'msg': '小步溜达到小食碗边，闻闻酥脆小鱼干！🥣',
        },
        // 目标 D: 右下前侧地板 · 温馨小夜灯 (前景开阔区)
        {
          'x': (screenSize.width - 85.0).clamp(nestX + 40.0, screenSize.width - 45.0),
          'y': (nestY + 95.0).clamp(floorTop + 60.0, screenSize.height - 120.0),
          'name': 'NIGHT_LAMP',
          'msg': '溜达去右前方小夜灯下蹭蹭暖光~ 💡',
        },
        // 目标 E: 开阔活动中庭 · 实体粉红毛线球
        {
          'x': _yarnX.clamp(55.0, screenSize.width - 55.0),
          'y': (_yarnY - 22.0).clamp(floorTop + 45.0, screenSize.height - 125.0),
          'name': 'YARN_BALL',
          'msg': '悄悄溜向粉红毛线球，准备扑一下！🧶',
        },
        // 目标 F: 回大猫窝中心暖绒垫 (中央核心)
        {
          'x': nestX,
          'y': nestY,
          'name': 'COZY_NEST',
          'msg': '小碎步踱步回暖暖的大猫窝啦~ ☁️🐾',
        },
        // 目标 G: 阳光光斑 · 暖阳晒肚皮 (晴空出现)
        if (_windowWeather == 0)
          {
            'x': (nestX + 42.0).clamp(50.0, screenSize.width - 50.0),
            'y': (nestY - 18.0).clamp(floorTop + 30.0, screenSize.height - 120.0),
            'name': 'SUNBEAM_PATCH',
            'msg': '小碎步溜去阳光光斑里晒太阳打盹~ ☀️',
          },
      ];

      // 挑选一个离当前位置有一定真实 2D 距离的目标 (避免原地踏步)
      targets.shuffle();
      Map<String, dynamic>? selectedTarget;
      for (final t in targets) {
        final tx = t['x'] as double;
        final ty = t['y'] as double;
        final dist = math.sqrt((tx - _petX) * (tx - _petX) + (ty - _petY) * (ty - _petY));
        if (dist > 35.0) {
          selectedTarget = t;
          break;
        }
      }
      selectedTarget ??= targets.first;

      final targetX = selectedTarget['x'] as double;
      final targetY = selectedTarget['y'] as double;
      final targetName = selectedTarget['name'] as String;
      final msg = selectedTarget['msg'] as String;

      _startWalkingTo(targetX, targetY, targetName, msg);
    } else {
      // 55% 概率原地自主萌态微动作
      final idleActions = [
        'WASH_FACE',
        'TILT_HEAD',
        'LOOK_AROUND',
        'SIT_WAG_TAIL',
        'STRETCH_YAWN',
        'DOZE_OFF',
      ];
      final act = idleActions[rnd.nextInt(idleActions.length)];
      setState(() {
        _state = act;
      });

      final actionLines = {
        'WASH_FACE': '爪爪沾沾温水，认真洗脸理毛变帅帅~ 🫧✨',
        'TILT_HEAD': '歪头好奇打量~ 主人在看什么有趣的内容呢？❓',
        'LOOK_AROUND': '左瞅瞅右看看，波可认真保卫主人手机！🔍🐾',
        'SIT_WAG_TAIL': '乖乖端坐，蓬松大尾巴兴奋晃来晃去~ 🐈💕',
        'STRETCH_YAWN': '哈欠连天~ 伸个大大的懒腰，浑身舒畅！🥱',
        'DOZE_OFF': '小脑瓜一点一点... 困意来袭，打个小瞌睡~ 💤',
      };
      if (actionLines.containsKey(act)) {
        _showDialogueBubble(actionLines[act]!, duration: const Duration(seconds: 4));
      }

      if (act == 'DOZE_OFF') {
        SoundService.startPurr();
      } else if (act == 'TILT_HEAD' || act == 'WASH_FACE') {
        SoundService.playMeow();
      }

      _idleActionTimer?.cancel();
      _idleActionTimer = Timer(const Duration(milliseconds: 3800), () {
        if (mounted && _state == act) {
          if (act == 'DOZE_OFF') {
            SoundService.stopPurr();
          }
          setState(() {
            _state = 'IDLE';
          });
        }
      });
    }
  }

  /// 启动 2.5D 小碎步全向漫步巡视
  void _startWalkingTo(double targetX, double targetY, String targetName, String msg) {
    if (!mounted || _isDragging || widget.petModel.isSleeping) return;
    setState(() {
      _isRoaming = true;
      _isCoveredWithBlanket = false;
      _targetWalkX = targetX;
      _targetWalkY = targetY;
      _roamTargetName = targetName;
      _facingLeft = (targetX < _petX);
      _state = 'WALK';
    });
    SoundService.playMeow();
    _showDialogueBubble(msg, duration: const Duration(seconds: 3));

    // 防卡死保护：最多 8 秒结束漫步
    _roamTimer?.cancel();
    _roamTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _isRoaming) {
        setState(() {
          _isRoaming = false;
          _targetWalkX = null;
          _targetWalkY = null;
          _roamTargetName = null;
          _state = 'IDLE';
        });
      }
    });
  }

  /// 漫步到达巡视目的地后的智能有机交互触发
  void _onArrivedAtDestination(String? targetName) {
    _roamTimer?.cancel();
    final floorTop = (_lastScreenSize.height * 0.28).clamp(195.0, 245.0);
    final nestX = _lastScreenSize.width / 2;
    final nestY = floorTop + 130.0;

    switch (targetName) {
      case 'CAT_GRASS':
        _onPlantTap();
        _playAction('LOOK_AROUND');
        _showDialogueBubble('巡视猫草盆栽~ 凑近闻闻青草清香！🌱✨');
        break;
      case 'SCRATCHING_POST':
        _onScratcherTap();
        _playAction('WASH_FACE');
        _showDialogueBubble('巡视剑麻猫抓柱~ 伸个懒腰准备磨爪爪！🪵🐾');
        break;
      case 'FOOD_BOWL':
        _popFishFromBowl(nestX, nestY);
        _playAction('LOOK_AROUND');
        _showDialogueBubble('来到小猫碗边啦~ 闻闻还有没有酥脆小鱼干！🥣😋');
        break;
      case 'NIGHT_LAMP':
        _onNightLampTap();
        _playAction('LOOK_AROUND');
        _showDialogueBubble('来到小夜灯边~ 暖融融的光晕好舒服呀！💡✨');
        break;
      case 'YARN_BALL':
        _playAction('PLAY_YARN');
        SoundService.playPop();
        _showDialogueBubble('追到粉红毛线球啦！两只爪爪抱住滚来滚去~ 🧶🐾');
        break;
      case 'SUNBEAM_PATCH':
        _playAction('DOZE_OFF');
        widget.petModel.addIntimacy(2);
        _spawnParticles(Offset(_petX, _petY - 20), emoji: '☀️', count: 4);
        _spawnTextParticle(Offset(_petX - 35, _petY - 55), '暖洋洋晒肚皮 ☀️', const Color(0xFFF59E0B));
        _showDialogueBubble('阳光晒得背上暖烘烘的~ 伸直小爪子晒肚皮打个盹！☀️🐾');
        break;
      case 'COZY_NEST':
      default:
        _playAction('SIT_WAG_TAIL');
        _showDialogueBubble('回到蓬松温暖的专属大猫窝啦！舒服趴好摇尾巴~ ☁️🐾');
        SoundService.playMeow();
        break;
    }
  }

  /// 优雅的半屏 BottomSheet 唤起，顶部半屏留空小猫互动演出
  void _showBottomSheetModal(Widget sheet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (ctx) => sheet,
    );
  }

  /// 打开波可的奇妙背包上拉抽屉
  void _openBackpackDrawer(bool isNight) {
    _idleSeconds = 0;
    _isRoaming = false;
    _targetWalkX = null;
    SoundService.playClick();
    if (widget.petModel.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _showBottomSheetModal(
      PokoBackpackDrawer(
        model: widget.petModel,
        isNight: isNight,
        memoCount: widget.memoModel.content.trim().isNotEmpty ? 1 : 0,
        onFeedTap: () {
          _showBottomSheetModal(
            FeedingDialog(
              model: widget.petModel,
              onFeedSelected: (foodId) {
                final food = PetModel.foodMenu.firstWhere(
                  (f) => f['id'] == foodId,
                  orElse: () => PetModel.foodMenu.first,
                );
                final foodIcon = food['icon'] as String;
                final foodName = food['name'] as String;
                final hungerGain = (food['hunger'] as double).toInt();
                final expGain = (food['exp'] as double).toInt();

                widget.petModel.feed(foodId);
                if (widget.petModel.enableHaptics) {
                  HapticFeedback.mediumImpact();
                }

                // 触发进食咀嚼动画
                _playAction('EATING');

                // 飞出食物与属性增加飘字
                _spawnParticles(Offset(_petX, _petY - 25), emoji: foodIcon, count: 5);
                _spawnTextParticle(Offset(_petX - 35, _petY - 55), '+$hungerGain 饱腹 ❤️', const Color(0xFFF59E0B));
                _spawnTextParticle(Offset(_petX + 25, _petY - 75), '+$expGain 经验 ✨', const Color(0xFF6366F1));

                _showDialogueBubble('哇！$foodName 太美味啦~ 肚子饱饱的，好幸福！(๑´ڡ`๑)', duration: const Duration(seconds: 4));
              },
            ),
          );
        },
        onLaserTap: _startLaserChase,
        onTeaseTap: _teasePlay,
        onMemoTap: () {
          _showBottomSheetModal(
            MemoScreen(memoModel: widget.memoModel),
          );
        },
        onBathTap: () {
          widget.petModel.wash();
          _spawnParticles(Offset(_petX, _petY - 20), emoji: '🫧', count: 5);
          _showDialogueBubble('洗香香啦！浑身散发着草莓沐浴露的香气~ 🫧✨');
        },
        onSleepTap: () {
          _isRoaming = false;
          _targetWalkX = null;
          final isSleep = widget.petModel.toggleSleep();
          if (isSleep) {
            SoundService.startPurr();
            _showDialogueBubble('呼噜呼噜... 进入甜甜的梦乡啦，嘘~ 💤');
          } else {
            SoundService.stopPurr();
            SoundService.playMeow();
            _showDialogueBubble('睡饱醒来啦！元气活力充沛~ ☀️');
          }
        },
        onToggleFloating: () {
          _handleFloatingTap();
        },
      ),
    );
  }

  /// 趣味交互：开启神奇指尖激光笔
  void _startLaserChase() {
    _idleSeconds = 0;
    _stopRoaming();
    _isChasingYarn = false;
    _isYarnFlying = false;
    SoundService.playMeow();
    final screenSize = MediaQuery.of(context).size;
    setState(() {
      _isLaserMode = true;
      _isWardrobeMode = false;
      _isActionMode = false;
      _laserPos = Offset(screenSize.width * 0.35, screenSize.height * 0.44);
      _state = 'IDLE';
    });
    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    _showDialogueBubble('神奇激光笔启动！在屏幕任意位置滑动指尖，看波可疯狂追扑~ 🔴🐾', duration: const Duration(seconds: 4));
  }

  /// 退出激光笔逗猫模式
  void _stopLaserChase() {
    setState(() {
      _isLaserMode = false;
      _laserPos = null;
    });
    _showDialogueBubble('收好激光笔啦！波可抓得超尽兴~ 🐾✨');
  }

  /// 天象互动：夜空月亮轻触 (流星许愿)
  void _onMoonTap() {
    if (widget.petModel.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _spawnParticles(Offset(_petX - 30, _petY - 60), emoji: '🌠', count: 2);
    _spawnParticles(Offset(_petX + 30, _petY - 80), emoji: '⭐', count: 4);
    _spawnTextParticle(Offset(_petX - 30, _petY - 95), '流星许愿 +10 ⭐', const Color(0xFFFDE047));
    widget.petModel.addExp(10.0);
    _showDialogueBubble('哇！流星划过静谧星空啦~ 愿主人的愿望全部实现！⭐✨', duration: const Duration(seconds: 4));
  }

  /// 天象互动：白天晴空轻触 (微风甘露)
  void _onSunTap() {
    if (widget.petModel.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _spawnParticles(Offset(_petX - 60, _petY - 60), emoji: '🌈', count: 3);
    _spawnTextParticle(Offset(_petX - 25, _petY - 95), '晴空温煦 +10 ☀️', const Color(0xFFF59E0B));
    widget.petModel.addExp(10.0);
    _showDialogueBubble('微风拂过晴空，有波可陪伴的每一天都是大晴天~ ☀️🌈', duration: const Duration(seconds: 4));
  }

  /// 趣味交互：遮眼躲猫猫 (Peek-a-boo 藏头露尾) 开始
  void _startPeekABoo() {
    _idleSeconds = 0;
    _isRoaming = false;
    _targetWalkX = null;
    SoundService.playMeow();
    if (widget.petModel.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _state = 'PEEK_A_BOO';
    });
    _spawnParticles(Offset(_petX, _petY - 30), emoji: '🙈', count: 3);
    _showDialogueBubble('看不见啦看不见啦~ 猜猜波可在哪里？(>_<)🙈', duration: const Duration(seconds: 4));
  }

  /// 趣味交互：遮眼躲猫猫 抬手惊喜发现
  void _finishPeekABoo() {
    _idleSeconds = 0;
    _isRoaming = false;
    _targetWalkX = null;
    SoundService.playMeow();
    if (widget.petModel.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _squishController.forward(from: 0.0);
    setState(() {
      _state = 'HAPPY_SPIN';
    });
    _spawnParticles(Offset(_petX, _petY - 30), emoji: '🎉', count: 4);
    _spawnParticles(Offset(_petX, _petY - 30), emoji: '💖', count: 4);
    _spawnTextParticle(Offset(_petX - 35, _petY - 65), '躲猫猫大成功！✨', const Color(0xFFEC4899));
    _showDialogueBubble('哈哈！发现主人啦！扑个大满怀~ 喵呜！(✧ω✧)💕', duration: const Duration(seconds: 4));
    Timer(const Duration(milliseconds: 3200), () {
      if (mounted && _state == 'HAPPY_SPIN') {
        setState(() => _state = 'IDLE');
      }
    });
  }

  /// 家具交互：猫草轻摇 (清香飘逸，猫咪开心)
  void _onPlantTap() {
    _idleSeconds = 0;
    if (widget.petModel.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _plantAnimTimer?.cancel();
    setState(() => _plantTilt = 0.14);
    _plantAnimTimer = Timer(const Duration(milliseconds: 240), () {
      if (mounted) {
        setState(() => _plantTilt = -0.08);
        _plantAnimTimer = Timer(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _plantTilt = 0.0);
        });
      }
    });

    _spawnParticles(Offset(_petX - 80, _petY - 20), emoji: '🌿', count: 3);
    _spawnParticles(Offset(_petX - 60, _petY - 30), emoji: '🌱', count: 2);
    _spawnTextParticle(Offset(_petX - 85, _petY - 50), '猫草清香 +5 🌱', const Color(0xFF10B981));
    widget.petModel.addExp(5.0);
    SoundService.playMeow();
    _showDialogueBubble('猫草清香扑鼻~ 波可闻到了开心咬了一小口！🌱😋', duration: const Duration(seconds: 4));
  }

  /// 家具交互：原木剑麻猫抓柱磨爪 (真实解压利爪抓挠撕扯沙沙声 + 弹性震颤 + 真实木屑火花 + 猫咪惬意互动)
  void _onScratcherTap() {
    _idleSeconds = 0;
    SoundService.playScratch();
    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
      Timer(const Duration(milliseconds: 100), () {
        HapticFeedback.heavyImpact();
        Timer(const Duration(milliseconds: 120), () {
          HapticFeedback.lightImpact();
        });
      });
    }

    // 猫抓柱多段高频弹性减震物理反馈 (模拟真实剑麻受力回弹)
    _postAnimTimer?.cancel();
    setState(() => _postWiggle = 6.0);
    _postAnimTimer = Timer(const Duration(milliseconds: 60), () {
      if (mounted) {
        setState(() => _postWiggle = -5.0);
        _postAnimTimer = Timer(const Duration(milliseconds: 70), () {
          if (mounted) {
            setState(() => _postWiggle = 3.5);
            _postAnimTimer = Timer(const Duration(milliseconds: 80), () {
              if (mounted) {
                setState(() => _postWiggle = -1.5);
                _postAnimTimer = Timer(const Duration(milliseconds: 80), () {
                  if (mounted) setState(() => _postWiggle = 0.0);
                });
              }
            });
          }
        });
      }
    });

    // 精准定位在右上角猫抓柱真实几何中心
    final floorTop = (_lastScreenSize.height * 0.28).clamp(195.0, 245.0);
    final postCenterX = _lastScreenSize.width - 24.0 - 24.0;
    final postCenterY = floorTop + 16.0 + 26.0;

    _spawnParticles(Offset(postCenterX, postCenterY - 10), emoji: '🪵', count: 3);
    _spawnParticles(Offset(postCenterX - 10, postCenterY), emoji: '✨', count: 3);
    _spawnParticles(Offset(postCenterX + 5, postCenterY - 15), emoji: '🐾', count: 2);
    _spawnTextParticle(Offset(postCenterX - 50, postCenterY - 35), '磨爪爪解压 +5 🐾', const Color(0xFFF59E0B));
    widget.petModel.addExp(5.0);

    // 猫咪动态响应：面朝右侧猫抓柱，伸展利爪微动作，并在磨完后满足地发出软萌耳语喵
    if (!_isDragging) {
      setState(() {
        _facingLeft = false;
        _twitchEar = 'RIGHT';
      });
      _earTwitchTimer?.cancel();
      _earTwitchTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _twitchEar = null);
      });

      // 若处于空闲或坐卧，萌宠伸展腰肢磨爪互动
      _actionTimer?.cancel();
      if (_state == 'IDLE' || _state == 'SIT_WAG_TAIL') {
        setState(() {
          _state = 'STRETCH_YAWN';
        });
        _actionTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted && _state == 'STRETCH_YAWN') {
            setState(() => _state = 'IDLE');
          }
        });
      }

      // 磨完爪子后小猫发出满足温润的软喵
      _scratcherMeowTimer?.cancel();
      _scratcherMeowTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted && SoundService.soundEnabled) {
          SoundService.playMeow(tone: MeowTone.soft);
        }
      });
    }

    final scratcherLines = [
      '磨磨爪子~ 抓板真结实，指甲尖尖亮晶晶！(ฅ>ω<*ฅ)🪵',
      '磨磨利爪~ 剑麻柱沙沙响，指甲尖尖超锋利！(ฅ>ω<*ฅ)🪵',
      '抓板太解压啦！伸长腰肢舒舒服服磨个痛快~ 🐾✨',
      '咔嚓咔嚓~ 爪尖磨得亮晶晶，波可浑身充满干劲！(✧ω✧)🪵',
    ];
    final line = scratcherLines[math.Random().nextInt(scratcherLines.length)];
    _showDialogueBubble(line, duration: const Duration(seconds: 4));
  }

  /// 家具交互：开关萌猫小夜灯 (温润呼吸暖光)
  void _onNightLampTap() {
    _idleSeconds = 0;
    SoundService.playClick();
    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _isNightLampOn = !_isNightLampOn;
    });

    if (_isNightLampOn) {
      _spawnParticles(Offset(_petX + 50, _petY), emoji: '💡', count: 3);
      _spawnParticles(Offset(_petX + 55, _petY - 20), emoji: '✨', count: 3);
      _spawnTextParticle(Offset(_petX + 35, _petY - 35), '暖光微亮 💡', const Color(0xFFFBBF24));
      _showDialogueBubble('啪嗒~ 暖光小夜灯点亮啦，守护波可的香甜美梦 💡', duration: const Duration(seconds: 4));
    } else {
      _spawnParticles(Offset(_petX + 50, _petY), emoji: '💤', count: 2);
      _spawnTextParticle(Offset(_petX + 35, _petY - 35), '小夜灯已熄灭 🌙', const Color(0xFF94A3B8));
      _showDialogueBubble('啪嗒~ 小夜灯熄灭啦，晚安好梦~ 🌙', duration: const Duration(seconds: 3));
    }
  }

  /// 家具交互：点按标签切换房间治愈 ASMR 白噪音 (雨声 / 猫咪深度打呼噜 / 关闭)
  Future<void> _cycleAmbientSound() async {
    _idleSeconds = 0;
    if (widget.petModel.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    final mode = await SoundService.cycleAmbientSound();
    setState(() {});

    if (mode == 'rain') {
      _spawnParticles(Offset(_petX + 50, _petY - 20), emoji: '🌧️', count: 4);
      _spawnTextParticle(Offset(_petX + 20, _petY - 45), '沥沥细雨 ASMR 🌧️', const Color(0xFF38BDF8));
      _showDialogueBubble('🌧️ 已开启窗外细雨白噪音，温柔雨声伴您进入深度专注心流~', duration: const Duration(seconds: 4));
    } else if (mode == 'purr') {
      _spawnParticles(Offset(_petX + 50, _petY - 20), emoji: '🐱', count: 4);
      _spawnTextParticle(Offset(_petX + 20, _petY - 45), '深度呼噜助眠 🐱', const Color(0xFFA855F7));
      _showDialogueBubble('🐱 已开启波可深度呼噜助眠 ASMR，纯净低频共鸣超级解压安神~', duration: const Duration(seconds: 4));
    } else {
      _spawnParticles(Offset(_petX + 50, _petY - 20), emoji: '💡', count: 3);
      _spawnTextParticle(Offset(_petX + 20, _petY - 45), '宁静房间 💡', const Color(0xFFFBBF24));
      _showDialogueBubble('💡 已关闭环境白噪音，房间回归温馨安宁~', duration: const Duration(seconds: 3));
    }
  }

  /// 墙面装饰：拍立得照片墙摇晃并展开时光手账与纪念相册
  void _onPhotoTap() {
    _idleSeconds = 0;
    SoundService.playShutter();
    if (widget.petModel.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _photoAnimTimer?.cancel();
    setState(() => _photoAngle = 0.10);
    _photoAnimTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted) {
        setState(() => _photoAngle = -0.12);
        _photoAnimTimer = Timer(const Duration(milliseconds: 260), () {
          if (mounted) setState(() => _photoAngle = -0.06);
        });
      }
    });

    _spawnParticles(const Offset(45, 135), emoji: '💕', count: 3);
    _spawnParticles(const Offset(40, 115), emoji: '📸', count: 2);
    _spawnTextParticle(const Offset(20, 105), '珍藏回忆 💕', const Color(0xFFEC4899));
    _showDialogueBubble('相框里是初遇那天拍的纪念照~ 正在翻开波可的专属时光手账！🥰📷', duration: const Duration(seconds: 4));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MemoryAlbumDialog(model: widget.petModel),
    );
  }

  /// 家具交互：轻触云朵暖暖窝 (波可舒适归窝，享受幸福踩奶特技与呼噜 ASMR)
  void _onBedTap(double nestX, double nestY) {
    _idleSeconds = 0;
    _stopRoaming();
    _isChasingYarn = false;
    _isYarnFlying = false;

    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }

    // 萌宠回归暖绒圆垫中心位置
    setState(() {
      _petX = nestX;
      _petY = nestY;
      _facingLeft = false;
      _state = 'KNEADING_BISCUITS';
    });

    // 播放连续真实打呼噜声与轻柔耳语
    SoundService.startPurr();
    _spawnParticles(Offset(nestX - 25, nestY - 20), emoji: '🥐', count: 3);
    _spawnParticles(Offset(nestX + 25, nestY - 25), emoji: '🐾', count: 3);
    _spawnParticles(Offset(nestX, nestY - 40), emoji: '💕', count: 4);
    _spawnTextParticle(Offset(nestX - 45, nestY - 60), '幸福踩奶 +10 🥐', const Color(0xFFF59E0B));
    widget.petModel.addExp(10.0);

    // 踩奶节奏细微触感
    _purrHapticTimer?.cancel();
    int kneadTick = 0;
    if (widget.petModel.enableHaptics) {
      _purrHapticTimer = Timer.periodic(const Duration(milliseconds: 200), (t) {
        if (kneadTick++ >= 12 || _state != 'KNEADING_BISCUITS') {
          t.cancel();
        } else {
          HapticFeedback.selectionClick();
        }
      });
    }

    _actionTimer?.cancel();
    _actionTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted && _state == 'KNEADING_BISCUITS') {
        SoundService.stopPurr();
        SoundService.playMeow(tone: MeowTone.soft);
        setState(() => _state = 'SIT_WAG_TAIL');
      }
    });

    final bedQuotes = [
      '呼噜噜~ 波可正在软软云朵垫上认真踩奶做小面包呢！(ฅ˘ω˘ฅ)🥐💕',
      '暖绒圆垫软乎乎暖洋洋的，肉垫陷在里面踩得好过瘾~ ☁️🐾',
      '小脚丫左一下、右一下~ 踩出全世界最甜的奶香小面包！🥐✨',
    ];
    final quote = bedQuotes[math.Random().nextInt(bedQuotes.length)];
    _showDialogueBubble(quote, duration: const Duration(seconds: 4));
  }

  /// 屏幕全域动态视线与手指追踪
  void _onPointerHoverOrMove(Offset globalPos) {
    if (_isDragging) return;
    final relX = globalPos.dx - _petX;
    final relY = globalPos.dy - _petY;
    if (relX.abs() < 340 && relY.abs() < 340) {
      if (_lookTargetPos == null || (_lookTargetPos!.dx - relX).abs() > 3 || (_lookTargetPos!.dy - relY).abs() > 3) {
        setState(() {
          _lookTargetPos = Offset(relX, relY);
          if (relX < -50 && !_facingLeft && _state == 'IDLE') {
            _facingLeft = true;
          } else if (relX > 50 && _facingLeft && _state == 'IDLE') {
            _facingLeft = false;
          }
        });
      }
    }
  }

  void _onPointerUpOrExit() {
    if (_lookTargetPos != null) {
      setState(() => _lookTargetPos = null);
    }
  }

  /// 墙面装饰：温暖小串灯轻触 (一闪一闪亮晶晶)
  void _onFairyLightsTap() {
    _idleSeconds = 0;
    SoundService.playClick();
    if (widget.petModel.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _spawnParticles(Offset(_petX - 40, 85), emoji: '✨', count: 3);
    _spawnParticles(Offset(_petX + 40, 85), emoji: '🌟', count: 3);
    _showDialogueBubble('暖黄小串灯一闪一闪的，小窝变得好温馨呀~ ✨💡', duration: const Duration(seconds: 4));
  }

  /// 重置萌宠回到专属暖绒圆垫
  void _resetToMat(Size screenSize) {
    _idleSeconds = 0;
    _stopRoaming();
    SoundService.playMeow();
    final floorTop = (screenSize.height * 0.28).clamp(195.0, 245.0);
    final nestX = screenSize.width / 2;
    final nestY = floorTop + 130.0;
    setState(() {
      _petX = nestX;
      _petY = nestY;
      _yarnX = screenSize.width * 0.5;
      _yarnY = nestY + 155.0;
      _isYarnFlying = false;
      _isChasingYarn = false;
      _yarnVx = 0.0;
      _yarnVy = 0.0;
      _state = 'IDLE';
    });
    _showDialogueBubble('回到蓬松温暖的专属暖绒垫啦！舒服趴好~ 🐾☁️');
    if (widget.petModel.enableHaptics) {
      HapticFeedback.selectionClick();
    }
  }

  /// 真实昼夜光影与陪伴生活作息
  Map<String, dynamic> _getCircadianTheme() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) {
      return {
        'name': '清晨晨光',
        'icon': '☀️',
        'colors': const [Color(0xFFFFFBEB), Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
        'isNight': false,
        'greeting': '早安主人！今天也要元气满满哦，波可陪着您~ ☀️🐾',
      };
    } else if (hour >= 11 && hour < 17) {
      return {
        'name': '午后晴空',
        'icon': '⛅',
        'colors': const [Color(0xFFE0F2FE), Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
        'isNight': false,
        'greeting': '午后微风轻拂，适合在软垫上伸懒腰打个小盹~ ☕✨',
      };
    } else if (hour >= 17 && hour < 20) {
      return {
        'name': '日落晚霞',
        'icon': '🌇',
        'colors': const [Color(0xFFFFF1F2), Color(0xFFFEF3C7), Color(0xFFF3E8FF)],
        'isNight': false,
        'greeting': '夕阳染上金边啦，主人今天辛苦啦，欢迎回家！🌇💕',
      };
    } else {
      return {
        'name': '静谧星夜',
        'icon': '🌙',
        'colors': const [
          Color(0xFF0F0E26), // 暮夜深紫星空
          Color(0xFF18153E), // 梦幻星夜靛蓝
          Color(0xFF221A48), // 暖调午夜微光
        ],
        'isNight': true,
        'greeting': '夜深啦，小星星都眨眼了，主人早点休息哦，波可守着您~ 💤🌙',
      };
    }
  }

  /// 踩出地板温润小猫肉垫爪印
  void _maybeAddFootprint(Offset currentPos) {
    if (!widget.petModel.enableFootprints) return;
    if (_lastFootprintPos == null) {
      _lastFootprintPos = currentPos;
      return;
    }
    final diff = currentPos - _lastFootprintPos!;
    final dist = diff.distance;
    // 真实猫咪步幅节奏：间距 34px，告别密集紧凑假印
    if (dist >= 34.0) {
      _lastFootprintPos = currentPos;
      _footprintLeft = !_footprintLeft;

      // 运动朝向角
      final angle = math.atan2(diff.dy, diff.dx) + math.pi / 2;

      // 左右两脚横向交替自然步宽 (±7px)
      final perp = Offset(-diff.dy, diff.dx) / dist;
      final lateral = perp * (_footprintLeft ? -7.0 : 7.0);

      // 脚印精准落点：猫咪双前爪着地接触面 (+58px)
      final footPos = currentPos + const Offset(0, 58.0) + lateral;
      _footprints.add(_Footprint(
        position: footPos,
        angle: angle,
        isLeft: _footprintLeft,
        opacity: 0.45,
      ));
      // 保持地板洁净纯粹：最多仅保留最近 8 处轻微爪印
      if (_footprints.length > 8) {
        _footprints.removeAt(0);
      }
    }
  }

  /// 揪尾巴炸毛微互动：触发触电惊跳、高频电波甩尾、微嗔短叫与俏皮台词
  void _triggerTailBoop() {
    _idleSeconds = 0;
    _stopRoaming();
    SoundService.playMeow(tone: MeowTone.short);
    if (widget.petModel.enableHaptics) {
      HapticFeedback.heavyImpact();
      Timer(const Duration(milliseconds: 120), () {
        HapticFeedback.lightImpact();
      });
    }
    _squishController.forward(from: 0.0);
    setState(() {
      _isTailPuffed = true;
      _isAirplaneEars = true;
    });
    _tailPuffTimer?.cancel();
    _tailPuffTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _isTailPuffed = false);
    });
    _airplaneEarsTimer?.cancel();
    _airplaneEarsTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _isAirplaneEars = false);
    });

    final tailParticleX = _petX + (_facingLeft ? -45.0 : 45.0);
    _spawnParticles(Offset(tailParticleX, _petY + 10), emoji: '⚡', count: 2);
    _spawnParticles(Offset(tailParticleX, _petY), emoji: '💢', count: 3);
    _spawnParticles(Offset(tailParticleX, _petY - 15), emoji: '💨', count: 2);

    final tailQuotes = [
      '喵呜？！谁在偷抓波可的尾巴！尾巴是敏感禁区喵~ 😾💢',
      '哈！尾巴炸毛啦！不许偷偷拉小猫咪的天线！⚡(>﹏<)',
      '喵呜呜~ 尾巴尖尖被碰到了，浑身电波噼里啪啦！💨⚡',
      '尾巴防御系统启动！波可要哈气啦~ 哼！😾🐾',
    ];
    _showDialogueBubble(tailQuotes[math.Random().nextInt(tailQuotes.length)], duration: const Duration(seconds: 4));
  }

  /// 维度一：部位差异化触感与猫咪打呼噜反应
  void _handleBodyPartTouch(Offset localPos, Size screenSize) {
    _idleSeconds = 0;
    _isRoaming = false;
    _targetWalkX = null;

    // 0. 揪尾巴炸毛微互动 (Tail Boop / Pinch - 尾巴敏感禁区惊跳炸毛与高频电波甩尾)
    final isTailTouch = (!_facingLeft && localPos.dx >= 135 && localPos.dx <= 192 && localPos.dy >= 55 && localPos.dy <= 135) ||
                        (_facingLeft && localPos.dx >= 8 && localPos.dx <= 65 && localPos.dy >= 55 && localPos.dy <= 135);
    if (isTailTouch) {
      _triggerTailBoop();
      return;
    }

    // 0.1 戳呆萌小舌头 (Blep Boop - 戳收回小舌头)
    if (_isBlep && (localPos.dx - 100).abs() < 16 && (localPos.dy - 104).abs() < 14) {
      SoundService.playPop();
      if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
      setState(() => _isBlep = false);
      _spawnParticles(Offset(_petX, _petY - 20), emoji: '👅', count: 3);
      _spawnTextParticle(Offset(_petX - 35, _petY - 45), '收回小舌头~ (ฅ^ω^ฅ)', const Color(0xFFF43F5E));
      _showDialogueBubble('呀！被主人戳到小舌头啦，哧溜缩回来！👅✨');
      return;
    }

    // 1. 点粉嫩小鼻子 (Nose Boop - 触发短促清脆小猫打喷嚏回应喵)
    if ((localPos.dx - 100).abs() < 14 && (localPos.dy - 93).abs() < 10) {
      SoundService.playMeow(tone: MeowTone.short);
      if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
      _squishController.forward(from: 0.0);
      _spawnParticles(Offset(_petX, _petY - 25), emoji: '🤧', count: 3);
      _showDialogueBubble('阿嚏！(>﹏<) 戳到波可敏感的小鼻尖啦~ 🐾', duration: const Duration(seconds: 4));
      return;
    }

    // 2. 挠下巴 / 颈窝 (Chin Scratch - 触发猫咪打呼噜连续细密震动与真实ASMR喉音起伏)
    if ((localPos.dx - 100).abs() < 24 && (localPos.dy >= 99 && localPos.dy <= 122)) {
      setState(() {
        _isPurring = true;
      });
      SoundService.startPurr();
      _purrHapticTimer?.cancel();
      int purrTick = 0;
      if (widget.petModel.enableHaptics) {
        _purrHapticTimer = Timer.periodic(const Duration(milliseconds: 130), (t) {
          if (purrTick++ >= 9 || !_isPurring) {
            t.cancel();
          } else {
            HapticFeedback.selectionClick();
            _spawnParticles(Offset(_petX + (purrTick.isEven ? -18 : 18), _petY - 24), emoji: '🫧', count: 1);
          }
        });
      }
      _purrTimer?.cancel();
      _purrTimer = Timer(const Duration(milliseconds: 2600), () {
        SoundService.stopPurr();
        if (mounted) {
          setState(() => _isPurring = false);
          _triggerSlowBlink();
        }
      });
      widget.petModel.petHead();
      _spawnParticles(Offset(_petX, _petY - 30), emoji: '💕', count: 5);
      _showDialogueBubble('咕噜咕噜... 下巴挠得好舒服，要融化在主人手心啦~ (˘ω˘)💕', duration: const Duration(seconds: 4));
      return;
    }

    // 3. 触摸左耳 (俏皮机敏轻短喵)
    if (localPos.dx >= 45 && localPos.dx <= 88 && localPos.dy >= 18 && localPos.dy <= 62) {
      SoundService.playMeow(tone: MeowTone.short);
      if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
      setState(() {
        _twitchEar = 'LEFT';
      });
      _earTwitchTimer?.cancel();
      _earTwitchTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _twitchEar = null);
      });
      _spawnParticles(Offset(_petX - 35, _petY - 50), emoji: '👂', count: 2);
      _showDialogueBubble('左耳朵机灵抖抖~ 听到主人的心声啦！👂✨');
      return;
    }

    // 4. 触摸右耳 (俏皮机敏轻短喵)
    if (localPos.dx >= 112 && localPos.dx <= 155 && localPos.dy >= 18 && localPos.dy <= 62) {
      SoundService.playMeow(tone: MeowTone.short);
      if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
      setState(() {
        _twitchEar = 'RIGHT';
      });
      _earTwitchTimer?.cancel();
      _earTwitchTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _twitchEar = null);
      });
      _spawnParticles(Offset(_petX + 35, _petY - 50), emoji: '👂', count: 2);
      _showDialogueBubble('右耳朵抖一抖~ 喵呜！右侧雷达收到！👂🐾');
      return;
    }

    // 5. 捏两腮包子脸 (Cheek Pinch - 软糯亲昵耳语喵)
    final isLeftCheek = (localPos.dx >= 52 && localPos.dx <= 84 && localPos.dy >= 70 && localPos.dy <= 104);
    final isRightCheek = (localPos.dx >= 116 && localPos.dx <= 148 && localPos.dy >= 70 && localPos.dy <= 104);
    if (isLeftCheek || isRightCheek) {
      SoundService.playMeow(tone: MeowTone.soft);
      if (widget.petModel.enableHaptics) {
        HapticFeedback.lightImpact();
      }
      _squishController.forward(from: 0.0);
      _spawnParticles(Offset(_petX, _petY - 20), emoji: '🫧', count: 3);
      _showDialogueBubble('唔姆~ 脸颊肉肉要被主人捏圆啦！(ฅ\'ω\'ฅ)', duration: const Duration(seconds: 4));
      return;
    }

    // 6. 摸肉垫 / 肚皮 (High Five / Tummy Poke)
    if (localPos.dy > 120) {
      final floorTop = (screenSize.height * 0.28).clamp(195.0, 245.0);
      final nestX = screenSize.width / 2;
      final nestY = floorTop + 130.0;
      if ((_petX - nestX).abs() < 25 && (_petY - nestY).abs() < 25) {
        _onBedTap(nestX, nestY);
        return;
      }
      SoundService.playPop();
      if (widget.petModel.enableHaptics) HapticFeedback.mediumImpact();
      _spawnParticles(Offset(_petX, _petY - 10), emoji: '🐾', count: 4);
      _showDialogueBubble('击掌！High Five~ 击退一切烦恼！🐾⭐');
      return;
    }

    // 7. 头部一般触碰
    _onPetTap(Offset(_petX, _petY));
  }

  /// 方向一：慢眨眼“猫咪之吻” (Slow Blink - 表达爱意与极致信任)
  void _triggerSlowBlink() {
    if (!mounted || _isSlowBlink || _state != 'IDLE') return;
    setState(() => _isSlowBlink = true);
    SoundService.playMeow(tone: MeowTone.soft);
    if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
    _spawnParticles(Offset(_petX, _petY - 35), emoji: '💖', count: 3);
    _spawnTextParticle(Offset(_petX - 35, _petY - 60), '猫咪之吻 🐾💕', const Color(0xFFF43F5E));
    widget.petModel.addIntimacy(3);
    _showDialogueBubble('波可正在对主人慢眨眼哦~ 在小猫的世界里，这是表达最深爱意与信任的‘猫咪之吻’呢！(˘ω˘)💕', duration: const Duration(seconds: 4));

    _slowBlinkTimer?.cancel();
    _slowBlinkTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _isSlowBlink = false);
    });
  }

  /// 方向一：呆萌吐小舌头 (Blep)
  void _triggerBlep({Duration duration = const Duration(milliseconds: 2200)}) {
    if (!mounted) return;
    setState(() => _isBlep = true);
    Timer(duration, () {
      if (mounted) setState(() => _isBlep = false);
    });
  }

  /// 维度五：跑过来贴贴屏幕 (Glass Boop)
  void _triggerGlassBoop(Size screenSize) {
    if (!mounted || _state == 'GLASS_BOOP' || _isDragging) return;
    _isRoaming = false;
    _targetWalkX = null;
    SoundService.playMeow();
    setState(() {
      _state = 'GLASS_BOOP';
      _hasGlassPawPrints = true;
      _pawPrints = [
        Offset(_petX - 38, _petY + 22),
        Offset(_petX + 38, _petY + 22),
      ];
    });
    if (widget.petModel.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    _showDialogueBubble('波可跑来贴贴屏幕啦！主人也在看波可嘛？(ฅ\'ω\'ฅ)💕', duration: const Duration(seconds: 4));

    _boopTimer?.cancel();
    _boopTimer = Timer(const Duration(milliseconds: 3800), () {
      if (mounted && _state == 'GLASS_BOOP') {
        setState(() {
          _state = 'IDLE';
        });
      }
    });
  }

  /// 维度二：从小鱼碗弹射小鲜鱼
  void _popFishFromBowl(double nestX, double nestY) {
    if (_fishPopping) return;
    SoundService.playPop();
    setState(() {
      _fishPopping = true;
      _poppingFishPos = Offset(42.0, nestY + 115.0);
    });
    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
  }

  /// 逗趣与毛线球主动抛掷
  void _teasePlay() {
    _idleSeconds = 0;
    _isRoaming = false;
    _targetWalkX = null;
    SoundService.playPop();
    setState(() {
      _isYarnFlying = true;
      _yarnVx = (math.Random().nextBool() ? 9.0 : -9.0);
      _yarnVy = -11.0;
    });
    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    _showDialogueBubble('逗猫时间到！毛线球飞起来啦，波可快去追~ 🧶💨', duration: const Duration(seconds: 4));
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    _lastScreenSize = screenSize;

    // 房间空间黄金分割：
    // 踢脚线与地板起始位置：在上方约 22%，给宽敞木地板留足 78% 空间
    final floorTop = (screenSize.height * 0.28).clamp(195.0, 245.0);
    // 房间核心重心：萌宠专属暖绒圆垫位于中景焦点黄金位置
    final nestX = screenSize.width / 2;
    final nestY = floorTop + 130.0;

    // 首次进入时，萌宠舒适安卧于暖绒圆垫中心
    if (!_initializedPos && screenSize.width > 0) {
      _petX = nestX;
      _petY = nestY;
      _initializedPos = true;
    }

    // 萌宠允许移动的上下安全边界
    const minSafeY = 130.0;
    final maxSafeY = screenSize.height - 120.0;

    // 维度四：昼夜光影与氛围主题
    final circadian = _getCircadianTheme();
    final gradientColors = circadian['colors'] as List<Color>;
    final isNight = circadian['isNight'] as bool;
    final ambientIcon = circadian['icon'] as String;

    // 维度二：毛线球位于前侧宽敞开阔地板上
    if (!_yarnInitialized && screenSize.width > 0) {
      _yarnX = screenSize.width * 0.5;
      _yarnY = nestY + 155.0;
      _yarnInitialized = true;
    }

    return Scaffold(
      body: Listener(
        onPointerHover: (event) => _onPointerHoverOrMove(event.position),
        onPointerMove: (event) => _onPointerHoverOrMove(event.position),
        onPointerUp: (_) => _onPointerUpOrExit(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
          ),
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 助眠专注氛围：细雨微动粒子 (Rain ASMR Active)
                if (SoundService.ambientMode == 'rain') ...[
                  for (int i = 0; i < 14; i++)
                    Positioned(
                      left: ((i * 27.0 + _idleAnimController.value * 350.0) % screenSize.width),
                      top: ((i * 59.0 + _idleAnimController.value * 650.0) % screenSize.height),
                      child: IgnorePointer(
                        child: Container(
                          width: 1.5,
                          height: 12.0,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                ],
                // 0. 维度四：背景微光氛围天象 (清晨/正午/日落/星夜，支持点击天象交互彩蛋)
                if (isNight) ...[
                // 月亮：轻触触发流星雨与许愿彩蛋
                Positioned(
                  top: 56,
                  right: 22,
                  child: GestureDetector(
                    onTap: _onMoonTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Text(
                        '🌙',
                        style: TextStyle(
                          fontSize: 36,
                          shadows: [
                            Shadow(
                              color: const Color(0xFFFDE047).withOpacity(0.6),
                              blurRadius: 18,
                            ),
                            Shadow(
                              color: const Color(0xFFF59E0B).withOpacity(0.3),
                              blurRadius: 28,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // 漫天静谧微星 (支持轻触交互，飘出星光)
                Positioned(
                  top: 85,
                  left: 28,
                  child: GestureDetector(
                    onTap: _onMoonTap,
                    child: Text('✨', style: TextStyle(fontSize: 16, color: const Color(0xFFFDE047).withOpacity(0.7))),
                  ),
                ),
                Positioned(
                  top: 150,
                  right: 70,
                  child: GestureDetector(
                    onTap: _onMoonTap,
                    child: Text('⭐', style: TextStyle(fontSize: 13, color: Colors.amber.shade100.withOpacity(0.6))),
                  ),
                ),
                Positioned(
                  top: 205,
                  left: 50,
                  child: GestureDetector(
                    onTap: _onMoonTap,
                    child: Text('✨', style: TextStyle(fontSize: 14, color: Colors.yellow.shade100.withOpacity(0.5))),
                  ),
                ),
                Positioned(
                  top: 170,
                  left: 110,
                  child: GestureDetector(
                    onTap: _onMoonTap,
                    child: Text('⭐', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
                  ),
                ),
              ] else ...[
                // 白天环境氛围 (太阳/云朵/晚霞，轻触触发晴空微风彩蛋)
                Positioned(
                  top: 56,
                  right: 22,
                  child: GestureDetector(
                    onTap: _onSunTap,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      child: Text(ambientIcon, style: const TextStyle(fontSize: 34)),
                    ),
                  ),
                ),
                Positioned(
                  top: 115,
                  left: 24,
                  child: GestureDetector(
                    onTap: _onSunTap,
                    child: Text('☁️', style: TextStyle(fontSize: 22, color: Colors.white.withOpacity(0.6))),
                  ),
                ),
              ],

              // 0.1 房间立体景深：深长木质地台与高光踢脚线 (自 floorTop 处起铺展至底，填补大片空地)
              Positioned(
                top: floorTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: _buildCozyFlooring(isNight),
                ),
              ),

              // 0.2 墙面软装：顶部浪漫温暖小串灯 (支持轻触点亮与星光闪耀)
              Positioned(
                top: 64,
                left: 18,
                right: 18,
                child: _buildFairyLightsRow(isNight),
              ),

              // 0.3 墙面软装：左上侧拍立得纪念相框 (初遇回忆，轻触摇晃冒心心)
              Positioned(
                top: 106,
                left: 18,
                child: _buildPolaroidFrame(isNight),
              ),

              // 0.4 墙面软装：法式拱形观景窗 (4 季天象点按切换，居中对称美学)
              Positioned(
                top: 62,
                left: screenSize.width / 2 - 43,
                child: _buildFrenchArchWindow(isNight),
              ),

              // 软装家具 1：左上角 · 萌宠猫草盆栽 (靠左后侧，静立于木地板墙角)
              Positioned(
                left: 24.0,
                top: floorTop + 16.0,
                child: _buildCatGrassPlanter(isNight),
              ),

              // 软装家具 2：右上角 · 原木剑麻猫抓柱 (靠右后侧，立于木地板墙角，与猫草呼应)
              Positioned(
                right: 24.0,
                top: floorTop + 16.0,
                child: _buildCatScratchingPost(isNight),
              ),

              // 软装家具 3：左侧就餐角 · 萌宠双联食水一体托盘 (原木陶瓷质感，双碗一体化防滑托盘)
              Positioned(
                left: 20.0,
                top: nestY + 102.0,
                child: _buildCatDiningStation(nestX, nestY, isNight),
              ),

              // 美味零食投喂已移至底部悬浮投喂坞 _buildLiveFeedingDock (保持中景纯净无遮挡)

              // 维度二：飞跃弹跳的小鱼 (弧线投喂到猫咪嘴边)
              if (_fishPopping && _poppingFishPos != null)
                Positioned(
                  left: _poppingFishPos!.dx,
                  top: _poppingFishPos!.dy,
                  child: const IgnorePointer(
                    child: Text('🐟', style: TextStyle(fontSize: 22)),
                  ),
                ),

              // 软装家具 4：右侧照明角 · 温馨小夜灯呼吸光晕
              if (_isNightLampOn)
                Positioned(
                  right: 8.0,
                  top: nestY + 90.0,
                  child: IgnorePointer(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (isNight ? const Color(0xFFFDE047) : const Color(0xFFFBBF24)).withOpacity(0.38),
                            (isNight ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B)).withOpacity(0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 软装家具 4：右侧照明角 · 温馨小夜灯 (置于右侧地板，轻触“啪嗒”开关台灯)
              Positioned(
                right: 24.0,
                top: nestY + 105.0,
                child: _buildKittenNightLamp(isNight),
              ),

              // 阳光暖阳下木地板柔和光斑
              if (_windowWeather == 0 && !isNight)
                _buildSunbeamPatch(nestX, nestY, isNight),

              // 春日落樱轻盈飘落花瓣 (轻触化作粉红光尘消散)
              if (_windowWeather == 2)
                ..._buildSakuraPetals(screenSize, isNight),

              // 萌宠专属舒睡暖绒圆垫 (极简轻奢，铺展于猫咪身后地板上，猫咪坐于其上)
              _buildCatRug(nestX, nestY, isNight),

              // 地板粉嫩小猫爪印层 (2.5D 木地板巡视与冲刺追球时淡隐脚印)
              if (_footprints.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _FootprintPainter(_footprints),
                    ),
                  ),
                ),

              // 顶部双灵动岛浮空栏 (左侧萌宠身份 + 右侧饱腹心情小窝，告别拥挤，自然呼吸)
              Positioned(
                top: 10,
                left: 14,
                right: 14,
                child: _buildTopDualIslands(screenSize, isNight),
              ),

              // 3. 萌宠主窗体 (维度一：部位差异化触感与猫咪打呼噜；维度三：剧烈晃动眩晕；维度五：亲密连击与贴贴)
              Positioned(
                left: _petX - 100,
                top: _petY - 100,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _handleBodyPartTouch(details.localPosition, screenSize),
                  onTap: () {},
                  onDoubleTap: _onPetDoubleTap,
                  onLongPressStart: (_) => _startPeekABoo(),
                  onLongPressEnd: (_) => _finishPeekABoo(),
                  onPanStart: (details) {
                    setState(() {
                      _isDragging = true;
                      _stopRoaming();
                      _isChasingYarn = false;
                      _isYarnFlying = false;
                      _state = 'DRAGGING';
                      _strokeDistance = 0.0;
                      _dragDirectionReversals = 0;
                      _lastDragDirection = 0.0;
                      _lastDragTime = DateTime.now();
                    });
                  },
                  onPanUpdate: (details) {
                    final now = DateTime.now();
                    final dt = now.difference(_lastDragTime).inMilliseconds;
                    _lastDragTime = now;

                    setState(() {
                      _petX += details.delta.dx;
                      _petY += details.delta.dy;

                      // 限制萌宠不出屏幕
                      _petX = _petX.clamp(35.0, screenSize.width - 35.0);
                      _petY = _petY.clamp(minSafeY, maxSafeY);

                      _facingLeft = (details.delta.dx < -0.8);
                      _touchPos = details.localPosition;

                      // 维度三：高频剧烈左右晃动眩晕检测
                      final curDx = details.delta.dx;
                      if (curDx.abs() > 4.5 && dt < 80) {
                        final dir = curDx > 0 ? 1.0 : -1.0;
                        if (_lastDragDirection != 0.0 && dir != _lastDragDirection) {
                          _dragDirectionReversals++;
                          if (_dragDirectionReversals >= 5 && _state != 'DIZZY') {
                            _state = 'DIZZY';
                            _dragDirectionReversals = 0;
                            if (widget.petModel.enableHaptics) {
                              HapticFeedback.heavyImpact();
                            }
                            _spawnParticles(Offset(_petX, _petY - 45), emoji: '💫', count: 4);
                            _showDialogueBubble('哎呀呀~ 晃得波可晕乎乎啦，头顶都在转圈圈！(@_@)', duration: const Duration(seconds: 4));
                            Timer(const Duration(milliseconds: 3500), () {
                              if (mounted && _state == 'DIZZY') {
                                setState(() => _state = 'IDLE');
                              }
                            });
                          }
                        }
                        _lastDragDirection = dir;
                      }

                      // 拖拽移动与抚摸交互解耦：搬动宠物时不误触发贴贴屏幕膨胀态
                      final delta = details.delta.distance;
                      if (delta > 2.0 && delta < 12.0) {
                        _strokeDistance += delta;
                        if (_strokeDistance > 60.0) {
                          _strokeDistance = 0.0;
                          _petProgress = 1.0;
                          _spawnParticles(
                            Offset(_petX, _petY - 40),
                            emoji: '✨',
                            count: 1,
                          );
                        }
                      }
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isDragging = false;
                      _touchPos = null;
                      _petProgress = 0.0;
                      _dragDirectionReversals = 0;

                      // 贴边探头偷看判定 (靠屏幕边缘 < 50px 自动贴边)
                      if (_petX < 55) {
                        _state = 'PEEK_LEFT';
                        _petX = 35;
                        _showDialogueBubble('探头偷看~ 主人在看什么呀？👀');
                        return;
                      } else if (_petX > screenSize.width - 55) {
                        _state = 'PEEK_RIGHT';
                        _petX = screenSize.width - 35;
                        _showDialogueBubble('探头偷看~ 报告主人，屏幕右侧安全！🐾');
                        return;
                      }

                      // 拖拽释放平稳平滑着陆，回归自然待机状态 (方向四：肉垫减震轻弹 Cushioned Landing + 触地微扬尘)
                      if (_state != 'DIZZY') {
                        _state = 'IDLE';
                        _squishController.forward(from: 0.0);
                        if (widget.petModel.enableHaptics) {
                          HapticFeedback.lightImpact();
                        }
                        _spawnParticles(Offset(_petX, _petY + 28), emoji: '🐾', count: 2);
                      }
                    });
                  },
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_idleAnimController, _squishController]),
                    builder: (context, child) {
                      return Transform.scale(
                        scaleX: _squishScaleX.value,
                        scaleY: _squishScaleY.value,
                        child: CustomPaint(
                          size: const Size(200, 200),
                          painter: PetPainter(
                            model: widget.petModel,
                            animTime: _idleAnimController.value * 10,
                            state: _state,
                            touchPos: (_isYarnFlying || _isYarnDragging)
                                ? Offset(_yarnX - _petX, _yarnY - _petY)
                                : (_touchPos ?? _lookTargetPos),
                            facingLeft: _facingLeft,
                            petProgress: _petProgress,
                            isPurring: _isPurring,
                            twitchEar: _twitchEar,
                            isHunting: (_isLaserMode || _isChasingYarn || _state == 'PLAY_YARN' || _state == 'CATCH_MOUSE' || _draggingFoodPos != null),
                            isTailPuffed: _isTailPuffed,
                            isAirplaneEars: _isAirplaneEars,
                            isBlep: _isBlep,
                            isSlowBlink: _isSlowBlink,
                            winkEye: _winkEye,
                            isNight: isNight,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 暖绒圆垫前侧轻触响应区 (零视觉遮挡，纯净透明交互，支持轻触圆垫触发幸福踩奶)
              Positioned(
                key: const ValueKey('cozy_cat_rug'),
                left: nestX - 90.0,
                top: nestY + 30.0,
                width: 180.0,
                height: 60.0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _onBedTap(nestX, nestY),
                ),
              ),

              // 暖绒舒睡圆垫小被子 (随呼吸起伏，支持盖被被与掀被被微互动)
              if (((_petX - nestX).abs() < 45 && (_petY - nestY).abs() < 45) || _isCoveredWithBlanket)
                _buildBlanket(nestX, nestY, isNight),

              // 维度二：开阔活动地板：实体物理毛线球 (在猫咪扑玩期间隐藏外部球，玩耍结束后恢复在猫爪旁)
              if (_state != 'PLAY_YARN')
                Positioned(
                  left: _yarnX - 18,
                  top: _yarnY - 18,
                  child: _buildYarnBall(screenSize, isNight),
                ),

              // 维度五：亲密连击 Combo 胶囊徽章
              if (_petCombo >= 2)
                Positioned(
                  left: _petX - 60,
                  top: _petY - 125,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF43F5E).withOpacity(0.32),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _petCombo >= 5 ? '🔥 MAX COMBO x$_petCombo' : '💖 COMBO x$_petCombo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),

              // 维度五：高连击满屏粉嫩微光光晕边框
              if (_petCombo >= 3)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFF43F5E).withOpacity(0.2),
                          width: 4.5,
                        ),
                      ),
                    ),
                  ),
                ),

              // 维度五：屏幕贴贴粉嫩肉垫印 🐾 与点击擦除
              if (_hasGlassPawPrints) ...[
                for (final paw in _pawPrints)
                  Positioned(
                    left: paw.dx - 28,
                    top: paw.dy - 28,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.8,
                        child: Transform.rotate(
                          angle: paw.dx < screenSize.width / 2 ? -0.15 : 0.15,
                          child: const Text('🐾', style: TextStyle(fontSize: 46)),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: screenSize.height * 0.38 + 72,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _hasGlassPawPrints = false;
                          _pawPrints = [];
                        });
                        _spawnParticles(
                          Offset(screenSize.width / 2, screenSize.height * 0.38 + 30),
                          emoji: '🫧',
                          count: 6,
                        );
                        if (widget.petModel.enableHaptics) {
                          HapticFeedback.lightImpact();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFBCFE8), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEC4899).withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🫧', style: TextStyle(fontSize: 13)),
                            SizedBox(width: 4),
                            Text(
                              '点击屏幕擦掉小猫肉垫印',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFBE185D),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // 4. 浮空特效粒子层 (心心、星星浮动)
              for (final p in _particles)
                Positioned(
                  key: p.id,
                  left: p.position.dx - 12,
                  top: p.position.dy - 12,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1.0 - p.progress).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.8 + p.progress * 0.5,
                        child: Text(
                          p.text,
                          style: TextStyle(
                            fontSize: p.fontSize,
                            fontWeight: FontWeight.bold,
                            color: p.color,
                            shadows: [
                              Shadow(
                                color: Colors.white.withOpacity(0.9),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. 对话气泡 (层级在萌宠之上，永不遮挡，智能防越界，夜晚自适应柔和星空底色)
              if (_showDialogue) _buildSmartDialogueBubble(screenSize, isNight),

              // 空白画布轻触自动收起换装/绝活滑轨坞
              if (_isWardrobeMode || _isActionMode)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      setState(() {
                        _isWardrobeMode = false;
                        _isActionMode = false;
                      });
                    },
                  ),
                ),

              // 趣味激光笔追光交互层 (全屏指尖拖拽驱动激光红点与猫咪飞扑)
              if (_isLaserMode) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanDown: (details) {
                      setState(() {
                        _laserPos = details.localPosition;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _laserPos = details.localPosition;
                      });
                    },
                  ),
                ),
                if (_laserPos != null)
                  Positioned(
                    left: _laserPos!.dx - 18,
                    top: _laserPos!.dy - 18,
                    child: IgnorePointer(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFEF4444).withOpacity(0.55),
                                  const Color(0xFFEF4444).withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF2442),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFFEF4444),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  top: 56,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: GestureDetector(
                      onTap: _stopLaserChase,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF991B1B).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF87171), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🔴', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 6),
                            Text(
                              '激光笔逗猫中 · 点击收起',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.close_rounded, color: Colors.white, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              // 浮空拖拽零食渲染层 (跟随手指移动)
              if (_draggingFoodPos != null)
                _buildDraggingFoodOverlay(),

              // 6. 底部交互控制：常态下三灵动胶囊；进入对应模式呈现画布级无遮挡点播坞/换装坞/投喂坞
              if (_isWardrobeMode)
                _buildLiveWardrobeDock(screenSize, isNight)
              else if (_isActionMode)
                _buildLiveActionDock(screenSize, isNight)
              else if (_showFoodTray)
                _buildLiveFeedingDock(screenSize, isNight)
              else
                _buildBottomFloatingBar(screenSize, isNight),
            ],
          ),
        ),
      ),
    ),
  );
  }

  /// 智能对齐气泡：永不被猫挡住，附带指向小箭头，支持昼夜温润自适应
  Widget _buildSmartDialogueBubble(Size screenSize, bool isNight) {
    final bubbleWidth = math.min(236.0, screenSize.width - 96.0);
    // 水平居中对齐猫咪；当左侧食碗展开微气泡时，气泡自动靠右避让就餐角
    double bubbleLeft = (_petX - bubbleWidth / 2).clamp(46.0, screenSize.width - bubbleWidth - 46.0);
    if (_showFoodTray) {
      bubbleLeft = math.max(168.0, bubbleLeft).clamp(16.0, screenSize.width - bubbleWidth - 16.0);
    }

    // 垂直方向：如果猫咪在屏幕上方，气泡放猫咪下方；默认放猫咪头顶上方！
    final showAbove = _petY > 210.0;
    final bubbleTop = showAbove ? (_petY - 142.0) : (_petY + 95.0);

    return Positioned(
      left: bubbleLeft,
      top: bubbleTop,
      child: GestureDetector(
        onTap: () {
          // 点击气泡换一句台词
          _checkAutoDialogue();
        },
        child: Container(
          width: bubbleWidth,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isNight
                ? const Color(0xFF1B173E).withOpacity(0.88)
                : Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isNight
                  ? const Color(0xFF6366F1).withOpacity(0.45)
                  : const Color(0xFFE0E7FF),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isNight
                    ? const Color(0xFF3730A3).withOpacity(0.25)
                    : const Color(0xFF6366F1).withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isNight ? '✨' : '💬', style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _currentDialogue,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isNight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 底部三灵动悬浮胶囊 (奇妙背包 + 魔法换装 + 专属绝活，1-Tap 直达，零层级深度)
  Widget _buildBottomFloatingBar(Size screenSize, bool isNight) {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. 奇妙背包
            GestureDetector(
              onTap: () => _openBackpackDrawer(isNight),
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < -50) {
                  _openBackpackDrawer(isNight);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                decoration: BoxDecoration(
                  color: isNight
                      ? const Color(0xFF1E1A40).withOpacity(0.9)
                      : Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isNight
                        ? const Color(0xFF6366F1).withOpacity(0.4)
                        : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isNight
                          ? const Color(0xFF0F0C24).withOpacity(0.5)
                          : const Color(0xFF6366F1).withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎒', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '奇妙背包',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isNight ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 16,
                      color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 7),

            // 2. 魔法换装 / 品种 (直达 1-Tap 开启悬浮换装坞，零弹窗遮挡)
            GestureDetector(
              onTap: () {
                _idleSeconds = 0;
                _isRoaming = false;
                _targetWalkX = null;
                SoundService.playMeow();
                if (widget.petModel.enableHaptics) {
                  HapticFeedback.lightImpact();
                }
                setState(() {
                  _isWardrobeMode = true;
                  _isActionMode = false;
                  _wardrobeTab = 0;
                });
                _spawnParticles(Offset(_petX, _petY - 20), emoji: '✨', count: 3);
                _showDialogueBubble('开启魔法换装！点选下方任意品种，波可即刻变身给你看~ 👗✨', duration: const Duration(seconds: 4));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                decoration: BoxDecoration(
                  color: isNight
                      ? const Color(0xFF311E66).withOpacity(0.9)
                      : const Color(0xFFFAF5FF).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isNight
                        ? const Color(0xFFA855F7).withOpacity(0.5)
                        : const Color(0xFFE9D5FF),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA855F7).withOpacity(0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('👗', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '魔法换装',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 7),

            // 3. 专属绝活 (直达 1-Tap 开启悬浮点播坞，零遮挡全景观赏)
            GestureDetector(
              onTap: () {
                _idleSeconds = 0;
                _isRoaming = false;
                _targetWalkX = null;
                SoundService.playMeow();
                if (widget.petModel.enableHaptics) {
                  HapticFeedback.lightImpact();
                }
                setState(() {
                  _isActionMode = true;
                  _isWardrobeMode = false;
                });
                _spawnParticles(Offset(_petX, _petY - 20), emoji: '✨', count: 3);
                _showDialogueBubble('专属绝活点播台已就绪！点选下方任意绝活，看波可大展身手~ 🎭✨', duration: const Duration(seconds: 4));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                decoration: BoxDecoration(
                  color: isNight
                      ? const Color(0xFF3D2714).withOpacity(0.9)
                      : const Color(0xFFFFFBEB).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isNight
                        ? const Color(0xFFF59E0B).withOpacity(0.55)
                        : const Color(0xFFFDE68A),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      '专属绝活',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isNight ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 画布级无遮挡换装滑轨坞 (彻底消灭阻塞弹窗，全屏无暗色遮罩，零多余操作)
  Widget _buildLiveWardrobeDock(Size screenSize, bool isNight) {
    final bgColor = isNight
        ? const Color(0xFF161334).withOpacity(0.96)
        : Colors.white.withOpacity(0.98);
    final borderColor = isNight
        ? const Color(0xFF6366F1).withOpacity(0.55)
        : const Color(0xFFDDD6FE);
    final titleColor = isNight ? Colors.white : const Color(0xFF1E293B);
    final subColor = isNight ? const Color(0xFFA5B4FC) : const Color(0xFF64748B);
    final cardBg = isNight ? const Color(0xFF262054) : const Color(0xFFF8FAFC);

    final currentSkin = widget.petModel.currentSkin;
    final currentHead = widget.petModel.decorations['head'] ?? 'none';
    final currentNeck = widget.petModel.decorations['neck'] ?? 'none';

    // 8 大名贵猫咪品种
    final skins = PetModel.availableSkins.values
        .where((s) => s.id != 'cat_white')
        .toList();

    // 头部帽子库
    final headDecos = const [
      {'id': 'none', 'name': '无帽子', 'icon': '🚫'},
      {'id': 'gold_crown_sparkle', 'name': '星辉皇冠', 'icon': '✨', 'minStage': '4'},
      {'id': 'crown', 'name': '璀璨金冠', 'icon': '👑'},
      {'id': 'wizard_hat', 'name': '魔法巫师帽', 'icon': '🧙‍♂️'},
      {'id': 'straw_hat', 'name': '田园草帽', 'icon': '👒'},
      {'id': 'sailor_cap', 'name': '蔚蓝水手帽', 'icon': '⚓'},
    ];

    // 颈部配饰库
    final neckDecos = const [
      {'id': 'none', 'name': '无配饰', 'icon': '🚫'},
      {'id': 'royal_cape', 'name': '皇家披风', 'icon': '🦸‍♂️', 'minStage': '3'},
      {'id': 'bell', 'name': '经典金铃铛', 'icon': '🔔'},
      {'id': 'ribbon', 'name': '俏皮蝴蝶结', 'icon': '🎀'},
      {'id': 'bowtie', 'name': '英伦绅士领结', 'icon': '🤵'},
      {'id': 'scarf', 'name': '暖冬红围巾', 'icon': '🧣'},
    ];

    // 当前选中的形态标签摘要
    String currentSummary = '';
    if (_wardrobeTab == 0) {
      final tags = _getBreedSummary(currentSkin.id);
      currentSummary = '🐱 当前品种：${currentSkin.name} ($tags)';
    } else if (_wardrobeTab == 1) {
      final item = headDecos.firstWhere((h) => h['id'] == currentHead, orElse: () => headDecos.first);
      currentSummary = '🎩 头部帽子：${item['name']}';
    } else {
      final item = neckDecos.firstWhere((n) => n['id'] == currentNeck, orElse: () => neckDecos.first);
      currentSummary = '🎀 颈部挂件：${item['name']}';
    }

    return Positioned(
      bottom: 12,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isNight
                  ? const Color(0xFF0F0C24).withOpacity(0.65)
                  : const Color(0xFF6366F1).withOpacity(0.14),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶层栏：分类选项卡 + 完成退出按钮
            Row(
              children: [
                _buildDockTabPill(0, '🐱 品种', isNight),
                const SizedBox(width: 6),
                _buildDockTabPill(1, '🎩 帽子', isNight),
                const SizedBox(width: 6),
                _buildDockTabPill(2, '🎀 挂件', isNight),
                const Spacer(),
                // 完成退出换装按钮 (零阻碍，一键退出换装模式)
                GestureDetector(
                  onTap: () {
                    if (widget.petModel.enableHaptics) {
                      HapticFeedback.lightImpact();
                    }
                    setState(() {
                      _isWardrobeMode = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 3),
                        Text(
                          '完成',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),

            // 状态指示摘要条 (紧凑指示，不遮挡上方小猫)
            Text(
              currentSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: subColor,
              ),
            ),
            const SizedBox(height: 8),

            // 水平滑动卡片展示列表 (高度仅 72px，全屏萌宠完全无阻挡)
            SizedBox(
              height: 72,
              child: _wardrobeTab == 0
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: skins.length,
                      itemBuilder: (context, index) {
                        final skin = skins[index];
                        final isSelected = (widget.petModel.skinId == skin.id);

                        return GestureDetector(
                          onTap: () {
                            if (widget.petModel.enableHaptics) {
                              HapticFeedback.mediumImpact();
                            }
                            setState(() {
                              widget.petModel.setSkin(skin.id);
                            });
                            _spawnParticles(Offset(_petX, _petY - 20), emoji: '✨', count: 3);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 72,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isNight ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF))
                                  : cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFA855F7)
                                    : (isNight ? const Color(0xFF4338CA).withOpacity(0.4) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 2.2 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFA855F7).withOpacity(0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Color(skin.primaryColor),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Color(skin.secondaryColor), width: 2.5),
                                      ),
                                      child: Center(
                                        child: Text(skin.icon, style: const TextStyle(fontSize: 14)),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withOpacity(0.35),
                                        ),
                                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  skin.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? (isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE))
                                        : titleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : (_wardrobeTab == 1
                      ? ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: headDecos.length,
                          itemBuilder: (context, index) {
                            final item = headDecos[index];
                            final id = item['id']!;
                            final isSelected = (currentHead == id);
                            final minStageStr = item['minStage'];
                            final minStage = minStageStr != null ? int.parse(minStageStr) : 0;
                            final currentStage = (widget.petModel.intimacyBondInfo['stage'] as int?) ?? 1;
                            final isLocked = minStage > currentStage;

                            return GestureDetector(
                              onTap: () {
                                if (isLocked) {
                                  if (widget.petModel.enableHaptics) HapticFeedback.heavyImpact();
                                  _showDialogueBubble('🔒 专属装扮：亲密度羁绊需达到第 $minStage 阶解锁！多与波可互动吧~ 💖');
                                  return;
                                }
                                if (widget.petModel.enableHaptics) {
                                  HapticFeedback.lightImpact();
                                }
                                setState(() {
                                  widget.petModel.setDecoration('head', id);
                                });
                                _spawnParticles(Offset(_petX, _petY - 20), emoji: '🎩', count: 3);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 72,
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isNight ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF))
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFA855F7)
                                        : (isNight ? const Color(0xFF4338CA).withOpacity(0.4) : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 2.2 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFA855F7).withOpacity(0.35),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isLocked)
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Opacity(
                                            opacity: 0.35,
                                            child: Text(item['icon']!, style: const TextStyle(fontSize: 18)),
                                          ),
                                          const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFF59E0B)),
                                        ],
                                      )
                                    else
                                      Text(item['icon']!, style: const TextStyle(fontSize: 20)),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['name']!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isLocked
                                            ? const Color(0xFF94A3B8)
                                            : (isSelected
                                                ? (isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE))
                                                : titleColor),
                                      ),
                                    ),
                                    if (isLocked)
                                      Text(
                                        '阶$minStage解锁',
                                        style: const TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),

                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: neckDecos.length,
                          itemBuilder: (context, index) {
                            final item = neckDecos[index];
                            final id = item['id']!;
                            final isSelected = (currentNeck == id);
                            final minStageStr = item['minStage'];
                            final minStage = minStageStr != null ? int.parse(minStageStr) : 0;
                            final currentStage = (widget.petModel.intimacyBondInfo['stage'] as int?) ?? 1;
                            final isLocked = minStage > currentStage;

                            return GestureDetector(
                              onTap: () {
                                if (isLocked) {
                                  if (widget.petModel.enableHaptics) HapticFeedback.heavyImpact();
                                  _showDialogueBubble('🔒 专属装扮：亲密度羁绊需达到第 $minStage 阶解锁！多与波可互动吧~ 💖');
                                  return;
                                }
                                if (widget.petModel.enableHaptics) {
                                  HapticFeedback.lightImpact();
                                }
                                setState(() {
                                  widget.petModel.setDecoration('neck', id);
                                });
                                _spawnParticles(Offset(_petX, _petY - 20), emoji: '🎀', count: 3);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 72,
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isNight ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF))
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFA855F7)
                                        : (isNight ? const Color(0xFF4338CA).withOpacity(0.4) : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 2.2 : 1.0,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFA855F7).withOpacity(0.35),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isLocked)
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Opacity(
                                            opacity: 0.35,
                                            child: Text(item['icon']!, style: const TextStyle(fontSize: 18)),
                                          ),
                                          const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFF59E0B)),
                                        ],
                                      )
                                    else
                                      Text(item['icon']!, style: const TextStyle(fontSize: 20)),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['name']!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isLocked
                                            ? const Color(0xFF94A3B8)
                                            : (isSelected
                                                ? (isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE))
                                                : titleColor),
                                      ),
                                    ),
                                    if (isLocked)
                                      Text(
                                        '阶$minStage解锁',
                                        style: const TextStyle(
                                          fontSize: 7.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),

                                  ],
                                ),
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  /// 画布级无遮挡专属绝活滑轨点播台 (彻底消灭阻塞弹窗，全屏无暗色遮罩，零多余操作)
  Widget _buildLiveActionDock(Size screenSize, bool isNight) {
    final bgColor = isNight
        ? const Color(0xFF14122C).withOpacity(0.96)
        : Colors.white.withOpacity(0.98);
    final borderColor = isNight
        ? const Color(0xFFF59E0B).withOpacity(0.55)
        : const Color(0xFFFDE68A);
    final cardBg = isNight ? const Color(0xFF231B45) : const Color(0xFFFFFBEB);

    final actions = ActionDialog.actions;

    // 当前是否在表演某项绝活
    final isActing = actions.any((act) => act['id'] == _state);
    final currentAct = isActing
        ? actions.firstWhere((act) => act['id'] == _state)
        : null;

    final headerText = isActing
        ? '🎭 正在表演：${currentAct!['name']} · ${currentAct['desc']}'
        : '✨ 绝活点播台 · 点击下方卡片即刻开演 (共${actions.length}项)';

    return Positioned(
      bottom: 12,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isNight
                  ? const Color(0xFF0F0C24).withOpacity(0.65)
                  : const Color(0xFFF59E0B).withOpacity(0.14),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶层栏：动态表演状态指示 + 完成退出按钮
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isActing
                              ? const Color(0xFFEF4444).withOpacity(isNight ? 0.3 : 0.12)
                              : const Color(0xFFF59E0B).withOpacity(isNight ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActing
                                ? const Color(0xFFEF4444).withOpacity(0.5)
                                : const Color(0xFFF59E0B).withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          isActing ? '🔴 LIVE' : '✨ 才艺',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActing
                                ? (isNight ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                                : (isNight ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          headerText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isActing
                                ? (isNight ? Colors.white : const Color(0xFF0F172A))
                                : (isNight ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 完成退出点播按钮 (一键收起滑轨坞，回归日常互动)
                GestureDetector(
                  onTap: () {
                    if (widget.petModel.enableHaptics) {
                      HapticFeedback.lightImpact();
                    }
                    setState(() {
                      _isActionMode = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 3),
                        Text(
                          '完成',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 水平滑动卡片展示列表 (高度仅 72px，全屏萌宠与地面道具完全无遮挡)
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final act = actions[index];
                  final isCurrent = (_state == act['id']);

                  return GestureDetector(
                    onTap: () {
                      _playAction(act['id']!);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 78,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? (isNight ? const Color(0xFF581C87) : const Color(0xFFFEF3C7))
                            : cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFFF59E0B)
                              : (isNight ? const Color(0xFF4338CA).withOpacity(0.35) : const Color(0xFFFDE68A).withOpacity(0.7)),
                          width: isCurrent ? 2.2 : 1.0,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withOpacity(0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Text(act['icon']!, style: const TextStyle(fontSize: 22)),
                              if (isCurrent)
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            act['name']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: isCurrent
                                  ? (isNight ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                                  : (isNight ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockTabPill(int index, String label, bool isNight) {
    final isSelected = (_wardrobeTab == index);
    return GestureDetector(
      onTap: () {
        if (widget.petModel.enableHaptics) {
          HapticFeedback.selectionClick();
        }
        setState(() {
          _wardrobeTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFA855F7)
              : (isNight ? const Color(0xFF262054) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFA855F7).withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isNight ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  String _getBreedSummary(String skinId) {
    switch (skinId) {
      case 'cat_ragdoll':
        return '八字开脸 · 蓬松羽尾 · 仙气胸毛';
      case 'cat_siamese':
        return '高耸尖耳 · 楔形V脸 · 细鞭尾';
      case 'cat_british_blue':
        return '包子脸发腮 · 矮胖躯干 · 水獭尾';
      case 'cat_orange':
        return '大橘肚腩 · 虎斑环纹尾 · 肥肉爪';
      case 'cat_persian_white':
        return '鸳鸯异瞳 · 飘逸鬃毛 · 纯白羽尾';
      case 'cat_calico':
        return '阴阳双色耳 · 锦鲤花斑 · 招财吉猫';
      case 'cat_american_tabby':
        return '虎斑M纹 · 大理石回旋 · 斑纹尾';
      case 'cat_black':
        return '曜石流线 · 踏雪寻梅白爪 · 金瞳';
      default:
        return '纯洁灵动小萌宠';
    }
  }

  /// 顶部双灵动岛浮空栏：左侧身份好感 + 右侧饱腹心情小窝，紧凑优雅，严防窄屏溢出
  Widget _buildTopDualIslands(Size screenSize, bool isNight) {
    final bondInfo = widget.petModel.intimacyBondInfo;
    final bondColor = Color(bondInfo['color'] as int);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 左侧灵动岛：萌宠等级、名称与亲密称号徽章 (双层精简卡片，绝不挤压横向空间)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isNight
                ? const Color(0xFF181534).withOpacity(0.88)
                : Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNight ? const Color(0xFF6366F1).withOpacity(0.35) : Colors.white,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: isNight
                    ? const Color(0xFF0F0C24).withOpacity(0.5)
                    : const Color(0xFF6366F1).withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 等级徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  'Lv.${widget.petModel.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 垂直布局：上方名称，下方亲密度与称号徽章
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: (screenSize.width * 0.28).clamp(70.0, 110.0)),
                    child: Text(
                      widget.petModel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isNight ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '❤️ ${widget.petModel.intimacy}',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: isNight ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // 亲密羁绊称号勋章胶囊 (点按呼出成就卡片)
                      GestureDetector(
                        key: const ValueKey('intimacy_bond_badge'),
                        onTap: _showIntimacyBondModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: bondColor.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: bondColor.withOpacity(0.55),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(bondInfo['icon'] as String, style: const TextStyle(fontSize: 8)),
                              const SizedBox(width: 1.5),
                              Text(
                                bondInfo['title'] as String,
                                style: TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: FontWeight.bold,
                                  color: bondColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. 右侧灵动岛：饱腹与心情 + 快捷工具组 (双层设计，通透呼吸，绝不溢出)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
          decoration: BoxDecoration(
            color: isNight
                ? const Color(0xFF181534).withOpacity(0.88)
                : Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNight ? const Color(0xFF6366F1).withOpacity(0.35) : Colors.white,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: isNight
                    ? const Color(0xFF0F0C24).withOpacity(0.5)
                    : const Color(0xFF6366F1).withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 上排：饱腹与心情状态数值
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🍗', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 2),
                  Text(
                    '${widget.petModel.hunger.toInt()}%',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 2.5,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text('💖', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 2),
                  Text(
                    '${widget.petModel.mood.toInt()}%',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              // 下排：快捷控制按钮 (声音开关、爪印开关、回窝按钮)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 音效开关
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        SoundService.soundEnabled = !SoundService.soundEnabled;
                      });
                      if (SoundService.soundEnabled) SoundService.playMeow();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: SoundService.soundEnabled
                            ? (isNight ? const Color(0xFF312E81) : const Color(0xFFEEF2FF))
                            : (isNight ? const Color(0xFF26204E) : const Color(0xFFF1F5F9)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: SoundService.soundEnabled
                              ? const Color(0xFF6366F1)
                              : (isNight ? const Color(0xFF4F46E5).withOpacity(0.4) : const Color(0xFFE2E8F0)),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        SoundService.soundEnabled ? '🔊' : '🔇',
                        style: const TextStyle(fontSize: 8.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // 地板猫爪印开关
                  GestureDetector(
                    key: const ValueKey('footprint_toggle_button'),
                    onTap: () {
                      setState(() {
                        widget.petModel.toggleFootprints();
                        if (!widget.petModel.enableFootprints) {
                          _footprints.clear();
                        }
                      });
                      if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
                      _showDialogueBubble(
                        widget.petModel.enableFootprints
                            ? '已开启温润小猫肉垫爪印~ 🐾'
                            : '已收起爪印，保持地板纯净洁白✨',
                        duration: const Duration(seconds: 3),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: widget.petModel.enableFootprints
                            ? (isNight ? const Color(0xFF312E81) : const Color(0xFFFFF1F2))
                            : (isNight ? const Color(0xFF26204E) : const Color(0xFFF1F5F9)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.petModel.enableFootprints
                              ? const Color(0xFFFB7185)
                              : (isNight ? const Color(0xFF4F46E5).withOpacity(0.4) : const Color(0xFFE2E8F0)),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        widget.petModel.enableFootprints ? '🐾' : '🧹',
                        style: const TextStyle(fontSize: 8.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // 回到小窝按钮
                  GestureDetector(
                    onTap: () => _resetToMat(screenSize),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isNight ? const Color(0xFF26204E) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isNight ? const Color(0xFF4F46E5).withOpacity(0.4) : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        size: 11,
                        color: isNight ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handleFloatingTap() async {
    final hasPermission = await OverlayService.checkPermission();
    final isRunning = await OverlayService.isRunning();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Text('📱', style: TextStyle(fontSize: 24)),
                SizedBox(width: 8),
                Text('全局桌面悬浮宠', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasPermission
                      ? '✅ 系统悬浮窗权限已就绪！\n开启后波可将突破 App 边界，常驻在手机桌面、微信、浏览器等任意应用的最上层，随时随地陪伴您。'
                      : '⚠️ 尚未开启“显示在其他应用上层”权限。\n请先点击下方按钮前往系统设置开启悬浮窗权限，方可在手机桌面上显示波可。',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
                ),
                const SizedBox(height: 14),
                if (hasPermission)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isRunning ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isRunning ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(isRunning ? '🟢 悬浮萌宠：运行中 (已在屏幕边缘)' : '⚪ 悬浮萌宠：未开启',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isRunning ? const Color(0xFF047857) : const Color(0xFF64748B),
                            )),
                      ],
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('稍后再说', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              if (!hasPermission)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('前往授权悬浮窗'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await OverlayService.requestPermission();
                  },
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRunning ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(isRunning ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded, size: 18),
                  label: Text(isRunning ? '收回悬浮宠' : '立即启动桌面悬浮'),
                  onPressed: () async {
                    if (isRunning) {
                      await OverlayService.stopFloatingPet();
                      _showDialogueBubble('桌面悬浮宠已收回小窝~ 🐾');
                    } else {
                      final ok = await OverlayService.startFloatingPet();
                      if (ok) {
                        _showDialogueBubble('桌面悬浮宠启动成功！切回手机桌面就能看到波可啦~ ✨');
                      }
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  /// 房间立体景深：木质地台与高光踢脚线 (白天浅橡木纹，夜间静谧胡桃木)
  Widget _buildCozyFlooring(bool isNight) {
    final baseboardColor = isNight ? const Color(0xFF1E1738) : const Color(0xFFD4A373);
    final baseboardHighlight = isNight ? const Color(0xFF332A55) : const Color(0xFFFAEDCD);
    final floorGradient = isNight
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF16122C),
              Color(0xFF110D24),
              Color(0xFF0C091A),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFBF4EB),
              Color(0xFFF4E3D0),
              Color(0xFFECD2BA),
            ],
          );
    final plankLineColor = isNight
        ? Colors.white.withOpacity(0.04)
        : const Color(0xFFB07D53).withOpacity(0.12);

    return Container(
      decoration: BoxDecoration(
        gradient: floorGradient,
      ),
      child: Stack(
        children: [
          // 踢脚线顶面高光线
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 3,
            child: Container(color: baseboardHighlight),
          ),
          // 踢脚线主体
          Positioned(
            top: 3,
            left: 0,
            right: 0,
            height: 12,
            child: Container(color: baseboardColor),
          ),
          // 踢脚线下立体阴影
          Positioned(
            top: 15,
            left: 0,
            right: 0,
            height: 8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(isNight ? 0.35 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 木地板横向接缝细线 (模拟原木拼花空间景深，延伸铺满整个下层空间)
          for (int i = 1; i <= 10; i++)
            Positioned(
              top: 25.0 + i * 52.0,
              left: 0,
              right: 0,
              height: 1.0,
              child: Container(color: plankLineColor),
            ),
        ],
      ),
    );
  }

  /// 顶部浪漫温馨小串灯 (白天晶莹，夜晚散发微黄暖芒，轻触闪耀)
  Widget _buildFairyLightsRow(bool isNight) {
    return GestureDetector(
      onTap: _onFairyLightsTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFairyLight('💡', isNight),
            _buildFairyWire(isNight),
            _buildFairyLight('✨', isNight),
            _buildFairyWire(isNight),
            _buildFairyLight('🌟', isNight),
            _buildFairyWire(isNight),
            _buildFairyLight('💡', isNight),
          ],
        ),
      ),
    );
  }

  Widget _buildFairyLight(String icon, bool isNight) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isNight
            ? const Color(0xFFFEF08A).withOpacity(0.18)
            : const Color(0xFFFEF3C7).withOpacity(0.6),
        shape: BoxShape.circle,
        boxShadow: isNight
            ? [
                BoxShadow(
                  color: const Color(0xFFFDE047).withOpacity(0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Text(icon, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildFairyWire(bool isNight) {
    return Expanded(
      child: Container(
        height: 1.2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isNight
              ? const Color(0xFF94A3B8).withOpacity(0.3)
              : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  /// 墙面拍立得相框 (初遇温馨纪念，轻触微晃冒心心)
  Widget _buildPolaroidFrame(bool isNight) {
    return GestureDetector(
      onTap: _onPhotoTap,
      child: Transform.rotate(
        angle: _photoAngle,
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 6),
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF241D49) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isNight ? const Color(0xFF6366F1).withOpacity(0.3) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isNight ? 0.35 : 0.10),
                blurRadius: 8,
                offset: const Offset(1, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 和纸胶带
              Container(
                width: 20,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFF472B6).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 3),
              // 照片内框
              Container(
                width: 44,
                height: 38,
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFF161131) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('🐾❤️', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Day 1 · 相遇',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                  color: isNight ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 暖绒云朵舒睡圆垫 (柔和通透羊毛地垫，自然融入原木地板，告别生硬厚重黄色块)
  Widget _buildCatRug(double nestX, double nestY, bool isNight) {
    const rugWidth = 148.0;
    const rugHeight = 68.0;
    return Positioned(
      left: nestX - rugWidth / 2,
      top: nestY + 12.0,
      width: rugWidth,
      height: rugHeight,
      child: GestureDetector(
        onTap: () => _onBedTap(nestX, nestY),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // 1. 地板柔和漫反射阴影 (Diffused Floor Shadow)
            Positioned(
              bottom: 2,
              child: Container(
                width: rugWidth * 0.92,
                height: rugHeight * 0.44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(rugWidth * 0.92 / 2, rugHeight * 0.44 / 2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isNight ? 0.25 : 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            // 2. 暖绒羊羔呢圆垫主体 (柔和通透微渐变，透出地板木纹)
            Container(
              width: rugWidth,
              height: rugHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(rugWidth / 2, rugHeight / 2)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isNight
                      ? [const Color(0xFF2B2252).withOpacity(0.55), const Color(0xFF1D1739).withOpacity(0.60)]
                      : [const Color(0xFFFFFDF5).withOpacity(0.68), const Color(0xFFFEF3C7).withOpacity(0.45)],
                ),
                border: Border.all(
                  color: isNight
                      ? const Color(0xFF6366F1).withOpacity(0.28)
                      : const Color(0xFFFDE68A).withOpacity(0.60),
                  width: 1.2,
                ),
              ),
              child: Center(
                // 垫内柔和暗纹肉垫印记 (极简美观，低调质感)
                child: Opacity(
                  opacity: isNight ? 0.14 : 0.16,
                  child: Text(
                    '🐾',
                    style: TextStyle(
                      fontSize: 16,
                      color: isNight ? const Color(0xFFC7D2FE) : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 软装家具 1：萌宠猫草盆栽 (轻触轻摇，散发清香与青草粒子，静立于木地板墙角)
  Widget _buildCatGrassPlanter(bool isNight) {
    return GestureDetector(
      onTap: _onPlantTap,
      child: Transform.rotate(
        angle: _plantTilt,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF1E1838) : Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isNight ? const Color(0xFF10B981).withOpacity(0.6) : const Color(0xFFA7F3D0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(isNight ? 0.22 : 0.14),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪴', style: TextStyle(fontSize: 24)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFF065F46) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '猫草',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isNight ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 软装家具 2：原木剑麻猫抓柱 (磨爪解压，轻触咔嚓磨爪与木屑火花，立于右上角木地板)
  Widget _buildCatScratchingPost(bool isNight) {
    final isScratching = _postWiggle.abs() > 0.1;
    return GestureDetector(
      onTap: _onScratcherTap,
      child: Transform.translate(
        offset: Offset(_postWiggle, 0),
        child: Transform.scale(
          scaleX: 1.0 + (_postWiggle.abs() * 0.04),
          scaleY: 1.0 - (_postWiggle.abs() * 0.03),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isNight
                  ? (isScratching ? const Color(0xFF2C2250) : const Color(0xFF1E1838))
                  : (isScratching ? const Color(0xFFFEF9C3) : Colors.white.withOpacity(0.96)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isScratching
                    ? const Color(0xFFF59E0B)
                    : (isNight ? const Color(0xFFF59E0B).withOpacity(0.6) : const Color(0xFFFDE68A)),
                width: isScratching ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withOpacity(isScratching ? 0.38 : (isNight ? 0.22 : 0.14)),
                  blurRadius: isScratching ? 14 : 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isScratching ? '🐾' : '🪵', style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isScratching
                        ? const Color(0xFFF59E0B)
                        : (isNight ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isScratching ? '解压中' : '磨爪',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isScratching
                          ? Colors.white
                          : (isNight ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 软装家具 3：左下角就餐角 · 萌宠双联食水一体托盘 (原木陶瓷质感，双碗一体化防滑托盘)
  Widget _buildCatDiningStation(double nestX, double nestY, bool isNight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: isNight
            ? const Color(0xFF1B1635).withOpacity(0.92)
            : Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isNight
              ? const Color(0xFF6366F1).withOpacity(0.35)
              : const Color(0xFFE2E8F0),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isNight ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 左侧：精致小食碗 (点击投喂，双击弹鲜鱼)
          _buildCatFoodBowl(nestX, nestY, isNight),
          // 优雅陶瓷分隔微线
          Container(
            width: 1.0,
            height: 24,
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            color: isNight ? const Color(0xFF3730A3).withOpacity(0.4) : const Color(0xFFE2E8F0),
          ),
          // 右侧：清澈小水碗 (点击波光粼粼涟漪，解渴补水)
          _buildCatWaterBowl(nestX, nestY, isNight),
        ],
      ),
    );
  }

  /// 食碗凹槽组件
  Widget _buildCatFoodBowl(double nestX, double nestY, bool isNight) {
    return GestureDetector(
      key: const ValueKey('cat_food_bowl'),
      onTap: () {
        SoundService.playPop();
        if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
        setState(() {
          _showFoodTray = !_showFoodTray;
          if (_showFoodTray) {
            _isWardrobeMode = false;
            _isActionMode = false;
          }
        });
        if (_showFoodTray) {
          _showDialogueBubble('喵~ 好吃的！按住小鱼干拖给波可吧~ 🥣✨', duration: const Duration(seconds: 3));
        }
      },
      onDoubleTap: () => _popFishFromBowl(nestX, nestY),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _showFoodTray
              ? const Color(0xFFF43F5E).withOpacity(0.18)
              : (isNight ? const Color(0xFF140F2A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _showFoodTray
                ? const Color(0xFFF43F5E)
                : (isNight ? const Color(0xFF4338CA).withOpacity(0.3) : const Color(0xFFE2E8F0)),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🥣', style: TextStyle(fontSize: 14)),
                SizedBox(width: 2),
                Text('🐟', style: TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 1.5),
            Text(
              _showFoodTray ? '投喂中' : '食碗',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: _showFoodTray
                    ? const Color(0xFFF43F5E)
                    : (isNight ? const Color(0xFFA5B4FC) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 水碗凹槽组件
  Widget _buildCatWaterBowl(double nestX, double nestY, bool isNight) {
    return GestureDetector(
      key: const ValueKey('cat_water_bowl'),
      onTap: () {
        SoundService.playPop();
        if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
        setState(() {
          _isWaterRippling = true;
        });
        _spawnParticles(Offset(100, nestY + 115), emoji: '💧', count: 4);
        _spawnTextParticle(Offset(80, nestY + 95), '解渴补水 💧✨', const Color(0xFF0284C7));
        widget.petModel.addCleanliness(8);
        widget.petModel.addMood(6);
        widget.petModel.addIntimacy(2);

        // 如果猫咪在就餐角附近，触发低头小舔水微表情动作
        if ((_petX - 80).abs() < 100 && (_petY - (nestY + 105)).abs() < 90) {
          _triggerBlep();
          _showDialogueBubble('咕嘟咕嘟~ 清凉甘甜的水好解渴呀！清洁+8 心情+6 💧(ฅ>ω<*ฅ)', duration: const Duration(seconds: 4));
        } else {
          _showDialogueBubble('水碗泛起粼粼清澈涟漪~ 唤波可过来喝水补充水分吧！💧✨', duration: const Duration(seconds: 3));
        }

        _waterRippleTimer?.cancel();
        _waterRippleTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _isWaterRippling = false);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isWaterRippling
              ? const Color(0xFF38BDF8).withOpacity(0.25)
              : (isNight ? const Color(0xFF140F2A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isWaterRippling
                ? const Color(0xFF0284C7)
                : (isNight ? const Color(0xFF38BDF8).withOpacity(0.4) : const Color(0xFFBAE6FD)),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🥣', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 2),
                Text(_isWaterRippling ? '🫧' : '💧', style: const TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 1.5),
            Text(
              _isWaterRippling ? '波光粼粼' : '水碗',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: _isWaterRippling
                    ? const Color(0xFF0284C7)
                    : (isNight ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 空间环境 1：法式拱形观景窗 (French Arch Window - 4 季天象点按切换)
  Widget _buildFrenchArchWindow(bool isNight) {
    // 0: ☀️ 暖阳晴空, 1: 🌧️ 治愈雨季, 2: 🌸 春日落樱, 3: 🌙 浪漫星空
    final gradients = [
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF38BDF8), Color(0xFFBAE6FD)],
      ),
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF475569), Color(0xFF94A3B8)],
      ),
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF472B6), Color(0xFFFCE7F3)],
      ),
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F172A), Color(0xFF312E81)],
      ),
    ];

    final weatherTags = ['☀️ 晴空', '🌧️ 细雨', '🌸 落樱', '🌙 星夜'];

    return GestureDetector(
      key: const ValueKey('french_arch_window'),
      onTap: _cycleWindowWeather,
      child: Container(
        width: 86,
        height: 112,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(43), bottom: Radius.circular(6)),
          border: Border.all(
            color: isNight ? const Color(0xFF4338CA).withOpacity(0.8) : const Color(0xFFE2E8F0),
            width: 3.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isNight ? 0.35 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(39), bottom: Radius.circular(3)),
          child: Stack(
            children: [
              Container(decoration: BoxDecoration(gradient: gradients[_windowWeather])),
              if (_windowWeather == 0) ...[
                const Positioned(top: 10, right: 10, child: Text('☀️', style: TextStyle(fontSize: 16))),
                const Positioned(bottom: 22, left: 10, child: Text('☁️', style: TextStyle(fontSize: 14))),
              ] else if (_windowWeather == 1) ...[
                const Positioned(top: 8, left: 12, child: Text('🌧️', style: TextStyle(fontSize: 16))),
                Positioned(
                  bottom: 20,
                  right: 14,
                  child: Text('💧', style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8))),
                ),
              ] else if (_windowWeather == 2) ...[
                const Positioned(top: 12, left: 10, child: Text('🌸', style: TextStyle(fontSize: 14))),
                const Positioned(bottom: 22, right: 10, child: Text('🌸', style: TextStyle(fontSize: 11))),
              ] else ...[
                const Positioned(top: 8, right: 10, child: Text('🌙', style: TextStyle(fontSize: 14))),
                const Positioned(bottom: 22, left: 12, child: Text('✨', style: TextStyle(fontSize: 11))),
              ],
              Center(
                child: Container(
                  width: 2.0,
                  height: double.infinity,
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: Container(
                  height: 2.0,
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
              Positioned(
                bottom: 3,
                left: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.32),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      weatherTags[_windowWeather],
                      style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 空间环境 2：阳光光斑 (Sunbeam Patch - 晴空暖阳下映照在木地板上的柔和光斑 + 丁达尔浮动金尘)
  Widget _buildSunbeamPatch(double nestX, double nestY, bool isNight) {
    return Positioned(
      left: nestX + 32,
      top: nestY - 22,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _idleAnimController,
          builder: (context, _) {
            final animVal = _idleAnimController.value * 2 * math.pi;
            return Transform.rotate(
              angle: -0.16,
              child: Container(
                width: 120,
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.elliptical(60, 31)),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFEF08A).withOpacity(0.36),
                      const Color(0xFFFDE047).withOpacity(0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Opacity(
                      opacity: 0.28,
                      child: Text('☀️', style: TextStyle(fontSize: 18, color: Color(0xFFF59E0B))),
                    ),
                    // 丁达尔金光微尘 (Dust Motes ✨ ⭐)
                    Positioned(
                      top: 14 + math.sin(animVal) * 3,
                      left: 28 + math.cos(animVal) * 4,
                      child: Opacity(
                        opacity: (0.45 + math.sin(animVal).abs() * 0.35).clamp(0.0, 1.0),
                        child: const Text('✨', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                    Positioned(
                      bottom: 12 - math.sin(animVal) * 3,
                      right: 24 - math.cos(animVal) * 4,
                      child: Opacity(
                        opacity: (0.35 + math.cos(animVal).abs() * 0.35).clamp(0.0, 1.0),
                        child: const Text('⭐', style: TextStyle(fontSize: 9)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 空间环境 3：春日落樱花瓣 (Sakura Petals - 随风摇曳，轻触化为粉红光尘)
  List<Widget> _buildSakuraPetals(Size screenSize, bool isNight) {
    final basePositions = [
      Offset(screenSize.width * 0.22, 175),
      Offset(screenSize.width * 0.76, 215),
      Offset(screenSize.width * 0.48, 290),
    ];

    return List.generate(basePositions.length, (index) {
      final base = basePositions[index];
      final phase = index * 1.8;
      final animVal = _idleAnimController.value * 2 * math.pi;
      final floatX = base.dx + math.sin(animVal + phase) * 14;
      final floatY = base.dy + math.cos(animVal + phase) * 10;
      final angle = math.sin(animVal + phase) * 0.35;

      return Positioned(
        key: ValueKey('sakura_petal_$index'),
        left: floatX,
        top: floatY,
        child: GestureDetector(
          onTap: () {
            SoundService.playPop();
            if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
            _spawnParticles(Offset(floatX + 10, floatY + 10), emoji: '🌸', count: 3);
            _spawnParticles(Offset(floatX + 10, floatY + 10), emoji: '✨', count: 2);
            _spawnTextParticle(Offset(floatX - 15, floatY - 20), '落樱轻抚 🌸+1💖', const Color(0xFFF43F5E));
            widget.petModel.addIntimacy(1);
            _showDialogueBubble('轻触飘落的樱花瓣~ 化作粉红微尘消散在风中啦！(🌸´▽`🌸)', duration: const Duration(seconds: 3));
          },
          child: Transform.rotate(
            angle: angle,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: const Text('🌸', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      );
    });
  }

  /// 底部沉浸式美食投喂坞 (Live Feeding Dock - 位于底部黄金触控区，零中景遮挡，轻触或向上拖拽喂猫)
  Widget _buildLiveFeedingDock(Size screenSize, bool isNight) {
    final foodItems = [
      {'id': 'dried_fish', 'name': '香酥小鱼干', 'icon': '🐟', 'hunger': 20, 'intimacy': 5, 'desc': '+20饱腹 +5💖'},
      {'id': 'salmon_cubes', 'name': '纯肉三文鱼', 'icon': '🍣', 'hunger': 35, 'intimacy': 8, 'desc': '+35饱腹 +8💖'},
      {'id': 'goat_milk', 'name': '舒化羊奶', 'icon': '🥛', 'hunger': 15, 'intimacy': 10, 'desc': '+15饱腹 +10💖'},
    ];

    return Positioned(
      key: const ValueKey('drag_to_feed_tray'),
      bottom: 14,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: isNight
              ? const Color(0xFF161334).withOpacity(0.96)
              : Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isNight ? const Color(0xFFFB7185).withOpacity(0.45) : const Color(0xFFFDA4AF),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF43F5E).withOpacity(isNight ? 0.28 : 0.12),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶栏：标题说明 + 提示 + 完成关闭按钮
            Row(
              children: [
                const Text('🥣', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '美味投喂 · 轻触或向上拖拽给波可',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isNight ? Colors.white : const Color(0xFF9F1239),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
                    setState(() => _showFoodTray = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF2E2652) : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDA4AF).withOpacity(0.5), width: 0.9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 12, color: isNight ? const Color(0xFFCBD5E1) : const Color(0xFFE11D48)),
                        const SizedBox(width: 2),
                        Text(
                          '完成',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isNight ? Colors.white : const Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 3 颗横向精致美食卡片
            Row(
              children: foodItems.map((food) {
                final id = food['id'] as String;
                final name = food['name'] as String;
                final icon = food['icon'] as String;
                final hunger = food['hunger'] as int;
                final intimacy = food['intimacy'] as int;
                final desc = food['desc'] as String;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _finishDragToFeed(hunger, intimacy);
                      _spawnParticles(Offset(_petX, _petY - 20), emoji: icon, count: 4);
                    },
                    onPanStart: (details) {
                      setState(() {
                        _draggingFoodId = id;
                        _draggingFoodName = name;
                        _draggingFoodIcon = icon;
                        _draggingFoodPos = details.globalPosition;
                        _lookTargetPos = _draggingFoodPos! - Offset(_petX, _petY);
                      });
                      if (widget.petModel.enableHaptics) HapticFeedback.selectionClick();
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _draggingFoodPos = details.globalPosition;
                        _lookTargetPos = _draggingFoodPos! - Offset(_petX, _petY);
                      });
                    },
                    onPanEnd: (details) {
                      _finishDragToFeed(hunger, intimacy);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isNight
                              ? [const Color(0xFF2E2652), const Color(0xFF1E1838)]
                              : [const Color(0xFFFFF5F5), const Color(0xFFFFECEF)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFDA4AF).withOpacity(0.6),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFB7185).withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isNight ? const Color(0xFF3F356B) : Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFB7185).withOpacity(0.18),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(icon, style: const TextStyle(fontSize: 20)),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isNight ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 舒睡暖垫小被子 (Tuck-in Blanket - 随呼吸起伏，支持盖被被与掀被被微互动)
  Widget _buildBlanket(double nestX, double nestY, bool isNight) {
    final isCatAtBed = (_petX - nestX).abs() < 45 && (_petY - nestY).abs() < 45;
    if (!isCatAtBed && !_isCoveredWithBlanket) {
      return const Positioned(child: SizedBox.shrink());
    }

    if (!_isCoveredWithBlanket) {
      return Positioned(
        key: const ValueKey('tuck_in_blanket_button'),
        left: nestX + 48,
        top: nestY + 28,
        child: GestureDetector(
          onTap: _toggleBlanket,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFB7185), Color(0xFFF43F5E)]),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF43F5E).withOpacity(0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🛏️', style: TextStyle(fontSize: 10)),
                SizedBox(width: 2.5),
                Text('盖被被', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    final breathOffset = math.sin(_idleAnimController.value * 2 * math.pi) * 2.2;

    return Positioned(
      key: const ValueKey('covered_blanket'),
      left: _petX - 62,
      top: _petY + 18 + breathOffset,
      child: GestureDetector(
        onTap: () {
          SoundService.startPurr();
          if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
          _spawnParticles(Offset(_petX, _petY - 20), emoji: '💤', count: 3);
          final sleepyQuotes = [
            '呼呜... (梦话) 最喜欢主人了... 💤',
            '被窝里好暖和好舒服，呼噜噜... (˘ω˘)🛌',
            '再睡五分钟嘛主人... 翻个身把小爪子缩进被窝~ 🐾',
          ];
          _showDialogueBubble(sleepyQuotes[math.Random().nextInt(sleepyQuotes.length)]);
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 124,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isNight
                      ? const [Color(0xFF4C1D95), Color(0xFF312E81)]
                      : const [Color(0xFFFECDD3), Color(0xFFFDA4AF)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(
                  color: isNight ? const Color(0xFF8B5CF6) : const Color(0xFFF43F5E),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        border: Border(
                          bottom: BorderSide(
                            color: (isNight ? const Color(0xFF8B5CF6) : const Color(0xFFF43F5E)).withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 22,
                    left: 18,
                    child: Text('🐾', style: TextStyle(fontSize: 10, color: Colors.white70)),
                  ),
                  const Positioned(
                    top: 32,
                    right: 22,
                    child: Text('⭐', style: TextStyle(fontSize: 10, color: Colors.white70)),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -8,
              right: -6,
              child: GestureDetector(
                onTap: _toggleBlanket,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF43F5E), width: 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4),
                    ],
                  ),
                  child: const Text('掀被 ☀️', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFE11D48))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 浮空拖拽零食渲染层 (跟随手指移动)
  Widget _buildDraggingFoodOverlay() {
    if (_draggingFoodPos == null) return const Positioned(child: SizedBox.shrink());
    return Positioned(
      left: _draggingFoodPos!.dx - 24,
      top: _draggingFoodPos!.dy - 24,
      child: IgnorePointer(
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF43F5E).withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFFB7185), width: 2.0),
          ),
          child: Center(
            child: Text(_draggingFoodIcon ?? '🐟', style: const TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }

  /// 软装家具 4：右下角夜灯台 · 萌猫头温馨夜灯 (轻触开关台灯，点按上方标签切换 ASMR 白噪音)
  Widget _buildKittenNightLamp(bool isNight) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isNightLampOn) ...[
          GestureDetector(
            onTap: _cycleAmbientSound,
            child: Container(
              margin: const EdgeInsets.only(bottom: 3.5),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isNight ? const Color(0xFF312E81) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1),
              ),
              child: Text(
                SoundService.ambientMode == 'rain'
                    ? '🌧️ 雨声'
                    : (SoundService.ambientMode == 'purr' ? '🐱 呼噜' : '🎵 ASMR'),
                style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
              ),
            ),
          ),
        ],
        GestureDetector(
          onTap: _onNightLampTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: _isNightLampOn
                  ? (isNight ? const Color(0xFF312E81) : const Color(0xFFFEF3C7))
                  : (isNight ? const Color(0xFF1E1838) : Colors.white.withOpacity(0.96)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isNightLampOn ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8).withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isNightLampOn
                      ? const Color(0xFFF59E0B).withOpacity(0.4)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: _isNightLampOn ? 12 : 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_isNightLampOn ? '💡' : '💤', style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 3),
                Text(
                  _isNightLampOn ? 'ON' : 'OFF',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: _isNightLampOn ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 实体物理毛线球 (支持手指轻点弹跳、自由拖拽甩动与猫咪疾速追球飞扑)
  Widget _buildYarnBall(Size screenSize, bool isNight) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        SoundService.playPop();
        if (widget.petModel.enableHaptics) {
          HapticFeedback.mediumImpact();
        }
        final rnd = math.Random();
        final vx = (rnd.nextDouble() * 10.0 + 4.0) * (rnd.nextBool() ? 1.0 : -1.0);
        final vy = -(rnd.nextDouble() * 9.0 + 7.0);
        setState(() {
          _isYarnFlying = true;
          _isChasingYarn = true;
          _yarnVx = vx;
          _yarnVy = vy;
        });
        _spawnParticles(Offset(_yarnX, _yarnY), emoji: '🧶', count: 3);
      },
      onPanStart: (details) {
        setState(() {
          _isYarnDragging = true;
          _isYarnFlying = false;
          _isChasingYarn = false;
          _yarnVx = 0.0;
          _yarnVy = 0.0;
        });
      },
      onPanUpdate: (details) {
        setState(() {
          _yarnX += details.delta.dx;
          _yarnY += details.delta.dy;
          _yarnX = _yarnX.clamp(20.0, screenSize.width - 20.0);
          _yarnY = _yarnY.clamp(80.0, screenSize.height - 100.0);
        });
      },
      onPanEnd: (details) {
        final rawVx = details.velocity.pixelsPerSecond.dx / 60.0;
        final rawVy = details.velocity.pixelsPerSecond.dy / 60.0;
        final vx = rawVx.clamp(-18.0, 18.0);
        final vy = rawVy.clamp(-22.0, 18.0);
        final hasVelocity = vx.abs() > 0.8 || vy.abs() > 0.8;

        setState(() {
          _isYarnDragging = false;
          _isYarnFlying = hasVelocity;
          _isChasingYarn = true;
          _yarnVx = vx;
          _yarnVy = vy;
        });
        if (widget.petModel.enableHaptics) {
          HapticFeedback.lightImpact();
        }
      },
      child: Transform.rotate(
        angle: _yarnX * 0.05,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF1E1A40) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isNight ? const Color(0xFFF43F5E).withOpacity(0.6) : const Color(0xFFFBCFE8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF43F5E).withOpacity(isNight ? 0.25 : 0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Text('🧶', style: TextStyle(fontSize: 18)),
        ),
      ),
    );
  }
}
