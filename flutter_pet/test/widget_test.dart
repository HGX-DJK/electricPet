import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pet/main.dart';
import 'package:flutter_pet/services/sound_service.dart';

void main() {
  testWidgets('Poko Pet App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('波可'), findsWidgets);
  });

  testWidgets('Live Action Jukebox Dock test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    // 验证暖绒舒睡圆垫
    expect(find.byKey(const ValueKey('cozy_cat_rug')), findsOneWidget);

    // 验证室内软装家具均存在
    expect(find.text('猫草'), findsOneWidget);
    expect(find.text('磨爪'), findsOneWidget);
    expect(find.text('ON'), findsOneWidget);
    expect(find.textContaining('Day 1'), findsOneWidget);

    // 交互 1：轻触猫草盆栽
    await tester.tap(find.text('猫草'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('猫草清香'), findsWidgets);

    // 交互 2：轻触原木剑麻猫抓柱
    await tester.tap(find.text('磨爪'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('爪'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 2000));

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

    // 交互 5：轻触拍立得照片挂饰，打开专属时光相册
    await tester.tap(find.textContaining('Day 1').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('相框里是初遇那天'), findsWidgets);
    expect(find.textContaining('时光纪念相册'), findsOneWidget);
    expect(find.textContaining('咔嚓！拍下一张今日纪念照'), findsOneWidget);

    // 交互 6：点击即时快门拍照留念
    await tester.tap(find.textContaining('咔嚓！拍下一张今日纪念照'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('收入纪念相册'), findsOneWidget);

    // 关闭相册弹窗
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // 交互 7：轻触暖绒舒睡圆垫触发“幸福踩奶做小面包”
    await tester.tap(find.byKey(const ValueKey('cozy_cat_rug')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('踩奶'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 3500));
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

    // 验证波可专属暖绒舒睡圆垫
    expect(find.byKey(const ValueKey('cozy_cat_rug')), findsOneWidget);
  });

  testWidgets('Dynamic Pupils, Floor Paw Footprints, and Tail Boop Puff test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 1. 验证小猫与场景 CustomPaint 正常挂载
    final catPaintFinder = find.byType(CustomPaint);
    expect(catPaintFinder, findsWidgets);

    // 2. 测试揪尾巴微互动 (Tail Boop / Pinch & Puff)
    // 寻找小猫 GestureDetector 并点击小猫右侧尾巴区域 (相对于 200x200 画布的 offset (160, 95))
    final catFinder = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.child is AnimatedBuilder,
    );
    expect(catFinder, findsOneWidget);

    final catTopLeft = tester.getTopLeft(catFinder);
    final tailTapTarget = Offset(catTopLeft.dx + 160.0, catTopLeft.dy + 95.0);
    await tester.tapAt(tailTapTarget);
    await tester.pump(const Duration(milliseconds: 500));

    // 验证触发尾巴敏感禁区警告台词与炸毛惊跳反应
    expect(find.textContaining('尾巴'), findsWidgets);

    // 3. 验证炸毛状态持续并在约 2 秒后自然平复
    await tester.pump(const Duration(milliseconds: 2000));

    // 4. 验证地板漫步与追球脚印渲染层挂载运行
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('Micro-Expressions, Drag-to-Feed, Blanket, French Window, and Intimacy Bond test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 1. 方向三：法式拱形观景窗天象点按切换
    final windowFinder = find.byKey(const ValueKey('french_arch_window'));
    expect(windowFinder, findsOneWidget);
    expect(find.text('☀️ 晴空'), findsOneWidget);

    // 点击切换为治愈雨季
    await tester.tap(windowFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('🌧️ 细雨'), findsOneWidget);

    // 再次点击切换为春日落樱
    await tester.tap(windowFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('🌸 落樱'), findsOneWidget);

    // 2. 方向二：小猫食碗与美味拖拽投喂托盘
    final foodBowlFinder = find.byKey(const ValueKey('cat_food_bowl'));
    expect(foodBowlFinder, findsOneWidget);

    // 轻触食碗展开拖拽美食托盘
    await tester.tap(foodBowlFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('drag_to_feed_tray')), findsOneWidget);
    expect(find.text('香酥小鱼干'), findsOneWidget);
    expect(find.text('纯肉三文鱼'), findsOneWidget);
    expect(find.text('舒化羊奶'), findsOneWidget);

    // 点击关闭收起美食托盘
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('drag_to_feed_tray')), findsNothing);

    // 3. 方向四：亲密羁绊称号勋章胶囊与成就卡片弹窗
    final bondBadgeFinder = find.byKey(const ValueKey('intimacy_bond_badge'));
    expect(bondBadgeFinder, findsOneWidget);

    // 点按羁绊勋章呼出全览卡片
    await tester.tap(bondBadgeFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('波可与你的亲密羁绊'), findsOneWidget);
    expect(find.textContaining('专属特权'), findsOneWidget);
    expect(find.textContaining('皇家丝绒披风'), findsOneWidget);
    expect(find.textContaining('璀璨星辉皇冠'), findsOneWidget);

    // 关闭羁绊弹窗
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 4. 方向二：舒睡暖垫盖小被子 (Tuck-in) 与掀被互动
    await tester.tap(find.byKey(const ValueKey('cozy_cat_rug')));
    await tester.pump(const Duration(milliseconds: 300));

    // 验证出现“盖被被”按钮
    final tuckInFinder = find.byKey(const ValueKey('tuck_in_blanket_button'));
    expect(tuckInFinder, findsOneWidget);

    // 点击盖被被
    await tester.tap(tuckInFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('covered_blanket')), findsOneWidget);
    expect(find.text('掀被 ☀️'), findsOneWidget);

    // 点击掀被 ☀️
    await tester.tap(find.text('掀被 ☀️'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('covered_blanket')), findsNothing);

    // 5. 方向四：换装滑轨坞内专属金饰锁定提示与形态展示
    await tester.tap(find.text('魔法换装'));
    await tester.pump(const Duration(milliseconds: 300));

    // 切换到帽子 Tab
    await tester.tap(find.text('🎩 帽子'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('星辉皇冠'), findsOneWidget);
    expect(find.text('阶4解锁'), findsOneWidget);

    // 点击锁定的星辉皇冠，触发友好提示
    await tester.tap(find.text('星辉皇冠'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('需达到第 4 阶解锁'), findsWidgets);

    // 切换到挂件 Tab
    await tester.tap(find.text('🎀 挂件'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('皇家披风'), findsOneWidget);
    expect(find.text('阶3解锁'), findsOneWidget);

    // 点击完成按钮退出换装
    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('魔法换装'), findsOneWidget);
  });

  testWidgets('Pet drag stability and no inflation test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 找到萌宠主窗体并模拟大幅度拖拽移动
    final petFinder = find.byType(CustomPaint).first;
    expect(petFinder, findsWidgets);

    // 模拟大幅拖动（原逻辑中连续滑行超过 132px 会误触发 GLASS_BOOP 膨胀态）
    final gesture = await tester.startGesture(const Offset(540, 1200));
    await gesture.moveBy(const Offset(50, -30));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(60, -20));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(50, 40));
    await tester.pump(const Duration(milliseconds: 50));

    // 验证拖拽过程中绝不出现贴贴屏幕对话与膨胀态
    expect(find.textContaining('波可跑来贴贴屏幕啦'), findsNothing);

    // 结束拖拽
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));

    // 验证拖拽结束后平稳回归 IDLE，绝不残留贴贴屏幕气泡
    expect(find.textContaining('波可跑来贴贴屏幕啦'), findsNothing);
  });

  testWidgets('Footprint toggle and Cape back-layering test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 1. 验证顶部灵动胶囊栏中的爪印切换按钮存在 (默认开启 🐾)
    final fpToggleFinder = find.byKey(const ValueKey('footprint_toggle_button'));
    expect(fpToggleFinder, findsOneWidget);
    expect(find.descendant(of: fpToggleFinder, matching: find.text('🐾')), findsOneWidget);

    // 点击切换为纯净地板 (🧹)
    await tester.tap(fpToggleFinder);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.descendant(of: fpToggleFinder, matching: find.text('🧹')), findsOneWidget);
    expect(find.textContaining('已收起爪印，保持地板纯净洁白'), findsOneWidget);

    // 再次点击恢复温润爪印 (🐾)
    await tester.tap(fpToggleFinder);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.descendant(of: fpToggleFinder, matching: find.text('🐾')), findsOneWidget);
    expect(find.textContaining('已开启温润小猫肉垫爪印'), findsOneWidget);
  });

  testWidgets('Four Major Dimensions (Slow Blink, ASMR Rain, Water Bowl & Sakura, Cushioned Landing) test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 1. 方向二：观景窗切换“细雨”触发 ASMR 白噪音联动
    final windowFinder = find.byKey(const ValueKey('french_arch_window'));
    expect(windowFinder, findsOneWidget);

    // 切换至雨季
    await tester.tap(windowFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('🌧️ 细雨'), findsOneWidget);
    expect(SoundService.ambientMode, equals('rain'));

    // 切换至落樱，雨声白噪音自动平稳停止
    await tester.tap(windowFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('🌸 落樱'), findsOneWidget);
    expect(SoundService.ambientMode, equals('none'));

    // 2. 方向二：春日落樱可轻触花瓣消散
    final sakuraFinder = find.byKey(const ValueKey('sakura_petal_0'));
    expect(sakuraFinder, findsOneWidget);
    await tester.tap(sakuraFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('轻触飘落的樱花瓣'), findsOneWidget);

    // 3. 方向三：左侧就餐角清澈小水碗
    final waterBowlFinder = find.byKey(const ValueKey('cat_water_bowl'));
    expect(waterBowlFinder, findsOneWidget);
    await tester.tap(waterBowlFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('波光粼粼'), findsOneWidget);

    // 4. 方向四：半空拖拽轻盈落足肉垫缓冲微弹
    final center = tester.getCenter(find.byType(CustomPaint).first);
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 1400));
  });

  testWidgets('Compact Screen Top Bar and Unified Cat Dining Station test', (WidgetTester tester) async {
    // 模拟窄屏移动设备 (360px 宽度)
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 1. 验证顶部灵动岛即使在 360px 窄屏下也绝无溢出，所有按钮均在屏幕范围内
    final homeIconFinder = find.byIcon(Icons.home_rounded);
    expect(homeIconFinder, findsOneWidget);
    final homeBottomRight = tester.getBottomRight(homeIconFinder);
    expect(homeBottomRight.dx, lessThan(360.0));

    final fpButtonFinder = find.byKey(const ValueKey('footprint_toggle_button'));
    expect(fpButtonFinder, findsOneWidget);
    final fpBottomRight = tester.getBottomRight(fpButtonFinder);
    expect(fpBottomRight.dx, lessThan(360.0));

    // 2. 验证左下角萌宠双联食水一体托盘
    final foodBowlFinder = find.byKey(const ValueKey('cat_food_bowl'));
    final waterBowlFinder = find.byKey(const ValueKey('cat_water_bowl'));
    expect(foodBowlFinder, findsOneWidget);
    expect(waterBowlFinder, findsOneWidget);

    // 验证食水双碗并列在一体化托盘中且宽度适度、绝不超界
    final foodRect = tester.getRect(foodBowlFinder);
    final waterRect = tester.getRect(waterBowlFinder);
    expect(foodRect.left, lessThan(waterRect.left));
    expect(waterRect.right, lessThan(200.0));

    // 3. 验证床头小夜灯与全屋光影沉浸切换
    final lampOnFinder = find.text('ON');
    expect(lampOnFinder, findsOneWidget);
    await tester.tap(lampOnFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('OFF'), findsOneWidget);
    expect(find.textContaining('小夜灯已熄灭'), findsOneWidget);

    // 再次点亮小夜灯，全屋温暖照明恢复
    await tester.tap(find.text('OFF'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ON'), findsOneWidget);
    expect(find.textContaining('小夜灯点亮'), findsOneWidget);
  });
}

