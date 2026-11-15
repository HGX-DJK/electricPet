import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ============================================================================
/// 设计系统守卫 —— 防止样式长尾复发的"体检报告"
/// ----------------------------------------------------------------------------
/// 这个仓库早年没有统一的样式令牌，各文件散落着裸 `Color(0xFF…)`、
/// `fontSize: 13.5`、`Duration(milliseconds: 180)`。三轮样式收敛已经把它们
/// 全部收进 [PokoPalette] / [PokoFont] / [PokoRadius] / [PokoDuration] /
/// [PokoCurves]。
///
/// 但令牌本身不会阻止下一个人再写一个裸值 —— 所以这里立规矩：
///
///  * **字号** 必须是 [PokoFont] 令牌，或属于"展示级"白名单（34/40/44/46/48，
///    这些是 emoji 与超大数字的字号，不是文本层级）。
///  * **样式转场时长** 必须是 [PokoDuration] 令牌。
///    `Timer(...)` / `Future.delayed(...)` 与"气泡停留几秒"属于**行为延时**，
///    不归样式管 —— 那是产品节奏，不是视觉节奏。
///  * **缓动曲线** 必须走 [PokoCurves]。
///  * **卡片圆角** 必须走 [PokoRadius]。小于 8 的"微圆角"（发丝线、进度条
///    轨道）以及个别异形圆角属于例外。
///  * **色值** 只要 [PokoPalette] 里有对应项，就必须用令牌。
///  * **可点击元素** 必须有按下反馈 —— 裸 `GestureDetector(onTap:)` 点了像没点。
///
/// 角色美术（`lib/renderers/`）是波可本体的配色，属于"画面内容"而非
/// "界面装饰"，整目录豁免。
/// ============================================================================

/// 展示级字号白名单 —— emoji / 超大数字，不是文本层级。
const Set<String> kDisplayFontSizes = {'34', '40', '44', '46', '48'};

/// 微圆角白名单 —— 发丝线、进度条轨道、极小胶囊。
const Set<String> kMicroRadii = {'1', '1.5', '2', '3', '4', '5', '6'};

/// 异形圆角白名单 —— 个别家具/窗框的自定义造型。
const Set<String> kBespokeRadii = {'39', '43'};

/// 扫描范围：UI 代码。角色美术与令牌定义本身豁免。
const List<String> kSkippedDirs = ['renderers', 'theme'];

/// PokoDuration 覆盖的全部毫秒值 —— 这些时长"已经有令牌"，就必须用令牌。
const Set<int> kTokenizedDurations = {
  80, 110, 120, 140, 160, 180, 200, 220, 240, 260, 280, 320, 420, 600, 700,
};

/// 扫出源码里所有 `GestureDetector(...)` 的**括号配平**参数体。
///
/// 不能用正则 —— `onTap: () => foo(...)` 里的右括号会让正则提前截断，
/// 把"带拖拽的手势"误判成"只有点击"。
List<({int line, String body, String args})> findGestureDetectors(String source) {
  final out = <({int line, String body, String args})>[];
  var index = 0;
  while (true) {
    final start = source.indexOf('GestureDetector(', index);
    if (start < 0) break;
    final open = source.indexOf('(', start);
    var depth = 0;
    var p = open;
    String? quote;
    var escaped = false;
    for (; p < source.length; p++) {
      final ch = source[p];
      if (quote != null) {
        if (escaped) {
          escaped = false;
        } else if (ch == r'\') {
          escaped = true;
        } else if (ch == quote) {
          quote = null;
        }
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
      } else if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    final args = source.substring(open + 1, p);
    final line = source.substring(0, start).split('\n').length;
    out.add((line: line, body: source.substring(start, p + 1), args: args));
    index = p + 1;
  }
  return out;
}

void main() {
  final libDir = Directory('lib');
  final themeSource = File('lib/theme/poko_theme.dart').readAsStringSync();

  // 从令牌定义里解析出"哪些色值已经有令牌了"
  final paletteValues = <String, String>{
    for (final m in RegExp(r'static const Color (\w+) = Color\((0xFF[0-9A-Fa-f]{6})\);')
        .allMatches(themeSource))
      m.group(2)!: m.group(1)!,
  };

  /// 收集所有参与体检的 Dart 文件（排除豁免目录）
  List<File> uiFiles() {
    final out = <File>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path
          .substring('lib${Platform.pathSeparator}'.length)
          .replaceAll('\\', '/');
      if (kSkippedDirs.any((d) => relative.startsWith('$d/'))) continue;
      out.add(entity);
    }
    return out;
  }

  group('设计系统守卫', () {
    test('字号必须来自 PokoFont（或展示级白名单）', () {
      final violations = <String>[];
      for (final file in uiFiles()) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          for (final m in RegExp(r'fontSize:\s*([0-9]+(?:\.[0-9]+)?)').allMatches(line)) {
            final raw = m.group(1)!;
            if (kDisplayFontSizes.contains(raw)) continue;
            violations.add('${file.path}:${i + 1}  fontSize: $raw');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '字号必须用 PokoFont 令牌。半档字号（8.5 / 9.5 / 11.5 …）在小屏上'
            '会因字体回退渲染成不同实际字号，是"忽大忽小"的元凶：\n'
            '${violations.join('\n')}',
      );
    });

    test('样式转场时长必须来自 PokoDuration', () {
      final violations = <String>[];
      for (final file in uiFiles()) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!line.contains('duration:')) continue;
          // 只管"已经有令牌"的毫秒时长；
          // 气泡停留 4 秒、抽卡结算延迟 450ms 这类属于产品节奏，不归样式管。
          for (final m in RegExp(
            r'duration:\s*(?:const\s+)?Duration\(milliseconds:\s*(\d+)\)',
          ).allMatches(line)) {
            final ms = int.parse(m.group(1)!);
            if (!kTokenizedDurations.contains(ms)) continue;
            violations.add('${file.path}:${i + 1}  ${m.group(0)}');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '样式转场时长必须用 PokoDuration 令牌：\n${violations.join('\n')}',
      );
    });

    test('缓动曲线必须来自 PokoCurves', () {
      final violations = <String>[];
      for (final file in uiFiles()) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // PokoCurves.standard 也会匹配 Curves.，所以要排除带前缀的
          for (final m in RegExp(r'(?<![\w.])Curves\.(\w+)').allMatches(line)) {
            violations.add('${file.path}:${i + 1}  Curves.${m.group(1)}');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '缓动曲线必须用 PokoCurves 令牌：\n${violations.join('\n')}',
      );
    });

    test('卡片圆角必须来自 PokoRadius', () {
      final violations = <String>[];
      for (final file in uiFiles()) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          for (final m in RegExp(
            r'(?:BorderRadius|Radius)\.circular\((\d+(?:\.\d+)?)\)',
          ).allMatches(line)) {
            final raw = m.group(1)!;
            if (kMicroRadii.contains(raw) || kBespokeRadii.contains(raw)) continue;
            violations.add('${file.path}:${i + 1}  circular($raw)');
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '卡片/面板/药丸的圆角只允许 8 / 12 / 16 / 20 / 28 / pill 六档：\n'
            '${violations.join('\n')}',
      );
    });

    test('已有令牌对应的色值不得再写裸 hex', () {
      final violations = <String>[];
      for (final file in uiFiles()) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          for (final m in RegExp(
            r'(?:const\s+)?Color\((0xFF[0-9A-Fa-f]{6})\)',
          ).allMatches(line)) {
            final raw = m.group(1)!;
            if (!paletteValues.containsKey(raw)) continue;
            violations.add(
              '${file.path}:${i + 1}  $raw  → PokoPalette.${paletteValues[raw]}',
            );
          }
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '色值必须走 PokoPalette 令牌（同一个灰阶之前散落了 28 次裸 hex）：\n'
            '${violations.join('\n')}',
      );
    });

    test('令牌刻度本身不得再出现半档 / 越界值', () {
      // PokoFont 的每一档都必须是整数
      final fontBlock = RegExp(
        r'class PokoFont \{.*?\n\}',
        dotAll: true,
      ).firstMatch(themeSource)!.group(0)!;
      final halfSteps = RegExp(r'=\s*(\d+\.\d+)\s*;')
          .allMatches(fontBlock)
          .map((m) => m.group(1))
          .toList();
      expect(
        halfSteps,
        isEmpty,
        reason: '字阶不允许半档：$halfSteps',
      );

      // PokoRadius 只允许 8 / 12 / 16 / 20 / 28 / 999
      final radiusBlock = RegExp(
        r'class PokoRadius \{.*?\n\}',
        dotAll: true,
      ).firstMatch(themeSource)!.group(0)!;
      final radii = RegExp(r'=\s*(\d+)\s*;')
          .allMatches(radiusBlock)
          .map((m) => m.group(1)!)
          .toSet();
      expect(
        radii.difference({'8', '12', '16', '20', '28', '999'}),
        isEmpty,
        reason: 'PokoRadius 只允许 8 / 12 / 16 / 20 / 28 / 999，实际 $radii',
      );
    });

    test('可点击元素必须给出按下反馈', () {
      final violations = <String>[];
      for (final file in uiFiles()) {
        final source = file.readAsStringSync();
        for (final gd in findGestureDetectors(source)) {
          final args = gd.args;
          if (!args.contains('onTap:')) continue;
          // 已经有别的手势（拖拽 / 长按 / 缩放）→ 靠 PokoPressScale 补手感
          // 注意 onVerticalDragStart 这类名字中间夹了词，得用 \w* 兜住
          if (RegExp(r'on\w*(Pan|Drag|Scale|LongPress|TapDown|TapUp|TapCancel)\w*:')
              .hasMatch(args)) {
            continue;
          }
          // 没有 child 的 GestureDetector 是"不可见热区"（空白画布收起、
          // 贴边探头区），没有可缩放的视觉，不要求按压反馈。
          if (!RegExp(r'\bchild:').hasMatch(args)) continue;
          violations.add('${file.path}:${gd.line}');
        }
      }
      expect(
        violations,
        isEmpty,
        reason: '裸 GestureDetector(onTap) 没有任何按下反馈，用户点了像没点：\n'
            '${violations.join('\n')}',
      );
    });

    test('两端色板必须完全一致（与桌面端 pet/theme.py 对齐）', () {
      // 只在能读到桌面端源码时校验（例如只检出 flutter_pet 子目录时跳过）。
      final pythonTheme = File('../pet/theme.py');
      if (!pythonTheme.existsSync()) return;

      final pythonPalette = <String, String>{
        for (final m in RegExp(
          r'^    ([a-z_0-9]+)\s*=\s*"(#[0-9A-Fa-f]{6})"\s*$',
          multiLine: true,
        ).allMatches(pythonTheme.readAsStringSync()))
          m.group(1)!: m.group(2)!.toUpperCase(),
      };

      final flutterPalette = <String, String>{
        for (final m in RegExp(
          r'static const Color (\w+) = Color\((0xFF[0-9A-Fa-f]{6})\);',
        ).allMatches(themeSource))
          m.group(1)!: '#${m.group(2)!.substring(4).toUpperCase()}',
      };

      expect(
        flutterPalette.keys.toSet().difference(pythonPalette.keys.toSet()),
        isEmpty,
        reason: 'Flutter 端多出来的令牌，桌面端没有同名项 —— '
            '改一次配色只会改到一半：\n'
            '${flutterPalette.keys.toSet().difference(pythonPalette.keys.toSet())}',
      );
      expect(
        pythonPalette.keys.toSet().difference(flutterPalette.keys.toSet()),
        isEmpty,
        reason: '桌面端多出来的令牌，Flutter 端没有同名项：\n'
            '${pythonPalette.keys.toSet().difference(flutterPalette.keys.toSet())}',
      );
      for (final entry in flutterPalette.entries) {
        expect(
          pythonPalette[entry.key],
          entry.value,
          reason: '两端同名令牌 ${entry.key} 色值分叉了',
        );
      }
    });
  });
}
