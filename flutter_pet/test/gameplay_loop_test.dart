// 第五轮：可玩性 / 可交互性回归测试。
//
// 这一组测的是「养成数值到底有没有变成玩法」以及「交互有没有层次」。
//
// 覆盖四件事：
//
// 1. **摸头要返回数值增量** —— 摸头是全 App 点击频次最高的动作，却曾是
//    **唯一没有数值回显**的路径：玩家摸了半天不知道拿到了什么。
//    现在 petHead() 返回增量，UI 把它飘出来。
//    且必须返回**实际**增量：心情已经 99 时只加了 1 点，飘字不能写「+4.5 心情」。
//
// 2. **扭卡奖池是唯一真源** —— 奖池从 drawGacha() 函数体提到 static const gachaPool，
//    界面上的「图鉴」面板才能读到它。
//
// 3. **重复件退款与桌面端同值**（15 枚），且**模型层不直接改金币**
//    —— 退款由 UI 统一兑现，两端同构（桌面端 pet/model.py 同样如此）。
//
// 4. **图鉴要真的渲染出来** —— 否则「已收集 X/N」只是代码里的一个字段。
//
// 5. **抽到过的专属装扮不再被羁绊阶锁住** —— gold_crown_sparkle 既是 UR 奖池项、
//    又是 4 阶羁绊专属；1 阶玩家抽到它却穿不上，看起来像抽卡骗人。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_pet/models/pet_model.dart';
import 'package:flutter_pet/services/backup_service.dart';
import 'package:flutter_pet/views/dialogs/gacha_dialog.dart';

/// 定位 Flutter 包根目录（向上查找 pubspec.yaml），兼容在不同工作目录下执行测试。
Directory _findPackageRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('未找到 Flutter 包根目录 (pubspec.yaml)');
    }
    dir = parent;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // 别把测试数据写到用户真实的公共备份目录里
    final tmp = Directory('${Directory.systemTemp.path}/poko_gameplay_test');
    if (!tmp.existsSync()) tmp.createSync(recursive: true);
    BackupService.customBackupDir = tmp.path;
  });

  group('摸头数值反馈', () {
    test('petHead 返回本次的数值增量', () {
      final pet = PetModel();
      pet.mood = 50;
      pet.exp = 0;

      final gain = pet.petHead();

      expect(gain.containsKey('mood'), isTrue);
      expect(gain.containsKey('exp'), isTrue);
      expect(gain.containsKey('intimacy'), isTrue);
      expect(gain['exp'], closeTo(4.0, 0.001));
      expect(gain['intimacy'], closeTo(3.0, 0.001));
      expect(gain['mood'], closeTo(4.5, 0.001));
      expect(pet.mood, closeTo(54.5, 0.001));
    });

    test('⚠️ 心情封顶时必须报实际增量，不能报标称值', () {
      // 反馈必须诚实：数字和实际到账对不上，玩家很快就再也不信这些飘字了。
      final pet = PetModel();
      pet.mood = 99;

      final gain = pet.petHead();

      expect(pet.mood, closeTo(100.0, 0.001));
      expect(
        gain['mood'],
        closeTo(1.0, 0.001),
        reason: '封顶时只加了 1 点，不能报标称的 4.5',
      );
    });
  });

  group('扭卡奖池唯一真源', () {
    test('gachaPool 存在、长度合理、代号唯一', () {
      const pool = PetModel.gachaPool;
      expect(pool.length, greaterThanOrEqualTo(15));
      final codes = pool.map((e) => e['code']).toSet();
      expect(codes.length, pool.length, reason: '奖池里出现了重复代号');
    });

    test('drawGacha 抽出来的每一件都来自 gachaPool', () {
      final pet = PetModel();
      pet.coins = 5000;
      final results = pet.drawGacha(10);
      final poolCodes = PetModel.gachaPool.map((e) => e['code']).toSet();
      for (final r in results) {
        expect(poolCodes.contains(r['code']), isTrue);
      }
    });

    test('重复件退款金额与桌面端一致（15 枚）', () {
      expect(PetModel.gachaDuplicateRefund, 15);
    });

    test('重复件要报退款、且模型层不直接改金币', () {
      final pet = PetModel();
      pet.coins = 1000;
      // 把整个奖池都设为已拥有 ⇒ 抽到的必然全是重复件（无随机性）
      pet.unlockedItems = PetModel.gachaPool.map((e) => e['code'] as String).toList();

      final before = pet.coins;
      final results = pet.drawGacha(10);

      for (final r in results) {
        expect(r['refundCoins'], PetModel.gachaDuplicateRefund);
      }
      expect(
        pet.coins,
        before - 270,
        reason: '模型层不该直接退币 —— 退币由 UI 统一兑现（与桌面端同构）',
      );
    });

    test('新件没有退款', () {
      final pet = PetModel();
      pet.coins = 1000;
      pet.unlockedItems = <String>[];

      final results = pet.drawGacha(1);

      expect(results.first['refundCoins'], 0);
    });
  });

  group('扭蛋图鉴', () {
    testWidgets('面板要真的把「已收集 X/N」渲染出来', (tester) async {
      final pet = PetModel();
      pet.coins = 500;
      // 假装已经收集了几件
      pet.unlockedItems = <String>[
        PetModel.gachaPool.first['code'] as String,
        PetModel.gachaPool[1]['code'] as String,
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GachaDialog(model: pet, onUpdated: () {})),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining('扭蛋图鉴'),
        findsWidgets,
        reason: '图鉴标题必须渲染出来',
      );
      expect(
        find.textContaining('已收集 2/${PetModel.gachaPool.length}'),
        findsWidgets,
        reason: '收集进度必须显示出来 —— 否则抽卡没有可追求的样子',
      );
    });

    testWidgets('奖池里每一件都要出现在图鉴里', (tester) async {
      final pet = PetModel();
      pet.coins = 500;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GachaDialog(model: pet, onUpdated: () {})),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      for (final entry in PetModel.gachaPool) {
        expect(
          find.text(entry['icon'] as String),
          findsWidgets,
          reason: '奖池里的 ${entry['name']} 必须出现在图鉴里',
        );
      }
    });
  });

  group('退款必须落盘', () {
    // ⚠ drawGacha() 自己在返回前已经 saveToDisk() 过，
    // 而退款是在它**之后**由界面兑现的 —— 不补这一次落盘，
    // 玩家就会莫名其妙少一笔钱（这个仓库最在意的一类 bug）。
    test('退款兑现后必须真的写到盘上', () async {
      final pet = PetModel();
      await pet.isReady;
      pet.coins = 1000;
      // 把整个奖池都设为已拥有 ⇒ 抽到的必然全是重复件（无随机性）
      pet.unlockedItems = PetModel.gachaPool.map((e) => e['code'] as String).toList();

      final before = pet.coins;
      final results = pet.drawGacha(10);
      final refund = results.fold<int>(
        0,
        (sum, r) => sum + (r['refundCoins'] as int),
      );
      expect(refund, 10 * PetModel.gachaDuplicateRefund);

      await pet.creditRefund(refund);

      expect(pet.coins, before - 270 + refund);

      // 盘上的金币必须也是退完之后的数
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('poko_pet_data');
      expect(raw, isNotNull);
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      expect(
        data['coins'],
        before - 270 + refund,
        reason: '退款只在内存里 —— App 被杀这笔钱就没了',
      );
    });

    test('退 0 枚是空操作', () async {
      final pet = PetModel();
      await pet.isReady;
      final before = pet.coins;
      expect(await pet.creditRefund(0), before);
      expect(pet.coins, before);
    });
  });

  group('执行顺序守护', () {
    // ⚠ 这是一条**确定性**守护，不是靠跑运气。
    //
    // 背景：抽卡结算在 450ms 定时器回调里完成。那次回调里如果先 await 了
    // 退款落盘（落盘链末端是 BackupService.writeSilentBackup —— 真实文件 I/O
    // + flush），那么「出结果卡」的 setState 就会整整晚一拍：
    // flutter_test 的 fake-async 沙箱里，这个完成回调不在微任务队列中，
    // tester.pump(600ms) 那一拍根本渲染不出结果卡 —— CI 上随机红。
    //
    // 修法：加币同步生效、落盘丢给后台；界面绝不 await 落盘。
    test('退款落盘绝不能挡在「出结果卡」前面', () {
      final root = _findPackageRoot();
      final src = File(
        '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
        'views${Platform.pathSeparator}dialogs${Platform.pathSeparator}'
        'gacha_dialog.dart',
      ).readAsStringSync();

      final start = src.indexOf('if (totalRefund > 0) {');
      expect(start, greaterThan(-1), reason: '找不到退款兑现分支');
      final end = src.indexOf('widget.onUpdated();', start);
      expect(end, greaterThan(start), reason: '找不到退款兑现分支的终点');

      final block = src.substring(start, end);
      expect(
        block,
        contains('unawaited('),
        reason: '退款必须「不等落盘」—— 加币同步生效、落盘在后台跑',
      );
      expect(
        block,
        isNot(contains('await widget.model.creditRefund')),
        reason: 'await 落盘会把「出结果卡」整整拖晚一拍（真实文件 I/O）',
      );
    });

    test('creditRefund 必须同步加币（不等落盘也能立刻拿到余额）', () {
      final root = _findPackageRoot();
      final src = File(
        '${root.path}${Platform.pathSeparator}lib${Platform.pathSeparator}'
        'models${Platform.pathSeparator}pet_model.dart',
      ).readAsStringSync();

      final start = src.indexOf('Future<int> creditRefund');
      expect(start, greaterThan(-1), reason: '找不到 creditRefund');
      // 用「方法结尾」切片，而不是找某个具体语句 ——
      // 否则代码形态一变（await 写法 vs 后台写法）守护自己先崩，
      // 报错信息还完全指不到真正的问题上。
      final end = src.indexOf('\n  }', start);
      expect(end, greaterThan(start), reason: '找不到 creditRefund 的方法体结尾');
      final body = src.substring(start, end);

      expect(
        body,
        isNot(contains('async {')),
        reason: 'creditRefund 不能是 async 函数 —— 它的加币必须同步生效，'
            '否则界面拿到的余额是旧的',
      );
      expect(
        body,
        contains('coins += amount;'),
        reason: '加币必须在函数返回前同步完成',
      );
      expect(
        body,
        contains('return saveToDisk()'),
        reason: '落盘必须真的发起 —— 不能只加币不写盘，'
            '否则 App 被杀就是「扣了币、退款没了」',
      );
    });
  });
}
