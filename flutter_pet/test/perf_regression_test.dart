import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 「性能守护」测试：锁住已经做过的几处性能优化，防止后续重构悄悄把它们改回去。
///
/// 背景：这些优化解决的都是「看不出来但很贵」的问题 ——
///   * 主界面 build() 有 1400+ 行组件树，早先每 24ms（≈41fps）就整树 setState 一次，
///     等于每秒重建 40 次整棵树；
///   * 太阳天文学位置（NOAA 三角函数）在同一频率下被反复重算；
///   * 测试里 widget 测试会把「语音预热」真的打出去，flutter_test 拦截后
///     统一返回 400，刷一屏无意义日志。
///
/// 这些都不是靠肉眼能发现的回归，所以用源码审计的方式钉死（与本仓库
/// pet_appearance_test.dart / floating_overlay_native_test.dart 的既有风格一致）。
void main() {
  late String petScreenSource;
  late String solarSource;
  late String minimaxSource;

  setUpAll(() {
    final root = _findPackageRoot();
    petScreenSource = _read(root, 'lib/views/pet_screen.dart');
    solarSource = _read(root, 'lib/services/solar_service.dart');
    minimaxSource = _read(root, 'lib/services/minimax_service.dart');
  });

  group('高频运动帧不得重建整棵组件树', () {
    test('运动信号必须由独立的 ValueNotifier 承载，而不是靠整树 setState', () {
      expect(petScreenSource, contains('final ValueNotifier<int> _motionTick'),
          reason: '必须存在专用的运动信号 notifier');
      expect(petScreenSource, contains('_motionTick.dispose()'),
          reason: 'notifier 必须在 dispose() 里释放，否则每次进主界面都会泄漏一个');
    });

    test('物理/粒子定时器在「结构态未变」时只能走局部刷新', () {
      final body = _functionBody(petScreenSource, 'void _startParticleTimer()');
      expect(body, isNotEmpty, reason: '解析不到 _startParticleTimer 函数体');

      expect(body, contains('_motionTick.value++'),
          reason: '纯运动帧必须走 _motionTick 局部刷新，不能整树 setState');
      expect(body, contains('_structuralSnapshot()'),
          reason: '必须先比对结构态快照，才能判断「只是动了一下」');
      expect(body, contains('setState(() {})'),
          reason: '结构态变化时仍要保留整树重建，行为不能退化');
    });

    test('结构态快照必须覆盖所有会改变组件树结构的字段', () {
      final body = _functionBody(petScreenSource, '_structuralSnapshot() {');
      expect(body, isNotEmpty, reason: '解析不到 _structuralSnapshot 函数体');

      for (final field in [
        '_state', // 状态机切换（决定毛线球是否隐藏等）
        '_isYarnFlying', // 毛线球飞行态
        '_isChasingYarn', // 追逐态
        '_isLaserMode', // 激光笔整层增删
        '_fishPopping', // 小鱼图层增删
        '_laserPos', // 激光点图层增删
        '_footprints', // 脚印图层增删
        '_particles', // 粒子图层增删
        '_petCombo', // 连击徽章增删
      ]) {
        expect(body, contains(field),
            reason: '结构态快照漏了 $field —— 该字段变化时图层会增删，'
                '只走局部刷新会导致 UI 不更新');
      }
    });

    test('所有会随运动变化的图层都必须由 _motionTick 驱动', () {
      // 萌宠本体 / 毛线球 / 连击徽章 / 粒子层 / 脚印层 / 小鱼 / 激光点
      final motionDriven = RegExp(
        r'ValueListenableBuilder<int>\(\s*valueListenable:\s*_motionTick',
      );
      final count = motionDriven.allMatches(petScreenSource).length;
      expect(count, greaterThanOrEqualTo(7),
          reason: '至少要有 7 处（萌宠/毛线球/连击/粒子/脚印/小鱼/激光点）'
              '改由 _motionTick 驱动；当前只有 $count 处');

      // 这些位置绝不能再直接读运动字段（必须经过 builder 闭包）
      for (final pattern in [
        r'left:\s*_petX\s*-\s*100', // 萌宠
        r'left:\s*_yarnX\s*-\s*22', // 毛线球
        r'left:\s*_petX\s*-\s*60', // 连击徽章
        r'left:\s*_laserPos!\.dx', // 激光点
      ]) {
        expect(RegExp(pattern).hasMatch(petScreenSource), isTrue,
            reason: '应能找到 $pattern 对应的运动节点');
      }
    });
  });

  group('太阳天文学位置不得每帧重算', () {
    test('getSkyTheme 必须走缓存，并按「日 / 分钟」两级缓存', () {
      final body = _functionBody(solarSource, 'static SkyTheme getSkyTheme(');
      expect(body, isNotEmpty, reason: '解析不到 getSkyTheme 函数体');
      expect(body, contains('_cachedSolarTimes'),
          reason: '日升日落只依赖年内第几天，必须按日缓存');
      expect(body, contains('_themeCache'),
          reason: '天空主题必须按分钟缓存，否则每帧都要重跑渐变插值');
    });

    test('缓存必须提供显式失效入口（手动切换光影模式时用得上）', () {
      expect(solarSource, contains('static void invalidateCache()'),
          reason: '需要给「手动切换光影模式」这类显式失效场景留口子');
    });

    test('太阳时刻只依赖年内第几天 —— 缓存按 doy 索引是无损的', () {
      final body = _functionBody(solarSource, 'static SolarTimes calculateSolarTimes(');
      expect(body, isNotEmpty);
      expect(body, contains('dayOfYear(date)'),
          reason: 'calculateSolarTimes 只能依赖 dayOfYear，否则按日缓存就会算错');
    });
  });

  group('测试环境不得发起真实语音网络请求', () {
    test('必须提供关闭语音网络的开关，且在真正发请求前短路', () {
      expect(minimaxSource, contains('static bool networkEnabled'),
          reason: '需要给测试一个关闭语音网络请求的开关');
      final body = _functionBody(minimaxSource, 'Future<Uint8List?> synthesizeVoice(');
      expect(body, isNotEmpty, reason: '解析不到 synthesizeVoice 函数体');
      expect(body, contains('if (!networkEnabled) return null;'),
          reason: '必须在发请求之前短路，否则 flutter_test 会刷一屏 400 噪音日志');
    });

    test('预热循环也必须尊重该开关', () {
      final body = _functionBody(minimaxSource, 'Future<void> prewarmCommonVoices()');
      expect(body, isNotEmpty);
      expect(body, contains('if (!networkEnabled) return;'),
          reason: '预热是 5 条请求的循环，必须整体短路');
    });
  });
}

/// 定位 Flutter 包根目录（向上查找 pubspec.yaml）
Directory _findPackageRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('未找到 Flutter 包根目录 (pubspec.yaml)');
    }
    dir = parent;
  }
}

String _read(Directory root, String relativePath) {
  final file = File('${root.path}${Platform.pathSeparator}$relativePath');
  if (!file.existsSync()) {
    fail('未找到仓库文件: $relativePath');
  }
  return file.readAsStringSync();
}

/// 截取以 [marker] 开头的那一对花括号内的内容（按括号配平查找）
///
/// 注意：必须先跳过**参数列表**再找函数体的大括号。
/// 例如 `foo(int a, {double b = 1}) { ... }` 的第一个 `{` 属于具名参数组，
/// 直接拿它当函数体起点会截出错误的内容。
String _functionBody(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) return '';

  var i = start + marker.length;

  // marker 已直接指向函数体的大括号（如 `foo() {`），从它开始配平即可
  if (marker.endsWith('{')) {
    return _balancedBody(source, i - 1);
  }

  // marker 若已包含参数列表（如 `foo()`），就不用再配平圆括号；
  // 否则先配平，跳过具名参数组。
  if (!marker.endsWith(')')) {
    var paren = 1;
    while (i < source.length && paren > 0) {
      final ch = source[i];
      if (ch == '(') {
        paren++;
      } else if (ch == ')') {
        paren--;
      }
      i++;
    }
    if (paren > 0) return '';
  }

  // 再跳过空白与 async 等修饰，找到函数体的 '{'
  while (i < source.length && source[i] != '{') {
    if (source[i] == ';') return ''; // 声明而非定义
    i++;
  }
  if (i >= source.length) return '';

  return _balancedBody(source, i);
}

/// 从 [open]（指向 '{'）开始，按括号配平截出函数体内容
String _balancedBody(String source, int open) {
  var depth = 0;
  for (var j = open; j < source.length; j++) {
    final ch = source[j];
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, j);
    }
  }
  return '';
}
