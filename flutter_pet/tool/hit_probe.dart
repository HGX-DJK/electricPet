/// 命中测试探针：回答「屏幕上的这个点，到底被哪些控件盖住了？」
///
/// 手机端经常出现「某个胶囊徽标压在猫身上」「点不到被遮住的按钮」这类问题，
/// 肉眼估坐标非常容易算错。用命中测试可以百分百定位：
///
/// ```bash
/// flutter test tool/hit_probe.dart
/// ```
///
/// 默认探测 (270, 447)（390×844 逻辑像素下「盖被被」胶囊所在处）。
/// 想换坐标，改下面的 `probePoints` 即可。
library;

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pet/main.dart';

/// 待探测的屏幕坐标（逻辑像素）。
const List<Offset> probePoints = [Offset(270, 447)];

void main() {
  testWidgets('hit probe', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));

    final containers = find.byType(Container);
    for (final probe in probePoints) {
      // ignore: avoid_print
      print('--- 覆盖 ($probe) 的控件 ---');
      for (final e in containers.evaluate()) {
        final w = e.widget as Container;
        final box = tester.renderObject<RenderBox>(find.byWidget(w));
        final r = box.localToGlobal(Offset.zero) & box.size;
        if (!r.contains(probe)) continue;
        final deco = w.decoration;
        final grad = deco is BoxDecoration ? deco.gradient : null;
        final colors = grad is LinearGradient
            ? grad.colors.map((c) => c.toARGB32().toRadixString(16)).toList()
            : null;
        // ignore: avoid_print
        print('Container rect=$r radius=${deco is BoxDecoration ? deco.borderRadius : null} '
            'colors=$colors child=${w.child?.runtimeType}');
      }

      // ignore: avoid_print
      print('--- 该点的命中测试链 ---');
      final res = tester.hitTestOnBinding(probe);
      for (final entry in res.path.take(12)) {
        // ignore: avoid_print
        print('  ${entry.target.runtimeType}');
      }
    }
  });
}
