import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/haptic_service.dart';
import '../../services/minimax_service.dart';
import '../../services/sound_service.dart';

/// 波可与主人的 MiniMax AI 语音伴侣交互界面
class AiVoiceChatDialog extends StatefulWidget {
  final bool isNight;
  final Function(String action, String dialogue) onActionTriggered;

  const AiVoiceChatDialog({
    super.key,
    required this.isNight,
    required this.onActionTriggered,
  });

  /// 快速便捷弹出语音伴侣面板
  static Future<void> show(
    BuildContext context, {
    required bool isNight,
    required Function(String action, String dialogue) onActionTriggered,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiVoiceChatDialog(
        isNight: isNight,
        onActionTriggered: onActionTriggered,
      ),
    );
  }

  @override
  State<AiVoiceChatDialog> createState() => _AiVoiceChatDialogState();
}

class _AiVoiceChatDialogState extends State<AiVoiceChatDialog> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MinimaxService _ai = MinimaxService.instance;

  bool _isLoading = false;
  bool _isListening = false;
  bool _showKeyboardInput = false;
  Timer? _listeningTimer;
  late final AnimationController _waveAnimController;

  final List<String> _quickPrompts = const [
    '🐟 投喂小鱼干',
    '🌙 晚安睡觉觉',
    '🧶 陪我玩毛线球',
    '🌀 跳个开心大回旋',
    '🐾 今天好累求摸摸',
    '🐱 讲个猫猫悄悄话',
    '✨ 你最喜欢吃什么呀',
  ];

  @override
  void initState() {
    super.initState();
    _ai.init();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    _listeningTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isLoading) return;

    _textController.clear();
    _waveAnimController.repeat(reverse: true);
    setState(() {
      _isLoading = true;
      _isListening = false;
    });
    _scrollToBottom();
    HapticService.selection();

    final resp = await _ai.chatWithPoko(query);

    if (mounted) {
      _waveAnimController.stop();
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();

      // 播放语音响应 (MiniMax T2A 音频或回退喵叫)
      _ai.playVoiceResponse(resp.audioBytes);

      // 若大模型给出了物理动作指令，联动驱动房间内的小猫执行动作！
      if (resp.action != null && resp.action!.isNotEmpty) {
        widget.onActionTriggered(resp.action!, resp.text);
      }
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _listeningTimer?.cancel();
      _waveAnimController.stop();
      setState(() => _isListening = false);
    } else {
      HapticService.medium();
      SoundService.playPop();
      _waveAnimController.repeat(reverse: true);
      setState(() => _isListening = true);

      // 模拟 2.2 秒自然语音倾诉捕获后自动提交 (支持后续外接 speech_to_text 实时流)
      _listeningTimer?.cancel();
      _listeningTimer = Timer(const Duration(milliseconds: 2400), () {
        if (!mounted || !_isListening) return;
        final mockPool = [
          '波可，今天写代码好累啊，求摸摸头~',
          '波可，给你准备了香酥小鱼干，快来吃呀！',
          '波可，要睡觉啦，我们互道晚安好不好？',
          '波可，来表演一个超级无敌大回旋跳舞吧！',
          '波可，毛线球准备好啦，出来玩耍咯！',
        ];
        final picked = mockPool[DateTime.now().millisecond % mockPool.length];
        _sendMessage(picked);
      });
    }
  }

  void _openSettingsDialog() {
    final keyController = TextEditingController(text: _ai.apiKey);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: widget.isNight ? const Color(0xFF1E1B4B) : Colors.white,
          title: Row(
            children: [
              const Text('⚙️', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                'MiniMax AI 配置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.isNight ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '输入 MiniMax API Key 即可激活大模型智能陪伴与高保真小奶音 T2A 语音合成。若不填，将自动使用本地智能引擎！',
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: keyController,
                obscureText: true,
                style: TextStyle(color: widget.isNight ? Colors.white : Colors.black, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'MiniMax API Key',
                  hintText: 'ey...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _ai.updateConfig(apiKey: keyController.text);
                if (ctx.mounted) Navigator.pop(ctx);
                setState(() {});
                HapticService.light();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isNight = widget.isNight;
    final history = _ai.chatHistory;

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: isNight
            ? const Color(0xFF16142E).withValues(alpha: 0.96)
            : const Color(0xFFFAF5FF).withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isNight ? const Color(0xFF6366F1).withValues(alpha: 0.35) : const Color(0xFFE9D5FF),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 28, offset: Offset(0, -6)),
        ],
      ),
      child: Column(
        children: [
          // 1. 顶部手柄与功能导航栏
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 14, 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isNight ? const Color(0xFF26234F) : const Color(0xFFF3E8FF),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                // 呼吸光环小头像
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFF6366F1)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(child: Text('🐱', style: TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '波可的 AI 语音小电台',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isNight ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('🎙️', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6.5,
                            height: 6.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _ai.hasApiKey ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _ai.hasApiKey ? 'MiniMax 神经语音就绪' : '智能陪伴模式 (点击设置 Key)',
                            style: TextStyle(
                              fontSize: 10,
                              color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF7E22CE),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 设置按钮
                IconButton(
                  icon: const Text('⚙️', style: TextStyle(fontSize: 18)),
                  onPressed: _openSettingsDialog,
                  tooltip: '设置 API Key',
                ),
                // 关闭按钮
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF26234F) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. 聊天对话气泡记录滚动区
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🐾', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 10),
                        Text(
                          '对波可说句话吧~ 可以聊心事、也可以喊开饭或玩耍哦！',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isNight ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final msg = history[index];
                      final isUser = msg.role == 'user';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEDE9FE),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(child: Text('🐱', style: TextStyle(fontSize: 16))),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9.5),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? const Color(0xFF6366F1)
                                      : (isNight ? const Color(0xFF211D44) : Colors.white),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                                    bottomRight: Radius.circular(isUser ? 4 : 16),
                                  ),
                                  border: Border.all(
                                    color: isUser
                                        ? const Color(0xFF4F46E5)
                                        : (isNight ? const Color(0xFF3B356D) : const Color(0xFFE2E8F0)),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg.content,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: isUser
                                        ? Colors.white
                                        : (isNight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                                  ),
                                ),
                              ),
                            ),
                            if (isUser) const SizedBox(width: 4),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // 3. AI 思考中 / 声波动画指示条
          if (_isLoading || _isListening)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _waveAnimController,
                    builder: (context, _) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) {
                          final height = 6.0 + 12.0 * math.sin((_waveAnimController.value * math.pi) + (i * 0.6)).abs();
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 3.5,
                            height: height,
                            decoration: BoxDecoration(
                              color: _isListening ? const Color(0xFFEF4444) : const Color(0xFFA855F7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isListening ? '正在倾听主人的心声... 🎙️' : '波可正在用猫猫脑瓜认真思考中... ✨',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                    ),
                  ),
                ],
              ),
            ),

          // 4. 快捷灵感话题横滑标签 (Quick Action Chips)
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                return GestureDetector(
                  onTap: () => _sendMessage(prompt),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF241F48) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isNight ? const Color(0xFF4C4482) : const Color(0xFFE9D5FF),
                      ),
                    ),
                    child: Text(
                      prompt,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isNight ? const Color(0xFFE0E7FF) : const Color(0xFF581C87),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // 5. 底部语音 / 键盘输入控制条
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
            decoration: BoxDecoration(
              color: isNight ? const Color(0xFF1E1A3C) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isNight ? const Color(0xFF2D275A) : const Color(0xFFF1F5F9),
                  width: 1.0,
                ),
              ),
            ),
            child: _showKeyboardInput
                ? Row(
                    children: [
                      IconButton(
                        icon: const Text('🎙️', style: TextStyle(fontSize: 20)),
                        onPressed: () => setState(() => _showKeyboardInput = false),
                        tooltip: '切换至按住语音',
                      ),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: _sendMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: isNight ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: '对波可说点什么吧...',
                            hintStyle: TextStyle(
                              color: isNight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: isNight ? const Color(0xFF282352) : const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Color(0xFF6366F1), size: 22),
                        onPressed: () => _sendMessage(_textController.text),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_alt_rounded, color: Color(0xFF8B5CF6), size: 22),
                        onPressed: () => setState(() => _showKeyboardInput = true),
                        tooltip: '切换文字输入',
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _toggleListening,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: _isListening
                                    ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                                    : [const Color(0xFFA855F7), const Color(0xFF6366F1)],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening ? const Color(0xFFEF4444) : const Color(0xFF6366F1))
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_isListening ? '🛑' : '🎙️', style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  _isListening ? '正在倾听... (轻触发送)' : '轻触对波可说话',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 清空记录按钮
                      IconButton(
                        icon: const Text('🧹', style: TextStyle(fontSize: 16)),
                        onPressed: () {
                          _ai.clearHistory();
                          setState(() {});
                          HapticService.light();
                        },
                        tooltip: '清空记忆',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
