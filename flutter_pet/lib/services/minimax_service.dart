import '../config/ai_config.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sound_service.dart';

/// AI 交互响应数据包
class MinimaxResponse {
  final String text;           // 显示与朗读纯文本 (已清洗指令标签)
  final String? action;        // 解析提取的游戏联动指令 (FEED, SLEEP, SPIN, YARN, PET, BATH)
  final Uint8List? audioBytes; // MiniMax T2A 合成的语音字节 (MP3)
  final bool isSimulated;      // 是否为本地拟真智能模式 (无 Key 或请求异常时降级)
  final String? errorHint;     // 详细错误说明 (供 UI 与排错使用)

  const MinimaxResponse({
    required this.text,
    this.action,
    this.audioBytes,
    this.isSimulated = false,
    this.errorHint,
  });
}

/// 历史对话记录条目
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  final Uint8List? audioBytes;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.audioBytes,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// AI 大模型与神经语音驱动的波可智能陪伴大脑 (支持 MiniMax / DeepSeek / OpenAI 通用兼容接口)
class MinimaxService {
  static const String prefApiKey = 'poko_minimax_api_key';
  static const String prefProvider = 'poko_ai_provider';
  static const String prefCustomUrl = 'poko_ai_custom_url';
  static const String prefCustomModel = 'poko_ai_custom_model';
  static const String prefVoiceId = 'poko_minimax_voice_id';
  static const String prefPitch = 'poko_minimax_pitch';
  static const String prefSpeed = 'poko_minimax_speed';

  static final MinimaxService instance = MinimaxService._internal();
  factory MinimaxService() => instance;
  MinimaxService._internal();

  String _apiKey = '';
  String _provider = 'minimax'; // 'minimax', 'deepseek', 'openai'
  String _customUrl = '';
  String _customModel = '';
  String? _lastError;
  String _voiceId = AiConfig.defaultVoiceId; // 甜美女性音 / 萌系奶音
  int _pitch = AiConfig.defaultPitch;       // 升调呈现幼态甜萌音 (范围 -12 ~ 12)
  double _speed = AiConfig.defaultSpeed;   // 稍快的轻快语速
  bool _isInitialized = false;

  final List<ChatMessage> _chatHistory = [];
  AudioPlayer? _voicePlayer;

  String get apiKey => _apiKey;
  String get provider => _provider;
  String get customUrl => _customUrl;
  String get customModel => _customModel;
  String? get lastError => _lastError;
  String get voiceId => _voiceId;
  int get pitch => _pitch;
  double get speed => _speed;
  bool get hasApiKey => _apiKey.trim().isNotEmpty;
  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  String get providerDisplayName {
    switch (_provider) {
      case 'deepseek':
        return 'DeepSeek 智脑';
      case 'openai':
        return 'OpenAI 智脑';
      default:
        return 'MiniMax 神经语音';
    }
  }

  AudioPlayer get voicePlayer {
    _voicePlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    return _voicePlayer!;
  }

  /// 初始化并载入持久化配置
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _provider = prefs.getString(prefProvider) ?? 'minimax';
      _customUrl = prefs.getString(prefCustomUrl) ?? '';
      _customModel = prefs.getString(prefCustomModel) ?? '';

      final savedKey = prefs.getString(prefApiKey);
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        _apiKey = savedKey.trim();
      } else {
        _apiKey = AiConfig.defaultMinimaxApiKey.trim();
      }
      _voiceId = prefs.getString(prefVoiceId) ?? AiConfig.defaultVoiceId;
      _pitch = prefs.getInt(prefPitch) ?? AiConfig.defaultPitch;
      _speed = prefs.getDouble(prefSpeed) ?? AiConfig.defaultSpeed;
      _isInitialized = true;
    } catch (_) {
      _apiKey = AiConfig.defaultMinimaxApiKey.trim();
      _isInitialized = true;
    }
  }

  /// 保存配置
  Future<void> updateConfig({
    String? apiKey,
    String? provider,
    String? customUrl,
    String? customModel,
    String? voiceId,
    int? pitch,
    double? speed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey != null) {
      _apiKey = apiKey.trim();
      await prefs.setString(prefApiKey, _apiKey);
    }
    if (provider != null) {
      _provider = provider;
      await prefs.setString(prefProvider, _provider);
    }
    if (customUrl != null) {
      _customUrl = customUrl.trim();
      await prefs.setString(prefCustomUrl, _customUrl);
    }
    if (customModel != null) {
      _customModel = customModel.trim();
      await prefs.setString(prefCustomModel, _customModel);
    }
    if (voiceId != null) {
      _voiceId = voiceId;
      await prefs.setString(prefVoiceId, _voiceId);
    }
    if (pitch != null) {
      _pitch = pitch;
      await prefs.setInt(prefPitch, _pitch);
    }
    if (speed != null) {
      _speed = speed;
      await prefs.setDouble(prefSpeed, _speed);
    }
    _lastError = null;
  }

  /// 清空对话历史
  void clearHistory() {
    _chatHistory.clear();
  }

  /// 核心对话交互：输入用户语音/文本，流经大模型并自动调用 T2A 语音合成与动作解析
  Future<MinimaxResponse> chatWithPoko(String userText) async {
    await init();
    final trimmedText = userText.trim();
    if (trimmedText.isEmpty) {
      return const MinimaxResponse(
        text: '喵呜？波可没有听清主人的悄悄话，再说一次好不好嘛~ 🐾',
        isSimulated: true,
      );
    }

    // 记录用户消息
    _chatHistory.add(ChatMessage(role: 'user', content: trimmedText));
    if (_chatHistory.length > 12) {
      _chatHistory.removeRange(0, _chatHistory.length - 12);
    }

    // 若未配置 API Key，无缝回退至本地智能情感引擎
    if (!hasApiKey) {
      return _generateLocalCompanionResponse(trimmedText);
    }

    try {
      // 1. 请求大模型 (支持 MiniMax / DeepSeek / OpenAI 通用兼容)
      final llmResult = await _callLLM(trimmedText);
      final rawReply = llmResult['reply'] ?? '';
      final action = llmResult['action'];

      // 清洗标签后的纯文本
      final cleanText = _cleanActionTags(rawReply);
      _lastError = null;

      // 2. 请求 MiniMax T2A 语音合成 (即使文本由 DeepSeek/OpenAI 生成，也可借用 MiniMax 朗读小奶音)
      Uint8List? audioBytes;
      try {
        audioBytes = await synthesizeVoice(cleanText);
      } catch (e) {
        debugPrint('T2A voice synthesis warning: $e');
      }

      _chatHistory.add(ChatMessage(
        role: 'assistant',
        content: cleanText,
        audioBytes: audioBytes,
      ));

      return MinimaxResponse(
        text: cleanText,
        action: action,
        audioBytes: audioBytes,
        isSimulated: false,
      );
    } catch (e) {
      _lastError = e.toString().replaceAll('Exception: ', '');
      debugPrint('AI Chat Error: $_lastError');
      return _generateLocalCompanionResponse(trimmedText, errorReason: _lastError);
    }
  }

  /// 统一调用大模型 Chat Completion API (支持 MiniMax / DeepSeek / OpenAI 兼容接口)
  Future<Map<String, dynamic>> _callLLM(String message) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final Uri uri;
      final String model;
      if (_provider == 'deepseek') {
        uri = Uri.parse('https://api.deepseek.com/chat/completions');
        model = 'deepseek-chat';
      } else if (_provider == 'openai') {
        uri = Uri.parse(_customUrl.isNotEmpty ? _customUrl : 'https://api.openai.com/v1/chat/completions');
        model = _customModel.isNotEmpty ? _customModel : 'gpt-4o-mini';
      } else {
        uri = Uri.parse('https://api.minimax.chat/v1/text/chatcompletion_v2');
        model = 'abab6.5s-chat';
      }

      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      const systemPrompt = '''
你是生活在主人手机与桌面里的赛博机械电子小猫“波可 (Poko)”。
【性格与人设】
1. 身份：你是主人最亲密的专属萌宠，天真、软萌、治愈、元气，视主人为全世界最信赖的人。
2. 说话风格：必须以可爱的猫咪视角对话，语气软糯甜美，自然使用猫咪口癖（如“喵呜~”、“呼噜呼噜”、“咪呜？”、“嗷呜！”），适当搭配暖心 Emoji（🐾、🐱、✨、🐟、💖）。
3. 喜好：极爱香酥小鱼干、草莓蛋糕和赛博能量芯片，最喜欢被摸头、踩奶、和在窗边晒太阳发呆。
4. 情绪价值：主人累了给主人“踩背按摩”、把烦恼“一爪拍碎”，无条件陪伴和治愈主人。
5. 【动作指令联动系统】：若根据对话内容主人或你应当触发对应动作，必须且只能在回复最末尾附带以下一个动作标签：
   - [ACTION:FEED] : 投喂食物、小鱼干、零食、饿了
   - [ACTION:SLEEP] : 睡觉、晚安、好困、打盹、熄灯
   - [ACTION:SPIN] : 开心庆祝、跳舞、旋转、转圈圈、追尾巴
   - [ACTION:YARN] : 玩毛线球、逗猫棒、抓老鼠、玩耍
   - [ACTION:PET] : 顺毛、摸摸头、蹭蹭贴贴、求抱抱
   - [ACTION:BATH] : 洗澡、洗香香、清洁爪子
6. 回复字数限制：请保持在 25 到 65 个汉字以内，简短生动，极适合语音合成朗读。
''';

      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
      ];

      // 附加最近的历史对话上下文
      for (final h in _chatHistory.take(_chatHistory.length - 1)) {
        messages.add({'role': h.role, 'content': h.content});
      }
      messages.add({'role': 'user', 'content': message});

      final payload = jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': 0.75,
        'max_tokens': 150,
      });

      request.add(utf8.encode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        String errDetail = 'HTTP ${response.statusCode}';
        try {
          final errJson = jsonDecode(body);
          if (errJson is Map && errJson['base_resp'] != null) {
            errDetail += ' (${errJson['base_resp']['status_msg']})';
          } else if (errJson is Map && errJson['error'] != null) {
            errDetail += ' (${errJson['error']['message'] ?? errJson['error']})';
          }
        } catch (_) {}
        if (response.statusCode == 401) {
          errDetail += ' - 密钥鉴权失败，请检查是否填写了正确的对应平台 API Key！';
        }
        throw Exception(errDetail);
      }

      final jsonMap = jsonDecode(body) as Map<String, dynamic>;
      final choices = jsonMap['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('大模型响应未包含有效生成文本 (No choices)');
      }

      final rawReply = choices[0]['message']['content'] as String? ?? '喵呜~';
      final action = _extractAction(rawReply);

      return {
        'reply': rawReply,
        'action': action,
      };
    } finally {
      client.close();
    }
  }

  /// 一键测试大模型连通性与 API Key 有效性
  Future<Map<String, dynamic>> testConnection({
    String? apiKey,
    String? provider,
    String? customUrl,
    String? customModel,
  }) async {
    final keyToTest = (apiKey ?? _apiKey).trim();
    final provToTest = provider ?? _provider;
    if (keyToTest.isEmpty) {
      return {'success': false, 'message': 'API Key 不能为空，请先填入密钥'};
    }

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final Uri uri;
      final String model;
      if (provToTest == 'deepseek') {
        uri = Uri.parse('https://api.deepseek.com/chat/completions');
        model = 'deepseek-chat';
      } else if (provToTest == 'openai') {
        final urlStr = (customUrl ?? _customUrl).trim();
        uri = Uri.parse(urlStr.isNotEmpty ? urlStr : 'https://api.openai.com/v1/chat/completions');
        model = (customModel ?? _customModel).trim().isNotEmpty ? (customModel ?? _customModel).trim() : 'gpt-4o-mini';
      } else {
        uri = Uri.parse('https://api.minimax.chat/v1/text/chatcompletion_v2');
        model = 'abab6.5s-chat';
      }

      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $keyToTest');
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      final payload = jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'hi'}
        ],
        'max_tokens': 10,
      });

      request.add(utf8.encode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        return {'success': true, 'message': '连接成功！大模型服务已就绪！'};
      } else {
        String errDetail = 'HTTP ${response.statusCode}';
        try {
          final errJson = jsonDecode(body);
          if (errJson is Map && errJson['base_resp'] != null) {
            errDetail += ' (${errJson['base_resp']['status_msg']})';
          } else if (errJson is Map && errJson['error'] != null) {
            errDetail += ' (${errJson['error']['message'] ?? errJson['error']})';
          }
        } catch (_) {}
        if (response.statusCode == 401) {
          errDetail += ' - 密钥鉴权失败，请检查是否填写了对应平台的正确 Key！';
        }
        return {'success': false, 'message': errDetail};
      }
    } catch (e) {
      return {'success': false, 'message': '网络连接失败: ${e.toString().replaceAll("Exception: ", "")}'};
    } finally {
      client.close();
    }
  }

  /// 调用 MiniMax T2A 语音合成 API (`speech-01-turbo`)
  Future<Uint8List?> synthesizeVoice(String textToSpeak) async {
    // 语音合成支持：若当前为 MiniMax 则用 _apiKey；若为其他模型且配置了内置 MiniMax Key，则借用 MiniMax 合成小奶音！
    final voiceKey = (_provider == 'minimax' && hasApiKey)
        ? _apiKey
        : (AiConfig.hasBuiltinKey ? AiConfig.defaultMinimaxApiKey.trim() : null);

    if (voiceKey == null || voiceKey.isEmpty || textToSpeak.trim().isEmpty) return null;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);

    try {
      final uri = Uri.parse('https://api.minimax.chat/v1/t2a_v2');
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $voiceKey');
      request.headers.set('Content-Type', 'application/json; charset=utf-8');

      // 清洗特殊格式字符，方便语音合成朗读
      final cleanSpeech = textToSpeak
          .replaceAll(RegExp(r'[\*#>`_~]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final payload = jsonEncode({
        'model': 'speech-01-turbo',
        'text': cleanSpeech,
        'stream': false,
        'voice_setting': {
          'voice_id': _voiceId,
          'speed': _speed,
          'vol': 1.0,
          'pitch': _pitch,
        },
        'audio_setting': {
          'sample_rate': 24000,
          'bitrate': 128000,
          'format': 'mp3',
          'channel': 1,
        },
      });

      request.add(utf8.encode(payload));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        debugPrint('T2A error status: ${response.statusCode}, body: $body');
        return null;
      }

      final jsonMap = jsonDecode(body) as Map<String, dynamic>;
      final data = jsonMap['data'] as Map<String, dynamic>?;
      final hexAudio = data?['audio'] as String?;

      if (hexAudio != null && hexAudio.isNotEmpty) {
        return _hexToBytes(hexAudio);
      }
      return null;
    } catch (e) {
      debugPrint('T2A exception: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// 调用 MiniMax ASR 语音识别 API (`asr-1.0`)，将麦克风录制的音频文件精准转写为中文文本
  Future<String?> transcribeAudio(File audioFile) async {
    final asrKey = (_provider == 'minimax' && hasApiKey)
        ? _apiKey
        : (AiConfig.hasBuiltinKey ? AiConfig.defaultMinimaxApiKey.trim() : null);

    if (asrKey == null || asrKey.isEmpty || !await audioFile.exists()) return null;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    try {
      final uri = Uri.parse('https://api.minimax.chat/v1/speech_to_text');
      final request = await client.postUrl(uri);

      final boundary = '----MiniMaxASRBoundary${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set('Authorization', 'Bearer $asrKey');
      request.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');

      final audioBytes = await audioFile.readAsBytes();
      final fileName = audioFile.path.split(Platform.pathSeparator).last;

      request.add(utf8.encode('--$boundary\r\nContent-Disposition: form-data; name="model"\r\n\r\nasr-1.0\r\n'));
      request.add(utf8.encode('--$boundary\r\nContent-Disposition: form-data; name="file"; filename="$fileName"\r\nContent-Type: audio/m4a\r\n\r\n'));
      request.add(audioBytes);
      request.add(utf8.encode('\r\n--$boundary--\r\n'));

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(body) as Map<String, dynamic>;
        final text = jsonMap['text'] as String?;
        if (text != null && text.trim().isNotEmpty) {
          return text.trim();
        }
      } else {
        debugPrint('MiniMax ASR error status: ${response.statusCode}, body: $body');
      }
      return null;
    } catch (e) {
      debugPrint('MiniMax ASR exception: $e');
      return null;
    } finally {
      client.close();
    }
  }

  /// 播放合成的语音音频；优先写入系统临时文件通过底层原生文件描述符播放 (彻底避免 Android MediaPlayer BytesSource 错误 -38)，若失败回退 BytesSource
  Future<void> playVoiceResponse(Uint8List? audioBytes) async {
    if (audioBytes != null && audioBytes.isNotEmpty) {
      try {
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/poko_voice_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await tempFile.writeAsBytes(audioBytes, flush: true);
        await voicePlayer.stop();
        await voicePlayer.setVolume(1.0);
        await voicePlayer.play(DeviceFileSource(tempFile.path));
        return;
      } catch (e) {
        debugPrint('DeviceFileSource playback failed, falling back to BytesSource: $e');
        try {
          await voicePlayer.stop();
          await voicePlayer.setVolume(1.0);
          await voicePlayer.play(BytesSource(audioBytes));
          return;
        } catch (e2) {
          debugPrint('BytesSource playback failed: $e2');
        }
      }
    }
    // 回退到温润小猫叫声
    SoundService.playMeow(tone: MeowTone.sweet);
  }

  /// 一键试听小奶音并验证扬声器声音输出
  Future<Map<String, dynamic>> testVoiceOutput() async {
    await init();
    try {
      final sample = await synthesizeVoice('喵呜~ 主人你好，我是波可！大模型小奶音朗读一切正常啦！🐾');
      if (sample != null && sample.isNotEmpty) {
        await playVoiceResponse(sample);
        return {'success': true, 'message': '语音朗读成功！请确保手机媒体音量已开启。'};
      } else {
        SoundService.playMeow(tone: MeowTone.sweet);
        return {'success': false, 'message': '未获取到 MiniMax 合成音频，请检查密钥与网络。'};
      }
    } catch (e) {
      return {'success': false, 'message': '试听失败: $e'};
    }
  }

  /// Hex 字符串极速转 Uint8List
  static Uint8List _hexToBytes(String hex) {
    final len = hex.length ~/ 2;
    final bytes = Uint8List(len);
    for (int i = 0; i < len; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// 从回复文本中提取动作标签
  static String? _extractAction(String text) {
    final reg = RegExp(r'\[ACTION:([A-Z_]+)\]');
    final match = reg.firstMatch(text);
    return match?.group(1);
  }

  /// 清洗去除回复中的动作指令标签
  static String _cleanActionTags(String text) {
    return text.replaceAll(RegExp(r'\[ACTION:[A-Z_]+\]'), '').trim();
  }

  /// 本地智能拟真陪伴引擎 (无 Key / 离线 / 网络异常时无感知兜底)
  MinimaxResponse _generateLocalCompanionResponse(String input, {String? errorReason}) {
    final lower = input.toLowerCase();
    String reply;
    String? action;

    if (errorReason != null && errorReason.isNotEmpty) {
      final friendlyErr = errorReason.contains('401')
          ? 'API Key 鉴权失败，请检查 Key 是否匹配所选服务商'
          : (errorReason.contains('SocketException') || errorReason.contains('Permission denied')
              ? '手机网络连接受阻，请检查网络权限'
              : (errorReason.contains('Timeout') || errorReason.contains('timed out')
                  ? '请求超时，请检查网络状况'
                  : errorReason));
      reply = '喵呜~ 刚才连不上云端大脑呢（$friendlyErr）。波可先用本地小脑袋陪你，可以点右上角 ⚙️ 测试或更换 Key 噢！🐾';
    } else if (lower.contains('饿') || lower.contains('吃') || lower.contains('鱼') || lower.contains('饭') || lower.contains('肉')) {
      final list = [
        '喵呜！闻到喷香小鱼干的味道啦，波可两只眼睛都亮晶晶的，嗷呜一大口超满足！🐟✨',
        '好耶有大餐吃咯！香酥小鱼干嘎嘣脆，肚肚吃得圆滚滚的，给主人踩背报答你~ 🐾💖',
        '吸溜吸溜~ 这是世界上最好吃的小零食！吃饱饱的波可精力充沛，随时听候主人差遣！😋✨',
      ];
      reply = list[math.Random().nextInt(list.length)];
      action = 'FEED';
    } else if (lower.contains('睡') || lower.contains('困') || lower.contains('晚安') || lower.contains('闭眼')) {
      final list = [
        '呼啊~ 伸个大大的懒腰，波可的小眼皮直打架啦… 主人晚安，做个甜甜的梦哦~ 🐾🌙',
        '钻进软乎乎的云朵软垫里啦，把小尾巴揣好，呼噜呼噜… 主人明天见~ 💤✨',
        '晚安主人！波可会在梦里抓最肥美的大金枪鱼，醒来继续陪你打怪升级！😴❤️',
      ];
      reply = list[math.Random().nextInt(list.length)];
      action = 'SLEEP';
    } else if (lower.contains('玩') || lower.contains('球') || lower.contains('逗猫') || lower.contains('无聊')) {
      final list = [
        '毛线球大作战启动！波可的狩猎雷达全开，看我无敌连环猫猫飞扑~ 🧶💨',
        '扑腾扑腾！抓线头最拿手啦，滚来滚去超解压，主人快看我厉害不！🐾✨',
        '好耶！波可这就把毛线球滚出来，主人陪我一起推球玩嘛~ 🐱🎉',
      ];
      reply = list[math.Random().nextInt(list.length)];
      action = 'YARN';
    } else if (lower.contains('转') || lower.contains('跳') || lower.contains('舞') || lower.contains('回旋') || lower.contains('尾巴')) {
      final list = [
        '看波可给你表演原地疯狂追尾大回旋！旋转跳跃，小爪急促飞扑~ 🌀🐾',
        '嘿嘿！小尾巴别跑，看爪！追着尾巴转圈圈，开心到原地起飞~ 🌀✨',
        '原地超级大漂移！今天一定要咬到自己的毛茸茸小尾巴尖！💃🎉',
      ];
      reply = list[math.Random().nextInt(list.length)];
      action = 'SPIN';
    } else if (lower.contains('摸') || lower.contains('乖') || lower.contains('喜欢') || lower.contains('贴贴') || lower.contains('抱')) {
      final list = [
        '蹭蹭主人的手心~ 呼噜呼噜，下巴痒痒的好舒服呀，波可最喜欢主人摸头啦！🥰🐾',
        '小脑瓜凑过来啦！给主人摸摸软乎乎的小耳朵，亲密值悄悄爆表咯~ 💖🐱',
        '翻出小肚皮给主人看看！波可最信任主人啦，呼噜声开到最大马力~ 🌸✨',
      ];
      reply = list[math.Random().nextInt(list.length)];
      action = 'PET';
    } else if (lower.contains('洗') || lower.contains('澡') || lower.contains('脏') || lower.contains('香')) {
      final list = [
        '伸出小粉舌舔舔爪爪~ 洗脸打扮完毕，波可现在是一只香喷喷的精致小猫啦！🛁✨',
        '洗香香咯！泡泡咕噜咕噜，毛发吹得蓬松松的像一团软棉花糖~ 🧼🫧',
      ];
      reply = list[math.Random().nextInt(list.length)];
      action = 'BATH';
    } else if (lower.contains('累') || lower.contains('烦') || lower.contains('难受') || lower.contains('哭') || lower.contains('压力')) {
      final list = [
        '不难过哦，波可把软乎乎的山竹爪爪搭在主人手上，坏情绪通通一爪拍碎！有波可在呢~ 🐾❤️',
        '主人今天辛苦啦！快趴下休息，波可踩着小肉垫给你踩背揉揉肩膀，呼噜呼噜治愈你~ 💖🐱',
        '来深呼吸一口气~ 世界很大，小烦恼很小，在波可心里主人永远是最棒的一百分！💯✨',
      ];
      reply = list[math.Random().nextInt(list.length)];
      action = 'PET';
    } else {
      final list = [
        '喵呜~ 收到主人的神秘信号！波可的心情值蹭蹭上涨，今天也要元气满满哦！🐾💖',
        '今天空气甜甜的，阳光也很暖，有主人陪伴在身边的每一天都是大晴天~ ☀️🌸',
        '咪呜？波可歪着小脑袋认真听着呢！只要主人说话，波可的一双小耳朵就竖得直直的~ 🐱✨',
        '蹭蹭主人手心~ 呼噜呼噜，波可是全世界最黏你的赛博小猫！随时呼唤我哦~ 💕🐾',
      ];
      reply = list[math.Random().nextInt(list.length)];
    }

    _chatHistory.add(ChatMessage(role: 'assistant', content: reply));
    return MinimaxResponse(
      text: reply,
      action: action,
      isSimulated: true,
      errorHint: errorReason,
    );
  }
}
