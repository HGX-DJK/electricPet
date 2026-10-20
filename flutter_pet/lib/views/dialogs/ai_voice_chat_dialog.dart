import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/haptic_service.dart';
import '../../services/minimax_service.dart';
import '../../services/sound_service.dart';

// 波可与主人的 MiniMax AI 语音伴侣交互界面
class AiVoiceChatDialog extends StatefulWidget {
  final bool isNight;
  final bool autoStartListening;
  final Function(String action, String dialogue) onActionTriggered;

  const AiVoiceChatDialog({
    super.key,
    required this.isNight,
    this.autoStartListening = false,
    required this.onActionTriggered,
  });

  /// 快速便捷弹出语音伴侣面板
  static Future<void> show(
    BuildContext context, {
    required bool isNight,
    bool autoStartListening = false,
    required Function(String action, String dialogue) onActionTriggered,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiVoiceChatDialog(
        isNight: isNight,
        autoStartListening: autoStartListening,
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
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isLoading = false;
  bool _speechEnabled = false;
  bool _isRealListening = false;
  String _liveSpokenWords = '';
  double _soundLevel = 0.0;
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
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (err) {
          debugPrint('STT error: ${err.errorMsg}');
          if (mounted) {
            setState(() {
              _isRealListening = false;
              _waveAnimController.stop();
            });
          }
        },
        onStatus: (status) {
          debugPrint('STT status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isRealListening) {
              _stopListeningAndSend();
            }
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechEnabled = available;
        });
        if (widget.autoStartListening && available && !_isRealListening) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _startListening();
          });
        }
      }
    } catch (e) {
      debugPrint('STT initialize failed: $e');
      if (mounted) {
        setState(() {
          _speechEnabled = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    _listeningTimer?.cancel();
    try {
      _speech.stop();
    } catch (_) {}
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
      _isRealListening = false;
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

  Future<void> _toggleListening() async {
    if (_isRealListening) {
      await _stopListeningAndSend();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    HapticService.medium();
    SoundService.playPop();

    if (!_speechEnabled) {
      await _initSpeech();
    }

    if (!_speechEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎙️ 麦克风录音权限未开启或系统未安装语音引擎，已开启打字对话（输入法自带麦克风可语音打字）！'),
            duration: Duration(seconds: 3),
          ),
        );
        _showVoiceSpeechSheet();
      }
      return;
    }

    _liveSpokenWords = '';
    _soundLevel = 0.0;
    setState(() {
      _isRealListening = true;
    });
    _waveAnimController.repeat(reverse: true);

    try {
      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _liveSpokenWords = result.recognizedWords;
            });
            if (result.finalResult && _liveSpokenWords.trim().isNotEmpty) {
              _stopListeningAndSend();
            }
          }
        },
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() {
              _soundLevel = level;
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
          autoPunctuation: true,
        ),
      );
    } catch (e) {
      debugPrint('STT listen error: $e');
      if (mounted) {
        setState(() {
          _isRealListening = false;
        });
        _waveAnimController.stop();
      }
    }
  }

  Future<void> _stopListeningAndSend() async {
    if (!_isRealListening && _liveSpokenWords.trim().isEmpty) return;
    try {
      await _speech.stop();
    } catch (_) {}

    _waveAnimController.stop();
    final toSend = _liveSpokenWords.trim();
    setState(() {
      _isRealListening = false;
      _liveSpokenWords = '';
    });

    if (toSend.isNotEmpty) {
      HapticService.light();
      await _sendMessage(toSend);
    }
  }

  void _showVoiceSpeechSheet() {
    HapticService.medium();
    SoundService.playPop();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isNight = widget.isNight;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF1E1B4B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎙️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    '快捷倾诉与心声互动',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isNight ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFF2E2A60) : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '如需自由语音对话，请点击【切换打字】，使用手机键盘上的麦克风🎙️即可精准语音转文字！',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF6B21A8),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '选择你想对波可说的心声：',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isNight ? Colors.white70 : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _speechChip(ctx, '🐟 波可，给你准备了香酥小鱼干，快来吃呀！'),
                  _speechChip(ctx, '🌙 波可，今天好累呀，互道晚安睡觉觉好不好？'),
                  _speechChip(ctx, '🌀 波可，来表演一个超级无敌大回旋跳舞吧！'),
                  _speechChip(ctx, '🧶 波可，毛线球准备好啦，出来玩耍咯！'),
                  _speechChip(ctx, '🐾 波可，写代码好累啊，求摸摸头安慰一下~'),
                  _speechChip(ctx, '🐱 波可，讲个猫猫悄悄话哄我开心好不好？'),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _showKeyboardInput = true);
                  },
                  icon: const Icon(Icons.keyboard_alt_rounded, size: 18),
                  label: const Text('切换至打字输入 (自由提问与语音转字)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _speechChip(BuildContext ctx, String text) {
    final isNight = widget.isNight;
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        _sendMessage(text);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isNight ? const Color(0xFF282352) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isNight ? const Color(0xFF4338CA) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isNight ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  void _openSettingsDialog() {
    final keyController = TextEditingController(text: _ai.apiKey);
    final customUrlController = TextEditingController(text: _ai.customUrl);
    String selectedProvider = _ai.provider;
    bool isTesting = false;
    bool isTestingVoice = false;
    String? testResult;
    bool? testSuccess;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isNight = widget.isNight;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: isNight ? const Color(0xFF1E1B4B) : Colors.white,
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Row(
                children: [
                  const Text('⚙️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(
                    'AI 大模型与语音配置',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.bold,
                      color: isNight ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '选择大模型服务商并填入对应的 API Key。配置后即可体验大语言模型深度对话与专属萌系小奶音朗读！',
                      style: TextStyle(
                        fontSize: 12,
                        color: isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 服务商选择
                    Text(
                      '模型服务商：',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isNight ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedProvider = 'minimax';
                                testResult = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedProvider == 'minimax'
                                    ? const Color(0xFF6366F1)
                                    : (isNight ? const Color(0xFF2E2A60) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'MiniMax\n(海螺·小奶音)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: selectedProvider == 'minimax'
                                      ? Colors.white
                                      : (isNight ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedProvider = 'deepseek';
                                testResult = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedProvider == 'deepseek'
                                    ? const Color(0xFF0284C7)
                                    : (isNight ? const Color(0xFF2E2A60) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'DeepSeek\n(超高智商)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: selectedProvider == 'deepseek'
                                      ? Colors.white
                                      : (isNight ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedProvider = 'openai';
                                testResult = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selectedProvider == 'openai'
                                    ? const Color(0xFF10B981)
                                    : (isNight ? const Color(0xFF2E2A60) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'OpenAI\n(通用兼容)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: selectedProvider == 'openai'
                                      ? Colors.white
                                      : (isNight ? Colors.white70 : const Color(0xFF475569)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // API Key 输入框
                    TextField(
                      controller: keyController,
                      obscureText: false,
                      style: TextStyle(color: isNight ? Colors.white : Colors.black, fontSize: 12.5),
                      decoration: InputDecoration(
                        labelText: selectedProvider == 'minimax'
                            ? 'MiniMax API Key'
                            : (selectedProvider == 'deepseek' ? 'DeepSeek API Key' : 'OpenAI API Key'),
                        hintText: selectedProvider == 'minimax'
                            ? 'sk-cp--... 或 ey...'
                            : (selectedProvider == 'deepseek' ? 'sk-... (platform.deepseek.com)' : 'sk-...'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),

                    if (selectedProvider == 'openai') ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: customUrlController,
                        style: TextStyle(color: isNight ? Colors.white : Colors.black, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: '自定义接口地址 (可选)',
                          hintText: '默认 https://api.openai.com/v1/chat/completions',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // 测试连接与试听语音按钮
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: isTesting
                              ? null
                              : () async {
                                  setDialogState(() {
                                    isTesting = true;
                                    testResult = null;
                                  });
                                  final res = await _ai.testConnection(
                                    apiKey: keyController.text,
                                    provider: selectedProvider,
                                    customUrl: customUrlController.text,
                                  );
                                  setDialogState(() {
                                    isTesting = false;
                                    testSuccess = res['success'] == true;
                                    testResult = res['message'] as String?;
                                  });
                                },
                          icon: isTesting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('🧪', style: TextStyle(fontSize: 14)),
                          label: Text(isTesting ? '正在测试...' : '测试大模型连接'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: isTestingVoice
                              ? null
                              : () async {
                                  setDialogState(() {
                                    isTestingVoice = true;
                                    testResult = null;
                                  });
                                  final res = await _ai.testVoiceOutput();
                                  setDialogState(() {
                                    isTestingVoice = false;
                                    testSuccess = res['success'] == true;
                                    testResult = res['message'] as String?;
                                  });
                                },
                          icon: isTestingVoice
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('🔊', style: TextStyle(fontSize: 14)),
                          label: Text(isTestingVoice ? '正在发声...' : '试听小奶音'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedProvider == 'minimax'
                          ? '💡 MiniMax 原生支持大模型深度思考与高保真萌宠小奶音朗读'
                          : '💡 对话走 $selectedProvider，语音自动共享 MiniMax 小奶音',
                      style: TextStyle(
                        fontSize: 11,
                        color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                      ),
                    ),

                    if (testResult != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (testSuccess == true)
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (testSuccess == true) ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          testResult!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: (testSuccess == true)
                                ? (isNight ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                                : (isNight ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _ai.updateConfig(
                      apiKey: keyController.text,
                      provider: selectedProvider,
                      customUrl: customUrlController.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                    HapticService.light();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('保存并激活'),
                ),
              ],
            );
          },
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
                              color: (_ai.lastError != null)
                                  ? const Color(0xFFEF4444)
                                  : (_ai.hasApiKey ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (_ai.lastError != null)
                                ? '云端连接异常 (点击 ⚙️ 排查)'
                                : (_ai.hasApiKey ? ' 就绪' : '智能陪伴模式 (点击 ⚙️ 设置)'),
                            style: TextStyle(
                              fontSize: 10,
                              color: (_ai.lastError != null)
                                  ? const Color(0xFFEF4444)
                                  : (isNight ? const Color(0xFFA5B4FC) : const Color(0xFF7E22CE)),
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg.content,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: isUser
                                            ? Colors.white
                                            : (isNight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B)),
                                      ),
                                    ),
                                    if (!isUser) ...[
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () async {
                                          HapticService.light();
                                          if (msg.audioBytes != null && msg.audioBytes!.isNotEmpty) {
                                            await _ai.playVoiceResponse(msg.audioBytes);
                                          } else {
                                            final audio = await _ai.synthesizeVoice(msg.content);
                                            if (audio != null) {
                                              await _ai.playVoiceResponse(audio);
                                            } else {
                                              SoundService.playMeow(tone: MeowTone.sweet);
                                            }
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: isNight ? const Color(0xFF2E2A60) : const Color(0xFFF3E8FF),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isNight ? const Color(0xFF4C4482) : const Color(0xFFE9D5FF),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('🔊', style: TextStyle(fontSize: 11)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '重播小奶音',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF7C3AED),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
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
          if (_isLoading || _isRealListening)
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
                          final dynamicLevel = _isRealListening ? math.max(_soundLevel * 1.5, 0.0) : 0.0;
                          final height = 6.0 + (12.0 + dynamicLevel * 10.0) * math.sin((_waveAnimController.value * math.pi) + (i * 0.6)).abs();
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 3.5,
                            height: height.clamp(4.0, 26.0),
                            decoration: BoxDecoration(
                              color: _isRealListening ? const Color(0xFFEF4444) : const Color(0xFFA855F7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _isRealListening
                          ? (_liveSpokenWords.isEmpty ? '正在倾听主人的声音... 🎙️' : '识别中: "$_liveSpokenWords"')
                          : '波可正在用猫猫脑瓜认真思考中... ✨',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _isRealListening ? const Color(0xFFEF4444) : (isNight ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1)),
                      ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 模式快速切换导航与提示
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _showKeyboardInput = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: _showKeyboardInput
                                ? const Color(0xFF6366F1)
                                : (isNight ? const Color(0xFF282352) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⌨️', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                '键盘打字',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _showKeyboardInput
                                      ? Colors.white
                                      : (isNight ? const Color(0xFFA5B4FC) : const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _showKeyboardInput = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: !_showKeyboardInput
                                ? const Color(0xFF8B5CF6)
                                : (isNight ? const Color(0xFF282352) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🎙️', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                '快捷倾诉',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: !_showKeyboardInput
                                      ? Colors.white
                                      : (isNight ? const Color(0xFFA5B4FC) : const Color(0xFF475569)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '💡 手机输入法自带麦克风可精准语音打字',
                        style: TextStyle(
                          fontSize: 10,
                          color: isNight ? const Color(0xFF818CF8) : const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),
                _showKeyboardInput
                    ? Row(
                        children: [
                          InkWell(
                            onTap: () => setState(() => _showKeyboardInput = false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              decoration: BoxDecoration(
                                color: isNight ? const Color(0xFF282352) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🎙️', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 2),
                                  Text(
                                    '语音',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
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
                                hintText: '对波可说点什么吧...（输入法麦克风可语音打字）',
                                hintStyle: TextStyle(
                                  fontSize: 12,
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
                          InkWell(
                            onTap: () => setState(() => _showKeyboardInput = true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              decoration: BoxDecoration(
                                color: isNight ? const Color(0xFF282352) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.keyboard_alt_rounded,
                                    color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '打字',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: GestureDetector(
                              onTap: _toggleListening,
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _isRealListening
                                        ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                                        : const [Color(0xFFA855F7), Color(0xFF6366F1)],
                                  ),
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isRealListening ? const Color(0xFFEF4444) : const Color(0xFF6366F1)).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_isRealListening ? '🛑' : '🎙️', style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        _isRealListening
                                            ? (_liveSpokenWords.isEmpty ? '正在聆听... (点击发送)' : '点击发送: "$_liveSpokenWords"')
                                            : '轻触对波可说话',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // 快捷心声卡片入口
                          InkWell(
                            onTap: _showVoiceSpeechSheet,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                              decoration: BoxDecoration(
                                color: isNight ? const Color(0xFF282352) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('💡', style: TextStyle(fontSize: 14)),
                                  const SizedBox(width: 2),
                                  Text(
                                    '心声',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
