import 'package:flutter/services.dart';

import '../models/overlay_settings.dart';
import 'overlay_channel.dart';

/// Android 原生悬浮窗与系统交互通道服务
class OverlayService {
  static const MethodChannel _channel = MethodChannel(OverlayChannel.name);

  /// 检查是否拥有悬浮窗权限 (SYSTEM_ALERT_WINDOW)
  static Future<bool> checkPermission() async {
    try {
      final bool hasPerm =
          await _channel.invokeMethod(OverlayChannel.checkOverlayPermission);
      return hasPerm;
    } catch (_) {
      return false;
    }
  }

  /// 请求系统弹出悬浮窗权限设置页
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod(OverlayChannel.requestOverlayPermission);
    } catch (_) {}
  }

  /// 申请 Android 13+ 通知权限 (前台服务通知需要, 拒绝后悬浮宠常驻通知不可见)
  /// 返回是否已授权
  static Future<bool> requestNotificationPermission() async {
    try {
      final bool? granted = await _channel
          .invokeMethod<bool>(OverlayChannel.requestNotificationPermission);
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 开启全局桌面悬浮宠
  ///
  /// [nightMode] 是 App 按真实太阳节律算出来的昼夜状态，
  /// 传过去可以让桌面上的波可一开始就配上对应的夜间/日间配色。
  static Future<bool> startFloatingPet({
    String? skinId,
    String? petName,
    bool? nightMode,
  }) async {
    try {
      final bool res = await _channel.invokeMethod(OverlayChannel.startFloatingService, {
        OverlayChannel.argSkinId: skinId,
        OverlayChannel.argPetName: petName,
        OverlayChannel.argNightMode: nightMode,
      });
      return res;
    } catch (_) {
      return false;
    }
  }

  /// 关闭全局桌面悬浮宠
  static Future<void> stopFloatingPet() async {
    try {
      await _channel.invokeMethod(OverlayChannel.stopFloatingService);
    } catch (_) {}
  }

  /// 把最新的外观配置实时同步给正在运行的桌面悬浮宠 (切换品种/改名后立即生效)
  /// 悬浮服务未运行时返回 false，不会误启动服务
  ///
  /// [nightMode] 是 App 按真实太阳节律算出来的昼夜状态：
  /// 桌面上的波可据此切换夜间配色，深夜不再亮得刺眼。
  static Future<bool> updateFloatingPet({
    String? skinId,
    String? petName,
    bool? nightMode,
  }) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>(
        OverlayChannel.updateFloatingPet,
        {
          OverlayChannel.argSkinId: skinId,
          OverlayChannel.argPetName: petName,
          OverlayChannel.argNightMode: nightMode,
        },
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 检查悬浮窗是否正在运行
  static Future<bool> isRunning() async {
    try {
      final bool running =
          await _channel.invokeMethod(OverlayChannel.isFloatingServiceRunning);
      return running;
    } catch (_) {
      return false;
    }
  }

  /// 读取桌面悬浮宠设置（悬浮服务未运行时也能读取已保存的设置）
  static Future<OverlaySettings> getSettings() async {
    try {
      final Map<Object?, Object?>? raw =
          await _channel.invokeMethod<Map<Object?, Object?>>(
        OverlayChannel.getOverlaySettings,
      );
      return OverlaySettings.fromMap(raw ?? const <Object?, Object?>{});
    } catch (_) {
      return const OverlaySettings();
    }
  }

  /// 更新桌面悬浮宠设置（服务运行中会立即生效，未运行则下次启动套用）
  static Future<bool> updateSettings(OverlaySettings settings) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>(
        OverlayChannel.updateOverlaySettings,
        {OverlayChannel.argSettings: settings.toMap()},
      );
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
