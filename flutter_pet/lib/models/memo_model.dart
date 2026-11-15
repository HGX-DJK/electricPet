import 'dart:convert';
import '../theme/poko_theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoTheme {
  final String id;
  final String name;
  final Color bg;
  final Color border;
  final Color header;
  final Color text;
  final Color sub;

  const MemoTheme({
    required this.id,
    required this.name,
    required this.bg,
    required this.border,
    required this.header,
    required this.text,
    required this.sub,
  });
}

class MemoModel extends ChangeNotifier {
  static const Map<String, MemoTheme> themes = {
    'yellow': MemoTheme(
      id: 'yellow',
      name: '奶杏黄',
      bg: PokoPalette.glow_warm,
      border: PokoPalette.yellow_300,
      header: PokoPalette.yellow_200,
      text: PokoPalette.slate_800,
      sub: PokoPalette.amber_800,
    ),
    'pink': MemoTheme(
      id: 'pink',
      name: '落樱粉',
      bg: PokoPalette.rose_50,
      border: PokoPalette.rose_200,
      header: PokoPalette.rose_100,
      text: PokoPalette.slate_800,
      sub: PokoPalette.rose_900,
    ),
    'green': MemoTheme(
      id: 'green',
      name: '薄荷绿',
      bg: PokoPalette.emerald_50,
      border: PokoPalette.mint_200,
      header: PokoPalette.mint_100,
      text: PokoPalette.slate_800,
      sub: PokoPalette.mint_800,
    ),
    'blue': MemoTheme(
      id: 'blue',
      name: '晴空蓝',
      bg: PokoPalette.blue_50,
      border: PokoPalette.blue_200,
      header: PokoPalette.blue_100,
      text: PokoPalette.slate_800,
      sub: PokoPalette.blue_800,
    ),
  };

  String content = '';
  String currentThemeKey = 'yellow';
  bool isPinned = true;
  String updatedAt = '';

  /// 异步磁盘载入完成凭证
  late final Future<void> isReady;

  MemoModel() {
    isReady = loadFromDisk();
  }

  MemoTheme get currentTheme => themes[currentThemeKey] ?? themes['yellow']!;

  void setContent(String text) {
    content = text;
    final now = DateTime.now();
    updatedAt = '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    notifyListeners();
    saveToDisk();
  }

  void setTheme(String themeId) {
    if (themes.containsKey(themeId)) {
      currentThemeKey = themeId;
      notifyListeners();
      saveToDisk();
    }
  }

  void togglePin() {
    isPinned = !isPinned;
    notifyListeners();
    saveToDisk();
  }

  void insertTimestamp() {
    final now = DateTime.now();
    final timeStr = '【${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}】';
    content = content.isEmpty ? timeStr : '$content\n$timeStr ';
    notifyListeners();
    saveToDisk();
  }

  /// 当前便签数据的快照（与 [saveToDisk] 落盘的内容保持一致）。
  ///
  /// 供「覆盖前安全备份」使用 —— 继承历史档案会整体替换便签内容，
  /// 替换前得先把现有一份另存出来。
  Map<String, dynamic> toDataMap() {
    return {
      'content': content,
      'currentThemeKey': currentThemeKey,
      'isPinned': isPinned,
      'updatedAt': updatedAt,
    };
  }

  Future<void> saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = toDataMap();
      await prefs.setString('poko_memo_data', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('poko_memo_data');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        content = data['content'] ?? '';
        currentThemeKey = data['currentThemeKey'] ?? 'yellow';
        isPinned = data['isPinned'] ?? true;
        updatedAt = data['updatedAt'] ?? '';
        notifyListeners();
      }
    } catch (_) {}
  }
}
