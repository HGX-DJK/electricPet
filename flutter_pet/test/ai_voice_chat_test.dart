import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pet/services/minimax_service.dart';
import 'package:flutter_pet/config/ai_config.dart';
import 'package:flutter_pet/views/dialogs/ai_voice_chat_dialog.dart';
import 'package:record/record.dart';
import 'package:record_platform_interface/record_platform_interface.dart';

/// 录音平台桩: 替换 RecordPlatform.instance, 让真实的 AudioRecorder 在无麦克风环境下可测。
class _FakeRecordPlatform extends RecordPlatform {
  /// 权限申请耗时 (用于复现"长按松手时录音尚未建立"的竞态)
  Duration permissionDelay = Duration.zero;

  /// stop() 返回的音频文件路径
  String? audioPath;

  int startCount = 0;
  int stopCount = 0;
  bool recording = false;

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<void> start(String recorderId, RecordConfig config, {required String path}) async {
    startCount++;
    recording = true;
  }

  @override
  Future<String?> stop(String recorderId) async {
    stopCount++;
    recording = false;
    return audioPath;
  }

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) async {
    if (permissionDelay > Duration.zero) {
      await Future<void>.delayed(permissionDelay);
    }
    return true;
  }

  @override
  Future<void> dispose(String recorderId) async {
    recording = false;
  }

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<bool> isRecording(String recorderId) async => recording;

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<Stream<Uint8List>> startStream(String recorderId, RecordConfig config) async =>
      const Stream<Uint8List>.empty();

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: 0, max: 0);

  @override
  Future<bool> isEncoderSupported(String recorderId, AudioEncoder encoder) async => true;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async => const [];

  @override
  Future<void> cancel(String recorderId) async {
    recording = false;
  }

  @override
  Stream<RecordState> onStateChanged(String recorderId) => const Stream<RecordState>.empty();

  @override
  void setOnConfigChanged(String recorderId, void Function(RecordConfig config)? handler) {}
}

/// AI 服务桩: 记录送入大模型的文本, 并模拟 MiniMax ASR 的返回。
class _FakeAiService extends MinimaxService {
  _FakeAiService() : super.forTesting();

  /// 桩: ASR 识别结果
  String? transcribed;

  /// 桩: ASR 失败原因
  String? asrError;

  /// 实际送入大模型的文本 (回归断言的核心)
  final List<String> sentTexts = <String>[];

  final List<ChatMessage> _history = <ChatMessage>[];

  @override
  List<ChatMessage> get chatHistory => List<ChatMessage>.unmodifiable(_history);

  @override
  String? get lastAsrError => asrError;

  @override
  Future<String?> transcribeAudio(File audioFile) async {
    if (transcribed == null) {
      return null;
    }
    return transcribed;
  }

  @override
  Future<MinimaxResponse> chatWithPoko(
    String userText, {
    void Function(Uint8List? audio)? onAudioReady,
  }) async {
    sentTexts.add(userText);
    _history.add(ChatMessage(role: 'user', content: userText));
    _history.add(ChatMessage(role: 'assistant', content: '喵呜~ 收到啦，波可记住啦！'));
    onAudioReady?.call(null);
    return const MinimaxResponse(text: '喵呜~ 收到啦，波可记住啦！', action: 'FEED');
  }

  @override
  Future<void> playVoiceResponse(Uint8List? audioBytes) async {}

  @override
  Future<void> stopVoice() async {}
}

/// 推进测试时钟并清空微任务队列 (声波动画是无限循环, 不能用 pumpAndSettle)
Future<void> _flush(WidgetTester tester, [int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeRecordPlatform fakePlatform;
  late File fakeAudio;

  setUp(() async {
    fakePlatform = _FakeRecordPlatform();
    RecordPlatform.instance = fakePlatform;

    fakeAudio = File(
        '${Directory.systemTemp.path}/poko_test_voice_${DateTime.now().microsecondsSinceEpoch}.m4a');
    await fakeAudio.writeAsBytes(List<int>.filled(1024, 7));
    fakePlatform.audioPath = fakeAudio.path;
  });

  tearDown(() async {
    if (fakeAudio.existsSync()) {
      try {
        fakeAudio.deleteSync();
      } catch (_) {}
    }
  });

  group('AI 语音链路回归测试', () {
    testWidgets('P0-1: 按住说话 → 松手 → 识别文本必须真正送达大模型',
        (WidgetTester tester) async {
      final ai = _FakeAiService()..transcribed = '波可今天想吃小鱼干';
      String? triggeredAction;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AiVoiceChatDialog(
            isNight: false,
            aiService: ai,
            onActionTriggered: (action, dialogue) => triggeredAction = action,
          ),
        ),
      ));
      await _flush(tester, 4);

      // 按住麦克风开始录音
      final mic = find.text('按住说话，松手发送');
      final gesture = await tester.startGesture(tester.getCenter(mic));
      await _flush(tester);
      expect(fakePlatform.startCount, 1, reason: '按下即应开始录音');
      expect(find.text('松手就发送给波可~'), findsOneWidget);

      // 松手 → 停止录音并转写发送
      await gesture.up();
      await _flush(tester);

      expect(fakePlatform.stopCount, 1, reason: '松手后录音应被停止');
      expect(
        ai.sentTexts,
        contains('波可今天想吃小鱼干'),
        reason: '★ 语音识别结果必须送达大模型 (旧版被 busy 守卫静默丢弃)',
      );
      // 用户气泡必须出现 (旧版症状: "语音识别没有出现语音接收识别")
      expect(find.text('波可今天想吃小鱼干'), findsOneWidget);
      expect(triggeredAction, 'FEED', reason: '动作联动应照常触发');
    });

    testWidgets('P0-3: 轻触误按(<400ms)不应发送, 而应提示正确用法',
        (WidgetTester tester) async {
      final ai = _FakeAiService()..transcribed = '波可今天想吃小鱼干';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AiVoiceChatDialog(
            isNight: false,
            aiService: ai,
            onActionTriggered: (action, dialogue) {},
          ),
        ),
      ));
      await _flush(tester, 4);

      // 极短的轻触: 旧实现会因为长按被 reject 而"松手后仍在录音且不发送"
      final mic = find.text('按住说话，松手发送');
      final gesture = await tester.startGesture(tester.getCenter(mic));
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.up();
      await _flush(tester);

      expect(fakePlatform.stopCount, 1, reason: '★ 轻触也必须把录音停下来, 不能一直开着');
      expect(ai.sentTexts, isEmpty, reason: '轻触误按不应该发送');
      expect(
        find.textContaining('按住麦克风说话'),
        findsOneWidget,
        reason: '★ 应提示正确的用法, 让用户知道要按住',
      );
      // 面板回到可继续对话的状态
      expect(find.text('按住说话，松手发送'), findsOneWidget);
    });

    testWidgets('P0-2: 按住到松手, 录音必须被真正停止并送达', (WidgetTester tester) async {
      // 权限申请耗时 300ms: 复现"松手时录音尚未建立"的竞态
      fakePlatform.permissionDelay = const Duration(milliseconds: 300);
      final ai = _FakeAiService()..transcribed = '波可陪我玩毛线球';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AiVoiceChatDialog(
            isNight: false,
            aiService: ai,
            onActionTriggered: (action, dialogue) {},
          ),
        ),
      ));
      await _flush(tester, 4);

      final mic = find.text('按住说话，松手发送');
      final gesture = await tester.startGesture(tester.getCenter(mic));
      await tester.pump(const Duration(milliseconds: 520)); // 按住
      await gesture.up(); // 松手 (此时录音可能尚未真正建立)
      await _flush(tester, 20);

      expect(fakePlatform.startCount, 1, reason: '按住应启动录音');
      expect(
        fakePlatform.stopCount,
        greaterThanOrEqualTo(1),
        reason: '★ 松手后录音必须被停止 (旧版因竞态直接 return, 麦克风一直开着)',
      );
      expect(
        ai.sentTexts,
        contains('波可陪我玩毛线球'),
        reason: '★ 对讲的识别结果同样必须送达大模型',
      );
    });

    testWidgets('语音识别失败时, 应透出具体原因而非笼统的"没听清"', (WidgetTester tester) async {
      final ai = _FakeAiService()
        ..transcribed = null
        ..asrError = '语音识别服务返回 HTTP 401';

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AiVoiceChatDialog(
            isNight: false,
            aiService: ai,
            onActionTriggered: (action, dialogue) {},
          ),
        ),
      ));
      await _flush(tester, 4);

      final mic = find.text('按住说话，松手发送');
      final gesture = await tester.startGesture(tester.getCenter(mic));
      await _flush(tester);
      await gesture.up();
      await _flush(tester);

      expect(ai.sentTexts, isEmpty, reason: '识别失败时不应发送任何文本');
      expect(
        find.textContaining('HTTP 401'),
        findsOneWidget,
        reason: '★ 应向用户透出真实的失败原因',
      );
    });

    testWidgets('快捷心声面板: 预置短语可正常送达大模型', (WidgetTester tester) async {
      final ai = _FakeAiService();
      String? triggeredAction;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AiVoiceChatDialog(
            isNight: false,
            aiService: ai,
            onActionTriggered: (action, dialogue) => triggeredAction = action,
          ),
        ),
      ));
      await _flush(tester, 4);

      // 主面板不再堆一排快捷按钮, 预置短语收在「快捷心声」面板里
      expect(find.text('🐟 投喂小鱼干'), findsNothing);
      await tester.tap(find.byTooltip('快捷心声'));
      await _flush(tester, 4);

      expect(find.text('想和波可说点什么？'), findsOneWidget);
      await tester.tap(find.text('波可，给你准备了香酥小鱼干，快来吃呀！'));
      await _flush(tester);

      expect(ai.sentTexts, contains('波可，给你准备了香酥小鱼干，快来吃呀！'));
      expect(triggeredAction, 'FEED');
    });
  });

  group('大模型回复清洗与兜底', () {
    test('去掉动作标签后保留正文', () {
      final ai = _FakeAiService();
      final text =
          ai.cleanReplyText('呼噜呼噜~ 波可来给主人踩背啦！[ACTION:PET]', '摸摸头');
      expect(text, '呼噜呼噜~ 波可来给主人踩背啦！');
      expect(text.contains('[ACTION'), isFalse);
    });

    test('模型只回动作标签时不能产生空气泡', () {
      final ai = _FakeAiService();
      final text = ai.cleanReplyText('[ACTION:PET]', '好的');
      expect(text.trim(), isNotEmpty);
      expect(text.contains('[ACTION'), isFalse);
    });

    test('模型回空内容时不能产生空气泡', () {
      final ai = _FakeAiService();
      expect(ai.cleanReplyText('', '好的').trim(), isNotEmpty);
      expect(ai.cleanReplyText('   ', '好的').trim(), isNotEmpty);
    });

    test('内置对话模型不是已下线的旧型号 (下线后接口只回 base_resp 错误)', () {
      expect(AiConfig.defaultChatModel.trim(), isNotEmpty);
      expect(AiConfig.defaultChatModel, isNot('abab6.5s-chat'));
      expect(AiConfig.defaultChatModel, isNot('abab5.5s-chat'));
      expect(AiConfig.defaultChatModel, isNot('MiniMax-M2'));
    });
  });
}
