import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/backup_service.dart';
import '../services/overlay_service.dart';

/// 宠物外观皮肤/品种配置
class SkinConfig {
  final String id;
  final String name;      // 简短名称 (如 "布偶猫")
  final String breed;     // 完整品种名 (如 "布偶猫 (Ragdoll)")
  final String title;     // 专属称号 (如 "仙女喵")
  final String desc;      // 外貌与性格简介
  final int primaryColor;
  final int secondaryColor;
  final int eyeColor;
  final String icon;      // 品种代表 emoji

  const SkinConfig({
    required this.id,
    required this.name,
    required this.breed,
    required this.title,
    required this.desc,
    required this.primaryColor,
    required this.secondaryColor,
    required this.eyeColor,
    this.icon = '🐱',
  });
}

/// 一条真实的时光纪念。
///
/// 既包括系统自动记下的成长里程碑（第一次喂食、升级、换装、陪伴满 N 天…），
/// 也包括用户自己拍下的「今日纪念照」—— 全部落盘，重启还在。
///
/// 以前这个相册是五张写死的假卡片，日期也是编的，
/// 「拍下一张今日纪念照」按钮只播了个音效，什么也没存 —— 毫无实际意义。
class MemoryEntry {
  /// 去重键：里程碑用稳定 id（如 `level_3`），快照用时间戳
  final String id;
  final String title;
  final String note;
  final String emoji;
  final String badge;

  /// 发生时间（毫秒）
  final int timestamp;

  /// 记录当时的品种
  final String skinId;

  /// true = 用户亲手拍的快照；false = 系统自动记下的里程碑
  final bool isSnapshot;

  const MemoryEntry({
    required this.id,
    required this.title,
    required this.note,
    required this.emoji,
    required this.badge,
    required this.timestamp,
    required this.skinId,
    this.isSnapshot = false,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'title': title,
        'note': note,
        'emoji': emoji,
        'badge': badge,
        'timestamp': timestamp,
        'skinId': skinId,
        'isSnapshot': isSnapshot,
      };

  static MemoryEntry fromMap(Map<String, dynamic> m) => MemoryEntry(
        id: (m['id'] ?? '') as String,
        title: (m['title'] ?? '') as String,
        note: (m['note'] ?? '') as String,
        emoji: (m['emoji'] ?? '🐾') as String,
        badge: (m['badge'] ?? '纪念') as String,
        timestamp: (m['timestamp'] as num?)?.toInt() ?? 0,
        skinId: (m['skinId'] ?? '') as String,
        isSnapshot: (m['isSnapshot'] as bool?) ?? false,
      );

  /// 真实日期（YYYY.MM.DD）
  String get dateText {
    final d = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

/// 萌宠核心属性与成长模型
class PetModel extends ChangeNotifier {
  static const Map<String, SkinConfig> availableSkins = {
    'cat_golden_shaded': SkinConfig(
      id: 'cat_golden_shaded',
      name: '金渐层英短',
      breed: '英国短毛猫 (Golden Shaded Ny25)',
      title: '富贵金渐层',
      desc: '猫界顶流大明星！暖金杏桃渐变软毛、圆滚滚包子脸与一双祖母绿宝石明眸',
      primaryColor: 0xFFFED7AA,
      secondaryColor: 0xFFD97706,
      eyeColor: 0xFF059669,
      icon: '👑',
    ),
    'cat_silver_shaded': SkinConfig(
      id: 'cat_silver_shaded',
      name: '银渐层英短',
      breed: '英国短毛猫 (Silver Shaded Ns11)',
      title: '仙气银渐层',
      desc: '仙气白月光！通体若轻柔白雪覆霜顶，配纯黑自然眼线与清澈薄荷绿碧玉眸',
      primaryColor: 0xFFF8FAFC,
      secondaryColor: 0xFF94A3B8,
      eyeColor: 0xFF0D9488,
      icon: '💎',
    ),
    'cat_ragdoll': SkinConfig(
      id: 'cat_ragdoll',
      name: '海蓝双色布偶',
      breed: '布偶猫 (Blue Bicolor Ragdoll)',
      title: '绝美小仙女',
      desc: '猫中仙女！对称柔雅的银蓝八字开脸、如云雪白长围脖与深邃海蓝宝石双眸',
      primaryColor: 0xFFFFFDF8,
      secondaryColor: 0xFF8E9AAF,
      eyeColor: 0xFF0284C7,
      icon: '🌸',
    ),
    'cat_tuxedo': SkinConfig(
      id: 'cat_tuxedo',
      name: '黑白奶牛警长',
      breed: '中华奶牛猫 (Tuxedo Cat)',
      title: '帅气绅士喵',
      desc: '帅气燕尾服加身！对称白鼻梁八字面具、雪白围脖与优雅四蹄踏雪',
      primaryColor: 0xFF1E293B,
      secondaryColor: 0xFFFFFFFF,
      eyeColor: 0xFFFACC15,
      icon: '🎩',
    ),
    'cat_maine_coon': SkinConfig(
      id: 'cat_maine_coon',
      name: '霸气森林缅因',
      breed: '缅因猫 (Maine Coon)',
      title: '森林小狮子',
      desc: '猫界温柔巨人！威风凛凛的猞猁耳尖羽毛、霸气狮鬃领圈与蓬松狐狸长尾',
      primaryColor: 0xFFD7CCC8,
      secondaryColor: 0xFF4E342E,
      eyeColor: 0xFFEAB308,
      icon: '🦁',
    ),
    'cat_sakura_peach': SkinConfig(
      id: 'cat_sakura_peach',
      name: '樱花蜜桃粉晶猫',
      breed: '梦幻仙境奇喵 (Sakura Peach)',
      title: '粉晶治愈喵',
      desc: '春日童话萌宠！柔润蜜桃粉渐变被毛、粉红樱花肉垫与水润玫瑰星芒明眸',
      primaryColor: 0xFFFFF0F5,
      secondaryColor: 0xFFF472B6,
      eyeColor: 0xFFFB7185,
      icon: '🍡',
    ),
    'cat_british_blue': SkinConfig(
      id: 'cat_british_blue',
      name: '英国短毛蓝猫',
      breed: '英国短毛猫 (British Blue)',
      title: '经典蓝胖子',
      desc: '经典蓝灰缎面毛发，肉嘟嘟大包子脸与如小太阳般温暖澄澈的琥珀金圆眼',
      primaryColor: 0xFF64748B,
      secondaryColor: 0xFF475569,
      eyeColor: 0xFFF59E0B,
      icon: '🍊',
    ),
    'cat_american_tabby': SkinConfig(
      id: 'cat_american_tabby',
      name: '美短银虎斑',
      breed: '美短银虎斑 (American Tabby)',
      title: '银斑精灵',
      desc: '银白底色配灵动黑灰鱼骨斑纹，额头 M 纹霸气又活泼敏捷',
      primaryColor: 0xFFE2E8F0,
      secondaryColor: 0xFF334155,
      eyeColor: 0xFF10B981,
      icon: '🐯',
    ),
    'cat_orange': SkinConfig(
      id: 'cat_orange',
      name: '中华大橘猫',
      breed: '中华大橘猫 (Ginger Tabby)',
      title: '大橘为重',
      desc: '阳光开朗大吃货，手感极佳毛茸茸、超治愈的小暖炉',
      primaryColor: 0xFFFED7AA,
      secondaryColor: 0xFFEA580C,
      eyeColor: 0xFFFBBF24,
      icon: '🥐',
    ),
    'cat_calico': SkinConfig(
      id: 'cat_calico',
      name: '日系软萌三花',
      breed: '中华三花猫 (Pastel Calico)',
      title: '幸运锦鲤喵',
      desc: '温柔杏桃与暖灰轻落雪白软毛，民间招财迎福、带来好运和平安的象征',
      primaryColor: 0xFFFFFFFF,
      secondaryColor: 0xFFFF9E7D,
      eyeColor: 0xFF10B981,
      icon: '🐾',
    ),
    'cat_persian_white': SkinConfig(
      id: 'cat_persian_white',
      name: '异瞳临清狮子猫',
      breed: '临清狮子猫 (Odd-eyed Lion)',
      title: '金银双眸仙子',
      desc: '通体如雪丝绸长毛，自带仙气的金银双色鸳鸯异瞳（左金右蓝）',
      primaryColor: 0xFFFFFFFF,
      secondaryColor: 0xFFF1F5F9,
      eyeColor: 0xFF06B6D4,
      icon: '❄️',
    ),
    'cat_white': SkinConfig(
      id: 'cat_white',
      name: '雪球白猫',
      breed: '雪球白猫 (Pure White)',
      title: '纯白雪球',
      desc: '通体如雪，灵动纯洁',
      primaryColor: 0xFFFFFFFF,
      secondaryColor: 0xFFF1F5F9,
      eyeColor: 0xFF06B6D4,
      icon: '❄️',
    ),
    'cat_siamese': SkinConfig(
      id: 'cat_siamese',
      name: '焦糖拿铁暹罗',
      breed: '暹罗猫 (Caramel Point)',
      title: '灵动小淘气',
      desc: '热带贵族话痨小猫，温柔暖调焦糖重点色配电光天青蓝宝石双眸',
      primaryColor: 0xFFFAF5EF,
      secondaryColor: 0xFF5C3D2E,
      eyeColor: 0xFF38BDF8,
      icon: '☕',
    ),
    'cat_black': SkinConfig(
      id: 'cat_black',
      name: '玄夜黑猫',
      breed: '玄夜黑猫 (Black Cat)',
      title: '暗夜玄神',
      desc: '神秘高雅黑曜石灵猫，金色眼眸如同暗夜中明亮澄澈的星火',
      primaryColor: 0xFF0F172A,
      secondaryColor: 0xFF1E293B,
      eyeColor: 0xFFFACC15,
      icon: '🖤',
    ),
  };

  static const List<Map<String, dynamic>> foodMenu = [
    {'id': 'dried_fish', 'name': '香酥小鱼干', 'icon': '🐟', 'hunger': 18.0, 'mood': 10.0, 'exp': 15.0, 'personality': ['sport', 2]},
    {'id': 'canned_tuna', 'name': '特级金枪鱼罐头', 'icon': '🥫', 'hunger': 35.0, 'mood': 25.0, 'exp': 30.0, 'personality': ['sport', 3]},
    {'id': 'freeze_dried_salmon', 'name': '纯肉三文鱼', 'icon': '🍣', 'hunger': 28.0, 'mood': 20.0, 'exp': 25.0, 'personality': ['sport', 2]},
    {'id': 'cyber_chip', 'name': '赛博能量芯片', 'icon': '⚡', 'hunger': 25.0, 'mood': 20.0, 'exp': 35.0, 'personality': ['tech', 4]},
    {'id': 'hacker_coffee', 'name': '极客黑客冷萃', 'icon': '☕', 'hunger': 15.0, 'mood': 30.0, 'exp': 30.0, 'personality': ['tech', 3]},
    {'id': 'milk', 'name': '舒化羊奶', 'icon': '🥛', 'hunger': 12.0, 'mood': 15.0, 'exp': 10.0, 'personality': ['lazy', 3]},
    {'id': 'cat_pudding', 'name': '焦糖猫布丁', 'icon': '🍮', 'hunger': 15.0, 'mood': 22.0, 'exp': 18.0, 'personality': ['lazy', 2]},
    {'id': 'cat_grass', 'name': '有机猫草沙拉', 'icon': '🌿', 'hunger': 8.0, 'mood': 12.0, 'exp': 12.0, 'personality': ['sport', 1]},
    {'id': 'strawberry_cake', 'name': '草莓千层蛋糕', 'icon': '🍰', 'hunger': 22.0, 'mood': 28.0, 'exp': 26.0, 'personality': ['lazy', 2]},
    {'id': 'golden_feast', 'name': '奢华猫咪满汉全席', 'icon': '🍱', 'hunger': 60.0, 'mood': 50.0, 'exp': 80.0, 'personality': ['sport', 4]},
  ];

  String name = '波可 (Poko)';
  String skinId = 'cat_calico';
  double hunger = 85.0;      // 饱腹度 (0~100)
  double mood = 90.0;        // 心情值 (0~100)
  double energy = 80.0;      // 体力值 (0~100)
  double cleanliness = 85.0; // 洁净度 (0~100)

  /// 状态快照的时间戳（毫秒）：当前这组状态值是"那一刻"的真实值。
  ///
  /// 背景：App 内与桌面悬浮宠都会按时间衰减这组状态，两边同时扣会重复扣减。
  /// 约定为「谁写盘谁盖时间戳」，另一方按 (now - stateSavedAt) 补算，
  /// 这样同一段时间永远只会被扣一次，两边读到的值也一致。
  int stateSavedAt = 0;

  /// 状态衰减速率（每秒）。
  ///
  /// ⚠️ 必须与原生侧 `FloatingPetService` 的 DECAY_RATES 保持完全一致，
  /// 否则 App 里和桌面上的波可会算出不同的状态。守护测试会逐项比对。
  static const Map<String, double> decayRates = <String, double>{
    'hunger': 0.45,
    'mood': 0.35,
    'cleanliness': 0.15,
    'energy': 0.25,
  };

  /// 单次最多补算的离线时长（秒，12 小时）——防止改系统时间造成数值爆炸
  static const double maxOfflineDecaySeconds = 43200;

  int level = 1;
  double exp = 0.0;
  int intimacy = 100;
  double weight = 3.6;
  int totalFedCount = 0;
  int birthTime = 0; // 初生时间戳 (毫秒)

  /// 真实陪伴天数 (根据初生时间戳动态计算)
  int get totalDays {
    if (birthTime <= 0) return 1;
    final diffMs = DateTime.now().millisecondsSinceEpoch - birthTime;
    if (diffMs <= 0) return 1;
    return math.max(1, (diffMs / 86400000).floor() + 1);
  }

  // ---------- 时光纪念相册（真实记录，落盘持久化） ----------

  /// 纪念相册内容，**最新在前**
  final List<MemoryEntry> memories = <MemoryEntry>[];

  /// 相册最多保留多少条（超出的从最旧开始丢）
  static const int maxMemories = 80;

  /// 上次检查陪伴天数里程碑时的天数（避免每秒重复扫描）
  int _lastMilestoneDays = 0;

  /// 记一条纪念（同一个 id 只记一次）。
  ///
  /// [timestamp] 允许传入"这件事真正发生的时间"——
  /// 比如陪伴满 7 天是第 7 天的事，补记时也要写第 7 天的日期，而不是今天。
  void recordMemory({
    required String id,
    required String title,
    required String note,
    required String emoji,
    required String badge,
    int? timestamp,
  }) {
    if (memories.any((m) => m.id == id)) return;
    _insertMemory(
      MemoryEntry(
        id: id,
        title: title,
        note: note,
        emoji: emoji,
        badge: badge,
        timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
        skinId: skinId,
      ),
    );
    notifyListeners();
    saveToDisk();
  }

  /// 按时间倒序插入纪念（最新的在最前面；补记的旧里程碑会回到它该在的位置）
  void _insertMemory(MemoryEntry entry) {
    // 用 <= 而不是 <：同一毫秒内发生的两件事（如"初遇"和"第一张快照"），
    // 后来的那条必须排在前面，否则"最新在最前"会在毫秒边界上翻车。
    var index = memories.indexWhere((m) => m.timestamp <= entry.timestamp);
    if (index < 0) index = memories.length;
    memories.insert(index, entry);
    if (memories.length > maxMemories) {
      memories.removeRange(maxMemories, memories.length);
    }
  }

  /// 拍一张「今日纪念照」——真的会进相册、也会存盘。
  MemoryEntry takeSnapshot() {
    final now = DateTime.now();
    final skin = currentSkin;
    final state = _stateLine();
    final entry = MemoryEntry(
      id: 'snap_${now.millisecondsSinceEpoch}',
      title: '${now.month} 月 ${now.day} 日 · ${skin.name}',
      note: '今天的我，是$skin.name。$state',
      emoji: skin.icon,
      badge: '今日纪念',
      timestamp: now.millisecondsSinceEpoch,
      skinId: skinId,
      isSnapshot: true,
    );
    _insertMemory(entry);
    notifyListeners();
    saveToDisk();
    return entry;
  }

  /// 一句话描述当前状态（拍立得手账用）
  String _stateLine() {
    if (isSleeping) return '正缩在暖垫上呼呼大睡，梦里大概全是小鱼干～';
    if (hunger < 35) return '肚子咕咕叫着想吃小鱼干，胡须都耷拉下来了～';
    if (cleanliness < 40) return '毛上沾了点灰，得找个时间好好搓个澡～';
    if (mood < 40) return '有点小失落，蹭蹭你的手心就会好起来～';
    return '今天状态满满，尾巴翘得老高，元气满满地陪着你！';
  }

  /// 检查羁绊阶段里程碑（阶段提升时记一条）
  void _syncBondMilestone() {
    final bond = intimacyBondInfo;
    final stage = bond['stage'] as int;
    recordMemory(
      id: 'bond_$stage',
      title: '羁绊进阶 · ${bond['title']}',
      note: '${bond['desc']}从这一刻起，我开始叫你「${bond['ownerTitle']}」啦！',
      emoji: bond['icon'] as String,
      badge: '羁绊$stage阶段',
    );
  }

  /// 检查陪伴天数里程碑（第 7 / 30 / 100 / 365 天）
  void _syncDayMilestones() {
    if (birthTime <= 0) return;
    final days = totalDays;
    if (days == _lastMilestoneDays) return;
    _lastMilestoneDays = days;
    const marks = <int>[7, 30, 100, 365];
    for (final d in marks) {
      if (days < d) continue;
      // 写第 d 天那天真正发生的时间，而不是补记的今天
      final at = birthTime + (d - 1) * 86400000;
      recordMemory(
        id: 'days_$d',
        title: '相伴第 $d 天',
        note: '已经和你一起走过 $d 天啦！每一天的投喂、摸头、磨爪，我都记在心里 💖',
        emoji: d >= 100 ? '🎉' : '📅',
        badge: '陪伴里程碑',
        timestamp: at,
      );
    }
  }

  bool isSleeping = false;
  bool isStudying = false;
  bool enableSound = true;
  bool enableHaptics = true;
  bool enableFootprints = true;
  double userScale = 1.0;

  Map<String, int> personalityStats = {
    'tech': 0,
    'sport': 0,
    'lazy': 0,
  };

  String habitat = 'none'; // 'none', 'neon_matrix', 'retro_arcade', 'summer_beach', 'zen_tatami'
  int coins = 200;
  List<String> unlockedItems = [
    'none', 'bell', 'ribbon', 'cat_calico', 'cat_ragdoll'
  ];

  Map<String, String> decorations = {
    'head': 'none',
    'face': 'none',
    'neck': 'bell',
    'back': 'none',
    'hand': 'none',
  };

  /// 首次启动/重装后初生状态标记 (用于触发首启历史档案检测)
  bool isFreshInstall = false;

  /// 异步磁盘载入完成凭证 (避免构造函数未完成时的读取时序竞态)
  late final Future<void> isReady;

  PetModel() {
    birthTime = DateTime.now().millisecondsSinceEpoch;
    isReady = loadFromDisk();
  }

  /// 主导性格判定: HACKER (极客黑客喵), ATHLETE (元气运动喵), LAZY (佛系大懒喵), BALANCED (纯真萌体)
  String get personality {
    final tech = personalityStats['tech'] ?? 0;
    final sport = personalityStats['sport'] ?? 0;
    final lazy = personalityStats['lazy'] ?? 0;

    final scores = [
      MapEntry('HACKER', tech),
      MapEntry('ATHLETE', sport),
      MapEntry('LAZY', lazy),
    ];
    scores.sort((a, b) => b.value.compareTo(a.value));
    final top = scores[0];
    final second = scores[1];

    if (top.value >= 15 && (top.value - second.value >= 3)) {
      return top.key;
    }
    return 'BALANCED';
  }

  /// 性格专属档案与特权
  Map<String, dynamic> get personalityInfo {
    switch (personality) {
      case 'HACKER':
        return {
          'id': 'HACKER',
          'name': '极客黑客喵 ⚡',
          'badge': '⚡ 极客黑客喵',
          'title': '赛博算力核心 · 极客黑客喵',
          'desc': '常食能量芯片与黑客冷萃，精通各种语言代码，警报 Bug 灵敏度 100%！',
          'bonus': '专注模式算力效率提升 +20%，周围伴随矩阵代码流',
          'color': 0xFF0EA5E9,
          'exclusiveItem': 'hacker_viser',
          'exclusiveItemName': '战术全息目镜',
        };
      case 'ATHLETE':
        return {
          'id': 'ATHLETE',
          'name': '元气运动喵 🏃',
          'badge': '🏃 元气运动喵',
          'title': '桌面闪电飞人 · 元气运动喵',
          'desc': '热爱追逐玩耍与敏捷翻滚，身手矫健活力四射，浑身充满热血能量！',
          'bonus': '漫步移动速度提升 +25%，互动兴奋度翻倍',
          'color': 0xFF10B981,
          'exclusiveItem': 'band_sport',
          'exclusiveItemName': '热血运动发带',
        };
      case 'LAZY':
        return {
          'id': 'LAZY',
          'name': '佛系大懒喵 🍵',
          'badge': '🍵 佛系大懒喵',
          'title': '躺平禅意宗师 · 佛系大懒喵',
          'desc': '随遇而安发呆大师，享受温暖日光与软垫小憩，万物皆空小鱼干独尊！',
          'bonus': '睡眠精力恢复加速 +30%，更持久的心情稳定度',
          'color': 0xFFF59E0B,
          'exclusiveItem': 'cushion_zen',
          'exclusiveItemName': '禅意榻榻米软垫',
        };
      case 'BALANCED':
      default:
        return {
          'id': 'BALANCED',
          'name': '纯真软萌体 🐾',
          'badge': '🐾 纯真萌宠',
          'title': '元气初生伙伴 · 纯真萌体',
          'desc': '性格均衡可爱，对桌面上的一切新鲜事物保持着天真好奇与探索欲。',
          'bonus': '均衡成长，各项属性消耗平缓',
          'color': 0xFFEC4899,
          'exclusiveItem': 'none',
          'exclusiveItemName': '无',
        };
    }
  }

  void addPersonalityPoint(String category, int pts) {
    if (pts <= 0) return;
    personalityStats[category] = (personalityStats[category] ?? 0) + pts;
    notifyListeners();
    saveToDisk();
  }

  void setHabitat(String newHabitat) {
    habitat = newHabitat;
    notifyListeners();
    saveToDisk();
  }

  /// 赛博盲盒抽卡系统 (单抽 / 十连保底 SSR/UR)
  List<Map<String, dynamic>> drawGacha(int count) {
    final pool = [
      {'rarity': 'UR', 'slot': 'habitat', 'code': 'neon_matrix', 'name': '暗夜霓虹极客房', 'icon': '💻', 'weight': 4, 'desc': '全景赛博代码雨，专注效率提升+20%'},
      {'rarity': 'UR', 'slot': 'habitat', 'code': 'retro_arcade', 'name': '复古像素电玩厅', 'icon': '🕹️', 'weight': 4, 'desc': '80s 霓虹晚霞与十字星，心情回复加速'},
      {'rarity': 'UR', 'slot': 'back', 'code': 'wings_angel', 'name': '圣洁天使羽翼', 'icon': '🪽', 'weight': 5, 'desc': '神圣光翼展开，高空轻盈缓降，飘落治愈爱心'},
      {'rarity': 'UR', 'slot': 'head', 'code': 'gold_crown_sparkle', 'name': '璀璨星辉皇冠', 'icon': '👑', 'weight': 5, 'desc': '纯金钻石皇冠，闪烁星辉尊贵非凡'},
      {'rarity': 'SSR', 'slot': 'face', 'code': 'hacker_viser', 'name': '赛博战术目镜', 'icon': '🥽', 'weight': 10, 'desc': '战术全息HUD扫描，周围触发二进制流动光环'},
      {'rarity': 'SSR', 'slot': 'head', 'code': 'band_sport', 'name': '热血运动发带', 'icon': '🥊', 'weight': 10, 'desc': '元气运动加成，步履矫健，移动速度+30%'},
      {'rarity': 'SSR', 'slot': 'back', 'code': 'cushion_zen', 'name': '禅意榻榻米软垫', 'icon': '🍵', 'weight': 10, 'desc': '随心躺平蒲团，安睡体力恢复+35%'},
      {'rarity': 'SSR', 'slot': 'hand', 'code': 'keyboard_rgb', 'name': 'RGB机械键盘', 'icon': '⌨️', 'weight': 12, 'desc': '敲击彩色发光键帽，经验获取速度+25%'},
      {'rarity': 'SSR', 'slot': 'hand', 'code': 'gamepad_retro', 'name': '8-bit 复古掌机', 'icon': '🎮', 'weight': 12, 'desc': '怀旧像素游戏快乐，玩耍兴奋度+30%'},
      {'rarity': 'SSR', 'slot': 'habitat', 'code': 'summer_beach', 'name': '夏日阳光海滩', 'icon': '🏖️', 'weight': 10, 'desc': '碧海金沙与椰树微风，清凉舒爽海浪'},
      {'rarity': 'SSR', 'slot': 'habitat', 'code': 'zen_tatami', 'name': '佛系禅意蒲团室', 'icon': '🌸', 'weight': 10, 'desc': '和室障子与漫天落樱，静心禅意'},
      {'rarity': 'SR', 'slot': 'back', 'code': 'cape_cyber', 'name': '赛博霓虹披风', 'icon': '🦸‍♂️', 'weight': 15, 'desc': '暗夜流光披风，霓虹电路线路'},
      {'rarity': 'SR', 'slot': 'hand', 'code': 'teaser_laser', 'name': '全息光纤逗猫棒', 'icon': '🪄', 'weight': 18, 'desc': '发光小鱼摇曳，猫咪最爱逗趣神器'},
      {'rarity': 'SR', 'slot': 'hand', 'code': 'coffee_cyber', 'name': '极客外带咖啡', 'icon': '☕', 'weight': 18, 'desc': '冷萃浓郁提神，陪伴学习专注Buff'},
      {'rarity': 'SR', 'slot': 'hand', 'code': 'dumbbell_power', 'name': '能量健身哑铃', 'icon': '🏋️', 'weight': 18, 'desc': '活力力量训练，健康值提升'},
      {'rarity': 'SR', 'slot': 'face', 'code': 'sunglasses_cool', 'name': '酷炫战术黑超', 'icon': '🕶️', 'weight': 20, 'desc': '飞行员金色边框墨镜，帅气逼人'},
      {'rarity': 'SR', 'slot': 'head', 'code': 'wizard_hat', 'name': '魔法巫师尖帽', 'icon': '🧙', 'weight': 20, 'desc': '神秘星夜魔术帽，智慧气息'},
      {'rarity': 'R', 'slot': 'neck', 'code': 'ribbon', 'name': '优雅赤红蝴蝶结', 'icon': '🎀', 'weight': 25, 'desc': '精致红丝绸结，淑女气质'},
      {'rarity': 'R', 'slot': 'neck', 'code': 'bell', 'name': '招财金小挂铃', 'icon': '🔔', 'weight': 25, 'desc': '清脆招财金铃铛，叮当悦耳'},
      {'rarity': 'R', 'slot': 'face', 'code': 'glasses_black', 'name': '黑框智能平光镜', 'icon': '🤓', 'weight': 25, 'desc': '学霸文青标配，斯文温和'},
    ];

    final cost = count == 1 ? 30 : 270;
    if (coins >= cost) {
      coins -= cost;
    } else {
      final expCost = (cost * 2).toDouble();
      exp = math.max(0.0, exp - expCost);
    }

    final totalWeight = pool.fold<int>(0, (sum, item) => sum + (item['weight'] as int));
    final random = math.Random();
    final results = <Map<String, dynamic>>[];

    for (int i = 0; i < count; i++) {
      Map<String, dynamic> chosen;
      if (count >= 10 && i == count - 1) {
        final highPool = pool.where((x) => x['rarity'] == 'SSR' || x['rarity'] == 'UR').toList();
        final highWeight = highPool.fold<int>(0, (sum, x) => sum + (x['weight'] as int));
        int r = random.nextInt(highWeight);
        int upto = 0;
        chosen = highPool.first;
        for (final item in highPool) {
          if (upto + (item['weight'] as int) > r) {
            chosen = item;
            break;
          }
          upto += item['weight'] as int;
        }
      } else {
        int r = random.nextInt(totalWeight);
        int upto = 0;
        chosen = pool.first;
        for (final item in pool) {
          if (upto + (item['weight'] as int) > r) {
            chosen = item;
            break;
          }
          upto += item['weight'] as int;
        }
      }

      final code = chosen['code'] as String;
      final isNew = !unlockedItems.contains(code);
      final refundCoins = isNew ? 0 : 15;
      if (isNew) {
        unlockedItems.add(code);
      }

      results.add({
        'rarity': chosen['rarity'],
        'slot': chosen['slot'],
        'code': code,
        'name': chosen['name'],
        'icon': chosen['icon'],
        'desc': chosen['desc'] ?? '专属装扮与成长加成',
        'isNew': isNew,
        'refundCoins': refundCoins,
      });
    }

    notifyListeners();
    saveToDisk();
    return results;
  }

  SkinConfig get currentSkin => availableSkins[skinId] ?? availableSkins['cat_calico']!;

  double get maxExpForLevel => 60.0 + (level * 35.0);

  double get expProgress => (exp / maxExpForLevel).clamp(0.0, 1.0);

  /// 亲密羁绊阶段配置模型 (陌生萌新 -> 熟悉玩伴 -> 亲密依恋 -> 形影不离 -> 灵魂羁绊)
  Map<String, dynamic> get intimacyBondInfo {
    if (intimacy < 60) {
      return {
        'stage': 1,
        'title': '陌生萌新',
        'icon': '🌱',
        'color': 0xFF10B981,
        'ownerTitle': '两脚兽朋友',
        'desc': '波可还在偷偷打量你，多喂食摸头建立信任吧~',
        'nextThreshold': 60,
        'progress': (intimacy / 60.0).clamp(0.0, 1.0),
      };
    } else if (intimacy < 150) {
      return {
        'stage': 2,
        'title': '熟悉玩伴',
        'icon': '🐾',
        'color': 0xFF38BDF8,
        'ownerTitle': '波可的好伙伴',
        'desc': '波可愿意主动跑过来蹭蹭手心啦！',
        'nextThreshold': 150,
        'progress': ((intimacy - 60) / 90.0).clamp(0.0, 1.0),
      };
    } else if (intimacy < 280) {
      return {
        'stage': 3,
        'title': '亲密依恋',
        'icon': '💖',
        'color': 0xFFF43F5E,
        'ownerTitle': '最喜欢的饲主',
        'desc': '解锁专属【皇家丝绒披风】！只要你在身边就很安心~',
        'nextThreshold': 280,
        'progress': ((intimacy - 150) / 130.0).clamp(0.0, 1.0),
      };
    } else if (intimacy < 450) {
      return {
        'stage': 4,
        'title': '形影不离',
        'icon': '⭐',
        'color': 0xFF8B5CF6,
        'ownerTitle': '波可的专属铲屎官',
        'desc': '解锁专属【璀璨星辉皇冠】！波可连睡觉都要贴着你~',
        'nextThreshold': 450,
        'progress': ((intimacy - 280) / 170.0).clamp(0.0, 1.0),
      };
    } else {
      return {
        'stage': 5,
        'title': '灵魂羁绊',
        'icon': '👑',
        'color': 0xFFF59E0B,
        'ownerTitle': '最爱最爱的主人大人',
        'desc': '心有灵犀的灵魂共鸣！波可会用一辈子守护主人！',
        'nextThreshold': 9999,
        'progress': 1.0,
      };
    }
  }

  void addIntimacy(int amount) {
    intimacy += amount;
    notifyListeners();
    saveToDisk();
    _syncBondMilestone();
  }

  void addCleanliness(double amount) {
    cleanliness = (cleanliness + amount).clamp(0.0, 100.0);
    notifyListeners();
    saveToDisk();
  }

  void addMood(double amount) {
    mood = (mood + amount).clamp(0.0, 100.0);
    notifyListeners();
    saveToDisk();
  }

  /// 是否已完全吃饱 (饱腹度达上限 100%)
  bool get isFull => hunger >= 100.0;

  /// 投喂美食 (支持防暴食机制，吃饱状态下拒食并给予萌系反馈)
  bool feed(String foodId, {bool allowWhenFull = true}) {
    if (isSleeping) return false;
    if (!allowWhenFull && isFull) return false;
    final food = foodMenu.firstWhere((f) => f['id'] == foodId, orElse: () => foodMenu.first);
    hunger = (hunger + (food['hunger'] as double)).clamp(0.0, 100.0);
    mood = (mood + (food['mood'] as double)).clamp(0.0, 100.0);
    intimacy += 8;
    totalFedCount += 1;
    weight += 0.02;
    addExp(food['exp'] as double);

    // 第一次被投喂 —— 这是最该被记住的一刻
    if (totalFedCount == 1) {
      recordMemory(
        id: 'first_feed',
        title: '第一口小鱼干',
        note: '你把${food['name']}递到我嘴边！第一口鱼干嘎吱嘎吱，尾巴当场翘成了问号 🐟',
        emoji: '🐟',
        badge: '第一次投喂',
      );
    }

    final pers = food['personality'] as List<dynamic>?;
    if (pers != null && pers.length == 2) {
      addPersonalityPoint(pers[0] as String, pers[1] as int);
    }

    notifyListeners();
    saveToDisk();
    return true;
  }

  /// 抚摸头部
  void petHead() {
    mood = (mood + 4.5).clamp(0.0, 100.0);
    intimacy += 3;
    addExp(4.0);
    addPersonalityPoint('sport', 1);
    notifyListeners();
    saveToDisk();
    _syncBondMilestone();
  }

  /// 洗澡清洁
  void wash() {
    cleanliness = 100.0;
    mood = (mood + 10.0).clamp(0.0, 100.0);
    addExp(15.0);
    // 第一次被搓澡 —— 也是一条值得记住的纪念
    recordMemory(
      id: 'first_wash',
      title: '第一次搓澡澡',
      note: '被你按在小盆里搓得蓬松又干净，抖了抖水珠，假装生气地喵了一声 🫧',
      emoji: '🫧',
      badge: '第一次洗澡',
    );
    notifyListeners();
    saveToDisk();
  }

  /// 哄睡 / 唤醒
  bool toggleSleep() {
    isSleeping = !isSleeping;
    if (isSleeping) {
      isStudying = false;
      addPersonalityPoint('lazy', 2);
    }
    notifyListeners();
    saveToDisk();
    return isSleeping;
  }

  /// 唤醒
  void wakeUp() {
    if (isSleeping) {
      isSleeping = false;
      notifyListeners();
      saveToDisk();
    }
  }

  /// 哄睡
  void sleep() {
    if (!isSleeping) {
      isSleeping = true;
      isStudying = false;
      addPersonalityPoint('lazy', 2);
      notifyListeners();
      saveToDisk();
    }
  }

  /// 专注学习
  bool toggleStudy() {
    isStudying = !isStudying;
    if (isStudying) {
      isSleeping = false;
    } else {
      addPersonalityPoint('tech', 4);
      coins += 10;
    }
    notifyListeners();
    saveToDisk();
    return isStudying;
  }

  /// 切换皮肤
  void setSkin(String newSkinId) {
    if (availableSkins.containsKey(newSkinId)) {
      final previousSkinId = skinId;
      skinId = newSkinId;
      // 第一次换上这个品种 —— 衣橱里的每一款，都值得留一张纪念
      final skin = availableSkins[newSkinId]!;
      recordMemory(
        id: 'skin_$newSkinId',
        title: '第一次换上${skin.name}',
        note: previousSkinId == newSkinId
            ? '又换上了${skin.name}，镜子里依然是那个最熟悉的毛茸茸～'
            : '换上了${skin.name}！${skin.desc}',
        emoji: skin.icon,
        badge: '新造型',
      );
      notifyListeners();
      saveToDisk();
      // 实时同步到桌面悬浮宠：所有换品种入口（衣橱弹窗/换装坞）都汇聚到这里，
      // 悬浮服务未运行时原生侧直接返回 false，不会误启动服务
      unawaited(
        OverlayService.updateFloatingPet(skinId: newSkinId, petName: name),
      );
    }
  }

  /// 佩戴装扮
  void setDecoration(String slot, String itemId) {
    decorations[slot] = itemId;
    notifyListeners();
    saveToDisk();
  }

  /// 获得经验升级
  void addExp(double amount) {
    exp += amount;
    while (exp >= maxExpForLevel) {
      exp -= maxExpForLevel;
      level += 1;
      intimacy += 25;
      coins += 20; // 升级奖励 20 赛博金币
      // 升级的瞬间就是一条值得记住的里程碑
      recordMemory(
        id: 'level_$level',
        title: '升级啦 · Lv.$level',
        note: '经验攒满，升级到 Lv.$level！还奖励了 20 枚赛博金币，尾巴当场翘成了问号 ✨',
        emoji: '⭐',
        badge: '等级里程碑',
      );
    }
    notifyListeners();
    saveToDisk();
    _syncBondMilestone();
  }

  /// 时间流逝状态扣减 (每秒调用)
  void tickDecay(double dt) {
    if (isSleeping) {
      energy = (energy + dt * 1.5).clamp(0.0, 100.0);
      hunger = (hunger - dt * 0.2).clamp(0.0, 100.0);
    } else {
      hunger = (hunger - dt * decayRates['hunger']!).clamp(0.0, 100.0);
      mood = (mood - dt * decayRates['mood']!).clamp(0.0, 100.0);
      cleanliness = (cleanliness - dt * decayRates['cleanliness']!).clamp(0.0, 100.0);
      energy = (energy - dt * decayRates['energy']!).clamp(0.0, 100.0);
    }
    notifyListeners();
    // 陪伴天数的里程碑（每跨过一天才检查一次）
    _syncDayMilestones();
  }

  /// 离线期间的状态补算：按 stateSavedAt 推算流逝时长并扣减。
  ///
  /// 桌面悬浮宠即使 App 没开也会按同一套速率结算，
  /// 所以这里必须和原生侧用完全相同的公式，否则两端会算出不同的状态。
  /// @return 实际补算的秒数
  double applyOfflineDecay() {
    if (stateSavedAt <= 0) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final seconds = ((now - stateSavedAt) / 1000.0).clamp(0.0, maxOfflineDecaySeconds);
    if (seconds <= 0) return 0;
    tickDecay(seconds);
    stateSavedAt = now;
    return seconds;
  }

  void setUserScale(double scale) {
    userScale = scale.clamp(0.75, 1.45);
    notifyListeners();
    saveToDisk();
  }

  void toggleFootprints() {
    enableFootprints = !enableFootprints;
    notifyListeners();
    saveToDisk();
  }

  Map<String, dynamic> toDataMap() {
    return {
      'name': name,
      'skinId': skinId,
      'hunger': hunger,
      'mood': mood,
      'energy': energy,
      'cleanliness': cleanliness,
      'stateSavedAt': stateSavedAt,
      'level': level,
      'exp': exp,
      'intimacy': intimacy,
      'weight': weight,
      'totalFedCount': totalFedCount,
      'birthTime': birthTime > 0 ? birthTime : DateTime.now().millisecondsSinceEpoch,
      'decorations': Map<String, String>.from(decorations),
      'personalityStats': Map<String, int>.from(personalityStats),
      'habitat': habitat,
      'coins': coins,
      'unlockedItems': List<String>.from(unlockedItems),
      'enableSound': enableSound,
      'enableHaptics': enableHaptics,
      'enableFootprints': enableFootprints,
      'userScale': userScale,
      'memories': memories.map((m) => m.toMap()).toList(),
    };
  }

  void applyDataMap(Map<String, dynamic> data) {
    name = data['name'] ?? name;
    skinId = data['skinId'] ?? skinId;
    hunger = (data['hunger'] as num?)?.toDouble() ?? hunger;
    mood = (data['mood'] as num?)?.toDouble() ?? mood;
    energy = (data['energy'] as num?)?.toDouble() ?? energy;
    cleanliness = (data['cleanliness'] as num?)?.toDouble() ?? cleanliness;
    stateSavedAt = (data['stateSavedAt'] as num?)?.toInt() ?? stateSavedAt;
    level = data['level'] ?? level;
    exp = (data['exp'] as num?)?.toDouble() ?? exp;
    intimacy = data['intimacy'] ?? intimacy;
    weight = (data['weight'] as num?)?.toDouble() ?? weight;
    totalFedCount = data['totalFedCount'] ?? totalFedCount;
    final rawBirth = (data['birthTime'] ?? data['birth_time']) as num?;
    if (rawBirth != null && rawBirth.toInt() > 0) {
      birthTime = rawBirth.toInt();
    } else if (birthTime <= 0) {
      birthTime = DateTime.now().millisecondsSinceEpoch;
    }
    if (data['decorations'] != null) {
      final loaded = Map<String, String>.from(data['decorations']);
      decorations['head'] = loaded['head'] ?? 'none';
      decorations['face'] = loaded['face'] ?? 'none';
      decorations['neck'] = loaded['neck'] ?? 'bell';
      decorations['back'] = loaded['back'] ?? 'none';
      decorations['hand'] = loaded['hand'] ?? 'none';
    }
    if (data['personalityStats'] != null) {
      personalityStats = Map<String, int>.from(data['personalityStats']);
    }
    habitat = data['habitat'] ?? habitat;
    coins = data['coins'] ?? coins;
    if (data['unlockedItems'] != null) {
      unlockedItems = List<String>.from(data['unlockedItems']);
    }
    enableSound = data['enableSound'] ?? enableSound;
    enableHaptics = data['enableHaptics'] ?? enableHaptics;
    enableFootprints = data['enableFootprints'] ?? enableFootprints;
    userScale = (data['userScale'] as num?)?.toDouble() ?? userScale;
    // 时光纪念相册：真实记录，跟着存档一起走
    if (data['memories'] != null) {
      final loaded = (data['memories'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(MemoryEntry.fromMap)
          .toList();
      memories
        ..clear()
        ..addAll(loaded);
    }
  }

  void restoreFromData(Map<String, dynamic> data) {
    applyDataMap(data);
    isFreshInstall = false;
    notifyListeners();
    // 读档后外观可能整体改变（含品种），同步给桌面悬浮宠
    unawaited(
      OverlayService.updateFloatingPet(skinId: skinId, petName: name),
    );
  }

  Future<void> saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 写盘即盖时间戳：这份状态值是"此刻"的真实值，
      // 桌面悬浮宠据此按 (now - stateSavedAt) 补算离线期间的衰减
      stateSavedAt = DateTime.now().millisecondsSinceEpoch;
      final data = toDataMap();
      await prefs.setString('poko_pet_data', jsonEncode(data));
      // 方案 B：静默双写到外部公用目录 (防卸载丢失)
      await BackupService.writeSilentBackup(data);
    } catch (_) {}
  }

  Future<void> flushSave() async => saveToDisk();

  Future<void> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString('poko_pet_data');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        applyDataMap(data);
        // 冷启动补算：App 关着这段时间状态也该衰减（桌面悬浮宠也是同一套公式）
        applyOfflineDecay();
        isFreshInstall = false;
        notifyListeners();
      } else {
        isFreshInstall = true;
        // 第一次相遇 —— 相册的第一张，也是最有分量的一张
        recordMemory(
          id: 'meet',
          title: '初遇的那天',
          note: '你第一次把我领进这个温暖的房间。我睁着大大的水灵眼睛，怯生生地打量着四周 —— 从今天起，我就是你的波可啦。',
          emoji: '🐱',
          badge: '初入家门',
          timestamp: birthTime > 0 ? birthTime : DateTime.now().millisecondsSinceEpoch,
        );
      }
    } catch (_) {
      isFreshInstall = true;
    }
  }
}
