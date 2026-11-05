// 手机端界面截图探针：把真实 App 界面按手机分辨率渲染成 PNG，用于肉眼审查
// 样式与细节交互（比读代码更可靠）。
//
// 用法：flutter test tool/render_ui_probe.dart
// 产物：<系统临时目录>/poko_ui/<场景>.png（共 8 张，正常约 15-20 秒出完）
//
// ⚠️ 8 张图全部打印成 SHOT=<path> 之后，flutter test 的进程**不会自己结束**
//    —— App 里那些常驻的定时器与订阅吊着事件循环。看到最后一张 SHOT= 出来，
//    直接 Ctrl+C 结束即可（探针本身已经跑完，产物都已落盘）。
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pet/main.dart';
import 'package:flutter_pet/services/minimax_service.dart';
import 'package:flutter_pet/services/sensor_service.dart';
import 'package:flutter_pet/services/sound_service.dart';

const Size kPhone = Size(390, 844); // 逻辑像素，典型手机尺寸

/// 测试环境没有真实传感器 / 音频插件，它们会抛 MissingPluginException。
/// 这里 mock 掉相关平台通道，避免异步异常被测试框架当成用例失败。
///
/// ⚠️ 缺一条通道都不行：
///   1) sensors_plus 7.x 的方法通道 `dev.fluttercommunity.plus/sensors/method`
///      —— 用来设置采样周期；
///   2) sensors_plus 7.x 的事件通道 `dev.fluttercommunity.plus/sensors/accelerometer`
///      —— 真正的读数流；
///   3) audioplayers 的全局方法通道 / 事件通道 —— 按钮音效一响就会被调到；
///   4) audioplayers 的**每个播放器**各有一条事件通道 `xyz.luan/audioplayers/events/<playerId>`。
///
/// 第 4 条最麻烦：playerId 是 AudioPlayer 构造时生成的随机 UUID，名字每次都不一样，
/// 没法按固定字符串去 mock。解法是**提前把 App 会用的播放器建出来**，
/// 从它们身上读出真实 playerId，再按这个名字装 mock。
/// AudioPlayer 构造只会同步跑到第一个 await（发出 create 消息），
/// 真正 listen 事件通道发生在之后的微任务里 —— 所以下面这段同步代码
/// 一定赶在 listen 之前把 mock 装好。
void _mockPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // 1) sensors_plus 方法通道：设置采样周期
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
    (call) async => null,
  );

  // 2) sensors_plus 事件通道：加速度计读数。
  //    负载是 [x, y, z, 时间戳(微秒)]（见 sensors_plus 的 method_channel_sensors.dart）。
  //    这里给一份「静止竖放」的读数，并立刻结束流 —— 探针只关心界面长什么样。
  messenger.setMockStreamHandler(
    const EventChannel('dev.fluttercommunity.plus/sensors/accelerometer'),
    MockStreamHandler.inline(
      onListen: (arguments, sink) {
        sink.success(<double>[
          0.0, // x
          0.0, // y
          9.8, // z（重力）
          DateTime.now().microsecondsSinceEpoch.toDouble(),
        ]);
        sink.endOfStream();
      },
    ),
  );

  // 3) audioplayers 的全局通道
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (call) async => null,
  );
  messenger.setMockStreamHandler(
    const EventChannel('xyz.luan/audioplayers.global/events'),
    MockStreamHandler.inline(
      onListen: (arguments, sink) {
        // 立刻收流：留着一条永不结束的订阅会把 isolate 吊住不退出。
        sink.endOfStream();
      },
    ),
  );

  // 4) audioplayers 的单播放器通道（方法通道名是固定的）
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async => null,
  );

  // 4.5) record 插件（AI 语聊面板的按住说话）：只有方法通道是固定名，
  //      录音事件通道带 UUID，而面板只是打开并不会开始录音，所以够用。
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.record/messages'),
    (call) async => null,
  );
}

/// audioplayers 的**每个播放器**各有一条事件通道 `xyz.luan/audioplayers/events/<playerId>`，
/// 而 playerId 是 AudioPlayer 构造时生成的随机 UUID，名字每次都不一样，
/// 没法按固定字符串去 mock。解法是**提前把 App 会用的播放器建出来**，
/// 从它们身上读出真实 playerId，再按这个名字装 mock。
///
/// ⚠️ 必须在**测试体内部**调用（而不是 setUpAll）：
///    setUpAll 跑在真实事件循环里，建出来的播放器带着一条永远等不到回复的
///    平台通道 Future，会把整个 isolate 吊住不退出 —— 探针跑完进程不结束，
///    以前每次都得手动 Ctrl+C。
///    在测试体内建，flutter_test 会在用例收尾时把这些订阅/定时器一并清掉。
///
/// AudioPlayer 构造只会同步跑到第一个 await（发出 create 消息），
/// 真正 listen 事件通道发生在之后的微任务里 —— 所以下面这段同步代码
/// 一定赶在 listen 之前把 mock 装好。
void _prepareAudioPlayers() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  // 这几个播放器 App 自己也会用（静态单例），提前建出来不会改变行为。
  final players = <AudioPlayer>[
    SoundService.sfxPlayer,
    SoundService.purrPlayer,
    SoundService.ambientPlayer,
    MinimaxService().voicePlayer,
  ];
  for (final player in players) {
    messenger.setMockStreamHandler(
      EventChannel('xyz.luan/audioplayers/events/${player.playerId}'),
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          // 立刻收流：留着一条永不结束的订阅会把 isolate 吊住不退出。
          sink.endOfStream();
        },
      ),
    );
  }
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
  // 播放器必须在测试体内建（见 _prepareAudioPlayers 的注释）。
  _prepareAudioPlayers();
  await tester.pumpWidget(RepaintBoundary(key: key, child: const DesktopElectricPetApp()));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 2));
}

/// 销毁 App 树，避免无限循环动画导致用例收尾挂起
Future<void> _teardown(WidgetTester tester) async {
  // 断开传感器订阅：它是静态的，不取消的话会一直吊着事件循环。
  SensorService.stopListening();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  final dir = Directory('${Directory.systemTemp.path}/poko_ui');
  dir.createSync(recursive: true);

  // ⚠️ 必须挂在 setUpAll，不能挂在 setUp：
  //    setUp 跑在 flutter_test 的 fake-async 区里，AudioPlayer 构造时那条
  //    「create」通道调用会挂在等 fake 时钟推进上，进而把整个用例拖死。
  //    setUpAll 在真实事件循环里跑，通道调用能正常往返。
  setUpAll(_mockPlatformChannels);

  // 关掉 AI 云端调用（沿用 mobile_features_test.dart 的既有做法）。
  //
  // ⚠️ 不关的话，AI 语聊面板会真的去请求 MiniMax 的 TTS 接口：
  //    测试环境里 HttpOverrides 会把请求打成 400，但**请求本身是异步的**，
  //    最后一个用例收尾时可能还有没落地的请求吊着事件循环 ——
  //    探针跑完进程不退出（以前每次都得手动 Ctrl+C）。
  setUpAll(() {
    MinimaxService.networkEnabled = false;
  });

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
    // ⚠️ 底部浮动坞上**没有**独立的投喂按钮了，投喂入口现在藏在
    //    「奇妙背包」抽屉里的「美味投喂」卡片上。旧选择器直接 tap
    //    '美味投喂' 会报「Found 0 widgets」—— 抽屉不开，卡片根本不在树上。
    await tester.tap(find.text('奇妙背包'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('美味投喂'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await _capture(tester, key, '05_feeding_dock', dir);
    await _teardown(tester);
  });

  testWidgets('shot ai voice chat', (tester) async {
    // 原来的第 6 张是「萌宠衣橱弹窗」，但那个弹窗（WardrobeDialog）在当前
    // App 里已经没有入口了（衣橱改成了全屏模式），留着就是一张永远拍不到的图。
    // 换成当下真实存在的「AI 语聊」面板。
    setPhone(tester);
    final key = GlobalKey();
    await _boot(tester, key);
    await tester.tap(find.text('AI语聊'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await _capture(tester, key, '06_ai_voice_chat', dir);
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
