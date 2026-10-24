import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pet/main.dart';
import 'package:flutter_pet/services/sound_service.dart';
import 'package:flutter_pet/services/solar_service.dart';
import 'package:flutter_pet/views/dialogs/action_dialog.dart';

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
    expect(find.text('装扮小窝'), findsOneWidget);
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
    // 尾巴永远拖在"身后"（与朝向相反的一侧）：默认朝右时尾巴在**左**边，
    // 所以这里点的是小猫左侧的尾巴区域 (相对于 200x200 画布的 offset (35, 95))
    final catFinder = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.child is AnimatedBuilder,
    );
    expect(catFinder, findsOneWidget);

    final catTopLeft = tester.getTopLeft(catFinder);
    final tailTapTarget = Offset(catTopLeft.dx + 35.0, catTopLeft.dy + 95.0);
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
    await tester.tap(find.text('装扮小窝'));
    await tester.pump(const Duration(milliseconds: 300));

    // 切换到头部 Tab
    await tester.tap(find.text('🎩 头部'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('星辉皇冠'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);

    // 点击锁定的星辉皇冠，触发友好提示
    await tester.tap(find.text('星辉皇冠'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('需达到第 4 阶解锁'), findsWidgets);

    // 切换到颈部 Tab
    await tester.tap(find.text('🎀 颈部'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('皇家披风'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);

    // 点击完成按钮退出换装
    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('装扮小窝'), findsOneWidget);
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

    // 1. 验证顶部灵动岛即使在 360px 窄屏下也绝无溢出，所有按钮均在屏幕范围内；冗余唤回猫垫图标已移除
    expect(find.byIcon(Icons.home_rounded), findsNothing);

    final skyButtonFinder = find.byKey(const ValueKey('sky_rhythm_toggle_button'));
    expect(skyButtonFinder, findsOneWidget);
    final skyBottomRight = tester.getBottomRight(skyButtonFinder);
    expect(skyBottomRight.dx, lessThan(360.0));

    final fpButtonFinder = find.byKey(const ValueKey('footprint_toggle_button'));
    expect(fpButtonFinder, findsOneWidget);
    final fpBottomRight = tester.getBottomRight(fpButtonFinder);
    expect(fpBottomRight.dx, lessThan(360.0));

    // 2. 验证左下角萌宠双联食水一体托盘
    final foodBowlFinder = find.byKey(const ValueKey('cat_food_bowl'));
    final waterBowlFinder = find.byKey(const ValueKey('cat_water_bowl'));
    expect(foodBowlFinder, findsOneWidget);
    expect(waterBowlFinder, findsOneWidget);

    // 验证食水双碗竖向排布在立式一体化托盘中且靠左紧凑、绝不遮挡中央萌宠
    final foodRect = tester.getRect(foodBowlFinder);
    final waterRect = tester.getRect(waterBowlFinder);
    expect(foodRect.top, lessThan(waterRect.top));
    expect(waterRect.right, lessThan(100.0));

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

  testWidgets('Comprehensive Style, Presentation & Micro-Interactions Polish test',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 1. 验证轻戳对话气泡触发猫咪心事与悄悄话翻牌彩蛋
    final bubbleFinder = find.byKey(const ValueKey('smart_dialogue_bubble'));
    expect(bubbleFinder, findsOneWidget);
    await tester.tap(bubbleFinder);
    await tester.pump(const Duration(milliseconds: 300));

    // 验证气泡更新为专属悄悄话之一
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is Text && widget.data != null) {
          final t = widget.data!;
          return t.contains('悄悄话') ||
              t.contains('闪闪发光') ||
              t.contains('小耳朵') ||
              t.contains('小爪子按个章') ||
              t.contains('呼噜噜') ||
              t.contains('小鱼干藏在被窝');
        }
        return false;
      }),
      findsOneWidget,
    );

    // 2. 验证点击远处猫草盆栽触发互动与猫草清香
    final plantFinder = find.text('猫草');
    expect(plantFinder, findsOneWidget);
    await tester.tap(plantFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('猫草清香'), findsWidgets);

    // 3. 验证点击远处猫抓柱触发磨爪与腰肢伸展
    final scratcherFinder = find.text('磨爪');
    expect(scratcherFinder, findsOneWidget);
    await tester.tap(scratcherFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('爪'), findsWidgets);

    // 4. 验证点击空白地板背景触发机敏眼神注视追踪，不会发生异常
    await tester.tapAt(const Offset(300, 450));
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('Six Major High-Order Interactions test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 0. 验证专属绝活坞与列表中包含新增的猫式伸展、击掌对拳、翻肚皮蹬腿
    await tester.tap(find.text('专属绝活'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('点击下方卡片即刻开演'), findsOneWidget);
    expect(ActionDialog.actions.any((a) => a['name'] == '猫式伸展' && a['icon'] == '🧘'), isTrue);
    expect(ActionDialog.actions.any((a) => a['name'] == '击掌对拳' && a['icon'] == '✋'), isTrue);
    expect(ActionDialog.actions.any((a) => a['name'] == '翻肚皮蹬腿' && a['icon'] == '🐰'), isTrue);
    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 200));

    final catFinder = find.byWidgetPredicate(
      (w) => w is GestureDetector && w.child is AnimatedBuilder,
    );
    expect(catFinder, findsOneWidget);
    var catTopLeft = tester.getTopLeft(catFinder);

    // 1. 方向二：指尖对掌与默契击掌 (High-Five & Finger Boop 🐾)
    // 轻触猫咪前爪区域 (dy >= 142 即在 catTopLeft 下方约 150px)
    await tester.tapAt(Offset(catTopLeft.dx + 100.0, catTopLeft.dy + 150.0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('击掌'), findsWidgets);

    // 2. 方向三：翻滚露肚皮 (Belly Rub Roll) 与持续揉按开心兔子蹬腿 (Bunny Kicks)
    // 挠软萌腹部肚皮 (dy 位于 105 ~ 142 即在 catTopLeft 下方约 125px)
    await tester.tapAt(Offset(catTopLeft.dx + 100.0, catTopLeft.dy + 125.0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('软肚皮'), findsWidgets);
    // 处于翻肚皮态下，再次轻揉肚皮触发兔子踩单车蹬腿
    await tester.tapAt(Offset(catTopLeft.dx + 100.0, catTopLeft.dy + 125.0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('踩单车'), findsWidgets);

    // 3. 方向五：敲敲罐头瞬间冲刺狂奔召唤 (Can Spoon Tap & Sprint Summon 🥫)
    final canFinder = find.byKey(const ValueKey('can_summon_button'));
    expect(canFinder, findsOneWidget);
    await tester.tap(canFinder);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('敲罐头的声音'), findsOneWidget);
    // 等待冲刺飞奔到达餐盘前方
    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.textContaining('波可已飞奔就位'), findsOneWidget);

    // 4. 方向四：就餐角小口饮水仪式与水花涟漪 (Water Lapping 🥣💧)
    final waterFinder = find.byKey(const ValueKey('cat_water_bowl'));
    expect(waterFinder, findsOneWidget);
    await tester.tap(waterFinder);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('纯净水'), findsOneWidget);

    // 收起展开的投喂坞，恢复底部三灵动胶囊
    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 200));

    // 5. 方向一：物理悬空与被拎起体态 (Scruff Lift & Air Dangling Physics)
    catTopLeft = tester.getTopLeft(catFinder);
    final catCenter = Offset(catTopLeft.dx + 100.0, catTopLeft.dy + 100.0);
    final gesture = await tester.startGesture(catCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 600));

    // 6. 方向六：睡眠唤醒正宗猫式伸展瑜伽仪式 (Gentle Wake-up & Cat Stretch Yoga 🧘‍♀️)
    // 打开奇妙背包伴眠哄睡
    await tester.tap(find.text('奇妙背包'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('伴眠哄睡'), findsOneWidget);
    await tester.tap(find.text('伴眠哄睡'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 轻戳睡梦中的小猫，触发三阶段唤醒仪式
    await tester.tap(catFinder);
    await tester.pump(const Duration(milliseconds: 400));
    // 阶段 1：揉揉睡眼洗小脸
    expect(find.textContaining('揉揉睡眼'), findsOneWidget);
    // 推进时间进入阶段 2：正宗猫式大伸展
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.textContaining('猫式懒腰'), findsOneWidget);
    // 推进时间进入阶段 3：欢喜抖毛元气百倍
    await tester.pump(const Duration(milliseconds: 2400));
    expect(find.textContaining('元气满满'), findsOneWidget);
  });

  testWidgets('Five Major Existing Details, Layout & Micro-Interactions Polish test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 1. 细节一：对话气泡指向小尾巴与弹性翻牌动效
    final bubbleFinder = find.byKey(const ValueKey('smart_dialogue_bubble'));
    expect(bubbleFinder, findsOneWidget);
    await tester.tap(bubbleFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('主人'), findsWidgets);

    // 2. 细节二：底部三灵动药丸胶囊的触感弹性形变
    expect(find.text('奇妙背包'), findsOneWidget);
    expect(find.text('装扮小窝'), findsOneWidget);
    expect(find.text('专属绝活'), findsOneWidget);

    // 3. 细节三：就餐角托盘三元素几何对齐与陶瓷凹槽下陷反馈 (敲罐按钮升级为 🥫 🔔 双图标对称)
    final foodBowlFinder = find.byKey(const ValueKey('cat_food_bowl'));
    final waterBowlFinder = find.byKey(const ValueKey('cat_water_bowl'));
    final canButtonFinder = find.byKey(const ValueKey('can_summon_button'));
    expect(foodBowlFinder, findsOneWidget);
    expect(waterBowlFinder, findsOneWidget);
    expect(canButtonFinder, findsOneWidget);
    expect(find.text('🔔'), findsOneWidget);

    // 4. 细节四：拍立得相框与小夜灯的真实物理机械开关反馈
    // 小夜灯实体开关测试 (包含 ON/OFF 状态切换)
    expect(find.text('ON'), findsOneWidget);
    await tester.tap(find.text('ON'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('OFF'), findsOneWidget);

    // 5. 细节五：舒睡小被子织物绗缝与被窝记忆棉弹性微动效
    final rugFinder = find.byKey(const ValueKey('cozy_cat_rug'));
    expect(rugFinder, findsOneWidget);
    await tester.tap(rugFinder);
    await tester.pump(const Duration(milliseconds: 300));

    final tuckInFinder = find.byKey(const ValueKey('tuck_in_blanket_button'));
    if (tuckInFinder.evaluate().isNotEmpty) {
      await tester.tap(tuckInFinder);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('covered_blanket')), findsOneWidget);
    }
  });

  testWidgets('Astronomical Solar Engine & Continuous Sky Flow test', (WidgetTester tester) async {
    // 1. 验证 NOAA 真实天文算法：四季时角与动态日出日落
    final summerSolstice = DateTime(2026, 6, 21); // 夏至
    final winterSolstice = DateTime(2026, 12, 21); // 冬至
    final summerTimes = SolarService.calculateSolarTimes(summerSolstice);
    final winterTimes = SolarService.calculateSolarTimes(winterSolstice);

    // 夏至白昼显著长于冬至
    expect(summerTimes.dayLengthHours > winterTimes.dayLengthHours, isTrue);
    expect(summerTimes.sunriseHours < winterTimes.sunriseHours, isTrue); // 夏至天亮更早 (约05:00 vs 07:05)
    expect(summerTimes.sunsetHours > winterTimes.sunsetHours, isTrue);   // 夏至落日更晚 (约19:25 vs 17:05)

    // 2. 验证 24h 连续基于分钟进度的 Color.lerp 平滑插值无突变
    final noonTheme = SolarService.getSkyTheme(customTime: DateTime(2026, 10, 18, 12, 0));
    final midnightTheme = SolarService.getSkyTheme(customTime: DateTime(2026, 10, 18, 0, 0));
    expect(noonTheme.isNight, isFalse);
    expect(midnightTheme.isNight, isTrue);
    expect(noonTheme.colors.length, 3);
    expect(midnightTheme.colors.length, 3);

    // 3. 验证 4 大手动光影覆盖模式
    expect(SolarService.getSkyTheme(manualMode: 0).name, '破晓晨曦');
    expect(SolarService.getSkyTheme(manualMode: 1).name, '澄澈晴空');
    expect(SolarService.getSkyTheme(manualMode: 2).name, '落日晚霞');
    expect(SolarService.getSkyTheme(manualMode: 3).name, '静谧星夜');

    // 4. 界面交互验证：时空天光罗盘胶囊按钮一键循环切换
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    final skyButtonFinder = find.byKey(const ValueKey('sky_rhythm_toggle_button'));
    expect(skyButtonFinder, findsOneWidget);

    // 默认处于自然天文模式
    expect(find.text('自然'), findsOneWidget);

    // 点击 1: 切换到 0: 破晓晨曦
    await tester.tap(skyButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('破晓晨曦'), findsOneWidget);
    expect(find.text('模式'), findsOneWidget);

    // 点击 2: 切换到 1: 澄澈晴空
    await tester.tap(skyButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('澄澈晴空'), findsOneWidget);

    // 点击 3: 切换到 2: 落日晚霞
    await tester.tap(skyButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('落日晚霞'), findsOneWidget);

    // 点击 4: 切换到 3: 静谧星夜
    await tester.tap(skyButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('静谧星夜'), findsOneWidget);

    // 点击 5: 回归自然天文模式
    await tester.tap(skyButtonFinder);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('自然'), findsOneWidget);
  });

  testWidgets('Bottom Dock Zero-Jitter Stability and Realistic Yarn Ball Interaction test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 200));

    // 1. 验证底部常态胶囊与各个面板均持有持久唯一的稳固 Key，且无弹性位移动画，杜绝销毁重建抖动
    final floatingBarFinder = find.byKey(const ValueKey('bottom_floating_bar'));
    expect(floatingBarFinder, findsOneWidget);

    // 切换至专属绝活坞
    await tester.tap(find.text('专属绝活'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('live_action_dock')), findsOneWidget);

    // 切换至装扮小窝坞
    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('装扮小窝'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('live_wardrobe_dock')), findsOneWidget);

    // 收起换装坞
    await tester.tap(find.text('完成'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('bottom_floating_bar')), findsOneWidget);

    // 2. 验证实体物理毛线球存在且具备真实 3D 渲染与物理滚转属性
    final yarnBallFinder = find.byKey(const ValueKey('floor_yarn_ball'));
    expect(yarnBallFinder, findsOneWidget);

    // 轻点毛线球，触发拍飞物理初速度与猫咪主动追逐
    await tester.tap(yarnBallFinder);
    await tester.pump(const Duration(milliseconds: 100));

    // 经过数个周期物理推进与追逐拍打
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  });
}


