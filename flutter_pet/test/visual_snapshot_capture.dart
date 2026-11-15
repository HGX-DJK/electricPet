// 视觉快照夹具（工具型测试，非回归用例）
//
// 用途：把若干代表性 UI 表面渲染成 PNG，供「改动前 / 改动后」逐字节比对。
// Flutter 仓库目前没有 golden 基线，做样式收敛时没有像素兜底，
// 这个夹具就是第三轮样式改动的那张安全网。
//
// 用法：
//   set SNAP_DIR=<输出目录>
//   flutter test test/visual_snapshot_capture.dart
//
// 文件名刻意不以 _test.dart 结尾 —— `flutter test` 全量跑时不会带上它。

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_pet/models/memo_model.dart';
import 'package:flutter_pet/models/pet_model.dart';
import 'package:flutter_pet/services/solar_service.dart';
import 'package:flutter_pet/theme/poko_theme.dart';
import 'package:flutter_pet/views/backpack_drawer.dart';
import 'package:flutter_pet/views/dialogs/action_dialog.dart';
import 'package:flutter_pet/views/dialogs/feeding_dialog.dart';
import 'package:flutter_pet/views/dialogs/gacha_dialog.dart';
import 'package:flutter_pet/views/dialogs/heritage_backup_dialog.dart';
import 'package:flutter_pet/views/dialogs/memory_album_dialog.dart';
import 'package:flutter_pet/views/dialogs/wardrobe_dialog.dart';
import 'package:flutter_pet/views/docks/live_feeding_dock.dart';
import 'package:flutter_pet/views/docks/live_wardrobe_dock.dart';
import 'package:flutter_pet/views/docks/top_dual_islands.dart';
import 'package:flutter_pet/views/memo_screen.dart';

const String kSnapFontPath = r'C:\Windows\Fonts\simhei.ttf';

late Directory outDir;

Future<void> _loadFont() async {
  try {
    final bytes = File(kSnapFontPath).readAsBytesSync();
    final loader = FontLoader('SnapSans')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  } catch (_) {
    // 拿不到字体就退回 Flutter 测试默认字体（字形渲染成方块），不影响像素比对
  }
}

Future<void> _capture(
  WidgetTester tester,
  String name,
  Widget child, {
  Size size = const Size(430, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'SnapSans'),
      home: Scaffold(
        backgroundColor: PokoTokens.day.canvas,
        // 必须垫一层 Stack —— 滑轨坞等控件内部用了 Positioned，
        // 直接挂在 RepaintBoundary 下会抛 ParentDataWidget 断言。
        body: RepaintBoundary(
          key: key,
          child: Stack(fit: StackFit.expand, children: [child]),
        ),
      ),
    ),
  );
  // 不使用 pumpAndSettle —— 部分控件带无限循环动画，会直接把测试卡死。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pump(const Duration(milliseconds: 400));

  // ⚠️ toImage / toByteData 必须放进 tester.runAsync ——
  // 假时钟环境下引擎不会真正出帧，直接 await 会永远挂起。
  // Flutter 自己的 matchesGoldenFile 也是这么绕的。
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('PNG 编码失败：$name');
    }
    File('${outDir.path}/$name.png').writeAsBytesSync(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  });
}

void main() {
  final dirPath = Platform.environment['SNAP_DIR'];
  if (dirPath == null || dirPath.isEmpty) {
    throw StateError('必须设置 SNAP_DIR 环境变量，指定 PNG 输出目录');
  }
  outDir = Directory(dirPath)..createSync(recursive: true);

  setUpAll(_loadFont);

  testWidgets('主题组件', (tester) async {
    for (final night in [false, true]) {
      final tag = night ? 'night' : 'day';
      await _capture(
        tester,
        'theme_components_$tag',
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PokoGlassCard(
                isNight: night,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('面板标题', style: PokoText.title(PokoTokens.of(night))),
                    const SizedBox(height: 6),
                    Text('正文说明文字，用于检查字阶与行高。', style: PokoText.body(PokoTokens.of(night))),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        PokoChip(label: '状态胶囊', isNight: night),
                        const SizedBox(width: 8),
                        PokoChip(
                          label: '强调',
                          isNight: night,
                          color: PokoPalette.rose_500,
                          solid: true,
                          icon: Icons.star_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PokoSheetShell(
                isNight: night,
                heightFactor: 0.3,
                child: Padding(
                  padding: const EdgeInsets.all(PokoSpacing.lg),
                  child: Text('底部弹层外壳', style: PokoText.body(PokoTokens.of(night))),
                ),
              ),
            ],
          ),
        ),
      );
    }
  });

  testWidgets('顶栏双岛', (tester) async {
    final model = PetModel();
    for (final night in [false, true]) {
      await _capture(
        tester,
        'top_dual_islands_${night ? 'night' : 'day'}',
        TopDualIslands(
          petModel: model,
          screenSize: const Size(430, 900),
          isNight: night,
          circadianTheme: SolarService.getSkyTheme(manualMode: night ? 3 : 1),
          isManualSky: true,
          onIntimacyTap: () {},
          onSoundToggle: () {},
          onFootprintsToggle: () {},
          onSkyRhythmToggle: () {},
        ),
        size: const Size(430, 220),
      );
    }
  });

  testWidgets('投喂滑轨坞', (tester) async {
    final foods = <Map<String, dynamic>>[
      {'id': 'dried_fish', 'name': '小鱼干', 'icon': '🐟', 'hunger': 12, 'intimacy_gain': 3},
      {'id': 'milk', 'name': '温热奶粉', 'icon': '🍼', 'hunger': 20, 'intimacy_gain': 5},
      {'id': 'cake', 'name': '草莓蛋糕', 'icon': '🍰', 'hunger': 8, 'intimacy_gain': 2},
    ];
    for (final night in [false, true]) {
      await _capture(
        tester,
        'live_feeding_dock_${night ? 'night' : 'day'}',
        LiveFeedingDock(
          isNight: night,
          foodMenu: foods,
          currentHunger: 62,
          onFoodTap: (_, __, ___, ____, _____) {},
          onFoodPanStart: (_, __, ___, ____) {},
          onFoodPanUpdate: (_) {},
          onFoodPanEnd: (_, __) {},
          onClose: () {},
        ),
        size: const Size(430, 360),
      );
    }
  });

  testWidgets('衣橱滑轨坞', (tester) async {
    final model = PetModel();
    for (final night in [false, true]) {
      await _capture(
        tester,
        'live_wardrobe_dock_${night ? 'night' : 'day'}',
        LiveWardrobeDock(
          petModel: model,
          isNight: night,
          wardrobeTab: 0,
          onTabChanged: (_) {},
          onSkinSelected: (_) {},
          onDecorationSelected: (_, __) {},
          onHabitatSelected: (_, __) {},
          onGachaTap: () {},
          onClose: () {},
        ),
        size: const Size(430, 520),
      );
    }
  });

  testWidgets('背包抽屉', (tester) async {
    final model = PetModel();
    for (final night in [false, true]) {
      await _capture(
        tester,
        'backpack_drawer_${night ? 'night' : 'day'}',
        PokoBackpackDrawer(
          model: model,
          isNight: night,
          memoCount: 3,
          onFeedTap: () {},
          onLaserTap: () {},
          onTeaseTap: () {},
          onMemoTap: () {},
          onBathTap: () {},
          onSleepTap: () {},
          onToggleFloating: () {},
        ),
        size: const Size(430, 760),
      );
    }
  });

  testWidgets('扭蛋面板', (tester) async {
    final model = PetModel();
    model.coins = 500;
    await _capture(
      tester,
      'gacha_dialog',
      GachaDialog(model: model, onUpdated: () {}),
    );
  });

  testWidgets('衣橱面板', (tester) async {
    final model = PetModel();
    await _capture(
      tester,
      'wardrobe_dialog',
      WardrobeDialog(model: model),
    );
  });

  testWidgets('记忆相册', (tester) async {
    final model = PetModel();
    await _capture(
      tester,
      'memory_album_dialog',
      MemoryAlbumDialog(model: model),
    );
  });

  testWidgets('喂食面板', (tester) async {
    final model = PetModel();
    await _capture(
      tester,
      'feeding_dialog',
      FeedingDialog(model: model, onFeedSelected: (_) {}),
    );
  });

  testWidgets('才艺面板', (tester) async {
    await _capture(
      tester,
      'action_dialog',
      ActionDialog(onActionSelected: (_) {}),
    );
  });

  testWidgets('历史档案继承', (tester) async {
    await _capture(
      tester,
      'heritage_backup_dialog',
      HeritageBackupDialog(
        backupData: const {
          'level': 7,
          'coins': 888,
          'items': {'a': 1},
          'created_at': '2026-01-01',
        },
        onInherit: () {},
        onDecline: () {},
        currentLevel: 3,
        currentCoins: 120,
        currentItemCount: 4,
      ),
    );
  });

  testWidgets('便签页', (tester) async {
    final memo = MemoModel();
    memo.content = '今天也要好好吃饭呀～\n记得给波可买小鱼干 🐟';
    await _capture(
      tester,
      'memo_screen',
      MemoScreen(memoModel: memo),
    );
  });
}
