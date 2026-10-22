import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet_model.dart';
import '../models/memo_model.dart';
import '../renderers/pet_painter.dart';
import 'backpack_drawer.dart';
import 'dialogs/feeding_dialog.dart';
import 'dialogs/action_dialog.dart';
import 'dialogs/memory_album_dialog.dart';
import 'memo_screen.dart';
import '../services/overlay_service.dart';
import '../services/sound_service.dart';
import '../services/minimax_service.dart';
import '../services/solar_service.dart';
import '../services/sensor_service.dart';
import '../services/haptic_service.dart';
import 'dialogs/gacha_dialog.dart';
import '../widgets/smart_dialogue_bubble.dart';
import 'physics/floor_footprints.dart';
import 'physics/yarn_ball_widget.dart';
import 'habitat/habitat_scene.dart';
import 'furniture/cat_dining_station.dart';
import 'furniture/cat_room_items.dart';
import 'docks/top_dual_islands.dart';
import 'docks/bottom_floating_bar.dart';
import 'docks/live_wardrobe_dock.dart';
import 'docks/live_action_dock.dart';
import 'docks/live_feeding_dock.dart';
import 'docks/cyber_gacha_fab.dart';
import '../services/backup_service.dart';
import 'dialogs/heritage_backup_dialog.dart';
import 'dialogs/ai_voice_chat_dialog.dart';

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
    this.fontSize = 13,
  });
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
  Timer? _blepTimer;
  String? _winkEye;
  Timer? _winkTimer;
  bool _isSlowBlink = false; // 慢眨眼“猫咪之吻”
  Timer? _slowBlinkTimer;
  bool _isWaterRippling = false; // 水碗波光粼粼涟漪
  Timer? _waterRippleTimer;

  // 方向二：沉浸式养宠仪式感 (拖拽投喂 + 睡垫盖小被子)
  // 手势防误触与体验优化：抚摸微动 vs 悬空拖拽解耦
  double _dragTotalDistance = 0.0;
  bool _hasExceededDragThreshold = false;

  /// 统一安全触觉震动反馈 (受设置 enableHaptics 严格约束)
  void _vibrate([String type = 'medium']) {
    if (!widget.petModel.enableHaptics) return;
    switch (type) {
      case 'selection':
        HapticFeedback.selectionClick();
        break;
      case 'light':
        HapticFeedback.lightImpact();
        break;
      case 'heavy':
        HapticFeedback.heavyImpact();
        break;
      case 'medium':
      default:
        HapticFeedback.mediumImpact();
        break;
    }
  }
  bool _showFoodTray = false;
  String? _draggingFoodId;
  String? _draggingFoodName;
  String? _draggingFoodIcon;
  Offset? _draggingFoodPos;
  bool _isCoveredWithBlanket = false;

  // 方向三：空间环境与天象治愈 (法式拱形观景窗 + 阳光光斑晒太阳)
  int _windowWeather = 0; // 0: ☀️ 阳光暖阳, 1: 🌧️ 细雨水滴, 2: 🌸 春日落樱, 3: 🌙 浪漫星空
  int _skyManualMode = -1; // -1: 自然天文自动, 0: 破晓晨曦, 1: 澄澈晴空, 2: 落日晚霞, 3: 静谧星夜

  // 地板粉嫩小猫爪印系统
  final List<Footprint> _footprints = [];
  Offset? _lastFootprintPos;
  bool _footprintLeft = false;

  // 维度二：毛线球物理与小鱼碗弹射
  double _yarnX = 0.0;
  double _yarnY = 0.0;
  double _yarnVx = 0.0;
  double _yarnVy = 0.0;
  double _yarnRollAngle = 0.0;
  int _yarnBatCount = 0;
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
  int _lastFloorTapTime = 0; // 地板轻敲双击召唤判定时间戳
  Offset _lastFloorTapPos = Offset.zero;

  // 飘浮爱心粒子列表
  final List<_Particle> _particles = [];

  // 对话气泡系统
  String _currentDialogue = '喵呜~ 戳戳我或者摸摸我的小脑瓜吧！(ฅ\'ω\'ฅ)';
  bool _showDialogue = true;

  // 手机端专属硬件感知与多指手势 (陀螺仪重力倾角与双指缩放)
  double _userScale = 1.0;
  double _baseScale = 1.0;
  double _tiltX = 0.0;

  // 画布级无遮挡换装模式 (免弹窗、零遮挡、实时全景预览)
  bool _isWardrobeMode = false;
  int _wardrobeTab = 0; // 0: 猫咪品种, 1: 头部, 2: 面部, 3: 颈部, 4: 背部, 5: 手持, 6: 小窝
  int _lastCatSlotTab = 0; // 记录最近选中的猫咪装扮部位 (0~5)，切回装扮模式时秒回原位

  // 画布级无遮挡专属绝活模式 (免弹窗、零遮挡、实时全景表演点播)
  bool _isActionMode = false;

  // 趣味交互：神奇激光笔逗猫模式 (指尖红点，小猫疯狂追扑)
  bool _isLaserMode = false;
  Offset? _laserPos;

  // 趣味家具交互状态 (猫草微晃、猫抓板震颤、夜灯开关、相框摇摆)
  bool _isNightLampOn = true;
  bool _isLampSwitchDepressed = false;
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

  // 细节优化增强状态：触碰果冻阻尼倾角、眼神注视机敏定时器、观景窗弹动缩放
  double _bodyTiltAngle = 0.0;
  Timer? _tiltTimer;
  Timer? _glanceTimer;
  double _windowScale = 1.0;

  // 6大高阶交互演进定时器
  Timer? _highFiveTimer;
  Timer? _drinkTimer;
  Timer? _grassNibbleTimer;
  Timer? _sprintTimer;
  Timer? _bunnyKickTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HapticService.enabled = widget.petModel.enableHaptics;

    _userScale = widget.petModel.userScale;

    // 手机专属硬件感知：陀螺仪/加速度计倾角与晃动检测
    SensorService.startListening();
    SensorService.onTilt = (tilt) {
      if (!mounted) return;
      setState(() {
        _tiltX = tilt;
      });
      // 待机时受倾角微小滑步走动
      if (_state == 'IDLE' && !_isDragging && !_isLaserMode && !_isWardrobeMode && !widget.petModel.isSleeping) {
        if (tilt.abs() > 0.45) {
          final moveStep = tilt * 1.8;
          _petX = (_petX + moveStep).clamp(45.0, _lastScreenSize.width - 45.0);
          _facingLeft = (tilt < 0);
        }
      }
    };
    SensorService.onShake = () {
      if (!mounted) return;
      if (_state != 'DIZZY') {
        HapticService.heavy();
        _playAction('DIZZY');
        _spawnParticles(Offset(_petX, _petY - 35), emoji: '💫', count: 1);
        _spawnParticles(Offset(_petX, _petY - 45), emoji: '⭐', count: 1);
        _showDialogueBubble('哎呀呀~ 手机晃得波可晕乎乎啦，眼冒金星啦！(◎_◎;)', duration: const Duration(seconds: 4));
      }
    };

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

    // 监听 PetModel 属性变更
    widget.petModel.addListener(_onModelUpdated);

    // 启动初始对话 (根据当前真实时段问候)
    final circadian = _getCircadianTheme();
    _showDialogueBubble(circadian['greeting'] as String, speak: true);

    // 方案 B：首启/重装后历史档案自动感知与一键继承探测，并预热高频小奶音
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkHeritageBackupOnLaunch();
      MinimaxService.instance.prewarmCommonVoices();
    });

    // 粒子飞升与物理帧驱动定时器 (60fps)
    _startParticleTimer();

    // 状态自然衰减与自言自语及自主微动作定时器
    _startDecayTimer();
  }

  /// 启动粒子飞升与物理帧驱动定时器
  void _startParticleTimer() {
    _particleTimer?.cancel();
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
          _yarnRollAngle += (_yarnVx * 0.08); // 旋转滚动物理
          _yarnVx *= 0.95;
          _yarnVy = (_yarnVy + 0.42) * 0.96;

          const minX = 24.0;
          final maxX = _lastScreenSize.width > 100 ? (_lastScreenSize.width - 24.0) : 340.0;
          final floorTop = (_lastScreenSize.height * 0.33).clamp(240.0, 290.0);
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

          if (dist > 48.0) {
            // 未抓住时：猫咪迈动小碎步疾速奔跑追赶！
            if (_state != 'WALK' && _state != 'PLAY_YARN') {
              _state = 'WALK';
            }
            final speed = math.min(dist * 0.16, 9.0);
            final norm = diff / dist;
            _petX += norm.dx * speed;
            _petY += norm.dy * speed;
            final floorTop = (_lastScreenSize.height * 0.33).clamp(240.0, 290.0);
            _petX = _petX.clamp(35.0, _lastScreenSize.width - 35.0);
            _petY = _petY.clamp(floorTop + 25.0, _lastScreenSize.height - 115.0);
            _maybeAddFootprint(Offset(_petX, _petY));
          } else {
            // 追上毛线球瞬间！真实生物天性：前 1~2 次追上时，探爪拍飞 (Bat & Swat)！
            if (_yarnBatCount < 2) {
              _yarnBatCount++;
              SoundService.playPop();
              _vibrate('medium');
              // 爪爪一拍，球球带着初速度向前弹开！
              final forwardDir = _facingLeft ? -1.0 : 1.0;
              final rnd = math.Random();
              _yarnVx = forwardDir * (rnd.nextDouble() * 7.0 + 8.0);
              _yarnVy = -(rnd.nextDouble() * 4.0 + 3.0);
              _isYarnFlying = true;
              _isChasingYarn = true;
              _spawnParticles(ballPos, emoji: '🐾', count: 3);
              _spawnParticles(ballPos, emoji: '💨', count: 2);
              _showDialogueBubble(
                _yarnBatCount == 1 ? '嗷呜！一爪拍飞~ 球球别跑，波可接着追！🐾💨' : '看波可无影快爪，再拍一下！(ฅ>ω<*ฅ)🧶',
                duration: const Duration(seconds: 3),
              );
            } else {
              // 飞扑抱球抓牢成功！(Pounce & Catch & Hug Roll)
              _yarnBatCount = 0;
              _isYarnFlying = false;
              _isChasingYarn = false;
              _yarnVx = 0.0;
              _yarnVy = 0.0;

              _yarnX = _petX + (_facingLeft ? -22.0 : 22.0);
              _yarnY = _petY + 44.0;

              _playAction('PLAY_YARN');
              _vibrate('heavy');

              _squishController.forward(from: 0.0);
              _spawnParticles(ballPos, emoji: '🧶', count: 4);
              _spawnParticles(ballPos, emoji: '✨', count: 3);
              _spawnParticles(Offset(_petX, _petY - 20), emoji: '🐾', count: 3);
              _spawnTextParticle(Offset(_petX - 35, _petY - 55), '抓牢抱球滚滚玩耍！🐾🧶', const Color(0xFFF43F5E));
              _spawnTextParticle(Offset(_petX + 25, _petY - 75), '+10 经验 ✨', const Color(0xFF6366F1));
              widget.petModel.addExp(10.0);
              widget.petModel.addIntimacy(4);
              _showDialogueBubble('哇！猛虎飞扑抓住毛线球啦！两只小爪爪抱紧紧滚来滚去~ 🧶🐾💕', duration: const Duration(seconds: 4), speak: true);

              _actionTimer?.cancel();
              _actionTimer = Timer(const Duration(milliseconds: 3800), () {
                if (mounted && _state == 'PLAY_YARN') {
                  setState(() => _state = 'SIT_WAG_TAIL');
                }
              });
            }
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
          _vibrate('medium');
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
  }

  /// 启动状态自然衰减与自言自语及自主微动作定时器
  void _startDecayTimer() {
    _decayTimer?.cancel();
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
  }

  /// 首启/重装后探测公共存储中的历史档案并呼出继承弹窗 (防卸载丢失)
  Future<void> _checkHeritageBackupOnLaunch() async {
    if (!mounted) return;
    // 等待 PetModel 完成底层载入，杜绝时序竞态
    await widget.petModel.isReady;

    final prefs = await SharedPreferences.getInstance();
    final bool hasDeclined = prefs.getBool('poko_heritage_declined') ?? false;

    // 探测公用目录与原生通道的历史备份
    final backup = await BackupService.checkHistoricalBackup();
    if (backup != null && mounted) {
      final petData = backup['pet'] as Map<String, dynamic>?;
      final backupLevel = (petData?['level'] as num?)?.toInt() ?? 1;
      final backupItems = (petData?['unlockedItems'] as List?)?.length ?? 0;
      final backupCoins = (petData?['coins'] as num?)?.toInt() ?? 200;

      // 智能继承判定：
      // 1. 全新安装 (isFreshInstall == true)
      // 2. 或者当前宠物为初生状态 (level == 1 且解锁装扮 <= 5) 且备份更有价值
      // 3. 或者备份等级明显高于当前本地等级
      final bool isCurrentPristine = widget.petModel.level == 1 && widget.petModel.unlockedItems.length <= 5;
      final bool hasSuperiorBackup = backupLevel > widget.petModel.level ||
          (isCurrentPristine && (backupLevel >= 2 || backupItems > 5 || backupCoins > 200));

      if (hasSuperiorBackup && !hasDeclined) {
        _showHeritageInheritDialog(backup);
        return;
      }
    }

    // 若未读取到备份，且当前处于 Android 初生状态，提示授权以扫描公共下载目录
    if (!kIsWeb && Platform.isAndroid && widget.petModel.level == 1 && !hasDeclined) {
      final hasPerm = await BackupService.isStoragePermissionGranted();
      final hasPromptedPerm = prefs.getBool('poko_storage_perm_prompted') ?? false;
      if (!hasPerm && !hasPromptedPerm && mounted) {
        await prefs.setBool('poko_storage_perm_prompted', true);
        _promptStoragePermissionGuidance();
      }
    }
  }

  /// 呼出历史波可档案继承确认弹窗
  void _showHeritageInheritDialog(Map<String, dynamic> backup) {
    if (!mounted) return;
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => HeritageBackupDialog(
        backupData: backup,
        isNight: _isNightMode,
        onInherit: () async {
          final ok = await BackupService.restoreFromHistoricalBackup(
            backup,
            widget.petModel,
            memo: widget.memoModel,
          );
          if (ok && mounted) {
            setState(() {});
            _playAction('HAPPY_SPIN');
            _spawnParticles(Offset(_petX, _petY - 20), emoji: '✨', count: 6);
            _showDialogueBubble('🎉 哇！成功找回了波可的全部记忆与装扮，欢迎回家主人~ ✨', duration: const Duration(seconds: 5));
          }
        },
        onDecline: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('poko_heritage_declined', true);
          if (mounted) {
            _showDialogueBubble('🐾 好的，新旅程开启！波可会一直陪着您~', duration: const Duration(seconds: 4));
          }
        },
      ),
    );
  }

  /// 首次初生状态引导授权扫描公共下载目录
  void _promptStoragePermissionGuidance() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: const Color(0xFFFFFDF9),
        title: const Row(
          children: [
            Text('🐾 ', style: TextStyle(fontSize: 22)),
            Text(
              '想要找回历史波可吗？',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF78350F),
              ),
            ),
          ],
        ),
        content: const Text(
          '检测到您当前波可处于初生状态。若您之前曾安装过波可，授权存储访问后即可自动扫描手机公共下载目录，找回以往的等级、金币与全部装扮！',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: Color(0xFF92400E),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('从头开始', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await BackupService.requestStoragePermission();
              Future.delayed(const Duration(milliseconds: 1200), () {
                if (mounted) _checkHeritageBackupOnLaunch();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('授权并扫描档案 ✨'),
          ),
        ],
      ),
    );
  }

  /// 手动触发扫描历史公共档案
  Future<void> _handleManualBackupScan() async {
    _idleSeconds = 0;
    SoundService.playClick();
    _vibrate('medium');

    // 1. 若为 Android 且无权限，先申请权限
    if (!kIsWeb && Platform.isAndroid) {
      final hasPerm = await BackupService.isStoragePermissionGranted();
      if (!hasPerm) {
        await BackupService.requestStoragePermission();
        _showDialogueBubble('📱 请在设置中开启存储权限，返回后波可将为您重新扫描公共目录~ 🐾', duration: const Duration(seconds: 4));
        return;
      }
    }

    // 2. 执行备份探测
    final backup = await BackupService.checkHistoricalBackup();
    if (backup != null && mounted) {
      _showHeritageInheritDialog(backup);
    } else {
      if (mounted) {
        _showDialogueBubble('🔍 公共目录中暂未找到历史备份文件 (poko_backup.json)。您也可以使用【导入口令恢复】哦~', duration: const Duration(seconds: 4));
      }
    }
  }

  /// 复制防丢口令码到剪贴板
  void _handleCopySaveCode() {
    _idleSeconds = 0;
    SoundService.playClick();
    _vibrate('medium');

    final code = BackupService.exportSaveCode(widget.petModel.toDataMap());
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      _spawnParticles(Offset(_petX, _petY - 20), emoji: '📋', count: 4);
      _showDialogueBubble('📋 防丢存档口令已复制到剪贴板！换机或重装时粘贴即可恢复全部等级与装扮~ ✨', duration: const Duration(seconds: 5));
    }
  }

  /// 粘贴口令码恢复档案弹窗
  void _handlePasteSaveCode() {
    _idleSeconds = 0;
    SoundService.playClick();
    _vibrate('light');

    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: const Color(0xFFFFFDF9),
        title: const Row(
          children: [
            Text('📥 ', style: TextStyle(fontSize: 22)),
            Text(
              '导入口令码恢复档案',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF78350F),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请粘贴之前导出的波可防丢口令码 (以 POKO# 开头)：',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E), height: 1.45),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'POKO#v2#...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFED7AA)),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded, color: Color(0xFFEA580C)),
                  tooltip: '读取剪贴板',
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      textCtrl.text = data!.text!.trim();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              final input = textCtrl.text.trim();
              if (input.isEmpty) return;
              final data = BackupService.importSaveCode(input);
              if (data == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('⚠️ 口令格式不正确或解析失败，请检查后重试')),
                );
                return;
              }
              Navigator.of(ctx).pop();
              final backupPayload = {'version': 2, 'savedAt': DateTime.now().toIso8601String(), 'pet': data};
              _showHeritageInheritDialog(backupPayload);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('解析并恢复 🚀'),
          ),
        ],
      ),
    );
  }

  /// 手动强制触发一份最新公共备份
  Future<void> _handleForceBackup() async {
    _idleSeconds = 0;
    SoundService.playClick();
    _vibrate('medium');

    await widget.petModel.saveToDisk();
    await widget.memoModel.saveToDisk();
    _spawnParticles(Offset(_petX, _petY - 20), emoji: '💾', count: 4);
    _showDialogueBubble('💾 已将当前波可状态 (Lv.${widget.petModel.level}) 完整备份至手机公共存储！', duration: const Duration(seconds: 4));
  }

  void _onModelUpdated() {
    HapticService.enabled = widget.petModel.enableHaptics;
    if (mounted) {
      setState(() {});
    }
  }

  DateTime? _lastPausedTime;

  /// 移动端节能模式：应用退到后台时深度暂停高频计时器与动效，降低 CPU/GPU 占用与电量消耗
  void _pauseBackgroundProcessing() {
    _idleAnimController.stop();
    _particleTimer?.cancel();
    _particleTimer = null;
    _decayTimer?.cancel();
    _decayTimer = null;
    _idleActionTimer?.cancel();
    _idleActionTimer = null;
  }

  /// 应用返回前台：无缝唤醒动画与计时器，并精确结算离线时间差
  void _resumeForegroundProcessing() {
    if (!_idleAnimController.isAnimating) {
      _idleAnimController.repeat();
    }
    _startParticleTimer();
    _startDecayTimer();

    if (_lastPausedTime != null) {
      final offlineSeconds = DateTime.now().difference(_lastPausedTime!).inSeconds;
      _lastPausedTime = null;
      if (offlineSeconds > 0) {
        // 离线状态平滑结算 (最多结算 12 小时 = 43200 秒)
        final effectiveSeconds = math.min(offlineSeconds, 43200);
        widget.petModel.tickDecay(effectiveSeconds.toDouble());
        if (effectiveSeconds >= 60 && mounted) {
          final mins = effectiveSeconds ~/ 60;
          _showDialogueBubble('波可刚才打了个小盹，已经过去 $mins 分钟啦~ 🐾', duration: const Duration(seconds: 4));
        }
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _lastPausedTime = DateTime.now();
      widget.petModel.flushSave();
      widget.memoModel.saveToDisk();
      SensorService.stopListening();
      _pauseBackgroundProcessing();
    } else if (state == AppLifecycleState.resumed) {
      SensorService.startListening();
      _resumeForegroundProcessing();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.petModel.flushSave();
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
    _blepTimer?.cancel();
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
    _tiltTimer?.cancel();
    _glanceTimer?.cancel();
    _highFiveTimer?.cancel();
    _drinkTimer?.cancel();
    _grassNibbleTimer?.cancel();
    _sprintTimer?.cancel();
    _bunnyKickTimer?.cancel();
    SensorService.stopListening();
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
    _vibrate('medium');
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
      if (widget.petModel.isFull) {
        _vibrate('light');
        _squishController.forward(from: 0.0);
        _spawnParticles(petHeadPos, emoji: '😋', count: 3);
        _spawnTextParticle(Offset(_petX - 35, _petY - 55), '肚皮圆滚滚~ (吃饱啦) 🐾', const Color(0xFFF59E0B));
        final fullQuotes = [
          '嗝~ 肚皮已经圆滚滚啦，实在吃不下啦！留着下一顿再吃好不好呀~',
          '波可的小肚子已经装得满满当当啦，再喂要变成猫猫球啦！',
          '好饱好满足呀！谢谢主人，等肚子消化一下再喂我吧~',
        ];
        _showDialogueBubble(fullQuotes[math.Random().nextInt(fullQuotes.length)], duration: const Duration(seconds: 4), speak: true);
        setState(() {
          _draggingFoodPos = null;
          _lookTargetPos = null;
        });
        return;
      }

      // 投喂成功！嗷呜飞扑吞食
      SoundService.playPop();
      _vibrate('heavy');
      _squishController.forward(from: 0.0);
      widget.petModel.feed(_draggingFoodId ?? 'dried_fish', allowWhenFull: false);
      widget.petModel.addIntimacy(intimacyGain);
      _spawnParticles(petHeadPos, emoji: foodIcon, count: 5);
      _spawnParticles(petHeadPos, emoji: '💖', count: 3);
      _spawnTextParticle(Offset(_petX - 35, _petY - 55), '+$hungerGain 饱腹  +$intimacyGain 亲密 💖', const Color(0xFFF43F5E));
      _triggerWink();
      if (math.Random().nextBool()) {
        _triggerBlep();
      }
      if (widget.petModel.hunger >= 90) {
        _spawnParticles(Offset(_petX, _petY - 20), emoji: '😋', count: 4);
        _spawnParticles(Offset(_petX, _petY - 35), emoji: '✨', count: 3);
        _showDialogueBubble('嗝~ 肚子吃得鼓囊囊的，好饱好幸福呀！😋💕', duration: const Duration(seconds: 4), speak: true);
        SoundService.startPurr();
        Timer(const Duration(milliseconds: 1600), () => SoundService.stopPurr());
      } else {
        _showDialogueBubble('嗷呜一大口！吃掉了$foodName，最喜欢主人啦~ 😋💕', speak: true);
      }

      // 吃完零食后 40% 概率口渴主动踱步去水碗饮水 (方向四：餐后补水习惯)
      if (math.Random().nextDouble() < 0.40) {
        Timer(const Duration(milliseconds: 1800), () {
          if (mounted && !_isDragging && !widget.petModel.isSleeping) {
            final floorTop = (_lastScreenSize.height * 0.33).clamp(240.0, 290.0);
            final nestY = floorTop + 130.0;
            _startWalkingTo(
              78.0,
              nestY + 72.0,
              'WATER_BOWL',
              '吃得香喷喷，嘴巴有点干啦~ 踱步去水碗喝口清甜的水水！💧🐾',
            );
          }
        });
      }

      setState(() {
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
    _vibrate('light');
    setState(() {
      _windowScale = 0.88;
      _windowWeather = (_windowWeather + 1) % 4;
    });
    Timer(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _windowScale = 1.0);
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

    // 春日落樱：全屏拂过一阵粉红花瓣微风
    if (_windowWeather == 2) {
      final sWidth = _lastScreenSize.width;
      _spawnParticles(Offset(sWidth * 0.25, 130), emoji: '🌸', count: 4);
      _spawnParticles(Offset(sWidth * 0.55, 110), emoji: '🌸', count: 5);
      _spawnParticles(Offset(sWidth * 0.80, 140), emoji: '🌸', count: 4);
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
    _vibrate('selection');

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
                    colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.06)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
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
                          '📅 陪伴第 ${widget.petModel.totalDays} 天 · 亲密值: ${widget.petModel.intimacy}',
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

  void _showDialogueBubble(
    String text, {
    Duration duration = const Duration(seconds: 4),
    bool speak = false,
  }) {
    if (!mounted) return;
    setState(() {
      _currentDialogue = text;
      _showDialogue = true;
    });
    // 当开启有声说话时，通过 MiniMax 萌系小奶音亲口朗读台词
    if (speak && SoundService.soundEnabled && SoundService.voiceSpeechEnabled) {
      MinimaxService.instance.speakPetVoice(text);
    }
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
      _triggerBlep();
    }

    if (_showDialogue) return;

    // 自发生理需求提醒 (优先于普通自言自语)
    if (widget.petModel.hunger < 35 && math.Random().nextDouble() < 0.35) {
      final hungryLines = [
        '咕噜噜... (肚子悄悄叫啦) 好想吃香喷喷的小鱼干呀~ 🥣🐟',
        '小肚肚空落落的... 主人，波可的小食碗在招手呢~ 🥣✨',
        '波可闻到零食的香味啦，主人要不要投喂一口酥脆酥罐呀？🥫🐾',
      ];
      _spawnParticles(Offset(_petX + 15, _petY - 35), emoji: '🐟', count: 1);
      _showDialogueBubble(hungryLines[math.Random().nextInt(hungryLines.length)]);
      return;
    }

    if (widget.petModel.energy < 25 && math.Random().nextDouble() < 0.35) {
      final tiredLines = [
        '哈欠~ (揉眼睛) 困意袭来啦，要不要早点盖被被呼呼睡呢~ 🥱💤',
        '眼皮有点打架啦... 主人长按小窝毛毯，让波可就寝吧~ 🛌✨',
      ];
      _spawnParticles(Offset(_petX + 15, _petY - 35), emoji: '💤', count: 1);
      _showDialogueBubble(tiredLines[math.Random().nextInt(tiredLines.length)]);
      return;
    }

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

  /// 释放轻柔微光特效粒子 (温润微光、柔和心芒，避免大串杂乱 emoji 喷射)
  void _spawnParticles(Offset pos, {String? emoji, int count = 1}) {
    final emojis = [emoji ?? '✨', '💕', '🐾'];
    final rnd = math.Random();
    for (int i = 0; i < count; i++) {
      final offsetX = (rnd.nextDouble() - 0.5) * 20;
      final offsetY = (rnd.nextDouble() - 0.5) * 16;
      _particles.add(_Particle(
        position: Offset(pos.dx + offsetX, pos.dy + offsetY),
        text: emojis[rnd.nextInt(emojis.length)],
        fontSize: 13,
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

  /// 触碰/戳戳萌宠 (以真实小奶音亲口说话，告别机械重复喵叫)
  void _onPetTap(Offset globalPos) {
    _idleSeconds = 0;
    _stopRoaming();
    _vibrate('medium');
    _squishController.forward(from: 0.0);
    _spawnParticles(Offset(_petX, _petY - 30), emoji: '💕', count: 1);

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
      '咕噜咕噜... 被主人摸得好舒服呀！💕',
      '波可的小脑袋随时供主人随意揉揉~ ✨',
      '嘿嘿！元气+100，主人今天也是最棒的！🐾',
    ];
    _showDialogueBubble(petLines[math.Random().nextInt(petLines.length)], speak: true);
  }

  /// 双击触发开心旋转绝活
  void _onPetDoubleTap() {
    _idleSeconds = 0;
    _stopRoaming();
    _vibrate('heavy');
    _playAction('HAPPY_SPIN');
    _spawnParticles(Offset(_petX, _petY - 40), emoji: '⭐', count: 1);
    _showDialogueBubble('看波可开心大回旋！主人笑一个嘛~ 🌀✨', speak: true);
  }

  void _playAction(String actionId) {
    _idleSeconds = 0;
    _stopRoaming();
    if (actionId == 'PLAY_YARN') {
      _isChasingYarn = false;
      _isYarnFlying = false;
      _yarnVx = 0.0;
      _yarnVy = 0.0;
      _yarnBatCount = 0;
      _yarnX = _petX + (_facingLeft ? -22.0 : 22.0);
      _yarnY = _petY + 44.0;
    } else {
      _isChasingYarn = false;
    }
    if (actionId == 'DOZE_OFF' || actionId == 'KNEADING_BISCUITS') {
      SoundService.startPurr();
    }
    _vibrate('medium');
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
      'HAPPY_SPIN': '看波可原地大漂移！疯狂追自己的小尾巴转圈圈~ 💫(✧ω✧)🐾',
      'CAT_STRETCH': '哈欠~~~ 伸个大大的猫式懒腰，小屁股翘高高，浑身舒展开啦！🥱✨',
      'HIGH_FIVE': '啪嗒！小爪爪和主人击掌啦~ 专属默契+100！(ฅ^ω^ฅ)🐾💕',
      'ROLL_ON_BACK': '呀啊~ 被挠到痒痒肉啦！翻个身把软乎乎的小肚皮露给主人摸~ (ฅ>ω<*ฅ)💕',
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
      'CAT_STRETCH': '🧘',
      'HIGH_FIVE': '✋',
      'ROLL_ON_BACK': '🐰',
      'DOZE_OFF': '💤',
      'DIZZY': '⭐',
    };

    final msg = actionLines[actionId] ?? '波可展现了独家才艺！✨';
    _showDialogueBubble(msg, duration: const Duration(seconds: 5));
    _spawnParticles(Offset(_petX, _petY - 40), emoji: actionEmojis[actionId], count: 1);

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

    final floorTop = (screenSize.height * 0.33).clamp(240.0, 290.0);
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
    final floorTop = (_lastScreenSize.height * 0.33).clamp(240.0, 290.0);
    final nestX = _lastScreenSize.width / 2;
    final nestY = floorTop + 130.0;

    switch (targetName) {
      case 'CAT_GRASS':
        _startNibblingGrass(floorTop);
        break;
      case 'SCRATCHING_POST':
        _onScratcherTap(false);
        _playAction('WASH_FACE');
        _showDialogueBubble('巡视剑麻猫抓柱~ 伸个懒腰准备磨爪爪！🪵🐾');
        break;
      case 'FOOD_BOWL':
        _popFishFromBowl(nestX, nestY);
        _playAction('LOOK_AROUND');
        _showDialogueBubble('来到小猫碗边啦~ 闻闻还有没有酥脆小鱼干！🥣😋');
        break;
      case 'WATER_BOWL':
        _startDrinkingWater(nestY);
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
        break;
    }
  }

  /// 优雅的半屏 BottomSheet 唤起，顶部半屏留空小猫互动演出
  void _showBottomSheetModal(Widget sheet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => sheet,
    );
  }

  /// 打开 MiniMax AI 语音陪伴小电台 (默认呼起麦克风即刻倾诉)
  void _openAiVoiceChatDialog({bool autoListen = true}) {
    _idleSeconds = 0;
    _isRoaming = false;
    _targetWalkX = null;
    SoundService.playPop();
    _vibrate('light');
    _spawnParticles(Offset(_petX, _petY - 20), emoji: '🎙️', count: 4);

    AiVoiceChatDialog.show(
      context,
      isNight: _isNightMode,
      autoStartListening: autoListen,
      onActionTriggered: (action, dialogue) {
        _handleAiVoiceAction(action, dialogue);
      },
    );
  }

  /// 执行 MiniMax AI 返回的拟真动作意图
  void _handleAiVoiceAction(String action, String dialogue) {
    _showDialogueBubble(dialogue, duration: const Duration(seconds: 5));
    switch (action.toUpperCase()) {
      case 'FEED':
        _playAction('EAT_FISH');
        widget.petModel.feed('dried_fish');
        _spawnParticles(Offset(_petX, _petY - 20), emoji: '🐟', count: 5);
        break;
      case 'SLEEP':
        if (!widget.petModel.isSleeping) {
          _isRoaming = false;
          _targetWalkX = null;
          widget.petModel.toggleSleep();
          SoundService.startPurr();
          _spawnParticles(Offset(_petX, _petY - 20), emoji: '💤', count: 5);
        }
        break;
      case 'SPIN':
        _playAction('HAPPY_SPIN');
        _spawnParticles(Offset(_petX, _petY - 20), emoji: '🌀', count: 6);
        break;
      case 'YARN':
        _teasePlay();
        break;
      case 'PET':
        _playAction('WASH_FACE');
        _spawnParticles(Offset(_petX, _petY - 20), emoji: '💖', count: 5);
        break;
      case 'BATH':
        widget.petModel.wash();
        _playAction('WASH_FACE');
        _spawnParticles(Offset(_petX, _petY - 20), emoji: '🫧', count: 6);
        break;
      default:
        break;
    }
  }

  /// 打开波可的奇妙背包上拉抽屉
  void _openBackpackDrawer(bool isNight) {
    _idleSeconds = 0;
    _isRoaming = false;
    _targetWalkX = null;
    SoundService.playClick();
    _vibrate('light');
    _showBottomSheetModal(
      PokoBackpackDrawer(
        model: widget.petModel,
        isNight: isNight,
        memoCount: widget.memoModel.content.trim().isNotEmpty ? 1 : 0,
        onFeedTap: () {
          _showBottomSheetModal(
            FeedingDialog(
              model: widget.petModel,
              isNight: isNight,
              onFeedSelected: (foodId) {
                final food = PetModel.foodMenu.firstWhere(
                  (f) => f['id'] == foodId,
                  orElse: () => PetModel.foodMenu.first,
                );
                final foodIcon = food['icon'] as String;
                final foodName = food['name'] as String;
                final hungerGain = (food['hunger'] as double).toInt();
                final expGain = (food['exp'] as double).toInt();

                if (widget.petModel.isFull) {
                  _vibrate('light');
                  _squishController.forward(from: 0.0);
                  _spawnParticles(Offset(_petX, _petY - 25), emoji: '😋', count: 3);
                  _spawnTextParticle(Offset(_petX - 35, _petY - 55), '肚皮圆滚滚~ (吃饱啦) 🐾', const Color(0xFFF59E0B));
                  final fullQuotes = [
                    '嗝~ 肚皮已经圆滚滚啦，实在吃不下啦！留着下一顿再吃好不好呀~',
                    '波可的小肚子已经装得满满当当啦，再喂要变成猫猫球啦！',
                    '好饱好满足呀！谢谢主人，等肚子消化一下再喂我吧~',
                  ];
                  _showDialogueBubble(fullQuotes[math.Random().nextInt(fullQuotes.length)], duration: const Duration(seconds: 4), speak: true);
                  return;
                }

                widget.petModel.feed(foodId, allowWhenFull: false);
                _vibrate('medium');

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
            _showDialogueBubble('睡饱醒来啦！元气活力充沛~ ☀️', speak: true);
          }
        },
        onToggleFloating: () {
          _handleFloatingTap();
        },
        onScanBackupTap: _handleManualBackupScan,
        onCopySaveCodeTap: _handleCopySaveCode,
        onPasteSaveCodeTap: _handlePasteSaveCode,
        onForceBackupTap: _handleForceBackup,
      ),
    );
  }

  /// 打开赛博星愿扭蛋盲盒 (零层级弹窗，带清脆弹跳与震动反馈)
  void _openGachaBottomSheet() {
    _idleSeconds = 0;
    _isRoaming = false;
    _targetWalkX = null;
    SoundService.playPop();
    _vibrate('light');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GachaDialog(
        model: widget.petModel,
        isNight: _isNightMode,
        onUpdated: () => setState(() {}),
      ),
    );
  }

  /// 趣味交互：开启神奇指尖激光笔
  void _startLaserChase() {
    _idleSeconds = 0;
    _stopRoaming();
    _isChasingYarn = false;
    _isYarnFlying = false;
    SoundService.playPop();
    final screenSize = MediaQuery.of(context).size;
    setState(() {
      _isLaserMode = true;
      _isWardrobeMode = false;
      _isActionMode = false;
      _laserPos = Offset(screenSize.width * 0.35, screenSize.height * 0.44);
      _state = 'IDLE';
    });
    _vibrate('medium');
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
    _vibrate('light');
    _spawnParticles(Offset(_petX - 30, _petY - 60), emoji: '🌠', count: 2);
    _spawnParticles(Offset(_petX + 30, _petY - 80), emoji: '⭐', count: 4);
    _spawnTextParticle(Offset(_petX - 30, _petY - 95), '流星许愿 +10 ⭐', const Color(0xFFFDE047));
    widget.petModel.addExp(10.0);
    _showDialogueBubble('哇！流星划过静谧星空啦~ 愿主人的愿望全部实现！⭐✨', duration: const Duration(seconds: 4));
  }

  /// 天象互动：白天晴空轻触 (微风甘露)
  void _onSunTap() {
    _vibrate('light');
    _spawnParticles(Offset(_petX - 60, _petY - 60), emoji: '🌈', count: 3);
    _spawnTextParticle(Offset(_petX - 25, _petY - 95), '晴空温煦 +10 ☀️', const Color(0xFFF59E0B));
    widget.petModel.addExp(10.0);
    _showDialogueBubble('微风拂过晴空，有波可陪伴的每一天都是大晴天~ ☀️🌈', duration: const Duration(seconds: 4));
  }

  /// 天象罗盘光影模式切换 (在真实自然天文与4大四季时角天光之间平滑循环流转)
  void _cycleSkyTheme() {
    _vibrate('medium');
    setState(() {
      if (_skyManualMode == -1) {
        _skyManualMode = 0; // 破晓晨曦
      } else if (_skyManualMode == 0) {
        _skyManualMode = 1; // 澄澈晴空
      } else if (_skyManualMode == 1) {
        _skyManualMode = 2; // 落日晚霞
      } else if (_skyManualMode == 2) {
        _skyManualMode = 3; // 静谧星夜
      } else {
        _skyManualMode = -1; // 回归真实自然天文
      }
    });

    final currentTheme = SolarService.getSkyTheme(manualMode: _skyManualMode);

    // 飘浮光影粒子与天象经验彩蛋
    _spawnParticles(Offset(_petX, _petY - 60), emoji: currentTheme.icon, count: 4);
    _spawnTextParticle(
      Offset(_petX - 35, _petY - 95),
      currentTheme.isManual ? '光影 · ${currentTheme.name} +10 ☀️' : '自然天文 · 自动流转 🌍✨',
      currentTheme.isNight ? const Color(0xFFC4B5FD) : const Color(0xFFF59E0B),
    );
    widget.petModel.addExp(10.0);

    String tip;
    if (currentTheme.isManual) {
      tip = currentTheme.greeting;
    } else {
      final st = currentTheme.solarTimes;
      tip = '已回归「自然天文·自动流转」，今日日出 ${st.sunriseStr}、日落 ${st.sunsetStr}，天空渐变随太阳时角每分钟连续平滑流光~ 🌍✨';
    }
    _showDialogueBubble(tip, duration: const Duration(seconds: 4));
  }

  /// 趣味交互：遮眼躲猫猫 (Peek-a-boo 藏头露尾) 开始
  void _startPeekABoo() {
    _idleSeconds = 0;
    _isRoaming = false;
    _targetWalkX = null;
    _vibrate('heavy');
    setState(() {
      _state = 'PEEK_A_BOO';
    });
    _spawnParticles(Offset(_petX, _petY - 30), emoji: '🙈', count: 3);
    _showDialogueBubble('看不见啦看不见啦~ 猜猜波可在哪里？(>_<)🙈', duration: const Duration(seconds: 4), speak: true);
  }

  /// 趣味交互：遮眼躲猫猫 抬手惊喜发现
  void _finishPeekABoo() {
    _idleSeconds = 0;
    _isRoaming = false;
    _targetWalkX = null;
    _vibrate('light');
    _squishController.forward(from: 0.0);
    setState(() {
      _state = 'HAPPY_SPIN';
    });
    _spawnParticles(Offset(_petX, _petY - 30), emoji: '🎉', count: 4);
    _spawnParticles(Offset(_petX, _petY - 30), emoji: '💖', count: 4);
    _spawnTextParticle(Offset(_petX - 35, _petY - 65), '躲猫猫大成功！✨', const Color(0xFFEC4899));
    _showDialogueBubble('哈哈！发现主人啦！扑个大满怀~ 喵呜！(✧ω✧)💕', duration: const Duration(seconds: 4), speak: true);
    _actionTimer?.cancel();
    _actionTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted && _state == 'HAPPY_SPIN') {
        setState(() => _state = 'IDLE');
      }
    });
  }

  /// 家具交互：猫草轻摇 (轻晃散发清香，诱发猫咪好奇小步跑来啃草)
  void _onPlantTap([bool walkIfFar = true]) {
    _idleSeconds = 0;
    SoundService.playGrassRustle();
    _vibrate('light');

    // 弹性轻摆多段物理回弹
    _plantAnimTimer?.cancel();
    setState(() => _plantTilt = 0.16);
    _plantAnimTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) {
        setState(() => _plantTilt = -0.10);
        _plantAnimTimer = Timer(const Duration(milliseconds: 160), () {
          if (mounted) {
            setState(() => _plantTilt = 0.05);
            _plantAnimTimer = Timer(const Duration(milliseconds: 140), () {
              if (mounted) setState(() => _plantTilt = 0.0);
            });
          }
        });
      }
    });

    final floorTop = (_lastScreenSize.height * 0.33).clamp(240.0, 290.0);
    const plantCenterX = 24.0 + 24.0;
    final plantCenterY = floorTop + 16.0 + 26.0;

    // 盆栽处飘出鲜嫩草叶与清香微粒子
    _spawnParticles(Offset(plantCenterX, plantCenterY - 10), emoji: '🌿', count: 4);
    _spawnParticles(Offset(plantCenterX + 12, plantCenterY - 15), emoji: '✨', count: 2);
    _spawnTextParticle(Offset(plantCenterX - 15, plantCenterY - 30), '猫草清香 🌿✨', const Color(0xFF10B981));

    // 判断猫咪是否已经在猫草旁边
    final isNearPlant = (_petX - (plantCenterX + 38.0)).abs() < 60.0 && (_petY - plantCenterY).abs() < 55.0;

    if (isNearPlant) {
      _startNibblingGrass(floorTop);
    } else if (walkIfFar && !_isDragging && !widget.petModel.isSleeping) {
      _showDialogueBubble('猫草清香扑鼻~ 迈着小碎步跑过去尝鲜咬一口！🌱🐾', duration: const Duration(seconds: 3), speak: true);
      _startWalkingTo(
        (plantCenterX + 38.0).clamp(35.0, _lastScreenSize.width - 35.0),
        plantCenterY,
        'CAT_GRASS',
        '猫草清香扑鼻~ 波可小步跑过去闻闻咬一小口！🌱😋',
      );
    }
  }

  /// 萌宠就餐角 · 专属啃猫草与调理肠胃仪式 (Cat Grass Nibbling & Digestion Ritual 🌿🌱)
  void _startNibblingGrass(double floorTop) {
    _stopRoaming();
    _idleSeconds = 0;
    _facingLeft = true;

    // Phase 1: 凑近轻嗅青草芳香
    _playAction('LOOK_AROUND');
    _vibrate('light');
    const plantCenterX = 24.0 + 24.0;
    final plantCenterY = floorTop + 16.0 + 26.0;

    _spawnParticles(Offset(plantCenterX, plantCenterY - 10), emoji: '🌿', count: 3);
    _spawnParticles(Offset(plantCenterX + 10, plantCenterY - 15), emoji: '✨', count: 2);
    _showDialogueBubble('凑近深吸一口~ 鲜嫩青草香气真好闻！准备下嘴啃嫩草啦~ (ฅ^ω^ฅ)🌱', duration: const Duration(seconds: 3));

    // Phase 2: 大口咀嚼进食动作 (伴随清脆咀嚼音效与水嫩绿叶微粒子)
    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      SoundService.playGrassRustle();
      _vibrate('medium');
      _playAction('EATING');

      // 盆栽微摇
      setState(() => _plantTilt = 0.12);
      Timer(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => _plantTilt = -0.08);
      });
      Timer(const Duration(milliseconds: 360), () {
        if (mounted) setState(() => _plantTilt = 0.0);
      });

      _spawnParticles(Offset(_petX - 25, _petY - 20), emoji: '🌱', count: 5);
      _spawnParticles(Offset(_petX - 15, _petY - 30), emoji: '🌿', count: 3);

      _grassNibbleTimer?.cancel();
      _grassNibbleTimer = Timer(const Duration(milliseconds: 2400), () {
        if (!mounted) return;
        // Phase 3: 肠胃舒畅满足结算 (调理肠胃，促进毛球排出)
        widget.petModel.addIntimacy(4);
        widget.petModel.addCleanliness(6);
        widget.petModel.addMood(8);
        widget.petModel.addExp(10.0);

        _spawnTextParticle(Offset(_petX - 35, _petY - 55), '排出毛球 · 肠胃舒畅 🌱✨', const Color(0xFF10B981));
        _spawnTextParticle(Offset(_petX + 25, _petY - 75), '+10 经验  +8 愉悦  +4 亲密 💖', const Color(0xFF059669));
        _spawnParticles(Offset(_petX, _petY - 20), emoji: '💖', count: 4);

        _triggerBlep();
        _triggerWink();
        SoundService.startPurr();
        Timer(const Duration(milliseconds: 1600), () => SoundService.stopPurr());

        _playAction('WASH_FACE');

        final grassQuotes = [
          '嗷呜咬下鲜嫩的小草尖！清甜脆嫩，肚肚里的毛球都被消化调理啦~ 🌿😋',
          '嚼嚼嚼~ 纯天然无公害有机猫草太棒啦！整只猫都神清气爽！🌱✨',
          '蹭蹭草叶~ 嘴巴里留着淡淡的青草清香，波可好喜欢这个盆栽！💚🐾',
        ];
        _showDialogueBubble(
          grassQuotes[math.Random().nextInt(grassQuotes.length)],
          duration: const Duration(seconds: 4),
          speak: true,
        );

        Timer(const Duration(milliseconds: 1800), () {
          if (mounted && _state == 'WASH_FACE') {
            setState(() => _state = 'IDLE');
          }
        });
      });
    });
  }

  /// 家具交互：原木剑麻猫抓柱磨爪 (真实解压利爪抓挠撕扯沙沙声 + 弹性震颤 + 真实木屑火花 + 猫咪惬意跑来磨爪)
  void _onScratcherTap([bool walkIfFar = true]) {
    _idleSeconds = 0;
    SoundService.playScratch();
    if (widget.petModel.enableHaptics) {
      _vibrate('medium');
      Timer(const Duration(milliseconds: 100), () {
        _vibrate('heavy');
        Timer(const Duration(milliseconds: 120), () {
          _vibrate('light');
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
    final floorTop = (_lastScreenSize.height * 0.33).clamp(240.0, 290.0);
    final postCenterX = _lastScreenSize.width - 24.0 - 24.0;
    final postCenterY = floorTop + 16.0 + 26.0;

    // 若猫咪距离猫抓柱较远，迈着欢快小碎步跑过去磨爪
    if (walkIfFar && ((_petX - postCenterX).abs() > 65.0) && !_isDragging && !widget.petModel.isSleeping) {
      _startWalkingTo(
        (postCenterX - 38.0).clamp(35.0, _lastScreenSize.width - 35.0),
        postCenterY,
        'SCRATCHING_POST',
        '迈着欢快的小碎步，跑去右上角剑麻柱磨爪爪啦！🐾🪵',
      );
    }

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

  /// 点击对话气泡彩蛋：轻戳气泡翻牌猫咪专属悄悄话心事 (以真实小奶音亲口诉说)
  void _onDialogueBubbleTap() {
    _idleSeconds = 0;
    _vibrate('light');
    _triggerWink();
    _spawnParticles(Offset(_petX, _petY - 35), emoji: '✨', count: 3);
    final secretLines = [
      '喵呜~ 主人戳我悄悄话啦！波可一直都在看着你哦~ (ฅ>ω<*ฅ)💕',
      '今天的主人也在闪闪发光呢！给主人打满分一百分！✨💯',
      '波可的小耳朵一直在听主人的心声，永远都陪着主人~ 👂🐾',
      '小爪子按个章：今天主人是最棒的，不接受反驳！🐾❤️',
      '呼噜噜... 只要主人摸摸头，波可浑身电量就充满啦！⚡🔋',
      '悄悄告诉主人：波可偷偷把最好的小鱼干藏在被窝留给你啦！🐟✨',
    ];
    _showDialogueBubble(secretLines[math.Random().nextInt(secretLines.length)], duration: const Duration(seconds: 4), speak: true);
  }

  /// 家具交互：开关萌猫小夜灯 (温润呼吸暖光与全屋夜眠氛围联动)
  void _onNightLampTap() {
    _idleSeconds = 0;
    SoundService.playClick();
    _vibrate('medium');
    setState(() {
      _isLampSwitchDepressed = true;
      _isNightLampOn = !_isNightLampOn;
    });
    Timer(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _isLampSwitchDepressed = false);
    });

    if (_isNightLampOn) {
      setState(() => _twitchEar = 'RIGHT');
      _earTwitchTimer?.cancel();
      _earTwitchTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _twitchEar = null);
      });
      _spawnParticles(Offset(_petX + 50, _petY), emoji: '💡', count: 4);
      _spawnParticles(Offset(_petX + 55, _petY - 20), emoji: '✨', count: 3);
      _spawnTextParticle(Offset(_petX + 35, _petY - 35), '暖光微亮 💡', const Color(0xFFFBBF24));
      _showDialogueBubble('啪嗒~ 暖光小夜灯点亮啦，守护波可的香甜美梦 💡', duration: const Duration(seconds: 4));
    } else {
      _spawnParticles(Offset(_petX + 50, _petY), emoji: '💤', count: 4);
      _spawnParticles(Offset(_petX + 50, _petY - 20), emoji: '🌙', count: 2);
      _spawnTextParticle(Offset(_petX + 35, _petY - 35), '小夜灯已熄灭 🌙', const Color(0xFF94A3B8));
      _showDialogueBubble('啪嗒~ 小夜灯熄灭啦，房间暗下来好助眠，晚安好梦~ 💤🌙', duration: const Duration(seconds: 4));
    }
  }

  /// 家具交互：点按标签切换房间治愈 ASMR 白噪音 (雨声 / 猫咪深度打呼噜 / 关闭)
  Future<void> _cycleAmbientSound() async {
    _idleSeconds = 0;
    _vibrate('heavy');
    final mode = await SoundService.cycleAmbientSound();
    setState(() {});

    if (mode == 'rain') {
      _spawnParticles(Offset(_petX + 50, _petY - 20), emoji: '🌧️', count: 4);
      _spawnParticles(Offset(_petX + 55, _petY), emoji: '💧', count: 3);
      _spawnTextParticle(Offset(_petX + 20, _petY - 45), '已开启窗外细雨 🌧️', const Color(0xFF38BDF8));
      _showDialogueBubble('🌧️ 窗外细雨沙沙作响，温柔雨声伴您进入深度专注心流~', duration: const Duration(seconds: 4));
    } else if (mode == 'purr') {
      _spawnParticles(Offset(_petX + 50, _petY - 20), emoji: '🐱', count: 4);
      _spawnParticles(Offset(_petX + 55, _petY), emoji: '🫧', count: 3);
      _spawnTextParticle(Offset(_petX + 20, _petY - 45), '已开启深度呼噜 🐱', const Color(0xFFA855F7));
      _showDialogueBubble('🐱 咕噜噜~ 波可发出深度解压呼噜声，超安神助眠~ (ฅ>ω<*ฅ)', duration: const Duration(seconds: 4));
    } else {
      _spawnParticles(Offset(_petX + 50, _petY - 20), emoji: '💡', count: 3);
      _spawnTextParticle(Offset(_petX + 20, _petY - 45), '房间回归宁静 💡', const Color(0xFFFBBF24));
      _showDialogueBubble('💡 已关闭环境白噪音，房间回归温馨安宁~', duration: const Duration(seconds: 3));
    }
  }

  /// 墙面装饰：拍立得照片墙摇晃并展开时光手账与纪念相册
  void _onPhotoTap() {
    _idleSeconds = 0;
    SoundService.playShutter();
    _vibrate('light');
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
      builder: (ctx) => MemoryAlbumDialog(
        model: widget.petModel,
        isNight: _isNightMode,
      ),
    );
  }

  /// 家具交互：轻触云朵暖暖窝 (波可舒适归窝，享受幸福踩奶特技与呼噜 ASMR)
  void _onBedTap(double nestX, double nestY) {
    _idleSeconds = 0;
    _stopRoaming();
    _isChasingYarn = false;
    _isYarnFlying = false;

    _vibrate('medium');

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
          _vibrate('selection');
        }
      });
    }

    _actionTimer?.cancel();
    _actionTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted && _state == 'KNEADING_BISCUITS') {
        SoundService.stopPurr();
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

  /// 方向二：指尖对掌与默契击掌 (High-Five & Finger Boop 🐾)
  void _triggerHighFive(Offset touchPos) {
    if (_isDragging || _isLaserMode || widget.petModel.isSleeping) return;
    _stopRoaming();
    _idleSeconds = 0;
    _vibrate('medium');
    setState(() {
      _state = 'HIGH_FIVE';
      _facingLeft = touchPos.dx < _petX;
    });
    _spawnParticles(touchPos, emoji: '✨', count: 1);
    _spawnTextParticle(Offset(touchPos.dx - 35, touchPos.dy - 40), '默契击掌 🐾💖', const Color(0xFFF43F5E));
    widget.petModel.addIntimacy(3);
    _triggerWink();
    _showDialogueBubble('啪嗒！小爪爪和主人击掌啦~ 专属默契+100！(ฅ^ω^ฅ)🐾💕', duration: const Duration(seconds: 4), speak: true);
    _highFiveTimer?.cancel();
    _highFiveTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted && _state == 'HIGH_FIVE') {
        setState(() => _state = 'IDLE');
      }
    });
  }

  /// 方向三：翻滚露肚皮与软萌小腹 (Roll on Back 🐾)
  void _triggerRollOnBack() {
    _stopRoaming();
    _idleSeconds = 0;
    _vibrate('light');
    _squishController.forward(from: 0.0);
    setState(() {
      _state = 'ROLL_ON_BACK';
    });
    _spawnParticles(Offset(_petX, _petY - 20), emoji: '💕', count: 1);
    _spawnTextParticle(Offset(_petX - 35, _petY - 50), '袒露软肚皮 💕', const Color(0xFFF43F5E));
    widget.petModel.addIntimacy(2);
    _showDialogueBubble('呀啊~ 被挠到痒痒肉啦！翻个身把软乎乎的小肚皮露给主人摸~ (ฅ>ω<*ฅ)💕', duration: const Duration(seconds: 4), speak: true);
    _bunnyKickTimer?.cancel();
    _bunnyKickTimer = Timer(const Duration(milliseconds: 3800), () {
      if (mounted && (_state == 'ROLL_ON_BACK' || _state == 'BUNNY_KICKS')) {
        setState(() => _state = 'IDLE');
      }
    });
  }

  /// 方向三：持续揉肚皮触发开心兔子蹬腿 (Bunny Kicks 🐰🐾)
  void _triggerBunnyKicks() {
    _stopRoaming();
    _idleSeconds = 0;
    SoundService.startPurr();
    _vibrate('medium');
    setState(() {
      _state = 'BUNNY_KICKS';
    });
    _spawnParticles(Offset(_petX, _petY - 15), emoji: '💖', count: 1);
    _spawnTextParticle(Offset(_petX - 35, _petY - 55), '兔子蹬腿 🐾🚴', const Color(0xFFEC4899));
    widget.petModel.addIntimacy(3);
    _showDialogueBubble('咕噜噜噜~ 别挠肚皮啦，小爪爪在空中踩单车停不下来啦！🐾🚴💕', duration: const Duration(seconds: 4));
    _bunnyKickTimer?.cancel();
    _bunnyKickTimer = Timer(const Duration(milliseconds: 3200), () {
      SoundService.stopPurr();
      if (mounted && (_state == 'ROLL_ON_BACK' || _state == 'BUNNY_KICKS')) {
        setState(() => _state = 'IDLE');
      }
    });
  }

  /// 方向四：就餐角小口饮水仪式 (Water Lapping 🥣💧)
  void _startDrinkingWater(double nestY) {
    _stopRoaming();
    _idleSeconds = 0;
    SoundService.playWaterLap();
    _vibrate('light');
    setState(() {
      _state = 'DRINK_WATER';
      _isWaterRippling = true;
      _facingLeft = true;
    });

    // 饮水过程水花四溅微粒子
    _spawnParticles(Offset(45.0, nestY + 80.0), emoji: '💧', count: 4);
    _spawnParticles(Offset(52.0, nestY + 75.0), emoji: '🫧', count: 2);
    _showDialogueBubble('吧唧吧唧~ 纯净水甘甜清冽，小猫咕嘟咕嘟喝水啦！💧(ฅ^ω^ฅ)', duration: const Duration(seconds: 3));

    Timer(const Duration(milliseconds: 1200), () {
      if (mounted && _state == 'DRINK_WATER') {
        _spawnParticles(Offset(45.0, nestY + 80.0), emoji: '💧', count: 3);
      }
    });

    _drinkTimer?.cancel();
    _drinkTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) {
        // 饮水完成结算身心属性并播放治愈呼噜
        widget.petModel.addCleanliness(8);
        widget.petModel.addMood(6);
        widget.petModel.addIntimacy(2);
        _spawnTextParticle(Offset(_petX - 35, _petY - 55), '+8 清洁  +6 愉悦  +2 亲密 💧✨', const Color(0xFF0284C7));
        _spawnParticles(Offset(_petX, _petY - 20), emoji: '💖', count: 3);
        _triggerBlep();
        _triggerWink();
        SoundService.startPurr();
        Timer(const Duration(milliseconds: 1600), () => SoundService.stopPurr());

        setState(() {
          _isWaterRippling = false;
          _state = 'WASH_FACE';
        });

        final drinkQuotes = [
          '咕嘟咕嘟~ 今天的清水甘甜又清凉，波可的小肚肚好舒服呀！(ฅ^ω^ฅ)💧',
          '呼~ 补充了满满的水分！舔舔胡须擦擦嘴，整只猫都神清气爽啦~ 🫧✨',
          '吧唧吧唧好满足！谢谢主人的新鲜清水，波可最喜欢喝水啦~ 💧💕',
        ];
        _showDialogueBubble(
          drinkQuotes[math.Random().nextInt(drinkQuotes.length)],
          duration: const Duration(seconds: 4),
          speak: true,
        );

        Timer(const Duration(milliseconds: 1800), () {
          if (mounted && _state == 'WASH_FACE') {
            setState(() => _state = 'IDLE');
          }
        });
      }
    });
  }

  /// 方向五：敲敲罐头瞬间冲刺狂奔召唤 (Can Spoon Tap & Sprint Summon 🥫)
  void _onCanSummonTap(double nestX, double nestY) {
    _stopRoaming();
    _idleSeconds = 0;
    SoundService.playCanChime();
    _vibrate('heavy');
    if (widget.petModel.isSleeping) {
      widget.petModel.wakeUp();
    }
    setState(() {
      _state = 'SPRINT';
      _isCoveredWithBlanket = false;
    });
    _spawnParticles(Offset(_petX, _petY - 20), emoji: '🥫', count: 4);
    _spawnParticles(Offset(_petX, _petY + 20), emoji: '💨', count: 3);
    _showDialogueBubble('罐头？！是开饭敲罐头的声音！！小猫全速飞奔而来啦——！！🥫💨', duration: const Duration(seconds: 4));

    // 全速冲刺位移至餐盘前方
    const targetX = 85.0;
    final targetY = nestY + 85.0;
    final startX = _petX;
    final startY = _petY;
    int step = 0;
    const totalSteps = 12;

    _sprintTimer?.cancel();
    _sprintTimer = Timer.periodic(const Duration(milliseconds: 28), (timer) {
      step++;
      final progress = (step / totalSteps).clamp(0.0, 1.0);
      final curve = Curves.easeInOutCubic.transform(progress);
      if (mounted) {
        setState(() {
          _petX = startX + (targetX - startX) * curve;
          _petY = startY + (targetY - startY) * curve;
          _facingLeft = targetX < startX;
          _maybeAddFootprint(Offset(_petX, _petY));
        });
      }
      if (step >= totalSteps) {
        timer.cancel();
        if (mounted) {
          _squishController.forward(from: 0.0);
          setState(() {
            _state = 'IDLE';
            _showFoodTray = true;
          });
          _spawnParticles(Offset(_petX, _petY - 20), emoji: '😋', count: 3);
          _spawnParticles(Offset(_petX, _petY - 35), emoji: '✨', count: 3);
          _showDialogueBubble('报告主人！波可已飞奔就位，小碗空空求加餐！(๑´ڡ`๑)🥫💕', duration: const Duration(seconds: 4), speak: true);
        }
      }
    });
  }

  /// 方向六：睡眠唤醒猫式伸展拉伸瑜伽仪式 (Gentle Wake-up & Cat Stretch Yoga 🧘‍♀️)
  void _wakeUpWithCatYoga() {
    _stopRoaming();
    _idleSeconds = 0;
    SoundService.stopPurr();
    _vibrate('light');
    // 阶段 1：揉揉睡眼洗小脸
    setState(() {
      _state = 'WASH_FACE';
      _isCoveredWithBlanket = false;
    });
    _spawnParticles(Offset(_petX, _petY - 20), emoji: '🫧', count: 3);
    _showDialogueBubble('呼呜... 睡得好香呀，揉揉睡眼惺忪的小脸蛋~ 🫧', duration: const Duration(milliseconds: 1400));

    Timer(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      // 阶段 2：正宗猫式大伸展
      _vibrate('medium');
      setState(() {
        _state = 'CAT_STRETCH';
      });
      _spawnParticles(Offset(_petX, _petY - 25), emoji: '🥱', count: 3);
      _spawnParticles(Offset(_petX + 30, _petY - 40), emoji: '✨', count: 3);
      _showDialogueBubble('哈欠~~~ 伸个大大的猫式懒腰，小屁股翘高高，浑身舒展开啦！🥱✨', duration: const Duration(seconds: 3));

      Timer(const Duration(milliseconds: 2200), () {
        if (!mounted) return;
        // 阶段 3：欢喜抖毛，精神百倍
        _squishController.forward(from: 0.0);
        if (widget.petModel.isSleeping) {
          widget.petModel.toggleSleep();
        }
        setState(() {
          _state = 'IDLE';
        });
        _showDialogueBubble('睡饱伸展完毕！波可元气满满，准备好和主人玩耍啦~ ☀️🐾', speak: true);
      });
    });
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
    _highFiveTimer?.cancel();
    if (_lookTargetPos != null) {
      setState(() => _lookTargetPos = null);
    }
  }

  /// 墙面装饰：温暖小串灯轻触 (一闪一闪亮晶晶)
  void _onFairyLightsTap() {
    _idleSeconds = 0;
    SoundService.playClick();
    _vibrate('light');
    _spawnParticles(Offset(_petX - 40, 85), emoji: '✨', count: 3);
    _spawnParticles(Offset(_petX + 40, 85), emoji: '🌟', count: 3);
    _showDialogueBubble('暖黄小串灯一闪一闪的，小窝变得好温馨呀~ ✨💡', duration: const Duration(seconds: 4));
  }

  /// 当前昼夜状态 (与主界面昼夜节律一致, 供各类弹层统一取用)
  bool get _isNightMode => _getCircadianTheme()['isNight'] as bool;

  /// 真实太阳天文算法与四季时角光影主题 (基于分钟进度 Color.lerp 平滑流光)
  Map<String, dynamic> _getCircadianTheme() {
    final theme = SolarService.getSkyTheme(manualMode: _skyManualMode);
    return {
      'name': theme.name,
      'icon': theme.icon,
      'colors': theme.colors,
      'isNight': theme.isNight,
      'greeting': theme.greeting,
      'phaseName': theme.phaseName,
      'solarTimes': theme.solarTimes,
      'isManual': theme.isManual,
    };
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
      _footprints.add(Footprint(
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

  /// 揪尾巴炸毛微互动：触发触电惊跳、高频电波甩尾与亲口嗔怪台词
  void _triggerTailBoop() {
    _idleSeconds = 0;
    _stopRoaming();
    if (widget.petModel.enableHaptics) {
      _vibrate('heavy');
      Timer(const Duration(milliseconds: 120), () {
        _vibrate('light');
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
    _spawnParticles(Offset(tailParticleX, _petY), emoji: '💨', count: 1);

    final tailQuotes = [
      '喵呜？！谁在偷抓波可的尾巴！尾巴是敏感禁区喵~ 😾💢',
      '哈！尾巴炸毛啦！不许偷偷拉小猫咪的天线！⚡(>﹏<)',
      '喵呜呜~ 尾巴尖尖被碰到了，浑身电波噼里啪啦！💨⚡',
      '尾巴防御系统启动！波可要哈气啦~ 哼！😾🐾',
    ];
    _showDialogueBubble(tailQuotes[math.Random().nextInt(tailQuotes.length)], duration: const Duration(seconds: 4), speak: true);
  }

  /// 触发猫咪极度满足的呼噜状态 (Purr Haptic Engine + ASMR)
  void _triggerPurringState({String? customDialogue}) {
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
          HapticService.purrHaptic();
          _spawnParticles(Offset(_petX + (purrTick.isEven ? -18 : 18), _petY - 24), emoji: '💕', count: 1);
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
    _spawnParticles(Offset(_petX, _petY - 30), emoji: '💕', count: 1);
    _showDialogueBubble(customDialogue ?? '咕噜咕噜... 下巴挠得好舒服，要融化在主人手心啦~ (˘ω˘)💕', duration: const Duration(seconds: 4));
  }

  /// 维度一：部位差异化触感与猫咪打呼噜反应
  void _handleBodyPartTouch(Offset localPos, Size screenSize) {
    _idleSeconds = 0;
    _isRoaming = false;
    _targetWalkX = null;

    // 方向六：触碰睡眠中的猫咪，触发正宗猫式伸展唤醒仪式
    if (widget.petModel.isSleeping || _state == 'DOZE_OFF') {
      _wakeUpWithCatYoga();
      return;
    }

    // 方向三：若已处于翻肚皮态，继续揉按触发高频兔子蹬腿
    if (_state == 'ROLL_ON_BACK' || _state == 'BUNNY_KICKS') {
      _triggerBunnyKicks();
      return;
    }

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
      _vibrate('light');
      setState(() => _isBlep = false);
      _spawnParticles(Offset(_petX, _petY - 20), emoji: '✨', count: 1);
      _spawnTextParticle(Offset(_petX - 35, _petY - 45), '收回小舌头~ (ฅ^ω^ฅ)', const Color(0xFFF43F5E));
      _showDialogueBubble('呀！被主人戳到小舌头啦，哧溜缩回来！👅✨');
      return;
    }

    // 1. 点粉嫩小鼻子 (Nose Boop - 触发短促俏皮打喷嚏并亲口说话)
    if ((localPos.dx - 100).abs() < 14 && (localPos.dy - 93).abs() < 10) {
      SoundService.playPop();
      _vibrate('light');
      _squishController.forward(from: 0.0);
      setState(() => _bodyTiltAngle = -0.04);
      _tiltTimer?.cancel();
      _tiltTimer = Timer(const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _bodyTiltAngle = 0.0);
      });
      _spawnParticles(Offset(_petX, _petY - 25), emoji: '✨', count: 1);
      _showDialogueBubble('阿嚏！(>﹏<) 戳到波可敏感的小鼻尖啦~ 🐾', duration: const Duration(seconds: 4), speak: true);
      return;
    }

    // 2. 挠下巴 / 颈窝 (Chin Scratch - 触发猫咪打呼噜连续细密震动与真实ASMR喉音起伏)
    if ((localPos.dx - 100).abs() < 24 && (localPos.dy >= 99 && localPos.dy <= 122)) {
      _triggerPurringState();
      return;
    }

    // 3. 触摸左耳 (俏皮机敏轻抖耳廓)
    if (localPos.dx >= 45 && localPos.dx <= 88 && localPos.dy >= 18 && localPos.dy <= 62) {
      _vibrate('light');
      setState(() {
        _twitchEar = 'LEFT';
        _bodyTiltAngle = -0.05;
      });
      _tiltTimer?.cancel();
      _tiltTimer = Timer(const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _bodyTiltAngle = 0.0);
      });
      _earTwitchTimer?.cancel();
      _earTwitchTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _twitchEar = null);
      });
      _spawnParticles(Offset(_petX - 35, _petY - 50), emoji: '✨', count: 1);
      _showDialogueBubble('左耳朵机灵抖抖~ 听到主人的心声啦！👂✨');
      return;
    }

    // 4. 触摸右耳 (俏皮机敏轻抖耳廓)
    if (localPos.dx >= 112 && localPos.dx <= 155 && localPos.dy >= 18 && localPos.dy <= 62) {
      _vibrate('light');
      setState(() {
        _twitchEar = 'RIGHT';
        _bodyTiltAngle = 0.05;
      });
      _tiltTimer?.cancel();
      _tiltTimer = Timer(const Duration(milliseconds: 260), () {
        if (mounted) setState(() => _bodyTiltAngle = 0.0);
      });
      _earTwitchTimer?.cancel();
      _earTwitchTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _twitchEar = null);
      });
      _spawnParticles(Offset(_petX + 35, _petY - 50), emoji: '✨', count: 1);
      _showDialogueBubble('右耳朵抖一抖~ 喵呜！右侧雷达收到！👂🐾');
      return;
    }

    // 5. 捏两腮包子脸 (Cheek Pinch - 软糯亲昵物理弹性挤压)
    final isLeftCheek = (localPos.dx >= 52 && localPos.dx <= 84 && localPos.dy >= 70 && localPos.dy <= 104);
    final isRightCheek = (localPos.dx >= 116 && localPos.dx <= 148 && localPos.dy >= 70 && localPos.dy <= 104);
    if (isLeftCheek || isRightCheek) {
      _vibrate('light');
      _squishController.forward(from: 0.0);
      setState(() => _bodyTiltAngle = isLeftCheek ? 0.07 : -0.07);
      _tiltTimer?.cancel();
      _tiltTimer = Timer(const Duration(milliseconds: 280), () {
        if (mounted) setState(() => _bodyTiltAngle = 0.0);
      });
      _spawnParticles(Offset(_petX, _petY - 20), emoji: '✨', count: 1);
      _showDialogueBubble('唔姆~ 脸颊肉肉要被主人捏圆啦！(ฅ\'ω\'ฅ)', duration: const Duration(seconds: 4));
      return;
    }

    // 方向二：摸前爪肉垫触发默契击掌 (High Five 🐾)
    if (localPos.dy >= 142) {
      _triggerHighFive(Offset(_petX + (localPos.dx - 100), _petY + (localPos.dy - 100)));
      return;
    }

    // 方向三：挠软萌小腹肚皮 (Belly Rub -> 翻滚露肚皮)
    if (localPos.dy >= 105 && localPos.dy < 142 && (localPos.dx - 100).abs() < 40) {
      _triggerRollOnBack();
      return;
    }

    // 6. 摸肉垫 / 肚皮其他区域
    if (localPos.dy > 120) {
      final floorTop = (screenSize.height * 0.33).clamp(240.0, 290.0);
      final nestX = screenSize.width / 2;
      final nestY = floorTop + 130.0;
      if ((_petX - nestX).abs() < 25 && (_petY - nestY).abs() < 25) {
        _onBedTap(nestX, nestY);
        return;
      }
      _triggerHighFive(Offset(_petX + (localPos.dx - 100), _petY + (localPos.dy - 100)));
      return;
    }

    // 7. 头部一般触碰
    _onPetTap(Offset(_petX, _petY));
  }

  /// 方向一：慢眨眼“猫咪之吻” (Slow Blink - 表达爱意与极致信任)
  void _triggerSlowBlink() {
    if (!mounted || _isSlowBlink || _state != 'IDLE') return;
    setState(() => _isSlowBlink = true);
    _vibrate('light');
    _spawnParticles(Offset(_petX, _petY - 35), emoji: '💖', count: 1);
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
    _blepTimer?.cancel();
    _blepTimer = Timer(duration, () {
      if (mounted) setState(() => _isBlep = false);
    });
  }

  /// 维度五：跑过来贴贴屏幕 (Glass Boop)
  void _triggerGlassBoop(Size screenSize) {
    if (!mounted || _state == 'GLASS_BOOP' || _isDragging) return;
    _isRoaming = false;
    _targetWalkX = null;
    setState(() {
      _state = 'GLASS_BOOP';
      _hasGlassPawPrints = true;
      _pawPrints = [
        Offset(_petX - 38, _petY + 22),
        Offset(_petX + 38, _petY + 22),
      ];
    });
    _vibrate('heavy');
    _showDialogueBubble('波可跑来贴贴屏幕啦！主人也在看波可嘛？(ฅ\'ω\'ฅ)💕', duration: const Duration(seconds: 4), speak: true);

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
      _poppingFishPos = Offset(38.0, nestY + 52.0);
    });
    _vibrate('medium');
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
    _showDialogueBubble('逗猫时间到！毛线球飞起来啦，波可快去追~ 🧶💨', duration: const Duration(seconds: 4));
  }

  /// 轻触空白背景区域：眼神机敏注视追踪与双击轻敲地板呼唤 (Eye Glance & Floor Calling)
  void _onBackgroundPointerDown(Offset globalPos, Size screenSize) {
    if (_isDragging || _isLaserMode || _showFoodTray || _isWardrobeMode || _isActionMode || widget.petModel.isSleeping) return;

    final floorTop = (screenSize.height * 0.33).clamp(240.0, 290.0);
    final nestX = screenSize.width / 2;
    final nestY = floorTop + 130.0;
    final relX = globalPos.dx - _petX;
    final relY = globalPos.dy - _petY;
    final dist = math.sqrt(relX * relX + relY * relY);

    // 智能双击地板检测 (Floor Double-Tap Calling - 仅限开阔地板空白处，绝不干扰猫咪自身抚摸与家具按钮)
    final isNearCat = dist < 75.0;
    final isNearBed = (globalPos.dx - nestX).abs() < 85 && (globalPos.dy - nestY).abs() < 60;
    final isNearDining = globalPos.dx < 130 && (globalPos.dy - nestY).abs() < 85;
    final isOnFloor = globalPos.dy >= floorTop + 25 && globalPos.dy <= screenSize.height - 85;

    if (isOnFloor && !isNearCat && !isNearBed && !isNearDining) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final isDoubleTap = (now - _lastFloorTapTime < 340) && ((globalPos - _lastFloorTapPos).distance < 48.0);
      _lastFloorTapTime = now;
      _lastFloorTapPos = globalPos;

      if (isDoubleTap) {
        _highFiveTimer?.cancel();
        _onFloorDoubleTap(globalPos, screenSize);
        return;
      }
    }
    // 点击在猫咪外部时，猫咪机敏转动眼珠与耳尖注视指尖落点
    if (dist > 50.0 && dist < 340.0) {
      setState(() {
        _lookTargetPos = Offset(relX, relY);
        _twitchEar = relX < 0 ? 'LEFT' : 'RIGHT';
      });
      _glanceTimer?.cancel();
      _glanceTimer = Timer(const Duration(milliseconds: 1300), () {
        if (mounted && !_isDragging) {
          setState(() {
            _lookTargetPos = null;
            _twitchEar = null;
          });
          _triggerWink();
        }
      });

      // 方向二：在猫咪身前长按手指 (> 450ms) 触发指尖对掌击掌
      _highFiveTimer?.cancel();
      if (dist >= 50.0 && dist <= 165.0 && relY >= -25.0 && relY <= 90.0) {
        _highFiveTimer = Timer(const Duration(milliseconds: 450), () {
          if (mounted && !_isDragging && _state != 'HIGH_FIVE') {
            _triggerHighFive(globalPos);
          }
        });
      }
    }
  }

  /// 双击地板空白处：轻敲地面呼唤唤回波可 (Floor Double-Tap Calling)
  void _onFloorDoubleTap(Offset targetPos, Size screenSize) {
    if (_isDragging || _isLaserMode || _showFoodTray || _isWardrobeMode || _isActionMode) return;
    if (widget.petModel.isSleeping) {
      _showDialogueBubble('波可正在被窝里熟睡呢，轻轻摸摸头唤醒它吧~ 💤');
      return;
    }

    _vibrate('medium');
    SoundService.playPop();

    // 敲击地板处泛起微光小波纹与爪印
    _spawnParticles(targetPos, emoji: '🐾', count: 1);
    _spawnTextParticle(Offset(targetPos.dx - 22, targetPos.dy - 24), '哒哒！✨', const Color(0xFF6366F1));

    // 唤起波可敏捷小跑靠近指尖落点
    final floorTop = (screenSize.height * 0.33).clamp(240.0, 290.0);
    final targetX = targetPos.dx.clamp(45.0, screenSize.width - 45.0);
    final targetY = targetPos.dy.clamp(floorTop + 20.0, screenSize.height - 85.0);

    _showDialogueBubble('来啦来啦~ 听见主人的呼唤，小跑过来啦！🐾✨', duration: const Duration(seconds: 3));
    _startWalkingTo(targetX, targetY, 'CALL_SUMMON', '来啦来啦~ 听见主人的呼唤，小跑过来啦！🐾✨');
  }

  /// 长按小窝圆垫：自动钻进被窝就寝入眠 (Cozy Nest Long-Press to Sleep)
  void _onBedLongPress(double nestX, double nestY) {
    if (widget.petModel.isSleeping) {
      _toggleBlanket();
      return;
    }
    _vibrate('medium');
    SoundService.startPurr();
    setState(() {
      _petX = nestX;
      _petY = nestY;
      _isCoveredWithBlanket = true;
      _state = 'IDLE';
    });
    widget.petModel.sleep();
    _spawnParticles(Offset(nestX, nestY - 20), emoji: '💤', count: 3);
    _showDialogueBubble('钻进温暖被窝啦~ 晚安主人，做个香甜好梦！🛌✨', duration: const Duration(seconds: 4));
  }

  @override
  Widget build(BuildContext context) {
    final rawSize = MediaQuery.of(context).size;
    final screenSize = Size(
      rawSize.width > 50 ? rawSize.width : 360.0,
      rawSize.height > 50 ? rawSize.height : 780.0,
    );
    _lastScreenSize = screenSize;

    // 房间空间黄金分割：
    // 踢脚线与地板起始位置：在上方约 22%，给宽敞木地板留足 78% 空间
    final floorTop = (screenSize.height * 0.33).clamp(240.0, 290.0);
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
    final isNight = circadian['isNight'] as bool;
    final habitat = widget.petModel.habitat;
    List<Color> gradientColors = (circadian['colors'] as List<Color>?) ?? const [Color(0xFF140F2D), Color(0xFF1D1742)];
    if (gradientColors.isEmpty) {
      gradientColors = const [Color(0xFF140F2D), Color(0xFF1D1742)];
    }
    if (habitat == 'neon_matrix') {
      gradientColors = const [Color(0xFF0A0F1D), Color(0xFF131D36), Color(0xFF032238)];
    } else if (habitat == 'retro_arcade') {
      gradientColors = const [Color(0xFF1E1035), Color(0xFF4C1D95), Color(0xFF831843), Color(0xFFD97706)];
    } else if (habitat == 'summer_beach') {
      gradientColors = isNight
          ? const [Color(0xFF0B132B), Color(0xFF1C2541), Color(0xFF0F766E)]
          : const [Color(0xFF38BDF8), Color(0xFF7DD3FC), Color(0xFFBAE6FD), Color(0xFFFEF3C7)];
    } else if (habitat == 'zen_tatami') {
      gradientColors = isNight
          ? const [Color(0xFF1C1917), Color(0xFF292524), Color(0xFF3D3835)]
          : const [Color(0xFFFAF7F2), Color(0xFFF3ECE2), Color(0xFFE5DDD0)];
    }

    // 维度二：毛线球位于前侧宽敞开阔地板上
    if (!_yarnInitialized && screenSize.width > 0) {
      _yarnX = screenSize.width * 0.5;
      _yarnY = nestY + 155.0;
      _yarnInitialized = true;
    }

    final bool hasActiveOverlay = _isWardrobeMode || _isActionMode || _showFoodTray || _isLaserMode;

    return PopScope(
      canPop: !hasActiveOverlay,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleSystemBack();
      },
      child: Scaffold(
      body: Listener(
        onPointerDown: (event) => _onBackgroundPointerDown(event.position, screenSize),
        onPointerHover: (event) => _onPointerHoverOrMove(event.position),
        onPointerMove: (event) => _onPointerHoverOrMove(event.position),
        onPointerUp: (_) => _onPointerUpOrExit(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
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
                // 助眠专注氛围：细雨微动粒子 (Rain ASMR Active，包裹 AnimatedBuilder 实现丝滑流动)
                if (SoundService.ambientMode == 'rain')
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _idleAnimController,
                        builder: (context, _) {
                          return Stack(
                            children: [
                              for (int i = 0; i < 14; i++)
                                Positioned(
                                  left: ((i * 27.0 + _idleAnimController.value * 350.0) % screenSize.width),
                                  top: ((i * 59.0 + _idleAnimController.value * 650.0) % screenSize.height),
                                  child: Container(
                                    width: 1.5,
                                    height: 12.0,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.28),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                // 背景微光氛围天象 (清晨/正午/日落/星夜，支持点击天象交互彩蛋)
                if (isNight) ...[
                  // 漫天静谧微星 (支持轻触交互，飘出星光)
                  Positioned(
                    top: 112,
                    left: 28,
                    child: GestureDetector(
                      onTap: _onMoonTap,
                      child: Text('✨', style: TextStyle(fontSize: 16, color: const Color(0xFFFDE047).withValues(alpha: 0.7))),
                    ),
                  ),
                  Positioned(
                    top: 150,
                    right: 70,
                    child: GestureDetector(
                      onTap: _onMoonTap,
                      child: Text('⭐', style: TextStyle(fontSize: 13, color: Colors.amber.shade100.withValues(alpha: 0.6))),
                    ),
                  ),
                  Positioned(
                    top: 205,
                    left: 50,
                    child: GestureDetector(
                      onTap: _onMoonTap,
                      child: Text('✨', style: TextStyle(fontSize: 14, color: Colors.yellow.shade100.withValues(alpha: 0.5))),
                    ),
                  ),
                  Positioned(
                    top: 170,
                    left: 110,
                    child: GestureDetector(
                      onTap: _onMoonTap,
                      child: Text('⭐', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4))),
                    ),
                  ),
                ] else ...[
                  // 白天环境氛围 (云朵轻触触发晴空微风彩蛋)
                  Positioned(
                    top: 145,
                    left: 24,
                    child: GestureDetector(
                      onTap: _onSunTap,
                      child: Text('☁️', style: TextStyle(fontSize: 22, color: Colors.white.withValues(alpha: 0.6))),
                    ),
                  ),
                ],

              // 0.1 房间立体景深：根据小窝场景 (Habitat) 自适应定制地台与地面
              Positioned(
                top: floorTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: HabitatFlooring(
                      habitat: habitat,
                      isNight: isNight,
                      idleAnimation: _idleAnimController,
                    ),
                  ),
                ),
              ),

              // 0.2~0.4 场景背景软装与家具：根据小窝场景 DIY 体系自适应呈现
              ...HabitatBackdropBuilder.buildBackdrop(
                habitat: habitat,
                isNight: isNight,
                screenSize: screenSize,
                floorTop: floorTop,
                idleAnimation: _idleAnimController,
                defaultDecorations: [
                  Positioned(
                    top: 92,
                    left: 18,
                    right: 18,
                    child: Transform.translate(
                      offset: Offset(_tiltX * -6.0, 0),
                      child: FairyLightsRow(isNight: isNight, onTap: _onFairyLightsTap),
                    ),
                  ),
                  Positioned(
                    top: 138,
                    left: 18,
                    child: Transform.translate(
                      offset: Offset(_tiltX * -8.0, 0),
                      child: PolaroidFrame(isNight: isNight, photoAngle: _photoAngle, onTap: _onPhotoTap),
                    ),
                  ),
                  Positioned(
                    top: 92,
                    left: screenSize.width / 2 - 43,
                    child: Transform.translate(
                      offset: Offset(_tiltX * -10.0, 0),
                      child: FrenchArchWindow(
                        isNight: isNight,
                        windowWeather: _windowWeather,
                        windowScale: _windowScale,
                        onTap: _cycleWindowWeather,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24.0,
                    top: floorTop + 16.0,
                    child: AnimatedOpacity(
                      opacity: _isWardrobeMode ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _isWardrobeMode,
                        child: CatGrassPlanter(isNight: isNight, plantTilt: _plantTilt, onTap: _onPlantTap),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 24.0,
                    top: floorTop + 16.0,
                    child: AnimatedOpacity(
                      opacity: _isWardrobeMode ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _isWardrobeMode,
                        child: CatScratchingPost(isNight: isNight, postWiggle: _postWiggle, onTap: _onScratcherTap),
                      ),
                    ),
                  ),
                ],
              ),

              // 维度二：飞跃弹跳的小鱼 (弧线投喂到猫咪嘴边)
              if (_fishPopping && _poppingFishPos != null)
                Positioned(
                  left: _poppingFishPos!.dx,
                  top: _poppingFishPos!.dy,
                  child: const IgnorePointer(
                    child: Text('🐟', style: TextStyle(fontSize: 22)),
                  ),
                ),

              // 软装家具 4：右侧照明角 · 暖光小夜灯大范围呼吸光晕 (开灯时温暖漫反射笼罩就寝区)
              if (_isNightLampOn)
                Positioned(
                  right: -30.0,
                  top: nestY + 20.0,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _idleAnimController,
                      builder: (context, _) {
                        final pulse = 1.0 + math.sin(_idleAnimController.value * 2 * math.pi) * 0.04;
                        return Transform.scale(
                          scale: pulse,
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  (isNight ? const Color(0xFFFDE047) : const Color(0xFFFBBF24)).withValues(alpha: 0.38),
                                  (isNight ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B)).withValues(alpha: 0.14),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // 关灯夜眠全景光影滤镜 (全屋柔和渐暗，星空与安睡氛围凸显)
              if (!_isNightLampOn)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 1.1,
                          colors: [
                            (isNight ? const Color(0xFF070417) : Colors.black).withValues(alpha: 0.44),
                            (isNight ? const Color(0xFF03010C) : Colors.black).withValues(alpha: 0.54),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 软装家具 4：右侧照明角 · 床头猫咪小台灯 (置于右侧地板，轻触“啪嗒”拉绳开关台灯)
              Positioned(
                right: 20.0,
                top: nestY + 86.0,
                child: AnimatedOpacity(
                  opacity: _isWardrobeMode ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: _isWardrobeMode,
                    child: KittenNightLamp(
                      isNight: isNight,
                      isNightLampOn: _isNightLampOn,
                      isLampSwitchDepressed: _isLampSwitchDepressed,
                      onLampTap: _onNightLampTap,
                    ),
                  ),
                ),
              ),

              // 阳光暖阳下木地板柔和光斑
              if (_windowWeather == 0 && !isNight)
                SunbeamPatch(nestX: nestX, nestY: nestY, idleAnimation: _idleAnimController),

              // 春日落樱轻盈飘落花瓣 (轻触化作粉红光尘消散)
              if (_windowWeather == 2)
                ...SakuraPetalsBuilder.build(
                  screenSize: screenSize,
                  idleAnimation: _idleAnimController,
                  onPetalTap: (index, x, y) {
                    SoundService.playPop();
                    _vibrate('light');
                    _spawnParticles(Offset(x + 10, y + 10), emoji: '🌸', count: 3);
                    _spawnParticles(Offset(x + 10, y + 10), emoji: '✨', count: 2);
                    _spawnTextParticle(Offset(x - 15, y - 20), '落樱轻抚 🌸+1💖', const Color(0xFFF43F5E));
                    widget.petModel.addIntimacy(1);
                    _showDialogueBubble('轻触飘落的樱花瓣~ 化作粉红微尘消散在风中啦！(🌸´▽`🌸)', duration: const Duration(seconds: 3));
                  },
                ),

              // 萌宠专属舒睡暖绒圆垫 (极简轻奢，铺展于猫咪身后地板上，猫咪坐于其上)
              CatRugBed(
                nestX: nestX,
                nestY: nestY,
                isNight: isNight,
                onTap: () => _onBedTap(nestX, nestY),
              ),

              // 地板粉嫩小猫爪印层 (2.5D 木地板巡视与冲刺追球时淡隐脚印)
              if (_footprints.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: FootprintPainter(
                          _footprints,
                          habitat: widget.petModel.habitat,
                        ),
                      ),
                    ),
                  ),
                ),

              // 顶部双灵动岛浮空栏 (左侧萌宠身份 + 右侧饱腹心情小窝，告别拥挤，自然呼吸)
              Positioned(
                top: 10,
                left: 14,
                right: 14,
                child: RepaintBoundary(
                  child: TopDualIslands(
                    petModel: widget.petModel,
                    screenSize: screenSize,
                    isNight: isNight,
                    circadianTheme: circadian,
                    isManualSky: _skyManualMode != -1,
                    ambientMode: SoundService.ambientMode,
                    onAmbientToggle: _cycleAmbientSound,
                    onIntimacyTap: _showIntimacyBondModal,
                    onSoundToggle: () {
                      setState(() {
                        SoundService.soundEnabled = !SoundService.soundEnabled;
                      });
                      if (SoundService.soundEnabled) {
                        _showDialogueBubble('波可的声音已开启啦！🐾', speak: true);
                      }
                    },
                    onFootprintsToggle: () {
                      setState(() {
                        widget.petModel.toggleFootprints();
                        if (!widget.petModel.enableFootprints) {
                          _footprints.clear();
                        }
                      });
                      _vibrate('light');
                      _showDialogueBubble(
                        widget.petModel.enableFootprints
                            ? '已开启温润小猫肉垫爪印~ 🐾'
                            : '已收起爪印，保持地板纯净洁白✨',
                        duration: const Duration(seconds: 3),
                      );
                    },
                    onSkyRhythmToggle: _cycleSkyTheme,
                  ),
                ),
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
                  onScaleStart: (details) {
                    _baseScale = _userScale;
                    if (details.pointerCount == 1) {
                      _dragTotalDistance = 0.0;
                      _hasExceededDragThreshold = false;
                      _strokeDistance = 0.0;
                      _dragDirectionReversals = 0;
                      _lastDragDirection = 0.0;
                      _lastDragTime = DateTime.now();
                      _touchPos = details.localFocalPoint;
                    }
                  },
                  onScaleUpdate: (details) {
                    // 双指捏合无级缩放 (0.75x ~ 1.45x)
                    if (details.pointerCount >= 2) {
                      final newScale = (_baseScale * details.scale).clamp(0.75, 1.45);
                      if ((newScale - _userScale).abs() > 0.015) {
                        setState(() {
                          _userScale = newScale;
                        });
                        _vibrate('selection');
                      }
                      return;
                    }

                    // 单指拖拽与抚摸 (带位移阈值阻尼防误触)
                    final now = DateTime.now();
                    final dt = now.difference(_lastDragTime).inMilliseconds;
                    _lastDragTime = now;

                    final deltaDist = details.focalPointDelta.distance;
                    _dragTotalDistance += deltaDist;

                    // 移动超过 16 像素阈值才正式认定为悬空拖拽，彻底解决原地顺毛/揉肚子被误抓起的痛点
                    if (!_hasExceededDragThreshold && _dragTotalDistance > 16.0) {
                      _hasExceededDragThreshold = true;
                      _isDragging = true;
                      _stopRoaming();
                      _isChasingYarn = false;
                      _isYarnFlying = false;
                      if (_state != 'DIZZY') {
                        _state = 'DANGLING';
                      }
                    }

                    setState(() {
                      if (_hasExceededDragThreshold) {
                        _petX += details.focalPointDelta.dx;
                        _petY += details.focalPointDelta.dy;

                        // 限制萌宠不出屏幕
                        _petX = _petX.clamp(35.0, screenSize.width - 35.0);
                        _petY = _petY.clamp(minSafeY, maxSafeY);

                        _facingLeft = (details.focalPointDelta.dx < -0.8);
                      }
                      _touchPos = details.localFocalPoint;

                      // 高频剧烈左右晃动眩晕检测 (仅在真正悬空拖拽中生效)
                      if (_hasExceededDragThreshold) {
                        final curDx = details.focalPointDelta.dx;
                        if (curDx.abs() > 4.5 && dt < 80) {
                          final dir = curDx > 0 ? 1.0 : -1.0;
                          if (_lastDragDirection != 0.0 && dir != _lastDragDirection) {
                            _dragDirectionReversals++;
                            if (_dragDirectionReversals >= 5 && _state != 'DIZZY') {
                              _state = 'DIZZY';
                              _dragDirectionReversals = 0;
                              _vibrate('heavy');
                              _spawnParticles(Offset(_petX, _petY - 45), emoji: '💫', count: 1);
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
                      }

                      // 抚摸交互：慢速拂过累加抚摸进度，触发呼噜微震与爱心漫溢
                      if (deltaDist > 1.5 && deltaDist < 14.0) {
                        _strokeDistance += deltaDist;
                        if (_strokeDistance > 46.0) {
                          _strokeDistance = 0.0;
                          _petProgress = 1.0;
                          _vibrate('selection');
                          if (!_isPurring) {
                            _triggerPurringState(customDialogue: '呼噜噜... 好舒服呀，最喜欢主人的温柔抚摸啦~ 💕🐾');
                          }
                          final emojis = ['💕', '✨', '🌸', '🐾'];
                          final pickedEmoji = emojis[math.Random().nextInt(emojis.length)];
                          _spawnParticles(
                            Offset(_petX, _petY - 40),
                            emoji: pickedEmoji,
                            count: 1,
                          );
                        }
                      }
                    });
                  },
                  onScaleEnd: (details) {
                    _baseScale = _userScale;
                    widget.petModel.setUserScale(_userScale);
                    widget.petModel.saveToDisk();

                    final wasDragging = _hasExceededDragThreshold;
                    _dragTotalDistance = 0.0;
                    _hasExceededDragThreshold = false;

                    setState(() {
                      _isDragging = false;
                      _touchPos = null;
                      _petProgress = 0.0;
                      _dragDirectionReversals = 0;

                      if (!wasDragging) {
                        if (_state == 'DANGLING') _state = 'IDLE';
                        return;
                      }

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

                      // 拖放于暖绒圆垫中心时，直接触发幸福踩奶特技
                      if ((_petX - nestX).abs() < 42.0 && (_petY - nestY).abs() < 42.0) {
                        _onBedTap(nestX, nestY);
                        return;
                      }

                      // 拖拽释放平稳平滑着陆，回归自然待机状态
                      if (_state != 'DIZZY') {
                        _state = 'IDLE';
                        _squishController.forward(from: 0.0);
                        _vibrate('light');
                        _spawnParticles(Offset(_petX, _petY + 28), emoji: '💨', count: 2);
                        _spawnParticles(Offset(_petX, _petY + 28), emoji: '🐾', count: 2);
                      }
                    });
                  },
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_idleAnimController, _squishController]),
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _bodyTiltAngle,
                        child: Transform.scale(
                          scaleX: _squishScaleX.value,
                          scaleY: _squishScaleY.value,
                          child: RepaintBoundary(
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
                                isHunting: (_isLaserMode || _isChasingYarn || _state == 'PLAY_YARN' || _state == 'CATCH_MOUSE' || _draggingFoodPos != null || _showFoodTray || (widget.petModel.hunger < 50 && _state == 'IDLE')),
                                isTailPuffed: _isTailPuffed,
                                isAirplaneEars: _isAirplaneEars,
                                isBlep: _isBlep,
                                isSlowBlink: _isSlowBlink,
                                winkEye: _winkEye,
                                isNight: isNight,
                                userScale: _userScale,
                                tiltX: _tiltX,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 暖绒圆垫前侧轻触响应区 (位于圆垫前缘，零遮挡猫爪，支持轻触圆垫触发幸福踩奶，长按一键入眠)
              CozyCatRug(
                nestX: nestX,
                nestY: nestY,
                onTap: () => _onBedTap(nestX, nestY),
                onLongPress: () => _onBedLongPress(nestX, nestY),
              ),

              // 软装家具 3：左侧就餐角 · 萌宠立式三联食水一体托盘 (换装模式自动淡出，纯净聚焦)
              Positioned(
                left: 16.0,
                top: nestY + 36.0,
                child: AnimatedOpacity(
                  opacity: _isWardrobeMode ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: _isWardrobeMode,
                    child: RepaintBoundary(
                      child: CatDiningStation(
                      isNight: isNight,
                      isHungry: widget.petModel.hunger < 50,
                      showFoodTray: _showFoodTray,
                      isWaterRippling: _isWaterRippling,
                      isDrinking: _state == 'DRINK_WATER',
                      onFoodBowlTap: () {
                        SoundService.playPop();
                        _vibrate('light');
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
                      onFoodBowlDoubleTap: () => _popFishFromBowl(nestX, nestY),
                      onWaterBowlTap: () {
                        // 播放清澈注水水滴音效与轻触反馈
                        SoundService.playWaterDrop();
                        _vibrate('light');
                        setState(() {
                          _isWaterRippling = true;
                        });
                        _spawnParticles(Offset(42, nestY + 80), emoji: '💧', count: 5);
                        _spawnParticles(Offset(48, nestY + 70), emoji: '✨', count: 3);
                        _spawnTextParticle(Offset(32, nestY + 55), '注满清冽甘泉 💧✨', const Color(0xFF0284C7));

                        if (_state == 'DRINK_WATER') {
                          _showDialogueBubble('添入新鲜甘泉啦！水质格外清冽冰凉~ 咕嘟咕嘟！💧✨', duration: const Duration(seconds: 3), speak: true);
                          return;
                        }

                        final isNearBowl = (_petX - 78.0).abs() < 80 && (_petY - (nestY + 72.0)).abs() < 75;

                        if (isNearBowl) {
                          _showDialogueBubble('闻到清甜纯净水的气味啦~ 凑近水碗吧唧吧唧喝大口！💧(ฅ^ω^ฅ)', duration: const Duration(seconds: 3), speak: true);
                          _startDrinkingWater(nestY);
                        } else {
                          _showDialogueBubble('听到清脆的倒水声啦！踱步过去喝清甜纯净水~ 💧🐾', duration: const Duration(seconds: 3), speak: true);
                          _startWalkingTo(
                            78.0,
                            nestY + 72.0,
                            'WATER_BOWL',
                            '添了清澈纯净水~ 踱步去水碗喝口清甜水水！💧🐾',
                          );
                        }

                        _waterRippleTimer?.cancel();
                        _waterRippleTimer = Timer(const Duration(milliseconds: 3000), () {
                          if (mounted && _state != 'DRINK_WATER') {
                            setState(() => _isWaterRippling = false);
                          }
                        });
                      },
                      onCanSummonTap: () => _onCanSummonTap(nestX, nestY),
                    ),
                  ),
                ),
              ),
              ),

              // 暖绒舒睡圆垫小被子 (随呼吸起伏，支持盖被被与掀被被微互动，换装模式自动淡出)
              CoveredBlanket(
                nestX: nestX,
                nestY: nestY,
                petX: _petX,
                petY: _petY,
                isNight: isNight,
                isCoveredWithBlanket: _isCoveredWithBlanket,
                idleAnimation: _idleAnimController,
                isWardrobeMode: _isWardrobeMode,
                onToggleBlanket: _toggleBlanket,
                onBlanketTap: () {
                  SoundService.startPurr();
                  _vibrate('light');
                  _spawnParticles(Offset(_petX, _petY - 20), emoji: '💤', count: 3);
                  final sleepyQuotes = [
                    '呼呜... (梦话) 最喜欢主人了... 💤',
                    '被窝里好暖和好舒服，呼噜噜... (˘ω˘)🛌',
                    '再睡五分钟嘛主人... 翻个身把小爪子缩进被窝~ 🐾',
                  ];
                  _showDialogueBubble(sleepyQuotes[math.Random().nextInt(sleepyQuotes.length)]);
                },
              ),

              // 维度二：开阔活动地板：实体物理毛线球 (在猫咪扑玩期间隐藏外部球，玩耍结束后恢复在猫爪旁)
              if (_state != 'PLAY_YARN')
                Positioned(
                  key: const ValueKey('floor_yarn_ball'),
                  left: _yarnX - 22,
                  top: _yarnY - 22,
                  child: YarnBallWidget(
                    rollAngle: _yarnRollAngle,
                    isNight: isNight,
                    isFlying: _isYarnFlying,
                    onTap: () {
                      SoundService.playPop();
                      _vibrate('medium');
                      _yarnBatCount = 0; // 重置拍球计数
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
                        _yarnBatCount = 0;
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _yarnX += details.delta.dx;
                        _yarnY += details.delta.dy;
                        _yarnRollAngle += details.delta.dx * 0.08;
                        _yarnX = _yarnX.clamp(20.0, screenSize.width - 20.0);
                        _yarnY = _yarnY.clamp(80.0, screenSize.height - 100.0);
                      });
                    },
                    onPanEnd: (details) {
                      final rawVx = details.velocity.pixelsPerSecond.dx / 60.0;
                      final rawVy = details.velocity.pixelsPerSecond.dy / 60.0;
                      final vx = rawVx.clamp(-18.0, 18.0);
                      final vy = rawVy.clamp(-22.0, 18.0);
                      setState(() {
                        _isYarnDragging = false;
                        _isYarnFlying = true;
                        _isChasingYarn = true;
                        _yarnVx = vx;
                        _yarnVy = vy;
                      });
                    },
                  ),
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
                            color: const Color(0xFFF43F5E).withValues(alpha: 0.32),
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
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.2),
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
                        _vibrate('light');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFBCFE8), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEC4899).withValues(alpha: 0.12),
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

              // 4. 浮空特效粒子层 (温润微光、柔和心芒与文字飘升)
              for (final p in _particles)
                Positioned(
                  key: p.id,
                  left: p.position.dx - (p.fontSize / 2),
                  top: p.position.dy - (p.fontSize / 2),
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1.0 - math.pow(p.progress, 1.2)).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: p.progress < 0.25
                            ? (0.7 + p.progress * 1.4)
                            : (1.05 - (p.progress - 0.25) * 0.25),
                        child: Text(
                          p.text,
                          style: TextStyle(
                            fontSize: p.fontSize,
                            fontWeight: FontWeight.w600,
                            color: p.color,
                            shadows: p.color != null
                                ? [
                                    Shadow(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      blurRadius: 3,
                                    ),
                                  ]
                                : [
                                    Shadow(
                                      color: const Color(0xFFF472B6).withValues(alpha: 0.35),
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
              if (_showDialogue)
                SmartDialogueBubble(
                  screenSize: screenSize,
                  isNight: isNight,
                  petX: _petX,
                  petY: _petY,
                  showFoodTray: _showFoodTray,
                  currentDialogue: _currentDialogue,
                  onTap: _onDialogueBubbleTap,
                ),

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
                                  const Color(0xFFEF4444).withValues(alpha: 0.55),
                                  const Color(0xFFEF4444).withValues(alpha: 0.0),
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
                  top: 76,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: GestureDetector(
                      onTap: _stopLaserChase,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF991B1B).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF87171), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
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

              // 6. 底部交互控制：常态下三灵动胶囊；进入对应模式呈现画布级无遮挡点播坞/换装坞/投喂坞 (固定稳定渲染，杜绝任何跳动)
              if (_isWardrobeMode)
                LiveWardrobeDock(
                  petModel: widget.petModel,
                  isNight: isNight,
                  wardrobeTab: _wardrobeTab,
                  onTabChanged: (tab) {
                    setState(() {
                      _wardrobeTab = tab;
                      if (tab < 6) _lastCatSlotTab = tab;
                    });
                  },
                  onSkinSelected: (skinId) {
                    if (widget.petModel.enableHaptics) HapticService.light();
                    setState(() {
                      widget.petModel.setSkin(skinId);
                    });
                    _spawnParticles(Offset(_petX, _petY - 20), emoji: '✨', count: 3);
                  },
                  onDecorationSelected: (slot, itemId) {
                    setState(() {
                      widget.petModel.setDecoration(slot, itemId);
                    });
                    _spawnParticles(Offset(_petX, _petY - 20), emoji: '🎀', count: 3);
                  },
                  onHabitatSelected: (habitatId, icon) {
                    if (widget.petModel.enableHaptics) HapticService.light();
                    setState(() {
                      widget.petModel.setHabitat(habitatId);
                    });
                    _spawnParticles(Offset(_petX, _petY - 20), emoji: icon, count: 3);
                  },
                  onGachaTap: _openGachaBottomSheet,
                  onClose: () {
                    _vibrate('light');
                    setState(() => _isWardrobeMode = false);
                  },
                  onShowDialogue: (msg) => _showDialogueBubble(msg),
                )
              else if (_isActionMode)
                LiveActionDock(
                  isNight: isNight,
                  currentState: _state,
                  actions: ActionDialog.actions,
                  onActionSelected: (actionId) => _playAction(actionId),
                  onClose: () {
                    _vibrate('light');
                    setState(() => _isActionMode = false);
                  },
                )
              else if (_showFoodTray)
                LiveFeedingDock(
                  isNight: isNight,
                  currentHunger: widget.petModel.hunger,
                  isFull: widget.petModel.isFull,
                  foodMenu: PetModel.foodMenu,
                  onFoodTap: (id, name, icon, hunger, intimacyGain) {
                    _draggingFoodId = id;
                    _draggingFoodName = name;
                    _draggingFoodIcon = icon;
                    _draggingFoodPos = Offset(_petX, _petY - 20);
                    _finishDragToFeed(hunger, intimacyGain);
                    _spawnParticles(Offset(_petX, _petY - 20), emoji: icon, count: 4);
                  },
                  onFoodPanStart: (id, name, icon, details) {
                    setState(() {
                      _draggingFoodId = id;
                      _draggingFoodName = name;
                      _draggingFoodIcon = icon;
                      _draggingFoodPos = details.globalPosition;
                      _lookTargetPos = _draggingFoodPos! - Offset(_petX, _petY);
                    });
                    _vibrate('selection');
                  },
                  onFoodPanUpdate: (details) {
                    setState(() {
                      _draggingFoodPos = details.globalPosition;
                      _lookTargetPos = _draggingFoodPos! - Offset(_petX, _petY);
                    });
                  },
                  onFoodPanEnd: (hunger, intimacyGain) {
                    _finishDragToFeed(hunger, intimacyGain);
                  },
                  onClose: () {
                    _vibrate('light');
                    setState(() => _showFoodTray = false);
                  },
                )
              else
                BottomFloatingBar(
                  isNight: isNight,
                  onBackpackTap: () => _openBackpackDrawer(isNight),
                  onWardrobeTap: () {
                    _idleSeconds = 0;
                    _isRoaming = false;
                    _targetWalkX = null;
                    SoundService.playClick();
                    _vibrate('light');
                    setState(() {
                      _isWardrobeMode = true;
                      _isActionMode = false;
                      _wardrobeTab = _lastCatSlotTab;
                    });
                    _spawnParticles(Offset(_petX, _petY - 20), emoji: '👗', count: 3);
                    _showDialogueBubble('装扮小窝已就绪！自由搭配猫咪穿戴与 5 大家园主题全屏房间~ ✨', duration: const Duration(seconds: 4));
                  },
                  onActionTap: () {
                    _idleSeconds = 0;
                    _isRoaming = false;
                    _targetWalkX = null;
                    SoundService.playClick();
                    _vibrate('light');
                    setState(() {
                      _isActionMode = true;
                      _isWardrobeMode = false;
                    });
                    _spawnParticles(Offset(_petX, _petY - 20), emoji: '✨', count: 3);
                    _showDialogueBubble('专属绝活点播台已就绪！点选下方任意绝活，看波可大展身手~ 🎭✨', duration: const Duration(seconds: 4));
                  },
                  onVoiceChatTap: _openAiVoiceChatDialog,
                ),

              // 7. 独立发光微动扭蛋机悬浮球 (Cyber Gacha FAB) - 常态下悬浮于右侧上方，开箱仪式感拉满，支持微缩渐隐优雅过渡
              Positioned(
                right: 18,
                bottom: 74,
                child: AnimatedScale(
                  scale: (!_isWardrobeMode && !_isActionMode && !_showFoodTray && !_isLaserMode) ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: (!_isWardrobeMode && !_isActionMode && !_showFoodTray && !_isLaserMode) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: IgnorePointer(
                      ignoring: _isWardrobeMode || _isActionMode || _showFoodTray || _isLaserMode,
                      child: CyberGachaFab(
                        isNight: isNight,
                        onTap: _openGachaBottomSheet,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }

  /// 响应系统物理返回键或边缘侧滑返回手势 (优先收起前台展开的交互抽屉或托盘，防误退 App)
  void _handleSystemBack() {
    _vibrate('light');
    if (_showFoodTray) {
      setState(() => _showFoodTray = false);
    } else if (_isWardrobeMode) {
      setState(() => _isWardrobeMode = false);
    } else if (_isActionMode) {
      setState(() => _isActionMode = false);
    } else if (_isLaserMode) {
      _stopLaserChase();
    }
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
                      ? '✅ 系统悬浮窗权限已就绪！\n开启后波可将突破 App 边界，常驻在手机桌面、微信、浏览器等任意应用的最上层，随时随地陪伴您。\n💡 按住波可拖动即可挪到屏幕任意位置，轻戳它会跟你说话，双击直接回到小窝。'
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
                      final ok = await OverlayService.startFloatingPet(
                        skinId: widget.petModel.skinId,
                        petName: widget.petModel.name,
                      );
                      if (ok) {
                        _showDialogueBubble('桌面悬浮宠启动成功！切回手机桌面就能看到波可啦~ ✨');
                      }
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (!isRunning && context.mounted && Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
            ],
          );
        },
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
                color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
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

}
