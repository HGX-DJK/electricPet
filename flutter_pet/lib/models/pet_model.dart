import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    'cat_ragdoll': SkinConfig(
      id: 'cat_ragdoll',
      name: '布偶猫',
      breed: '布偶猫 (Ragdoll)',
      title: '仙女喵',
      desc: '温顺亲人如小仙女，拥有对称八字双色面具与湛蓝深邃大眼',
      primaryColor: 0xFFFDFBF7,
      secondaryColor: 0xFF4A3525,
      eyeColor: 0xFF0284C7,
      icon: '🌸',
    ),
    'cat_british_blue': SkinConfig(
      id: 'cat_british_blue',
      name: '英国短毛猫',
      breed: '英国短毛猫 (British Blue)',
      title: '蓝胖子',
      desc: '经典蓝灰缎面毛发，迷人琥珀金圆眼与肉嘟嘟大包子脸',
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
    'cat_siamese': SkinConfig(
      id: 'cat_siamese',
      name: '暹罗猫',
      breed: '暹罗猫 (Siamese)',
      title: '挖煤小工',
      desc: '热带贵族话痨小猫，标志性的焦褐重点色糊糊小黑脸',
      primaryColor: 0xFFF5EBE0,
      secondaryColor: 0xFF3E2723,
      eyeColor: 0xFF38BDF8,
      icon: '☕',
    ),
    'cat_calico': SkinConfig(
      id: 'cat_calico',
      name: '中华三花猫',
      breed: '中华三花猫 (Calico)',
      title: '幸运招财',
      desc: '三色交织天生丽质，民间招财迎福、带来好运和平安的象征',
      primaryColor: 0xFFFFFFFF,
      secondaryColor: 0xFFE28743,
      eyeColor: 0xFF4ADE80,
      icon: '🐾',
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
    'cat_persian_white': SkinConfig(
      id: 'cat_persian_white',
      name: '临清狮子猫',
      breed: '临清狮子猫 (Persian Lion)',
      title: '雪域纯白',
      desc: '通体如雪丝绸长毛，自带仙气与高贵纯洁的澄澈水灵双眸',
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
    {'id': 'dried_fish', 'name': '香脆小鱼干', 'icon': '🐟', 'hunger': 18.0, 'mood': 10.0, 'exp': 15.0},
    {'id': 'canned_tuna', 'name': '特级金枪鱼罐头', 'icon': '🥫', 'hunger': 35.0, 'mood': 25.0, 'exp': 30.0},
    {'id': 'freeze_dried_salmon', 'name': '冻干三文鱼块', 'icon': '🍣', 'hunger': 28.0, 'mood': 20.0, 'exp': 25.0},
    {'id': 'milk', 'name': '香浓舒化羊奶', 'icon': '🥛', 'hunger': 12.0, 'mood': 15.0, 'exp': 10.0},
    {'id': 'cat_pudding', 'name': '焦糖猫布丁', 'icon': '🍮', 'hunger': 15.0, 'mood': 22.0, 'exp': 18.0},
    {'id': 'cat_grass', 'name': '有机猫草沙拉', 'icon': '🌿', 'hunger': 8.0, 'mood': 12.0, 'exp': 12.0},
    {'id': 'strawberry_cake', 'name': '草莓千层蛋糕', 'icon': '🍰', 'hunger': 22.0, 'mood': 28.0, 'exp': 26.0},
    {'id': 'golden_feast', 'name': '奢华猫咪满汉全席', 'icon': '🍱', 'hunger': 60.0, 'mood': 50.0, 'exp': 80.0},
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

  bool isSleeping = false;
  bool isStudying = false;
  bool enableSound = true;
  bool enableHaptics = true;

  Map<String, String> decorations = {
    'head': 'none',
    'neck': 'bell',
  };

  PetModel() {
    loadFromDisk();
  }

  SkinConfig get currentSkin => availableSkins[skinId] ?? availableSkins['cat_calico']!;

  double get maxExpForLevel => 60.0 + (level * 35.0);

  double get expProgress => (exp / maxExpForLevel).clamp(0.0, 1.0);

  /// 投喂美食
  bool feed(String foodId) {
    if (isSleeping) return false;
    final food = foodMenu.firstWhere((f) => f['id'] == foodId, orElse: () => foodMenu.first);
    hunger = (hunger + (food['hunger'] as double)).clamp(0.0, 100.0);
    mood = (mood + (food['mood'] as double)).clamp(0.0, 100.0);
    intimacy += 8;
    totalFedCount += 1;
    weight += 0.02;
    addExp(food['exp'] as double);
    notifyListeners();
    saveToDisk();
    return true;
  }

  /// 抚摸头部
  void petHead() {
    mood = (mood + 4.5).clamp(0.0, 100.0);
    intimacy += 3;
    addExp(4.0);
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
    }
    notifyListeners();
    saveToDisk();
    return isSleeping;
  }

  /// 专注学习
  bool toggleStudy() {
    isStudying = !isStudying;
    if (isStudying) {
      isSleeping = false;
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

  Future<void> saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
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
        'decorations': decorations,
        'enableSound': enableSound,
        'enableHaptics': enableHaptics,
      };
      await prefs.setString('poko_pet_data', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('poko_pet_data');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
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
        if (data['decorations'] != null) {
          decorations = Map<String, String>.from(data['decorations']);
        }
        enableSound = data['enableSound'] ?? enableSound;
        enableHaptics = data['enableHaptics'] ?? enableHaptics;
        notifyListeners();
      }
    } catch (_) {}
  }
}
