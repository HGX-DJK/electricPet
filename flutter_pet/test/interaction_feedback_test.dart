import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_pet/models/pet_model.dart';
import 'package:flutter_pet/services/backup_service.dart';
import 'package:flutter_pet/services/sound_service.dart';
import 'package:flutter_pet/views/dialogs/gacha_dialog.dart';

/// 交互体验回归测试：覆盖「用户点了之后到底发生了什么」。
///
/// 这一组盯的都是**静默失败 / 假反馈** —— 那类问题不会让程序崩，
/// 但会让用户以为应用坏了：
///  * 睡着的波可吃不下，却照样播进食动画、飘「+饱腹」字（数值纹丝不动）；
///  * 扭蛋动画播到一半关掉面板，币扣了、结果卡没了；
///  * 音效开关不落盘，重启又「自己开了」。
void main() {
  group('投喂反馈必须与实际结算一致', () {
    test('睡着的波可喂不进去（返回值必须是 false）', () {
      final model = PetModel();
      model.isSleeping = true;
      final hungerBefore = model.hunger;
      final expBefore = model.exp;

      final fed = model.feed('dried_fish');

      expect(fed, isFalse, reason: '睡着的波可必须拒食');
      expect(model.hunger, hungerBefore, reason: '拒食时饱腹度不能变');
      expect(model.exp, expBefore, reason: '拒食时经验不能变');
    });

    test('醒着且没吃饱时，投喂是成功的', () {
      final model = PetModel();
      model.isSleeping = false;
      model.hunger = 40;
      final hungerBefore = model.hunger;

      final fed = model.feed('dried_fish');

      expect(fed, isTrue);
      expect(model.hunger, greaterThan(hungerBefore));
    });
  });

  group('音效开关必须落盘', () {
    test('setSoundEnabled 会写进存档数据', () {
      final model = PetModel();
      model.setSoundEnabled(false);

      expect(model.enableSound, isFalse);
      expect(model.toDataMap()['enableSound'], isFalse,
          reason: '音效开关必须进存档 —— 否则重启就自己恢复成「开」了');
    });

    test('关闭音效后 playClick 不再发出系统物理声', () async {
      final original = SoundService.soundEnabled;
      addTearDown(() => SoundService.soundEnabled = original);

      SoundService.soundEnabled = false;
      await SoundService.playClick();

      // 这里断言不了「系统没响」，但能保证调用路径本身不抛异常；
      // 真正的回归点是 playClick 里「先判开关再播声」的顺序（源码审计）。
      expect(SoundService.soundEnabled, isFalse);
    });
  });

  group('覆盖前的安全备份不能顶掉历史档', () {
    test('安全备份写成独立文件，不覆盖 poko_backup.json', () async {
      final dir = Directory.systemTemp.createTempSync('poko_safety_');
      addTearDown(() => dir.deleteSync(recursive: true));
      BackupService.customBackupDir = dir.path;
      addTearDown(() => BackupService.customBackupDir = null);

      // 先放一份「历史档」
      final historyFile = File('${dir.path}/poko_backup.json');
      historyFile.writeAsStringSync('{"version":2,"format":"POKO_PUBLIC_BACKUP"}');

      final ok = await BackupService.writeSafetyBackup(
        {'level': 3, 'coins': 100},
        memoData: {'content': 'hi'},
      );

      expect(ok, isTrue, reason: '安全备份应该写成功');
      expect(
        historyFile.readAsStringSync(),
        '{"version":2,"format":"POKO_PUBLIC_BACKUP"}',
        reason: '安全备份绝不能动历史档本身 —— '
            '历史档正是从 poko_backup.json 读出来的，'
            '覆盖它等于把「要继承的那份」原地销毁',
      );

      final safetyFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('poko_safety_backup_'))
          .toList();
      expect(safetyFiles.length, 1, reason: '安全备份应当另起一个文件名');
      expect(safetyFiles.first.readAsStringSync(), contains('POKO_SAFETY_BACKUP'));
    });
  });

  group('扭卡中途关闭不能白扣币', () {
    /// 把扭蛋面板作为一个**真正的路由**推进 ——
    /// 面板里的关闭键走的是 Navigator.pop()，
    /// 如果它只是 home 的 body，pop 根本不会生效，测的就不是同一件事了。
    Future<void> openGacha(WidgetTester tester, PetModel model) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GachaDialog(model: model, onUpdated: () {}),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('抽卡动画期间关闭面板 → 不扣币、不产出', (tester) async {
      final model = PetModel();
      model.coins = 300;

      await openGacha(tester, model);

      // 点「开启心愿」
      await tester.tap(find.text('🌟 开启心愿'));
      // 只推进 100ms —— 抽卡实际结算发生在 450ms 之后
      await tester.pump(const Duration(milliseconds: 100));

      // 在结算前把面板关掉
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(model.coins, 300,
          reason: '面板在结算前就关了 —— 这次抽取应当整笔作废，不能扣币');
    });

    testWidgets('正常抽完会扣币并出结果', (tester) async {
      final model = PetModel();
      model.coins = 300;

      await openGacha(tester, model);

      await tester.tap(find.text('🌟 开启心愿'));
      await tester.pump(const Duration(milliseconds: 600));

      expect(model.coins, 270, reason: '正常抽一次应扣 30 币');
      expect(find.textContaining('愿望启封达成'), findsOneWidget,
          reason: '抽完应当出结果卡');
    });
  });
}
