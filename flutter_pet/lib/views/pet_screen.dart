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

/// 触摸产生的飘浮爱心与星光特效粒子
class _Particle {
  final Key id = UniqueKey();
  Offset position;
  final String text;
  double progress = 0.0; // 0.0 -> 1.0

  _Particle({
    required this.position,
    required this.text,
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

    // 粒子飞升帧驱动定时器 (60fps)
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

    // 状态自然衰减与自言自语定时器
    _decayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      widget.petModel.tickDecay(1.0);
      _checkAutoDialogue();
    });

    // 启动初始对话
    _showDialogueBubble('主人！今天也要元气满满哦，随时随地陪着您~ ✨');
  }

  @override
  void dispose() {
    _idleAnimController.dispose();
    _squishController.dispose();
    _decayTimer?.cancel();
    _dialogueTimer?.cancel();
    _particleTimer?.cancel();
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

  /// 触碰/戳戳萌宠
  void _onPetTap(Offset globalPos) {
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
    if (widget.petModel.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    _playAction('HAPPY_SPIN');
    _spawnParticles(Offset(_petX, _petY - 40), emoji: '⭐', count: 6);
  }

  void _playAction(String actionId) {
    if (widget.petModel.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
    setState(() {
      _state = actionId;
    });

    final actionLines = {
      'CARDBOARD_BOX': '钻进快递纸箱啦！好有安全感，探头偷看~ 📦✨',
      'CATCH_MOUSE': '看我的喵影神捕！敏捷一扑抓住小老鼠啦！🐭💨',
      'PLAY_YARN': '粉红毛线球滚呀滚~ 抱紧滚来滚去！🧶🐾',
      'PEEK_EDGE': '悄悄趴在屏幕边上偷看主人写代码~ 👀💕',
      'WASH_FACE': '爪爪沾沾温水，认真洗脸理毛变帅帅~ 🫧',
      'HAPPY_SPIN': '开心到飞起！旋转跳跃转圈圈~ 💫(✧ω✧)',
      'STRETCH_YAWN': '哈欠连天~ 伸个大大的懒腰，浑身舒畅！🥱',
      'TILT_HEAD': '歪头好奇打量~ 主人又在看什么有趣的内容呢？❓',
      'DIZZY': '小星星在头上转呀转~ 晕乎乎晃悠悠~ ⭐🌀',
    };

    final msg = actionLines[actionId] ?? '波可展现了独家才艺！✨';
    _showDialogueBubble(msg, duration: const Duration(seconds: 5));

    Timer(const Duration(milliseconds: 4800), () {
      if (mounted && _state == actionId) {
        setState(() {
          _state = 'IDLE';
        });
      }
    });
  }

  /// 重置萌宠回到中心软垫
  void _resetToMat(Size screenSize) {
    setState(() {
      _petX = screenSize.width / 2;
      _petY = screenSize.height * 0.44;
      _state = 'IDLE';
    });
    _showDialogueBubble('回到专属小软垫啦！舒服坐好~ 🐾');
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
              Color(0xFFF0FDF4), // 晨光马卡龙薄荷浅绿
              Color(0xFFF8FAFC), // 纯净奶油白
              Color(0xFFEEF2FF), // 治愈风铃草蓝
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 0. 背景微光氛围装饰 (萌宠小屋感)
              Positioned(
                top: 80,
                right: 30,
                child: Text('☁️', style: TextStyle(fontSize: 32, color: Colors.white.withOpacity(0.5))),
              ),
              Positioned(
                top: 140,
                left: 24,
                child: Text('✨', style: TextStyle(fontSize: 22, color: const Color(0xFFFDE047).withOpacity(0.7))),
              ),

              // 1. 软萌地毯/专属软垫 (给猫咪一个温暖的家底座)
              Positioned(
                left: matX - 95,
                top: matY - 22,
                child: Container(
                  width: 190,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withOpacity(0.65), // 暖杏黄奶酪垫
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFFDE68A).withOpacity(0.8),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '🐾  Poko\'s Mat  🐾',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFD97706),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),

              // 2. 顶部状态胶囊栏 (等级、好感度、饱腹、心情、重置快捷键)
              Positioned(
                top: 10,
                left: 16,
                right: 16,
                child: _buildTopStatsBar(screenSize),
              ),

              // 3. 萌宠主窗体 (支持手势拖拽、点击、双击、抚摸挠下巴与边缘偷看)
              Positioned(
                left: _petX - 100,
                top: _petY - 100,
                child: GestureDetector(
                  onTap: () => _onPetTap(Offset(_petX, _petY)),
                  onDoubleTap: _onPetDoubleTap,
                  onPanStart: (details) {
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

                      // 抚摸判定 (轻微滑动即算抚摸，产生心心)
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
                            fontSize: 22,
                            shadows: [
                              Shadow(
                                color: Colors.white.withOpacity(0.8),
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
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: CompanionDock(
                    model: widget.petModel,
                    onFeedTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => FeedingDialog(
                          model: widget.petModel,
                          onFeedSelected: (foodId) {
                            widget.petModel.feed(foodId);
                            _spawnParticles(Offset(_petX, _petY - 20), emoji: '🐟', count: 4);
                            _showDialogueBubble('哇！好吃到打滚~ 饱腹感满满！(๑´ڡ`๑)');
                          },
                        ),
                      );
                    },
                    onWardrobeTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => WardrobeDialog(model: widget.petModel),
                      );
                    },
                    onActionTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => ActionDialog(
                          onActionSelected: (actId) {
                            _playAction(actId);
                          },
                        ),
                      );
                    },
                    onMemoTap: () {
                      showDialog(
                        context: context,
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
                      _showFloatingNotice();
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

  /// 智能对齐气泡：永不被猫挡住，附带指向小箭头
  Widget _buildSmartDialogueBubble(Size screenSize) {
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
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE0E7FF), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.12),
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

  Widget _buildTopStatsBar(Size screenSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Lv.${widget.petModel.level}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.petModel.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 1),
              Text(
                '❤️ 亲密 ${widget.petModel.intimacy}',
                style: const TextStyle(fontSize: 10, color: Color(0xFFE11D48), fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Spacer(),
          _buildMiniBar('饱腹', widget.petModel.hunger / 100, const Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          _buildMiniBar('心情', widget.petModel.mood / 100, const Color(0xFF10B981)),
          const SizedBox(width: 8),
          // 一键重置回小窝按钮
          GestureDetector(
            onTap: () => _resetToMat(screenSize),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.home_rounded, size: 16, color: Color(0xFF64748B)),
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
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 3),
        Container(
          width: 48,
          height: 6,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
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

  void _showFloatingNotice() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Text('📱', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('全局屏幕悬浮窗模式', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '在 Android 设备上，波可支持突破 App 窗口界限，悬浮在手机桌面、微信、浏览器等任意应用的最上层。\n\n开启此模式需要授予“显示在其他应用上层”权限。',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道啦'),
          ),
        ],
      ),
    );
  }
}
