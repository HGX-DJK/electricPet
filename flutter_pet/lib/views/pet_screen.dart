import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pet_model.dart';
import '../models/memo_model.dart';
import '../renderers/pet_painter.dart';
import 'companion_dock.dart';
import 'dialogs/feeding_dialog.dart';
import 'dialogs/wardrobe_dialog.dart';
import 'dialogs/action_dialog.dart';
import 'memo_screen.dart';
import '../services/overlay_service.dart';

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

class _PetScreenState extends State<PetScreen> with TickerProviderStateMixin {
  late AnimationController _idleAnimController;
  late AnimationController _squishController;    // 点击戳戳 Q 弹形变控制器
  late AnimationController _walkController;      // 自主漫步平滑移动控制器
  late AnimationController _gravityController;   // 空中放下时重力坠落控制器
  late AnimationController _yarnRollController;  // 毛线球滚动控制器

  late Animation<double> _squishScaleX;
  late Animation<double> _squishScaleY;

  Timer? _decayTimer;
  Timer? _dialogueTimer;
  Timer? _particleTimer;

  // 萌宠坐标 (居中偏上舒适视线区域)
  double _petX = 200.0;
  double _petY = 320.0;
  bool _initializedPos = false;
  bool _isDragging = false;
  String _state = 'IDLE';
  bool _facingLeft = false;

  // 场景日夜模式切换
  bool _isNightMode = false;

  // 场景道具交互状态
  bool _bowlHasFood = false;

  // 等级提升监听
  int _previousLevel = 1;
  String? _levelUpBanner;

  // 自主漫步目的地
  double _walkStartX = 200.0;
  double _walkStartY = 320.0;
  double _walkTargetX = 200.0;
  double _walkTargetY = 320.0;
  int _idleSeconds = 0;
  int _nextWanderThreshold = 8; // 8~14秒自主漫步一次

  // 重力下落动画目标
  double _gravityStartY = 0.0;
  double _gravityTargetY = 0.0;
  Size _lastScreenSize = const Size(360.0, 640.0);

  // 抚摸与手势
  double _strokeDistance = 0.0;
  double _petProgress = 0.0;
  Offset? _touchPos;

  // 飘浮特效粒子列表
  final List<_Particle> _particles = [];

  // 对话气泡系统
  String _currentDialogue = '喵呜~ 戳戳我或者摸摸我的小脑瓜吧！(ฅ\'ω\'ฅ)';
  bool _showDialogue = true;

  @override
  void initState() {
    super.initState();
    _previousLevel = widget.petModel.level;

    // 呼吸律动主循环 (平滑 10 秒时间轴循环)
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

    // 自主漫步踱步位移控制器
    _walkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _walkController.addListener(() {
      if (!mounted || _isDragging) return;
      setState(() {
        final t = Curves.easeInOutCubic.transform(_walkController.value);
        _petX = _walkStartX + (_walkTargetX - _walkStartX) * t;
        _petY = _walkStartY + (_walkTargetY - _walkStartY) * t;

        // 漫步时脚底偶尔浮起超萌粉色爪印
        if (math.Random().nextDouble() < 0.06) {
          _spawnParticles(Offset(_petX, _petY + 28), emoji: '🐾', count: 1);
        }
      });
    });
    _walkController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && _state == 'WALK') {
        _onWalkCompleted();
      }
    });

    // 真实重力平滑坠落控制器 (空中放下时)
    _gravityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _gravityController.addListener(() {
      if (!mounted || _isDragging) return;
      setState(() {
        final t = Curves.easeInQuad.transform(_gravityController.value);
        _petY = _gravityStartY + (_gravityTargetY - _gravityStartY) * t;
      });
    });
    _gravityController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // 着地瞬间弹性触感与落地气流粒子
        _squishController.forward(from: 0.0);
        _spawnParticles(Offset(_petX, _petY + 25), emoji: '💨', count: 3);
        if (widget.petModel.enableHaptics) {
          HapticFeedback.mediumImpact();
        }
        _showDialogueBubble('四脚平稳落地！本喵敏捷度满分~ 🐾', duration: const Duration(seconds: 3));
      }
    });

    // 毛线球互动滚动控制器
    _yarnRollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _yarnRollController.addListener(() {
      if (mounted) setState(() {});
    });

    // 粒子飞升帧驱动定时器
    _particleTimer = Timer.periodic(const Duration(milliseconds: 24), (timer) {
      if (_particles.isNotEmpty) {
        setState(() {
          _particles.removeWhere((p) {
            p.progress += 0.035;
            p.position = Offset(p.position.dx, p.position.dy - 1.8);
            return p.progress >= 1.0;
          });
        });
      }
    });

    // 状态自然衰减与自主生活行为引擎 (每秒心跳)
    _decayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      widget.petModel.tickDecay(1.0);
      _checkLivingPetAI();
    });

    // 监听 PetModel 属性变更 (饱腹度、亲密度、等级升级、皮肤换装实时重绘)
    widget.petModel.addListener(_onModelUpdated);

    // 启动初始对话 (安全就绪，避免在 initState 期间触发 setState 引起构建异常)
    _currentDialogue = '主人！今天也要元气满满哦，随时随地陪着您~ ✨';
    _showDialogue = true;
    _dialogueTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showDialogue = false;
        });
      }
    });
  }

  void _onModelUpdated() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 监听是否升级并触发全屏庆典
      if (widget.petModel.level > _previousLevel) {
        _previousLevel = widget.petModel.level;
        _triggerLevelUpCelebration();
      }
      setState(() {});
    });
  }

  /// 升级里程碑全屏庆祝特效
  void _triggerLevelUpCelebration() {
    if (widget.petModel.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    _spawnParticles(Offset(_petX, _petY - 50), emoji: '🎉', count: 8);
    _spawnParticles(Offset(_petX - 30, _petY - 30), emoji: '⭐', count: 6);
    _spawnParticles(Offset(_petX + 30, _petY - 30), emoji: '✨', count: 6);

    setState(() {
      _levelUpBanner = '🎉 升级啦！波可升到了 Lv.${widget.petModel.level}！';
    });
    _showDialogueBubble('哇塞！主人把我养得太好啦~ 成功升到 Lv.${widget.petModel.level}！好爱好爱主人~ 💖(✧ω✧)', duration: const Duration(seconds: 6));

    Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _levelUpBanner = null);
    });
  }

  @override
  void dispose() {
    widget.petModel.removeListener(_onModelUpdated);
    _idleAnimController.dispose();
    _squishController.dispose();
    _walkController.dispose();
    _gravityController.dispose();
    _yarnRollController.dispose();
    _decayTimer?.cancel();
    _dialogueTimer?.cancel();
    _particleTimer?.cancel();
    super.dispose();
  }

  /// 自主生活行为引擎：让萌宠告别木桩呆板，自主在房间漫步、打滚、伸懒腰、洗脸、摇尾巴
  void _checkLivingPetAI() {
    if (_isDragging || widget.petModel.isSleeping || _state != 'IDLE' || _gravityController.isAnimating) return;

    _idleSeconds++;
    if (_idleSeconds >= _nextWanderThreshold) {
      _idleSeconds = 0;
      _nextWanderThreshold = 8 + math.Random().nextInt(7); // 下次 8~14 秒后触发

      final rnd = math.Random().nextDouble();
      if (rnd < 0.60) {
        // 60% 概率：自主漫步踱步 (从当前位置走到地毯周围新点位)
        _startAutonomousWander();
      } else {
        // 40% 概率：自主就地做萌趣微动作
        _triggerRandomMicroAction();
      }
    }
  }

  /// 开始自主漫步
  void _startAutonomousWander() {
    final safeW = _lastScreenSize.width > 0 ? _lastScreenSize.width : 360.0;
    final safeH = _lastScreenSize.height > 0 ? _lastScreenSize.height : 640.0;
    final rugCenterX = safeW / 2;
    final rugCenterY = safeH * 0.44;

    final minTargetX = 55.0;
    final maxTargetX = math.max(minTargetX + 10.0, safeW - 55.0);
    final minTargetY = 160.0;
    final maxTargetY = math.max(minTargetY + 10.0, safeH - 210.0);

    // 限制在地毯与房间舒适活动区
    final newTargetX = (rugCenterX + (math.Random().nextDouble() - 0.5) * 160).clamp(minTargetX, maxTargetX);
    final newTargetY = (rugCenterY + (math.Random().nextDouble() - 0.5) * 80).clamp(minTargetY, maxTargetY);

    _walkToCoordinates(newTargetX, newTargetY);

    final walkLines = [
      '吧嗒吧嗒~ 在房间里散步巡逻中🐾',
      '伸展小爪子，活动活动筋骨~ 🐾',
      '闻到空气里有小鱼干的香气吗？🐟',
      '悄悄靠近主人一点点~ 💕',
    ];
    if (math.Random().nextDouble() < 0.4) {
      _showDialogueBubble(walkLines[math.Random().nextInt(walkLines.length)], duration: const Duration(seconds: 3));
    }
  }

  void _walkToCoordinates(double targetX, double targetY, {VoidCallback? onArrived}) {
    final distance = (Offset(targetX, targetY) - Offset(_petX, _petY)).distance;
    if (distance < 15) {
      onArrived?.call();
      return;
    }

    _walkStartX = _petX;
    _walkStartY = _petY;
    _walkTargetX = targetX;
    _walkTargetY = targetY;

    setState(() {
      _facingLeft = (_walkTargetX < _walkStartX);
      _state = 'WALK';
    });

    final walkDurationMs = (distance * 14).clamp(1600, 3200).toInt();
    _walkController.duration = Duration(milliseconds: walkDurationMs);
    _walkController.forward(from: 0.0);
  }

  /// 漫步到达目标点后的反应
  void _onWalkCompleted() {
    if (!mounted) return;
    final rnd = math.Random().nextDouble();
    if (rnd < 0.55) {
      // 到达后随机做个小绝活庆祝
      final arrivals = ['LOOK_AROUND', 'SIT_WAG_TAIL', 'WASH_FACE', 'TILT_HEAD', 'STRETCH_YAWN', 'ROLL_OVER'];
      _playAction(arrivals[math.Random().nextInt(arrivals.length)]);
    } else {
      setState(() {
        _state = 'IDLE';
      });
    }
  }

  /// 自主随机微动作
  void _triggerRandomMicroAction() {
    final idleActions = ['WASH_FACE', 'TILT_HEAD', 'LOOK_AROUND', 'SIT_WAG_TAIL', 'STRETCH_YAWN', 'ROLL_OVER'];
    final act = idleActions[math.Random().nextInt(idleActions.length)];
    _playAction(act);
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

  /// 拟真分部位触碰感知系统 (头顶/耳朵、下巴喉咙、小肚子、小尾巴分别触发不同反应)
  void _onPetAnatomicalTap(Offset localPos) {
    if (_walkController.isAnimating) _walkController.stop();
    if (_gravityController.isAnimating) _gravityController.stop();
    _idleSeconds = 0;

    final relX = localPos.dx - 100;
    final relY = localPos.dy - 100;

    // 1. 下巴与喉咙 (-15 <= relY < 30) -> 挠下巴极致享受！
    if (relY >= -15 && relY < 30) {
      if (widget.petModel.enableHaptics) {
        HapticFeedback.lightImpact();
      }
      _squishController.forward(from: 0.0);
      widget.petModel.petHead();
      _spawnParticles(Offset(_petX, _petY - 20), emoji: '💖', count: 4);

      final chinLines = [
        '咕噜噜噜... 挠挠小下巴！舒服得都要融化成猫饼啦~ 🤤💕',
        '呼噜呼噜... 就是这个位置！波可眯上眼睛享受中~ ✨',
        '下巴被挠得好舒服，舒服到发出小猪叫~ 🐾',
      ];
      _showDialogueBubble(chinLines[math.Random().nextInt(chinLines.length)]);
      return;
    }

    // 2. 小肚子 (30 <= relY < 75 && 水平居中) -> 怕痒翻肚皮打滚！
    if (relY >= 30 && relY < 75 && relX.abs() < 42) {
      if (widget.petModel.enableHaptics) {
        HapticFeedback.mediumImpact();
      }
      _playAction('ROLL_OVER');
      widget.petModel.intimacy += 5;
      _spawnParticles(Offset(_petX, _petY - 10), emoji: '😻', count: 5);

      final bellyLines = [
        '喵呀！好痒好痒~ 肚肚是猫咪最软的弱点啦！(>ω<)💕',
        '被主人挠得笑翻天啦！四脚朝天打滚求放过~ 🐾',
        '软乎乎的小肚几只给最喜欢的主人摸哦！✨',
      ];
      _showDialogueBubble(bellyLines[math.Random().nextInt(bellyLines.length)]);
      return;
    }

    // 3. 蓬松小尾巴 (右侧偏下 relX > 25 && relY > 15) -> 警惕轻微受惊！
    if (relX > 25 && relY > 15) {
      if (widget.petModel.enableHaptics) {
        HapticFeedback.lightImpact();
      }
      _spawnParticles(Offset(_petX + 35, _petY), emoji: '❓', count: 2);
      final tailLines = [
        '嗷呜！被偷袭尾巴啦！尾巴只能看不准拽哦~ 😾💨',
        '尾巴警报响起！尾巴是猫咪保持平衡的机密雷达！🐾',
      ];
      _showDialogueBubble(tailLines[math.Random().nextInt(tailLines.length)]);
      return;
    }

    // 4. 头顶与耳朵 (relY < -15) 及其他区域 -> 经典摸头杀！
    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    _squishController.forward(from: 0.0);
    _spawnParticles(Offset(_petX, _petY - 30), count: 4);
    widget.petModel.petHead();

    final headLines = [
      '喵呜~ 蹭蹭主人的手心！好喜欢主人~ (ฅ\'ω\'ฅ)',
      '波可的小脑瓜随时供主人随意揉揉~ ✨',
      '嘿嘿！元气+100，主人今天也是最棒的！🐾',
    ];
    _showDialogueBubble(headLines[math.Random().nextInt(headLines.length)]);
  }

  /// 双击触发开怀绝活 (翻肚皮撒娇或欢喜转圈)
  void _onPetDoubleTap() {
    if (_walkController.isAnimating) _walkController.stop();
    if (_gravityController.isAnimating) _gravityController.stop();
    _idleSeconds = 0;

    if (widget.petModel.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    final doubleTapTricks = ['HAPPY_SPIN', 'ROLL_OVER'];
    _playAction(doubleTapTricks[math.Random().nextInt(doubleTapTricks.length)]);
    _spawnParticles(Offset(_petX, _petY - 40), emoji: '⭐', count: 6);
  }

  void _playAction(String actionId) {
    if (_walkController.isAnimating) _walkController.stop();
    _idleSeconds = 0;

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
      'ROLL_OVER': '四脚朝天翻肚皮撒娇啦~ 快来挠挠肚肚！😻💕',
      'PEEK_EDGE': '悄悄趴在屏幕边上偷看主人写代码~ 👀💕',
      'WASH_FACE': '爪爪沾沾温水，认真洗脸理毛变帅帅~ 🫧✨',
      'STRETCH_YAWN': '哈欠连天~ 伸个大大的懒腰，浑身舒畅！🥱',
      'TILT_HEAD': '歪头好奇打量~ 主人又在看什么有趣的内容呢？❓',
      'LOOK_AROUND': '左瞅瞅右看看，波可认真保卫主人手机！🔍🐾',
      'SIT_WAG_TAIL': '乖乖端坐，蓬松大尾巴兴奋晃来晃去~ 🐈💕',
      'HEAD_BOB_MUSIC': '戴上潮流大耳机！动次打次跟着节拍摇头晃脑~ 🎵🎧',
      'CHASE_BUTTERFLY': '哇！彩光小蝴蝶飞来啦~ 灵巧一扑！🦋✨',
      'HAPPY_SPIN': '开心到飞起！旋转跳跃转圈圈~ 💫(✧ω✧)',
      'DOZE_OFF': '小脑瓜一点一点... 困意来袭，打个小瞌睡~ 💤',
      'DIZZY': '小星星在头上转呀转~ 晕乎乎晃悠悠~ ⭐🌀',
      'EATING': '嚼嚼嚼~ 太美味啦！小肚子饱饱好幸福~ 🍱✨',
    };

    final actionEmojis = {
      'CARDBOARD_BOX': '📦',
      'CATCH_MOUSE': '🐭',
      'PLAY_YARN': '🧶',
      'ROLL_OVER': '😻',
      'PEEK_EDGE': '👀',
      'WASH_FACE': '🫧',
      'STRETCH_YAWN': '🥱',
      'TILT_HEAD': '❓',
      'LOOK_AROUND': '🔍',
      'SIT_WAG_TAIL': '🐾',
      'HEAD_BOB_MUSIC': '🎵',
      'CHASE_BUTTERFLY': '🦋',
      'HAPPY_SPIN': '💫',
      'DOZE_OFF': '💤',
      'DIZZY': '⭐',
      'EATING': '🍱',
    };

    final msg = actionLines[actionId] ?? '波可展现了独家才艺！✨';
    _showDialogueBubble(msg, duration: const Duration(seconds: 4));
    _spawnParticles(Offset(_petX, _petY - 40), emoji: actionEmojis[actionId], count: 5);

    Timer(const Duration(milliseconds: 4600), () {
      if (mounted && _state == actionId) {
        setState(() {
          _state = 'IDLE';
        });
      }
    });
  }

  /// 互动场景道具 1：点击陶瓷小食盆
  void _onBowlTapped(double matX, double matY) {
    if (widget.petModel.isSleeping) return;
    if (widget.petModel.enableHaptics) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _bowlHasFood = true;
    });

    _spawnParticles(Offset(matX - 95, matY), emoji: '🐟', count: 3);
    _spawnParticles(Offset(matX - 95, matY - 15), emoji: '✨', count: 3);
    _showDialogueBubble('❗️ 开饭啦！食盆里盛满了新鲜香脆小鱼干！', duration: const Duration(seconds: 3));

    // 猫咪立即闻香飞奔跑向食盆
    _walkToCoordinates(matX - 55, matY - 10, onArrived: () {
      if (!mounted) return;
      widget.petModel.feed('dried_fish');
      _playAction('EATING');
      _spawnTextParticle(Offset(_petX, _petY - 50), '+18 饱腹 ❤️', const Color(0xFFF59E0B));
      _spawnTextParticle(Offset(_petX, _petY - 70), '+15 经验 ✨', const Color(0xFF6366F1));

      Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _bowlHasFood = false);
      });
    });
  }

  /// 互动场景道具 2：点击粉红毛线团
  void _onYarnTapped(double matX, double matY) {
    if (widget.petModel.isSleeping) return;
    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    _yarnRollController.forward(from: 0.0);
    _spawnParticles(Offset(matX + 75, matY), emoji: '🧶', count: 4);
    _showDialogueBubble('哇！粉红毛线球滚滚滚~ 看波可神勇一扑！🐾', duration: const Duration(seconds: 3));

    // 猫咪飞奔扑球
    _walkToCoordinates(matX + 45, matY - 12, onArrived: () {
      if (!mounted) return;
      _playAction('PLAY_YARN');
      widget.petModel.mood = (widget.petModel.mood + 15).clamp(0.0, 100.0);
      widget.petModel.intimacy += 6;
      widget.petModel.addExp(20.0);
      _spawnTextParticle(Offset(_petX, _petY - 50), '+15 心情 💖', const Color(0xFFEC4899));
    });
  }

  /// 重置萌宠回到中心软垫
  void _resetToMat(Size screenSize) {
    if (_walkController.isAnimating) _walkController.stop();
    if (_gravityController.isAnimating) _gravityController.stop();
    _idleSeconds = 0;

    setState(() {
      _petX = screenSize.width / 2;
      _petY = screenSize.height * 0.44;
      _state = 'IDLE';
    });
    _showDialogueBubble('回到温暖专属小软垫啦！舒服坐好~ 🐾');
    if (widget.petModel.enableHaptics) {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenW = screenSize.width > 0 ? screenSize.width : 360.0;
    final screenH = screenSize.height > 0 ? screenSize.height : 640.0;
    final safeSize = Size(screenW, screenH);
    _lastScreenSize = safeSize;

    // 首次进入自适应设置萌宠在黄金视线居中点
    if (!_initializedPos) {
      _petX = screenW / 2;
      _petY = screenH * 0.44;
      _initializedPos = true;
    }

    // 地板与软垫基准位置
    final matX = screenW / 2;
    final matY = screenH * 0.44 + 68.0;

    // 萌宠允许移动的上下安全边界
    const minSafeY = 150.0;
    final maxSafeY = math.max(minSafeY + 20.0, screenH - 180.0);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _isNightMode
                ? const [
                    Color(0xFF0F172A), // 深邃星夜暗蓝
                    Color(0xFF1E1B4B), // 梦幻蓝紫夜空
                    Color(0xFF312E81), // 柔和深紫月光
                    Color(0xFF1E293B), // 静谧地板暗色
                  ]
                : const [
                    Color(0xFFE0F2FE), // 清新天空冰蓝
                    Color(0xFFFEF3C7), // 柔和香草奶油
                    Color(0xFFFCE7F3), // 梦幻落樱治愈粉
                    Color(0xFFEEF2FF), // 治愈风铃草蓝紫
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 0. 背景微光氛围装饰 (日间云朵金星 / 夜间弯月群星)
              if (!_isNightMode) ...[
                Positioned(
                  top: 75,
                  right: 28,
                  child: Text('☁️', style: TextStyle(fontSize: 34, color: Colors.white.withValues(alpha: 0.65))),
                ),
                Positioned(
                  top: 130,
                  left: 20,
                  child: Text('✨', style: TextStyle(fontSize: 24, color: const Color(0xFFFDE047).withValues(alpha: 0.75))),
                ),
                Positioned(
                  top: 260,
                  right: 18,
                  child: Text('⭐', style: TextStyle(fontSize: 18, color: const Color(0xFFFBBF24).withValues(alpha: 0.60))),
                ),
              ] else ...[
                const Positioned(
                  top: 75,
                  right: 32,
                  child: Text('🌙', style: TextStyle(fontSize: 34)),
                ),
                Positioned(
                  top: 110,
                  left: 36,
                  child: Text('✨', style: TextStyle(fontSize: 22, color: const Color(0xFFFEF08A).withValues(alpha: 0.85))),
                ),
                Positioned(
                  top: 170,
                  right: 90,
                  child: Text('⭐', style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.7))),
                ),
                Positioned(
                  top: 240,
                  left: 60,
                  child: Text('💫', style: TextStyle(fontSize: 18, color: const Color(0xFFC7D2FE).withValues(alpha: 0.8))),
                ),
              ],

              // 1. 专属立体刺绣软垫 (温暖地毯底座)
              Positioned(
                left: matX - 110,
                top: matY - 26,
                child: _buildCozyRug(),
              ),

              // 场景互动道具 1：左侧可点击小猫陶瓷食盆 (点击加鱼，猫咪跑来干饭)
              Positioned(
                left: matX - 100,
                top: matY - 8,
                child: GestureDetector(
                  onTap: () => _onBowlTapped(matX, matY),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _bowlHasFood ? const Color(0xFFFEF3C7) : Colors.white.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _bowlHasFood ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(_bowlHasFood ? '🐟' : '🥣', style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ),

              // 场景互动道具 2：右侧可点击粉红毛线团 (点击滚动，猫咪神扑玩耍)
              Positioned(
                left: matX + 70,
                top: matY - 8,
                child: GestureDetector(
                  onTap: () => _onYarnTapped(matX, matY),
                  child: AnimatedBuilder(
                    animation: _yarnRollController,
                    builder: (context, child) {
                      final roll = _yarnRollController.value * 2 * math.pi;
                      return Transform.rotate(
                        angle: roll,
                        child: child,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFBCFE8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text('🧶', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
              ),

              // 2. 顶部状态灵动微光毛玻璃胶囊 (等级、好感、饱腹、心情、日夜切换、回窝)
              Positioned(
                top: 8,
                left: 14,
                right: 14,
                child: _buildTopGlassBar(screenSize),
              ),

              // 升级全屏庆祝横幅
              if (_levelUpBanner != null)
                Positioned(
                  top: 76,
                  left: 24,
                  right: 24,
                  child: _buildLevelUpBanner(),
                ),

              // 3. 萌宠主窗体 (支持分部位触碰、双击、拖拽、重力落地缓冲)
              Positioned(
                left: _petX - 100,
                top: _petY - 100,
                child: GestureDetector(
                  onTapDown: (details) => _onPetAnatomicalTap(details.localPosition),
                  onDoubleTap: _onPetDoubleTap,
                  onPanStart: (details) {
                    if (_walkController.isAnimating) _walkController.stop();
                    if (_gravityController.isAnimating) _gravityController.stop();
                    _idleSeconds = 0;
                    setState(() {
                      _isDragging = true;
                      _state = 'DRAGGING';
                      _strokeDistance = 0.0;
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _petX += details.delta.dx;
                      _petY += details.delta.dy;

                      // 限制萌宠不出屏幕
                      _petX = _petX.clamp(35.0, screenSize.width - 35.0);
                      _petY = _petY.clamp(minSafeY, maxSafeY);

                      _facingLeft = (details.delta.dx < -0.8);
                      _touchPos = details.localPosition;

                      // 抚摸判定 (轻微滑动即算抚摸，产生心心与踩奶反馈)
                      final delta = details.delta.distance;
                      if (delta > 1.0 && delta < 15.0) {
                        _strokeDistance += delta;
                        if (_strokeDistance > 20.0) {
                          _strokeDistance = 0.0;
                          _petProgress = 1.0;
                          widget.petModel.petHead();
                          _spawnParticles(Offset(_petX, _petY - 40), emoji: '❤️', count: 1);
                          if (widget.petModel.enableHaptics) {
                            HapticFeedback.lightImpact();
                          }
                        }
                      }
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isDragging = false;
                      _touchPos = null;
                      _petProgress = 0.0;
                      _state = 'IDLE';
                    });

                    // 贴边探头偷看判定 (靠屏幕边缘 < 50px 自动贴边)
                    if (_petX < 55) {
                      setState(() {
                        _state = 'PEEK_LEFT';
                        _petX = 35;
                      });
                      _showDialogueBubble('探头偷看~ 主人在看什么呀？👀');
                      return;
                    } else if (_petX > screenSize.width - 55) {
                      setState(() {
                        _state = 'PEEK_RIGHT';
                        _petX = screenSize.width - 35;
                      });
                      _showDialogueBubble('探头偷看~ 报告主人，屏幕右侧安全！🐾');
                      return;
                    }

                    // 真实重力着陆判定：如果松手时被举在半空，自然平滑下落回地毯高度
                    final defaultFloorY = matY - 68.0;
                    if (_petY < defaultFloorY - 25.0) {
                      _gravityStartY = _petY;
                      _gravityTargetY = defaultFloorY;
                      _gravityController.forward(from: 0.0);
                    }
                  },
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_idleAnimController, _squishController, _walkController, _gravityController]),
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
                            touchPos: _touchPos,
                            facingLeft: _facingLeft,
                            petProgress: _petProgress,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 4. 浮空特效粒子层 (心心、星星、属性增加浮动)
              for (final p in _particles)
                Positioned(
                  key: p.id,
                  left: p.position.dx - 14,
                  top: p.position.dy - 14,
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
                                color: Colors.white.withValues(alpha: 0.9),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. 动态自主心理需求小气泡 (饥饿想吃鱼、无聊想玩球、困了想睡觉快捷点击)
              _buildPetNeedThoughtBubble(),

              // 6. 对话气泡 (层级在萌宠之上，永不遮挡，智能防越界)
              if (_showDialogue) _buildSmartDialogueBubble(screenSize),

              // 7. 底部灵动伴侣岛 Dock
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: CompanionDock(
                    model: widget.petModel,
                    onFeedTap: () {
                      _showBottomSheet(
                        builder: (_) => FeedingDialog(
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
                    onWardrobeTap: () {
                      _showBottomSheet(
                        builder: (_) => WardrobeDialog(model: widget.petModel),
                      );
                    },
                    onActionTap: () {
                      _showBottomSheet(
                        builder: (_) => ActionDialog(
                          onActionSelected: (actId) {
                            _playAction(actId);
                          },
                        ),
                      );
                    },
                    onMemoTap: () {
                      _showBottomSheet(
                        builder: (_) => MemoScreen(memoModel: widget.memoModel),
                      );
                    },
                    onBathTap: () {
                      // 沉浸式舒爽沐浴
                      widget.petModel.wash();
                      _playAction('WASH_FACE');
                      _spawnParticles(Offset(_petX, _petY - 30), emoji: '🫧', count: 8);
                      _spawnParticles(Offset(_petX, _petY - 10), emoji: '💦', count: 4);
                      _spawnParticles(Offset(_petX, _petY - 45), emoji: '✨', count: 4);
                      _showDialogueBubble('洗香香沐浴啦！浑身散发着草莓沐浴露的香气，闪闪发光~ 🫧✨');
                    },
                    onSleepTap: () {
                      final isSleep = widget.petModel.toggleSleep();
                      if (isSleep) {
                        _showDialogueBubble('呼噜呼噜... 进入甜甜的梦乡啦，嘘~ 💤');
                      } else {
                        _showDialogueBubble('睡饱醒来啦！元气活力充沛~ ☀️');
                      }
                    },
                    onToggleFloating: () {
                      _handleFloatingTap();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 萌宠动态自主心理需求快捷小气泡
  Widget _buildPetNeedThoughtBubble() {
    String? needEmoji;
    String? needText;
    VoidCallback? onTapNeed;

    if (widget.petModel.hunger < 45.0) {
      needEmoji = '🐟';
      needText = '肚子好饿饿...';
      onTapNeed = () {
        _showBottomSheet(
          builder: (_) => FeedingDialog(
            model: widget.petModel,
            onFeedSelected: (foodId) {
              widget.petModel.feed(foodId);
              _playAction('EATING');
            },
          ),
        );
      };
    } else if (widget.petModel.mood < 45.0) {
      needEmoji = '🧶';
      needText = '想玩球球...';
      onTapNeed = () {
        final matX = _lastScreenSize.width / 2;
        final matY = _lastScreenSize.height * 0.44 + 68.0;
        _onYarnTapped(matX, matY);
      };
    } else if (widget.petModel.cleanliness < 45.0) {
      needEmoji = '🫧';
      needText = '想洗香香...';
      onTapNeed = () {
        widget.petModel.wash();
        _playAction('WASH_FACE');
        _spawnParticles(Offset(_petX, _petY - 20), emoji: '🫧', count: 6);
      };
    }

    if (needEmoji == null) return const SizedBox.shrink();

    final screenW = _lastScreenSize.width > 0 ? _lastScreenSize.width : 360.0;
    final screenH = _lastScreenSize.height > 0 ? _lastScreenSize.height : 640.0;
    final maxL = math.max(16.0, screenW - 130.0);
    final maxT = math.max(70.0, screenH - 180.0);

    return Positioned(
      left: (_petX + 42).clamp(16.0, maxL),
      top: (_petY - 82).clamp(70.0, maxT),
      child: GestureDetector(
        onTap: onTapNeed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFED7AA), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF97316).withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(needEmoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                needText!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9A3412),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 升级庆祝顶部闪亮横幅
  Widget _buildLevelUpBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFEF3C7), Color(0xFFFDE047), Color(0xFFFACC15)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('⭐', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(
            _levelUpBanner!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF78350F),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          const Text('⭐', style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  /// 统一以现代化半屏 BottomSheet 呈现，绝不遮挡上层小猫
  void _showBottomSheet({required WidgetBuilder builder}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  /// 专属立体温暖地毯
  Widget _buildCozyRug() {
    return Container(
      width: 220,
      height: 52,
      decoration: BoxDecoration(
        color: _isNightMode
            ? const Color(0xFF334155).withValues(alpha: 0.75)
            : const Color(0xFFFEF3C7).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _isNightMode
              ? const Color(0xFF64748B).withValues(alpha: 0.8)
              : const Color(0xFFFDE68A).withValues(alpha: 0.9),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isNightMode
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '🐾  POKO\'S COZY HAVEN  🐾',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: _isNightMode ? const Color(0xFFCBD5E1) : const Color(0xFFD97706),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  /// 智能对齐气泡：永不被猫挡住，附带指向小箭头
  Widget _buildSmartDialogueBubble(Size screenSize) {
    final screenW = screenSize.width > 0 ? screenSize.width : 360.0;
    final bubbleWidth = math.min(270.0, math.max(160.0, screenW - 32.0));
    final maxLeft = math.max(16.0, screenW - bubbleWidth - 16.0);
    final bubbleLeft = (_petX - bubbleWidth / 2).clamp(16.0, maxLeft);

    // 垂直方向：根据猫咪所在高度自适应调整在头顶或脚下
    final showAbove = _petY > 210.0;
    final bubbleTop = showAbove ? (_petY - 145.0) : (_petY + 95.0);

    return Positioned(
      left: bubbleLeft,
      top: bubbleTop,
      child: GestureDetector(
        onTap: () {
          _checkLivingPetAI();
        },
        child: Container(
          width: bubbleWidth,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _isNightMode ? const Color(0xFF1E293B).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isNightMode ? const Color(0xFF475569) : const Color(0xFFE0E7FF),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('💬', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _currentDialogue,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _isNightMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
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

  /// 顶端微光灵动状态胶囊
  Widget _buildTopGlassBar(Size screenSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _isNightMode
            ? const Color(0xFF1E293B).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _isNightMode ? const Color(0xFF475569) : Colors.white,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 等级徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'Lv.${widget.petModel.level}',
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          // 猫咪名字与亲密等级
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.petModel.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: _isNightMode ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '❤️ 亲密 ${widget.petModel.intimacy}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Color(0xFFE11D48), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Spacer(),
          // 饱腹与心情进度胶囊
          _buildMiniBar('饱腹', widget.petModel.hunger / 100, const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          _buildMiniBar('心情', widget.petModel.mood / 100, const Color(0xFF10B981)),
          const SizedBox(width: 8),
          // 日夜氛围模式切换按钮
          GestureDetector(
            onTap: () {
              setState(() {
                _isNightMode = !_isNightMode;
              });
              if (widget.petModel.enableHaptics) {
                HapticFeedback.lightImpact();
              }
              if (_isNightMode) {
                _showDialogueBubble('切换到静谧月夜模式啦~ 波可陪您数星星入眠🌙💤');
              } else {
                _showDialogueBubble('早安！暖洋晨光已升起，新的一天要元气满满哦☀️🐾');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: _isNightMode ? const Color(0xFF312E81) : const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: Text(_isNightMode ? '🌙' : '☀️', style: const TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 6),
          // 一键回窝按钮
          GestureDetector(
            onTap: () => _resetToMat(screenSize),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isNightMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isNightMode ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Icon(
                Icons.home_rounded,
                size: 16,
                color: _isNightMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBar(String label, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ${(pct * 100).toInt()}%',
          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 3),
        Container(
          width: 44,
          height: 6,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          child: Container(
            width: 44 * pct.clamp(0.0, 1.0),
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ],
    );
  }

  /// 桌面悬浮控制面板 (以 BottomSheet 形式优雅唤起，一键授权与启停)
  Future<void> _handleFloatingTap() async {
    final hasPermission = await OverlayService.checkPermission();
    final isRunning = await OverlayService.isRunning();

    if (!mounted) return;

    _showBottomSheet(
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('📱', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Text(
                          '全局桌面悬浮宠',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Text(
                  hasPermission
                      ? '✅ 系统悬浮窗权限已就绪！开启后波可将突破 App 边界，常驻在手机桌面、微信、浏览器等任意应用的最上层，随时随地陪伴您。'
                      : '⚠️ 尚未开启“显示在其他应用上层”权限。请先点击下方按钮前往系统设置开启悬浮窗权限，方可在手机桌面上显示波可。',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
                ),
                const SizedBox(height: 14),

                if (hasPermission)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isRunning ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isRunning ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isRunning ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          size: 18,
                          color: isRunning ? const Color(0xFF047857) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isRunning ? '悬浮萌宠：运行中 (已在屏幕边缘常驻)' : '悬浮萌宠：未开启',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isRunning ? const Color(0xFF047857) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('稍后再说', style: TextStyle(color: Color(0xFF64748B))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: (!hasPermission)
                              ? const Color(0xFF4F46E5)
                              : (isRunning ? const Color(0xFFE11D48) : const Color(0xFF10B981)),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                        icon: Icon(
                          (!hasPermission)
                              ? Icons.settings_rounded
                              : (isRunning ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded),
                          size: 18,
                        ),
                        label: Text(
                          (!hasPermission)
                              ? '前往授权悬浮窗'
                              : (isRunning ? '收回悬浮宠' : '立即启动桌面悬浮'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          if (!hasPermission) {
                            Navigator.pop(ctx);
                            await OverlayService.requestPermission();
                          } else {
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
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
