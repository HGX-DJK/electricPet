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

class _PetScreenState extends State<PetScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _decayTimer;
  Timer? _dialogueTimer;

  // 萌宠坐标与物理重力
  double _petX = 180.0;
  double _petY = 380.0;
  double _vy = 0.0;
  bool _isDragging = false;
  String _state = 'IDLE';
  bool _facingLeft = false;

  // 摸头抚摸累积
  double _strokeDistance = 0.0;
  double _petProgress = 0.0;
  Offset? _touchPos;

  // 气泡台词系统
  String _currentDialogue = '喵呜~ 主人，波可随时在手机里陪着您呢！(ฅ\'ω\'ฅ)';
  bool _showDialogue = true;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // 状态衰减与漫步定时器 (1秒)
    _decayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      widget.petModel.tickDecay(1.0);
      _checkAutoRoam();
    });

    // 初始欢迎台词
    _showDialogueBubble('主人！今天也要元气满满哦，快摸摸我的小脑瓜~ ✨');
  }

  @override
  void dispose() {
    _animController.dispose();
    _decayTimer?.cancel();
    _dialogueTimer?.cancel();
    super.dispose();
  }

  void _showDialogueBubble(String text, {Duration duration = const Duration(seconds: 4)}) {
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

  void _checkAutoRoam() {
    if (_isDragging || widget.petModel.isSleeping || _state != 'IDLE') return;
    if (math.Random().nextDouble() < 0.25) {
      // 随机冒出一句暖心台词
      final lines = [
        '主人看屏幕累了吗？眨眨眼休息一下吧~ 🐾',
        '波可偷偷在草稿纸上画了主人的笑脸！💕',
        '咕噜噜... 只要在主人身边就最安心了~ ✨',
        '今天的天气好舒服，想和主人一起晒太阳！☀️',
      ];
      _showDialogueBubble(lines[math.Random().nextInt(lines.length)]);
    }
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final floorY = screenSize.height - 220.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8FAFC),
              Color(0xFFEFF6FF),
              Color(0xFFF1F5F9),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 1. 顶部状态胶囊栏 (等级、好感度、饱腹、心情)
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: _buildTopStatsBar(),
              ),

              // 2. 地板阴影线
              Positioned(
                top: floorY + 85,
                left: 20,
                right: 20,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 3. 对话气泡 (跟随萌宠头顶浮现)
              if (_showDialogue)
                Positioned(
                  left: math.max(16.0, math.min(_petX - 80, screenSize.width - 240)),
                  top: math.max(65.0, _petY - 70),
                  child: _buildSpeechBubble(),
                ),

              // 4. 萌宠主窗体 (支持手势拖拽、抛掷回弹与边缘偷看)
              Positioned(
                left: _petX - 100,
                top: _petY - 100,
                child: GestureDetector(
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
                      _facingLeft = (details.delta.dx < -1.0);
                      _touchPos = details.localPosition;

                      // 抚摸判定
                      final delta = details.delta.distance;
                      if (delta < 5.0) {
                        _strokeDistance += delta;
                        if (_strokeDistance > 25.0) {
                          _strokeDistance = 0.0;
                          _petProgress = 1.0;
                          widget.petModel.petHead();
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

                      // 贴边探头偷看判定 (靠屏幕边缘 < 45px 自动贴边)
                      if (_petX < 65) {
                        _state = 'PEEK_LEFT';
                        _petX = 35;
                        _showDialogueBubble('探头偷看~ 主人在忙什么呀？👀');
                        return;
                      } else if (_petX > screenSize.width - 65) {
                        _state = 'PEEK_RIGHT';
                        _petX = screenSize.width - 35;
                        _showDialogueBubble('探头偷看~ 报告主人，屏幕右侧安全！🐾');
                        return;
                      }

                      // 地面重力落地
                      if (_petY < floorY) {
                        _petY = floorY;
                      }
                      _state = 'IDLE';
                    });
                  },
                  child: AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(200, 200),
                        painter: PetPainter(
                          model: widget.petModel,
                          animTime: _animController.value * 10,
                          state: _state,
                          touchPos: _touchPos,
                          facingLeft: _facingLeft,
                          petProgress: _petProgress,
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 5. 底部灵动伴侣岛 Dock
              Positioned(
                bottom: 24,
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

  Widget _buildTopStatsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
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
              color: const Color(0xFF4F46E5),
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
            children: [
              Text(
                widget.petModel.name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 2),
              Text(
                '❤️ 亲密度 ${widget.petModel.intimacy}',
                style: const TextStyle(fontSize: 10, color: Color(0xFFE11D48)),
              ),
            ],
          ),
          const Spacer(),
          _buildMiniBar('饱腹', widget.petModel.hunger / 100, const Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          _buildMiniBar('心情', widget.petModel.mood / 100, const Color(0xFF10B981)),
        ],
      ),
    );
  }

  Widget _buildMiniBar(String label, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$label ${(pct * 100).toInt()}%',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 3),
        Container(
          width: 52,
          height: 6,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          child: Container(
            width: 52 * pct.clamp(0.0, 1.0),
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

  Widget _buildSpeechBubble() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        _currentDialogue,
        style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), height: 1.4),
      ),
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
