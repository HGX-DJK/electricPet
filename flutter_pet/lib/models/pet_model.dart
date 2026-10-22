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
  }

  /// 洗澡清洁
  void wash() {
    cleanliness = 100.0;
    mood = (mood + 10.0).clamp(0.0, 100.0);
    addExp(15.0);
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
      skinId = newSkinId;
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
    }
    notifyListeners();
    saveToDisk();
  }

  /// 时间流逝状态扣减 (每秒调用)
  void tickDecay(double dt) {
    if (isSleeping) {
      energy = (energy + dt * 1.5).clamp(0.0, 100.0);
      hunger = (hunger - dt * 0.2).clamp(0.0, 100.0);
    } else {
      hunger = (hunger - dt * 0.45).clamp(0.0, 100.0);
      mood = (mood - dt * 0.35).clamp(0.0, 100.0);
      cleanliness = (cleanliness - dt * 0.15).clamp(0.0, 100.0);
      energy = (energy - dt * 0.25).clamp(0.0, 100.0);
    }
    notifyListeners();
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
    };
  }

  void applyDataMap(Map<String, dynamic> data) {
    name = data['name'] ?? name;
    skinId = data['skinId'] ?? skinId;
    hunger = (data['hunger'] as num?)?.toDouble() ?? hunger;
    mood = (data['mood'] as num?)?.toDouble() ?? mood;
    energy = (data['energy'] as num?)?.toDouble() ?? energy;
    cleanliness = (data['cleanliness'] as num?)?.toDouble() ?? cleanliness;
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
      final raw = prefs.getString('poko_pet_data');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        applyDataMap(data);
        isFreshInstall = false;
        notifyListeners();
      } else {
        isFreshInstall = true;
      }
    } catch (_) {
      isFreshInstall = true;
    }
  }
}
