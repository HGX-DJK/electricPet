import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pet/main.dart';
import 'package:flutter_pet/models/pet_model.dart';
import 'package:flutter_pet/services/sensor_service.dart';
import 'dart:io';
import 'package:flutter_pet/renderers/pet_painter.dart';
import 'package:flutter_pet/services/backup_service.dart';
import 'package:flutter_pet/views/dialogs/gacha_dialog.dart';
import 'package:flutter_pet/views/dialogs/heritage_backup_dialog.dart';
import 'package:flutter_pet/views/backpack_drawer.dart';
import 'package:flutter_pet/services/minimax_service.dart';
import 'package:flutter_pet/views/dialogs/ai_voice_chat_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
      (MethodCall methodCall) async => null,
    );
  });

  group('Mobile Pet 100% Alignment & Hardware Perceiving Tests', () {
    test('Personality Algorithm and Awakening Test', () {
      final pet = PetModel();
      expect(pet.personality, equals('BALANCED'));
      expect(pet.personalityInfo['badge'], contains('纯真'));

      // 喂食科技芯片与黑客冷萃 -> 累积科技属性
      pet.feed('cyber_chip');
      pet.feed('hacker_coffee');
      expect(pet.personalityStats['tech'], greaterThanOrEqualTo(7));

      // 累积满 15 点科技属性且领先 3 点以上 -> 觉醒极客黑客喵
      pet.personalityStats = {'tech': 16, 'sport': 2, 'lazy': 0};
      expect(pet.personality, equals('HACKER'));
      expect(pet.personalityInfo['name'], contains('极客黑客喵'));
      expect(pet.personalityInfo['exclusiveItem'], equals('hacker_viser'));

      // 累积满 15 点运动属性 -> 觉醒元气运动喵
      pet.personalityStats = {'tech': 0, 'sport': 16, 'lazy': 0};
      expect(pet.personality, equals('ATHLETE'));
      expect(pet.personalityInfo['name'], contains('元气运动喵'));
      expect(pet.personalityInfo['exclusiveItem'], equals('band_sport'));

      // 佛系大懒喵
      pet.personalityStats = {'tech': 0, 'sport': 2, 'lazy': 16};
      expect(pet.personality, equals('LAZY'));
      expect(pet.personalityInfo['name'], contains('佛系大懒喵'));
      expect(pet.personalityInfo['exclusiveItem'], equals('cushion_zen'));
    });

    test('5-Slot Wardrobe & Habitat DIY System Test', () {
      final pet = PetModel();
      expect(pet.decorations.keys, containsAll(['head', 'face', 'neck', 'back', 'hand']));

      pet.setDecoration('head', 'band_sport');
      pet.setDecoration('face', 'hacker_viser');
      pet.setDecoration('neck', 'royal_cape');
      pet.setDecoration('back', 'cape_cyber');
      pet.setDecoration('hand', 'keyboard_rgb');
      pet.setHabitat('neon_matrix');

      expect(pet.decorations['head'], equals('band_sport'));
      expect(pet.decorations['face'], equals('hacker_viser'));
      expect(pet.decorations['neck'], equals('royal_cape'));
      expect(pet.decorations['back'], equals('cape_cyber'));
      expect(pet.decorations['hand'], equals('keyboard_rgb'));
      expect(pet.habitat, equals('neon_matrix'));
    });

    test('Cyber Gacha Pod Mechanics and 10-Pull Pity Guarantee Test', () {
      final pet = PetModel();
      pet.coins = 500;

      // 单抽
      final singleDraw = pet.drawGacha(1);
      expect(singleDraw.length, equals(1));
      expect(pet.coins, equals(470));
      expect(pet.unlockedItems, contains(singleDraw.first['code']));

      final item = GachaItem.fromMap(singleDraw.first);
      expect(item.id, equals(singleDraw.first['code']));
      expect(item.slotName.isNotEmpty, isTrue);

      // 十连保底测试：至少出 1 个 SSR 或 UR
      final tenDraw = pet.drawGacha(10);
      expect(tenDraw.length, equals(10));
      expect(pet.coins, equals(200)); // 470 - 270 = 200

      final highRarityCount = tenDraw.where((x) => x['rarity'] == 'SSR' || x['rarity'] == 'UR').length;
      expect(highRarityCount, greaterThanOrEqualTo(1));
    });

    test('User Scale Offset and Clamping Test', () {
      final pet = PetModel();
      expect(pet.userScale, equals(1.0));

      pet.setUserScale(0.5); // 下界钳制
      expect(pet.userScale, equals(0.75));

      pet.setUserScale(2.0); // 上界钳制
      expect(pet.userScale, equals(1.45));

      pet.setUserScale(1.15);
      expect(pet.userScale, equals(1.15));
    });

    test('SensorService LifeCycle and Degradation Test', () {
      expect(SensorService.tiltX, equals(0.0));
      // 启动在测试环境下安全不抛异常，优雅降级
      SensorService.startListening();
      SensorService.stopListening();
      expect(SensorService.tiltX, equals(0.0));
      expect(SensorService.isRunning, isFalse);
    });

    test('All 10 Foods Feeding and Personality Integration Test', () {
      final pet = PetModel();
      expect(PetModel.foodMenu.length, equals(10));

      for (final food in PetModel.foodMenu) {
        final id = food['id'] as String;
        final oldFed = pet.totalFedCount;
        final ok = pet.feed(id);
        expect(ok, isTrue);
        expect(pet.totalFedCount, equals(oldFed + 1));
        expect(food['name'].toString().isNotEmpty, isTrue);
        expect(food['icon'].toString().isNotEmpty, isTrue);
        expect(food['personality'], isA<List>());
      }
    });

    test('Pet Full Satiety Refusal Mechanism and Hunger Clamping Test', () {
      final pet = PetModel();
      pet.hunger = 80.0;
      expect(pet.isFull, isFalse);

      // Normal feeding when hungry
      final ok1 = pet.feed('canned_fish', allowWhenFull: false);
      expect(ok1, isTrue);
      expect(pet.hunger, greaterThan(80.0));

      // Force pet to full
      pet.hunger = 100.0;
      expect(pet.isFull, isTrue);

      // Feeding when full with allowWhenFull: false must be rejected
      final oldFed = pet.totalFedCount;
      final ok2 = pet.feed('dried_fish', allowWhenFull: false);
      expect(ok2, isFalse);
      expect(pet.totalFedCount, equals(oldFed));

      // With allowWhenFull: true, feeding still succeeds for dev/testing
      final ok3 = pet.feed('dried_fish', allowWhenFull: true);
      expect(ok3, isTrue);
      expect(pet.totalFedCount, equals(oldFed + 1));
      expect(pet.hunger, equals(100.0));
    });

    test('Gacha Item Buff Description & All 4 Habitat DIY Switching Test', () {
      final pet = PetModel();
      pet.coins = 600;
      final draws = pet.drawGacha(10);
      expect(draws.length, equals(10));
      for (final d in draws) {
        final item = GachaItem.fromMap(d);
        expect(item.name.isNotEmpty, isTrue);
        expect(item.desc.isNotEmpty, isTrue);
      }

      // 验证 4 大小窝场景切换
      final habitats = ['neon_matrix', 'retro_arcade', 'summer_beach', 'zen_tatami', 'default'];
      for (final h in habitats) {
        pet.setHabitat(h);
        expect(pet.habitat, equals(h));
      }
    });

    testWidgets('Home 5-Pill Floating Dock and Wardrobe Two-Tier Zero-Scroll Interaction Test', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const DesktopElectricPetApp());
      await tester.pump(const Duration(milliseconds: 200));

      // 1. 验证底部三灵动黄金大胶囊与独立发光微动扭蛋机 FAB 就绪
      expect(find.text('奇妙背包'), findsOneWidget);
      expect(find.text('装扮小窝'), findsOneWidget);
      expect(find.text('专属绝活'), findsOneWidget);
      expect(find.byKey(const ValueKey('cyber_gacha_fab')), findsOneWidget);

      // 2. 点击「装扮小窝」：直达空间坞并一键切入「小窝全景」
      await tester.tap(find.text('装扮小窝'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byKey(const ValueKey('live_wardrobe_dock')), findsOneWidget);

      await tester.tap(find.text('小窝全景'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('夏日海滩'), findsOneWidget);
      // 验证小窝全景模式下彻底隐藏盲盒按钮，保持房间沉浸纯净
      expect(find.text('盲盒'), findsNothing);

      // 3. 在换装坞顶层一键无缝切至「猫咪装扮」
      await tester.tap(find.text('猫咪装扮'));
      await tester.pump(const Duration(milliseconds: 250));

      // 4. 验证猫咪 6 大装扮插槽同屏全览，背部与手持 100% 同屏呈现，彻底消灭横向滑动
      expect(find.text('🐱 品种'), findsOneWidget);
      expect(find.text('🎩 头部'), findsOneWidget);
      expect(find.text('👓 面部'), findsOneWidget);
      expect(find.text('🎀 颈部'), findsOneWidget);
      expect(find.text('🦸‍♂️ 背部'), findsOneWidget);
      expect(find.text('🪄 手持'), findsOneWidget);

      // 切换至背部
      await tester.tap(find.text('🦸‍♂️ 背部'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('赛博霓虹披风'), findsOneWidget);

      // 5. 点击换装坞右上角「盲盒」快捷入口
      await tester.tap(find.text('盲盒'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GachaDialog), findsOneWidget);

      // 6. 收起盲盒与换装坞
      Navigator.of(tester.element(find.byType(GachaDialog))).pop();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(GachaDialog), findsNothing);

      await tester.tap(find.text('完成'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('bottom_floating_bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('cyber_gacha_fab')), findsOneWidget);
    });

    testWidgets('Realistic Billowing Cape Physics & 3D Turtle Shell Backpack Render Test', (WidgetTester tester) async {
      final pet = PetModel();
      pet.setDecoration('back', 'shell_turtle');
      pet.setDecoration('neck', 'royal_cape');

      // 验证正面视角正常绘制
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(220, 220),
              painter: PetPainter(
                model: pet,
                animTime: 1.5,
                state: 'IDLE',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CustomPaint), findsWidgets);

      // 验证赛博披风在待机与快乐旋转(背身视角)下正常绘制
      pet.setDecoration('back', 'cape_cyber');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(220, 220),
              painter: PetPainter(
                model: pet,
                animTime: 2.0,
                state: 'HAPPY_SPIN',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CustomPaint), findsWidgets);

      // 验证龟壳在背身视角(3D浮雕六边形全壳)下正常绘制
      pet.setDecoration('back', 'shell_turtle');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(220, 220),
              painter: PetPainter(
                model: pet,
                animTime: 2.5,
                state: 'HAPPY_SPIN',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    test('BackupService Public Storage I/O, Save-Code Encryption & Restoration Test', () async {
      final tempDir = Directory.systemTemp.createTempSync('poko_test_backup_');
      BackupService.customBackupDir = tempDir.path;

      try {
        final pet = PetModel();
        pet.level = 8;
        pet.coins = 450;
        pet.name = '赛博波可';
        pet.setDecoration('back', 'shell_turtle');

        // 测试静默双写备份
        await pet.saveToDisk();

        final backupFile = File('${tempDir.path}/poko_backup.json');
        expect(backupFile.existsSync(), isTrue);

        // 测试历史备份检测
        final historical = await BackupService.checkHistoricalBackup();
        expect(historical, isNotNull);
        final petData = historical!['pet'] as Map<String, dynamic>;
        expect(petData['level'], equals(8));
        expect(petData['coins'], equals(450));
        expect(petData['name'], equals('赛博波可'));

        // 测试存档码加密导出与解密导入
        final saveCode = BackupService.exportSaveCode(petData);
        expect(saveCode, startsWith('POKO#v2#'));

        final importedData = BackupService.importSaveCode(saveCode);
        expect(importedData, isNotNull);
        expect(importedData!['level'], equals(8));
        expect(importedData['name'], equals('赛博波可'));

        // 测试一键恢复至新模型
        final newPet = PetModel();
        expect(newPet.level, equals(1));
        final restored = await BackupService.restoreFromHistoricalBackup(historical, newPet);
        expect(restored, isTrue);
        expect(newPet.level, equals(8));
        expect(newPet.coins, equals(450));
        expect(newPet.name, equals('赛博波可'));
        expect(newPet.decorations['back'], equals('shell_turtle'));
      } finally {
        BackupService.customBackupDir = null;
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('Heritage Backup Auto-Detection and Inheritance Widget Test', (WidgetTester tester) async {
      final mockBackup = {
        'version': 2,
        'format': 'POKO_PUBLIC_BACKUP',
        'savedAt': '2026-10-20T08:30:00Z',
        'pet': {
          'name': '波可大师',
          'skinId': 'cat_ragdoll',
          'level': 15,
          'coins': 520,
          'intimacy': 160,
          'unlockedItems': ['none', 'bell', 'ribbon', 'cat_calico', 'shell_turtle', 'cape_cyber'],
          'decorations': {'head': 'none', 'face': 'none', 'neck': 'bell', 'back': 'shell_turtle', 'hand': 'none'},
        },
      };

      bool didInherit = false;
      bool didDecline = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => HeritageBackupDialog(
                      backupData: mockBackup,
                      onInherit: () {
                        didInherit = true;
                      },
                      onDecline: () {
                        didDecline = true;
                      },
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      // 打开弹窗
      await tester.tap(find.text('Show Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const ValueKey('heritage_backup_dialog')), findsOneWidget);
      expect(find.text('🎉 发现历史波可档案！'), findsOneWidget);
      expect(find.text('波可大师'), findsOneWidget);
      expect(find.text('Lv. 15'), findsOneWidget);
      expect(find.text('520'), findsOneWidget);
      expect(find.text('6 件'), findsOneWidget);

      // 点击一键继承
      await tester.tap(find.byKey(const ValueKey('inherit_backup_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('heritage_backup_dialog')), findsNothing);
      expect(didInherit, isTrue);
      expect(didDecline, isFalse);
    });

    test('PetModel and MemoModel isReady Async Lifecycle and Value Evaluation Test', () async {
      final pet = PetModel();
      await pet.isReady;
      expect(pet.level, greaterThanOrEqualTo(1));

      // 验证 isBackupValuable 智能判定
      expect(BackupService.isBackupValuable({'pet': {'level': 1, 'unlockedItems': ['none'], 'coins': 200, 'skinId': 'cat_calico'}}), isFalse);
      expect(BackupService.isBackupValuable({'pet': {'level': 5}}), isTrue);
      expect(BackupService.isBackupValuable({'pet': {'level': 1, 'coins': 450}}), isTrue);
      expect(BackupService.isBackupValuable({'pet': {'level': 1, 'unlockedItems': ['none', '1', '2', '3', '4', '5', '6']}}), isTrue);
      expect(BackupService.isBackupValuable({'pet': {'level': 1, 'skinId': 'cat_ragdoll'}}), isTrue);
    });

    testWidgets('Backpack Drawer Heritage & Backup Toolbar Interaction Test', (WidgetTester tester) async {
      final pet = PetModel();
      bool didScan = false;
      bool didCopy = false;
      bool didPaste = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PokoBackpackDrawer(
              model: pet,
              isNight: false,
              memoCount: 1,
              onFeedTap: () {},
              onLaserTap: () {},
              onTeaseTap: () {},
              onMemoTap: () {},
              onBathTap: () {},
              onSleepTap: () {},
              onToggleFloating: () {},
              onScanBackupTap: () {
                didScan = true;
              },
              onCopySaveCodeTap: () {
                didCopy = true;
              },
              onPasteSaveCodeTap: () {
                didPaste = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('档案守护与防丢继承'), findsOneWidget);
      expect(find.text('扫描历史档案'), findsOneWidget);
      expect(find.text('复制存档口令'), findsOneWidget);
      expect(find.text('导入口令恢复'), findsOneWidget);

      await tester.ensureVisible(find.text('扫描历史档案'));
      await tester.tap(find.text('扫描历史档案'), warnIfMissed: false);
      await tester.pump();
      expect(didScan, isTrue);

      await tester.ensureVisible(find.text('复制存档口令'));
      await tester.tap(find.text('复制存档口令'), warnIfMissed: false);
      await tester.pump();
      expect(didCopy, isTrue);

      await tester.ensureVisible(find.text('导入口令恢复'));
      await tester.tap(find.text('导入口令恢复'), warnIfMissed: false);
      await tester.pump();
      expect(didPaste, isTrue);
    });

    testWidgets('Backpack Drawer Text Stays Fully Visible On Narrow Screens', (WidgetTester tester) async {
      // 背景：背包抽屉是 2 列宫格，卡片内还得让出 38px 图标块 + 8px 间距，
      // 副标题真正能用的宽度在 320dp 窄屏上只剩约 75px（≈ 7 个全角汉字）。
      // 文案一旦写长，免不掉被省略号切掉半个字 —— 这里逐档屏宽守住这条线。
      // 抽屉标题栏同理：胶囊们曾把标题挤成一条省略号，这里一并守住。
      const cardSubtitles = [
        '饱腹又涨好感',
        '红点逗猫飞扑',
        '抛球满地打滚',
        '香波洗香香',
        '呼噜甜甜梦乡',
        '生活备忘待办',
      ];
      const headerTexts = [
        '波可的奇妙背包',
        '日常照料与逗猫玩具',
      ];
      // 只守「无角标」卡片的标题：带 % 数字角标的卡片，测试字体里数字是 1em
      // （真机是 0.55em），拿测试环境当基准会误报。
      const badgeFreeTitles = [
        '抛毛线球',
        '伴眠哄睡',
      ];
      // 带角标的标题只有 360dp 以上才守：320dp 上 2 列宫格卡片的右半区只剩
      // ~32px，放不下「标题 + 角标」，真机同样会省略号截断，属该宽度的固有取舍。
      const badgeTitles = [
        '激光笔',
      ];

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final width in [320.0, 360.0, 390.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;

        final pet = PetModel();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PokoBackpackDrawer(
                model: pet,
                isNight: false,
                memoCount: 0,
                onFeedTap: () {},
                onLaserTap: () {},
                onTeaseTap: () {},
                onMemoTap: () {},
                onBathTap: () {},
                onSleepTap: () {},
                onToggleFloating: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final texts = <String>[
          ...headerTexts,
          ...badgeFreeTitles,
          ...cardSubtitles,
          if (width >= 360) ...badgeTitles,
        ];
        for (final text in texts) {
          final finder = find.text(text);
          expect(finder, findsOneWidget, reason: '${width}dp 屏上找不到「$text」');
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: '${width}dp 屏上「$text」被省略号截断了',
          );
        }
      }
    });

    testWidgets('Tuck-in Blanket Chip Always Stays Clear Of The Cat Body', (WidgetTester tester) async {
      // 背景：「盖被被」粉色胶囊徽标曾被钉死在 nestX + 48，而波可默认就趴在
      // 圆垫正中心（petX ≈ nestX），猫身半宽约 50px —— 徽标左缘直接切进猫身右缘，
      // 看上去就是「一枚粉色胶囊黏在猫身上」。现在徽标跟着猫的实际站位走。
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(const DesktopElectricPetApp());
      await tester.pump(const Duration(milliseconds: 400));

      final chip = find.byKey(const ValueKey('tuck_in_blanket_button'));
      expect(chip, findsOneWidget, reason: '波可趴在窝上时应当出现「盖被被」徽标');

      final petFinder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is PetPainter);
      expect(petFinder, findsOneWidget);

      final chipRect = tester.getRect(chip);
      final petRect = tester.getRect(petFinder);

      // 猫身半宽约 50px（200×200 画布内的实际绘制范围），徽标左缘至少要让开 60px
      expect(
        chipRect.left,
        greaterThanOrEqualTo(petRect.center.dx + 60),
        reason: '「盖被被」徽标压到波可身上了（猫心 x=${petRect.center.dx}，徽标左缘 x=${chipRect.left}）',
      );
      // 同时不能顶出屏幕右边界
      expect(chipRect.right, lessThanOrEqualTo(392));
    });

    test('MiniMax AI Service Configuration and Local Companion Engine Test', () async {
      final ai = MinimaxService();
      await ai.init();

      // 测试配置持久化
      await ai.updateConfig(
        apiKey: 'test_minimax_key',
        voiceId: 'child_female',
        pitch: 3,
        speed: 1.15,
      );

      expect(ai.apiKey, equals('test_minimax_key'));
      expect(ai.voiceId, equals('child_female'));
      expect(ai.pitch, equals(3));
      expect(ai.speed, equals(1.15));
      expect(ai.hasApiKey, isTrue);

      // 清除 Key 测试本地智能伴侣仿真引擎与意图识别
      await ai.updateConfig(apiKey: '');
      expect(ai.hasApiKey, isFalse);

      final feedResp = await ai.chatWithPoko('波可，快来吃香酥小鱼干和罐头！');
      expect(feedResp.isSimulated, isTrue);
      expect(feedResp.action, equals('FEED'));
      expect(feedResp.text, isNotEmpty);

      final sleepResp = await ai.chatWithPoko('波可，好困呀晚安去睡觉觉吧');
      expect(sleepResp.action, equals('SLEEP'));

      final yarnResp = await ai.chatWithPoko('波可，陪我玩毛线球');
      expect(yarnResp.action, equals('YARN'));

      final spinResp = await ai.chatWithPoko('波可，跳个舞转圈圈');
      expect(spinResp.action, equals('SPIN'));

      expect(ai.chatHistory.length, greaterThanOrEqualTo(4));
      ai.clearHistory();
      expect(ai.chatHistory, isEmpty);
    });

    testWidgets('AiVoiceChatDialog Interactive Modal Test', (WidgetTester tester) async {
      String? triggeredAction;
      String? triggeredDialogue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AiVoiceChatDialog(
              isNight: false,
              onActionTriggered: (action, dialogue) {
                triggeredAction = action;
                triggeredDialogue = dialogue;
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('波可的小电台'), findsOneWidget);
      expect(find.text('按住说话，松手发送'), findsOneWidget);

      // 主面板保持简洁: 预置短语统一收在「快捷心声」面板
      expect(find.text('🐟 投喂小鱼干'), findsNothing);
      await tester.tap(find.byTooltip('快捷心声'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('想和波可说点什么？'), findsOneWidget);

      // 点选一条预置心声
      await tester.tap(find.text('波可，给你准备了香酥小鱼干，快来吃呀！'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(triggeredAction, equals('FEED'));
      expect(triggeredDialogue, isNotNull);
    });

    testWidgets('Mobile Optimization Enhancements: PopScope, RepaintBoundary and Lifecycle Test', (WidgetTester tester) async {
      await tester.pumpWidget(const DesktopElectricPetApp());
      await tester.pump(const Duration(milliseconds: 200));

      // 1. 验证关键性能图层均已包裹 RepaintBoundary 隔离重绘
      final repaintBoundaries = find.byType(RepaintBoundary);
      expect(repaintBoundaries, findsWidgets);

      // 2. 初始状态下无遮罩，PopScope 允许正常返回
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsOneWidget);
      PopScope popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isTrue);

      // 3. 打开装扮小窝 Dock -> PopScope 拦截系统返回手势
      await tester.tap(find.text('装扮小窝'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse);

      // 4. 模拟 Android 预测性返回 / iOS 边缘滑动返回 -> 优先收起装扮小窝，而非退出 App
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isTrue);
    });
  });
}


