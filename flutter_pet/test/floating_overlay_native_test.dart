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

    test('萌言萌语气泡窗口必须不可触摸，避免遮挡宠物与底层应用', () {
      final bubbleWindow = _layoutParamsBlock(serviceSource, 'bubbleParams = WindowManager.LayoutParams(');

      expect(bubbleWindow, contains('FLAG_NOT_TOUCHABLE'),
          reason: '气泡若可触摸会挡住宠物点击，也会吞掉底层应用的点击');
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

      expect(settle, contains('if (!isDockedAtEdge('),
          reason: '松手时必须先判断是否靠近边缘；未靠近时应原地停留，不能强制拉回屏幕边');
      expect(settle, contains('saveDockPreference(isLeftHalf, params.x, params.y)'),
          reason: '自由停留时必须保存当前落点，否则重启后又被拽回边缘');
    });

    test('拖拽释放必须走自由落位逻辑，而不是无条件磁吸贴边', () {
      final upBranch = _between(
        serviceSource,
        'MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL ->',
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
        'if (isClick && event.actionMasked',
      );

      expect(longPressBranch, contains('if (!hasDragged)'),
          reason: '长按分支必须只在「完全没有拖动」时才吞掉释放；否则「先按住半秒再拖」与「快速拖」结果不一致');
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
