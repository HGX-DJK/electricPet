// 手机端界面截图探针：把真实 App 界面按手机分辨率渲染成 PNG，用于肉眼审查
// 样式与细节交互（比读代码更可靠）。
//
// 用法：flutter test tool/render_ui_probe.dart
// 产物：<系统临时目录>/poko_ui/<场景>.png
//
// ⚠️ 跑完看到 PROBE_OUT=... 就 Ctrl+C 结束（渲染引擎占着，进程不会自动退出）。
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pet/main.dart';

const Size kPhone = Size(390, 844); // 逻辑像素，典型手机尺寸

/// 测试环境没有真实传感器插件，sensors_plus 会抛 MissingPluginException。
/// 这里 mock 掉该平台通道，避免异步异常被测试框架当成用例失败。
void _mockSensorChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
    (call) async => null,
  );
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey key,
  String name,
  Directory dir,
) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  // toImage 走引擎的异步通道，必须放进 runAsync，否则会污染测试的守卫状态
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('${dir.path}/$name.png');
    out.writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
    // ignore: avoid_print
    print('SHOT=${out.path}');
  });
}

/// 拉起 App 并等它稳定（呼吸动画等）
Future<void> _boot(WidgetTester tester, GlobalKey key) async {
  await tester.pumpWidget(RepaintBoundary(key: key, child: const DesktopElectricPetApp()));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

/// 销毁 App 树，避免无限循环动画导致用例收尾挂起
Future<void> _teardown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final dir = Directory('${Directory.systemTemp.path}/poko_ui');
  dir.createSync(recursive: true);

  setUpAll(_mockSensorChannel);

  void setPhone(WidgetTester tester) {
    tester.view.physicalSize = kPhone;
    tester.view.devicePixelRatio = 1.0;
    // 模拟真机的系统栏 inset（状态栏 47 + 手势导航条 34）。
    // 真机上正是这个 inset 暴露了「气泡用 MediaQuery 反推 Stack 高度」的定位 bug。
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
  }

  testWidgets('shot home', (tester) async {
    setPhone(tester);
    final key = GlobalKey();
    await _boot(tester, key);
    await _capture(tester, key, '01_home', dir);
    await _teardown(tester);
  });

  testWidgets('shot backpack', (tester) async {
    setPhone(tester);
    final key = GlobalKey();
    await _boot(tester, key);
    await tester.tap(find.text('奇妙背包'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, key, '02_backpack', dir);
    await _teardown(tester);
  });

  testWidgets('shot wardrobe dock', (tester) async {
    setPhone(tester);
    final key = GlobalKey();
    await _boot(tester, key);
    await tester.tap(find.text('装扮小窝'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, key, '03_wardrobe_dock', dir);
    await _teardown(tester);
  });

  testWidgets('shot action dock', (tester) async {
    setPhone(tester);
    final key = GlobalKey();
    await _boot(tester, key);
    await tester.tap(find.text('专属绝活'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, key, '04_action_dock', dir);
    await _teardown(tester);
  });

  testWidgets('shot feeding dock', (tester) async {
    setPhone(tester);
    final key = GlobalKey();
    await _boot(tester, key);
    await tester.tap(find.text('美味投喂'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, key, '05_feeding_dock', dir);
    await _teardown(tester);
  });

  testWidgets('shot wardrobe dialog', (tester) async {
    setPhone(tester);
    final key = GlobalKey();
    await _boot(tester, key);
    await tester.tap(find.text('萌宠衣橱'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await _capture(tester, key, '06_wardrobe_dialog', dir);
    await _teardown(tester);
  });

  testWidgets('shot action dialog', (tester) async {
    setPhone(tester);
    final key = GlobalKey();
    await _boot(tester, key);
    final gacha = find.byWidgetPredicate(
      (w) => w.runtimeType.toString().contains('CyberGachaFab'),
    );
    if (gacha.evaluate().isNotEmpty) {
      await tester.tap(gacha.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await _capture(tester, key, '07_action_dialog', dir);
    }
    await _teardown(tester);
  });

  testWidgets('shot memory album', (tester) async {
    setPhone(tester);
    final key = GlobalKey();
    await _boot(tester, key);
    final photo = find.byWidgetPredicate(
      (w) => w.runtimeType.toString().contains('PolaroidFrame'),
    );
    if (photo.evaluate().isNotEmpty) {
      await tester.tap(photo.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await _capture(tester, key, '08_memory_album', dir);
    }
    await _teardown(tester);
  });

  // ignore: avoid_print
  print('PROBE_OUT=${dir.path}');
}
