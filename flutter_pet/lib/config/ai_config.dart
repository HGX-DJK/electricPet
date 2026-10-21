/// 全局 AI 智能体与神经语音配置中枢
/// 将 API 密钥与参数内置写入此处，打包后 App 启动即默认激活 MiniMax 云端大模型与小奶音，无需用户手动输入！
class AiConfig {
  /// MiniMax 官方 API 密钥 (API Key)
  /// 获取途径: https://platform.minimaxi.com/ -> 账户管理 -> 接口密钥
  /// 将您的真实 Key（形如 eyJhbGciOi...）填入此处引号中即可内置激活！
  static const String defaultMinimaxApiKey = 'sk-cp--z0tZzUFDt_oWtwHIYIPT_H8cFOOLJHboaE4bGTFIjRnkSbDGhtTTsUXr2brB1XneU18EM5246EtrMCRqxAJNwmqg56JadcCr_vKZchZ6ULPNZZtcokydLM';

  /// MiniMax 默认音色 (MiniMax T2A Voice ID)
  /// 推荐音色选项：
  /// - 'female-tianmei' : 甜美女性音 / 萌系小奶音 (默认推荐)
  /// - 'child_female'   : 可爱软糯萝莉音
  /// - 'cute_boy'       : 呆萌小正太音
  /// - 'sweet_girl'     : 温柔治愈女声
  static const String defaultVoiceId = 'female-tianmei';

  /// 默认音调升降偏移 (-12 到 12，升调 2~3 可展现软糯幼态萌感)
  static const int defaultPitch = 2;

  /// 默认朗读语速 (0.5 到 2.0，1.05 轻快活泼)
  static const double defaultSpeed = 1.05;

  /// MiniMax 对话大语言模型代号
  ///
  /// 注意: MiniMax 已下线 abab6.5s-chat / abab5.5s-chat / MiniMax-M2 等旧模型,
  /// 下线后接口仍返回 HTTP 200, 但 body 里是
  /// `{"choices":null,"base_resp":{"status_code":2069,"status_msg":"... no longer available."}}`,
  /// 所以必须换成当前在线的模型代号, 否则表现为"连不上云端大脑"。
  static const String defaultChatModel = 'MiniMax-Text-01';

  /// MiniMax T2A 神经语音合成模型代号
  static const String defaultT2aModel = 'speech-01-turbo';

  /// 是否包含内置且非空的 API Key
  static bool get hasBuiltinKey =>
      defaultMinimaxApiKey.trim().isNotEmpty &&
      defaultMinimaxApiKey != 'YOUR_MINIMAX_API_KEY_HERE';
}
