import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_pet/models/memo_model.dart';
import 'package:flutter_pet/views/memo_screen.dart';
import 'package:flutter_pet/widgets/poko_tap_target.dart';

/// 无障碍回归测试：关键图标按钮必须**有名字**且**够得着**。
///
/// 背景：这个 App 原本零处 `Semantics`，读屏用户拿到的是一排没有名字的方块；
/// 而很多图标按钮只有 26~30 dp，手机上根本点不准。
/// 这组用例守住这两件事不再退化。
void main() {
  group('图标按钮的无障碍与触控目标', () {
    testWidgets('便签页的关闭键有读屏名字，且命中区 ≥ 44dp', (tester) async {
      // ⚠️ SemanticsHandle 必须在**用例体内** dispose ——
      // 用 addTearDown 太晚了，框架在用例体结束时就会检查句柄是否已释放。
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MemoScreen(memoModel: MemoModel()))),
      );
      await tester.pump();

      // 1. 有名字
      expect(
        find.bySemanticsLabel('关闭便签'),
        findsOneWidget,
        reason: '纯图标按钮不给读屏一个名字，用户只会听到「按钮、按钮」',
      );

      // 2. 命中区够大（视觉尺寸不变，靠额外的命中区兜底）
      final size = tester.getSize(find.bySemanticsLabel('关闭便签'));
      expect(
        size.width,
        greaterThanOrEqualTo(PokoTapTarget.defaultMinTapTarget),
        reason: '关闭键的命中区只有 ${size.width}dp，手机上太难点准',
      );
      expect(size.height, greaterThanOrEqualTo(PokoTapTarget.defaultMinTapTarget));

      handle.dispose();
    });

    testWidgets('便签色卡有读屏名字（颜色本身说不清是哪个）', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MemoScreen(memoModel: MemoModel()))),
      );
      await tester.pump();

      final dots = find.bySemanticsLabel(RegExp('切换便签配色'));
      expect(dots, findsWidgets, reason: '四枚色卡都应该有读屏名字');

      final size = tester.getSize(dots.first);
      expect(
        size.width,
        greaterThanOrEqualTo(40),
        reason: '26dp 的色卡在手机上很难点准',
      );

      handle.dispose();
    });

    testWidgets('时间戳按钮有读屏名字', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: MemoScreen(memoModel: MemoModel()))),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('插入当前时间戳'), findsOneWidget);

      handle.dispose();
    });
  });
}
