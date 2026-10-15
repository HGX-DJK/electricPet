import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
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
  late AnimationController _squishController; // 点击戳戳 Q 弹形变控制器
  late AnimationController _walkController;   // 自主漫步平滑移动控制器

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

  // 自主漫步目的地
  double _walkStartX = 200.0;
  double _walkStartY = 320.0;
  double _walkTargetX = 200.0;
  double _walkTargetY = 320.0;
  int _idleSeconds = 0;
  int _nextWanderThreshold = 8; // 8~14秒自主漫步一次

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
    _walkController = AnimationController(vsync: this);
    _walkController.addListener(() {
      if (!mounted || _isDragging) return;
      setState(() {
        final t = Curves.easeInOutCubic.transform(_walkController.value);
        _petX = _walkStartX + (_walkTargetX - _walkStartX) * t;
        _petY = _walkStartY + (_walkTargetY - _walkStartY) * t;

        // 漫步时偶尔在脚底浮起超萌粉色爪印
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

    // 监听 PetModel 属性变更 (饱腹度、亲密度、等级、皮肤换装实时重绘)
    widget.petModel.addListener(_onModelUpdated);

    // 启动初始对话
    _showDialogueBubble('主人！今天也要元气满满哦，随时随地陪着您~ ✨');
  }

  void _onModelUpdated() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.petModel.removeListener(_onModelUpdated);
    _idleAnimController.dispose();
    _squishController.dispose();
    _walkController.dispose();
    _decayTimer?.cancel();
    _dialogueTimer?.cancel();
    _particleTimer?.cancel();
    super.dispose();
  }

  /// 自主生活行为引擎：让萌宠告别木桩呆板，自主在房间漫步、打滚、伸懒腰、洗脸、摇尾巴
  void _checkLivingPetAI() {
    if (_isDragging || widget.petModel.isSleeping || _state != 'IDLE') return;

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
    final screenSize = MediaQuery.of(context).size;
    final rugCenterX = screenSize.width / 2;
    final rugCenterY = screenSize.height * 0.44;

    // 限制在地毯与房间舒适活动区
    final newTargetX = (rugCenterX + (math.Random().nextDouble() - 0.5) * 160).clamp(55.0, screenSize.width - 55.0);
    final newTargetY = (rugCenterY + (math.Random().nextDouble() - 0.5) * 80).clamp(160.0, screenSize.height - 210.0);

    final distance = (Offset(newTargetX, newTargetY) - Offset(_petX, _petY)).distance;
    if (distance < 20) return;

    _walkStartX = _petX;
    _walkStartY = _petY;
    _walkTargetX = newTargetX;
    _walkTargetY = newTargetY;

    setState(() {
      _facingLeft = (_walkTargetX < _walkStartX);
      _state = 'WALK';
    });

    final walkDurationMs = (distance * 14).clamp(1800, 3200).toInt();
    _walkController.duration = Duration(milliseconds: walkDurationMs);
    _walkController.forward(from: 0.0);

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

  /// 触碰/戳戳萌宠
  void _onPetTap(Offset globalPos) {
    if (_walkController.isAnimating) {
      _walkController.stop();
    }
    _idleSeconds = 0;

    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    _squishController.forward(from: 0.0);
    _spawnParticles(Offset(_petX, _petY - 30), count: 4);

    widget.petModel.petHead();

    final petLines = [
      '喵呜~ 蹭蹭主人的手心！好喜欢主人~ (ฅ\'ω\'ฅ)',
      '咕噜咕噜... 被主人戳得好舒服呀！💕',
      '波可的小脑袋随时供主人随意揉揉~ ✨',
      '嘿嘿！元气+100，主人今天也是最棒的！🐾',
    ];
    _showDialogueBubble(petLines[math.Random().nextInt(petLines.length)]);
  }

  /// 双击触发开怀绝活 (翻肚皮撒娇或欢喜转圈)
  void _onPetDoubleTap() {
    if (_walkController.isAnimating) {
      _walkController.stop();
    }
    _idleSeconds = 0;

    if (widget.petModel.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    final doubleTapTricks = ['HAPPY_SPIN', 'ROLL_OVER'];
    _playAction(doubleTapTricks[math.Random().nextInt(doubleTapTricks.length)]);
    _spawnParticles(Offset(_petX, _petY - 40), emoji: '⭐', count: 6);
  }

  void _playAction(String actionId) {
    if (_walkController.isAnimating) {
      _walkController.stop();
    }
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
      'ROLL_OVER': '四脚朝天翻肚皮撒娇啦~ 快来挠挠下巴！😻💕',
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

  /// 重置萌宠回到中心软垫
  void _resetToMat(Size screenSize) {
    if (_walkController.isAnimating) {
      _walkController.stop();
    }
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

    // 首次进入时，自适应设置萌宠在屏幕视觉黄金居中点
    if (!_initializedPos && screenSize.width > 0) {
      _petX = screenSize.width / 2;
      _petY = screenSize.height * 0.44;
      _initializedPos = true;
    }

    // 地板与软垫基准位置
    final matX = screenSize.width / 2;
    final matY = screenSize.height * 0.44 + 68.0;

    // 萌宠允许移动的上下安全边界
    const minSafeY = 150.0;
    final maxSafeY = screenSize.height - 180.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF7ED), // 晨光暖杏奶白
              Color(0xFFFEF3C7), // 柔和香草奶油
              Color(0xFFF0FDF4), // 清新薄荷浅绿
              Color(0xFFEEF2FF), // 治愈风铃草蓝紫
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 0. 背景微光氛围装饰 (移动端温馨小窝治愈感)
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

              // 1. 专属立体刺绣软垫 (温暖地毯底座)
              Positioned(
                left: matX - 110,
                top: matY - 26,
                child: _buildCozyRug(),
              ),

              // 地板可爱小道具：左侧小猫瓷碗，右侧粉色毛线球
              Positioned(
                left: matX - 95,
                top: matY - 4,
                child: const Text('🥣', style: TextStyle(fontSize: 22)),
              ),
              Positioned(
                left: matX + 75,
                top: matY - 4,
                child: const Text('🧶', style: TextStyle(fontSize: 22)),
              ),

              // 2. 顶部状态灵动微光毛玻璃胶囊 (等级、好感、饱腹、心情、回窝)
              Positioned(
                top: 8,
                left: 14,
                right: 14,
                child: _buildTopGlassBar(screenSize),
              ),

              // 3. 萌宠主窗体 (支持手势拖拽、点击、双击、抚摸挠下巴与边缘偷看)
              Positioned(
                left: _petX - 100,
                top: _petY - 100,
                child: GestureDetector(
                  onTap: () => _onPetTap(Offset(_petX, _petY)),
                  onDoubleTap: _onPetDoubleTap,
                  onPanStart: (details) {
                    if (_walkController.isAnimating) {
                      _walkController.stop();
                    }
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

                      _state = 'IDLE';
                    });
                  },
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_idleAnimController, _squishController, _walkController]),
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

              // 5. 对话气泡 (层级在萌宠之上，永不遮挡，智能防越界)
              if (_showDialogue) _buildSmartDialogueBubble(screenSize),

              // 6. 底部灵动伴侣岛 Dock
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
                      widget.petModel.wash();
                      _spawnParticles(Offset(_petX, _petY - 20), emoji: '🫧', count: 5);
                      _showDialogueBubble('洗香香啦！浑身散发着草莓沐浴露的香气~ 🫧✨');
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
        color: const Color(0xFFFEF3C7).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFFDE68A).withValues(alpha: 0.9),
          width: 2.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '🐾  POKO\'S COZY HOME  🐾',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD97706),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  /// 智能对齐气泡：永不被猫挡住，附带指向小箭头
  Widget _buildSmartDialogueBubble(Size screenSize) {
    final bubbleWidth = math.min(270.0, screenSize.width - 32.0);
    final bubbleLeft = (_petX - bubbleWidth / 2).clamp(16.0, screenSize.width - bubbleWidth - 16.0);

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
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E7FF), width: 1.5),
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
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF1E293B),
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

  /// 顶端微光毛玻璃状态胶囊
  Widget _buildTopGlassBar(Size screenSize) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.95), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                blurRadius: 16,
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
              // 猫咪名字与心情状态标语
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.petModel.name,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '❤️ 亲密 ${widget.petModel.intimacy}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFFE11D48), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),
              // 饱腹与心情进度胶囊
              _buildMiniBar('饱腹', widget.petModel.hunger / 100, const Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              _buildMiniBar('心情', widget.petModel.mood / 100, const Color(0xFF10B981)),
              const SizedBox(width: 10),
              // 一键回窝按钮
              GestureDetector(
                onTap: () => _resetToMat(screenSize),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(Icons.home_rounded, size: 17, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
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
          width: 48,
          height: 6,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          child: Container(
            width: 48 * pct.clamp(0.0, 1.0),
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
