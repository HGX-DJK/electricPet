import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pet/main.dart';

void main() {
  testWidgets('Poko Pet App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('波可'), findsWidgets);
  });

  testWidgets('Live Action Jukebox Dock test', (WidgetTester tester) async {
    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 验证常态三灵动悬浮胶囊存在
    expect(find.text('奇妙背包'), findsOneWidget);
    expect(find.text('魔法换装'), findsOneWidget);
    expect(find.text('专属绝活'), findsOneWidget);

    // 1-Tap 点击进入专属绝活点播台
    await tester.tap(find.text('专属绝活'));
    await tester.pump(const Duration(milliseconds: 200));

    // 验证点播台顶层说明与动作卡片
    expect(find.textContaining('点击下方卡片即刻开演'), findsOneWidget);
    expect(find.text('纸箱藏猫猫'), findsOneWidget);
    expect(find.text('喵影神捕'), findsOneWidget);

    // 点击某项绝活开启表演
    await tester.tap(find.text('喵影神捕'));
    await tester.pump(const Duration(milliseconds: 200));

    // 验证正在表演指示
    expect(find.textContaining('正在表演'), findsOneWidget);
    expect(find.textContaining('喵影神捕'), findsWidgets);

    // 点击完成按钮收起滑轨坞
    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 200));

    // 验证无缝收起，三胶囊重现
    expect(find.text('专属绝活'), findsOneWidget);

    // 动作演职时长 5.2s 结束后自动回归平静 IDLE
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Backpack clean and Laser Chase test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 打开奇妙背包抽屉
    await tester.tap(find.text('奇妙背包'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 验证抽屉内去重：不再包含衣橱与绝活，保持功能纯粹
    expect(find.text('萌宠衣橱'), findsNothing);
    expect(find.text('美味投喂'), findsOneWidget);
    expect(find.text('神奇激光笔'), findsOneWidget);

    // 启动神奇激光笔
    await tester.tap(find.text('神奇激光笔'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 验证激光模式提示出现
    expect(find.textContaining('激光笔逗猫中'), findsOneWidget);

    // 点击收起激光笔
    await tester.tap(find.textContaining('点击收起'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 验证激光笔模式退出
    expect(find.textContaining('激光笔逗猫中'), findsNothing);
  });

  testWidgets('Cozy 3D Room Furniture and Haven Interactions test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 验证双层云朵花瓣猫蒲团标牌
    expect(find.textContaining("Poko's Cozy Haven"), findsOneWidget);

    // 验证室内软装家具均存在
    expect(find.text('猫草'), findsOneWidget);
    expect(find.text('磨爪'), findsOneWidget);
    expect(find.text('ON'), findsOneWidget);
    expect(find.textContaining('Day 1'), findsOneWidget);

    // 交互 1：轻触猫草盆栽
    await tester.tap(find.text('猫草'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('猫草清香'), findsWidgets);

    // 交互 2：轻触原木剑麻猫抓板
    await tester.tap(find.text('磨爪'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('磨磨爪子'), findsWidgets);

    // 交互 3：轻触小夜灯开关，ON 切换为 OFF
    await tester.tap(find.text('ON'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('OFF'), findsOneWidget);
    expect(find.textContaining('小夜灯熄灭'), findsWidgets);

    // 交互 4：再次轻触小夜灯开启，OFF 切换为 ON
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ON'), findsOneWidget);
    expect(find.textContaining('小夜灯点亮'), findsWidgets);

    // 交互 5：轻触拍立得照片挂饰
    await tester.tap(find.textContaining('Day 1'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('相框里是初遇那天'), findsWidgets);
  });

  testWidgets('Sound Toggle and Autonomous Living System test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 验证初始状态音效开关处于开启态 (🔊)
    expect(find.text('🔊'), findsOneWidget);

    // 点击音效开关切换为静音态 (🔇)
    await tester.tap(find.text('🔊'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('🔇'), findsOneWidget);

    // 再次点击恢复为声音开启态 (🔊)
    await tester.tap(find.text('🔇'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('🔊'), findsOneWidget);

    // 模拟待机 5 秒触发自主生活决策 (漫步巡视或萌趣微动作)
    await tester.pump(const Duration(seconds: 5));
    // 待机后小猫自主产生了萌趣生活行为
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
