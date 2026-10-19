import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_pet/models/pet_model.dart';
import 'package:flutter_pet/services/sensor_service.dart';
import 'package:flutter_pet/views/dialogs/gacha_dialog.dart';

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
  });
}
