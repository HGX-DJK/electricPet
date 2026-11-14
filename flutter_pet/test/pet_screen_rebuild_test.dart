import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_pet/main.dart';
import 'package:flutter_pet/models/memo_model.dart';
import 'package:flutter_pet/models/pet_model.dart';
import 'package:flutter_pet/services/minimax_service.dart';
import 'package:flutter_pet/views/docks/top_dual_islands.dart';

/// 收集 TopDualIslands 里所有「xx%」形式的读数文本。
List<String> _percentReadings(WidgetTester tester) {
  final result = <String>[];
  for (final element in find.descendant(
    of: find.byType(TopDualIslands),
    matching: find.byType(Text),
  ).evaluate()) {
    final text = (element.widget as Text).data;
    if (text != null && RegExp(r'^\d+%$').hasMatch(text)) {
      result.add(text);
    }
  }
  return result;
}

void main() {
  setUp(() {
    // flutter_test 会把 HTTP 全拦掉并统一返回 400，
    // 主界面 initState 里的语音预热会让每个用例刷 5 条 "T2A error status: 400"。
    MinimaxService.networkEnabled = false;
  });

  /// 用手机尺寸的视口 —— 默认的 800x600 会让顶部胶囊溢出（那是布局问题，
  /// 不是本组用例要测的东西）。
  void usePhoneViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('数值衰减不得触发整树重建', () {
    testWidgets('每秒一次的数值衰减不能重建整棵组件树', (tester) async {
      usePhoneViewport(tester);
      final model = PetModel();
      await tester.pumpWidget(
        DesktopElectricPetApp(petModel: model, memoModel: MemoModel()),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      // 记录重建前 TopDualIslands 的**实例**：
      // 它是在 PetScreen.build() 里 new 出来的，
      // 所以实例变了 == 整棵树重建了。
      final before = tester.widget(find.byType(TopDualIslands));

      model.tickDecay(1.0);
      await tester.pump();

      final after = tester.widget(find.byType(TopDualIslands));

      expect(
        identical(before, after),
        isTrue,
        reason: '只是数值衰减（饥饿/心情/精力）时，画面并没有变化，'
            '不应该重建整棵组件树 —— 实测一次整树重建要 25.4ms，'
            '等于每秒掉一帧',
      );
    });

    testWidgets('会改变画面的模型变更仍然必须重建', (tester) async {
      usePhoneViewport(tester);
      final model = PetModel();
      await tester.pumpWidget(
        DesktopElectricPetApp(petModel: model, memoModel: MemoModel()),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      final before = tester.widget(find.byType(TopDualIslands));

      model.setSkin('cat_black');
      await tester.pump();

      final after = tester.widget(find.byType(TopDualIslands));

      expect(
        identical(before, after),
        isFalse,
        reason: '换了皮肤 = 萌宠长相要变，必须重建 —— '
            '不能为了省性能把真正的外观变更也一起拦掉',
      );
    });

    testWidgets('佩戴装扮同样必须重建', (tester) async {
      usePhoneViewport(tester);
      final model = PetModel();
      await tester.pumpWidget(
        DesktopElectricPetApp(petModel: model, memoModel: MemoModel()),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      final before = tester.widget(find.byType(TopDualIslands));

      model.setDecoration('head', 'ribbon');
      await tester.pump();

      final after = tester.widget(find.byType(TopDualIslands));
      expect(identical(before, after), isFalse);
    });
  });

  group('实时读数不依赖整树重建', () {
    testWidgets('顶部岛屿的饱腹/心情读数必须跟着数值衰减更新', (tester) async {
      usePhoneViewport(tester);
      final model = PetModel();
      await tester.pumpWidget(
        DesktopElectricPetApp(petModel: model, memoModel: MemoModel()),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      final before = _percentReadings(tester);
      expect(before, isNotEmpty, reason: '前置条件：顶部应当有百分比读数');

      // 衰减足够多次，确保数值一定变了
      for (var i = 0; i < 20; i++) {
        model.tickDecay(1.0);
      }
      await tester.pump();

      final after = _percentReadings(tester);
      expect(
        after,
        isNot(equals(before)),
        reason: '饱腹/心情读数必须实时更新 —— '
            '它们现在自己监听模型，不再依赖主界面整树重建',
      );
    });

    testWidgets('喂食托盘打开时仍要显示精确的饱腹数值', (tester) async {
      usePhoneViewport(tester);
      final model = PetModel();
      await tester.pumpWidget(
        DesktopElectricPetApp(petModel: model, memoModel: MemoModel()),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));

      // 打开「美味投喂」托盘
      await tester.tap(find.text('奇妙背包'));
      await tester.pump(const Duration(milliseconds: 300));

      final readings = _percentReadings(tester);
      expect(readings, isNotEmpty);
    });
  });
}
