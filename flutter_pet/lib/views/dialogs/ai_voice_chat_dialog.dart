import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../../services/haptic_service.dart';
import '../../services/minimax_service.dart';
import '../../services/sound_service.dart';

/// 波可与主人的 MiniMax AI 语音伴侣交互界面
class AiVoiceChatDialog extends StatefulWidget {
  final bool isNight;
  final bool autoStartListening;
  final Function(String action, String dialogue) onActionTriggered;

  /// 注入的 AI 服务 (默认使用全局单例, 供单元测试替换为桩实现)
  final MinimaxService? aiService;

  const AiVoiceChatDialog({
    super.key,
    required this.isNight,
    this.autoStartListening = false,
    required this.onActionTriggered,
    this.aiService,
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
  final AudioRecorder _audioRecorder = AudioRecorder();
  late final MinimaxService _ai;

  /// 大模型请求进行中 (气泡上屏 + 动作联动)
  bool _isSending = false;
  /// 录音结束后的语音识别进行中
  bool _isTranscribing = false;
  /// 麦克风正在收音
  bool _isRecording = false;
  /// 录音启动流程进行中 (含权限申请, 防止重复启动)
  bool _isStarting = false;
  /// 当前的录音启动流程, 供"松手"时等待其真正建立 (修复长按竞态)
  Future<void>? _startFuture;
  /// 本次录音的临时文件路径 (转写完成后清理)
  String? _currentRecordPath;
  /// 单次录音时长上限的看门狗
  Timer? _maxRecordTimer;

  /// 是否处于"等待回复"的忙碌态 (UI 指示条)
  bool get _isBusy => _isSending || _isTranscribing;

  bool _showKeyboardInput = false;
  late final AnimationController _waveAnimController;

  /// 预置心声 —— 统一收在「💭 心声」面板里, 主面板不再重复堆一排按钮
  final List<({String emoji, String text})> _presetPhrases = const [
    (emoji: '🐟', text: '波可，给你准备了香酥小鱼干，快来吃呀！'),
    (emoji: '🌙', text: '波可，今天好累呀，互道晚安睡觉觉好不好？'),
    (emoji: '🌀', text: '波可，来表演一个超级无敌大回旋跳舞吧！'),
    (emoji: '🧶', text: '波可，毛线球准备好啦，出来玩耍咯！'),
    (emoji: '🐾', text: '波可，写代码好累啊，求摸摸头安慰一下~'),
    (emoji: '🐱', text: '波可，讲个猫猫悄悄话哄我开心好不好？'),
  ];

  @override
  void initState() {
    super.initState();
    _ai = widget.aiService ?? MinimaxService.instance;
    _ai.init();
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.autoStartListening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isRecording) _ensureRecording();
      });
    }
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    _maxRecordTimer?.cancel();
    _maxRecordTimer = null;
    // 关闭面板时掐断小奶音, 避免弹窗已消失仍在后台说话
    _ai.stopVoice();
    try {
      _audioRecorder.dispose();
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

  /// 统一的轻提示
  void _showToast(String message, {Duration duration = const Duration(seconds: 2)}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
      ),
    );
  }

  /// 统一的发送入口。守卫只看 [_isSending] —— 语音识别阶段 ([_isTranscribing]) 不拦截,
  /// 否则"录音 → 识别 → 发送"链路会因为识别中已置 busy 而被静默丢弃。
  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isSending) return;

    _textController.clear();
    _waveAnimController.repeat(reverse: true);
    setState(() {
      _isSending = true;
      _isRecording = false;
    });
    _scrollToBottom();
    HapticService.selection();

    try {
      final resp = await _ai.chatWithPoko(
        query,
        // 语音合成在服务端后台完成, 到达后再播 —— 文本气泡无需等待 TTS
        onAudioReady: (audio) {
          if (mounted) _ai.playVoiceResponse(audio);
        },
      );

      if (mounted) {
        _scrollToBottom();

        // 若大模型给出了物理动作指令，联动驱动房间内的小猫执行动作！
        if (resp.action != null && resp.action!.isNotEmpty) {
          widget.onActionTriggered(resp.action!, resp.text);
        }
      }
    } finally {
      if (mounted) {
        _waveAnimController.stop();
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _toggleListening() async {
    if (_isRecording) {
      await _stopRecordingAndProcess();
    } else {
      await _ensureRecording();
    }
  }

  /// 幂等地启动录音, 并记录启动流程供"松手"时等待
  /// (修复: 长按对讲时, 权限申请尚未完成就松手, 旧实现会直接 return 导致录音停不下来)
  Future<void> _ensureRecording() {
    final pending = _startFuture;
    if (pending != null) return pending;

    final future = _doStartRecording();
    _startFuture = future;
    // 启动结束后释放句柄, 允许下一次录音
    future.whenComplete(() {
      if (identical(_startFuture, future)) _startFuture = null;
    });
    return future;
  }

  Future<void> _doStartRecording() async {
    if (_isRecording || _isStarting) return;
    _isStarting = true;
    try {
      // 先掐断正在播放的小奶音, 否则麦克风会录到波可自己的声音 (自我识别 + 啸叫)
      await _ai.stopVoice();

      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          _showToast('🎙️ 麦克风录音权限未开启，请在手机系统设置中授予麦克风权限！',
              duration: const Duration(seconds: 3));
        }
        return;
      }

      HapticService.medium();
      SoundService.playPop();

      final tempDir = Directory.systemTemp;
      _currentRecordPath =
          '${tempDir.path}/poko_user_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          bitRate: 64000,
        ),
        path: _currentRecordPath!,
      );

      // 单次录音最长 60 秒 (record 包未提供 maxDuration, 这里自行兜底,
      // 防止主人忘记松手导致音频文件无限增长)
      _maxRecordTimer?.cancel();
      _maxRecordTimer = Timer(const Duration(seconds: 60), () {
        if (mounted && _isRecording) _stopRecordingAndProcess();
      });

      if (mounted) {
        setState(() {
          _isRecording = true;
        });
        _waveAnimController.repeat(reverse: true);
      }
    } catch (e) {
      debugPrint('Start recording error: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
        _waveAnimController.stop();
        _showToast('🎙️ 麦克风启动失败，请重试~');
      }
    } finally {
      _isStarting = false;
    }
  }

  /// 停止录音 → 语音识别 → 把识别文本送入大模型
  Future<void> _stopRecordingAndProcess() async {
    if (_isTranscribing) return;

    // 等待可能仍在进行中的启动流程, 避免"松手"时录音尚未建立就直接返回
    final pending = _startFuture;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    if (!_isRecording) return;

    HapticService.light();
    _waveAnimController.stop();
    _maxRecordTimer?.cancel();
    _maxRecordTimer = null;

    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    String? recordPath;
    try {
      final path = await _audioRecorder.stop();
      recordPath = path ?? _currentRecordPath;
      final audioFile = File(recordPath ?? '');

      // 使用同步 stat: 单次系统调用, 既避免 async I/O 带来的竞态窗口
      // (两次 await 之间文件可能被并发清理), 也让该链路可在单元测试中稳定复现
      if (audioFile.existsSync() && audioFile.lengthSync() > 300) {
        final recognized = await _ai.transcribeAudio(audioFile);
        if (recognized != null && recognized.trim().isNotEmpty) {
          // ★ 关键: 识别文本必须真正送进大模型 (此处不再被 busy 守卫拦截)
          await _sendMessage(recognized.trim());
          return;
        }
        // 识别失败: 透出具体原因, 区分"没听清"与"服务异常"
        final reason = _ai.lastAsrError;
        _showToast(reason == null
            ? '🐱 说话时间太短或未能听清，请离麦克风近一点再说一次好不好嘛~ 🐾'
            : '🐱 $reason');
        return;
      }

      _showToast('🐱 说话时间太短或未能听清，请离麦克风近一点再说一次好不好嘛~ 🐾');
    } catch (e) {
      debugPrint('Audio recording/transcribe error: $e');
      if (mounted) {
        _showToast('🎙️ 录音或识别出错了，请再试一次~');
      }
    } finally {
      // 清理录音临时文件, 避免缓存目录无限堆积 (非阻塞, 不拖慢界面流程)
      final tempPath = recordPath;
      if (tempPath != null) {
        File(tempPath).delete().then((_) {}).catchError((_) {});
      }
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF1E1B4B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -6)),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 拖拽手柄
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isNight ? const Color(0xFF3B356D) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                    child: Row(
                      children: [
                        const Text('💭', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Text(
                          '想和波可说点什么？',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: isNight ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                    child: Text(
                      '选一句心声立刻开聊，或者直接按住麦克风说话~',
                      style: TextStyle(
                        fontSize: 12,
                        color: isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),

                  // 预置心声: 整行可点, 比小圆片更好读
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (final p in _presetPhrases)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _presetRow(ctx, p.emoji, p.text, isNight),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isNight ? const Color(0xFF2E2A60) : const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(height: 4),

                  // 次级操作收拢到面板底部, 主面板不再堆按钮
                  Row(
                    children: [
                      Expanded(
                        child: _sheetAction(
                          ctx,
                          icon: Icons.keyboard_alt_rounded,
                          label: '切换到打字输入',
                          isNight: isNight,
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() => _showKeyboardInput = true);
                          },
                        ),
                      ),
                      Expanded(
                        child: _sheetAction(
                          ctx,
                          icon: Icons.auto_delete_outlined,
                          label: '清空记忆',
                          isNight: isNight,
                          onTap: () {
                            Navigator.pop(ctx);
                            _ai.clearHistory();
                            setState(() {});
                            HapticService.light();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 预置心声的整行条目
  Widget _presetRow(BuildContext ctx, String emoji, String text, bool isNight) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pop(ctx);
          _sendMessage(text);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF262352) : const Color(0xFFFAF7FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isNight ? const Color(0xFF3B356D) : const Color(0xFFEDE9FE),
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: isNight ? const Color(0xFFE0E7FF) : const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isNight ? const Color(0xFF6366F1) : const Color(0xFFA78BFA),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 面板底部的次级操作按钮
  Widget _sheetAction(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required bool isNight,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF7C3AED)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF7C3AED),
              ),
            ),
          ],
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
                      '选择大模型服务商并填入对应的 API Key。配置后即可体验大语言模型深度对话与专属萌系小奶音朗读！\n'
                      '💡 未配置时波可会自动切换为「本地拟真陪伴模式」，功能依然可用。',
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

  /// 状态胶囊: 绿=就绪 / 橙=本地陪伴 / 红=云端异常, 点击可直接进入设置排查
  Widget _statusPill(bool isNight) {
    final hasError = _ai.lastError != null;
    final color = hasError
        ? const Color(0xFFEF4444)
        : (_ai.hasApiKey ? const Color(0xFF10B981) : const Color(0xFFF59E0B));
    final label = hasError
        ? '云端连接异常'
        : (_ai.hasApiKey ? '就绪' : '智能陪伴模式');
    return GestureDetector(
      onTap: _openSettingsDialog,
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.1,
                color: isNight ? color.withValues(alpha: 0.95) : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 头部圆形图标按钮 (视觉成对, 统一尺寸)
  Widget _roundIconButton({
    required IconData icon,
    required String tooltip,
    required bool isNight,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticService.light();
          onTap();
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF26234F) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  /// 语音模式输入条: 💭 心声 | 大麦克风 | 键盘
  Widget _voiceInputBar(bool isNight) {
    return Row(
      children: [
        _softCircleButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: '快捷心声',
          isNight: isNight,
          onTap: _showVoiceSpeechSheet,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _toggleListening,
            onLongPressStart: (_) {
              // 按住即开始录音; 内部会等待权限申请完成
              _ensureRecording();
            },
            onLongPressEnd: (_) {
              // 松手即停止并转写; 内部会等待录音真正建立, 避免竞态漏停
              _stopRecordingAndProcess();
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isRecording
                      ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
                      : const [Color(0xFFA855F7), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF6366F1))
                        .withValues(alpha: _isRecording ? 0.42 : 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isRecording ? '🛑' : '🎙️', style: const TextStyle(fontSize: 19)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _isRecording ? '正在录音中... (松手或点击发送)' : '轻触对波可说话',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
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
        const SizedBox(width: 10),
        _softCircleButton(
          icon: Icons.keyboard_alt_outlined,
          tooltip: '打字输入',
          isNight: isNight,
          onTap: () => setState(() => _showKeyboardInput = true),
        ),
      ],
    );
  }

  /// 打字模式输入条: 💭 心声 | 🎤 + 输入框 + 发送
  Widget _keyboardInputBar(bool isNight) {
    return Row(
      children: [
        _softCircleButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: '快捷心声',
          isNight: isNight,
          onTap: _showVoiceSpeechSheet,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: isNight ? const Color(0xFF282352) : const Color(0xFFF6F7FB),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: isNight ? const Color(0xFF3B356D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                // 回到语音输入
                GestureDetector(
                  onTap: () => setState(() => _showKeyboardInput = false),
                  child: Icon(
                    Icons.mic_rounded,
                    size: 18,
                    color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: isNight ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: '对波可说点什么吧...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: isNight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // 发送
                GestureDetector(
                  onTap: () => _sendMessage(_textController.text),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 底部次级圆形按钮
  Widget _softCircleButton({
    required IconData icon,
    required String tooltip,
    required bool isNight,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          HapticService.light();
          onTap();
        },
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF282352) : const Color(0xFFF1F5F9),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1),
          ),
        ),
      ),
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
          // 1. 顶部: 拖拽手柄 + 紧凑标题栏
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isNight ? const Color(0xFF26234F) : const Color(0xFFF3E8FF),
                  width: 1.0,
                ),
              ),
            ),
            child: Column(
              children: [
                // 拖拽手柄
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 2),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isNight ? const Color(0xFF3B356D) : const Color(0xFFE2D3F7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 12, 12),
                  child: Row(
              children: [
                // 呼吸光环小头像
                Container(
                  width: 34,
                  height: 34,
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
                  child: const Center(child: Text('🐱', style: TextStyle(fontSize: 19))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '波可的小电台',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isNight ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      _statusPill(isNight),
                    ],
                  ),
                ),
                // 设置按钮
                _roundIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: '设置 API Key',
                  isNight: isNight,
                  onTap: _openSettingsDialog,
                ),
                const SizedBox(width: 6),
                // 关闭按钮
                _roundIconButton(
                  icon: Icons.close_rounded,
                  tooltip: '关闭',
                  isNight: isNight,
                  onTap: () => Navigator.pop(context),
                ),
                    ],
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
                                      const SizedBox(height: 4),
                                      // 小奶音重播: 收成一枚圆形图标, 保持气泡干净
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Tooltip(
                                          message: '重播小奶音',
                                          child: GestureDetector(
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
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                color: isNight
                                                    ? const Color(0xFF2E2A60)
                                                    : const Color(0xFFF3E8FF),
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.volume_up_rounded,
                                                size: 14,
                                                color: isNight
                                                    ? const Color(0xFFA5B4FC)
                                                    : const Color(0xFF7C3AED),
                                              ),
                                            ),
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

          // 3. AI 思考中 / 语音识别中 / 录音声波动画指示条
          if (_isBusy || _isRecording)
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
                          final height = 6.0 + 16.0 * math.sin((_waveAnimController.value * math.pi) + (i * 0.6)).abs();
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 3.5,
                            height: height.clamp(4.0, 24.0),
                            decoration: BoxDecoration(
                              color: _isRecording ? const Color(0xFFEF4444) : const Color(0xFFA855F7),
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
                      _isRecording
                          ? '正在倾听主人的声音... 说话完毕轻触或松手即可发送 🎙️'
                          : _isTranscribing
                              ? '正在识别主人的声音... 请稍等喵~ 🐾'
                              : '波可正在用猫猫脑瓜认真思考并生成回复... ✨',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _isRecording ? const Color(0xFFEF4444) : (isNight ? const Color(0xFFA5B4FC) : const Color(0xFF6366F1)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 4. 底部输入区: 💭 心声 | 主输入 | 键盘/发送
          Container(
            decoration: BoxDecoration(
              color: isNight ? const Color(0xFF1E1A3C) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isNight ? const Color(0xFF2D275A) : const Color(0xFFF1F5F9),
                  width: 1.0,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: SafeArea(
              top: false,
              child: _showKeyboardInput
                  ? _keyboardInputBar(isNight)
                  : _voiceInputBar(isNight),
            ),
          ),
        ],
      ),
    );
  }
}
