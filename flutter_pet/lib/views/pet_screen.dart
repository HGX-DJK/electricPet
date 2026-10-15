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

  // 维度一：部位差异化感知 & 打呼噜状态
  bool _isPurring = false;
  Timer? _purrTimer;
  Timer? _purrHapticTimer;
  String? _twitchEar;
  Timer? _earTwitchTimer;

  // 维度二：毛线球物理与小鱼碗弹射
  double _yarnX = 0.0;
  double _yarnY = 0.0;
  double _yarnVx = 0.0;
  double _yarnVy = 0.0;
  bool _isYarnDragging = false;
  bool _isYarnFlying = false;
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

  // 飘浮爱心粒子列表
  final List<_Particle> _particles = [];

  // 对话气泡系统
  String _currentDialogue = '喵呜~ 戳戳我或者摸摸我的小脑瓜吧！(ฅ\'ω\'ฅ)';
  bool _showDialogue = true;

  @override
  void initState() {
    super.initState();

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

      // 毛线球物理运动更新
      if (_isYarnFlying) {
        _yarnX += _yarnVx;
        _yarnY += _yarnVy;
        _yarnVx *= 0.95;
        _yarnVy = (_yarnVy + 0.35) * 0.96;

        if (_yarnX < 24) { _yarnX = 24; _yarnVx = -_yarnVx * 0.7; }
        if (_yarnX > 360) { _yarnX = 360; _yarnVx = -_yarnVx * 0.7; }
        if (_yarnY > 580) { _yarnY = 580; _yarnVy = -_yarnVy * 0.6; }
        if (_yarnY < 120) { _yarnY = 120; _yarnVy = -_yarnVy * 0.7; }

        if (_yarnVx.abs() < 0.25 && _yarnVy.abs() < 0.25) {
          _isYarnFlying = false;
          _yarnVx = 0.0;
          _yarnVy = 0.0;

          // 若落在猫咪脚边，猫咪欢快扑抱毛线球
          final distToCat = (Offset(_yarnX, _yarnY) - Offset(_petX, _petY)).distance;
          if (distToCat < 100 && _state == 'IDLE') {
            _playAction('PLAY_YARN');
            _showDialogueBubble('抓住毛线球啦！抱紧滚来滚去~ 🧶🐾');
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

      if (needRepaint && mounted) {
        setState(() {});
      }
    });

    // 状态自然衰减与自言自语及自主微动作定时器
    _decayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      widget.petModel.tickDecay(1.0);
      _checkAutoDialogue();

      // 自主生活微动作引擎：待机 8~12 秒自动发生萌趣小动作
      if (_state == 'IDLE' && !_isDragging && !widget.petModel.isSleeping) {
        _idleSeconds++;
        if (_idleSeconds >= 9) {
          _idleSeconds = 0;
          _triggerRandomIdleAction();
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
  void dispose() {
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
    super.dispose();
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

  /// 触碰/戳戳萌宠
  void _onPetTap(Offset globalPos) {
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

  /// 双击触发开心旋转绝活
  void _onPetDoubleTap() {
    _idleSeconds = 0;
    if (widget.petModel.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    _playAction('HAPPY_SPIN');
    _spawnParticles(Offset(_petX, _petY - 40), emoji: '⭐', count: 6);
  }

  void _playAction(String actionId) {
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
      'PEEK_EDGE': '悄悄趴在屏幕边上偷看主人写代码~ 👀💕',
      'WASH_FACE': '爪爪沾沾温水，认真洗脸理毛变帅帅~ 🫧✨',
      'STRETCH_YAWN': '哈欠连天~ 伸个大大的懒腰，浑身舒畅！🥱',
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

    Timer(const Duration(milliseconds: 5200), () {
      if (mounted && _state == actionId) {
        setState(() {
          _state = 'IDLE';
        });
      }
    });
  }

  /// 待机自主萌趣小动作驱动 (洗脸、歪头、四处张望、摇尾巴、伸懒腰、打瞌睡)
  void _triggerRandomIdleAction() {
    if (!mounted || _state != 'IDLE' || _isDragging || widget.petModel.isSleeping) return;
    final idleActions = [
      'WASH_FACE',
      'TILT_HEAD',
      'LOOK_AROUND',
      'SIT_WAG_TAIL',
      'STRETCH_YAWN',
      'DOZE_OFF',
    ];
    final act = idleActions[math.Random().nextInt(idleActions.length)];
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

    Timer(const Duration(milliseconds: 3800), () {
      if (mounted && _state == act) {
        setState(() {
          _state = 'IDLE';
        });
      }
    });
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
    if (widget.petModel.enableHaptics) {
      HapticFeedback.lightImpact();
    }
    _showBottomSheetModal(
      PokoBackpackDrawer(
        model: widget.petModel,
        isNight: isNight,
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
        onTeaseTap: _teasePlay,
        onWardrobeTap: () {
          _showBottomSheetModal(
            WardrobeDialog(model: widget.petModel),
          );
        },
        onActionTap: () {
          _showBottomSheetModal(
            ActionDialog(
              onActionSelected: (actId) {
                _playAction(actId);
              },
            ),
          );
        },
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
    );
  }

  /// 重置萌宠回到中心软垫
  void _resetToMat(Size screenSize) {
    _idleSeconds = 0;
    final matX = screenSize.width / 2;
    final matY = screenSize.height * 0.38 + 68.0;
    setState(() {
      _petX = screenSize.width / 2;
      _petY = screenSize.height * 0.38;
      _yarnX = matX + 110;
      _yarnY = matY - 2;
      _isYarnFlying = false;
      _yarnVx = 0.0;
      _yarnVy = 0.0;
      _state = 'IDLE';
    });
    _showDialogueBubble('回到专属小软垫啦！舒服坐好~ 🐾');
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

  /// 维度一：部位差异化触感与猫咪打呼噜反应
  void _handleBodyPartTouch(Offset localPos, Size screenSize) {
    _idleSeconds = 0;

    // 1. 点粉嫩小鼻子 (Nose Boop)
    if ((localPos.dx - 100).abs() < 14 && (localPos.dy - 93).abs() < 10) {
      if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
      _squishController.forward(from: 0.0);
      _spawnParticles(Offset(_petX, _petY - 25), emoji: '🤧', count: 3);
      _showDialogueBubble('阿嚏！(>﹏<) 戳到波可敏感的小鼻尖啦~ 🐾', duration: const Duration(seconds: 4));
      return;
    }

    // 2. 挠下巴 / 颈窝 (Chin Scratch - 触发猫咪打呼噜连续细密震动与享受仰头)
    if ((localPos.dx - 100).abs() < 24 && (localPos.dy >= 99 && localPos.dy <= 122)) {
      setState(() {
        _isPurring = true;
      });
      _purrHapticTimer?.cancel();
      int purrTick = 0;
      if (widget.petModel.enableHaptics) {
        _purrHapticTimer = Timer.periodic(const Duration(milliseconds: 130), (t) {
          if (purrTick++ >= 9 || !_isPurring) {
            t.cancel();
          } else {
            HapticFeedback.selectionClick();
          }
        });
      }
      _purrTimer?.cancel();
      _purrTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) setState(() => _isPurring = false);
      });
      widget.petModel.petHead();
      _spawnParticles(Offset(_petX, _petY - 30), emoji: '💕', count: 5);
      _showDialogueBubble('咕噜咕噜... 下巴挠得好舒服，要融化在主人手心啦~ (˘ω˘)💕', duration: const Duration(seconds: 4));
      return;
    }

    // 3. 触摸左耳
    if (localPos.dx >= 45 && localPos.dx <= 88 && localPos.dy >= 18 && localPos.dy <= 62) {
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

    // 4. 触摸右耳
    if (localPos.dx >= 112 && localPos.dx <= 155 && localPos.dy >= 18 && localPos.dy <= 62) {
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

    // 5. 捏两腮包子脸 (Cheek Pinch)
    final isLeftCheek = (localPos.dx >= 52 && localPos.dx <= 84 && localPos.dy >= 70 && localPos.dy <= 104);
    final isRightCheek = (localPos.dx >= 116 && localPos.dx <= 148 && localPos.dy >= 70 && localPos.dy <= 104);
    if (isLeftCheek || isRightCheek) {
      if (widget.petModel.enableHaptics) HapticFeedback.lightImpact();
      _squishController.forward(from: 0.0);
      _spawnParticles(Offset(_petX, _petY - 20), emoji: '🫧', count: 3);
      _showDialogueBubble('唔姆~ 脸颊肉肉要被主人捏圆啦！(ฅ\'ω\'ฅ)', duration: const Duration(seconds: 4));
      return;
    }

    // 6. 摸肉垫 / 肚皮 (High Five / Tummy Poke)
    if (localPos.dy > 120) {
      if (widget.petModel.enableHaptics) HapticFeedback.mediumImpact();
      _spawnParticles(Offset(_petX, _petY - 10), emoji: '🐾', count: 4);
      _showDialogueBubble('击掌！High Five~ 击退一切烦恼！🐾⭐');
      return;
    }

    // 7. 头部一般触碰
    _onPetTap(Offset(_petX, _petY));
  }

  /// 维度五：跑过来贴贴屏幕 (Glass Boop)
  void _triggerGlassBoop(Size screenSize) {
    if (!mounted || _state == 'GLASS_BOOP') return;
    setState(() {
      _state = 'GLASS_BOOP';
      _hasGlassPawPrints = true;
      _pawPrints = [
        Offset(screenSize.width / 2 - 38, screenSize.height * 0.38 + 22),
        Offset(screenSize.width / 2 + 38, screenSize.height * 0.38 + 22),
      ];
    });
    if (widget.petModel.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    _showDialogueBubble('波可跑来贴贴屏幕啦！主人也在看波可嘛？(ฅ\'ω\'ฅ)💕', duration: const Duration(seconds: 5));

    Timer(const Duration(milliseconds: 4500), () {
      if (mounted && _state == 'GLASS_BOOP') {
        setState(() {
          _state = 'IDLE';
        });
      }
    });
  }

  /// 维度二：从小鱼碗弹射小鲜鱼
  void _popFishFromBowl(double matX, double matY) {
    if (_fishPopping) return;
    setState(() {
      _fishPopping = true;
      _poppingFishPos = Offset(matX - 135, matY - 14);
    });
    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
  }

  /// 逗趣与毛线球主动抛掷
  void _teasePlay() {
    _idleSeconds = 0;
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

    // 首次进入时，自适应设置萌宠在屏幕视觉黄金居中偏上点 (留出下方半屏空间给弹窗)
    if (!_initializedPos && screenSize.width > 0) {
      _petX = screenSize.width / 2;
      _petY = screenSize.height * 0.38;
      _initializedPos = true;
    }

    // 地板与软垫基准位置
    final matX = screenSize.width / 2;
    final matY = screenSize.height * 0.38 + 68.0;

    // 萌宠允许移动的上下安全边界
    const minSafeY = 140.0;
    final maxSafeY = screenSize.height - 180.0;

    // 维度四：昼夜光影与氛围主题
    final circadian = _getCircadianTheme();
    final gradientColors = circadian['colors'] as List<Color>;
    final isNight = circadian['isNight'] as bool;
    final ambientIcon = circadian['icon'] as String;

    // 维度二：毛线球在小窝右侧初始化
    if (!_yarnInitialized && screenSize.width > 0) {
      _yarnX = matX + 110;
      _yarnY = matY - 2;
      _yarnInitialized = true;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 0. 维度四：背景微光氛围天象 (清晨/正午/日落/星夜)
              if (isNight) ...[
                // 月亮：带有微暖柔和金辉的月牙，静静守候
                Positioned(
                  top: 56,
                  right: 28,
                  child: IgnorePointer(
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
                // 漫天静谧微星 (柔和错落分布，营造静谧温馨的星空感)
                Positioned(
                  top: 85,
                  left: 28,
                  child: IgnorePointer(
                    child: Text('✨', style: TextStyle(fontSize: 16, color: const Color(0xFFFDE047).withOpacity(0.7))),
                  ),
                ),
                Positioned(
                  top: 150,
                  right: 70,
                  child: IgnorePointer(
                    child: Text('⭐', style: TextStyle(fontSize: 13, color: Colors.amber.shade100.withOpacity(0.6))),
                  ),
                ),
                Positioned(
                  top: 205,
                  left: 50,
                  child: IgnorePointer(
                    child: Text('✨', style: TextStyle(fontSize: 14, color: Colors.yellow.shade100.withOpacity(0.5))),
                  ),
                ),
                Positioned(
                  top: 170,
                  left: 110,
                  child: IgnorePointer(
                    child: Text('⭐', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
                  ),
                ),
              ] else ...[
                // 白天环境氛围 (太阳/云朵/晚霞)
                Positioned(
                  top: 56,
                  right: 28,
                  child: IgnorePointer(
                    child: Text(ambientIcon, style: const TextStyle(fontSize: 34)),
                  ),
                ),
                Positioned(
                  top: 115,
                  left: 24,
                  child: IgnorePointer(
                    child: Text('☁️', style: TextStyle(fontSize: 22, color: Colors.white.withOpacity(0.6))),
                  ),
                ),
              ],

              // 1. 软萌地毯/专属软垫 (给猫咪一个温暖的家底座，夜晚采用治愈暮紫星空绒垫)
              Positioned(
                left: matX - 100,
                top: matY - 22,
                child: Container(
                  width: 200,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF231E4A).withOpacity(0.90) // 治愈暖调暮紫绒垫
                        : const Color(0xFFFEF3C7).withOpacity(0.88),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isNight
                          ? const Color(0xFF6366F1).withOpacity(0.5) // 星光紫边
                          : const Color(0xFFFDE68A),
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isNight
                            ? const Color(0xFF4338CA).withOpacity(0.25)
                            : const Color(0xFFF59E0B).withOpacity(0.14),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '🐾  Poko\'s Haven  🐾',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isNight ? const Color(0xFFFDE68A) : const Color(0xFFD97706),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),

              // 软垫左侧：精致小猫碗 (维度二：点击弹跳小鲜鱼投喂)
              Positioned(
                left: matX - 148,
                top: matY - 14,
                child: GestureDetector(
                  onTap: () => _popFishFromBowl(matX, matY),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF1E1A40) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isNight ? const Color(0xFF4F46E5).withOpacity(0.4) : const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🥣', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 2),
                        Text('🐟', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
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

              // 维度二：软垫右侧：实体物理毛线球 (支持手指拖拽、用力弹射抛物线与猫咪追球)
              Positioned(
                left: _yarnX - 18,
                top: _yarnY - 18,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _isYarnDragging = true;
                      _isYarnFlying = false;
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
                    final vx = (details.velocity.pixelsPerSecond.dx / 60.0).clamp(-18.0, 18.0);
                    final vy = (details.velocity.pixelsPerSecond.dy / 60.0).clamp(-22.0, 18.0);
                    setState(() {
                      _isYarnDragging = false;
                      _isYarnFlying = true;
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
                ),
              ),

              // 2. 顶部双灵动岛浮空栏 (左侧萌宠身份 + 右侧饱腹心情小窝，告别拥挤，自然呼吸)
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: _buildTopDualIslands(screenSize, isNight),
              ),

              // 3. 萌宠主窗体 (维度一：部位差异化触感与猫咪打呼噜；维度三：剧烈晃动眩晕；维度五：亲密连击与贴贴)
              Positioned(
                left: _petX - 100,
                top: _petY - 100,
                child: GestureDetector(
                  onTapDown: (details) => _handleBodyPartTouch(details.localPosition, screenSize),
                  onDoubleTap: _onPetDoubleTap,
                  onPanStart: (details) {
                    setState(() {
                      _isDragging = true;
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

                      // 维度五：连续抚摸判定与亲密 Combo
                      final delta = details.delta.distance;
                      if (delta > 1.0 && delta < 15.0) {
                        _strokeDistance += delta;
                        if (_strokeDistance > 22.0) {
                          _strokeDistance = 0.0;
                          _petProgress = 1.0;
                          widget.petModel.petHead();

                          _petCombo++;
                          _comboResetTimer?.cancel();
                          _comboResetTimer = Timer(const Duration(milliseconds: 2600), () {
                            if (mounted) {
                              setState(() => _petCombo = 0);
                            }
                          });

                          _spawnParticles(
                            Offset(_petX, _petY - 40),
                            emoji: _petCombo >= 4 ? '💖' : '❤️',
                            count: 1,
                          );
                          if (widget.petModel.enableHaptics) {
                            HapticFeedback.lightImpact();
                          }

                          // 连击达到 6 次触发猫咪贴贴屏幕
                          if (_petCombo >= 6 && _state != 'GLASS_BOOP') {
                            _petCombo = 0;
                            _triggerGlassBoop(screenSize);
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

                      if (_state != 'DIZZY' && _state != 'GLASS_BOOP') {
                        _state = 'IDLE';
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
                                : _touchPos,
                            facingLeft: _facingLeft,
                            petProgress: _petProgress,
                            isPurring: _isPurring,
                            twitchEar: _twitchEar,
                          ),
                        ),
                      );
                    },
                  ),
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

              // 6. 底部“奇妙背包”上拉把手胶囊 (轻点或上滑呼出分类抽屉，底部大解放)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _openBackpackDrawer(isNight),
                    onVerticalDragEnd: (details) {
                      if (details.primaryVelocity != null && details.primaryVelocity! < -50) {
                        _openBackpackDrawer(isNight);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isNight
                            ? const Color(0xFF1E1A40).withOpacity(0.88)
                            : Colors.white.withOpacity(0.92),
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
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎒', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 7),
                          Text(
                            '奇妙背包',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isNight
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFF334155),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 18,
                            color: isNight
                                ? const Color(0xFFA5B4FC)
                                : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
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

  /// 智能对齐气泡：永不被猫挡住，附带指向小箭头，支持昼夜温润自适应
  Widget _buildSmartDialogueBubble(Size screenSize, bool isNight) {
    final bubbleWidth = math.min(260.0, screenSize.width - 32.0);
    // 水平居中对齐猫咪，并防止超出左右屏
    final bubbleLeft = (_petX - bubbleWidth / 2).clamp(16.0, screenSize.width - bubbleWidth - 16.0);

    // 垂直方向：如果猫咪在屏幕上方，气泡放猫咪下方；默认放猫咪头顶上方！
    final showAbove = _petY > 210.0;
    final bubbleTop = showAbove ? (_petY - 145.0) : (_petY + 95.0);

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

  /// 顶部双灵动岛浮空栏：左侧身份好感 + 右侧饱腹心情小窝，告别拥挤，自然呼吸
  Widget _buildTopDualIslands(Size screenSize, bool isNight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. 左侧灵动岛：萌宠等级、名称与亲密值
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isNight
                ? const Color(0xFF181534).withOpacity(0.85)
                : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isNight ? const Color(0xFF6366F1).withOpacity(0.35) : Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isNight
                    ? const Color(0xFF0F0C24).withOpacity(0.5)
                    : const Color(0xFF6366F1).withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 等级徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Lv.${widget.petModel.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              // 萌宠名称与亲密值
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.petModel.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: isNight ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '❤️ ${widget.petModel.intimacy}',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: isNight ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. 右侧灵动岛：饱腹、心情与小窝重置
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isNight
                ? const Color(0xFF181534).withOpacity(0.85)
                : Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isNight ? const Color(0xFF6366F1).withOpacity(0.35) : Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isNight
                    ? const Color(0xFF0F0C24).withOpacity(0.5)
                    : const Color(0xFF6366F1).withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 饱腹指示
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🍗', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 3),
                  Text(
                    '${widget.petModel.hunger.toInt()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // 分隔微点
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              // 心情指示
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('💖', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 3),
                  Text(
                    '${widget.petModel.mood.toInt()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // 回到小窝按钮
              GestureDetector(
                onTap: () => _resetToMat(screenSize),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isNight ? const Color(0xFF26204E) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isNight ? const Color(0xFF4F46E5).withOpacity(0.4) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Icon(
                    Icons.home_rounded,
                    size: 14,
                    color: isNight ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                  ),
                ),
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
}
