import 'dart:convert';
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
      bg: Color(0xFFFEFCE8),
      border: Color(0xFFFDE047),
      header: Color(0xFFFEF08A),
      text: Color(0xFF1E293B),
      sub: Color(0xFF854D0E),
    ),
    'pink': MemoTheme(
      id: 'pink',
      name: '落樱粉',
      bg: Color(0xFFFFF1F2),
      border: Color(0xFFFECDD3),
      header: Color(0xFFFFE4E6),
      text: Color(0xFF1E293B),
      sub: Color(0xFF9F1239),
    ),
    'green': MemoTheme(
      id: 'green',
      name: '薄荷绿',
      bg: Color(0xFFF0FDF4),
      border: Color(0xFFBBF7D0),
      header: Color(0xFFDCFCE7),
      text: Color(0xFF1E293B),
      sub: Color(0xFF166534),
    ),
    'blue': MemoTheme(
      id: 'blue',
      name: '晴空蓝',
      bg: Color(0xFFEFF6FF),
      border: Color(0xFFBFDBFE),
      header: Color(0xFFDBEAFE),
      text: Color(0xFF1E293B),
      sub: Color(0xFF1E40AF),
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

  Future<void> saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'content': content,
        'currentThemeKey': currentThemeKey,
        'isPinned': isPinned,
        'updatedAt': updatedAt,
      };
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
