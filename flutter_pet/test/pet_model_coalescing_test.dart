import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:flutter_pet/models/pet_model.dart';
import 'package:flutter_pet/services/backup_service.dart';

/// 计数用的 SharedPreferences 存储：记下每一次真实写盘。
///
/// ⚠️ shared_preferences 的 legacy API（`SharedPreferences.getInstance` /
/// `setString`）最终都会落到 `SharedPreferencesStorePlatform.instance.setValue()`
/// 这一个咽喉上，所以在这里包一层就能数出「模型到底往磁盘写了几次」——
/// 不用往生产代码里塞任何测试专用的计数器。
class _CountingPrefsStore extends InMemorySharedPreferencesStore {
  _CountingPrefsStore() : super.empty();

  /// 总写盘次数
  int writeCount = 0;

  /// 每次写入的 key（SharedPreferences 会自动加 `flutter.` 前缀）
  final List<String> writtenKeys = <String>[];

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    writeCount++;
    writtenKeys.add(key);
    return super.setValue(valueType, key, value);
  }

  /// 宠物存档的写盘次数（存档是本轮唯一关心的写入目标）
  int get petDataWrites =>
      writtenKeys.where((k) => k.endsWith('poko_pet_data')).length;

  void reset() {
    writeCount = 0;
    writtenKeys.clear();
  }
}

/// 可控闸门版存储：第一次写盘会卡住，等测试放行。
///
/// 用来精确制造「写盘进行中，模型又发生了变化」这个时序，
/// 验证合并写盘不会把后来的变更吞掉。
class _GatedPrefsStore extends _CountingPrefsStore {
  final Completer<void> firstWriteEntered = Completer<void>();
  final Completer<void> releaseFirstWrite = Completer<void>();
  bool _gateArmed = false;

  /// 武装闸门：下一次写盘会卡住
  void armGate() {
    _gateArmed = true;
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (_gateArmed) {
      _gateArmed = false;
      if (!firstWriteEntered.isCompleted) firstWriteEntered.complete();
      await releaseFirstWrite.future;
    }
    return super.setValue(valueType, key, value);
  }
}

/// 读出当前已经落盘的宠物存档
Future<Map<String, dynamic>?> _readPersisted() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('poko_pet_data');
  if (raw == null) return null;
  return jsonDecode(raw) as Map<String, dynamic>;
}

/// 等写盘落定：轮询到写盘次数连续若干轮不再变化为止。
///
/// 写盘链路是 SharedPreferences + 真实文件 I/O（`flush: true`），
/// 所以这里只能靠"等它停下来"来判断，不能假设它是同步的。
Future<void> _waitForWritesToSettle(_CountingPrefsStore store) async {
  // 先给写盘链路留出启动时间（模型内部是先 await 再取快照）
  await Future<void>.delayed(const Duration(milliseconds: 60));
  var previous = store.writeCount;
  var stable = 0;
  for (var i = 0; i < 200; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final current = store.writeCount;
    if (current == previous) {
      stable++;
      // 连续 50ms 没有新增写盘 → 认为已落定
      if (stable >= 5) return;
    } else {
      stable = 0;
      previous = current;
    }
  }
}

void main() {
  late _CountingPrefsStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = _CountingPrefsStore();
    SharedPreferencesStorePlatform.instance = store;
    // 别把测试数据写到用户真实的公共备份目录里
    final tmp = Directory('${Directory.systemTemp.path}/poko_coalescing_test');
    if (!tmp.existsSync()) tmp.createSync(recursive: true);
    BackupService.customBackupDir = tmp.path;
  });

  tearDown(() {
    BackupService.customBackupDir = null;
  });

  group('写盘与通知合并', () {
    test('一次摸头 = 1 次通知 + 1 次写盘', () async {
      final model = PetModel();
      await model.isReady;
      await _waitForWritesToSettle(store);
      store.reset();

      var notifications = 0;
      model.addListener(() => notifications++);

      final moodBefore = model.mood;
      model.petHead();

      // 通知走微任务合并，让微任务跑完
      await Future<void>.delayed(Duration.zero);
      await _waitForWritesToSettle(store);

      expect(notifications, 1, reason: '一次交互只应触发一次通知（= 一次整树重建）');
      expect(store.petDataWrites, 1, reason: '一次交互只应写盘一次');

      final persisted = await _readPersisted();
      expect(persisted, isNotNull);
      expect(persisted!['mood'], isNot(moodBefore), reason: '落盘的数据必须反映本次交互');
    });

    test('一次投喂 = 1 次通知 + 1 次写盘', () async {
      final model = PetModel();
      await model.isReady;
      await _waitForWritesToSettle(store);
      store.reset();

      var notifications = 0;
      model.addListener(() => notifications++);

      model.feed('dried_fish');

      await Future<void>.delayed(Duration.zero);
      await _waitForWritesToSettle(store);

      expect(notifications, 1);
      expect(store.petDataWrites, 1);
    });

    test('一次哄睡 = 1 次通知 + 1 次写盘', () async {
      final model = PetModel();
      await model.isReady;
      await _waitForWritesToSettle(store);
      store.reset();

      var notifications = 0;
      model.addListener(() => notifications++);

      model.toggleSleep();

      await Future<void>.delayed(Duration.zero);
      await _waitForWritesToSettle(store);

      expect(notifications, 1);
      expect(store.petDataWrites, 1);
    });

    test('合并后落盘的是最终状态，不是中间态', () async {
      final model = PetModel();
      await model.isReady;
      await _waitForWritesToSettle(store);
      store.reset();

      model.feed('dried_fish');
      await _waitForWritesToSettle(store);

      final persisted = await _readPersisted();
      expect(persisted, isNotNull);
      final data = persisted!;

      // 投喂这条链路会连锁经过 addExp / recordMemory / addPersonalityPoint，
      // 合并成一次写盘后，快照必须已经包含全部这些变更。
      expect(data['totalFedCount'], 1, reason: '投喂次数必须落盘');
      final stats = (data['personalityStats'] as Map).cast<String, dynamic>();
      expect(stats['sport'], greaterThan(0), reason: '性格点数必须落盘');
      final memories = (data['memories'] as List).cast<Map<String, dynamic>>();
      expect(
        memories.any((m) => m['id'] == 'first_feed'),
        isTrue,
        reason: '「第一口小鱼干」这条纪念必须落盘',
      );
    });

    test('写盘进行中发生的新变更不会丢（尾随补写）', () async {
      final gated = _GatedPrefsStore();
      SharedPreferencesStorePlatform.instance = gated;
      store = gated;

      final model = PetModel();
      await model.isReady;
      await _waitForWritesToSettle(gated);

      // 武装闸门：下一次写盘会卡住
      gated.armGate();
      gated.reset();

      model.petHead();
      // 等到这次写盘真的进到 setValue（说明快照已经取过了）
      await gated.firstWriteEntered.future;

      // 写盘卡住的这段时间里，模型又变了
      model.setDecoration('head', 'ribbon');

      gated.releaseFirstWrite.complete();
      await _waitForWritesToSettle(gated);

      expect(
        gated.petDataWrites,
        2,
        reason: '快照之后来了新变更，必须补一次写盘',
      );
      final persisted = await _readPersisted();
      expect(persisted, isNotNull);
      final decorations = (persisted!['decorations'] as Map).cast<String, dynamic>();
      expect(decorations['head'], 'ribbon', reason: '后补的变更必须真的落盘');
    });

    test('连续两次独立操作会各写一次，不会被合并掉', () async {
      final model = PetModel();
      await model.isReady;
      await _waitForWritesToSettle(store);
      store.reset();

      model.petHead();
      await _waitForWritesToSettle(store);
      final afterFirst = store.petDataWrites;

      model.wash();
      await _waitForWritesToSettle(store);

      expect(afterFirst, 1);
      expect(store.petDataWrites, 2, reason: '两次独立操作不能被合并成一次写盘');
    });
  });
}
