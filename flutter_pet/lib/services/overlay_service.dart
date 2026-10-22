import 'package:flutter/services.dart';

/// Android 原生悬浮窗与系统交互通道服务
class OverlayService {
  static const MethodChannel _channel = MethodChannel('com.electricpet.poko/overlay');

  /// 检查是否拥有悬浮窗权限 (SYSTEM_ALERT_WINDOW)
  static Future<bool> checkPermission() async {
    try {
      final bool hasPerm = await _channel.invokeMethod('checkOverlayPermission');
      return hasPerm;
    } catch (_) {
      return false;
    }
  }

  /// 请求系统弹出悬浮窗权限设置页
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }

  /// 开启全局桌面悬浮宠
  static Future<bool> startFloatingPet({String? skinId, String? petName}) async {
    try {
      final bool res = await _channel.invokeMethod('startFloatingService', {
        'skinId': skinId,
        'petName': petName,
      });
      return res;
    } catch (_) {
      return false;
    }
  }

  /// 关闭全局桌面悬浮宠
  static Future<void> stopFloatingPet() async {
    try {
      await _channel.invokeMethod('stopFloatingService');
    } catch (_) {}
  }

  /// 把最新的外观配置实时同步给正在运行的桌面悬浮宠（切换品种/改名后立即生效）
  /// 悬浮服务未运行时返回 false，不会误启动服务
  static Future<bool> updateFloatingPet({String? skinId, String? petName}) async {
    try {
      final bool? res = await _channel.invokeMethod<bool>('updateFloatingPet', {
        'skinId': skinId,
        'petName': petName,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 检查悬浮窗是否正在运行
  static Future<bool> isRunning() async {
    try {
      final bool running = await _channel.invokeMethod('isFloatingServiceRunning');
      return running;
    } catch (_) {
      return false;
    }
  }
}
