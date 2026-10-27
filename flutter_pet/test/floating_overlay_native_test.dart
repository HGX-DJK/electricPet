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
  late String widgetProviderSource;
  late String manifestSource;
  late String widgetInfoXml;
  late String widgetLayoutXml;
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
    widgetProviderSource = _readRepoFile(
      packageRoot,
      'android/app/src/main/kotlin/com/electricpet/poko/PokoWidgetProvider.kt',
    );
    manifestSource = _readRepoFile(
      packageRoot,
      'android/app/src/main/AndroidManifest.xml',
    );
    widgetInfoXml = _readRepoFile(
      packageRoot,
      'android/app/src/main/res/xml/poko_widget_info.xml',
    );
    widgetLayoutXml = _readRepoFile(
      packageRoot,
      'android/app/src/main/res/layout/poko_widget.xml',
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

    test('探头偏移必须画在朝向镜像之前（屏幕坐标系位移，不被镜像反号）', () {
      // 背景（这里曾经反复改错，是"探头方向反了 / 拖到边缘就不跟手"的历史根源）：
      //
      // 水平镜像 x' = 2*cx - x 会把**任何**水平位移反号，
      // 无论平移写在镜像之前还是之后：
      //   · 先平移后镜像：M = T·S → 屏幕位移 = +tx
      //   · 先镜像后平移：M = S·T → 屏幕位移 = -tx
      //
      // 也就是说"换个顺序"根本改不掉反号 —— 正确做法是让偏移量本身与镜像无关：
      // 把 peekOffsetX 定义成**屏幕坐标系**的位移，并**先平移后镜像**。
      //
      // 旧实现是"先镜像后平移"（M = S·T，屏幕位移 = -tx），
      // 于是贴右边躲的波可会往屏幕**内侧**滑：
      // 探头完全反了向，拖拽时还会朝着手指的反方向跑，看起来就像"拖不动"。
      final drawBlock = _between(
        petViewSource,
        'override fun onDraw',
        'private fun drawTail',
      );

      final mirrorAt = drawBlock.indexOf('canvas.scale(-1f, 1f, w / 2f, h / 2f)');
      final peekAt = drawBlock.indexOf('canvas.translate(peekOffsetX, 0f)');

      expect(mirrorAt, greaterThan(0), reason: 'onDraw 里找不到朝向镜像');
      expect(peekAt, greaterThan(0), reason: 'onDraw 里找不到探头偏移平移');
      expect(
        peekAt,
        lessThan(mirrorAt),
        reason: '探头偏移必须在朝向镜像**之前**平移（M = T·S），'
            '这样 peekOffsetX 才是屏幕坐标系的位移（正 = 向屏幕右侧），'
            '镜像只翻"猫面朝哪边"、不翻偏移方向；'
            '写成"先镜像后平移"会让贴右边的波可往屏幕内侧躲，'
            '拖到边缘时猫还会朝手指的反方向跑 —— 直接表现为"拖不动"',
      );
    });

    test('探头偏移的方向约定必须是屏幕坐标系，并在服务层与绘制层保持一致', () {
      expect(petViewSource, contains('屏幕坐标系'),
          reason: 'peekOffsetX 的方向约定必须写清楚：它一旦被当成"局部坐标"理解，'
              '镜像就会把方向反掉');

      // 服务层：贴左躲 -> 负值（往屏幕左），贴右躲 -> 正值（往屏幕右）
      //
      // ⚠️ v9 起，这里的判据从"排任务时传入的 isLeft"改成了
      // "**当前窗口实际停在哪一侧**"（dockedOnLeft）。
      // 原因：探头任务延迟 5.5 秒才执行，这期间宠物可能被拖到另一侧；
      // 沿用旧的 isLeft 会让它被"横跨屏幕"瞬移回原来那侧 —— 用户说的"乱飞"。
      final peekBlock = _between(
        serviceSource,
        'private fun scheduleEdgePeeking',
        'private fun isPetDockedAtEdge',
      );
      expect(peekBlock, contains('if (dockedOnLeft) (-sizePx * 0.32f) else (sizePx * 0.32f)'),
          reason: '探头偏移必须是屏幕方向：左侧为负、右侧为正，'
              '这样"往哪边躲就往哪边藏"，与猫面朝哪边无关；'
              '而且左右必须按**当前实际停靠侧**判定，不能沿用排任务时的旧值');

      // 拖拽溢出偏移同理：手指往右推，猫就往右被推出屏幕边缘
      final moveBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_MOVE ->',
        'MotionEvent.ACTION_UP',
      );
      expect(moveBranch, contains('val overflow = (wantedX - params.x)'),
          reason: '拖拽溢出偏移必须直接来自"手指把窗口推出了多远"，'
              '否则猫会朝手指的反方向跑，表现为跟手性极差');

      // 状态徽标画在镜像矩阵**之外**，所以它必须自己再平移一次探头偏移。
      // 少了这一次，猫往屏幕边缘躲的时候徽标会留在原地不跟猫走。
      final drawBlock = _between(
        petViewSource,
        'override fun onDraw',
        'private fun drawTail',
      );
      expect(
        drawBlock.split('canvas.translate(peekOffsetX, 0f)').length - 1,
        greaterThanOrEqualTo(2),
        reason: '状态徽标画在镜像矩阵之外，必须单独再平移一次探头偏移，'
            '否则探头时徽标会留在原地、与猫身错开一整个偏移量',
      );
    });

    test('分区命中判定必须把探头偏移一起算进去', () {
      final hitBlock = _between(
        petViewSource,
        'fun hitTest(x: Float, y: Float): TouchZone',
        'fun reactToTouch',
      );

      expect(
        hitBlock,
        contains('peekOffsetX'),
        reason: '命中判定没有把探头绘制偏移算进去，会出现「看到的是头、摸到的却是身体」',
      );
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

  group('拖不动专项：触摸必须真的落到宠物身上', () {
    // 用户反馈原文：
    // 「新安装包手机端的桌面悬浮宠物会出现有时候可以拖动，有时候又拖动不了的情况，
    //  特别是关闭 app，再打开这个桌面悬浮宠物，在拖动好多时候都拖不动」
    //
    // 这一组把"按下 → 跟手"这条链路上所有会导致"按不动 / 拖不动"的坑逐条钉死。
    // 触摸链路在原生侧，widget 测试覆盖不到，只能用源码断言固化。

    test('悬浮窗脱挂必须能自愈：拖拽链路不能永久失效', () {
      expect(serviceSource, contains('private fun ensurePetWindowAttached()'),
          reason: '缺少悬浮窗挂载体检：「View 还在、窗口却已从 WindowManager 脱挂」时'
              '所有触摸都收不到，而且永远不会自己恢复');
      expect(serviceSource, contains('private fun reattachPetWindow()'),
          reason: '缺少悬浮窗重新挂载逻辑');
      expect(serviceSource, contains('isAttachedToWindow'),
          reason: '挂载体检必须真的检查 View 是否还挂在 WindowManager 上');

      final downBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_DOWN ->',
        'MotionEvent.ACTION_POINTER_DOWN',
      );
      expect(_stripLiteralsAndComments(downBranch), isNot(contains('ensurePetWindowAttached()')),
          reason: '按下分支里绝不能调用挂载自愈（它会重建窗口）：'
              '触摸手势属于窗口而不是屏幕，removeView + addView 会把当前手势一起丢掉，'
              '表现为「按下完全没反应、宠物根本拖不动」');

      final moveBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_MOVE ->',
        'MotionEvent.ACTION_UP',
      );
      // ⚠️ 这条断言在 v9 被推翻了。
      //
      // 旧断言要求"位置更新失败后立刻重挂窗口"，理由是窗口脱挂了就再也收不到触摸。
      // 但它忽略了一件事：**触摸手势属于窗口，而不是屏幕**。
      // removeView + addView 换掉窗口的那一刻，系统会把当前这根手指的
      // MOVE / UP 一起丢掉 —— 于是出现一个非常矛盾的现象：
      //   日志里明明已经打了「进入拖拽」，宠物却纹丝不动。
      // 这正是用户反馈的「有时候有进入拖拽，但是不动」。
      //
      // 正确做法：拖拽途中只记"待重挂"标记，等手势彻底结束，
      // 由手势之外的看门狗统一重挂 —— 既不丢手势，又能自愈。
      expect(_stripLiteralsAndComments(moveBranch), isNot(contains('reattachPetWindow()')),
          reason: '拖拽途中绝不能重建窗口 —— 触摸手势属于窗口而不是屏幕，'
              'removeView + addView 换掉窗口的那一刻，'
              '系统会把当前这根手指的 MOVE / UP 一起丢掉，'
              '表现出来就是「日志里已经打了『进入拖拽』，宠物却纹丝不动」');
      expect(_stripLiteralsAndComments(moveBranch), contains('petWindowNeedsReattach = true'),
          reason: '位置更新失败必须记下「待重挂」标记，'
              '否则窗口脱挂之后再也收不到触摸，而且永远不会自愈');
    });

    test('挂载体检绝不能用 View.parent 判断，且不得在手势进行中重建窗口', () {
      // 这条是"宠物完全拖不动"的直接原因 —— 而且它是被当成"修复"引进来的：
      //
      //   1. `WindowManager.addView()` 挂上去的视图，它的 parent 不是"是否还挂在窗口上"
      //      的可靠信号；拿 parent 判定会把**好好挂着**误判成"已脱挂"。
      //      （同一个坑在快捷菜单上早就踩过，所以那边用的是显式标记 isActionMenuAttached。）
      //   2. 于是 ACTION_DOWN 里调 ensurePetWindowAttached() 时，
      //      **每次按下都会 removeView + addView 重建窗口**。
      //   3. 触摸手势是跟着**窗口**走的：窗口一换，系统就把当前这根手指的触摸流一起丢掉，
      //      MOVE / UP 全部收不到 —— 按下完全没反应，宠物根本拖不动。
      //
      // 正确做法：用显式标记记录挂载状态，并且**绝不在手势进行中重建窗口**。
      final ensure = _braceBlock(serviceSource, 'private fun ensurePetWindowAttached()');
      expect(ensure, isNot(contains('view.parent')),
          reason: '挂载体检不能依赖 View.parent —— 对 WindowManager.addView 挂上去的视图，'
              'parent 不是"是否还挂着"的可靠信号，用它判定会把正常状态误判成脱挂');
      expect(serviceSource, contains('private var isPetWindowAttached: Boolean = false'),
          reason: '必须用显式标记记录悬浮窗的挂载状态'
              '（快捷菜单的 isActionMenuAttached 就是同样的做法），不能依赖 View.parent');
      expect(ensure, contains('isPetWindowAttached'),
          reason: '挂载体检必须基于显式标记');
      expect(_stripLiteralsAndComments(ensure), contains('isAttachedToWindow'),
          reason: '还必须叠加 View 自己的挂载状态，才能覆盖"被系统悄悄摘掉"的情况');

      // 看门狗必须在没有手指按着的时候才动手
      expect(serviceSource, contains('private val attachWatchdog'),
          reason: '缺少挂载看门狗；窗口静默脱挂时需要有人负责把它挂回去');
      final watchdog = _braceBlock(serviceSource, 'private val attachWatchdog');
      expect(watchdog, contains('if (hasTouchDown) return'),
          reason: '看门狗必须在没有任何手指按着的时候才动手，'
              '绝不能在手势进行中重建窗口');
      expect(watchdog, contains('ensurePetWindowAttached()'),
          reason: '看门狗发现脱挂后必须真正重挂');
    });

    test('拖拽位移必须用不受「窗口落后一帧」影响的坐标口径', () {
      // ⚠️ v10 推翻了 v8 的结论。
      //
      // v8 认为「窗口位置 + 窗口局部坐标」是无歧义的、绝对安全的算法。**它是错的**：
      //   · params.x 是我们**请求**的窗口位置 —— 同一帧内它就会被改写；
      //   · event.x 是相对窗口**真实**位置算出来的 —— 而窗口真正挪到新位置
      //     要等下一帧的 traversal（updateViewLayout 是跨进程异步的）。
      //
      // 于是同一帧里再来第 2、第 3 个 MOVE 事件时，
      // 新的 params.x 配旧的 event.x，算出来的"手指位置"凭空多出一整帧的位移，
      // 窗口每帧都往前冲一截 —— 表现就是**拖拽乱飞**；
      // 贴边时被钳制吃掉，就变成**拖不动**。
      //
      // 正确做法：优先用 event.rawX —— 它是输入管线里的屏幕绝对坐标，
      // **完全不受窗口什么时候真正挪过去的影响**，同一帧来几个 MOVE 都不会错位。
      // 同时在 ACTION_DOWN 那一刻**自校准**判定 rawX 的语义，
      // 万一某台机器上 rawX 不是屏幕绝对坐标，再退回局部坐标算法（并记进日志）。
      final moveBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_MOVE ->',
        'MotionEvent.ACTION_UP',
      );
      final moveCode = _stripLiteralsAndComments(moveBranch);

      expect(moveCode, contains('event.rawX + rawAnchorX'),
          reason: '首选必须用 raw 坐标口径：它是屏幕绝对坐标，'
              '不受「窗口真正挪过去要等下一帧」的影响');
      expect(moveCode, contains('params.x + event.x'),
          reason: '必须保留局部坐标算法作为兜底：'
              '万一某台机器上 rawX 不是屏幕绝对坐标');
      expect(moveCode, contains('if (rawIsScreenAbsolute)'),
          reason: '必须由 ACTION_DOWN 的自校准结果来决定用哪一种口径，'
              '而不是拍脑袋写死');
      expect(moveCode, contains('initialX + (fingerX - initialFingerX)'),
          reason: '窗口新位置 = 按下时的位置 + 手指的累计位移');
      expect(moveCode, contains('val clampedX = wantedX.coerceIn(0, maxX)'),
          reason: '窗口位置必须先算出"想去的位置"再钳制在屏幕内');
      expect(moveCode, contains('initialFingerX += (wantedX - clampedX)'),
          reason: '被边界吃掉的位移必须消费掉，否则往回拉时宠物会粘在屏幕边缘，'
              '用户感知就是「拖不动 / 粘手」');

      // 自校准：按下这一刻 params.x 就是窗口真实的屏幕原点，
      // 所以 rawX - event.x 要么等于窗口原点（rawX 是屏幕绝对坐标），要么等于 0。
      final downBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_DOWN ->',
        'MotionEvent.ACTION_POINTER_DOWN',
      );
      final downCode = _stripLiteralsAndComments(downBranch);
      expect(downCode, contains('val rawOriginX = event.rawX - event.x'),
          reason: '必须靠「rawX - 局部坐标」反推 rawX 的语义，这是唯一可靠的判据');
      expect(downCode, contains('rawIsScreenAbsolute ='),
          reason: '必须在按下这一刻就把语义判出来，'
              '整段手势才能用同一种口径');
      expect(downCode, contains('rawAnchorX = initialFingerX - event.rawX'),
          reason: '必须用锚点把 rawX 换算到窗口坐标系，'
              '顺手吸收状态栏 / 挖孔带来的常量偏移，'
              '保证窗口位移等于 rawX 的纯增量');
    });

    test('拖拽释放速度也必须由局部坐标推算，惯性方向才可靠', () {
      final upBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_UP -> {',
        'private fun refreshPetVisibility',
      );
      expect(_stripLiteralsAndComments(upBranch), isNot(contains('VelocityTracker')),
          reason: 'VelocityTracker 同样建立在 raw 坐标上，'
              '在悬浮窗上算出来的甩动方向可能与手指相反');
      expect(upBranch, contains('velocityX'),
          reason: '释放速度必须用局部坐标 + eventTime 自行推算');
      expect(serviceSource, contains('event.eventTime'),
          reason: '时间基准必须用 event.eventTime（语义明确），不能靠墙钟时间');
    });

    test('手势被系统中断时必须彻底复位状态，否则下一把拖拽会走错分支', () {
      final cancelBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_CANCEL -> {',
        'MotionEvent.ACTION_UP -> {',
      );
      final cancelCode = _stripLiteralsAndComments(cancelBranch);

      expect(cancelCode, contains('isClick = false'),
          reason: '中断后必须复位 isClick，否则松手会被误判成单击');
      expect(cancelCode, contains('hasDragged = false'),
          reason: '中断后必须复位 hasDragged');
      expect(cancelCode, contains('isPinching = false'),
          reason: '中断后必须复位捏合状态');
    });

  group('拖拽数学：行为级模拟（不依赖真机）', () {
    // 这一组不再断言源码长什么样，而是**把算法原样复刻出来跑数值**。
    //
    // 原因：源码断言只能证明"代码写成了某个样子"，证明不了"算出来对不对"；
    // 而这次的问题恰恰是算法本身错（依赖 rawX 语义），
    // 源码长得再规范，算错还是错。
    //
    // 复刻的公式（与 FloatingPetService.ACTION_MOVE 一致）：
    //   手指屏幕绝对位置 F = 窗口位置 W + 窗口局部坐标 l
    //   窗口新位置 W' = W_0 + (F_now - F_0)
    test('窗口位移必须始终等于手指位移（不能只跟第一帧）', () {
      final sim = _DragSim(
        windowX: 0,
        windowY: 0,
        windowSize: 82,
        screenWidth: 400,
        screenHeight: 800,
      );
      sim.down(50, 50);

      // 手指的屏幕位置依次 100 / 150 / 200 / 250
      for (final target in [100.0, 150.0, 200.0, 250.0]) {
        // 事件里的局部坐标 = 手指屏幕位置 - 此刻的窗口位置
        sim.move(target - sim.windowX, 50 - sim.windowY);
      }

      // 手指从 50 走到 250 → 位移 200 → 窗口必须也移动 200
      expect(sim.windowX, 200.0,
          reason: '窗口必须一路跟着手指走；'
              '旧实现（用 rawX 算位移）在窗口动过之后就再也算不出位移，'
              '表现为"只跟第一帧然后卡住"');
    });

    test('旧算法（rawX 语义为窗口内坐标）在窗口动过之后就卡住 —— 这就是时好时坏的来源', () {
      final sim = _DragSim(
        windowX: 0,
        windowY: 0,
        windowSize: 82,
        screenWidth: 400,
        screenHeight: 800,
        useRawCoordinateFormula: true,
      );
      sim.down(50, 50);

      for (final target in [100.0, 150.0, 200.0, 250.0]) {
        sim.move(target - sim.windowX, 50 - sim.windowY);
      }

      // 复刻旧算法：dx = rawX - initialRawX，rawX 取窗口内坐标
      expect(sim.windowX, lessThan(200.0),
          reason: '旧算法在这里明显跟不上手指（这正是用户看到的"拖到一半卡住"）。'
              '本测试的作用是把"为什么必须换掉 rawX"钉死，'
              '防止以后有人又把位移改回 rawX。');
    });

    test('拖到屏幕边缘被钳制后再往回拖，窗口必须平滑跟回，不能粘在边缘', () {
      final sim = _DragSim(
        windowX: 300,
        windowY: 300,
        windowSize: 82,
        screenWidth: 400,
        screenHeight: 800,
      );
      sim.down(50, 50);

      // 往右下拖到屏幕外（会被钳制在 318 / 718）
      for (final target in [350.0, 420.0, 500.0]) {
        sim.move(target - sim.windowX, 50 - sim.windowY);
      }
      expect(sim.windowX, 318.0, reason: '窗口必须被钳在屏幕内');

      // 往回拖 60px：被边界吃掉的位移必须被"消费掉"，
      // 窗口必须立刻跟回 60px，而不是先粘在边缘上一段距离。
      for (final target in [470.0, 440.0]) {
        sim.move(target - sim.windowX, 50 - sim.windowY);
      }
      expect(sim.windowX, closeTo(258.0, 0.001),
          reason: '回拖必须 1:1 跟回（318 - 60 = 258）；'
              '若窗口还粘在 318，说明被边界吃掉的位移没有消费掉，'
              '用户感知就是"拖到边缘就粘住、拉不回来"');
    });

    test('纵向拖动同样必须跟手（不能只跟横向）', () {
      final sim = _DragSim(
        windowX: 100,
        windowY: 100,
        windowSize: 82,
        screenWidth: 400,
        screenHeight: 800,
      );
      sim.down(40, 40);

      // 手指的横向保持 140 不变，纵向依次走到 200 / 260 / 320
      for (final target in [200.0, 260.0, 320.0]) {
        sim.move(140 - sim.windowX, target - sim.windowY);
      }
      expect(sim.windowY, 280.0,
          reason: '手指纵向从 140 走到 320 → 窗口必须同步下移 180（100 → 280）');
    });
  });

  group('乱飞专项：窗口坐标只能有一个写入者', () {
    // 用户反馈原文（第 4 轮）：
    // 「触摸按下有时候有进入拖拽，但是不动，有时候好像没有进入；有时候拖着还乱飞」
    //
    // 这一组把"谁有权写悬浮窗坐标"这件事钉死。
    //
    // 背景：悬浮窗的坐标 params.x / params.y 至少被 5 个地方写：
    //   ① 手势处理器（拖拽）        ← 手指按住时**唯一**合法的写入者
    //   ② 惯性滑行 flingAnimator
    //   ③ 贴边吸附 edgeSnapAnimator
    //   ④ 自主散步 strollAnimator
    //   ⑤ 探头调度 peekingRunnable
    //
    // 只要它们在手指按着的时候还在写，宠物就会"一边跟手指一边往别处跑"——
    // 这就是「乱飞」。而 Android 的 cancel() 会**先**回调 onAnimationCancel、
    // **再**回调 onAnimationEnd，所以"用户按住宠物 → 取消动画"这条路径上，
    // 旧实现会在新手势进行中又启动新的落位动画 / 探头调度。

    test('拖拽阈值必须用手指真实行程，不能用会被边界改写的位移', () {
      // 贴着屏幕边缘继续往外推时，窗口没地方去了，位移不再增长；
      // 但手指明明推了很远。旧实现用位移判阈值 → 永远进不了拖拽态 →
      // 用户看到的就是「有时候好像没有进入」。
      final moveBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_MOVE ->',
        'MotionEvent.ACTION_UP',
      );
      final moveCode = _stripLiteralsAndComments(moveBranch);

      expect(moveCode, contains('gestureStartFingerX'),
          reason: '必须有一个**不可变**的手势起点基线来度量手指真实行程');
      expect(moveCode, contains('val travelDx = (fingerX - gestureStartFingerX).toInt()'),
          reason: '拖拽阈值必须用手指相对手势起点的真实行程');
      expect(moveCode, contains('abs(travelDx) > touchSlop'),
          reason: '进入拖拽的判定必须基于真实行程，'
              '否则贴边外推时窗口动不了、阈值也过不去，用户以为"没进入拖拽"');
      expect(moveCode, isNot(contains('abs(totalDx) > touchSlop')),
          reason: 'totalDx 会被"边界钳制消费"改写，拿它判阈值在贴边时永远进不了拖拽态');
    });

    test('探头任务必须在运行时复查边缘，停靠侧也必须按当前位置判定', () {
      // 这是「有时候拖着还乱飞」的头号来源：
      //
      // 探头任务排下去之后要等 5.5 秒才执行。这 5.5 秒里宠物完全可能被
      // 用户拖走、被甩到另一边、或者被别的动画挪走。
      //
      // 旧实现只在**排任务时**检查了一次"是否停在边缘"，运行时直接
      //   params.x = dockedX
      // 把窗口硬拽回边缘；而 dockedX 用的是 **5.5 秒前捕获的 isLeft**，
      // 宠物被拖到另一侧时会被"横跨屏幕"瞬移回原来那侧。
      //
      // 5.5 秒的时序窗口，恰好解释了用户说的「时好时坏」。
      final peekFun = _braceBlock(serviceSource, 'private fun scheduleEdgePeeking');
      final runnable = _braceBlock(peekFun, 'peekingRunnable = Runnable {');
      final runnableCode = _stripLiteralsAndComments(runnable);

      expect(runnableCode, contains('if (!isPetDockedAtEdge()) return@Runnable'),
          reason: '探头任务**运行时**必须重新确认宠物此刻还停在边缘；'
              '只检查排任务时的那一刻，会把停在屏幕中间的宠物硬拽回边缘');
      expect(runnableCode, contains('peekScheduledX'),
          reason: '必须记录排任务时宠物的位置，'
              '运行时发现它被挪走了就要放弃探头，而不是把它拽回边缘');
      expect(runnableCode, contains('val dockedOnLeft = params.x <= snapRange'),
          reason: '停靠侧必须按**当前**窗口位置判定，'
              '绝不能沿用排任务时捕获的 isLeft —— 那会造成横跨屏幕的瞬移');
      expect(runnableCode, isNot(contains('val dockedX = if (isLeft)')),
          reason: 'dockedX 绝不能再由排任务时捕获的 isLeft 决定');
      expect(runnableCode, contains('val peekOffset = if (dockedOnLeft)'),
          reason: '探头偏移方向必须与"当前实际停靠侧"一致，'
              '否则宠物换边后探头会朝屏幕内侧滑');
    });

    test('动画器被取消时不得触发落位 / 探头调度', () {
      // Android 的 cancel() 会**先**回调 onAnimationCancel、**再**回调 onAnimationEnd。
      //
      // 用户在惯性滑行途中重新按住宠物 → ACTION_DOWN 里 cancel()
      // → onAnimationEnd 照样触发 → settleAfterDrag() 又启动新的落位吸附动画
      // → 宠物在新手势进行中自己往边缘滑走。
      //
      // 这就是「有时候拖着还乱飞」的确切来源之一。
      // 注意：不能用 Animator.isCanceled 判定 —— 它不是公开 SDK API，会编译失败。
      final fling = _braceBlock(serviceSource, 'flingAnimator = ValueAnimator.ofFloat(0f, 1f).apply {');
      expect(fling, contains('onAnimationCancel'),
          reason: '惯性动画必须能区分"播完"与"被取消"');
      expect(fling, contains('private var cancelled = false'),
          reason: '惯性动画必须用本地 cancelled 标记区分取消');
      expect(_stripLiteralsAndComments(_onAnimationEndBody(fling)),
          contains('if (cancelled) return'),
          reason: '被取消的惯性动画不得再启动落位逻辑，'
              '否则新手势进行中宠物会自己滑走');

      final snap = _braceBlock(serviceSource, 'edgeSnapAnimator = ValueAnimator.ofFloat(0f, 1f).apply {');
      expect(snap, contains('onAnimationCancel'),
          reason: '贴边吸附动画必须能区分"播完"与"被取消"');
      expect(_stripLiteralsAndComments(_onAnimationEndBody(snap)),
          contains('if (cancelled) return'),
          reason: '被取消的吸附动画不得再排探头任务 —— '
              '那等于在手势进行中排了个"把宠物拽回边缘"的任务');

      final stroll = _braceBlock(serviceSource, 'strollAnimator = ValueAnimator.ofFloat(0f, 1f).apply {');
      expect(stroll, contains('onAnimationCancel'),
          reason: '自主散步动画必须能区分"播完"与"被取消"');
      expect(_stripLiteralsAndComments(_onAnimationEndBody(stroll)),
          contains('if (cancelled) return'),
          reason: '被打断的散步不得再排探头任务');
    });

    test('手势进行中，动画器不得写窗口坐标（单写者原则）', () {
      // 只要动画器在手指按着的时候还能改 params.x / params.y，
      // 宠物就会一边跟手指一边往动画目标跑 —— 用户看到的就是「乱飞」。
      final fling = _braceBlock(serviceSource, 'flingAnimator = ValueAnimator.ofFloat(0f, 1f).apply {');
      final snap = _braceBlock(serviceSource, 'edgeSnapAnimator = ValueAnimator.ofFloat(0f, 1f).apply {');
      final stroll = _braceBlock(serviceSource, 'strollAnimator = ValueAnimator.ofFloat(0f, 1f).apply {');

      for (final entry in {
        '惯性滑行': fling,
        '贴边吸附': snap,
        '自主散步': stroll,
      }.entries) {
        expect(_stripLiteralsAndComments(entry.value), contains('if (!hasTouchDown)'),
            reason: '${entry.key}动画在写窗口坐标前必须检查"手指是不是还按着"；'
                '手指按着时窗口坐标只属于手势处理器');
      }
    });

    test('窗口坐标的其它写入者（探头调度）也必须避开手势进行中', () {
      final peekFun = _braceBlock(serviceSource, 'private fun scheduleEdgePeeking');
      final runnable = _braceBlock(peekFun, 'peekingRunnable = Runnable {');
      expect(_stripLiteralsAndComments(runnable), contains('hasTouchDown'),
          reason: '探头任务执行时必须确认没有手指按着，'
              '否则会在用户正拖它的时候把窗口挪走');
    });

    test('重建窗口必须有总闸：手势进行中任何路径都不许换窗口', () {
      // reattachPetWindow() 是所有"重建窗口"路径的总入口：
      //   看门狗、挂载体检 ensurePetWindowAttached()、显隐恢复
      //   restorePetWindowForInteraction()、拖拽失败重试……
      //
      // 只要有一条路径能在用户正按着的时候换窗口，这根手指后面的 MOVE / UP 就全丢了，
      // 表现出来就是「日志里已经打了『进入拖拽』，宠物却纹丝不动」。
      //
      // 所以总闸必须落在 reattachPetWindow() 自己身上，
      // 而不是指望每个调用方都记得检查（早晚会有新的调用方漏掉）。
      final reattach = _braceBlock(serviceSource, 'private fun reattachPetWindow()');
      final reattachCode = _stripLiteralsAndComments(reattach);
      expect(reattachCode, contains('if (hasTouchDown)'),
          reason: '重建窗口的总入口必须挡下手势进行中的调用');
      expect(reattachCode, contains('petWindowNeedsReattach = true'),
          reason: '挡下来之后要记下待重挂标记，'
              '否则窗口可能就这么挂着坏状态，直到下个看门狗周期才恢复');
      expect(reattachCode.indexOf('if (hasTouchDown)'),
          lessThan(reattachCode.indexOf('removeView')),
          reason: '总闸必须在 removeView 之前生效 —— '
              '先摘了再判断就晚了，手势已经断了');

      // 显隐恢复路径同理：它会重建窗口，也会顺带把坐标钳回屏内（等于把宠物挪走）
      final restore =
          _braceBlock(serviceSource, 'private fun restorePetWindowForInteraction()');
      expect(_stripLiteralsAndComments(restore), contains('if (hasTouchDown)'),
          reason: '显隐恢复会重建窗口并改坐标，手势进行中必须让路');

      final visibility =
          _braceBlock(serviceSource, 'private fun refreshPetVisibility(');
      expect(_stripLiteralsAndComments(visibility), contains('if (!hasTouchDown)'),
          reason: '显隐刷新里"把坐标钳回屏内"这一步会移动宠物，'
              '手势进行中绝不能做');
    });

    test('必须留下"进入拖拽却没动"的现场日志，否则下一轮只能靠猜', () {
      // 这一轮已经修掉了好几条确定的成因，但真机上的行为还需要用户实测确认。
      // 万一还有漏网的，必须留下现场证据：
      //   已进入拖拽、没被边界钳住、手指也在动，窗口坐标却一帧都没变。
      final moveBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_MOVE ->',
        'MotionEvent.ACTION_UP',
      );
      final moveCode = _stripLiteralsAndComments(moveBranch);
      expect(serviceSource, contains('var lastAppliedX'),
          reason: '缺少"进入拖拽却不动"的现场判定基线：'
              '必须记住上一帧真正写进窗口的坐标，才能发现窗口一帧都没动；'
              '没有它，下一轮反馈就只能靠猜');
      expect(moveCode, contains('params.x == lastAppliedX && params.y == lastAppliedY'),
          reason: '诊断必须真的比对"这一帧"和"上一帧"的窗口坐标，'
              '光记住坐标不比对等于没记');
      expect(moveCode, contains('wantedX == clampedX'),
          reason: '诊断必须先排除"被屏幕边界钳住"这种正常情况，否则全是误报');
      expect(moveBranch, contains('拖拽中窗口位置没有变化'),
          reason: '缺少"进入拖拽却不动"的现场日志文案');
    });
  });

  group('乱飞专项：行为级模拟（不依赖真机）', () {
    test('宠物被拖到屏幕中间后，探头任务必须放弃，不得把它拽回边缘', () {
      final sim = _PeekTaskSim(
        windowX: 8,
        windowY: 400,
        windowSize: 160,
        screenWidth: 1080,
        screenHeight: 2200,
        density: 3.0,
        isLeftAtSchedule: true,
      );
      sim.schedule();

      // 5.5 秒里用户把宠物拖到了屏幕中间
      sim.windowX = 460;

      final before = sim.windowX;
      sim.run();
      expect(sim.resultX, isNull,
          reason: '宠物已经不在边缘了，探头任务必须放弃 —— '
              '旧实现会把一个停在屏幕中间的宠物硬拽回边缘');
      expect(sim.windowX, before,
          reason: '放弃任务时窗口坐标绝不能被改动');
    });

    test('宠物被拖到另一侧后，探头任务绝不能横跨屏幕瞬移', () {
      final sim = _PeekTaskSim(
        windowX: 8,
        windowY: 400,
        windowSize: 160,
        screenWidth: 1080,
        screenHeight: 2200,
        density: 3.0,
        isLeftAtSchedule: true,
      );
      sim.schedule();

      // 5.5 秒里用户把宠物拖到了右边
      sim.windowX = 1080 - 160 - 8;

      sim.run();

      final leftDockedX = 4 * 3.0;
      expect(sim.resultX, isNull,
          reason: '宠物被挪走太远，探头任务应当放弃');
      expect(sim.windowX, isNot(closeTo(leftDockedX, 1.0)),
          reason: '绝不能把宠物瞬移回 5.5 秒前那一侧的边缘');
      expect(sim.windowX, closeTo(1080 - 160 - 8, 1.0),
          reason: '宠物必须留在用户放它的位置');
    });

    test('即使漂移检查放行，停靠侧也必须按当前位置判定', () {
      // 把漂移检查关掉，只验证"停靠侧来自当前位置"这一条：
      // 旧实现用排任务时捕获的 isLeft，宠物在右边却会被算成左边。
      final sim = _PeekTaskSim(
        windowX: 8,
        windowY: 400,
        windowSize: 160,
        screenWidth: 1080,
        screenHeight: 2200,
        density: 3.0,
        isLeftAtSchedule: true,
        enforceDrift: false,
      );
      sim.schedule();

      // 宠物此刻在右侧边缘，但排任务时的参考侧是左边
      sim.windowX = 1080 - 160 - 8;
      sim.run();

      final rightDockedX = 1080 - 160 - 4 * 3.0;
      final leftDockedX = 4 * 3.0;
      expect(sim.windowX, closeTo(rightDockedX, 1.0),
          reason: '探头必须贴在**当前**所在的那一侧');
      expect(sim.windowX, isNot(closeTo(leftDockedX, 1.0)),
          reason: '沿用旧的参考侧会造成横跨屏幕的瞬移（用户说的"乱飞"）');
    });

    test('用户按住宠物时取消惯性动画，宠物不得再自己往落位目标滑', () {
      final sim = _FlingVsTouchSim(
        windowX: 100,
        snapTargetX: 900,
      );
      sim.touchDown = true;
      sim.cancel();

      expect(sim.settleStarted, isFalse,
          reason: '取消动画不得启动新的落位动画 —— '
              '那会让宠物在用户正按着的时候自己往边缘滑（"拖着还乱飞"）');
      expect(sim.windowX, 100.0,
          reason: '手指按着期间，窗口坐标只能属于手势处理器');
    });

    test('旧实现（取消仍触发落位 + 动画器照写坐标）在同一场景下确实会乱飞', () {
      // 这条测试的作用是把"为什么必须加取消守卫"钉死，
      // 防止以后有人为了"简化"把守卫删掉。
      final sim = _FlingVsTouchSim(
        windowX: 100,
        snapTargetX: 900,
        guardAgainstCancel: false,
        guardSingleWriter: false,
      );
      sim.touchDown = true;
      sim.cancel();
      sim.update(0.5);

      expect(sim.settleStarted, isTrue,
          reason: '旧实现里 cancel() 触发的 onAnimationEnd 会启动落位动画');
      expect(sim.windowX, isNot(100.0),
          reason: '旧实现下宠物会在手指按住期间自己往落位目标移动 —— 这就是"乱飞"');
    });

    test('贴着屏幕边缘继续外推也必须进入拖拽态', () {
      final sim = _DragSim(
        windowX: 318,
        windowY: 300,
        windowSize: 82,
        screenWidth: 400,
        screenHeight: 800,
        touchSlop: 12,
      );
      sim.down(50, 50);

      // 手指继续往右推 200px（窗口已经贴到右边缘，去不了了）
      for (final target in [380.0, 450.0, 520.0]) {
        sim.move(target - sim.windowX, 50 - sim.windowY);
      }

      expect(sim.windowX, 318.0, reason: '窗口必须被钳在屏幕内');
      expect(sim.enteredDrag, isTrue,
          reason: '手指真实行程已经超过阈值，必须进入拖拽态；'
              '旧实现用"窗口位移"判阈值，贴边时永远进不去 —— '
              '用户看到的就是"有时候好像没有进入"');
    });
  });

  group('拖拽口径：行为级模拟（不依赖真机）', () {
    // 这一组针对的是 v10 的核心结论：
    // 「窗口位置 + 窗口局部坐标」不是无歧义的算法，它会把
    // "我们请求的位置"和"窗口真实位置"混在一起算，
    // 于是每帧都冲过头 —— 这就是**拖拽乱飞**。
    //
    // 复刻的两个平台事实：
    //   ① updateViewLayout 跨进程异步，窗口真正挪过去要等下一帧；
    //   ② 事件里的局部坐标相对窗口**真实**位置。

    test('v8 的局部坐标算法会冲过头，raw 坐标算法与手指严格 1:1', () {
      final stale = _DragAlgoSim(
        mode: 'local',
        startWindowX: 100,
        windowSize: 82,
        screenWidth: 400,
        startFingerX: 150,
      );
      final raw = _DragAlgoSim(
        mode: 'raw',
        startWindowX: 100,
        windowSize: 82,
        screenWidth: 400,
        startFingerX: 150,
      );
      stale.begin();
      raw.begin();

      // 同一帧里来了 3 个 MOVE 事件：手指 150 → 180 → 210 → 240
      for (final fx in [180.0, 210.0, 240.0]) {
        stale.moveFingerTo(fx);
        raw.moveFingerTo(fx);
      }
      stale.advanceFrame();
      raw.advanceFrame();

      // 手指一共走了 90px → 窗口必须正好挪 90px（100 → 190）
      expect(raw.requestedX, closeTo(190.0, 0.001),
          reason: 'raw 坐标口径下窗口必须严格跟着手指走');
      expect(stale.requestedX, isNot(closeTo(190.0, 0.001)),
          reason: '局部坐标口径会把"请求的位置"和"真实位置"混在一起算，'
              '每帧都冲过头 —— 这就是拖拽乱飞的机制。'
              '本测试的作用是把"为什么必须换掉它"钉死。');
      expect(stale.requestedX, greaterThan(raw.requestedX),
          reason: '旧口径只会冲过头，不会冲得不够');
    });

    test('raw 口径在连着多帧拖拽后依然与手指严格同步', () {
      final raw = _DragAlgoSim(
        mode: 'raw',
        startWindowX: 0,
        windowSize: 82,
        screenWidth: 400,
        startFingerX: 40,
      );
      raw.begin();

      var finger = 40.0;
      for (var frame = 0; frame < 8; frame++) {
        for (var i = 0; i < 3; i++) {
          finger += 7.0;
          raw.moveFingerTo(finger);
        }
        raw.advanceFrame();
      }

      // 手指一共走了 8*3*7 = 168px
      expect(raw.requestedX, closeTo(168.0, 0.001),
          reason: '无论一帧来几个 MOVE，窗口都必须严格等于手指的累计位移');
      expect(raw.requestedX - raw.actualX, closeTo(0.0, 0.001),
          reason: '帧结束时窗口真实位置必须已经追上请求的位置');
    });

    test('自校准判据：能区分 rawX 是屏幕绝对坐标还是窗口内坐标', () {
      // 复刻 ACTION_DOWN 里的判定：
      //   rawOrigin = rawX - event.x
      //   屏幕绝对坐标 → rawOrigin ≈ 窗口原点（params.x）
      //   窗口内坐标   → rawOrigin ≈ 0
      bool isScreenAbsolute(double rawX, double eventX, double windowX) {
        final rawOrigin = rawX - eventX;
        final xEvidence = windowX.abs();
        final yEvidence = 100.0; // 纵向更远离边，判据更硬
        if (xEvidence >= yEvidence) {
          return (rawOrigin - windowX).abs() <= rawOrigin.abs();
        }
        return false;
      }

      // rawX 是屏幕绝对坐标：rawX = 窗口原点 + 局部坐标
      expect(isScreenAbsolute(100 + 30, 30, 100), isTrue,
          reason: 'rawX 明显带着窗口原点，必须判定为"屏幕绝对坐标"');
      // rawX 是窗口内坐标：rawX ≈ 局部坐标
      expect(isScreenAbsolute(30, 30, 100), isFalse,
          reason: 'rawX 不带窗口原点，必须判定为"窗口内坐标"并退回局部算法');
    });
  });

  group('气泡必须贴着猫（不能离猫老远）', () {
    // 用户反馈原文：「弹窗和宠物偏离老远」。
    //
    // 两个成因：
    //   ① 气泡按**窗口**位置摆，而猫是用**绘制偏移**画在窗口之外的
    //      （探头避让 / 把猫推出屏幕边缘）→ 贴边时气泡离猫老远；
    //   ② 气泡（最多 200dp）比猫（82dp）宽得多，一律"与猫居中对齐"，
    //      再被屏幕边界钳一下，气泡就被推得离猫更远。

    test('气泡必须跟着猫的「绘制位置」走，而不是窗口位置', () {
      final compute = _braceBlock(serviceSource, 'private fun computeBubblePosition(');
      expect(compute, contains('peekOffsetX'),
          reason: '猫在探头 / 拖出屏幕时是用绘制偏移画在窗口之外的，'
              '气泡必须按绘制位置摆，否则贴边时气泡离猫老远');
      expect(compute, contains('val catX = pParams.x + (pokoView?.peekOffsetX ?: 0f)'),
          reason: '气泡的横向基准必须是"猫实际画出来的位置"');
    });

    test('气泡的显示与跟随必须共用同一套位置算法', () {
      expect(serviceSource, contains('private fun computeBubblePosition('),
          reason: '必须把位置算法抽成独立函数');
      final showBubble = _braceBlock(serviceSource, 'private fun showCustomSpeechBubble(');
      expect(_stripLiteralsAndComments(showBubble), contains('computeBubblePosition('),
          reason: '弹气泡时也必须用统一算法，'
              '否则会出现"刚弹出来贴着猫，拖两步就离猫老远"');
      final updateBubble = _braceBlock(serviceSource, 'private fun updateBubblePosition()');
      expect(_stripLiteralsAndComments(updateBubble), contains('computeBubblePosition('),
          reason: '拖拽跟随也必须用同一套算法');
    });

    test('气泡放不下时必须贴到猫的边缘，不能只是把居中位置钳进屏幕', () {
      // ⚠️ 这一条必须用**源码断言**钉住，不能只靠行为模拟：
      //    行为模拟复刻的是"规则应该是什么"，它证明不了"代码确实是这么实现的"。
      //    没有源码断言的话，把实现改回"直接钳制"这个回归就抓不住。
      final compute = _braceBlock(serviceSource, 'private fun computeBubblePosition(');
      final computeCode = _stripLiteralsAndComments(compute);

      expect(computeCode, contains('catX.toInt()'),
          reason: '猫在左半屏时，气泡左边缘必须与猫的左边缘对齐');
      expect(computeCode, contains('catRight - bubbleW'),
          reason: '猫在右半屏时，气泡右边缘必须与猫的右边缘对齐');
      expect(computeCode, isNot(contains('centered.coerceIn')),
          reason: '放不下时的兜底不能是"把居中位置直接钳进屏幕" —— '
              '那正是气泡被屏幕边界推离猫、离猫老远的成因');
    });

    test('行为级模拟：气泡放不下时要贴着猫，而不是被屏幕边界推离猫', () {
      // 1080px 宽的屏、3 倍密度 → 猫 246px（82dp）、气泡最多 600px（200dp）
      final sim = _BubbleSim(
        screenWidth: 1080,
        catWidth: 246,
        bubbleWidth: 600,
        density: 3.0,
      );

      // ① 猫在屏幕中间：气泡应当与猫居中对齐
      sim.catWindowX = 400;
      expect(sim.place(), closeTo(400 + 246 / 2 - 600 / 2, 0.001),
          reason: '猫在中间时气泡应当与猫居中对齐');
      expect(sim.overlapsCat(), isTrue, reason: '气泡必须与猫有重叠');

      // ② 猫在右半屏：居中放不下，气泡必须**贴着猫的右边缘**，
      //    而不是被屏幕右边界推走
      sim.catWindowX = 700;
      expect(sim.overlapsCat(), isTrue,
          reason: '气泡必须仍然与猫重叠，不能被屏幕边界推离猫');
      expect(sim.rightEdgeGap(), lessThanOrEqualTo(2.0),
          reason: '放不下时气泡的右边缘应当与猫的右边缘对齐（贴住猫），'
              '而不是留一大段空隙 —— 那正是用户说的"偏离老远"');

      // ③ 猫在左半屏：气泡贴着猫的左边缘
      sim.catWindowX = 100;
      expect(sim.overlapsCat(), isTrue,
          reason: '气泡必须仍然与猫重叠');
      expect(sim.place(), closeTo(100, 0.001),
          reason: '左半屏时气泡左边缘应当与猫左边缘对齐');

      // ④ 猫被探头偏移推到窗口外：气泡必须跟着绘制位置走
      //    （偏移 80px → 气泡必须同样偏移 80px，否则就会离猫老远）
      sim.catWindowX = 400;
      sim.peekOffsetX = 80;
      expect(sim.place(), closeTo(400 + 80 + 246 / 2 - 600 / 2, 0.001),
          reason: '猫的绘制位置整体挪了 80px，气泡必须跟着挪 80px，'
              '否则气泡会离猫老远');
    });
  });

  group('手势轨迹日志：让真机问题一击可定位', () {
    test('必须打出手势轨迹对账日志（手指走了多远 vs 窗口挪了多远）', () {
      expect(serviceSource, contains('private class GestureTrace'),
          reason: '缺少手势轨迹账本');
      expect(serviceSource, contains('private fun logGestureTrace('),
          reason: '缺少轨迹对账日志');
      final trace = _braceBlock(serviceSource, 'private class GestureTrace');
      expect(trace, contains('rawTravel='),
          reason: '必须记录 raw 口径下手指走了多远');
      expect(trace, contains('winTravel='),
          reason: '必须记录窗口**真的**挪了多远');
      expect(trace, contains('localTravel='),
          reason: '必须同时记录局部坐标口径下的手指位移，'
              '两种口径一对比就能判定 rawX 语义');
    });

    test('收手与被中断时都要打出轨迹日志', () {
      final upBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_UP -> {',
        'else -> false',
      );
      expect(upBranch, contains('logGestureTrace('),
          reason: '松手时必须打出轨迹对账');
      final cancelBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_CANCEL -> {',
        'MotionEvent.ACTION_UP -> {',
      );
      expect(cancelBranch, contains('logGestureTrace('),
          reason: '手势被系统中断时同样要打，'
              '那一类"按下去没反应"的问题只能靠它定位');
    });
  });

  group('「拖不动」可定位性：触摸送达心跳 + 用户自助修复', () {
    // 跨了好几轮都在猜"为什么有时候拖不动"，根子在于日志里只有
    // **有反应时**的记录，没有"该有反应却没有"的记录。
    //
    // 「拖不动」至少有两种完全不同的成因，日志长得很像：
    //   ① 触摸**根本没进窗口**（可触达区域陈旧 / 被别的窗口盖住 / 视图不可见）
    //   ② 触摸进来了，但拖拽算法没跟上
    // 没有心跳做基线，就永远分不出是哪一种。

    test('必须有「触摸送达」心跳，给拖不动留下一条可对照的基线', () {
      expect(serviceSource, contains('private val touchHeartbeat'),
          reason: '缺少触摸心跳；没有它就分不清'
              '"触摸没进窗口"和"算法没跟上"');
      final heartbeat = _braceBlock(serviceSource, 'private val touchHeartbeat');
      expect(heartbeat, contains('距上次触摸='),
          reason: '心跳必须报告"上一次收到触摸是什么时候"');
      expect(heartbeat, contains('isAttachedToWindow'),
          reason: '心跳必须报告窗口是否还挂着');
      expect(heartbeat, contains('vis='),
          reason: '心跳必须报告视图可见性（不可见的窗口收不到触摸）');
      expect(serviceSource, contains('mainHandler.postDelayed(touchHeartbeat, 30000)'),
          reason: '心跳必须真的被调度起来，否则等于没有');
      expect(serviceSource, contains('mainHandler.removeCallbacks(touchHeartbeat)'),
          reason: '服务销毁时必须把心跳撤掉，否则会泄漏');
    });

    test('通知栏与快捷菜单的「摸摸」必须兼做热区重建，给用户自助修复入口', () {
      // 「看得见但点不动」在部分国产 ROM 上只有重建窗口才能治好：
      // 可触达区域是 WMS 按 frame 算的，updateViewLayout 只走 relayout，
      // frame 没变就不会重算热区。
      //
      // 而通知栏 / 快捷菜单是**完全不依赖宠物能被按住**的入口 ——
      // 猫按不动的时候，只有它们还能用。
      expect(serviceSource, contains('private fun repairPetWindowForUser()'),
          reason: '缺少用户自助修复入口');
      final repair = _braceBlock(serviceSource, 'private fun repairPetWindowForUser()');
      expect(repair, contains('restorePetWindowForInteraction()'),
          reason: '自助修复必须走那条已验证的"重建窗口"路径');
      expect(repair, contains('if (hasTouchDown) return false'),
          reason: '绝不能在手势进行中重建窗口');

      // 重建必须真的发生（removeView + addView），只 updateViewLayout 不会重算热区
      final restore =
          _braceBlock(serviceSource, 'private fun restorePetWindowForInteraction()');
      expect(restore, contains('reattachPetWindow()'),
          reason: '自助修复必须真的重建窗口（removeView + addView），'
              '只 updateViewLayout 只走 relayout，frame 没变就不会重算可触达区域');
      expect(restore, contains('if (hasTouchDown)'),
          reason: '重建路径本身也必须挡下手势进行中的调用');

      // ⚠️ 必须走**完整恢复**（撑回满尺寸 + 置为可见 + 重建窗口），
      //    不能只调 repairPetWindowForUser（那只是重建窗口）：
      //    窗口卡在「1x1 + INVISIBLE」时，只重建窗口会把那个状态原样保留，
      //    猫还是看不见 —— 这条自救通道就形同虚设了。
      final notif = _braceBlock(serviceSource, 'private fun handleNotificationPet()');
      expect(notif, contains('refreshPetVisibility(forceRebuild = true)'),
          reason: '通知栏的「摸摸」必须做完整恢复：'
              '「看不见」和「看得见但点不动」一起治好');
      final desktop = _braceBlock(serviceSource, 'private fun handleDesktopPet()');
      expect(desktop, contains('refreshPetVisibility(forceRebuild = true)'),
          reason: '快捷菜单的「摸摸」也必须做完整恢复');
    });

    test('拖拽进行中不得旁路复位探头偏移，否则猫会在手指底下跳一下', () {
      // MOVE 分支每帧都会把 peekOffsetX 写成"拖出屏幕的那一段"。
      // 气泡弹出时如果顺手把探头偏移清零，猫就会在用户手指底下突然弹回原位。
      final showBubble = _braceBlock(serviceSource, 'private fun showCustomSpeechBubble(');
      expect(showBubble, contains('!hasTouchDown'),
          reason: '拖拽进行中不得复位探头偏移');
      expect(showBubble, contains('restoreFromPeeking()'),
          reason: '非拖拽状态下仍然要正常复位探头');
    });

    test('拖拽中窗口纹丝不动必须触发自愈（重建窗口）', () {
      // 这是「有时拖不动」唯一可靠的自动修复路径：
      // 手指在动、位置没被钳制、窗口却一帧没动
      // → 说明窗口的布局更新 / 可触达区域已经陈旧
      // → 收手时打上待重挂标记，看门狗在无手势时重建窗口
      final moveBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_MOVE ->',
        'MotionEvent.ACTION_UP',
      );
      expect(_stripLiteralsAndComments(moveBranch), contains('windowStuckWhileMoving = true'),
          reason: '必须识别出"该动却没动"这个特征');
      expect(moveBranch, contains('wantedX == clampedX'),
          reason: '判定必须排除"被屏幕边界钳住"这种正常情况，否则贴边拖会误触发');

      final upBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_UP -> {',
        'else -> false',
      );
      expect(_stripLiteralsAndComments(upBranch), contains('petWindowNeedsReattach = true'),
          reason: '收手时必须打上待重挂标记，让看门狗重建窗口');
    });

    test('App 回到后台必须显式重建悬浮窗，不能靠 wasVisible 猜', () {
      // 用户实测的正是这条路径：
      // 「第一次桌面的宠物是可以拖动的，再打开关闭 app，桌面宠物就不能拖动了」
      //
      // App 在前台时悬浮窗是「藏起来」的 —— 恢复之后能不能被按住，
      // 取决于系统给这个窗口算出来的可触达区域（Touchable Region）
      // 有没有跟着新 frame 重算一遍。
      //
      // 之前这里靠 wasVisible 启发式判断"要不要重建"，
      // 一旦漏判就只做了 updateViewLayout（只走 relayout，frame 没变不重算热区），
      // 于是留下一只"看得见、但按不动"的宠物。
      //
      // 所以：回到后台时必须**显式要求重建**，不猜。
      //
      // ⚠️ 而且必须**去抖**：Activity 的 onPause → onStop → onDestroy
      // 会连着来三次，三次都拆建悬浮窗既让猫连闪三下，
      // 也正好撞上 App 窗口退场的那一刻 —— 那是最不该动窗口的时机。
      final notify = _braceBlock(
        serviceSource,
        'fun notifyAppForegroundChanged(foreground: Boolean)',
      );
      expect(_stripLiteralsAndComments(notify),
          contains('svc.applyForegroundState('),
          reason: 'Activity 的前后台回调必须走统一入口，'
              '不能各写各的（两条链路一旦不一致，前台标记就会悬空）');

      final applyState =
          _braceBlock(serviceSource, 'private fun applyForegroundState(');
      expect(_stripLiteralsAndComments(applyState),
          contains('isAppForeground = foreground'),
          reason: '统一入口必须真的把前台标记写进去 —— '
              '标记悬空 = 桌面宠物永远不再出现');
      expect(_stripLiteralsAndComments(applyState),
          contains('schedulePetVisibilityRefreshAfterBackground()'),
          reason: 'App 回到后台时必须走「延迟合并后的刷新」，不能就地连做三次');
      expect(_stripLiteralsAndComments(applyState),
          contains('refreshPetVisibility(forceRebuild = false)'),
          reason: 'App 进前台时必须立刻把悬浮猫藏起来，否则 App 里会出现两只波可');

      final schedule = _braceBlock(
        serviceSource,
        'fun schedulePetVisibilityRefreshAfterBackground()',
      );
      expect(_stripLiteralsAndComments(schedule), contains('removeCallbacks'),
          reason: '回后台刷新必须去抖：三次回调只有最后一次生效');
      // ⚠️ 必须精确到 backgroundRefreshRunnable 这一个任务：
      //    巡检里也有 refreshPetVisibility(forceRebuild = true)，
      //    只断言"整份源码包含"会漏掉回后台那次被改坏。
      final backgroundRunnable =
          _braceBlock(serviceSource, 'private val backgroundRefreshRunnable = Runnable');
      expect(_stripLiteralsAndComments(backgroundRunnable),
          contains('refreshPetVisibility(forceRebuild = true)'),
          reason: '回后台的那一次刷新必须强制重建悬浮窗');

      final visibility =
          _braceBlock(serviceSource, 'private fun refreshPetVisibility(');
      expect(serviceSource, contains('forceRebuild: Boolean = false'),
          reason: '显隐刷新必须支持"强制重建"这个参数');
      expect(_stripLiteralsAndComments(visibility),
          contains('actuallyShowing && !forceRebuild'),
          reason: '强制重建必须能绕过"一直可见"的判断');
      expect(visibility, contains('restorePetWindowForInteraction()'),
          reason: '重建路径必须真正重建窗口（removeView + addView）');
    });

    test('宠物尺寸变化必须重建窗口，否则热区会停在旧尺寸上', () {
      final apply = _braceBlock(serviceSource, 'private fun applyOverlaySettings(');
      expect(apply, contains('repairPetWindowForUser()'),
          reason: '尺寸变了 = frame 变了 = 可触达区域必须重算；'
              '只 updateViewLayout 在部分 ROM 上不会刷新热区，'
              '会留下一只"只在旧尺寸区域里能按到"的宠物');
      // ⚠️ 尺寸变化必须按 petSizePx 判断：
      //    窗口藏起来时 params.width 是 1x1，拿它比会每次都判成"变了"，
      //    于是每改一次设置就重建一次窗口（还会把猫的位置钳到屏幕最右）。
      expect(_stripLiteralsAndComments(apply), contains('petSizePx != newSize'),
          reason: '尺寸变化必须按宠物真实尺寸 petSizePx 判断');
      expect(_stripLiteralsAndComments(apply),
          isNot(contains(RegExp(r'params\.width\s*!=\s*newSize'))),
          reason: '绝不能用 params.width 判断尺寸变化：隐藏时它是 1x1');
    });

    test('显隐切换日志必须带窗口状态，否则前后台切换时无从判断发生了什么', () {
      // 排查"打开关闭 app 后就拖不动"时，唯一能用的线索就是这条日志。
      // 它必须同时回答四个问题：
      //   切换前可见吗 / View 还挂在窗口上吗 / 我们认为 WMS 里还有它吗 / 它现在在哪
      // 少一个字段，就少一个可对照的判据 —— 这正是前面几轮排查卡住的原因。
      //
      // 注意：这里断言的是**原始文本**（不能用 _stripLiteralsAndComments，
      // 那个 helper 会把字符串字面量也剥掉，恰好把这几个字段一起抹掉）。
      final visibility =
          _braceBlock(serviceSource, 'private fun refreshPetVisibility(');
      expect(visibility,
          contains(r'悬浮猫显隐切换 visible=$visible actuallyShowing=$actuallyShowing'),
          reason: '显隐日志必须记录切换前是否真的露着（区分"刚恢复"与"一直可见"）');
      expect(visibility, contains(r'attached=${view.isAttachedToWindow}'),
          reason: '显隐日志必须记录 View 是否仍挂在窗口上');
      expect(visibility, contains(r'wm=$isPetWindowAttached'),
          reason: '显隐日志必须记录我们是否仍认为窗口挂在 WMS 里');
      expect(visibility, contains(r'win=(${pokoParams?.x},${pokoParams?.y})'),
          reason: '显隐日志必须记录窗口当前坐标');
    });

    test('隐藏悬浮猫不得用 View.GONE，必须让窗口帧真的变一次', () {
      // ⚠️ 这是 v13 的核心改动。
      //
      // View.GONE 会让 ViewRootImpl 销毁窗口的 surface，
      // 部分 ROM 还会顺势把窗口从输入分发器里摘掉；
      // 恢复成 VISIBLE 之后，可触达区域（Touchable Region）
      // 如果没跟着重算，就会留下一只"看得见、按不动"的猫 ——
      // 用户实测的正是这条路径：「第一次能拖，打开关闭 app 之后就拖不动」。
      //
      // 所以改成：隐藏时把窗口缩到 1x1 + 透明 + INVISIBLE，
      // 恢复时撑回满尺寸 —— **窗口帧真的变了**，WMS 必须重算热区。
      final visibility =
          _braceBlock(serviceSource, 'private fun refreshPetVisibility(');
      // ⚠️ 只禁宠物本体：气泡 / 快捷菜单是**另外的窗口**，
      //    它们用 View.GONE 收起来没有任何问题（见 bubbleView?.visibility）。
      expect(_stripLiteralsAndComments(visibility),
          isNot(contains(RegExp(r'view\.visibility\s*=\s*View\.GONE'))),
          reason: '悬浮猫本体绝不能用 View.GONE 隐藏：'
              'GONE 会销毁 surface / 可能摘掉输入通道，'
              '恢复时可触达区域容易停留在旧值上');
      expect(visibility, contains('View.INVISIBLE'),
          reason: '隐藏要用 INVISIBLE：窗口始终挂在 WindowManager 上，'
              '不会出现"View 还在、窗口却脱挂"的状态');
      expect(visibility, contains('applyPetWindowFrame(hidden = false)'),
          reason: '恢复时必须把窗口尺寸撑回去 —— 帧变化才会触发热区重算');
      expect(visibility, contains('applyPetWindowFrame(hidden = true)'),
          reason: '隐藏时必须把窗口缩到 1x1');

      final frame = _braceBlock(serviceSource, 'private fun applyPetWindowFrame(');
      expect(_stripLiteralsAndComments(frame), contains('params.width = size'),
          reason: '改尺寸必须真的改到 LayoutParams 上，否则 WMS 看不到帧变化');
      expect(_stripLiteralsAndComments(frame), contains('updateViewLayout'),
          reason: '尺寸变更必须提交给 WindowManager，否则帧不会变');
      expect(serviceSource, contains('const val HIDDEN_WINDOW_SIZE_PX = 1'),
          reason: '隐藏尺寸必须是 1x1：既不画东西，也不留可触达区域');
    });

    test('恢复时必须先撑回尺寸、再置为可见（热区要在"可见+满尺寸"下算）', () {
      final visibility =
          _braceBlock(serviceSource, 'private fun refreshPetVisibility(');
      final resizeAt = visibility.indexOf('applyPetWindowFrame(hidden = false)');
      final visibleAt = visibility.indexOf('view.visibility = View.VISIBLE');
      expect(resizeAt, greaterThan(-1), reason: '恢复路径必须把窗口尺寸撑回去');
      expect(visibleAt, greaterThan(-1), reason: '恢复路径必须把视图置为 VISIBLE');
      expect(resizeAt, lessThan(visibleAt),
          reason: '顺序：先把尺寸撑回满尺寸（帧变化），再置为可见 —— '
              '这样可触达区域一定是在"可见 + 满尺寸"的状态下算出来的，'
              '反过来的话中间会经过一个"可见但只有 1 像素"的窗口');
    });

    test('坐标钳制必须用宠物真实尺寸，不能用窗口当前尺寸', () {
      // 窗口藏起来时 width 是 1x1 —— 拿它当宠物尺寸会把位置钳到屏幕最右边，
      // 猫就再也拖不回来了。
      final clamp =
          _braceBlock(serviceSource, 'private fun clampPetPositionToScreen(');
      expect(_stripLiteralsAndComments(clamp), contains('petSizePx'),
          reason: '钳制必须基于宠物真实尺寸 petSizePx');
      expect(_stripLiteralsAndComments(clamp),
          isNot(contains('params.width > 0')),
          reason: '绝不能用 params.width 当宠物尺寸：隐藏时它是 1x1');
    });

    test('必须有一份触摸诊断快照，能直接回答"触摸到底进没进窗口"', () {
      // 前几轮排查反复卡住，根因是**日志只记录"有反应的时候"**：
      // 触摸压根没进窗口时日志上就是一片空白，谁也分不清故障类型。
      //
      // 这份快照要能一眼区分：
      //   DOWN=0        → 触摸没进窗口（热区 / 层级 / 被别的窗口挡住）
      //   DOWN>0 MOVE=0 → 进了窗口但手势被吃掉
      //   MOVE>0        → 触摸链路正常，问题在窗口位移上
      final diag =
          _braceBlock(serviceSource, 'private fun buildTouchDiagnostic()');
      expect(diag, contains(r'DOWN=$touchDownCount'),
          reason: '诊断必须带上按下次数');
      expect(diag, contains(r'MOVE=$touchMoveCount'),
          reason: '诊断必须带上移动次数');
      expect(diag, contains(r'attached=${view?.isAttachedToWindow}'),
          reason: '诊断必须带上窗口挂载状态');
      expect(diag, contains(r'wm=$isPetWindowAttached'),
          reason: '诊断必须带上我们认为的窗口挂载状态');
      expect(diag, contains(r'隐藏=$petWindowHidden'),
          reason: '诊断必须带上隐藏状态');
      // 计数器必须真的在触摸链路里累加，否则诊断永远是 0
      expect(serviceSource, contains('touchDownCount++'),
          reason: '按下时必须累加计数');
      expect(serviceSource, contains('touchMoveCount++'),
          reason: '移动时必须累加计数');
    });

    test('通知栏必须同时是诊断面板，并提供一键复制', () {
      // 用户不该为了反馈问题就去连电脑抓 logcat ——
      // 常驻通知是唯一"随时能看见、又不依赖宠物可触摸"的界面。
      final build =
          _braceBlock(serviceSource, 'private fun buildServiceNotification()');
      expect(build, contains('buildTouchDiagnostic()'),
          reason: '通知展开后必须能看到完整诊断');
      expect(build, contains('buildCompactDiagnosticLine()'),
          reason: '通知折叠状态也必须能看到紧凑诊断');
      expect(build, contains('ACTION_NOTIFICATION_DIAGNOSTIC'),
          reason: '通知必须提供「📋 诊断」按钮');
      expect(serviceSource, contains('setPrimaryClip'),
          reason: '诊断必须能一键复制到剪贴板 —— 用户粘给我们就行');
      expect(serviceSource, contains('refreshNotificationDiagnostic()'),
          reason: '诊断必须随心跳保持新鲜');
    });

    test('收进通知栏也必须用同一套隐藏机制，不能用 View.GONE', () {
      // 「收回 → 召回」这条路径同样会遇到热区陈旧，
      // 必须和前后台切换共用同一套（缩到 1x1 + INVISIBLE），
      // 否则用户"收一次再召回来"就再也拖不动了。
      final tray = _braceBlock(serviceSource, 'private fun hidePetToTray(');
      expect(_stripLiteralsAndComments(tray),
          isNot(contains(RegExp(r'view\.visibility\s*=\s*View\.GONE'))),
          reason: '收回时不能用 View.GONE：'
              'GONE 会销毁 surface / 可能摘掉输入通道，'
              '召回时可触达区域会停留在旧值上');
      expect(tray, contains('applyPetWindowFrame(hidden = true)'),
          reason: '收进通知栏时也必须让窗口帧变一次');
      expect(tray, contains('petWindowHidden = true'),
          reason: '必须同步维护隐藏标记，否则召回时走错分支');
    });

    test('【行为模拟】帧不变热区就陈旧；让帧变一次才能治好"看得见却按不动"', () {
      const petSize = 200;

      // —— 旧做法：隐藏/恢复只切可见性，窗口帧一动不动 ——
      final legacy = _OverlayFrameSim(petSize);
      legacy.applyFrame(petSize, visible: true);
      legacy.fingerDown();
      expect(legacy.touchDownCount, 1, reason: '初始状态必须能接到触摸');

      legacy.hideWithGoneToggle();
      legacy.showWithGoneToggle();
      legacy.fingerDown();
      expect(legacy.touchDownCount, 1,
          reason: '帧没变 → WMS 不重算可触达区域 → 触摸进不来，'
              '这正是"看得见却按不动"的用户症状');

      // —— 新做法：隐藏时缩到 1x1，恢复时撑回满尺寸 → 帧变了一次 ——
      final fixed = _OverlayFrameSim(petSize);
      fixed.applyFrame(petSize, visible: true);
      fixed.hideWithFrameChange();
      fixed.showWithFrameChange();
      fixed.fingerDown();
      expect(fixed.touchDownCount, 1,
          reason: '帧变化会让 WMS 重算可触达区域，触摸重新送达');
      expect(fixed.touchableRegion, petSize,
          reason: '恢复后热区必须重新覆盖整个宠物');
    });
  });

    test('拉起主 App 不得留下悬空的前台标记（悬空 = 悬浮猫永久不可触摸）', () {
      expect(serviceSource, contains('var isMainActivityResumed: Boolean'),
          reason: '缺少「主 Activity 是否真的在前台」这一交叉校验用的真值；'
              'isAppForeground 会被 openMainActivity 提前手工置 true，'
              '一旦拉起失败就没人复位，宠物永久停在 View.GONE（GONE 不参与触摸分发）');

      final notify = _braceBlock(serviceSource, 'fun notifyAppForegroundChanged');
      expect(notify, contains('isMainActivityResumed = foreground'),
          reason: 'Activity 前后台切换时必须同步维护真实前台状态');

      final openMain = _braceBlock(serviceSource, 'private fun openMainActivity()');
      expect(openMain, contains('foregroundWatchdog'),
          reason: '拉起主 App 时手工置位的前台标记必须配一个看门狗来回收');
      expect(openMain, contains('!isMainActivityResumed'),
          reason: '看门狗必须以「Activity 从未真正 resume」作为悬空判据');
      expect(openMain, contains('FOREGROUND_WATCHDOG_DELAY_MS'),
          reason: '看门狗必须有明确的超时时长');
    });

    test('主 Activity 销毁时必须复位前台标记', () {
      expect(activitySource, contains('override fun onDestroy()'),
          reason: '缺少 onDestroy 兜底');
      final destroy = _braceBlock(activitySource, 'override fun onDestroy()');
      expect(destroy, contains('notifyAppForegroundChanged(false)'),
          reason: 'Activity 真正销毁时必须复位前台标记，'
              '否则悬浮猫会停在不可见 / 不可触摸状态');
    });

    test('服务启动必须交叉校验前后台标记，防止标记失同步', () {
      final startCommand = _braceBlock(serviceSource, 'override fun onStartCommand');
      expect(startCommand, contains('isAppForeground != isMainActivityResumed'),
          reason: '服务被系统重建（START_STICKY）或被 App 重新拉起后，'
              '前后台标记可能失同步，必须交叉校验并纠正');
      expect(startCommand, contains('refreshPetVisibility()'),
          reason: '纠正标记后必须立刻刷新悬浮猫显隐');
    });

    test('双指手势不得在第二根手指落下时立刻接管拖拽', () {
      final pointerDown = _between(
        serviceSource,
        'MotionEvent.ACTION_POINTER_DOWN ->',
        'MotionEvent.ACTION_POINTER_UP',
      );
      // 断言只看真实代码：注释里为了说明历史问题会提到旧的写法
      expect(_stripLiteralsAndComments(pointerDown), isNot(contains('isPinching = true')),
          reason: '第二根手指一落下就切捏合模式，会把用户「想用力拖一把」或手掌误触的'
              '拖拽整段吞掉，宠物纹丝不动 —— 这是「有时能拖、有时拖不动」的主要来源之一');
      expect(pointerDown, contains('pinchStartDistance = pointerDistance(event)'),
          reason: '第二根手指落下时必须先记录两指距离基线');

      final moveBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_MOVE ->',
        'MotionEvent.ACTION_UP',
      );
      expect(moveBranch, contains('pinchTriggerDistance'),
          reason: '必须以两指距离变化阈值作为捏合判据');
      expect(moveBranch, contains('abs(dist - pinchStartDistance) > pinchTriggerDistance'),
          reason: '捏合判定必须比较「当前两指距离」与「基线距离」的差值');
    });

    test('快捷菜单不得压在宠物窗口上，否则会抢走宠物的触摸', () {
      final showMenu = _braceBlock(serviceSource, 'private fun showActionMenu()');
      final showMenuCode = _stripLiteralsAndComments(showMenu);
      expect(showMenuCode, isNot(contains('coerceAtMost(screenWidth - menuW')),
          reason: '用 coerceAtMost 把菜单夹回屏幕内的同时会把它拉回宠物身上；'
              '菜单窗口 z 序更高，会吃掉重叠区域的点击，'
              '表现为「明明按在猫身上，猫却一动不动」');
      expect(showMenuCode, isNot(contains('coerceAtLeast((4 * density)')),
          reason: '同上：把菜单夹回屏幕内会与宠物窗口重叠');
      expect(showMenu, contains('rightFits'),
          reason: '必须先判断菜单放右侧是否放得下，放不下就换边');
      expect(showMenu, contains('leftFits'),
          reason: '必须判断菜单放左侧是否放得下');
      expect(showMenu, contains('aboveY'),
          reason: '两侧都放不下时必须改放宠物上方 / 下方，绝不能压在宠物身上');
    });

    test('探头复位动画必须纳入统一托管，不能用不受控的匿名动画器写 peekOffsetX', () {
      final restore = _braceBlock(serviceSource, 'private fun restoreFromPeeking');
      expect(restore, contains('peekOffsetAnimator = ValueAnimator.ofFloat'),
          reason: '复位动画必须持有引用才能被取消；匿名动画器会在拖拽期间继续改写 '
              'peekOffsetX，与探头动画、溢出回收动画抢同一个属性，'
              '让「看到的猫」和「能按到的窗口区域」错位，表现为间歇性拖不动');
      expect(restore, contains('peekOffsetAnimator?.start()'),
          reason: '托管之后必须启动同一个被持有的动画器');
      expect(_stripLiteralsAndComments(restore), isNot(contains('}.start()')),
          reason: '仍然存在裸的匿名 ValueAnimator 启动调用，该动画不受控、无法取消');
    });

    test('触摸日志必须打印窗口挂载状态与屏幕尺寸', () {
      final downBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_DOWN ->',
        'MotionEvent.ACTION_POINTER_DOWN',
      );
      expect(downBranch, contains('isAttachedToWindow'),
          reason: '按下日志必须带出窗口挂载状态：一旦再出现「按不动」，'
              '一条 logcat 就能直接定位，不用再靠猜');
      expect(downBranch, contains('vis='),
          reason: '按下日志必须带出视图可见性');
      expect(downBranch, contains('screen='),
          reason: '按下日志必须带出屏幕尺寸，便于核对坐标钳制范围');
    });

    test('主 Activity 停止 (onStop) 时必须兜底复位前台标记', () {
      expect(activitySource, contains('override fun onStop()'),
          reason: '缺少 onStop 兜底；全面屏手势退出或直接杀死时可能不走 onDestroy 但走 onStop');
      final stop = _braceBlock(activitySource, 'override fun onStop()');
      expect(stop, contains('notifyAppForegroundChanged(false)'),
          reason: 'Activity 停止时必须复位前台标记');
    });

    test('悬浮窗从隐藏恢复后必须重建窗口，保证触控热区被重新计算', () {
      // 用户反馈原文：
      // 「关闭 app，再打开这个桌面悬浮宠物，在拖动好多时候都拖不动」
      //
      // 关键事实：View.GONE 的视图不参与触摸分发。
      // 恢复成 VISIBLE 之后能不能被按住，取决于系统给这个窗口算出来的
      // **可触达区域（Touchable Region）**是否已经刷新。
      //
      // 只 updateViewLayout 走的是 relayout：窗口 frame 没变，
      // WMS 就没有理由重算热区，部分 ROM（尤其国产 ROM）会保留旧热区 ——
      // 结果就是"看得见、点不动"。上一版（drag-fix-v5）就栽在这里。
      //
      // 真正可靠的做法是**重建窗口**（removeView + addView）：
      // WMS 会建一个全新的 WindowState，热区从头算一遍。
      final restore = _braceBlock(serviceSource, 'private fun restorePetWindowForInteraction()');

      expect(restore, contains('reattachPetWindow()'),
          reason: '从隐藏恢复时必须重建悬浮窗（removeView + addView），'
              '让 WMS 重新计算可触达区域；只 updateViewLayout 不会重算热区');
      expect(restore, contains('clampPetPositionToScreen'),
          reason: '重建前必须把窗口坐标钳回屏幕范围内：'
              '屏幕外的窗口看得见也摸不到（热区同样在屏幕外）');
      expect(restore, contains('setAnimationEnabled(true)'),
          reason: '重建会让 View 走一遍 detach/attach，onDetachedFromWindow 会停掉动画器，'
              '必须重新启动，否则猫会僵在桌面上不动');
      expect(restore, contains('Log.e'),
          reason: '重建失败必须写日志，不允许静默吞掉 —— '
              '否则线上出现"按不动"时完全无从定位');
    });

    test('恢复可见时必须区分「刚恢复」与「一直可见」，只在刚恢复时重建窗口', () {
      final refreshVis = _braceBlock(serviceSource, 'private fun refreshPetVisibility(');

      // ⚠️ "之前是不是真的露着"必须看**实际状态**（视图可见性 + 窗口尺寸），
      //    不能看某个标记 —— 标记会失配，实际状态不会骗人。
      expect(refreshVis, contains('val actuallyShowing = view.visibility == View.VISIBLE'),
          reason: '必须先记录"之前是不是真的露着"，才能区分「刚恢复」和「一直可见」；'
              '看实际状态而不是看标记，标记失配会让宠物永远不再出现');
      expect(refreshVis, contains('pokoParams?.width == petSizePx'),
          reason: '实际状态还要看窗口尺寸：尺寸停在 1x1 的宠物同样是"没露着"');
      expect(refreshVis, contains('restorePetWindowForInteraction()'),
          reason: '刚从隐藏恢复的那一次必须走重建窗口的路径');
      expect(refreshVis, contains('ensurePetWindowAttached()'),
          reason: '一直可见的路径仍要体检窗口是否还挂在 WindowManager 上');
    });

    test('显隐必须是幂等赋值，不能靠"状态翻转"才动窗口', () {
      // ⚠️⚠️ v13 的回归就出在这里：
      // 当时显隐是"只有 visible 与 wasVisible 不同才动窗口"，
      // 只要有一次判断失配（标记说该露着、窗口其实还是 1x1 + INVISIBLE），
      // 宠物就永远不再出现，而且没有任何机制会纠正它 ——
      // 用户实测原文：「打开 app，再关闭，桌面悬浮宠物就不显示了」。
      //
      // 现在必须是**每次都把窗口摆成应该的样子**（幂等）：
      // 这样任何一次意外都会在下一次调用（或巡检）时自动纠正。
      final visibility =
          _braceBlock(serviceSource, 'private fun refreshPetVisibility(');
      final hiddenBlock = visibility.indexOf('applyPetWindowFrame(hidden = true)');
      final shownBlock = visibility.indexOf('applyPetWindowFrame(hidden = false)');
      expect(hiddenBlock, greaterThan(-1), reason: '必须有一条"藏起来"的分支');
      expect(shownBlock, greaterThan(-1), reason: '必须有一条"露出来"的分支');

      // 两条分支都必须**无条件执行**，不能被"是否发生翻转"包着
      final flipGuard = RegExp(r'if\s*\(\s*wasVisible\s*!=\s*visible\s*\)');
      expect(flipGuard.hasMatch(visibility), isFalse,
          reason: '显隐绝不能再被"状态翻转"包着 —— '
              '一次失配就会让宠物永久消失（v13 回归）');

      // 两条分支都必须真的把状态摆对
      expect(visibility, contains('view.visibility = View.VISIBLE'),
          reason: '"露出来"这条分支必须真的把视图置为 VISIBLE');
      expect(visibility, contains('view.visibility = View.INVISIBLE'),
          reason: '"藏起来"这条分支必须真的把视图置为 INVISIBLE');
      expect(visibility, contains('view.alpha = currentPetAlpha()'),
          reason: '恢复时必须把透明度摆回正常值');

      // 也不允许用 alpha=0 来隐藏：透明度是第三份需要同步的状态
      expect(_stripLiteralsAndComments(visibility),
          isNot(contains(RegExp(r'view\.alpha\s*=\s*0f'))),
          reason: '隐藏用 INVISIBLE + 1x1 就够了；'
              '再加一份 alpha 状态就多一处可能失配的地方');
    });

    test('前台状态必须有第二条独立信号源：服务自己监听 Activity 生命周期', () {
      // 前台标记一旦悬空（说"在前台"、其实已经退到后台），
      // 桌面宠物就会**永远不再出现** —— 用户实测过「打开 app 再关闭，宠物就不显示了」。
      //
      // 只靠 MainActivity 自己的 onResume/onPause 是**单点故障**：
      // 那条链路一旦失灵，就再也没有人能纠正状态。
      // 所以服务必须自己监听框架派发的生命周期回调，做第二信号源。
      expect(serviceSource, contains('Application.ActivityLifecycleCallbacks'),
          reason: '服务必须自己监听 Activity 生命周期');
      expect(serviceSource, contains('registerActivityLifecycleCallbacks('),
          reason: '生命周期监听必须真的注册上');
      expect(serviceSource, contains('unregisterActivityLifecycleCallbacks('),
          reason: '服务销毁时必须注销，否则会泄漏');

      final callbacks = _braceBlock(
        serviceSource,
        'private val activityLifecycleCallbacks = object',
      );
      // ⚠️ 必须**逐个回调**断言，不能只断言"整体包含"：
      //    onActivityPaused 与 onActivityDestroyed 都写 applyForegroundState(false)，
      //    整体断言会漏掉其中一个被改坏。
      final onResumed = _braceBlock(callbacks, 'override fun onActivityResumed(');
      final onPaused = _braceBlock(callbacks, 'override fun onActivityPaused(');
      final onDestroyed =
          _braceBlock(callbacks, 'override fun onActivityDestroyed(');
      expect(_stripLiteralsAndComments(onResumed),
          contains('applyForegroundState(true)'),
          reason: 'Activity 恢复时必须把前台状态纠正回来');
      expect(_stripLiteralsAndComments(onPaused),
          contains('applyForegroundState(false)'),
          reason: 'Activity 暂停时必须把前台状态纠正回来');
      expect(_stripLiteralsAndComments(onDestroyed),
          contains('applyForegroundState(false)'),
          reason: 'Activity 销毁时前台标记绝不能留在 true（否则宠物永远不出现）');
    });

    test('必须有窗口状态巡检兜底，保证宠物不会永久消失', () {
      // 幂等赋值是主防线，巡检是最后一道保险：
      // 只要"该露着"却没真正露着，2 秒内就修回来。
      final watchdog =
          _braceBlock(serviceSource, 'private val windowStateWatchdog = object');
      expect(watchdog, contains('refreshPetVisibility(forceRebuild = true)'),
          reason: '巡检发现状态不对时必须强制恢复');
      expect(watchdog, contains('view.visibility != View.VISIBLE'),
          reason: '巡检必须检查视图可见性');
      expect(watchdog, contains('params.width != petSizePx'),
          reason: '巡检必须检查窗口尺寸是否停在 1x1');
      expect(serviceSource, contains('mainHandler.postDelayed(windowStateWatchdog, 2000)'),
          reason: '巡检必须真的被启动起来（onCreate）');
      expect(serviceSource, contains('mainHandler.removeCallbacks(windowStateWatchdog)'),
          reason: '服务销毁时必须撤掉巡检，否则会空跑');
    });

    test('重建窗口前必须确认旧窗口摘干净，否则会永久脱挂', () {
      // removeView 抛的异常被静默吞掉之后，视图可能还挂着；
      // 这时 addView 会抛 "View already added" ——
      // 「摘 + 挂」变成「只摘不挂」，窗口就此永久脱挂，
      // 用户看到的正是「桌面宠物不显示了」，而且它自己永远回不来。
      final reattach = _braceBlock(serviceSource, 'private fun reattachPetWindow(');
      expect(_stripLiteralsAndComments(reattach), contains('removeViewImmediate'),
          reason: '摘不掉就必须强制摘一次（removeViewImmediate），否则 addView 必然抛异常');
      expect(_stripLiteralsAndComments(reattach), contains('view.isAttachedToWindow'),
          reason: 'addView 之前必须先确认视图确实已经摘干净');
    });

    test('悬浮窗坐标必须能被钳回当前屏幕范围', () {
      expect(serviceSource, contains('private fun clampPetPositionToScreen'),
          reason: '缺少屏幕范围钳制；旋转 / 分屏 / 存档坐标失效后，'
              '窗口会停在屏幕外，可触达区域也在屏幕外，用户看得见却拖不动');
      final clamp = _braceBlock(serviceSource, 'private fun clampPetPositionToScreen');
      expect(clamp, contains('getScreenDimensions()'),
          reason: '钳制必须基于当前屏幕尺寸，而不是缓存的旧值');
      expect(clamp, contains('getSafeVerticalBounds'),
          reason: '纵向钳制必须避开状态栏与手势条');
    });

    test('服务 onCreate 必须先挂载窗口再刷新可见性，防止后台启动重复 addView 崩溃', () {
      final onCreateBlock = _braceBlock(serviceSource, 'override fun onCreate()');
      final addViewIdx = onCreateBlock.indexOf('addView(pokoView');
      final refreshIdx = onCreateBlock.indexOf('refreshPetVisibility()');
      expect(addViewIdx, isNonNegative, reason: 'onCreate 必须执行 addView');
      expect(refreshIdx, isNonNegative, reason: 'onCreate 必须执行 refreshPetVisibility');
      expect(addViewIdx, lessThan(refreshIdx),
          reason: 'addView 必须在 refreshPetVisibility 之前，否则 refreshPetVisibility 会提前触发 reattachPetWindow 导致后续 addView 抛 IllegalStateException 并 stopSelf() 自杀');
    });

    test('onStartCommand 在 App 侧重新启动时自动重置 isPetRecalled 标记', () {
      final startCommand = _braceBlock(serviceSource, 'override fun onStartCommand');
      expect(startCommand, contains('isPetRecalled'),
          reason: 'onStartCommand 必须检查并重置 isPetRecalled');
      expect(startCommand, contains('isPetRecalled = false'),
          reason: '重新启动悬浮窗时必须解除召回隐匿状态');
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
      expect(moveBranch, contains('params.x = clampedX'),
          reason: '窗口坐标必须始终被钳制在屏幕内，否则会重现拖不动的老问题');
      expect(moveBranch, contains('val clampedX = wantedX.coerceIn(0, maxX)'),
          reason: '钳制必须显式落在 wantedX 上');
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
        widgetProviderSource,
      ]);

      final problems = <String>[];
      for (final source in <String>[
        serviceSource,
        activitySource,
        petViewSource,
        overlayChannelKotlin,
        widgetProviderSource,
      ]) {
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

  group('Kotlin JVM 签名冲突：同类成员的隐式访问器不得与函数撞车', () {
    test('每个 Kotlin 文件里都不能出现同类成员的 JVM 签名冲突', () {
      // 背景：CI 报过
      //   Platform declaration clash: ... (setNightMode(Z)V)
      // 原因：public 属性 `isNightMode` 的隐式 setter 的 JVM 签名就是
      // setNightMode(Z)V（Kotlin 会剥掉 is 前缀），和手写的
      // `fun setNightMode(enabled: Boolean)` 完全撞车。
      //
      // 这类错误属于编译器 backend 阶段的问题 —— 本机缺 android.jar 时
      // frontend 阶段就已经报了一千多条 unresolved，根本走不到 backend，
      // 所以本地 kotlinc 永远看不到它，只能靠 CI 炸出来。
      //
      // 规则（与 Kotlin/JVM 编译器 backend 对齐）：
      //   - public var isFoo -> 隐式 setter 叫 setFoo
      //   - public var foo   -> 隐式 setter 叫 setFoo
      //   - public val foo   -> 隐式 getter 叫 getFoo
      //   - private 成员与 public 成员同名【不会】冲突（Kotlin 只在同可见性时报）
      //   - 只在同一个类内部比较（嵌套类、companion object 各自成域）
      final problems = <String>[];
      for (final source in <String>[
        serviceSource,
        activitySource,
        petViewSource,
        overlayChannelKotlin,
        widgetProviderSource,
      ]) {
        problems.addAll(_findJvmSignatureClashes(source));
      }

      expect(
        problems,
        isEmpty,
        reason: '发现 JVM 签名冲突（会直接导致 CI 编译失败）：\n'
            '${problems.join('\n')}',
      );
    });

    test('冲突检测器本身必须有效：能识别人造冲突样本', () {
      const clash = '''
class Clashy {
    var isNightMode: Boolean = false
    fun setNightMode(enabled: Boolean) {
        isNightMode = enabled
    }
}
''';
      expect(
        _findJvmSignatureClashes(clash).any((p) => p.contains('setNightMode')),
        isTrue,
        reason: '检测器应报出 public var isNightMode 与 fun setNightMode 的冲突',
      );

      // getter 撞 getter 同样会炸
      const getterClash = '''
class ClashyGetter {
    val petName: String = "x"
    fun getPetName(): String = petName
}
''';
      expect(
        _findJvmSignatureClashes(getterClash).any((p) => p.contains('getPetName')),
        isTrue,
        reason: '检测器应报出 public val petName 的隐式 getter 与 fun getPetName 的冲突',
      );
    });

    test('冲突检测器不得误报：private / 类型不同 / 跨类 都不算冲突', () {
      const safe = '''
class Safe1 {
    var isNightMode: Boolean = false
    private fun setNightMode(enabled: Boolean) {
        isNightMode = enabled
    }
}
class Safe2 {
    private var isAnimationEnabled: Boolean = true
    fun setAnimationEnabled(enabled: Boolean) {
        isAnimationEnabled = enabled
    }
}
class Safe3 {
    var nightMode: Boolean = false
    fun setNightMode(label: String) {
    }
}
class Safe4 {
    var currentAction: Int = 0
    inner class Inner {
        fun setCurrentAction(action: Int) {
        }
    }
}
class Safe5 {
    var isNightMode: Boolean = false
}
class Safe6 {
    fun setNightMode(enabled: Boolean) {
    }
}
''';
      expect(
        _findJvmSignatureClashes(safe),
        isEmpty,
        reason: 'private 成员、参数类型不同、跨类同名 都不构成 Platform declaration clash，'
            '检测器不应误报',
      );
    });

    test('检测器覆盖率自检：必须真的扫到了真实的类与成员', () {
      // 目的：防止检测器因为正则失效而"扫不出任何东西 -> 报 0 问题 -> 假通过"。
      // 一旦覆盖率掉下来，这条用例会红。
      final classes = <String, _KotlinClassInfo>{};
      var totalProps = 0;
      var totalFuns = 0;
      for (final source in <String>[
        serviceSource,
        activitySource,
        petViewSource,
        overlayChannelKotlin,
        widgetProviderSource,
      ]) {
        for (final c in _scanKotlinClasses(source)) {
          classes[c.name] = c;
          totalProps += c.props.length;
          totalFuns += c.funs.length;
        }
      }

      expect(classes.keys, contains('PokoPetView'),
          reason: '应扫到 PokoPetView');
      expect(classes.keys, contains('FloatingPetService'),
          reason: '应扫到 FloatingPetService');
      expect(classes.keys, contains('OverlayChannel'),
          reason: '应扫到 OverlayChannel');
      expect(classes.keys, contains('MainActivity'),
          reason: '应扫到 MainActivity');
      expect(classes.keys, contains('FloatingPetService.Companion'),
          reason: '应扫到 companion object —— 它的成员同样是 JVM 成员，必须参与冲突检查');

      final view = classes['PokoPetView']!;
      expect(view.props.map((p) => p.name), contains('isNightMode'),
          reason: 'PokoPetView 的 isNightMode 属性必须被扫到');
      expect(view.props.map((p) => p.name), contains('skinId'));
      expect(view.funs.map((f) => f.name), contains('setAnimationEnabled'));
      expect(view.funs.map((f) => f.name), contains('applyConfig'));

      final service = classes['FloatingPetService']!;
      expect(service.props.map((p) => p.name), contains('petSizeDp'));
      expect(service.funs.map((f) => f.name), contains('applyNightModeFromApp'));

      final companion = classes['FloatingPetService.Companion']!;
      expect(companion.funs.map((f) => f.name), contains('readSettings'),
          reason: 'companion 里的函数必须被扫到');
      expect(companion.props.map((p) => p.name), contains('isAppForeground'));

      expect(totalProps, greaterThan(200),
          reason: '属性扫描量明显偏低（当前 $totalProps），检测器可能已经失效');
      expect(totalFuns, greaterThan(80),
          reason: '函数扫描量明显偏低（当前 $totalFuns），检测器可能已经失效');
    });
  });

  group('触觉反馈：震动必须按语义区分，且波形长度必须自洽', () {
    test('每个震动模式的 timings 与 amplitudes 长度必须相等', () {
      // ⚠️ VibrationEffect.createWaveform(timings, amplitudes, repeat) 在
      // amplitudes 长度与 timings 不一致时抛 IllegalArgumentException —— 直接崩。
      // 这类手滑只有机器能查，守护测试就是那个机器。
      final patternRe = RegExp(
        r'val (HAPTIC_\w+)\s*=\s*HapticPattern\(\s*longArrayOf\(([^)]*)\)\s*,\s*intArrayOf\(([^)]*)\)\s*\)',
      );
      final matches = patternRe.allMatches(serviceSource).toList();

      expect(matches.length, greaterThanOrEqualTo(8),
          reason: '应至少解析出 8 个震动模式，实际 ${matches.length} 个 —— '
              '检测器可能已经失效');

      for (final m in matches) {
        final name = m.group(1)!;
        final timings = m.group(2)!
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .length;
        final amplitudes = m.group(3)!
            .split(',')
            .where((s) => s.trim().isNotEmpty)
            .length;
        expect(amplitudes, timings,
            reason: '$name 的 amplitudes 长度($amplitudes) 与 timings 长度($timings) '
                '不一致 —— 运行时 VibrationEffect.createWaveform 会抛异常闪退');
      }
    });

    test('不得再出现裸的 vibrate(30) 这类无语义的震动调用', () {
      // 此前所有触摸反馈都是同一个 vibrate(30)，摸头和被踩尾巴手感完全一样。
      // 现在全部走语义表（HAPTIC_*），所以代码里不该再有裸 vibrate(...) 调用。
      // 先剥掉注释 —— 文档里提到旧写法是正常的。
      final code = _stripLiteralsAndComments(serviceSource);
      final bareVibrates = RegExp(r'(?<![\w.])vibrate\(\s*\d')
          .allMatches(code)
          .map((m) => m.group(0))
          .toList();
      expect(bareVibrates, isEmpty,
          reason: '发现无语义的裸震动调用：${bareVibrates.join(", ")}');
    });

    test('四个触摸分区必须有各自不同的震动模式', () {
      for (final pattern in const <String>[
        'HAPTIC_PET_HEAD',
        'HAPTIC_PET_BODY',
        'HAPTIC_PET_TAIL',
        'HAPTIC_PET_PAW',
      ]) {
        expect(serviceSource, contains(pattern),
            reason: '缺少 $pattern —— 分区触觉必须互不相同');
      }
    });
  });

  group('状态可见化：徽标阈值与状态播报必须用同一组常量', () {
    test('桌面猫必须有状态徽标（饿了/脏了/困了一眼可见）', () {
      expect(petViewSource, contains('refreshStateBadge'),
          reason: 'PokoPetView 必须提供状态徽标刷新入口');
      expect(petViewSource, contains('drawStatusBadge'),
          reason: 'PokoPetView 必须绘制状态徽标');
      for (final threshold in const <String>[
        'BADGE_THRESHOLD_HUNGER',
        'BADGE_THRESHOLD_MOOD',
        'BADGE_THRESHOLD_ENERGY',
        'BADGE_THRESHOLD_CLEAN',
      ]) {
        expect(petViewSource, contains(threshold),
            reason: 'PokoPetView 缺少状态阈值 $threshold');
      }
    });

    test('状态播报必须复用徽标的同一组阈值常量，不得硬编码数字', () {
      // 徽标用 PokoPetView.BADGE_THRESHOLD_*，播报也必须用同一组，
      // 否则会出现"徽标亮了但没播报"或"播报了但没徽标"的割裂感。
      expect(serviceSource, contains('PokoPetView.BADGE_THRESHOLD_HUNGER'));
      expect(serviceSource, contains('PokoPetView.BADGE_THRESHOLD_CLEAN'));
      expect(serviceSource, contains('PokoPetView.BADGE_THRESHOLD_ENERGY'));
      expect(serviceSource, contains('PokoPetView.BADGE_THRESHOLD_MOOD'));
      expect(serviceSource, contains('maybeBroadcastStateChange'),
          reason: '服务层必须在状态跌破阈值时主动播报');
    });

    test('状态播报必须有节流，不能每次同步都弹气泡', () {
      expect(serviceSource, contains('STATE_BROADCAST_COOLDOWN_MS'),
          reason: '状态播报必须节流，否则 App 里每点一下就弹一次气泡');
      expect(serviceSource, contains('lastStateBroadcastAt'));
    });
  });

  group('桌面小组件：只读状态 + 一键唤出悬浮猫', () {
    test('Manifest 必须声明小组件 receiver', () {
      expect(manifestSource, contains('.PokoWidgetProvider'));
      expect(manifestSource, contains('android.appwidget.action.APPWIDGET_UPDATE'));
      expect(manifestSource, contains('android.appwidget.provider'));
      expect(manifestSource, contains('@xml/poko_widget_info'));
    });

    test('小组件元信息与布局必须齐备', () {
      expect(widgetInfoXml, contains('<appwidget-provider'));
      expect(widgetInfoXml, contains('@layout/poko_widget'));
      expect(widgetInfoXml, contains('android:updatePeriodMillis'),
          reason: '小组件必须有刷新周期');
      for (final id in const <String>[
        'widget_root',
        'widget_emoji',
        'widget_name',
        'widget_status',
        'widget_recall',
      ]) {
        expect(widgetLayoutXml, contains(id),
            reason: '小组件布局缺少 $id');
      }
    });

    test('小组件必须复用服务层的状态快照，不得自己另算一套', () {
      expect(widgetProviderSource, contains('FloatingPetService.readStateSnapshot'),
          reason: '小组件必须用与桌面猫同一份状态快照');
      expect(serviceSource, contains('fun readStateSnapshot'),
          reason: '状态快照必须由服务层统一提供');
    });

    test('小组件只读不写：不得写 SharedPreferences', () {
      // 状态存档由 App 与悬浮宠服务共同维护。
      // 小组件要是也去写，就会和 Flutter 侧互相覆盖（App 内存里的旧值会盖掉新值）。
      expect(widgetProviderSource, isNot(contains('.edit()')),
          reason: '小组件不得写 SharedPreferences');
      expect(widgetProviderSource, isNot(contains('putString')));
      expect(widgetProviderSource, isNot(contains('putInt')));
    });

    test('唤出桌面猫必须走前台服务通道（后台启动限制）', () {
      expect(widgetProviderSource, contains('getForegroundService'),
          reason: '后台唤出前台服务必须用 getForegroundService，'
              '用 getService 在 Android 8+ 会抛 IllegalStateException');
      expect(widgetProviderSource, contains('FloatingPetService'),
          reason: '小组件按钮必须能启动悬浮宠服务');
    });

    test('状态变化时小组件要跟着刷新', () {
      expect(widgetProviderSource, contains('fun refreshAll'));
      expect(serviceSource, contains('PokoWidgetProvider.refreshAll'),
          reason: '服务层状态变化后必须主动刷新小组件');
    });
  });

  group('入口语义：点身体=互动，点旁边=菜单，收起后能召回', () {
    test('点空白只开菜单，不得再叠加"摸摸 + 随机气泡"', () {
      // 之前一次点击同时做三件事：摸摸（音效+动画）、弹菜单、冒随机气泡，
      // 用户说不清自己在按什么，菜单也像是自己冒出来的。
      final zoneFn = _braceBlock(serviceSource, 'private fun handleZoneTap(');
      final blankBranch = zoneFn.substring(zoneFn.indexOf('// 空白处'));
      expect(blankBranch, isNot(contains('playSound(')),
          reason: '点空白开菜单时不应再叠加音效');
      expect(blankBranch, isNot(contains('onPetTapped()')),
          reason: '点空白开菜单时不应再叠加"摸摸"动画');
      expect(blankBranch, isNot(contains('showSpeechBubble(')),
          reason: '点空白开菜单时不应再叠加随机气泡');
      expect(blankBranch, contains('showActionMenu()'),
          reason: '点空白仍然要能开菜单');
    });

    test('"收起"不能等同于"消失"：不得 stopSelf，必须留着召回入口', () {
      final dismissFn = _braceBlock(serviceSource, 'private fun handleDesktopDismiss(');
      expect(dismissFn, isNot(contains('stopSelf()')),
          reason: '收起只是收进通知栏，不能把服务停掉 —— '
              '否则用户收起来就再也找不回来了');
      expect(serviceSource, contains('ACTION_NOTIFICATION_RECALL'),
          reason: '必须提供"召回波可"的 action');
      expect(serviceSource, contains('fun recallPet()'));
      expect(serviceSource, contains('isPetRecalled'),
          reason: '必须记录"当前是否被收进通知栏"');
    });

    test('通知栏按钮要跟着状态切换：可见时互动，收起后召回/关闭', () {
      expect(serviceSource, contains('🐾 召回'));
      expect(serviceSource, contains('✕ 关闭'));
      // 收起状态下，猫不能因为 App 前后台切换就自己跑回桌面
      expect(serviceSource, contains('!isPetRecalled'),
          reason: '显隐判定必须把"被用户收起"算进去');
    });
  });

  group('Android 资源引用完整性：aapt 阶段的错误本地查不到', () {
    test('XML 与 Kotlin 里引用的资源必须真实存在', () {
      // 背景：本机没有 Android SDK，aapt 根本跑不起来，
      // 所以 "@string/xxx 写错了" / "@layout/xxx 不存在" 这类错误本地完全看不出来，
      // 只能等 CI 在 aapt 阶段炸出来。本组把这一层也纳入守护。
      final resDir =
          Directory('${packageRoot.path}/android/app/src/main/res');
      final defined = _collectAndroidResources(resDir);
      expect(defined, isNotEmpty, reason: '资源目录解析失败，检测器可能已失效');

      // 引用来源：所有 XML（含 AndroidManifest）+ Kotlin 里的 R.xxx.yyy
      final refs = <String, String>{};

      for (final file in resDir.listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.xml')) continue;
        final content = file.readAsStringSync();
        for (final m
            in RegExp(r'@(?!android:)(\w+)/([A-Za-z0-9_.]+)').allMatches(content)) {
          refs.putIfAbsent(m.group(2)!, () => file.path);
        }
      }
      for (final source in <String>[
        serviceSource,
        activitySource,
        petViewSource,
        overlayChannelKotlin,
        widgetProviderSource,
      ]) {
        for (final m in RegExp(r'\bR\.(\w+)\.(\w+)').allMatches(source)) {
          refs.putIfAbsent(m.group(2)!, () => 'R.${m.group(1)}');
        }
      }
      for (final m in RegExp(r'@(\w+)/([A-Za-z0-9_.]+)')
          .allMatches(manifestSource)) {
        refs.putIfAbsent(m.group(2)!, () => 'AndroidManifest.xml');
      }

      final missing = refs.keys.where((n) => !defined.contains(n)).toList()
        ..sort();
      expect(
        missing,
        isEmpty,
        reason: '引用了不存在的资源（CI 会在 aapt 阶段失败）：\n'
            '${missing.map((n) => '$n  (来自 ${refs[n]})').join('\n')}',
      );
    });

    test('资源引用的解析器必须真的解析出了东西（防止检测器空转）', () {
      final resDir =
          Directory('${packageRoot.path}/android/app/src/main/res');
      final defined = _collectAndroidResources(resDir);
      expect(defined.length, greaterThan(10),
          reason: '解析到的资源数明显偏少（${defined.length}），检测器可能已失效');
      expect(defined, contains('poko_widget'),
          reason: '应识别出小组件布局');
      expect(defined, contains('widget_background'),
          reason: '应识别出小组件背景 drawable');
      expect(defined, contains('widget_description'),
          reason: '应识别出 values/strings.xml 里定义的字符串');
      expect(defined, contains('widget_emoji'),
          reason: '应识别出布局里 @+id 声明的 id');
    });
  });

  group('Android 静态常量：成员必须真实存在', () {
    test('Intent.ACTION_* / CATEGORY_* 必须是真实存在的常量', () {
      // 背景：CI 报过 `Unresolved reference 'CATEGORY_APP_WIDGET'` ——
      // Intent 里根本没有这个常量（是记错了，AppWidgetManager 那边才是别的名字）。
      // 这类"成员不存在"的错误本地原理上查不出来：
      // import 审计器只查"用了没 import"，而这里是"import 了但成员没有"。
      final code = _stripLiteralsAndComments(<String>[
        serviceSource,
        activitySource,
        petViewSource,
        overlayChannelKotlin,
        widgetProviderSource,
      ].join('\n'));

      final problems = <String>[];
      for (final m in RegExp(r'\bIntent\.(ACTION_[A-Z0-9_]+|CATEGORY_[A-Z0-9_]+)\b')
          .allMatches(code)) {
        final name = m.group(1)!;
        if (!_knownIntentConstants.contains(name)) {
          problems.add('Intent.$name');
        }
      }

      expect(
        problems,
        isEmpty,
        reason: '引用了 Intent 上不存在的常量（CI 会报 Unresolved reference）：\n'
            '${problems.join("\n")}\n'
            '若确实要用新的 Intent 常量，先确认它在 android.content.Intent 里真实存在，'
            '再登记到守护测试的 _knownIntentConstants 表里。',
      );
    });

    test('Intent 常量表本身不能为空（防止检测器把一切都放行）', () {
      expect(_knownIntentConstants.length, greaterThan(20),
          reason: 'Intent 常量表明显偏小，检测器可能已失效');
      expect(_knownIntentConstants, contains('ACTION_MAIN'));
      expect(_knownIntentConstants, contains('CATEGORY_LAUNCHER'));
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

    test('昼夜状态必须两端都能传', () {
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
    });

    test('悬浮宠必须提供无障碍描述', () {
      expect(serviceSource, contains('contentDescription'),
          reason: '悬浮宠没有 contentDescription，TalkBack 读不到它');
      expect(serviceSource, contains('IMPORTANT_FOR_ACCESSIBILITY_YES'),
          reason: '悬浮宠没有声明无障碍重要性');
    });
  });

  group('桌面悬浮猫与 App 内的猫必须是同一只', () {
    test('双端皮肤色表必须逐项一致', () {
      // 背景：原生侧 updateColors() 里原本只覆盖 10 个品种，
      // 剩下 5 个（银渐层/缅因/美短/临清狮子/雪球白）全部落到 else 默认橘猫配色，
      // 用户在 App 里换完装，桌面上却变成了一只橘猫。
      //
      // 这里把两张表逐项比对，任何一边新增/改色而另一边忘了同步，CI 立刻变红。
      final dartSkins = _parseDartSkinTable(petModelSource);
      final kotlinSkins = _parseKotlinSkinPalette(petViewSource);

      expect(dartSkins.length, greaterThanOrEqualTo(14),
          reason: 'Dart 端皮肤表解析结果异常，检测器可能空转');
      expect(kotlinSkins.length, greaterThanOrEqualTo(14),
          reason: '原生端皮肤表解析结果异常，检测器可能空转');

      final dartIds = dartSkins.keys.toSet();
      final kotlinIds = kotlinSkins.keys.toSet();
      expect(kotlinIds, dartIds,
          reason: '两端的品种集合不一致 —— '
              '原生多出：${kotlinIds.difference(dartIds)}，'
              '原生缺少：${dartIds.difference(kotlinIds)}');

      for (final id in dartIds) {
        expect(kotlinSkins[id], dartSkins[id],
            reason: '品种 $id 的配色两端不一致：'
                'App=${dartSkins[id]}，桌面=${kotlinSkins[id]}');
      }
    });

    test('双端皮肤色表解析器必须有效（防止检测器静默退化）', () {
      final dartSkins = _parseDartSkinTable(petModelSource);
      final kotlinSkins = _parseKotlinSkinPalette(petViewSource);

      expect(dartSkins.containsKey('cat_ragdoll'), isTrue,
          reason: 'Dart 端皮肤表解析失效');
      expect(dartSkins['cat_ragdoll'], ['FFFDF8', '8E9AAF', '0284C7'],
          reason: 'Dart 端皮肤表解析结果不对');
      expect(kotlinSkins.containsKey('cat_ragdoll'), isTrue,
          reason: '原生端皮肤表解析失效');
      expect(kotlinSkins['cat_ragdoll'], ['FFFDF8', '8E9AAF', '0284C7'],
          reason: '原生端皮肤表解析结果不对');

      // 人造样本：解析器必须真的能读出跨行 / 带注释的表
      const fake = '''
  "cat_demo" -> SkinPalette(
      Color.parseColor("#112233"),
      Color.parseColor("#445566"),
      Color.parseColor("#778899"),
      Color.parseColor("#AABBCC"),
  )
''';
      final parsed = _parseKotlinSkinPalette(fake);
      expect(parsed['cat_demo'], ['112233', '445566', 'AABBCC'],
          reason: '原生端皮肤表解析器对跨行样本失效');
    });

    test('夜间不得改动猫的毛色', () {
      // 用户反馈："到晚上桌面悬浮猫的颜色渲染不太对，和 App 内的不太统一"。
      // 根因：原生侧在夜间给毛色压了一层"月光滤镜"（×0.72 / 0.74 / 0.86），
      // 而 App 里的猫用的就是皮肤原色（lib/renderers/pet_painter.dart 从不套夜间滤镜），
      // 于是同一只白猫，App 里雪白、桌面上是暗黄灰。
      //
      // 这是一条**反向**守护：只要有人再给本体色加滤镜，CI 立刻变红。
      expect(petViewSource, isNot(contains('applyNightTint')),
          reason: '桌面悬浮猫不允许在夜间给毛色套滤镜：'
              'App 里的猫用的是皮肤原色，桌面这边必须一致');
      expect(petViewSource, isNot(contains('blendTowardGray')),
          reason: '桌面悬浮猫不允许"脏了毛色发灰"：App 里的猫不这么画，'
              '"脏了"由状态徽标（🧼）表达');

      final updateColorsBody = _braceBlock(petViewSource, 'private fun updateColors()');
      expect(updateColorsBody, isNot(contains('* 0.')),
          reason: 'updateColors() 里出现了颜色系数，说明有人在本体色上加滤镜');
      expect(updateColorsBody, contains('skinPaletteOf(skinId)'),
          reason: '猫本体色应当直接取自皮肤配色表');
    });

    test('昼夜边界必须两端贯通：桌面端自己按太阳节律判昼夜', () {
      expect(overlayChannelKotlin, contains('const val ARG_DAY_START_MINUTE'),
          reason: '原生侧缺少昼夜边界参数');
      expect(overlayChannelKotlin, contains('const val ARG_NIGHT_START_MINUTE'),
          reason: '原生侧缺少昼夜边界参数');
      expect(overlayChannelDart, contains('argDayStartMinute'),
          reason: 'Dart 侧缺少昼夜边界参数');
      expect(overlayChannelDart, contains('argNightStartMinute'),
          reason: 'Dart 侧缺少昼夜边界参数');
      expect(activitySource, contains('OverlayChannel.ARG_DAY_START_MINUTE'),
          reason: 'MainActivity 没有把昼夜边界传给服务');
      expect(activitySource, contains('OverlayChannel.ARG_NIGHT_START_MINUTE'),
          reason: 'MainActivity 没有把昼夜边界传给服务');
      expect(serviceSource, contains('appDayStartMinute'),
          reason: '服务没有保存 App 推来的昼夜边界');
      expect(serviceSource, contains('currentMinuteOfDay()'),
          reason: '服务没有按当前本地时间自己判断昼夜');
    });

    test('重点色品种必须有招牌色块', () {
      final headFn =
          _memberFunctions(petViewSource).firstWhere((f) => f.name == 'drawHead');
      for (final breed in <String>[
        'cat_ragdoll',
        'cat_siamese',
        'cat_american_tabby',
        'cat_maine_coon',
      ]) {
        expect(headFn.body, contains(breed),
            reason: 'drawHead() 里没有 $breed 的招牌色块，桌面猫认不出品种');
      }

      final earsFn =
          _memberFunctions(petViewSource).firstWhere((f) => f.name == 'drawEars');
      expect(earsFn.body, contains('cat_ragdoll'),
          reason: 'drawEars() 里没有布偶猫：重点色猫的耳背要用重点色');
      expect(earsFn.body, contains('isPointCat'),
          reason: 'drawEars() 缺少"重点色猫"判断');

      // 尾巴尖重点色：App 端有 7 个品种用辅助色，桌面端必须一致
      final tailFn =
          _memberFunctions(petViewSource).firstWhere((f) => f.name == 'drawTail');
      for (final breed in <String>[
        'cat_siamese',
        'cat_ragdoll',
        'cat_calico',
        'cat_golden_shaded',
        'cat_silver_shaded',
        'cat_maine_coon',
        'cat_sakura_peach',
      ]) {
        expect(tailFn.body, contains(breed),
            reason: 'drawTail() 的尾尖重点色少了 $breed，桌面猫和 App 里的猫对不上');
      }

      // 临清狮子猫是金银异瞳
      final eyesFn =
          _memberFunctions(petViewSource).firstWhere((f) => f.name == 'drawEyes');
      expect(eyesFn.body, contains('cat_persian_white'),
          reason: 'drawEyes() 没有处理临清狮子猫的金银异瞳');
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

  group('Kotlin 空安全：宿主类回调参数必须显式收窄', () {
    // 真实事故：CI 上 :app:compileReleaseKotlin 报
    //   Argument type mismatch: actual type is 'Runnable?', but 'Runnable' was expected.
    // 原因是 Android SDK 里 Handler.removeCallbacks(Runnable) 的参数声明为**非空**，
    // 而本机没有 android.jar，kotlinc 分不出宿主类成员的真实签名 ——
    // 这类问题本地永远查不出来，只能等 CI 炸（一次往返 4 分半）。
    // 所以这里用源码断言提前拦住。

    test('可空 Runnable 不得直接传给 Handler.removeCallbacks / postDelayed', () {
      final problems = <String>[];
      final sources = <String, String>{
        'FloatingPetService.kt': serviceSource,
        'MainActivity.kt': activitySource,
        'PokoPetView.kt': petViewSource,
        'PokoWidgetProvider.kt': widgetProviderSource,
      };
      for (final entry in sources.entries) {
        for (final p in _findNullableCallbackArgs(entry.value)) {
          problems.add('${entry.key}: $p');
        }
      }

      expect(problems, isEmpty,
          reason: '可空回调被直接传给 Handler/View 的回调方法，'
              'Android SDK 里这些参数是非空的，CI 会报 '
              '"Argument type mismatch: actual type is \'Runnable?\', but \'Runnable\' was expected." '
              '必须写成 name!! 或 name?.let { ... }');
    });

    test('检测器本身必须有效：能识别人造的可空回调误用样本', () {
      const bad = '''
        private var tick: Runnable? = null
        fun boom(handler: Handler) {
          handler.removeCallbacks(tick)
          handler.postDelayed(tick, 100)
        }
      ''';
      expect(_findNullableCallbackArgs(bad), isNotEmpty,
          reason: '检测器对「可空 Runnable 直接传入」的样本必须报警，否则等于没检测');

      const good = '''
        private var tick: Runnable? = null
        fun ok(handler: Handler) {
          tick?.let { handler.removeCallbacks(it) }
          handler.postDelayed(tick!!, 100)
        }
      ''';
      expect(_findNullableCallbackArgs(good), isEmpty,
          reason: '合法的显式收窄写法不应被误报');
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
// Android 资源与常量审计
//
// 动机：本机没有 Android SDK，aapt 跑不起来、android.jar 也没有，
// 于是两类错误本地原理上就查不出来，只能等 CI 炸出来：
//   1. 资源引用错误：@string/xxx 写错了、@layout/xxx 不存在 -> aapt 阶段失败
//   2. 常量成员错误：Intent.CATEGORY_APP_WIDGET 根本不存在 -> kotlinc 阶段失败
// ---------------------------------------------------------------------------

/// 已知的 android.content.Intent 静态常量（ACTION_* / CATEGORY_*）。
///
/// ⚠️ 新增 Intent 常量时，务必先确认它在 android.content.Intent 里真实存在，
/// 再登记到这里 —— 没登记的会被判为"不存在的常量"而让 CI 变红。
const Set<String> _knownIntentConstants = <String>{
  // ---- ACTION ----
  'ACTION_MAIN', 'ACTION_VIEW', 'ACTION_SEND', 'ACTION_SENDTO',
  'ACTION_SEND_MULTIPLE', 'ACTION_EDIT', 'ACTION_INSERT', 'ACTION_DELETE',
  'ACTION_PICK', 'ACTION_GET_CONTENT', 'ACTION_CHOOSER', 'ACTION_ASSIST',
  'ACTION_CAPTURE_IMAGE', 'ACTION_CAPTURE_VIDEO', 'ACTION_CAMERA',
  'ACTION_DIAL', 'ACTION_SEARCH', 'ACTION_PROCESS_TEXT',
  'ACTION_CREATE_SHORTCUT', 'ACTION_DELETE_SHORTCUT',
  'ACTION_MEDIA_MOUNTED', 'ACTION_MEDIA_UNMOUNTED', 'ACTION_MEDIA_EJECT',
  'ACTION_MEDIA_SCANNER_SCAN_FILE', 'ACTION_PACKAGE_ADDED',
  'ACTION_PACKAGE_REMOVED', 'ACTION_PACKAGE_REPLACED', 'ACTION_PACKAGE_CHANGED',
  'ACTION_PACKAGE_DATA_CLEARED', 'ACTION_PACKAGE_RESTARTED',
  'ACTION_INSTALL_PACKAGE', 'ACTION_UNINSTALL_PACKAGE',
  'ACTION_TIME_TICK', 'ACTION_TIME_CHANGED', 'ACTION_TIMEZONE_CHANGED',
  'ACTION_LOCALE_CHANGED', 'ACTION_BOOT_COMPLETED', 'ACTION_SHUTDOWN',
  'ACTION_USER_PRESENT', 'ACTION_SCREEN_ON', 'ACTION_SCREEN_OFF',
  'ACTION_HEADSET_PLUG', 'ACTION_BATTERY_CHANGED', 'ACTION_BATTERY_LOW',
  'ACTION_BATTERY_OKAY', 'ACTION_POWER_CONNECTED', 'ACTION_POWER_DISCONNECTED',
  'ACTION_NEW_OUTGOING_CALL', 'ACTION_CALL_BUTTON', 'ACTION_EMERGENCY_ASSIST',
  // ---- CATEGORY ----
  'CATEGORY_DEFAULT', 'CATEGORY_BROWSABLE', 'CATEGORY_LAUNCHER', 'CATEGORY_HOME',
  'CATEGORY_INFO', 'CATEGORY_SERVICE', 'CATEGORY_CARGO', 'CATEGORY_MESSAGING',
  'CATEGORY_SOCIAL', 'CATEGORY_EVERYTHING', 'CATEGORY_TAB',
};

/// 收集 res/ 目录下已定义的全部资源名。
///
/// 覆盖三类来源：
///   - 文件名（layout/xxx.xml、drawable/xxx.xml、mipmap-*/xxx.png ...）
///   - values/*.xml 里声明的 string / color / style / dimen ...
///   - 布局里 `@+id/xxx` 声明的 id
Set<String> _collectAndroidResources(Directory resDir) {
  final defined = <String>{};
  if (!resDir.existsSync()) return defined;

  for (final entity in resDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll('\\', '/');
    final fileName = path.split('/').last;
    final parentDir =
        path.substring(0, path.lastIndexOf('/')).split('/').last;

    if (parentDir.startsWith('values')) {
      // values/ 里定义的是 string / color / style / dimen ...
      final content = entity.readAsStringSync();
      for (final m in RegExp(
        r'<(?:string|color|style|dimen|bool|integer|string-array|array|plurals|item)\s[^>]*?name="([^"]+)"',
      ).allMatches(content)) {
        defined.add(m.group(1)!);
      }
    } else {
      // 其余目录：文件名即资源名（drawable / layout / mipmap / xml ...）
      final dot = fileName.indexOf('.');
      if (dot > 0) defined.add(fileName.substring(0, dot));
    }

    // 布局里用 @+id/xxx 声明的 id
    if (fileName.endsWith('.xml')) {
      final content = entity.readAsStringSync();
      for (final m in RegExp(r'@\+id/([A-Za-z0-9_]+)').allMatches(content)) {
        defined.add(m.group(1)!);
      }
    }
  }
  return defined;
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
  'Companion',    // 伴生对象的隐式名，同类内可直接引用
  'Charsets',     // kotlin.text.Charsets，kotlin 默认导入
  'START_STICKY', // android.app.Service 的继承成员
  'START_NOT_STICKY',
  'LAYER_TYPE_HARDWARE', // android.view.View 的继承常量
  'MeasureSpec',          // android.view.View 的嵌套类（View 子类内可直接用）
};

/// 通配符导入包内已知可用的类型（只列本项目真正会用到的，宁可宽松也别误报）
const Map<String, Set<String>> _wildcardPackageMembers = <String, Set<String>>{
  'android.graphics': <String>{
    'Canvas', 'Color', 'Paint', 'Path', 'Rect', 'RectF', 'Point', 'PointF',
    'Matrix', 'Shader', 'RadialGradient', 'LinearGradient', 'SweepGradient',
    'ComposeShader', 'PorterDuff', 'PorterDuffXfermode', 'Xfermode',
    'Typeface', 'Bitmap', 'BitmapFactory', 'BlurMaskFilter', 'DashPathEffect',
    'PaintFlags', 'PathEffect', 'PathMeasure', 'RoundRect', 'Picture',
    'FontMetrics', 'TypefaceMetrics',
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

/// Kotlin 源里的一个属性（含主构造函数的 val/var 参数）
class _KotlinProp {
  final String name;
  final String type;
  final String visibility;
  final bool isVar;

  const _KotlinProp(this.name, this.type, this.visibility, this.isVar);
}

/// Kotlin 源里的一个函数
class _KotlinFun {
  final String name;
  final List<String> paramTypes;
  final String returnType;
  final String visibility;

  const _KotlinFun(this.name, this.paramTypes, this.returnType, this.visibility);
}

/// Kotlin 源里的一个类（含嵌套类 / companion object）
class _KotlinClassInfo {
  final String name;
  final List<_KotlinProp> props = <_KotlinProp>[];
  final List<_KotlinFun> funs = <_KotlinFun>[];

  _KotlinClassInfo(this.name);
}

/// 一个 JVM 签名条目：描述 + Kotlin 可见性
class _JvmSigEntry {
  final String description;
  final String visibility;

  const _JvmSigEntry(this.description, this.visibility);
}

/// class / object / interface 声明
/// group(1) = 可见性，group(2) = 类名
final RegExp _kotlinClassDeclRegex = RegExp(
  r'^(?:@\w+(?:\([^)]*\))?\s+)*'
  r'(public|private|internal|protected)?\s*'
  r'(?:(?:data|enum|sealed|annotation|value|open|abstract|inner|expect|actual)\s+)*'
  r'(?:class|object|interface)\s+'
  r'([A-Za-z_]\w*)',
);

/// 匿名 companion object 声明（group(1) = 可见性）
final RegExp _kotlinCompanionDeclRegex = RegExp(
  r'^(?:@\w+(?:\([^)]*\))?\s+)*'
  r'(public|private|internal|protected)?\s*'
  r'(?:(?:data|enum|sealed|annotation|value|open|abstract|inner|expect|actual)\s+)*'
  r'companion\s+object\b',
);

/// 成员声明前的修饰词前缀（可见性 / override / 注解 ...），group(1) = 修饰词串
final RegExp _kotlinMemberPrefixRegex = RegExp(
  r'^((?:(?:@\w+(?:\([^)]*\))?\s+)'
  r'|(?:(?:public|private|internal|protected|override|open|final|suspend|inline|operator|'
  r'infix|tailrec|external|lateinit|const|abstract|expect|actual|companion|data|enum|sealed|'
  r'annotation|value|inner|vararg|crossinline|noinline)\s+))*)',
);

/// Kotlin 原始类型 -> JVM 原始类型描述符
const Map<String, String> _kotlinPrimitiveDescriptors = <String, String>{
  'Boolean': 'Z',
  'Int': 'I',
  'Long': 'J',
  'Float': 'F',
  'Double': 'D',
  'Char': 'C',
  'Short': 'S',
  'Byte': 'B',
};

/// Kotlin 原始数组类型
const Map<String, String> _kotlinArrayPrimitives = <String, String>{
  'IntArray': 'I',
  'FloatArray': 'F',
  'BooleanArray': 'Z',
  'LongArray': 'J',
  'DoubleArray': 'D',
  'ByteArray': 'B',
  'CharArray': 'C',
  'ShortArray': 'S',
};

/// 常见 Kotlin 引用类型 -> JVM 内部类名
const Map<String, String> _kotlinStdlibJvmNames = <String, String>{
  'String': 'java/lang/String',
  'Any': 'java/lang/Object',
  'Nothing': 'java/lang/Object',
  'List': 'java/util/List',
  'MutableList': 'java/util/List',
  'ArrayList': 'java/util/ArrayList',
  'Map': 'java/util/Map',
  'MutableMap': 'java/util/Map',
  'HashMap': 'java/util/HashMap',
  'Set': 'java/util/Set',
  'MutableSet': 'java/util/Set',
  'HashSet': 'java/util/HashSet',
  'Pair': 'kotlin/Pair',
  'Triple': 'kotlin/Triple',
};

/// Kotlin 类型 -> JVM 擦除描述符
String _eraseJvmType(String rawType) {
  var t = rawType.trim();
  if (t.isEmpty) return '?';
  t = t.replaceAll(RegExp(r'@\w+(\.[\w.]+)?(\([^)]*\))?'), ' ').trim();
  t = t.replaceAll('?', '');
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceFirst(RegExp(r'^(out|in)\s+'), '').trim();
  if (t.contains('->')) return 'Lkotlin/jvm/functions/FunctionN;';
  if (t.contains('<')) {
    return _eraseJvmType(t.substring(0, t.indexOf('<')));
  }
  final prim = _kotlinPrimitiveDescriptors[t];
  if (prim != null) return prim;
  if (t == 'Unit') return 'V';
  final arr = _kotlinArrayPrimitives[t];
  if (arr != null) return '[$arr';
  final std = _kotlinStdlibJvmNames[t];
  if (std != null) return 'L$std;';
  final simple = t.contains('.') ? t.split('.').last : t;
  return 'L$simple;';
}

/// Kotlin 属性的隐式 setter 名：
///   isNightMode -> setNightMode（Kotlin 会剥掉 is 前缀）
///   nightMode   -> setNightMode
String _implicitSetterName(String propName) {
  if (propName.length > 2 &&
      propName.startsWith('is') &&
      propName[2] == propName[2].toUpperCase()) {
    return 'set${propName.substring(2)}';
  }
  return 'set${propName[0].toUpperCase()}${propName.substring(1)}';
}

/// 属性生成的 JVM 方法：[jvmName, descriptor, 描述]
List<List<Object>> _accessorDescriptors(
  String propName,
  String type,
  bool isVar,
) {
  final out = <List<Object>>[];
  final erased = _eraseJvmType(type);
  final isBoolean = erased == 'Z';
  final hasIsPrefix = propName.length > 2 &&
      propName.startsWith('is') &&
      propName[2] == propName[2].toUpperCase();

  var getterName = 'get${propName[0].toUpperCase()}${propName.substring(1)}';
  if (isBoolean && hasIsPrefix) {
    // Boolean 的 is 前缀属性，getter 保留 isX
    getterName = propName;
  }
  out.add(<Object>[getterName, '()$erased', 'public 属性 `$propName` 的隐式 getter']);
  if (isVar) {
    out.add(<Object>[
      _implicitSetterName(propName),
      '($erased)V',
      'public 属性 `$propName` 的隐式 setter',
    ]);
  }
  return out;
}

/// 函数返回的 JVM 描述符：(参数类型...)返回类型
String _funJvmDescriptor(List<String> paramTypes, String returnType) {
  final ps = paramTypes.map(_eraseJvmType).join(',');
  return '($ps)${_eraseJvmType(returnType)}';
}

int _countChar(String s, String ch) {
  var n = 0;
  for (var i = 0; i < s.length; i++) {
    if (s[i] == ch) n++;
  }
  return n;
}

/// 按顶层分隔符切分（括号 / 尖括号 / 方括号内的逗号不算）
List<String> _splitTopLevel(String s, String sep) {
  final out = <String>[];
  var depth = 0;
  var cur = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == '(' || ch == '<' || ch == '[') {
      depth++;
    } else if (ch == ')' || ch == '>' || ch == ']') {
      depth = depth > 0 ? depth - 1 : 0;
    }
    if (ch == sep && depth == 0) {
      out.add(cur.toString());
      cur = StringBuffer();
    } else {
      cur.write(ch);
    }
  }
  out.add(cur.toString());
  return out;
}

/// 返回与 openIdx 处 '(' 配对的 ')' 下标；找不到返回 -1
int _matchParen(String s, int openIdx) {
  var depth = 0;
  for (var i = openIdx; i < s.length; i++) {
    if (s[i] == '(') {
      depth++;
    } else if (s[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

/// 从初始化表达式粗略推断类型：Foo(...) -> Foo；否则 Any
String _inferKotlinType(String? init) {
  if (init == null) return 'Any';
  final m = RegExp(r'^([A-Z]\w*)\s*\(').firstMatch(init.trim());
  return m != null ? m.group(1)! : 'Any';
}

/// 主构造函数里的 val/var 参数也是属性
List<_KotlinProp> _primaryCtorProps(
  String code,
  List<String> lines,
  int lineIndex,
  int nameEndInLine,
) {
  var offset = 0;
  for (var k = 0; k < lineIndex; k++) {
    offset += lines[k].length + 1;
  }
  final openIdx = code.indexOf('(', offset + nameEndInLine);
  if (openIdx < 0) return const <_KotlinProp>[];
  final closeIdx = _matchParen(code, openIdx);
  if (closeIdx < 0) return const <_KotlinProp>[];

  final out = <_KotlinProp>[];
  for (final raw in _splitTopLevel(code.substring(openIdx + 1, closeIdx), ',')) {
    final p = raw.trim();
    final m = RegExp(
      r'^(?:@\w+(?:\([^)]*\))?\s+)*(val|var)\s+([A-Za-z_]\w*)'
      r'\s*(?::\s*(.+?))?(?:\s*=.*)?$',
    ).firstMatch(p);
    if (m != null) {
      out.add(_KotlinProp(
        m.group(2)!,
        (m.group(3) ?? 'Any').trim(),
        'public',
        true,
      ));
    }
  }
  return out;
}

/// 从一行源码里抽出属性 / 函数，塞进所属类
void _collectKotlinMember(String line, _KotlinClassInfo cls) {
  if (line.isEmpty || line.startsWith('//') || line.startsWith('*')) return;

  final pm = _kotlinMemberPrefixRegex.firstMatch(line);
  if (pm == null) return;
  final mods = pm.group(1) ?? '';
  var vis = 'public';
  for (final w in const <String>['public', 'private', 'internal', 'protected']) {
    if (RegExp('\\b$w\\b').hasMatch(mods)) vis = w;
  }

  final rest = line.substring(pm.end).trim();
  if (rest.isEmpty) return;
  final kw = rest.split(RegExp(r'\s+')).first;

  if (kw == 'var' || kw == 'val') {
    final m = RegExp(
      r'^(var|val)\s+([A-Za-z_]\w*)\s*(?::\s*(.+?))?(?:\s*=\s*(.*))?$',
    ).firstMatch(rest);
    if (m == null) return;
    var type = (m.group(3) ?? '').trim();
    if (type.isEmpty) type = _inferKotlinType(m.group(4));
    cls.props.add(_KotlinProp(m.group(2)!, type, vis, m.group(1) == 'var'));
    return;
  }

  if (kw != 'fun') return;

  // 扩展函数（带接收者）不属于宿主类的成员
  if (RegExp(r'^fun\s+(?:<[^>]*>\s*)?[A-Za-z_]\w*\.[A-Za-z_]\w*\s*\(')
      .hasMatch(rest)) {
    return;
  }

  final nameMatch =
      RegExp(r'^fun\s+(?:<[^>]*>\s*)?([A-Za-z_]\w*)\s*\(').firstMatch(rest);
  if (nameMatch == null) return;
  final name = nameMatch.group(1)!;
  final openIdx = rest.indexOf('(', nameMatch.start);
  final closeIdx = _matchParen(rest, openIdx);
  if (closeIdx < 0) return;

  final params = rest.substring(openIdx + 1, closeIdx);
  final after = rest.substring(closeIdx + 1).trim();
  var ret = 'Unit';
  final retMatch = RegExp(r'^:\s*([^=]+?)\s*(?:=|\{|$)').firstMatch(after);
  if (retMatch != null) ret = retMatch.group(1)!.trim();

  final types = <String>[];
  if (params.trim().isNotEmpty) {
    for (final p in _splitTopLevel(params, ',')) {
      final pt = RegExp(
        r'^\s*(?:@\w+(?:\([^)]*\))?\s*)*(?:vararg\s+)?'
        r'(?:[A-Za-z_]\w*\s*:\s*)?(.+?)\s*(?:=.*)?$',
      ).firstMatch(p);
      if (pt != null) types.add(pt.group(1)!.trim());
    }
  }
  cls.funs.add(_KotlinFun(name, types, ret, vis));
}

/// 扫描 Kotlin 源码里所有类（含嵌套类 / companion object）及其成员
List<_KotlinClassInfo> _scanKotlinClasses(String source) {
  final code = _stripLiteralsAndComments(source);
  final lines = code.split('\n');

  // 每行"开始前"的花括号深度
  final depthBefore = <int>[];
  var d = 0;
  for (final l in lines) {
    depthBefore.add(d);
    d += _countChar(l, '{') - _countChar(l, '}');
  }

  final classes = <_KotlinClassInfo>[];
  // 基础深度 -> 该深度上声明的类名（用于给嵌套类 / companion 命名）
  final classAtBaseDepth = <int, String>{};

  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trim();

    // 匿名 companion object —— 它的成员也是一个独立的 JVM 类（Owner$Companion）
    final companionMatch = _kotlinCompanionDeclRegex.firstMatch(trimmed);
    if (companionMatch != null) {
      final base = depthBefore[i];
      final owner = classAtBaseDepth[base - 1] ?? 'Companion';
      final cls = _KotlinClassInfo('$owner.Companion');
      final bodyEnd = _classBodyEnd(lines, depthBefore, i, base);
      for (var k = i + 1; k <= bodyEnd; k++) {
        if (depthBefore[k] != base + 1) continue;
        _collectKotlinMember(_logicalMemberLine(lines, k), cls);
      }
      classes.add(cls);
      continue;
    }

    final m = _kotlinClassDeclRegex.firstMatch(trimmed);
    if (m == null) continue;
    final base = depthBefore[i];
    classAtBaseDepth[base] = m.group(2)!;

    final cls = _KotlinClassInfo(m.group(2)!);
    cls.props.addAll(_primaryCtorProps(code, lines, i, m.end));
    final bodyEnd = _classBodyEnd(lines, depthBefore, i, base);
    for (var k = i + 1; k <= bodyEnd; k++) {
      if (depthBefore[k] != base + 1) continue;
      _collectKotlinMember(_logicalMemberLine(lines, k), cls);
    }
    classes.add(cls);
  }
  return classes;
}

/// 取第 [k] 行起、括号配平后的"逻辑成员声明"（支持跨行函数签名）。
///
/// 背景：函数签名写成跨行多行时，单行解析会因为括号没配平而**静默跳过整个函数**，
/// JVM 签名冲突检测就等于给它开了后门 —— 恰好是本守护最该拦住的那类错误。
/// 所以这里把跨行签名拼回一行再交给 [_collectKotlinMember]。
String _logicalMemberLine(List<String> lines, int k) {
  final first = lines[k].trim();
  // 只有函数声明需要拼行；属性声明跨行的情况不在本检测器的关注范围内
  if (!RegExp(r'\bfun\b').hasMatch(first)) return first;

  final buf = StringBuffer(first);
  var depth = _parenDepth(buf.toString());
  var j = k + 1;
  while (depth > 0 && j < lines.length) {
    buf.write(' ');
    buf.write(lines[j].trim());
    depth = _parenDepth(buf.toString());
    j++;
  }
  return buf.toString();
}

/// 一段文本里未闭合的圆括号数量（正数为还剩几个左括号没闭合）
int _parenDepth(String text) {
  var depth = 0;
  for (final ch in text.split('')) {
    if (ch == '(') {
      depth++;
    } else if (ch == ')') {
      depth--;
    }
  }
  return depth;
}

/// 类体结束行：从声明行之后起，最后一个"开始前深度 > base"的行
int _classBodyEnd(List<String> lines, List<int> depthBefore, int declLine, int base) {
  var bodyEnd = declLine;
  for (var j = declLine + 1; j < lines.length && depthBefore[j] > base; j++) {
    bodyEnd = j;
  }
  return bodyEnd;
}

/// 找出 Kotlin 文件里同类成员之间的 JVM 签名冲突（Platform declaration clash）。
///
/// 规则（与 Kotlin/JVM 编译器 backend 对齐）：
///   - 只比较**同一个类**内部（嵌套类、companion object 各自成域）；
///   - public / internal 之间会冲突，private 与非 private 不冲突；
///   - public var isFoo 的隐式 setter 是 setFoo(Boolean)，
///     public var foo 的隐式 setter 是 setFoo(T)，
///     public val 的隐式 getter 是 getFoo()；
///   - 函数 f(a: A): R 的签名是 f(A)R。
List<String> _findJvmSignatureClashes(String source) {
  final classes = _scanKotlinClasses(source);

  final problems = <String>[];
  for (final cls in classes) {
    final sigs = <String, List<_JvmSigEntry>>{};

    void put(String jvmName, String descriptor, String desc, String vis) {
      sigs
          .putIfAbsent('$jvmName$descriptor', () => <_JvmSigEntry>[])
          .add(_JvmSigEntry('$desc（$jvmName$descriptor）', vis));
    }

    for (final p in cls.props) {
      for (final a in _accessorDescriptors(p.name, p.type, p.isVar)) {
        put(a[0] as String, a[1] as String, a[2] as String, p.visibility);
      }
    }
    for (final f in cls.funs) {
      final desc = _funJvmDescriptor(f.paramTypes, f.returnType);
      put(f.name, desc, 'public 函数 `${f.name}`', f.visibility);
    }

    for (final entry in sigs.entries) {
      if (entry.value.length < 2) continue;
      final nonPrivate = entry.value
          .where((e) => e.visibility == 'public' || e.visibility == 'internal')
          .toList();
      if (nonPrivate.length < 2) continue;
      problems.add(
        '${cls.name}: ${nonPrivate.map((e) => e.description).join(' 与 ')} '
        'JVM 签名相同 —— 会报 Platform declaration clash',
      );
    }
  }

  return problems;
}

/// 拖拽算法的行为级模拟器。
///
/// 把原生侧 `FloatingPetService` 的拖拽数学原样复刻出来跑数值：
///   · 手指屏幕绝对位置 F = 窗口位置 W + 窗口局部坐标 l
///   · 窗口新位置 W' = W_0 + (F_now - F_0)（W_0 / F_0 是按下时的基线）
///
/// [useRawCoordinateFormula] 打开后改用**旧算法**（dx = rawX - initialRawX，
/// rawX 取窗口内坐标），用来证明旧算法确实会卡住。
class _DragSim {
  _DragSim({
    required this.windowX,
    required this.windowY,
    required this.windowSize,
    required this.screenWidth,
    required this.screenHeight,
    this.useRawCoordinateFormula = false,
    this.touchSlop = 12,
  });

  double windowX;
  double windowY;
  final double windowSize;
  final double screenWidth;
  final double screenHeight;

  /// 是否改用旧算法（依赖 raw 坐标语义）
  final bool useRawCoordinateFormula;

  /// 进入拖拽的位移阈值（px）
  final double touchSlop;
  late double initialX;
  late double initialY;
  late double initialFingerX;
  late double initialFingerY;
  late double initialRawX;
  late double initialRawY;
  late double lastFingerX;
  late double lastFingerY;
  late double totalDx;
  late double totalDy;

  /// 手指相对**手势起点**的真实行程（不会被边界钳制改写）
  late double gestureStartFingerX;
  late double gestureStartFingerY;
  double travelDx = 0;
  double travelDy = 0;

  /// 是否已经进入拖拽态
  bool enteredDrag = false;

  /// 手指按下
  void down(double localX, double localY) {
    initialX = windowX;
    initialY = windowY;
    initialFingerX = windowX + localX;
    initialFingerY = windowY + localY;
    initialRawX = localX;
    initialRawY = localY;
    lastFingerX = initialFingerX;
    lastFingerY = initialFingerY;
    totalDx = 0;
    totalDy = 0;
    gestureStartFingerX = initialFingerX;
    gestureStartFingerY = initialFingerY;
    travelDx = 0;
    travelDy = 0;
    enteredDrag = false;
  }

  /// 手指移动到新的局部坐标处
  void move(double localX, double localY) {
    double wantedX;
    double wantedY;
    if (useRawCoordinateFormula) {
      // 旧算法：位移来自 raw 坐标（这里按"窗口内坐标"这一语义模拟）
      wantedX = initialX + (localX - initialRawX);
      wantedY = initialY + (localY - initialRawY);
    } else {
      // 新算法：先还原手指的屏幕绝对位置，再算累计位移
      // ⚠️ 注意：这里复刻的是「窗口位置 + 窗口局部坐标」这一口径，
      //    它在**窗口位置与真实位置同步**的前提下是对的（用来验证边界钳制等逻辑），
      //    但真实拖拽里窗口位置会落后一帧 —— 那个坑由 [_DragAlgoSim] 专门复刻。
      final fingerX = windowX + localX;
      final fingerY = windowY + localY;
      totalDx += fingerX - lastFingerX;
      totalDy += fingerY - lastFingerY;
      lastFingerX = fingerX;
      lastFingerY = fingerY;
      wantedX = initialX + (fingerX - initialFingerX);
      wantedY = initialY + (fingerY - initialFingerY);
      // 真实行程：相对不可变的手势起点，边界钳制改不动它
      travelDx = fingerX - gestureStartFingerX;
      travelDy = fingerY - gestureStartFingerY;
      if (!enteredDrag &&
          (travelDx.abs() > touchSlop || travelDy.abs() > touchSlop)) {
        enteredDrag = true;
      }
    }

    final maxX = (screenWidth - windowSize).clamp(0.0, double.infinity);
    final maxY = (screenHeight - windowSize).clamp(0.0, double.infinity);
    final clampedX = wantedX.clamp(0.0, maxX);
    final clampedY = wantedY.clamp(0.0, maxY);
    if (!useRawCoordinateFormula) {
      // 被边界吃掉的位移必须消费掉，否则往回拉时会"粘"在边缘
      initialFingerX += wantedX - clampedX;
      initialFingerY += wantedY - clampedY;
    }
    windowX = clampedX;
    windowY = clampedY;
  }
}

/// 复刻 FloatingPetService.scheduleEdgePeeking 里 peekingRunnable 的判定逻辑。
///
/// 探头任务是**延迟 5.5 秒**才执行的，这 5.5 秒里宠物完全可能被用户拖走。
/// 旧实现只在排任务时检查了一次"是否停在边缘"，运行时直接
/// `params.x = dockedX` 把窗口硬拽回边缘，而 dockedX 用的是 5.5 秒前捕获的 isLeft
/// —— 宠物被拖到另一侧时会被"横跨屏幕"瞬移回去。
class _PeekTaskSim {
  _PeekTaskSim({
    required this.windowX,
    required this.windowY,
    required this.windowSize,
    required this.screenWidth,
    required this.screenHeight,
    required this.density,
    required this.isLeftAtSchedule,
    this.enforceDrift = true,
  });

  double windowX;
  double windowY;
  final double windowSize;
  final double screenWidth;
  final double screenHeight;
  final double density;

  /// 排任务时捕获的参考侧（旧实现直接拿它算 dockedX —— 跨侧瞬移的根源）
  final bool isLeftAtSchedule;

  /// 是否启用"漂移复查"（宠物被挪太远就放弃探头）
  final bool enforceDrift;

  late double scheduledX;
  late double scheduledY;

  /// 任务执行后的窗口 X；null 表示"任务放弃，什么都没做"
  double? resultX;

  /// 排任务
  void schedule() {
    scheduledX = windowX;
    scheduledY = windowY;
  }

  /// 5.5 秒后任务真正执行（期间宠物可能已经被拖走）
  void run() {
    final maxX = (screenWidth - windowSize).clamp(0.0, double.infinity);
    final snapRange = 10 * density;

    // 运行时复查：必须仍在边缘
    final docked = windowX <= snapRange || windowX >= maxX - snapRange;
    if (!docked) {
      resultX = null;
      return;
    }

    // 漂移复查：宠物被挪到别处了就放弃
    if (enforceDrift) {
      final driftTolerance = 24 * density;
      if ((windowX - scheduledX).abs() > driftTolerance ||
          (windowY - scheduledY).abs() > driftTolerance) {
        resultX = null;
        return;
      }
    }

    // 停靠侧按**当前**位置判定
    final dockedOnLeft = windowX <= snapRange;
    final edgeThreshold = 4 * density;
    final dockedX = dockedOnLeft
        ? edgeThreshold
        : (screenWidth - windowSize - edgeThreshold).clamp(0.0, double.infinity);

    if ((windowX - dockedX).abs() <= snapRange && windowX != dockedX) {
      windowX = dockedX;
    }
    resultX = windowX;
  }
}

/// 复刻「用户按住宠物时，惯性 / 吸附动画还在跑」这条对抗场景。
///
/// 复刻的关键平台事实：Android 的 `cancel()` 会**先**回调 onAnimationCancel、
/// **再**回调 onAnimationEnd。旧实现没有区分二者，于是"用户按住宠物 → 取消动画"
/// 这条路径上，落位动画照样被启动，宠物在新手势进行中自己往边缘滑。
class _FlingVsTouchSim {
  _FlingVsTouchSim({
    required this.windowX,
    required this.snapTargetX,
    this.guardAgainstCancel = true,
    this.guardSingleWriter = true,
  });

  double windowX;

  /// 落位动画的目标 X（宠物会自己往这里滑）
  final double snapTargetX;

  /// 是否区分"被取消"与"播完"（新实现才有）
  final bool guardAgainstCancel;

  /// 手指按着时动画器是否还写窗口坐标（新实现才有）
  final bool guardSingleWriter;

  /// 手指是否按着
  bool touchDown = false;

  /// 是否已启动落位动画
  bool settleStarted = false;

  /// cancel()：Android 会先回调 onAnimationCancel，再回调 onAnimationEnd
  void cancel() {
    final cancelled = true;
    onAnimationEnd(cancelled: cancelled);
  }

  void onAnimationEnd({required bool cancelled}) {
    if (guardAgainstCancel && cancelled) return;
    settleStarted = true;
  }

  /// 动画的逐帧更新
  void update(double f) {
    if (guardSingleWriter && touchDown) return;
    windowX = windowX + (snapTargetX - windowX) * f;
  }
}

/// 提取动画器监听器里 `onAnimationEnd` 的方法体（按花括号配平）。
///
/// Android 在 `cancel()` 时会**先**回调 onAnimationCancel、**再**回调 onAnimationEnd，
/// 所以这里必须能单独把 onAnimationEnd 的body抠出来检查它有没有"被取消就跳过"的守卫。
String _onAnimationEndBody(String source) {
  const marker = 'override fun onAnimationEnd(animation: Animator)';
  final start = source.indexOf(marker);
  if (start < 0) {
    fail('未找到: $marker');
  }
  final open = source.indexOf('{', start);
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
  fail('onAnimationEnd 的花括号不配平');
}

/// 复刻两种拖拽算法，跑同一串手指轨迹，看窗口最后停在哪。
///
/// 复刻的关键平台事实有两个：
///   ① `updateViewLayout` 是**跨进程异步**的 —— 我们请求的新位置要等下一帧的
///      traversal 才真正生效，所以同一帧里再来 MOVE 事件时，
///      窗口的**真实**位置还是旧的；
///   ② 事件里的局部坐标（event.x）是相对窗口**真实**位置算出来的。
///
/// 于是：
///   mode = 'local' → v8 算法：finger = params.x（我们**请求**的位置） + event.x（相对**真实**位置）
///                     两者差着一整帧的窗口位移 → 算出来的手指位置凭空多出一截
///                     → 窗口每帧往前冲一截 = **拖拽乱飞**
///   mode = 'raw'   → v10 算法：finger = raw 坐标（输入管线的屏幕绝对坐标）
///                     完全不受窗口什么时候真正挪过去的影响 → 窗口与手指始终 1:1
class _DragAlgoSim {
  _DragAlgoSim({
    required this.mode,
    required this.startWindowX,
    required this.windowSize,
    required this.screenWidth,
    required this.startFingerX,
  });

  /// 'raw' 或 'local'
  final String mode;
  final double startWindowX;
  final double windowSize;
  final double screenWidth;
  final double startFingerX;

  /// 窗口**真实**位置（系统那边已生效的）
  double actualX = 0;

  /// 我们**请求**的位置（params.x）
  double requestedX = 0;

  double initialX = 0;
  double initialFingerX = 0;

  void begin() {
    actualX = startWindowX;
    requestedX = startWindowX;
    initialX = startWindowX;
    initialFingerX = startFingerX;
  }

  /// 手指移动到屏幕位置 [fingerX]（真值）
  void moveFingerTo(double fingerX) {
    final localX = fingerX - actualX; // 事件里的局部坐标：相对窗口真实位置
    final computed = mode == 'raw' ? fingerX : requestedX + localX;
    final wanted = initialX + (computed - initialFingerX);
    final maxX = (screenWidth - windowSize).clamp(0.0, double.infinity);
    requestedX = wanted.clamp(0.0, maxX);
  }

  /// 一帧结束：traversal 生效，窗口真实位置追上我们请求的位置
  void advanceFrame() {
    actualX = requestedX;
  }
}

/// 复刻 computeBubblePosition 的水平摆放规则。
///
/// 气泡比猫宽得多（猫 82dp，气泡最多 200dp），
/// 一律"与猫居中对齐"再被屏幕边界钳一下，气泡就会被推离猫很远。
/// 正确做法是：居中放不下时**贴着猫的那一侧**摆。
class _BubbleSim {
  _BubbleSim({
    required this.screenWidth,
    required this.catWidth,
    required this.bubbleWidth,
    required this.density,
  });

  final double screenWidth;
  final double catWidth;
  final double bubbleWidth;
  final double density;

  /// 猫所在窗口的 x
  double catWindowX = 0;

  /// 猫的绘制偏移（探头 / 拖出屏幕时，猫画在窗口之外）
  double peekOffsetX = 0;

  double get catLeft => catWindowX + peekOffsetX;
  double get catRight => catLeft + catWidth;
  double get catCenter => catLeft + catWidth / 2;

  /// 气泡左边缘的最终位置
  double place() {
    final minX = 10 * density;
    final maxX =
        (screenWidth - bubbleWidth - 10 * density).clamp(minX, double.infinity);
    final centered = catCenter - bubbleWidth / 2;
    if (centered >= minX && centered <= maxX) return centered;
    if (catCenter < screenWidth / 2) {
      return catLeft.clamp(minX, maxX);
    }
    return (catRight - bubbleWidth).clamp(minX, maxX);
  }

  /// 气泡右边缘与猫右边缘的距离（越小越贴）
  double rightEdgeGap() => (place() + bubbleWidth) - catRight;

  /// 气泡与猫在水平方向是否还有重叠
  bool overlapsCat() {
    final left = place();
    return left < catRight && (left + bubbleWidth) > catLeft;
  }
}

/// 模拟「悬浮窗帧 ↔ 可触达区域（Touchable Region）」的关系。
///
/// 复刻的平台规则（WMS 的真实行为）：
///
///   1. 视图不可见时，可触达区域一律作废 —— 触摸根本进不来；
///   2. 视图可见时，可触达区域**只在窗口帧发生变化**的那一刻才会被重算；
///      帧没变就不重算，旧的（可能已经失效的）区域会被保留下来。
///
/// 这两条规则合起来，就是「第一次能拖，打开关闭 app 之后就拖不动」的机制：
/// 旧做法用 View.GONE 隐藏（帧没变），恢复时区域算不出来 → 看不见但按不动。
class _OverlayFrameSim {
  _OverlayFrameSim(this.petSize);

  /// 宠物的真实边长（像素）
  final int petSize;

  /// 窗口当前帧（宽 = 高）
  int width = 0;
  int height = 0;

  /// 视图当前是否可见
  bool viewVisible = false;

  /// WMS 手里那个可触达区域的边长
  int touchableRegion = 0;

  /// 真正送达窗口的按下次数
  int touchDownCount = 0;

  /// 把窗口尺寸改成 [size] 并提交给 WMS（相当于 updateViewLayout）。
  ///
  /// [visible] 为 false 时走"视图不可见 → 区域作废"；
  /// 为 true 时，只有帧真的变了才会重算区域。
  void applyFrame(int size, {required bool visible}) {
    final frameChanged = width != size || height != size;
    width = size;
    height = size;
    viewVisible = visible;
    if (!visible) {
      touchableRegion = 0;
    } else if (frameChanged) {
      touchableRegion = size;
    }
  }

  /// 旧做法：隐藏 = View.GONE（帧不动）
  void hideWithGoneToggle() {
    viewVisible = false;
    touchableRegion = 0;
  }

  /// 旧做法：恢复 = View.VISIBLE（帧不动 → WMS 不重算区域）
  void showWithGoneToggle() {
    viewVisible = true;
  }

  /// 新做法：隐藏时把窗口缩到 1x1 —— **帧变了**
  void hideWithFrameChange() {
    applyFrame(1, visible: false);
  }

  /// 新做法：恢复时把窗口撑回满尺寸 —— **帧变了**
  void showWithFrameChange() {
    applyFrame(petSize, visible: true);
  }

  /// 手指按在宠物身上
  void fingerDown() {
    if (viewVisible && touchableRegion >= petSize) {
      touchDownCount++;
    }
  }
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

/// 解析 Dart 端 `PetModel.availableSkins` 的皮肤配色表。
///
/// 返回 品种 id -> [主体色, 辅助色, 眼睛色]（大写十六进制，不含 0x 前缀）。
Map<String, List<String>> _parseDartSkinTable(String source) {
  final out = <String, List<String>>{};
  // 以条目起点切分：'cat_xxx': SkinConfig(
  final chunks = source.split(RegExp(r"'cat_[a-z_]+':\s*SkinConfig\("));
  for (var i = 1; i < chunks.length; i++) {
    final chunk = chunks[i];
    final idM = RegExp(r"id:\s*'(cat_[a-z_]+)'").firstMatch(chunk);
    final pM = RegExp(r'primaryColor:\s*0x([0-9A-Fa-f]{8})').firstMatch(chunk);
    final sM =
        RegExp(r'secondaryColor:\s*0x([0-9A-Fa-f]{8})').firstMatch(chunk);
    final eM = RegExp(r'eyeColor:\s*0x([0-9A-Fa-f]{8})').firstMatch(chunk);
    if (idM == null || pM == null || sM == null || eM == null) continue;
    out[idM.group(1)!] = <String>[
      pM.group(1)!.substring(2).toUpperCase(),
      sM.group(1)!.substring(2).toUpperCase(),
      eM.group(1)!.substring(2).toUpperCase(),
    ];
  }
  return out;
}

/// 解析 Kotlin 端 `skinPaletteOf()` 的皮肤配色表。
///
/// 表项形如：
/// ```
/// "cat_ragdoll" -> SkinPalette(
///     Color.parseColor("#FFFDF8"),  // 主体色
///     Color.parseColor("#8E9AAF"),  // 辅助色
///     Color.parseColor("#64748B"),  // 深色斑块（原生侧独有）
///     Color.parseColor("#0284C7"),  // 眼睛色
/// )
/// ```
///
/// 返回 品种 id -> [主体色, 辅助色, 眼睛色]，与 [_parseDartSkinTable] 同构。
Map<String, List<String>> _parseKotlinSkinPalette(String source) {
  final out = <String, List<String>>{};
  final declRe = RegExp(r'"(cat_[a-z_]+)"\s*->\s*SkinPalette\(');
  for (final m in declRe.allMatches(source)) {
    final openIdx = source.indexOf('(', m.end - 1);
    if (openIdx < 0) continue;
    final closeIdx = _matchParen(source, openIdx);
    if (closeIdx < 0) continue;
    final body = source.substring(openIdx + 1, closeIdx);
    final colors = RegExp(r'#([0-9A-Fa-f]{6})')
        .allMatches(body)
        .map((c) => c.group(1)!.toUpperCase())
        .toList();
    if (colors.length != 4) continue;
    out[m.group(1)!] = <String>[colors[0], colors[1], colors[3]];
  }
  return out;
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

/// 找出「可空回调被直接传给 Handler/View 的回调方法」的空安全问题。
///
/// Android SDK 里 `Handler.removeCallbacks(Runnable)` / `postDelayed(Runnable, long)`
/// 的参数声明为**非空**，把可空变量直接塞进去就是编译错误：
/// `Argument type mismatch: actual type is 'Runnable?', but 'Runnable' was expected.`
///
/// 本机没有 android.jar 时 kotlinc 无法区分宿主类成员的真实签名（宿主类连同它的成员
/// 一起 unresolved），所以这类问题本地永远查不出来，只有 CI 能炸出来。
/// 这里用源码断言提前拦，别再拿一次 CI 往返去换一条编译错误。
List<String> _findNullableCallbackArgs(String source) {
  final problems = <String>[];

  // 1. 找出声明为可空的 Runnable 变量（成员与局部都算）
  final nullableNames = <String>{};
  for (final m
      in RegExp(r'\b(?:var|val)\s+(\w+)\s*:\s*Runnable\?\s*=').allMatches(source)) {
    nullableNames.add(m.group(1)!);
  }
  if (nullableNames.isEmpty) return problems;

  // 2. 检查这些名字有没有被直接塞进回调方法
  for (final name in nullableNames) {
    // 后面紧跟 "!!" 才算显式收窄；
    // "name?.let { handler.removeCallbacks(it) }" 里的实参是 it，天然匹配不到。
    final re = RegExp(r'\b(?:removeCallbacks|postDelayed)\(\s*' + name + r'\b(?!\s*!)');
    for (final _ in re.allMatches(source)) {
      problems.add('$name 被直接传给回调方法（应写成 $name!! 或 $name?.let { ... }）');
    }
  }
  return problems;
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
