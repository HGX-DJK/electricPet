import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:flutter_pet/models/pet_model.dart';
import 'package:flutter_pet/services/backup_service.dart';
import 'package:flutter_pet/services/overlay_channel.dart';
import 'package:flutter_pet/services/overlay_service.dart';

/// 桌面悬浮宠投喂的「单写方」守护测试。
///
/// 背景：Dart 侧与原生侧共用同一份宠物存档（SharedPreferences 的
/// `flutter.poko_pet_data`）。两边都写就是「读-改-写」互相覆盖 ——
/// 后写的赢，先写的那份改动直接丢，表现为「App 里喂了，桌面上的猫却没吃到」。
///
/// 约定：**Flutter 引擎活着时由 Dart 独占写盘**，原生只把「投喂」这个*动作*
/// 转交给 Dart 去结算；引擎不在（App 被杀）才由原生自己结算写盘兜底。
///
/// 这组测试钉住 Dart 侧那一半：结算规则、数值边界、以及「模型没加载完时
/// 不能拿默认值覆盖存档」。原生那一半由
/// `test/floating_overlay_native_test.dart` 的源码断言守护。
class _CountingPrefsStore extends InMemorySharedPreferencesStore {
  _CountingPrefsStore() : super.empty();

  int writeCount = 0;

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    writeCount++;
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
Future<void> _waitForWritesToSettle(_CountingPrefsStore store) async {
  await Future<void>.delayed(const Duration(milliseconds: 60));
  var previous = store.writeCount;
  var stable = 0;
  for (var i = 0; i < 200; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final current = store.writeCount;
    if (current == previous) {
      stable++;
      if (stable >= 5) return;
    } else {
      stable = 0;
      previous = current;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingPrefsStore store;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = _CountingPrefsStore();
    SharedPreferencesStorePlatform.instance = store;
    // 别把测试数据写到用户真实的公共备份目录里
    final tmp = Directory('${Directory.systemTemp.path}/poko_feeding_test');
    if (!tmp.existsSync()) tmp.createSync(recursive: true);
    BackupService.customBackupDir = tmp.path;
  });

  tearDown(() {
    BackupService.customBackupDir = null;
  });

  group('桌面投喂的 Dart 侧结算', () {
    test('饱食度 +增量、心情 +10、亲密度 +5，并真的落盘', () async {
      final model = PetModel();
      await model.isReady;
      await _waitForWritesToSettle(store);

      model.hunger = 40;
      model.mood = 50;
      model.intimacy = 60;
      // 把「此刻」钉死，免得结算前的离线补算把数值带偏
      model.stateSavedAt = DateTime.now().millisecondsSinceEpoch;

      await model.applyExternalFeeding(15);

      expect(model.hunger, closeTo(55, 0.05));
      expect(model.mood, closeTo(60, 0.05));
      expect(model.intimacy, 65);

      // 关键：这次结算必须落盘，否则桌面上的猫永远吃不到
      await _waitForWritesToSettle(store);
      final persisted = await _readPersisted();
      expect(persisted, isNotNull, reason: '投喂后没有落盘');
      expect(persisted!['hunger'], closeTo(55, 0.05));
      expect(persisted['mood'], closeTo(60, 0.05));
      expect(persisted['intimacy'], 65);
    });

    test('结算前先补算离线衰减，不会把 App 攒下的状态抹掉', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(
        'poko_pet_data',
        jsonEncode(<String, dynamic>{
          'hunger': 80.0,
          'mood': 80.0,
          'energy': 80.0,
          'cleanliness': 80.0,
          'intimacy': 50,
          'stateSavedAt': now - 60000, // 60 秒前
        }),
      );

      final model = PetModel();
      await model.isReady;
      await model.applyExternalFeeding(15);

      // 60 秒离线：hunger -0.45*60 = -27，mood -0.35*60 = -21
      expect(model.hunger, closeTo(80 - 27 + 15, 0.5));
      expect(model.mood, closeTo(80 - 21 + 10, 0.5));
      // 亲密度不参与衰减，只加固定的 +5
      expect(model.intimacy, 55);
    });

    test('饱食度与亲密度都封顶在 100', () async {
      final model = PetModel();
      await model.isReady;

      model.hunger = 99;
      model.intimacy = 99;
      model.stateSavedAt = DateTime.now().millisecondsSinceEpoch;

      await model.applyExternalFeeding(15);

      expect(model.hunger, 100.0);
      expect(model.intimacy, 100);
    });

    test('模型还没加载完就收到投喂，必须等加载完再结算（不能拿默认值覆盖存档）', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'poko_pet_data',
        jsonEncode(<String, dynamic>{
          'hunger': 12.0,
          'mood': 34.0,
          'intimacy': 40,
          'stateSavedAt': DateTime.now().millisecondsSinceEpoch,
        }),
      );

      final model = PetModel();
      // 故意不 await model.isReady —— 方法内部必须自己等
      await model.applyExternalFeeding(15);

      expect(model.hunger, closeTo(27.0, 0.5),
          reason: '没等模型加载完就结算，存档里的真实状态会被默认值覆盖');
      expect(model.mood, closeTo(44.0, 0.5));
      expect(model.intimacy, 45);
    });
  });

  group('原生 → Dart 的投喂通道', () {
    test('原生调用 applyFeeding 时，Dart 侧用模型结算并回执', () async {
      final model = PetModel();
      await model.isReady;
      model.hunger = 30;
      model.mood = 40;
      model.intimacy = 50;
      model.stateSavedAt = DateTime.now().millisecondsSinceEpoch;

      OverlayService.bindNativeCalls(model);

      Object? reply;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        OverlayChannel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall(OverlayChannel.applyFeeding, <String, Object>{
            OverlayChannel.argHungerDelta: 15,
          }),
        ),
        (dynamic value) => reply = value,
      );

      expect(reply, isNotNull, reason: 'Dart 侧没有接住原生的 applyFeeding 调用');
      expect(model.hunger, closeTo(45, 0.05));
      expect(model.mood, closeTo(50, 0.05));
      expect(model.intimacy, 55);
    });
  });
}
