import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sound_service.dart';

/// MiniMax AI 交互响应数据包
class MinimaxResponse {
  final String text;           // 显示与朗读纯文本 (已清洗指令标签)
  final String? action;        // 解析提取的游戏联动指令 (FEED, SLEEP, SPIN, YARN, PET, BATH)
  final Uint8List? audioBytes; // MiniMax T2A 合成的语音字节 (MP3)
  final bool isSimulated;      // 是否为本地拟真智能模式 (无 Key 降级)

  const MinimaxResponse({
    required this.text,
    this.action,
    this.audioBytes,
    this.isSimulated = false,
  });
}

/// 历史对话记录条目
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// MiniMax AI 驱动的波可语音与情感陪伴大脑
class MinimaxService {
  static const String prefApiKey = 'poko_minimax_api_key';
  static const String prefVoiceId = 'poko_minimax_voice_id';
  static const String prefPitch = 'poko_minimax_pitch';
  static const String prefSpeed = 'poko_minimax_speed';

  static final MinimaxService instance = MinimaxService._internal();
  factory MinimaxService() => instance;
  MinimaxService._internal();

  String _apiKey = '';
  String _voiceId = 'female-tianmei'; // 甜美女性音 / 萌系奶音
  int _pitch = 2;                     // 略微升调呈现幼态甜萌音 (范围 -12 ~ 12)
  double _speed = 1.05;               // 稍快的轻快语速
  bool _isInitialized = false;

  final List<ChatMessage> _chatHistory = [];
  AudioPlayer? _voicePlayer;

  String get apiKey => _apiKey;
  String get voiceId => _voiceId;
  int get pitch => _pitch;
  double get speed => _speed;
  bool get hasApiKey => _apiKey.trim().isNotEmpty;
  List<ChatMessage> get chatHistory => List.unmodifiable(_chatHistory);

  AudioPlayer get voicePlayer {
    _voicePlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    return _voicePlayer!;
  }

  /// 初始化并载入持久化配置
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString(prefApiKey) ?? '';
      _voiceId = prefs.getString(prefVoiceId) ?? 'female-tianmei';
      _pitch = prefs.getInt(prefPitch) ?? 2;
      _speed = prefs.getDouble(prefSpeed) ?? 1.05;
      _isInitialized = true;
    } catch (_) {
      _isInitialized = true;
    }
  }

  /// 保存配置
  Future<void> updateConfig({
    String? apiKey,
    String? voiceId,
    int? pitch,
    double? speed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey != null) {
      _apiKey = apiKey.trim();
      await prefs.setString(prefApiKey, _apiKey);
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
  }

  /// 清空对话历史
  void clearHistory() {
    _chatHistory.clear();
  }

  /// 核心对话交互：输入用户语音/文本，流经 MiniMax 大模型并自动调用 T2A 语音合成
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

    // 若未配置 API Key 或请求失败，无缝回退至本地智能情感引擎，保障 100% 顺畅交互
    if (!hasApiKey) {
      return _generateLocalCompanionResponse(trimmedText);
    }

    try {
      // 1. 请求 MiniMax Chat Completion 大模型
      final llmResult = await _callMiniMaxLLM(trimmedText);
      final rawReply = llmResult['reply'] ?? '';
      final action = llmResult['action'];

      // 清洗标签后的纯文本
      final cleanText = _cleanActionTags(rawReply);
      _chatHistory.add(ChatMessage(role: 'assistant', content: cleanText));

      // 2. 请求 MiniMax T2A 语音合成
      Uint8List? audioBytes;
      try {
        audioBytes = await synthesizeVoice(cleanText);
      } catch (e) {
        // T2A 异常时不阻断对话，仅降级为音效
      }

      return MinimaxResponse(
        text: cleanText,
        action: action,
        audioBytes: audioBytes,
        isSimulated: false,
      );
    } catch (e) {
      // 网络或调用异常时优雅降级
      return _generateLocalCompanionResponse(trimmedText);
    }
  }

  /// 调用 MiniMax Chat Completion API (abab6.5s-chat / MiniMax-Text-01)
  Future<Map<String, dynamic>> _callMiniMaxLLM(String message) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final uri = Uri.parse('https://api.minimax.chat/v1/text/chatcompletion_v2');
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set('Content-Type', 'application/json');

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
   - [ACTION:SPIN] : 开心庆祝、跳舞、旋转、转圈圈
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
        'model': 'abab6.5s-chat',
        'messages': messages,
        'temperature': 0.75,
        'max_tokens': 120,
      });

      request.write(payload);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('MiniMax Chat API error: ${response.statusCode}');
      }

      final jsonMap = jsonDecode(body) as Map<String, dynamic>;
      final choices = jsonMap['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) {
        throw Exception('No choices in MiniMax response');
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

  /// 调用 MiniMax T2A 语音合成 API (`speech-01-turbo`)
  Future<Uint8List?> synthesizeVoice(String textToSpeak) async {
    if (!hasApiKey || textToSpeak.trim().isEmpty) return null;

    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final uri = Uri.parse('https://api.minimax.chat/v1/t2a_v2');
      final request = await client.postUrl(uri);
      request.headers.set('Authorization', 'Bearer $_apiKey');
      request.headers.set('Content-Type', 'application/json');

      final payload = jsonEncode({
        'model': 'speech-01-turbo',
        'text': textToSpeak,
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

      request.write(payload);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        return null;
      }

      final jsonMap = jsonDecode(body) as Map<String, dynamic>;
      final data = jsonMap['data'] as Map<String, dynamic>?;
      final hexAudio = data?['audio'] as String?;

      if (hexAudio != null && hexAudio.isNotEmpty) {
        return _hexToBytes(hexAudio);
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// 播放合成的语音音频；若无合成数据则播放原生软萌喵音
  Future<void> playVoiceResponse(Uint8List? audioBytes) async {
    if (audioBytes != null && audioBytes.isNotEmpty) {
      try {
        await voicePlayer.stop();
        await voicePlayer.play(BytesSource(audioBytes));
        return;
      } catch (_) {}
    }
    // 回退到温润小猫叫声
    SoundService.playMeow(tone: MeowTone.sweet);
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

  /// 本地智能拟真陪伴引擎 (无 Key / 离线时无感知兜底)
  MinimaxResponse _generateLocalCompanionResponse(String input) {
    final lower = input.toLowerCase();
    String reply;
    String? action;

    if (lower.contains('吃') || lower.contains('饿') || lower.contains('鱼') || lower.contains('罐头') || lower.contains('蛋糕') || lower.contains('饭')) {
      final list = [
        '闻到香喷喷的味道啦！波可的小肚子正咕噜咕噜叫呢，嗷呜一口全吃光光~ 🐟✨',
        '开饭咯！最喜欢香酥小鱼干啦，吧唧吧唧嚼得超满足！谢谢主人投喂~ 罐头也超棒！🥫💕',
        '有小鱼干吃的小猫是世界上最幸福的猫！小胡须开心得直抖动~ 😋🐾',
      ];
      reply = list[math.Random().nextInt(list.length)];
      action = 'FEED';
    } else if (lower.contains('睡') || lower.contains('困') || lower.contains('晚安') || lower.contains('眯')) {
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
    } else if (lower.contains('转') || lower.contains('跳') || lower.contains('舞') || lower.contains('开心') || lower.contains('棒')) {
      final list = [
        '看波可给你表演 360 度赛博快乐大回旋！旋转跳跃，快乐转圈圈~ 🌀✨',
        '嘿嘿！被主人夸奖啦，元气值瞬间暴涨 100%！给主人跳一个开心小碎步~ 🐾💖',
        '转呀转，快乐加倍！有波可陪着的每一刻都要闪闪发光哦！💃✨',
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
        '咪呜？波可歪着小脑袋认真听着呢！只要主人说话，波可的一双小耳朵就竖得直直的~ 🐱✨',
        '喵呜~ 收到主人的神秘信号！波可的心情值蹭蹭上涨，新的一天也要元气满满哦！🐾💖',
        '今天空气甜甜的，阳光也很暖，有主人陪伴在身边的每一天都是大晴天~ ☀️🌸',
      ];
      reply = list[math.Random().nextInt(list.length)];
    }

    _chatHistory.add(ChatMessage(role: 'assistant', content: reply));
    return MinimaxResponse(
      text: reply,
      action: action,
      isSimulated: true,
    );
  }
}
