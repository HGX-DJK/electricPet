import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android 原生桌面悬浮窗 (SYSTEM_ALERT_WINDOW) 源码守护测试。
///
/// 背景：「桌面悬浮宠无法拖动」这个缺陷在历史上被修好又改坏过两次：
///   - ea7df41 修好：窗口标志用 FLAG_NOT_TOUCH_MODAL + FLAG_LAYOUT_IN_SCREEN
///   - 03fc3a9 改坏：为解决「拖到屏幕边缘丢事件」换回 FLAG_LAYOUT_NO_LIMITS，
///     顺带丢掉了 FLAG_NOT_TOUCH_MODAL —— 悬浮窗可触达区域失效、触摸命中不到宠物
///   - 2145509 再改坏：把「仅近边轻吸附」换成「无条件强制磁吸到最近边缘」，
///     松手必被拽回屏幕边，放哪儿都不算数，用户再次反馈「宠物拖不动」
///
/// 另有两条悬浮宠协同不变量：
///   - 双击桌面悬浮猫打开小窝时，桌面悬浮猫必须让位，否则与 App 内的猫叠成两只
///   - App 内切换品种后，桌面悬浮猫必须实时换装，不能还停在旧品种
///
/// 原生行为无法用 widget 测试覆盖，但这些关键约束可以用源码断言固化，
/// 让回归在 CI 的 `flutter test` 阶段就被拦下，而不是等用户装到手机上才发现。
void main() {
  late Directory packageRoot;
  late String serviceSource;
  late String activitySource;
  late String petViewSource;
  late String overlayChannelKotlin;
  late String overlayChannelDart;
  late String overlayServiceSource;
  late String petModelSource;

  setUpAll(() {
    packageRoot = _findPackageRoot();
    serviceSource = _readRepoFile(
      packageRoot,
      'android/app/src/main/kotlin/com/electricpet/poko/FloatingPetService.kt',
    );
    activitySource = _readRepoFile(
      packageRoot,
      'android/app/src/main/kotlin/com/electricpet/poko/MainActivity.kt',
    );
    petViewSource = _readRepoFile(
      packageRoot,
      'android/app/src/main/kotlin/com/electricpet/poko/PokoPetView.kt',
    );
    overlayChannelKotlin = _readRepoFile(
      packageRoot,
      'android/app/src/main/kotlin/com/electricpet/poko/OverlayChannel.kt',
    );
    overlayChannelDart = _readRepoFile(packageRoot, 'lib/services/overlay_channel.dart');
    overlayServiceSource = _readRepoFile(packageRoot, 'lib/services/overlay_service.dart');
    petModelSource = _readRepoFile(packageRoot, 'lib/models/pet_model.dart');
  });

  group('Android 原生悬浮窗拖拽约束守护', () {
    test('悬浮宠物窗口必须使用 FLAG_NOT_TOUCH_MODAL + FLAG_LAYOUT_IN_SCREEN', () {
      final petWindow = _layoutParamsBlock(serviceSource, 'pokoParams = WindowManager.LayoutParams(');

      expect(petWindow, contains('FLAG_NOT_FOCUSABLE'),
          reason: '悬浮窗不应抢占键盘焦点，否则会打断用户正在使用的应用');
      expect(petWindow, contains('FLAG_NOT_TOUCH_MODAL'),
          reason: '缺少 FLAG_NOT_TOUCH_MODAL，悬浮窗会变成触摸模态吞掉整屏点击，底层应用点不动');
      expect(petWindow, contains('FLAG_LAYOUT_IN_SCREEN'),
          reason: '缺少 FLAG_LAYOUT_IN_SCREEN，窗口不按物理屏幕坐标系布局，坐标与可触达区域都会算错');
      expect(petWindow, isNot(contains('FLAG_LAYOUT_NO_LIMITS')),
          reason: 'FLAG_LAYOUT_NO_LIMITS 会让窗口脱离屏幕裁剪，Android 10+ 上触摸命中失效，正是拖不动的根因');
    });

    test('萌言萌语气泡窗口可点击回小窝，但不能吞掉宠物与底层应用的点击', () {
      final bubbleWindow = _layoutParamsBlock(serviceSource, 'bubbleParams = WindowManager.LayoutParams(');

      expect(bubbleWindow, contains('FLAG_NOT_TOUCH_MODAL'),
          reason: '气泡必须透传窗口外的触摸，否则会挡住宠物与底层应用');
      expect(bubbleWindow, isNot(contains('FLAG_NOT_TOUCHABLE')),
          reason: '气泡需要可点（点一下回小窝），FLAG_NOT_TOUCHABLE 会让它收不到点击');
      expect(serviceSource, contains('setOnClickListener'),
          reason: '气泡未绑定点击事件');
      expect(bubbleWindow, isNot(contains('FLAG_LAYOUT_NO_LIMITS')),
          reason: '气泡同样不应脱离屏幕裁剪，否则位置计算与实际显示会错位');
    });

    test('拖拽管线完整：监听触摸 -> 跟随移动 -> 实时更新窗口位置', () {
      expect(serviceSource, contains('setOnTouchListener'), reason: '缺少触摸监听，宠物无法拖动');
      expect(serviceSource, contains('MotionEvent.ACTION_DOWN'));
      expect(serviceSource, contains('MotionEvent.ACTION_MOVE'));
      expect(serviceSource, contains('MotionEvent.ACTION_UP'));
      expect(serviceSource, contains('windowManager?.updateViewLayout'),
          reason: '缺少 updateViewLayout，按下后窗口位置不会跟随手指');
      expect(serviceSource, contains('onDragStateChanged'), reason: '缺少拖拽状态反馈');
    });

    test('位置更新失败必须写日志，不允许静默吞掉异常', () {
      final moveBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_MOVE ->',
        'MotionEvent.ACTION_UP',
      );

      expect(moveBranch, contains('Log.e'),
          reason: 'updateViewLayout 异常被静默吞掉时，线上完全无法定位「拖不动」问题');
    });

    test('贴边吸附阈值必须小于初始停靠间距，否则宠物会被吸回原位', () {
      final threshold = _intAfter(serviceSource, 'val edgeThreshold = (');
      final dockGap = _intAfter(serviceSource, 'x = (screenWidth - sizePx - (');

      expect(threshold, isNotNull, reason: '未找到贴边吸附阈值');
      expect(dockGap, isNotNull, reason: '未找到初始停靠间距');
      expect(threshold!, lessThan(dockGap!),
          reason: '吸附阈值($threshold) >= 初始停靠间距($dockGap) 时，用户刚拖动一点点宠物就会被吸回原位，表现为「拖不动」');
    });
  });

  group('松手落位：必须允许自由放置，禁止无条件强制吸边', () {
    test('松手落位函数必须区分「近边吸附」与「自由停留」两条分支', () {
      final settle = _between(
        serviceSource,
        'private fun settleAfterDrag',
        'private fun isDockedAtEdge',
      );

      expect(settle, contains('if (!enableEdgeSnap || !isDockedAtEdge('),
          reason: '松手时必须先判断是否靠近边缘；未靠近时应原地停留，不能强制拉回屏幕边');
      expect(settle, contains('saveDockPreference(isLeftHalf, params.x, params.y)'),
          reason: '自由停留时必须保存当前落点，否则重启后又被拽回边缘');
    });

    test('拖拽释放必须走自由落位逻辑，而不是无条件磁吸贴边', () {
      final upBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_UP -> {',
        'private fun refreshPetVisibility',
      );

      expect(upBranch, contains('settleAfterDrag'),
          reason: '拖拽释放未走 settleAfterDrag，自由放置能力失效');
      expect(upBranch, isNot(contains('snapToNearestEdge')),
          reason: 'snapToNearestEdge 是无条件强制吸边的旧实现，必须彻底移除');
      expect(serviceSource, isNot(contains('snapToNearestEdge')),
          reason: '旧的无条件强制吸边实现仍留在代码里，用户松手后宠物必然弹回屏幕边');
    });

    test('自由放置的横向位置必须持久化，重启与旋转后不得被拽回边缘', () {
      expect(serviceSource, contains('putFloat("flutter.poko_dock_x_ratio", xRatio)'),
          reason: '横向落点未持久化，重启后宠物会跳回屏幕边缘');
      expect(serviceSource, contains('getFloat("flutter.poko_dock_x_ratio", -1f)'),
          reason: '未读取持久化的横向落点');
      expect(serviceSource, contains('savedXRatio'),
          reason: '启动时未按比例还原用户放置的横向位置');
    });

    test('边缘动效（探头避让 / 自主散步）只能在贴边时触发', () {
      expect(serviceSource, contains('private fun isDockedAtEdge('),
          reason: '缺少贴边判定，自由放在屏幕中间的波可会被边缘动效拽走');
      expect(serviceSource, contains('if (!isPetDockedAtEdge()) return'),
          reason: '探头避让未做贴边校验，自由放置的波可会被拉出屏幕外');
      expect(serviceSource, contains('if (!isDockedAtEdge(params, sizePx, density, screenWidth)) return'),
          reason: '自主边缘散步未做贴边校验');
    });
  });

  group('拖拽手感：按下归位 / 长按 / 探头状态三不得互相打架', () {
    test('按下瞬间必须直接归位，不得用动画与拖拽抢写窗口坐标', () {
      final downBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_DOWN ->',
        'MotionEvent.ACTION_MOVE ->',
      );

      expect(downBranch, contains('restoreFromPeeking(animated = false)'),
          reason: '按下时若走归位动画，动画会逐帧改写 params.x，与拖拽互相覆盖，表现为起手跳变、按不住');
    });

    test('探头动画被取消时不得误标记为探头状态', () {
      final peekBlock = _between(
        serviceSource,
        'private fun scheduleEdgePeeking',
        'private fun isPetDockedAtEdge',
      );

      expect(peekBlock, contains('override fun onAnimationCancel(animation: Animator)'),
          reason: '缺少 onAnimationCancel 回调，无法区分"探头完成"与"被中途取消"；'
              'Android 在 cancel() 时同样回调 onAnimationEnd，误判会让每次按下都被强行拉回屏幕边');
      expect(peekBlock, contains('isPeeking = !cancelled'),
          reason: '探头状态必须结合取消标记判定');
      expect(serviceSource, isNot(contains('animation.isCanceled')),
          reason: 'Animator.isCanceled 不是公开 SDK API，使用它会导致 Android 端编译失败'
              '（已在 CI 的 compileReleaseKotlin 阶段报错）');
    });

    test('长按不得吞掉已经发生拖拽的释放落位', () {
      final longPressBranch = _between(
        serviceSource,
        'if (isLongPressing) {',
        'if (isClick) {',
      );

      expect(longPressBranch, contains('if (!hasDragged)'),
          reason: '长按分支必须只在「完全没有拖动」时才吞掉释放；否则「先按住半秒再拖」与「快速拖」结果不一致');
    });

    test('探头避让只能改绘制偏移，绝不能移动窗口', () {
      final peekBlock = _between(
        serviceSource,
        'private fun scheduleEdgePeeking',
        'private fun isPetDockedAtEdge',
      );

      expect(peekBlock, contains('view.peekOffsetX = peekOffset * f'),
          reason: '探头必须通过窗口内的绘制偏移实现');
      expect(peekBlock, isNot(contains('peekTargetX')),
          reason: '旧实现靠移动窗口做探头，窗口 x 会落到屏幕之外，'
              '而拖拽坐标钳制范围是 [0, screenWidth - sizePx]，'
              '拖拽起始坐标被钉死在边缘 —— 这正是「宠物拖不动」的根因');
      expect(petViewSource, contains('var peekOffsetX: Float'),
          reason: 'PokoPetView 缺少探头绘制偏移属性');
      expect(petViewSource, contains('canvas.translate(peekOffsetX, 0f)'),
          reason: '绘制管线未应用探头偏移');
    });

    test('从探头恢复时不得移动窗口', () {
      final restoreBlock = _between(
        serviceSource,
        'private fun restoreFromPeeking',
        'private fun startAsForeground',
      );

      expect(restoreBlock, isNot(contains('params.x =')),
          reason: '恢复可见时移动窗口会让拖拽起点落到屏幕外并被坐标钳制，宠物被钉死在边缘');
      expect(restoreBlock, contains('view.peekOffsetX = 0f'),
          reason: '恢复可见应复位绘制偏移而不是搬动窗口');
    });

    test('系统中断手势 (ACTION_CANCEL) 不得当成松手处理', () {
      // 只看宠物自身的触摸监听器：菜单按钮里的 UP/CANCEL 合并写法是合法的
      final petTouchBlock = _between(
        serviceSource,
        'private fun setupTouchListener',
        'private fun refreshPetVisibility',
      );

      expect(petTouchBlock, contains('MotionEvent.ACTION_CANCEL ->'),
          reason: '缺少独立的 ACTION_CANCEL 分支');
      expect(petTouchBlock, isNot(contains('MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL ->')),
          reason: 'ACTION_CANCEL 与 ACTION_UP 必须分开处理，否则系统中断手势时'
              '宠物会被误判为拖拽结束而吸附回边缘，看起来又像拖不动');
    });

    test('服务启动必须打印拖拽修复版本标记', () {
      expect(serviceSource, contains('const val DRAG_FIX_VERSION'),
          reason: '缺少版本标记，无法确认用户手机上装的是否是包含拖拽修复的新包');
      expect(serviceSource, contains('Log.i(TAG, "悬浮宠服务启动'),
          reason: '启动日志未打印版本标记');
      expect(serviceSource, contains(r'$DRAG_FIX_VERSION'),
          reason: '启动日志没有带上版本标记值');
    });
  });

  group('悬浮窗族标志位一致性', () {
    test('快捷控制菜单窗口必须与宠物窗口一致使用 FLAG_NOT_TOUCH_MODAL', () {
      final menuWindow = _layoutParamsBlock(serviceSource, 'actionMenuParams = WindowManager.LayoutParams(');

      expect(menuWindow, contains('FLAG_NOT_TOUCH_MODAL'),
          reason: '菜单窗口缺 FLAG_NOT_TOUCH_MODAL，一旦将来可获焦就会变成触摸模态窗口吞掉整屏点击，宠物彻底拖不动');
    });

    test('快捷菜单隐藏后必须真正移除窗口，不能一直挂在 WindowManager 上', () {
      expect(serviceSource, contains('private fun removeActionMenuWindow()'),
          reason: '缺少移除菜单窗口的逻辑');
      expect(serviceSource, contains('isActionMenuAttached = false'),
          reason: '菜单窗口移除后未复位挂载标记，重复 addView 会抛异常被静默吞掉，菜单再也不出现');
    });
  });

  group('交互增强：分区触摸 / 视线跟随 / 物理手感', () {
    test('分区触摸必须按头 / 身 / 尾 / 爪给出不同反应', () {
      expect(petViewSource, contains('enum class TouchZone { HEAD, BODY, TAIL, PAW, NONE }'),
          reason: '缺少身体分区枚举');
      expect(petViewSource, contains('fun hitTest(x: Float, y: Float): TouchZone'),
          reason: '缺少分区命中判定');
      expect(petViewSource, contains('fun reactToTouch(zone: TouchZone): Boolean'),
          reason: '缺少分区反应');
      expect(serviceSource, contains('private fun handleZoneTap(touchX: Float, touchY: Float)'),
          reason: '服务层未按分区派发单击');
      expect(serviceSource, contains('pokoView?.hitTest(touchX, touchY)'),
          reason: '单击未使用视图局部坐标做命中判定');
    });

    test('视线跟随必须复用已有瞳孔偏移，且只在待机时生效', () {
      expect(petViewSource, contains('fun setGazeTarget(x: Float, y: Float)'),
          reason: '缺少视线目标设置');
      expect(petViewSource, contains('fun clearGazeTarget()'),
          reason: '缺少视线目标清除');
      expect(petViewSource, contains('private fun updateGaze()'),
          reason: '缺少视线缓动解算');
      expect(petViewSource, contains('updateGaze()'),
          reason: '视线解算未接入待机动画');
    });

    test('拎起悬空必须等到真正开始拖动才触发', () {
      final downBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_DOWN ->',
        'MotionEvent.ACTION_POINTER_DOWN ->',
      );
      final moveBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_MOVE ->',
        'MotionEvent.ACTION_CANCEL ->',
      );

      expect(downBranch, isNot(contains('onDragStateChanged(true)')),
          reason: '按下就切"拎起"会让单击出现拎起-落地的抽搐');
      expect(moveBranch, contains('onDragStateChanged(true)'),
          reason: '超过拖拽阈值后必须切到拎起悬空');
    });

    test('松手必须有惯性滑行，不能瞬间停住', () {
      final upBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_UP ->',
        'else -> false',
      );

      expect(serviceSource, contains('private fun flingAndSettle('),
          reason: '缺少惯性滑行实现');
      expect(upBranch, contains('flingAndSettle('),
          reason: '松手未走惯性滑行');
      expect(serviceSource, contains('import kotlin.math.exp'),
          reason: '惯性滑行缺少摩擦模型所需的 exp');
    });

    test('双指手势必须支持缩放大小与旋转翻面', () {
      final pointerDown = _between(
        serviceSource,
        'MotionEvent.ACTION_POINTER_DOWN ->',
        'MotionEvent.ACTION_POINTER_UP ->',
      );

      expect(pointerDown, contains('pointerDistance(event)'),
          reason: '缺少双指距离计算');
      expect(serviceSource, contains('private fun handlePinchGesture(event: MotionEvent)'),
          reason: '缺少双指手势处理');
      expect(serviceSource, contains('applyOverlaySettings(settings)'),
          reason: '双指缩放后尺寸没有真正应用');
    });

    test('拖出屏幕的部分只能用绘制偏移表现，窗口不得越界', () {
      final moveBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_MOVE ->',
        'MotionEvent.ACTION_CANCEL ->',
      );

      expect(moveBranch, contains('pokoView?.peekOffsetX = overflow.toFloat()'),
          reason: '边缘溢出必须走绘制偏移');
      expect(moveBranch, contains('params.x = wantedX.coerceIn(0, maxX)'),
          reason: '窗口坐标必须始终被钳制在屏幕内，否则会重现拖不动的老问题');
    });

    test('拖拽溢出偏移必须在滑行与落位时收回，否则宠物会歪在窗口旁', () {
      final flingBlock = _between(
        serviceSource,
        'private fun flingAndSettle(',
        'private fun handlePinchGesture(',
      );
      final settleBlock = _between(
        serviceSource,
        'private fun settleAfterDrag(',
        'private fun isDockedAtEdge(',
      );

      expect(serviceSource, contains('private fun animatePeekOffsetBack('),
          reason: '缺少溢出偏移回收实现');
      expect(flingBlock, contains('startPeek * (1f - f)'),
          reason: '惯性滑行过程中偏移没有同步收回，宠物与窗口会错位');
      expect(settleBlock, contains('animatePeekOffsetBack()'),
          reason: '落位时未回收拖拽溢出偏移，宠物会歪在窗口旁边像掉出屏幕');
    });

    test('双击不再拉起主应用，回小窝入口改到快捷菜单', () {
      final upBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_UP ->',
        'else -> false',
      );

      expect(upBranch, isNot(contains('openMainActivity()')),
          reason: '双击应该用来逗猫，不该抢走手势把用户拉出 App');
      expect(serviceSource, contains('private fun handleDesktopHome()'),
          reason: '缺少回小窝的菜单入口');
    });
  });

  group('玩法闭环：投喂小游戏 / 状态驱动 / 主动搭话', () {
    test('小鱼干必须靠拖到嘴边才结算，拖偏要扑空', () {
      expect(serviceSource, contains('private fun startFeedingGame()'),
          reason: '缺少投喂小游戏入口');
      expect(serviceSource, contains('private fun resolveFeeding('),
          reason: '缺少投喂结算判定');
      expect(serviceSource, contains('private fun removeFoodWindow()'),
          reason: '小鱼干窗口用完必须移除');
      expect(serviceSource, contains('private fun applyFeeding(hungerDelta: Int)'),
          reason: '喂食结算没有统一入口');
    });

    test('饱食度与心情必须驱动表情与自主行为', () {
      expect(petViewSource, contains('var hungerLevel: Int = 80'),
          reason: '悬浮猫缺少饱食度状态');
      expect(petViewSource, contains('var happinessLevel: Int = 80'),
          reason: '悬浮猫缺少心情状态');
      expect(petViewSource, contains('var energyLevel: Int = 80'),
          reason: '悬浮猫缺少体力状态');
      expect(serviceSource, contains('private fun syncPetMood()'),
          reason: '缺少状态同步');
      expect(serviceSource, contains('view.hungerLevel = state.hunger'),
          reason: '饱食度未同步给悬浮猫');
      expect(serviceSource, contains('view.happinessLevel = state.mood'),
          reason: '心情未同步给悬浮猫');
    });

    test('主动搭话必须有时间阈值，且可被设置关闭', () {
      final autoChatBlock = _between(
        serviceSource,
        'private val autoChatRunnable = object : Runnable',
        'private fun autoChatLine()',
      );

      expect(serviceSource, contains('const val AUTO_CHAT_IDLE_MS'),
          reason: '缺少主动搭话的空闲阈值');
      expect(autoChatBlock, contains('enableAutoChat'),
          reason: '主动搭话没有被设置开关管控');
      expect(autoChatBlock, contains('AUTO_CHAT_IDLE_MS'),
          reason: '主动搭话没有按空闲时长判定');
    });
  });

  group('悬浮宠设置：协议 / 存储 / 应用 / 面板', () {
    test('设置协议两端必须都提供读与写方法', () {
      expect(overlayChannelKotlin, contains('const val GET_OVERLAY_SETTINGS'),
          reason: 'Kotlin 侧缺少读取设置的协议常量');
      expect(overlayChannelKotlin, contains('const val UPDATE_OVERLAY_SETTINGS'),
          reason: 'Kotlin 侧缺少更新设置的协议常量');
      expect(overlayChannelDart, contains("'GET_OVERLAY_SETTINGS': 'getOverlaySettings'"),
          reason: 'Dart 侧缺少读取设置的协议常量');
      expect(overlayChannelDart, contains("'UPDATE_OVERLAY_SETTINGS': 'updateOverlaySettings'"),
          reason: 'Dart 侧缺少更新设置的协议常量');
      expect(activitySource, contains('OverlayChannel.GET_OVERLAY_SETTINGS'),
          reason: 'MainActivity 未处理读取设置');
      expect(activitySource, contains('OverlayChannel.UPDATE_OVERLAY_SETTINGS'),
          reason: 'MainActivity 未处理更新设置');
    });

    test('设置必须落到共享存储，服务未运行时也要保存下来', () {
      expect(serviceSource, contains('data class OverlaySettings('),
          reason: '缺少设置结构体');
      expect(serviceSource, contains('fun readSettings(context: Context): OverlaySettings'),
          reason: '缺少跨组件读取设置的入口');
      expect(serviceSource, contains('fun writeSettings(context: Context, settings: OverlaySettings)'),
          reason: '缺少跨组件写入设置的入口');
      expect(serviceSource, contains('fun applySettingsFromChannel(settings: OverlaySettings)'),
          reason: '服务运行中无法实时套用设置');
    });

    test('尺寸设置必须真正作用到绘制上', () {
      expect(petViewSource, contains('private val density: Float get() = baseDensity * sizeScale'),
          reason: '绘制密度没有跟随窗口尺寸缩放，改大小只会让猫原地不动');
      expect(petViewSource, contains('override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int)'),
          reason: '窗口尺寸变化后没有重算缩放系数');
    });

    test('Dart 侧必须提供设置读取与写入接口', () {
      expect(overlayServiceSource, contains('static Future<OverlaySettings> getSettings()'),
          reason: 'Dart 侧缺少读取设置接口');
      expect(overlayServiceSource, contains('static Future<bool> updateSettings('),
          reason: 'Dart 侧缺少更新设置接口');
    });
  });

  group('悬浮宠与主 App 协同约束', () {
    test('主 Activity 必须在前后台切换时同步悬浮猫显隐', () {
      expect(activitySource, contains('override fun onResume()'),
          reason: '缺少 onResume 回调，桌面悬浮猫无法在 App 进入前台时让位');
      expect(activitySource, contains('override fun onPause()'),
          reason: '缺少 onPause 回调，退出小窝后悬浮猫不会回来');
      expect(activitySource, contains('notifyAppForegroundChanged(true)'));
      expect(activitySource, contains('notifyAppForegroundChanged(false)'));
      expect(serviceSource, contains('refreshPetVisibility'),
          reason: '服务缺少前后台显隐处理，小窝打开时桌面与 App 内会出现两只波可');
    });

    test('主 Activity 必须提供 updateFloatingPet 通道以实时换品种', () {
      expect(activitySource, contains('OverlayChannel.UPDATE_FLOATING_PET'),
          reason: '缺少 updateFloatingPet 方法，App 内换品种后桌面悬浮猫不会变');
      expect(activitySource, contains('OverlayChannel.ARG_SKIN_ID'),
          reason: '推送时未携带 skinId，悬浮猫无从换装');
      expect(activitySource, contains('OverlayChannel.ARG_PET_NAME'),
          reason: '推送时未携带 petName，悬浮猫名字不会更新');
    });

    test('悬浮服务每次启动都必须重新应用外观配置', () {
      final onStartCommand = _between(
        serviceSource,
        'override fun onStartCommand',
        'override fun onTaskRemoved',
      );

      expect(onStartCommand, contains('applyConfig(skinId, petName)'),
          reason: 'onStartCommand 未无条件应用外观，收到推送也不会换品种');
      expect(onStartCommand, isNot(contains('if (!skinId.isNullOrBlank()')),
          reason: '旧的空值守卫会让空配置跳过换装逻辑');
    });

    test('Dart 侧换品种必须实时同步给桌面悬浮宠', () {
      expect(overlayServiceSource, contains('OverlayChannel.updateFloatingPet'),
          reason: 'OverlayService 缺少 updateFloatingPet 方法');

      // 断言必须落在 setSkin 方法内部，否则读档路径里的同名调用会掩盖换品种路径的缺失
      final setSkin = _between(
        petModelSource,
        'void setSkin(String newSkinId)',
        'void setDecoration(',
      );
      expect(setSkin, contains('OverlayService.updateFloatingPet'),
          reason: 'PetModel.setSkin 未同步悬浮宠，切换品种后桌面悬浮猫仍是旧品种');
      expect(setSkin, contains('unawaited('),
          reason: 'setSkin 中的同步调用未使用 unawaited 包裹，会产生未等待的 Future 告警');
    });
  });

  group('MethodChannel 协议两端必须逐项一致', () {
    test('通道名一致', () {
      final kotlinName = _kotlinConstValue(overlayChannelKotlin, 'NAME');
      final dartName = _dartConstValue(overlayChannelDart, 'name');

      expect(kotlinName, isNotNull, reason: 'Kotlin 侧未定义通道名常量');
      expect(dartName, isNotNull, reason: 'Dart 侧未定义通道名常量');
      expect(dartName, kotlinName, reason: '★ 两端通道名不一致，调用会直接失联');
    });

    test('方法名常量表完全一致', () {
      final kotlin = _parseKotlinConstMap(overlayChannelKotlin, 'ALL_METHODS');
      final dart = _parseDartConstMap(overlayChannelDart, 'allMethods');

      expect(kotlin, isNotEmpty);
      expect(dart, isNotEmpty);
      expect(
        dart.keys.toSet().difference(kotlin.keys.toSet()),
        isEmpty,
        reason: '★ Dart 侧多出/缺少方法常量: '
            '${dart.keys.toSet().difference(kotlin.keys.toSet())}',
      );
      expect(
        kotlin.keys.toSet().difference(dart.keys.toSet()),
        isEmpty,
        reason: '★ Kotlin 侧多出/缺少方法常量: '
            '${kotlin.keys.toSet().difference(dart.keys.toSet())}',
      );
      kotlin.forEach((key, value) {
        expect(dart[key], value, reason: '★ 方法常量 $key 两端取值不一致');
      });
    });

    test('参数名常量表完全一致', () {
      final kotlin = _parseKotlinConstMap(overlayChannelKotlin, 'ALL_ARGS');
      final dart = _parseDartConstMap(overlayChannelDart, 'allArgs');

      expect(kotlin, isNotEmpty);
      expect(dart, isNotEmpty);
      expect(dart.keys.toSet(), kotlin.keys.toSet(), reason: '★ 参数常量集合两端不一致');
      kotlin.forEach((key, value) {
        expect(dart[key], value, reason: '★ 参数常量 $key 两端取值不一致');
      });
    });

    test('两端服务代码都不得再手写通道名/方法名字面量', () {
      expect(overlayServiceSource, contains('OverlayChannel.name'),
          reason: 'OverlayService 应使用共享常量而非手写通道名');
      expect(overlayServiceSource, isNot(contains("'com.electricpet.poko/overlay'")),
          reason: 'OverlayService 仍手写通道名字面量');
      expect(activitySource, contains('OverlayChannel.NAME'),
          reason: 'MainActivity 应使用共享常量而非手写通道名');
      expect(activitySource, isNot(contains('"com.electricpet.poko/overlay"')),
          reason: 'MainActivity 仍手写通道名字面量');
    });
  });

  group('Kotlin import 完整性：漏 import 只有 CI 能发现', () {
    test('用到的类型必须都有对应 import（缺 import 会让 CI 编译失败）', () {
      // 背景：本机没有 android.jar，kotlinc 会把 android.* 全部报成 unresolved，
      // 于是"少写一行 import"这类错误在本地完全看不出来 —— 上一次 CI 就是这样炸的：
      //   Unresolved reference 'SharedPreferences'.
      // 本用例做一次静态 import 审计，把这类错误挡在 CI 之前。
      final declared = _projectDeclaredNames(<String>[
        serviceSource,
        activitySource,
        petViewSource,
        overlayChannelKotlin,
      ]);

      final problems = <String>[];
      for (final source in <String>[serviceSource, activitySource, petViewSource]) {
        problems.addAll(_findMissingImports(source, declared));
      }

      expect(
        problems,
        isEmpty,
        reason: '发现缺少 import 的类型（会直接导致 CI 编译失败）：\n'
            '${problems.join('\n')}',
      );
    });

    test('import 审计器本身必须有效：能识别人造漏 import 的样本', () {
      const sample = '''
package com.example

import android.content.Context
import android.view.View

class Sample(context: Context) {
    fun build() {
        val listener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ -> }
        val v = View(context)
    }
}
''';
      final problems = _findMissingImports(sample, <String>{});

      expect(
        problems.any((p) => p.contains('SharedPreferences')),
        isTrue,
        reason: '审计器应报出漏 import 的 SharedPreferences',
      );
      expect(
        problems.any((p) => p.contains('Context') || p.contains('View')),
        isFalse,
        reason: '已正确 import 的类型不应误报',
      );
    });
  });

  group('状态系统：字段名 / 衰减速率 / 时间戳约定必须两端一致', () {
    test('心情字段必须是 mood，绝不能再用 happiness', () {
      // 历史事故：原生侧读写 "happiness"，而 Dart 侧 PetModel 用的是 "mood"，
      // 桌面猫永远读到兜底值，App 里喂食涨的心情它也完全感知不到。
      expect(petModelSource, contains("'mood': mood"),
          reason: 'Dart 侧状态字段是 mood');
      expect(petModelSource, isNot(contains("'happiness'")),
          reason: 'Dart 侧不应出现 happiness 字段');
      // 注意：允许出现 json.remove("happiness") —— 那是清理旧版本留下的垃圾 key
      expect(serviceSource, isNot(contains('optInt("happiness"')),
          reason: '原生侧不得再读取 happiness —— 它不是 Dart 侧认识的 key');
      expect(serviceSource, isNot(contains('optDouble("happiness"')),
          reason: '原生侧不得再读取 happiness —— 它不是 Dart 侧认识的 key');
      expect(serviceSource, isNot(contains('put("happiness"')),
          reason: '原生侧不得再写入 happiness —— 会凭空多一个 App 不认的存档字段');
      expect(serviceSource, contains('"mood"'),
          reason: '原生侧必须读写真实的 mood 字段');
    });

    test('状态衰减速率两端必须逐项一致', () {
      final dartRates = _extractDecayRates(petModelSource, dart: true);
      final kotlinRates = _extractDecayRates(serviceSource, dart: false);

      expect(dartRates, isNotEmpty, reason: 'Dart 侧未找到衰减速率表');
      expect(kotlinRates.keys.toSet(), dartRates.keys.toSet(),
          reason: '两端的衰减字段集合不一致：'
              'Dart=${dartRates.keys.toList()} Kotlin=${kotlinRates.keys.toList()}');
      for (final key in dartRates.keys) {
        expect(kotlinRates[key], closeTo(dartRates[key]!, 0.0001),
            reason: '衰减速率 `$key` 两端不一致，'
                'App 里和桌面上的波可会算出不同的状态');
      }
    });

    test('状态快照时间戳 stateSavedAt 两端必须成对出现', () {
      // 约定：谁写盘谁盖时间戳，读取方按 (now - stateSavedAt) 补算，
      // 这样同一段时间只会被扣一次。
      expect(petModelSource, contains("'stateSavedAt': stateSavedAt"),
          reason: 'Dart 侧存档缺少 stateSavedAt');
      expect(petModelSource, contains('stateSavedAt = DateTime.now().millisecondsSinceEpoch'),
          reason: 'Dart 侧写盘时没有盖时间戳');
      expect(serviceSource, contains('json.optLong("stateSavedAt"'),
          reason: '原生侧没有按 stateSavedAt 计算流逝时间');
      expect(serviceSource, contains('json.put("stateSavedAt"'),
          reason: '原生侧写盘时没有盖时间戳');
    });

    test('状态必须真的随时间衰减，且 App 关着也生效', () {
      // 旧实现只在 pet_screen 的前台定时器里 tickDecay，App 一关状态就冻结，
      // 桌面悬浮宠的「饿了找食」在真实场景下等于从来没发生过。
      expect(serviceSource, contains('private fun elapsedDecaySeconds('),
          reason: '原生侧缺少按时间戳结算流逝时长的能力');
      expect(serviceSource, contains('private fun decayedValue('),
          reason: '原生侧缺少按流逝时间补算状态值的能力');
      expect(petModelSource, contains('double applyOfflineDecay()'),
          reason: 'Dart 侧缺少离线补算');
    });

    test('存档变更必须能实时通知原生侧', () {
      expect(serviceSource, contains('SharedPreferences.OnSharedPreferenceChangeListener'),
          reason: '缺少存档变更监听，App 里喂完桌面猫要等 60 秒才反应过来');
      expect(serviceSource, contains('registerPetDataListener()'),
          reason: '服务启动时没有注册存档监听');
      expect(serviceSource, contains('unregisterPetDataListener()'),
          reason: '服务销毁时没有注销监听，会泄漏');
    });
  });

  group('绘制性能：onDraw 不得每帧分配对象', () {
    test('绘制路径里不得现 new RectF / Paint / Path', () {
      // 待机动画 60fps 常驻，每帧 new 十几个 RectF + 七八个 Paint
      // 等于每秒制造几百个临时对象，纯浪费。
      final drawBlock = _between(
        petViewSource,
        'private fun drawTail(',
        'override fun onDetachedFromWindow()',
      );

      expect(drawBlock, isNot(contains('RectF(')),
          reason: '绘制路径里现 new RectF，应改为复用成员矩形 + set()');
      expect(drawBlock, isNot(contains('Paint(Paint.ANTI_ALIAS_FLAG)')),
          reason: '绘制路径里现 new Paint，应改为复用成员画笔');
      expect(drawBlock, isNot(contains('Path()')),
          reason: '绘制路径里现 new Path，应改为复用成员路径');
      expect(drawBlock, isNot(contains('listOf(')),
          reason: '绘制路径里现 new listOf，应改为复用数组或展开写');
      expect(drawBlock, isNot(contains('Color.parseColor(')),
          reason: '绘制路径里每帧解析颜色字符串，应改为预解析的颜色常量');
    });

    test('渐变 shader 必须缓存，不能每帧重建 native 对象', () {
      final drawBlock = _between(
        petViewSource,
        'private fun drawTail(',
        'override fun onDetachedFromWindow()',
      );

      expect(petViewSource, contains('private var bodyShader: RadialGradient?'),
          reason: '身体渐变没有缓存，RadialGradient 是 native 对象，每帧重建很贵');
      expect(petViewSource, contains('setLocalMatrix(shaderMatrix)'),
          reason: '渐变位置变化应靠 local matrix 平移，而不是重建 shader');
      expect(drawBlock, contains('bodyShader == null'),
          reason: 'bodyShader 缺少「颜色/半径变了才重建」的判定');
    });
  });

  group('屏幕适配与夜间模式', () {
    test('屏幕尺寸必须缓存，并用 maximumWindowMetrics 取真实尺寸', () {
      expect(serviceSource, contains('private var cachedScreenWidth: Int = 0'),
          reason: '屏幕尺寸没有缓存，拖拽时每帧都要问系统');
      expect(serviceSource, contains('maximumWindowMetrics'),
          reason: 'API 30+ 应使用 maximumWindowMetrics，'
              'defaultDisplay.getRealMetrics 在分屏/折叠屏下会拿到错误尺寸');
      expect(serviceSource, contains('private fun invalidateScreenCache()'),
          reason: '屏幕配置变化后缓存没有失效');
    });

    test('系统栏避让边距必须缓存，不能每帧做资源表查找', () {
      expect(serviceSource, contains('private fun refreshSafeInsets()'),
          reason: '缺少系统栏避让边距的缓存刷新');
      expect(serviceSource, contains('private var safeTopInset: Int = 0'),
          reason: '系统栏避让边距没有缓存');
    });

    test('夜间模式必须两端都能传，且能改配色', () {
      expect(overlayChannelKotlin, contains('const val ARG_NIGHT_MODE'),
          reason: '原生侧缺少昼夜状态参数');
      expect(overlayChannelDart, contains('argNightMode'),
          reason: 'Dart 侧缺少昼夜状态参数');
      expect(activitySource, contains('OverlayChannel.ARG_NIGHT_MODE'),
          reason: 'MainActivity 没有把昼夜状态传给服务');
      expect(serviceSource, contains('fun applyNightModeFromApp('),
          reason: '服务没有接收 App 推送的昼夜状态');
      expect(petViewSource, contains('var isNightMode: Boolean = false'),
          reason: '悬浮猫没有夜间模式开关');
      expect(petViewSource, contains('private fun applyNightTint('),
          reason: '夜间模式没有对应的配色变换');
    });

    test('悬浮宠必须提供无障碍描述', () {
      expect(serviceSource, contains('contentDescription'),
          reason: '悬浮宠没有 contentDescription，TalkBack 读不到它');
      expect(serviceSource, contains('IMPORTANT_FOR_ACCESSIBILITY_YES'),
          reason: '悬浮宠没有声明无障碍重要性');
    });
  });

  group('原生编译期作用域守护：成员函数不得引用别的函数的局部变量', () {
    test('检测器本身必须有效：能识别人造的作用域越界样本', () {
      // 自验证：如果检测器逻辑写坏了（比如成员函数一个都识别不出来），
      // 上面的用例会永远"全绿"而形同虚设。这里用人造样本验证它真的会报警。
      const sample = '''
class Demo {
    private var memberCounter: Int = 0

    private fun setupTouchListener() {
        var sharedFlag = 0f
        var otherLocal = 1
        memberCounter += 1
        println(sharedFlag)
    }

    private fun handleSomewhereElse() {
        memberCounter += 1
        println(sharedFlag)
    }
}
''';
      final problems = _findScopeViolations(sample);

      expect(
        problems.any((p) => p.contains('sharedFlag')),
        isTrue,
        reason: '检测器应报出 sharedFlag：它在 setupTouchListener() 里是局部变量，'
            'handleSomewhereElse() 这个成员函数取不到',
      );
      expect(
        problems.any((p) => p.contains('otherLocal')),
        isFalse,
        reason: '未被别的函数引用的局部变量不应误报',
      );
      expect(
        problems.any((p) => p.contains('memberCounter')),
        isFalse,
        reason: '类成员变量不是局部变量，不应被当成作用域越界',
      );
    });

    test('成员函数解析必须真的解析出了函数（防止检测器空转）', () {
      expect(_memberFunctions(serviceSource).length, greaterThan(20),
          reason: 'FloatingPetService 成员函数解析结果异常，检测器可能空转');
      expect(_memberFunctions(petViewSource).length, greaterThan(10),
          reason: 'PokoPetView 成员函数解析结果异常，检测器可能空转');
      expect(
        _memberFunctions(serviceSource).map((f) => f.name),
        containsAll(<String>['setupTouchListener', 'handlePinchGesture']),
        reason: '关键成员函数没被解析出来，检测器覆盖不到真实场景',
      );
    });

    test('跨函数引用的状态字段必须是类成员，不能是某个函数里的局部变量', () {
      // 历史事故：pinchStartDistance / pinchStartSizeDp / pinchStartAngle /
      // pinchStartFacingLeft 曾被写成 setupTouchListener() 里的局部变量，
      // 而 handlePinchGesture() 是独立的成员函数，取不到它们 ——
      // CI 上报 Unresolved reference，release 包直接构建失败。
      // 本用例用结构化规则机械扫描所有 .kt 文件，防止同类问题再次溜过去。
      final problems = <String>[];

      for (final source in <String>[serviceSource, activitySource, petViewSource]) {
        for (final p in _findScopeViolations(source)) {
          problems.add('${_fileOf(source)}: $p');
        }
      }

      expect(
        problems,
        isEmpty,
        reason: '发现跨函数引用局部变量的问题（会直接导致 CI 编译失败）：\n'
            '${problems.join('\n')}',
      );
    });

    test('双指手势的状态字段必须提升为类成员', () {
      for (final field in <String>[
        'isPinching',
        'pinchStartDistance',
        'pinchStartSizeDp',
        'pinchStartAngle',
        'pinchStartFacingLeft',
      ]) {
        expect(
          serviceSource,
          contains(RegExp('^\\s*private var $field\\b', multiLine: true)),
          reason: '`$field` 必须是类成员变量（private var），'
              '否则成员函数 handlePinchGesture() 取不到，CI 编译会失败',
        );
      }
    });

    test('设置项 opacity 两侧类型必须都是 Float（不能混用 Double）', () {
      // OverlaySettings.opacity 是 Float；
      // MainActivity 若用 toDouble() 赋值会报
      // "Argument type mismatch: actual type is 'Number & Comparable<*>', but 'Float' was expected"
      expect(serviceSource, contains('val opacity: Float'),
          reason: '原生 OverlaySettings.opacity 必须是 Float');
      expect(activitySource, contains('ARG_SETTING_OPACITY] as? Number)?.toFloat()'),
          reason: 'MainActivity 回填 opacity 必须用 toFloat()，'
              '用 toDouble() 会与 Float 字段类型冲突导致 CI 编译失败');
      expect(activitySource, isNot(contains('ARG_SETTING_OPACITY] as? Number)?.toDouble()')),
          reason: 'opacity 回填不能使用 toDouble()，与 Float 字段类型不匹配');
    });
  });

  group('通知权限与耗电约束', () {
    test('Android 13+ 必须在运行时申请通知权限', () {
      expect(activitySource, contains('OverlayChannel.REQUEST_NOTIFICATION_PERMISSION'),
          reason: 'MainActivity 缺少通知权限申请分支');
      expect(activitySource, contains('POST_NOTIFICATIONS'),
          reason: '未引用 POST_NOTIFICATIONS，Android 13+ 前台服务通知不会显示');
      expect(activitySource, contains('onRequestPermissionsResult'),
          reason: '缺少权限结果回调，申请结果无法回传 Dart');
      expect(overlayServiceSource, contains('requestNotificationPermission'),
          reason: 'Dart 侧缺少通知权限申请入口');
    });

    test('悬浮猫不可见时必须停掉动画', () {
      expect(petViewSource, contains('fun setAnimationEnabled'),
          reason: 'PokoPetView 缺少动画开关');
      expect(serviceSource, contains('setAnimationEnabled'),
          reason: '服务未在悬浮猫隐藏时停掉 60fps 呼吸动画, 属于无谓耗电');
      expect(serviceSource, contains('ACTION_SCREEN_OFF'),
          reason: '未监听息屏, 屏幕熄灭后悬浮猫仍在空转');
    });
  });
}

/// 定位 Flutter 包根目录（向上查找 pubspec.yaml），兼容在不同工作目录下执行测试。
Directory _findPackageRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (File('${dir.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('未找到 Flutter 包根目录 (pubspec.yaml)');
    }
    dir = parent;
  }
}

String _readRepoFile(Directory root, String relativePath) {
  final file = File('${root.path}${Platform.pathSeparator}$relativePath');
  if (!file.existsSync()) {
    fail('未找到仓库文件: $relativePath');
  }
  return file.readAsStringSync();
}

// ---------------------------------------------------------------------------
// Kotlin import 审计
//
// 动机：本机没有 android.jar，kotlinc 会把 android.* 全部报成 unresolved，
// 于是"少写一行 import"在本地完全看不出来，只能等 CI 炸出来。
// 一次 CI 往返 6 分钟，这种错误必须提前拦下。
// ---------------------------------------------------------------------------

/// 项目内声明过的名字（类 / 属性 / 函数 / 枚举项等），这些不需要 import
Set<String> _projectDeclaredNames(List<String> sources) {
  final names = <String>{};
  final patterns = <RegExp>[
    RegExp(r'\b(?:private |public |internal |protected |override |open |final |abstract |sealed |data |enum |inner |annotation |value |companion )*'
        r'(?:class|object|interface)\s+([A-Za-z_]\w*)'),
    RegExp(r'\b(?:const |lateinit |override |private |public |internal |protected |open |final )*'
        r'(?:var|val)\s+([A-Za-z_]\w*)'),
    RegExp(r'\bfun\s+(?:<[^>]*>\s*)?([A-Za-z_]\w*)\s*\('),
    RegExp(r'\btypealias\s+([A-Za-z_]\w*)'),
  ];
  for (final source in sources) {
    final code = _stripLiteralsAndComments(source);
    for (final pat in patterns) {
      for (final m in pat.allMatches(code)) {
        final n = m.group(1);
        if (n != null) names.add(n);
      }
    }
    // 枚举项：enum class X { HEAD, BODY, ... }
    for (final m in RegExp(r'\benum\s+class\s+[A-Za-z_]\w*\s*\{([^}]*)\}')
        .allMatches(code)) {
      for (final entry in m.group(1)!.split(',')) {
        final n = entry.trim().split('(').first.trim();
        if (RegExp(r'^[A-Za-z_]\w*$').hasMatch(n)) names.add(n);
      }
    }
  }
  return names;
}

/// 明确无需 import 的名字：java.lang / kotlin 内建
const Set<String> _kotlinBuiltinNames = <String>{
  'Any', 'Nothing', 'Unit', 'Array', 'Boolean', 'Byte', 'Short', 'Int', 'Long',
  'Float', 'Double', 'Char', 'String', 'CharSequence', 'Number', 'Comparable',
  'Throwable', 'Exception', 'RuntimeException', 'Error', 'IllegalArgumentException',
  'IllegalStateException', 'NullPointerException', 'IndexOutOfBoundsException',
  'ClassCastException', 'UnsupportedOperationException', 'NumberFormatException',
  'Override', 'Deprecated', 'Suppress', 'SafeVarargs', 'FunctionalInterface',
  'JvmStatic', 'JvmField', 'JvmOverloads', 'JvmName', 'Volatile', 'Synchronized',
  'Object', 'Math', 'System', 'Integer', 'Character', 'Thread', 'Runnable',
  'Iterable', 'Iterator', 'Pair', 'Triple', 'Result', 'Regex', 'Enum',
  'Annotation', 'Function', 'StringBuilder', 'List', 'MutableList', 'Set',
  'MutableSet', 'Map', 'MutableMap', 'IntArray', 'FloatArray', 'DoubleArray',
  'BooleanArray', 'CharArray', 'LongArray', 'ShortArray', 'ByteArray',
  'ArrayList', 'HashMap', 'HashSet', 'LinkedHashMap', 'LinkedHashSet', 'Random',
  'UUID', 'Date', 'Timer', 'TimerTask', 'Objects', 'Collections', 'Arrays',
  'Locale', 'Scanner', 'Comparator', 'Queue', 'Deque', 'Optional', 'StringBuffer',
  'OptIn', 'RequiresOptIn', 'JvmInline', 'SuppressWarnings',
  // 下面这几个是"不用 import 也能用"的：
  'R',            // Android 自动生成的资源类，同包可见
  'Charsets',     // kotlin.text.Charsets，kotlin 默认导入
  'START_STICKY', // android.app.Service 的继承成员
  'START_NOT_STICKY',
  'LAYER_TYPE_HARDWARE', // android.view.View 的继承常量
  'MeasureSpec',          // android.view.View 的嵌套类（View 子类内可直接用）
};

/// 通配符导入包内已知可用���类型（只列本项目真正会用到的，宁可宽松也别误报）
const Map<String, Set<String>> _wildcardPackageMembers = <String, Set<String>>{
  'android.graphics': <String>{
    'Canvas', 'Color', 'Paint', 'Path', 'Rect', 'RectF', 'Point', 'PointF',
    'Matrix', 'Shader', 'RadialGradient', 'LinearGradient', 'SweepGradient',
    'ComposeShader', 'PorterDuff', 'PorterDuffXfermode', 'Xfermode',
    'Typeface', 'Bitmap', 'BitmapFactory', 'BlurMaskFilter', 'DashPathEffect',
    'PaintFlags', 'PathEffect', 'PathMeasure', 'RoundRect', 'Picture',
  },
  'android.view': <String>{
    'View', 'ViewGroup', 'MotionEvent', 'VelocityTracker', 'ViewConfiguration',
    'WindowManager', 'Gravity', 'HapticFeedbackConstants', 'SurfaceView',
    'SurfaceHolder', 'TextureView', 'ViewOutlineProvider', 'LayoutInflater',
    'KeyEvent', 'Menu', 'MenuItem', 'Window', 'WindowInsets',
    'Display', 'AccessibilityNodeInfo', 'ActionProvider', 'ActionMode',
  },
  'android.widget': <String>{
    'TextView', 'LinearLayout', 'ImageView', 'Button', 'EditText', 'FrameLayout',
    'ScrollView', 'Toast', 'ProgressBar', 'ImageButton', 'Space', 'GridLayout',
    'RelativeLayout', 'HorizontalScrollView', 'ViewFlipper', 'TextClock',
  },
  'android.util': <String>{
    'DisplayMetrics', 'Log', 'TypedValue', 'AttributeSet', 'SparseArray',
    'Base64', 'Size', 'SizeF', 'Pair', 'JsonReader', 'JsonWriter', 'JsonToken',
  },
  'android.os': <String>{
    'Bundle', 'Handler', 'Looper', 'Build', 'PowerManager', 'Vibrator',
    'VibrationEffect', 'BatteryManager', 'SystemClock', 'Environment',
    'Parcelable', 'StatFs', 'Process', 'UserManager', 'Message', 'AsyncTask',
  },
  'java.util': <String>{
    'List', 'Map', 'Set', 'ArrayList', 'HashMap', 'HashSet', 'Random', 'UUID',
    'Date', 'Timer', 'TimerTask', 'Objects', 'Collections', 'Arrays', 'Iterator',
    'LinkedHashMap', 'LinkedHashSet', 'TreeMap', 'TreeSet', 'Locale',
    'Calendar', 'Scanner', 'Comparator', 'Queue', 'Deque', 'Optional',
    'AbstractMap', 'AbstractList', 'NoSuchElementException', 'Enumeration',
    'BitSet', 'Vector', 'Stack', 'Properties', 'StringJoiner', 'Spliterator',
  },
  'kotlin.math': <String>{
    'abs', 'min', 'max', 'sqrt', 'sin', 'cos', 'tan', 'asin', 'acos', 'atan',
    'atan2', 'pow', 'exp', 'log', 'log2', 'log10', 'hypot', 'round', 'floor',
    'ceil', 'sign', 'PI', 'E', 'runBlocking',
  },
  'kotlin.collections': <String>{
    'List', 'MutableList', 'Set', 'MutableSet', 'Map', 'MutableMap',
  },
  'kotlin.text': <String>{'StringBuilder'},
  'kotlin.io': <String>{'File', 'Reader', 'Writer', 'Path'},
};

/// 找出文件里"用了但没 import"的类型名
List<String> _findMissingImports(String source, Set<String> declaredNames) {
  final code = _stripLiteralsAndComments(source);

  // 已 import 的简单名
  final imported = <String>{};
  // 通配符包允许的类型
  final wildcardAllowed = <String>{};
  for (final m in RegExp(r'^import\s+([\w.]+(?:\.\*)?)(?:\s+as\s+\w+)?\s*$', multiLine: true)
      .allMatches(code)) {
    final fq = m.group(1)!;
    if (fq.endsWith('.*')) {
      final pkg = fq.substring(0, fq.length - 2);
      wildcardAllowed.addAll(_wildcardPackageMembers[pkg] ?? const <String>{});
      // 未登记的通配符包：无法审计，保守起见不做限制
      if (!(_wildcardPackageMembers.containsKey(pkg))) {
        wildcardAllowed.add('*');
      }
    } else {
      imported.add(fq.split('.').last);
    }
  }

  // 收集用到的"类型形状"标识符：首字母大写，且不是成员访问 / 注解
  final used = <String>{};
  for (final m in RegExp(r'(?<![.\w])([A-Z][A-Za-z0-9_]*)').allMatches(code)) {
    final name = m.group(1)!;
    // 排除注解（前面是 @）
    final before = m.start > 0 ? code.substring(m.start - 1, m.start) : '';
    if (before == '@') continue;
    used.add(name);
  }

  final problems = <String>[];
  for (final name in used) {
    if (imported.contains(name)) continue;
    if (wildcardAllowed.contains(name)) continue;
    if (wildcardAllowed.contains('*')) continue;
    if (declaredNames.contains(name)) continue;
    if (_kotlinBuiltinNames.contains(name)) continue;
    problems.add(name);
  }
  return problems.map((n) => '缺少 import: $n').toList();
}

/// 截取以 [marker] 开头的那一对括号内的内容（按括号配平查找）。
String _parenBlock(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) {
    fail('未找到: $marker');
  }
  final open = source.indexOf('(', start);
  if (open < 0) {
    fail('$marker 后面没有左括号');
  }
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final ch = source[i];
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
      if (depth == 0) return source.substring(open, i + 1);
    }
  }
  fail('$marker 的括号不配平');
}

/// 截取以 [marker] 开头的那一对花括号内的内容（按括号配平查找）。
String _braceBlock(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) {
    fail('未找到: $marker');
  }
  final open = source.indexOf('{', start);
  if (open < 0) {
    fail('$marker 后面没有左花括号');
  }
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final ch = source[i];
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) return source.substring(open + 1, i);
    }
  }
  fail('$marker 的花括号不配平');
}

/// 提取状态衰减速率表。
///
/// Dart 侧: `static const Map<String, double> decayRates = <String, double>{ 'hunger': 0.45, ... }`
/// Kotlin 侧: `val DECAY_RATES: Map<String, Float> = mapOf( "hunger" to 0.45f, ... )`
///
/// 两张表必须逐项一致，否则 App 里和桌面上的波可会算出不同的状态。
Map<String, double> _extractDecayRates(String source, {required bool dart}) {
  final rates = <String, double>{};
  if (dart) {
    final block = _braceBlock(source, 'decayRates = <String, double>');
    for (final m in RegExp(r"'([A-Za-z_]\w*)':\s*([0-9]*\.?[0-9]+)")
        .allMatches(block)) {
      rates[m.group(1)!] = double.parse(m.group(2)!);
    }
  } else {
    final block = _parenBlock(source, 'DECAY_RATES');
    for (final m in RegExp(r'"([A-Za-z_]\w*)"\s+to\s+([0-9]*\.?[0-9]+)f')
        .allMatches(block)) {
      rates[m.group(1)!] = double.parse(m.group(2)!);
    }
  }
  return rates;
}

/// 截取某个 WindowManager.LayoutParams 构造调用的参数区（含 flags 段）。
String _layoutParamsBlock(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) {
    fail('未找到布局构造: $marker');
  }
  final end = source.indexOf('PixelFormat.TRANSLUCENT', start);
  if (end < 0) {
    fail('$marker 缺少 PixelFormat 参数');
  }
  return source.substring(start, end);
}

String _between(String source, String from, String to) {
  final start = source.indexOf(from);
  if (start < 0) {
    fail('未找到片段起点: $from');
  }
  final end = source.indexOf(to, start);
  if (end < 0) {
    fail('未找到片段终点: $to');
  }
  return source.substring(start, end);
}

// ---------------------------------------------------------------------------
// 编译期作用域检查用的 Kotlin 源码解析
//
// 目的：捕捉「把跨函数共享的状态写成某个函数里的局部变量」这类问题。
// 这种代码在本机没有 android.jar 时会被 kotlinc 的噪音淹没，
// 只有到了 CI（那里有完整 SDK）才会以 Unresolved reference 的形式炸出来，
// 一次就要搭上一轮 6 分钟的构建时间。
// ---------------------------------------------------------------------------

/// 一个成员级函数（缩进 4 空格，即类体直接持有的函数）
class _MemberFunction {
  final String name;
  final String signature;
  final String body;

  const _MemberFunction(this.name, this.signature, this.body);
}

/// Kotlin 关键字与内建类型名：出现在引用里也不算「跨函数引用」
const Set<String> _kotlinKeywords = <String>{
  'as', 'break', 'class', 'continue', 'do', 'else', 'false', 'for', 'fun', 'if',
  'in', 'interface', 'is', 'null', 'object', 'package', 'return', 'super',
  'this', 'throw', 'true', 'try', 'typealias', 'typeof', 'val', 'var', 'when',
  'while', 'by', 'catch', 'constructor', 'delegate', 'dynamic', 'field',
  'file', 'finally', 'get', 'import', 'init', 'param', 'property', 'receiver',
  'set', 'setparam', 'where', 'actual', 'abstract', 'annotation', 'companion',
  'const', 'crossinline', 'data', 'enum', 'expect', 'external', 'final',
  'infix', 'inline', 'inner', 'internal', 'lateinit', 'noinline', 'open',
  'operator', 'out', 'override', 'private', 'protected', 'public', 'reified',
  'sealed', 'suspend', 'tailrec', 'vararg', 'it',
};

/// 解析出源码里的所有成员级函数（类体直接持有的函数，缩进 4 空格）
List<_MemberFunction> _memberFunctions(String source) {
  final lines = source.split('\n');
  final result = <_MemberFunction>[];

  // 成员函数声明行：恰好 4 个空格缩进 + fun 名字
  final declRe = RegExp(r'^ {4}(?:private |public |internal |protected |override |open |final |suspend )*fun\s+([A-Za-z_]\w*)\s*\(');

  for (var i = 0; i < lines.length; i++) {
    final m = declRe.firstMatch(lines[i]);
    if (m == null) continue;

    final name = m.group(1)!;
    // 签名：从声明行到右括号（可能跨行）
    final signature = _collectSignature(lines, i);
    // 函数体：签名结束后的第一个 `{` 到与之匹配的 `}`
    final body = _collectBody(lines, i + signature.split('\n').length - 1);

    result.add(_MemberFunction(name, signature, body));
  }
  return result;
}

/// 从第 [start] 行开始收集函数签名（到括号配平为止）
String _collectSignature(List<String> lines, int start) {
  final buf = <String>[];
  var depth = 0;
  var started = false;
  for (var i = start; i < lines.length; i++) {
    buf.add(lines[i]);
    for (final ch in lines[i].split('')) {
      if (ch == '(') {
        depth++;
        started = true;
      } else if (ch == ')') {
        depth--;
      }
    }
    if (started && depth <= 0) break;
  }
  return buf.join('\n');
}

/// 从第 [start] 行开始收集函数体（按大括号配平）
String _collectBody(List<String> lines, int start) {
  final buf = <String>[];
  var depth = 0;
  var begun = false;
  for (var i = start; i < lines.length; i++) {
    buf.add(lines[i]);
    for (final ch in lines[i].split('')) {
      if (ch == '{') {
        depth++;
        begun = true;
      } else if (ch == '}') {
        depth--;
      }
    }
    if (begun && depth <= 0) break;
  }
  return buf.join('\n');
}

/// 剔除字符串字面量与注释，只留下真正的代码。
///
/// 必要性：日志文案里出现的裸词（例如 `"... sizePx=$petSizePx"`）会被
/// 朴素的标识符扫描当成"代码引用"，从而把检测器变成一堆误报的噪音源。
String _stripLiteralsAndComments(String source) {
  var out = StringBuffer();
  var i = 0;
  final n = source.length;

  while (i < n) {
    final ch = source[i];

    // 三引号字符串
    if (source.startsWith('"""', i)) {
      final end = source.indexOf('"""', i + 3);
      i = end < 0 ? n : end + 3;
      out.write(' ');
      continue;
    }

    // 普通字符串
    if (ch == '"') {
      i++;
      while (i < n) {
        if (source[i] == r'\' && i + 1 < n) {
          i += 2;
          continue;
        }
        if (source[i] == '"') {
          i++;
          break;
        }
        if (source[i] == '\n') {
          // 保留换行，否则会把字符串前后两行黏成一行，
          // 导致"行首赋值"这类按行匹配的规则失效
          out.write('\n');
          i++;
          break;
        }
        i++;
      }
      out.write(' ');
      continue;
    }

    // 行注释
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? n : end;
      out.write(' ');
      continue;
    }

    // 块注释
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i + 2);
      i = end < 0 ? n : end + 2;
      out.write(' ');
      continue;
    }

    out.write(ch);
    i++;
  }
  return out.toString();
}

/// 函数体里声明的局部变量名（val / var，含解构声明 `val (a, b) = ...`）
Set<String> _declaredLocals(String body) {
  final names = <String>{};
  final code = _stripLiteralsAndComments(body);

  // 普通声明：val x = ...
  for (final m in RegExp(r'\b(?:var|val)\s+([A-Za-z_]\w*)').allMatches(code)) {
    names.add(m.group(1)!);
  }
  // 解构声明：val (a, b) = ...
  for (final m in RegExp(r'\b(?:var|val)\s*\(([^)]*)\)').allMatches(code)) {
    for (final part in m.group(1)!.split(',')) {
      final n = part.trim().split(':').first.trim();
      // `_` 是解构通配符，不是真正的变量名
      if (n == '_') continue;
      if (RegExp(r'^[A-Za-z_]\w*$').hasMatch(n)) names.add(n);
    }
  }
  return names;
}

/// 语句级赋值的目标名（`x = ...` / `x += ...`）
///
/// 用于区分"读取"与"写入"：在 `apply {}` 里写 `flags = ...` 是给隐式接收者
/// 的属性赋值，不是给局部变量赋值，不能算作"跨函数引用局部变量"。
Set<String> _assignedNames(String body) {
  final code = _stripLiteralsAndComments(body);
  return RegExp(r'^\s*([A-Za-z_]\w*)\s*(?:[+\-*/%|&^]=|\?\?=|=)(?!=)', multiLine: true)
      .allMatches(code)
      .map((m) => m.group(1)!)
      .toSet();
}

/// 函数签名里的参数名
Set<String> _declaredParameters(String signature) {
  final open = signature.indexOf('(');
  final close = signature.lastIndexOf(')');
  if (open < 0 || close <= open) return <String>{};
  final params = signature.substring(open + 1, close);
  final names = <String>{};
  for (final part in params.split(',')) {
    final m = RegExp(r'([A-Za-z_]\w*)\s*(?::\s*[^=,]+)?\s*$').firstMatch(part.trim());
    if (m != null) {
      final n = m.group(1)!;
      // 排除 "name: Type = default" 里的 default 表达式残留
      if (!_kotlinKeywords.contains(n)) names.add(n);
    }
  }
  return names;
}

/// 函数体里引用到的标识符（排除成员访问 `a.b` / `a?.b`、关键字与字符串字面量）
Set<String> _referencedNames(String body) {
  final re = RegExp(r'(?<![.?\w])([A-Za-z_]\w*)');
  final names = <String>{};
  final code = _stripLiteralsAndComments(body);
  for (final m in re.allMatches(code)) {
    final n = m.group(1)!;
    if (_kotlinKeywords.contains(n)) continue;
    names.add(n);
  }
  return names;
}

/// 类成员级声明的名字（类体直接持有，或位于 companion object 中）
///
/// 关键：Kotlin 里 `memberCounter += 1` 这种"裸名字"和局部变量在语法上完全一样，
/// 光看引用点无法区分二者。唯一的判据是这个名字在类成员作用域里有没有声明过。
/// 所以必须先算出成员声明集合，才能判断一个跨函数引用到底是不是作用域 bug。
Set<String> _memberScopeDeclarations(String source) {
  final names = <String>{};
  final code = _stripLiteralsAndComments(source);
  final propRe = RegExp(
    r'^\s+(?:private |public |internal |protected |override |open |final |suspend |const |lateinit |vararg |@\w+ )*'
    r'(?:var|val)\s+([A-Za-z_]\w*)',
  );
  final funRe = RegExp(
    r'^\s+(?:private |public |internal |protected |override |open |final |suspend )*'
    r'fun\s+([A-Za-z_]\w*)',
  );

  // 块类型栈：'class' 表示类体/伴生对象体，'fun' 表示函数体
  // 只用深度不够 —— 类体(depth 1) 与函数体(depth 2) 深度上无法区分，
  // 但成员变量只可能出现在前者。
  final stack = <String>[];

  for (final raw in code.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;

    final inMemberScope = stack.isEmpty || stack.last == 'class';

    if (inMemberScope) {
      final p = propRe.firstMatch(raw);
      if (p != null) {
        names.add(p.group(1)!);
      } else {
        final f = funRe.firstMatch(raw);
        if (f != null) {
          names.add(f.group(1)!);
        }
      }
    }

    final opens = '{'.allMatches(line).length;
    final closes = '}'.allMatches(line).length;
    if (opens > 0) {
      final kind = RegExp(r'\bfun\b').hasMatch(line) ? 'fun' : 'class';
      for (var k = 0; k < opens; k++) {
        stack.add(kind);
      }
    }
    for (var k = 0; k < closes; k++) {
      if (stack.isNotEmpty) stack.removeLast();
    }
  }
  return names;
}

/// 扫描一个 Kotlin 文件，找出"局部变量被别的成员函数引用"的作用域越界问题。
///
/// 这类问题编译期必然报 Unresolved reference，是 release 包构建失败的直接原因。
List<String> _findScopeViolations(String source) {
  final problems = <String>[];
  final functions = _memberFunctions(source);
  final memberNames = _memberScopeDeclarations(source);

  for (final fn in functions) {
    for (final local in _declaredLocals(fn.body)) {
      // 名字在类成员里声明过 => 它本来就是成员变量，不是局部变量
      if (memberNames.contains(local)) continue;

      for (final other in functions) {
        if (other.name == fn.name) continue;
        // 对方自己声明了同名变量/参数 => 互不影响
        if (_declaredLocals(other.body).contains(local)) continue;
        if (_declaredParameters(other.signature).contains(local)) continue;
        if (!_referencedNames(other.body).contains(local)) continue;
        // 只在"读取"场景报警：在 apply {} 里写 `flags = ...` 是给隐式接收者
        // 的属性赋值，不是跨函数引用局部变量
        if (_assignedNames(other.body).contains(local)) continue;

        problems.add(
          '局部变量 `$local` 声明在 ${fn.name}() 里，却被 ${other.name}() 引用 —— '
          '跨函数作用域不可见，编译期会报 Unresolved reference',
        );
      }
    }
  }
  return problems;
}

/// 仅用于报错信息里的文件名
String _fileOf(String source) {
  if (source.contains('PokoPetView')) return 'PokoPetView.kt';
  if (source.contains('MainActivity')) return 'MainActivity.kt';
  return 'FloatingPetService.kt';
}

/// 取出形如 `val edgeThreshold = (10 * density)` 中紧跟左括号后的整数。
int? _intAfter(String source, String marker) {
  final start = source.indexOf(marker);
  if (start < 0) {
    return null;
  }
  final rest = source.substring(start + marker.length);
  final match = RegExp(r'(\d+)').firstMatch(rest);
  return match == null ? null : int.parse(match.group(1)!);
}

/// 取出 Kotlin 侧 `const val NAME = "值"` 的字面量值。
String? _kotlinConstValue(String source, String constName) {
  final match = RegExp('const val $constName\\s*=\\s*"([^"]*)"').firstMatch(source);
  return match?.group(1);
}

/// 取出 Dart 侧 `static const String name = '值';` 的字面量值。
String? _dartConstValue(String source, String fieldName) {
  final match = RegExp("static const String $fieldName\\s*=\\s*'([^']*)'")
      .firstMatch(source);
  return match?.group(1);
}

/// 解析 Kotlin 侧的 `val XXX: Map<String, String> = mapOf("KEY" to IDENT, ...)`，
/// 把 IDENT 解析回它声明时的字符串字面量。
Map<String, String> _parseKotlinConstMap(String source, String mapName) {
  final consts = <String, String>{};
  for (final m in RegExp(r'const val (\w+)\s*=\s*"([^"]*)"').allMatches(source)) {
    consts[m.group(1)!] = m.group(2)!;
  }

  final marker = 'val $mapName: Map<String, String> = mapOf(';
  final start = source.indexOf(marker);
  if (start < 0) {
    fail('未找到 Kotlin 常量表: $mapName');
  }
  final end = source.indexOf(')', start);
  if (end < 0) {
    fail('Kotlin 常量表 $mapName 未闭合');
  }
  final block = source.substring(start, end);

  final out = <String, String>{};
  for (final m in RegExp(r'"(\w+)"\s+to\s+(?:"([^"]*)"|(\w+))').allMatches(block)) {
    final key = m.group(1)!;
    final literal = m.group(2);
    final ident = m.group(3);
    String value;
    if (literal != null) {
      value = literal;
    } else {
      final resolved = consts[ident!];
      if (resolved == null) {
        fail('Kotlin 常量表 $mapName 引用了未声明的常量: $ident');
      }
      value = resolved;
    }
    out[key] = value;
  }
  return out;
}

/// 解析 Dart 侧的 `static const Map<String, String> xxx = { 'KEY': '值', ... }`。
Map<String, String> _parseDartConstMap(String source, String mapName) {
  final marker = 'Map<String, String> $mapName = {';
  final start = source.indexOf(marker);
  if (start < 0) {
    fail('未找到 Dart 常量表: $mapName');
  }
  final end = source.indexOf('};', start);
  if (end < 0) {
    fail('Dart 常量表 $mapName 未闭合');
  }
  final block = source.substring(start, end);

  final out = <String, String>{};
  for (final m in RegExp(r"'(\w+)'\s*:\s*'([^']*)'").allMatches(block)) {
    out[m.group(1)!] = m.group(2)!;
  }
  return out;
}
