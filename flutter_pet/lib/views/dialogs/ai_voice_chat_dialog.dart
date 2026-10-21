import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import '../../config/ai_config.dart';
import '../../services/haptic_service.dart';
import '../../services/minimax_service.dart';
import '../../services/sound_service.dart';
import '../../theme/poko_theme.dart';

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
  /// 本次按住是否已超过"认真说话"的最小时长
  bool _micHeldLongEnough = false;
  /// 按住时长判定计时器
  Timer? _micHoldTimer;

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

  /// 麦克风按下: 立刻开始录音 (走原始指针事件, 不经手势竞技场)
  void _onMicPointerDown() {
    _micHeldLongEnough = false;
    _micHoldTimer?.cancel();
    // 用计时器而不是墙钟来判断"是否认真说话": 计时器可被测试时钟驱动, 行为可复现
    _micHoldTimer = Timer(const Duration(milliseconds: 400), () {
      _micHeldLongEnough = true;
    });
    _ensureRecording();
  }

  /// 麦克风抬起: 必定停止录音并发送, 不存在"松手了还在录"的情况
  void _onMicPointerUp({bool cancelled = false}) {
    _micHoldTimer?.cancel();
    _micHoldTimer = null;
    final tooShort = !_micHeldLongEnough;
    _micHeldLongEnough = false;
    _stopRecordingAndProcess(tooShort: tooShort, cancelled: cancelled);
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
  ///
  /// [tooShort] 本次按住过短 (轻触误按), [cancelled] 指针被系统取消
  Future<void> _stopRecordingAndProcess({bool tooShort = false, bool cancelled = false}) async {
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

      // 轻触误按 (按住不足 400ms): 不发送, 改为提示正确用法,
      // 避免用户"松手了却什么都没发生"却不知道该怎么操作
      final isAccidentalTap = tooShort;

      // 使用同步 stat: 单次系统调用, 既避免 async I/O 带来的竞态窗口
      // (两次 await 之间文件可能被并发清理), 也让该链路可在单元测试中稳定复现
      if (!cancelled &&
          !isAccidentalTap &&
          audioFile.existsSync() &&
          audioFile.lengthSync() > 300) {
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

      if (isAccidentalTap) {
        _showToast('🐱 要按住麦克风说话哦，松开手就会发送给波可~');
      } else if (cancelled) {
        _showToast('🐱 这次录音被取消啦，再试一次嘛~');
      } else {
        _showToast('🐱 说话时间太短或未能听清，请离麦克风近一点再说一次好不好嘛~ 🐾');
      }
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
        final t = ctx.poko(isNight);
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(PokoRadius.xl)),
            boxShadow: PokoShadow.layer(t.shadow),
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
                      margin: const EdgeInsets.only(top: PokoSpacing.sm, bottom: PokoSpacing.xs),
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: t.border,
                        borderRadius: BorderRadius.circular(PokoRadius.xs),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        PokoSpacing.xl, PokoSpacing.sm, PokoSpacing.xl, 0),
                    child: Row(
                      children: [
                        const Text('💭', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: PokoSpacing.sm),
                        Text(
                          '想和波可说点什么？',
                          style: TextStyle(
                            fontSize: PokoFont.title,
                            fontWeight: FontWeight.bold,
                            color: t.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        PokoSpacing.xl, PokoSpacing.xs, PokoSpacing.xl, PokoSpacing.lg),
                    child: Text(
                      '选一句心声立刻开聊，或者直接按住麦克风说话~',
                      style: TextStyle(
                        fontSize: PokoFont.small,
                        color: t.textMuted,
                      ),
                    ),
                  ),

                  // 预置心声: 整行可点, 比小圆片更好读
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: PokoSpacing.lg),
                    child: Column(
                      children: [
                        for (final p in _presetPhrases)
                          Padding(
                            padding: const EdgeInsets.only(bottom: PokoSpacing.sm),
                            child: _presetRow(ctx, p.emoji, p.text, isNight),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: PokoSpacing.xs),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: t.border,
                  ),
                  const SizedBox(height: PokoSpacing.xs),

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
                  const SizedBox(height: PokoSpacing.sm),
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
    final t = ctx.poko(isNight);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(PokoRadius.md),
        onTap: () {
          Navigator.pop(ctx);
          _sendMessage(text);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: PokoSpacing.md, vertical: PokoSpacing.md),
          decoration: BoxDecoration(
            color: t.accentSoft,
            borderRadius: BorderRadius.circular(PokoRadius.md),
            border: Border.all(
              color: t.border,
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: PokoSpacing.md),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: PokoFont.body,
                    height: 1.3,
                    color: t.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: PokoSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: t.accent,
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
    final t = ctx.poko(isNight);
    return InkWell(
      borderRadius: BorderRadius.circular(PokoRadius.sm),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PokoSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: t.accent),
            const SizedBox(width: PokoSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: PokoFont.small,
                fontWeight: FontWeight.w600,
                color: t.accent,
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
    final modelController = TextEditingController(text: _ai.customModel);
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
            final t = context.poko(isNight);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PokoRadius.xl)),
              backgroundColor: t.surface,
              titlePadding: const EdgeInsets.fromLTRB(
                PokoSpacing.xl,
                PokoSpacing.xl,
                PokoSpacing.xl,
                PokoSpacing.sm,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: PokoSpacing.xl, vertical: PokoSpacing.sm),
              title: Row(
                children: [
                  const Text('⚙️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: PokoSpacing.sm),
                  Text(
                    'AI 大模型与语音配置',
                    style: TextStyle(
                      fontSize: PokoFont.title,
                      fontWeight: FontWeight.bold,
                      color: t.textPrimary,
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
                        fontSize: PokoFont.small,
                        color: t.textMuted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: PokoSpacing.md),

                    // 服务商选择
                    Text(
                      '模型服务商：',
                      style: TextStyle(
                        fontSize: PokoFont.small,
                        fontWeight: FontWeight.bold,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: PokoSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (selectedProvider != 'minimax') {
                                  modelController.clear();
                                }
                                selectedProvider = 'minimax';
                                testResult = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: PokoSpacing.sm),
                              decoration: BoxDecoration(
                                color: selectedProvider == 'minimax'
                                    ? PokoPalette.indigo
                                    : t.surfaceAlt,
                                borderRadius: BorderRadius.circular(PokoRadius.xs),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'MiniMax\n(海螺·小奶音)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: PokoFont.caption,
                                  fontWeight: FontWeight.bold,
                                  color: selectedProvider == 'minimax'
                                      ? Colors.white
                                      : t.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: PokoSpacing.sm),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (selectedProvider != 'deepseek') {
                                  modelController.clear();
                                }
                                selectedProvider = 'deepseek';
                                testResult = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: PokoSpacing.sm),
                              decoration: BoxDecoration(
                                color: selectedProvider == 'deepseek'
                                    ? PokoPalette.skyGlow
                                    : t.surfaceAlt,
                                borderRadius: BorderRadius.circular(PokoRadius.xs),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'DeepSeek\n(超高智商)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: PokoFont.caption,
                                  fontWeight: FontWeight.bold,
                                  color: selectedProvider == 'deepseek'
                                      ? Colors.white
                                      : t.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: PokoSpacing.sm),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (selectedProvider != 'openai') {
                                  modelController.clear();
                                }
                                selectedProvider = 'openai';
                                testResult = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: PokoSpacing.sm),
                              decoration: BoxDecoration(
                                color: selectedProvider == 'openai'
                                    ? PokoPalette.emerald
                                    : t.surfaceAlt,
                                borderRadius: BorderRadius.circular(PokoRadius.xs),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'OpenAI\n(通用兼容)',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: PokoFont.caption,
                                  fontWeight: FontWeight.bold,
                                  color: selectedProvider == 'openai'
                                      ? Colors.white
                                      : t.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PokoSpacing.md),

                    // API Key 输入框
                    TextField(
                      controller: keyController,
                      obscureText: false,
                      style: TextStyle(color: t.textPrimary, fontSize: PokoFont.body),
                      decoration: InputDecoration(
                        labelText: selectedProvider == 'minimax'
                            ? 'MiniMax API Key'
                            : (selectedProvider == 'deepseek' ? 'DeepSeek API Key' : 'OpenAI API Key'),
                        hintText: selectedProvider == 'minimax'
                            ? 'sk-cp--... 或 ey...'
                            : (selectedProvider == 'deepseek' ? 'sk-... (platform.deepseek.com)' : 'sk-...'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(PokoRadius.sm)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: PokoSpacing.md, vertical: PokoSpacing.sm),
                      ),
                    ),

                    if (selectedProvider == 'openai') ...[
                      const SizedBox(height: PokoSpacing.sm),
                      TextField(
                        controller: customUrlController,
                        style: TextStyle(color: t.textPrimary, fontSize: PokoFont.small),
                        decoration: InputDecoration(
                          labelText: '自定义接口地址 (可选)',
                          hintText: '默认 https://api.openai.com/v1/chat/completions',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(PokoRadius.sm)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: PokoSpacing.md, vertical: PokoSpacing.sm),
                        ),
                      ),
                    ],

                    const SizedBox(height: PokoSpacing.sm),

                    // 模型代号 (可选): MiniMax 下线旧模型时, 用户可在此自行切换, 无需换包
                    TextField(
                      controller: modelController,
                      style: TextStyle(color: t.textPrimary, fontSize: PokoFont.small),
                      decoration: InputDecoration(
                        labelText: '模型代号 (可选)',
                        hintText: selectedProvider == 'minimax'
                            ? '留空使用内置 ${AiConfig.defaultChatModel}'
                            : (selectedProvider == 'deepseek'
                                ? '留空使用内置 deepseek-chat'
                                : '留空使用内置 gpt-4o-mini'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(PokoRadius.sm)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: PokoSpacing.md, vertical: PokoSpacing.sm),
                      ),
                    ),

                    const SizedBox(height: PokoSpacing.md),

                    // 测试连接与试听语音按钮
                    Wrap(
                      spacing: PokoSpacing.sm,
                      runSpacing: PokoSpacing.sm,
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
                                    customModel: modelController.text,
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: PokoSpacing.sm, vertical: PokoSpacing.xs),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(PokoRadius.xs)),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: PokoSpacing.sm, vertical: PokoSpacing.xs),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(PokoRadius.xs)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PokoSpacing.xs),
                    Text(
                      selectedProvider == 'minimax'
                          ? '💡 MiniMax 原生支持大模型深度思考与高保真萌宠小奶音朗读'
                          : '💡 对话走 $selectedProvider，语音自动共享 MiniMax 小奶音',
                      style: TextStyle(
                        fontSize: PokoFont.caption,
                        color: t.accent,
                      ),
                    ),

                    if (testResult != null) ...[
                      const SizedBox(height: PokoSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(PokoSpacing.sm),
                        decoration: BoxDecoration(
                          color: (testSuccess == true)
                              ? PokoPalette.emerald.withValues(alpha: 0.15)
                              : PokoPalette.rose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(PokoRadius.sm),
                          border: Border.all(
                            color: (testSuccess == true) ? PokoPalette.emerald : PokoPalette.rose,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          testResult!,
                          style: TextStyle(
                            fontSize: PokoFont.caption,
                            color: t.textPrimary,
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
                      customModel: modelController.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    setState(() {});
                    HapticService.light();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PokoPalette.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PokoRadius.sm)),
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
        ? PokoPalette.rose
        : (_ai.hasApiKey ? PokoPalette.emerald : PokoPalette.amber);
    final label = hasError
        ? '云端连接异常'
        : (_ai.hasApiKey ? '就绪' : '智能陪伴模式');
    return GestureDetector(
      onTap: _openSettingsDialog,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          PokoSpacing.sm,
          PokoSpacing.xxs,
          PokoSpacing.sm,
          PokoSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(PokoRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: PokoSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: PokoFont.tiny,
                height: 1.1,
                color: color,
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
    final t = context.poko(isNight);
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
            color: t.surfaceAlt,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: t.textSecondary,
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
        const SizedBox(width: PokoSpacing.sm),
        Expanded(
          child: Listener(
            // ★ 用 Listener 直接接管原始指针事件, 绕开手势竞技场。
            //   之前 onTap + onLongPressStart 并存时, 手指抬起不足 500ms 的话
            //   长按识别器会被 reject, onLongPressEnd 不触发, 只剩 onTap 在松手
            //   那一刻才去启动录音 —— 表现为"松手了还在录、也没发出去"。
            //   现在按下即录、松手必定停止并发送, 没有中间状态。
            onPointerDown: (_) => _onMicPointerDown(),
            onPointerUp: (_) => _onMicPointerUp(),
            onPointerCancel: (_) => _onMicPointerUp(cancelled: true),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isRecording
                      ? const [PokoPalette.rose, PokoPalette.roseDeep]
                      : const [PokoPalette.violet, PokoPalette.indigo],
                ),
                borderRadius: BorderRadius.circular(PokoRadius.pill),
                boxShadow: PokoShadow.card(
                  _isRecording ? PokoPalette.rose : PokoPalette.indigo,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isRecording ? '🛑' : '🎙️', style: const TextStyle(fontSize: 19)),
                  const SizedBox(width: PokoSpacing.sm),
                  Flexible(
                    child: Text(
                      _isRecording ? '松手就发送给波可~' : '按住说话，松手发送',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: PokoFont.bodyLg,
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
        const SizedBox(width: PokoSpacing.sm),
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
    final t = context.poko(isNight);
    return Row(
      children: [
        _softCircleButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: '快捷心声',
          isNight: isNight,
          onTap: _showVoiceSpeechSheet,
        ),
        const SizedBox(width: PokoSpacing.sm),
        Expanded(
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: PokoSpacing.md),
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(PokoRadius.pill),
              border: Border.all(
                color: t.border,
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
                    color: t.accent,
                  ),
                ),
                const SizedBox(width: PokoSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _sendMessage,
                    style: TextStyle(
                      fontSize: PokoFont.body,
                      color: t.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '对波可说点什么吧...',
                      hintStyle: TextStyle(
                        fontSize: PokoFont.small,
                        color: t.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: PokoSpacing.xs),
                // 发送
                GestureDetector(
                  onTap: () => _sendMessage(_textController.text),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: PokoPalette.indigo,
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
    final t = context.poko(isNight);
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
            color: t.surfaceAlt,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: t.accent,
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isNight = widget.isNight;
    final t = context.poko(isNight);
    final history = _ai.chatHistory;

    return PokoSheetShell(
      isNight: isNight,
      heightFactor: 0.72,
      bottomInset: bottomInset,
      child: Column(
        children: [
          // 1. 顶部: 紧凑标题栏 (拖拽手柄由 PokoSheetShell 统一提供)
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: t.border,
                  width: 1.0,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                PokoSpacing.lg,
                PokoSpacing.sm,
                PokoSpacing.md,
                PokoSpacing.md,
              ),
              child: Row(
                children: [
                  // 呼吸光环小头像
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [PokoPalette.violet, PokoPalette.indigo],
                      ),
                      boxShadow: PokoShadow.soft(PokoPalette.violet),
                    ),
                    child: const Center(child: Text('🐱', style: TextStyle(fontSize: 19))),
                  ),
                  const SizedBox(width: PokoSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '波可的小电台',
                          style: TextStyle(
                            fontSize: PokoFont.bodyLg,
                            fontWeight: FontWeight.bold,
                            color: t.textPrimary,
                          ),
                        ),
                        const SizedBox(height: PokoSpacing.xs),
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
                  const SizedBox(width: PokoSpacing.xs),
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
          ),

          // 2. 聊天对话气泡记录滚动区
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🐾', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: PokoSpacing.sm),
                        Text(
                          '对波可说句话吧~ 可以聊心事、也可以喊开饭或玩耍哦！',
                          style: TextStyle(
                            fontSize: PokoFont.body,
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: PokoSpacing.lg, vertical: PokoSpacing.md),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final msg = history[index];
                      final isUser = msg.role == 'user';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: PokoSpacing.xs),
                        child: Row(
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: t.accentSoft,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(child: Text('🐱', style: TextStyle(fontSize: 16))),
                              ),
                              const SizedBox(width: PokoSpacing.sm),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: PokoSpacing.md, vertical: PokoSpacing.sm),
                                decoration: BoxDecoration(
                                  color: isUser ? PokoPalette.indigo : t.surface,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(PokoRadius.md),
                                    topRight: const Radius.circular(PokoRadius.md),
                                    bottomLeft: Radius.circular(isUser ? PokoRadius.md : PokoRadius.xs),
                                    bottomRight: Radius.circular(isUser ? PokoRadius.xs : PokoRadius.md),
                                  ),
                                  border: Border.all(
                                    color: isUser ? PokoPalette.indigoDeep : t.border,
                                  ),
                                  boxShadow: PokoShadow.soft(t.shadow),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg.content,
                                      style: TextStyle(
                                        fontSize: PokoFont.body,
                                        height: 1.4,
                                        color: isUser ? Colors.white : t.textPrimary,
                                      ),
                                    ),
                                    if (!isUser) ...[
                                      const SizedBox(height: PokoSpacing.xs),
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
                                                color: t.accentSoft,
                                                shape: BoxShape.circle,
                                              ),
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.volume_up_rounded,
                                                size: 14,
                                                color: t.accent,
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
                            if (isUser) const SizedBox(width: PokoSpacing.xs),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // 3. AI 思考中 / 语音识别中 / 录音声波动画指示条
          if (_isBusy || _isRecording)
            Container(
              padding: const EdgeInsets.symmetric(vertical: PokoSpacing.xs),
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
                            margin: const EdgeInsets.symmetric(horizontal: PokoSpacing.xxs),
                            width: 3.5,
                            height: height.clamp(4.0, 24.0),
                            decoration: BoxDecoration(
                              color: _isRecording ? PokoPalette.rose : PokoPalette.violet,
                              borderRadius: BorderRadius.circular(PokoRadius.xs),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                  const SizedBox(width: PokoSpacing.sm),
                  Flexible(
                    child: Text(
                      _isRecording
                          ? '正在倾听主人的声音... 松手就发送给波可~ 🎙️'
                          : _isTranscribing
                              ? '正在识别主人的声音... 请稍等喵~ 🐾'
                              : '波可正在用猫猫脑瓜认真思考并生成回复... ✨',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: PokoFont.caption,
                        fontWeight: FontWeight.w600,
                        color: _isRecording ? PokoPalette.rose : t.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 4. 底部输入区: 💭 心声 | 主输入 | 键盘/发送
          Container(
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(
                top: BorderSide(
                  color: t.border,
                  width: 1.0,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              PokoSpacing.md,
              PokoSpacing.sm,
              PokoSpacing.md,
              PokoSpacing.md,
            ),
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
