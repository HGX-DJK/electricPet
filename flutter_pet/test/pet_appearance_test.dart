import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 波可外观守护测试：朝向（尾巴位置）与时光纪念相册。
///
/// 背景一（朝向）：用户反馈"和猫草、磨爪交互的时候为啥是屁股对着的"。
/// 波可是**正面朝向**的，整只猫里唯一能表达"朝哪边"的就是**尾巴的位置** ——
/// 尾巴在哪边，就读成"屁股朝哪边"。以前尾巴和朝向画在**同一侧**，
/// 于是去啃左边的猫草、去磨右边的猫抓柱时，尾巴正好压在那件家具上，
/// 看起来就是"屁股对着家具"。现在尾巴永远拖在**身后**（与朝向相反的一侧）。
///
/// 背景二（相册）：「波可的时光纪念相册」以前是五张写死的假卡片、编好的日期，
/// 「拍下一张今日纪念照」按钮只播音效什么也不存 —— 毫无实际意义。
/// 现在相册必须来自 `PetModel.memories`（真实里程碑 + 真拍照），并且落盘。
void main() {
  late String painterSource;
  late String petScreenSource;
  late String petViewSource;
  late String memoryDialogSource;

  setUpAll(() {
    final root = _findPackageRoot();
    painterSource = _read(root, 'lib/renderers/pet_painter.dart');
    petScreenSource = _read(root, 'lib/views/pet_screen.dart');
    petViewSource = _read(
      root,
      'android/app/src/main/kotlin/com/electricpet/poko/PokoPetView.kt',
    );
    memoryDialogSource = _read(root, 'lib/views/dialogs/memory_album_dialog.dart');
  });

  group('朝向：尾巴必须永远拖在身后', () {
    test('App 内渲染器：尾巴必须做局部水平镜像', () {
      final body = _functionBody(painterSource, 'void _drawTail(');
      expect(body, isNotEmpty, reason: '解析不到 _drawTail 函数体');

      expect(body, contains('canvas.scale(-1, 1)'),
          reason: '尾巴必须局部水平镜像，才能永远待在"身后"（与朝向相反的一侧）；'
              '少了这一步，猫去啃猫草/磨猫抓柱时尾巴正好压在家具上，'
              '看起来就是"屁股对着家具"');
      expect(body, contains('canvas.save()'),
          reason: '局部镜像前必须 save，避免影响后续绘制');
      expect(body, contains('canvas.restore()'),
          reason: '局部镜像后必须 restore');
    });

    test('App 内尾巴触摸区必须跟着朝向换边', () {
      // 朝右时尾巴在左（dx 8~65），朝左时尾巴在右（dx 135~192）
      final m = RegExp(
        r'!_facingLeft\s*&&\s*localPos\.dx\s*>=\s*(\d+)[\s\S]{0,120}?'
        r'_facingLeft\s*&&\s*localPos\.dx\s*>=\s*(\d+)',
      ).firstMatch(petScreenSource);
      expect(m, isNotNull, reason: '找不到尾巴触摸区判定逻辑');

      final notFacingLeftX = int.parse(m!.group(1)!);
      final facingLeftX = int.parse(m.group(2)!);
      expect(notFacingLeftX, lessThan(facingLeftX),
          reason: '朝右时尾巴在左、朝左时尾巴在右，触摸区必须跟着换边，'
              '否则"摸左边"会变成摸尾巴、"摸右边"摸不到尾巴');
    });

    test('桌面悬浮猫：尾巴同样必须局部镜像', () {
      final body = _functionBody(petViewSource, 'private fun drawTail(');
      expect(body, isNotEmpty, reason: '解析不到 drawTail 函数体');
      expect(body, contains('canvas.scale(-1f, 1f, cx, cy)'),
          reason: '桌面悬浮猫的尾巴也必须拖在身后，和 App 内保持一致');
      expect(body, contains('canvas.save()'), reason: '镜像前必须 save');
      expect(body, contains('canvas.restore()'), reason: '镜像后必须 restore');
    });

    test('桌面悬浮猫：尾巴命中判定必须跟着换边', () {
      expect(
        RegExp(r'val tailX\s*=\s*cx\s*-\s*13f\s*\*\s*density').hasMatch(petViewSource),
        isTrue,
        reason: '尾巴拖在身后后，命中点必须跟着换到另一侧，'
            '否则"看到的是尾巴、摸到的却是身体"',
      );
    });
  });

  group('时光纪念相册：必须是真实记录', () {
    test('相册数据必须来自模型，不能再是写死的假卡片', () {
      expect(memoryDialogSource, contains('widget.model.memories'),
          reason: '相册必须读取 PetModel.memories 里的真实纪念');
      for (final fake in const <String>[
        '初遇初雪那天',
        '美食打卡',
        '活力瞬间',
        '成长解压',
        '治愈甜梦',
      ]) {
        expect(memoryDialogSource, isNot(contains(fake)),
            reason: '还残留着写死的假卡片「$fake」—— 相册必须展示真实发生过的纪念');
      }
    });

    test('拍照必须真的存进相册', () {
      expect(memoryDialogSource, contains('takeSnapshot()'),
          reason: '快门按钮必须调用 takeSnapshot()，把这一刻真的存进相册');
      expect(memoryDialogSource, contains('isSnapshot'),
          reason: '用户拍的照片要与系统里程碑区分开');
    });
  });

  group('面对家具：猫必须真的转过去对着猫草 / 猫抓柱', () {
    test('渲染器必须支持探身参数，并让头往朝向前方偏', () {
      expect(painterSource, contains('final double focusLean'),
          reason: '渲染器必须有 focusLean 参数，用来表达"探身面对家具"');
      expect(painterSource, contains('this.focusLean = 0.0'),
          reason: 'focusLean 默认必须是 0（不探身），保持待机姿态不变');

      final head = _bodyAfterSignature(painterSource, 'void _drawHead(');
      expect(head, isNotEmpty, reason: '解析不到 _drawHead 函数体');
      expect(head, contains('focusLean'),
          reason: '画头时必须用 focusLean 让脑袋往朝向前方探过去，'
              '否则波可去啃猫草时依然是正面盯着主人，看不出在跟草互动');
      expect(head, contains('canvas.rotate'),
          reason: '探身必须伴随头部侧倾，只平移会显得脖子被拉长');
    });

    test('探身时视线必须锁定家具', () {
      expect(painterSource, contains('focusLean'),
          reason: '视线也要跟着探身走');
      expect(RegExp(r'gazeX\s*=\s*\(gazeX\s*\+\s*[\d.]+\s*\*\s*focusLean\)').hasMatch(painterSource),
          isTrue,
          reason: '探身时瞳孔必须朝目标方向偏移，'
              '否则猫虽然歪着头、眼睛却还盯着主人，"面对猫草"依然不成立');
    });

    test('啃草与磨爪都必须开启探身', () {
      expect(petScreenSource, contains('_setFocusLean(true)'),
          reason: '啃猫草 / 磨猫抓柱时必须开启探身');
      expect(petScreenSource, contains('_setFocusLean(false)'),
          reason: '互动结束后必须把探身收回来，否则会一直歪着头');
      expect(petScreenSource, contains('focusLean: _focusController.value'),
          reason: '探身强度必须传给渲染器');
    });

    test('家具必须画在猫之后（前景层），否则会被猫头整个盖住', () {
      final painterAt = petScreenSource.indexOf('PetPainter(');
      expect(painterAt, greaterThan(0), reason: '找不到猫的绘制位置');

      for (final furniture in const <String>['CatGrassPlanter(', 'CatScratchingPost(']) {
        final at = petScreenSource.indexOf(furniture);
        expect(at, greaterThan(0), reason: '找不到家具：$furniture');
        expect(at, greaterThan(painterAt),
            reason: '$furniture 必须画在猫之后（前景层）。'
                '波可脑袋宽约 93px、猫草只有 56px 宽，'
                '家具若在猫之前，猫头会把猫草整个盖住，玩家根本看不见猫在啃什么');
      }
    });

    test('猫的站位必须留出距离，不能又贴回家具身上', () {
      expect(petScreenSource, contains('const double _kPlantStandOffset = 50.0'),
          reason: '啃草站位距离必须保持 50px：贴太近猫草会被猫头盖死');
      expect(petScreenSource, contains('const double _kPostStandOffset = 78.0'),
          reason: '磨爪站位距离必须保持 78px：磨爪时猫趴着伸展，贴太近柱子会被盖死');
      expect(petScreenSource, contains('const double _kPlantTopOffset = 50.0'),
          reason: '猫草盆栽必须下沉到地板线 + 50，草叶才落在猫的嘴边高度');
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
String _functionBody(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) return '';
  final open = source.indexOf('{', start);
  if (open < 0) return '';
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final ch = source[i];
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  return '';
}

/// 截取函数**签名之后**的那一对花括号内的内容。
///
/// 和 [_functionBody] 的区别：带具名参数的函数（如
/// `void _drawHead(Canvas c, SkinConfig s, {bool isBackView = false}) {`）
/// 的签名里就有 `{`，直接找"第一个 {"会取到参数列表而不是函数体。
String _bodyAfterSignature(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) return '';
  var i = source.indexOf('(', start);
  if (i < 0) return '';
  var depth = 0;
  for (; i < source.length; i++) {
    final ch = source[i];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
      if (depth == 0) break;
    }
  }
  final open = source.indexOf('{', i);
  if (open < 0) return '';
  depth = 0;
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
