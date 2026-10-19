import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// 移动端陀螺仪与重力传感器服务
/// 支持设备左右物理倾斜感知与摇晃检测 (Shake Detection)
class SensorService {
  static StreamSubscription<AccelerometerEvent>? _sub;
  static double _tiltX = 0.0; // 左右倾角: -1.0 (向左倾斜) ~ 1.0 (向右倾斜)
  static double get tiltX => _tiltX;

  static VoidCallback? onShake;
  static ValueChanged<double>? onTilt;

  // 摇晃检测加速度滑动窗口与阈值
  static double _lastX = 0.0;
  static double _lastY = 0.0;
  static double _lastZ = 0.0;
  static int _lastShakeTime = 0;
  static const double _shakeThreshold = 14.5; // 加速度突变阈值 (m/s^2)

  static bool _isRunning = false;
  static bool get isRunning => _isRunning;

  /// 启动传感器监听
  static void startListening() {
    if (_isRunning) return;
    try {
      _sub = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          _isRunning = true;
          // 1. 倾角计算 (X轴重力分量，通常在 -9.8 到 +9.8 之间)
          // 手机竖屏状态下，向右倾斜 event.x > 0，向左倾斜 event.x < 0
          final rawTilt = (event.x / 9.8).clamp(-1.0, 1.0);
          // 低通滤波平滑滤除手抖
          _tiltX = _tiltX * 0.75 + rawTilt * 0.25;
          if (_tiltX.abs() < 0.12) {
            _tiltX = 0.0; // 死区保护，直立时静止
          }
          onTilt?.call(_tiltX);

          // 2. 摇晃检测 (Shake Detection)
          final deltaX = (event.x - _lastX).abs();
          final deltaY = (event.y - _lastY).abs();
          final deltaZ = (event.z - _lastZ).abs();
          final totalDelta = deltaX + deltaY + deltaZ;

          _lastX = event.x;
          _lastY = event.y;
          _lastZ = event.z;

          final now = DateTime.now().millisecondsSinceEpoch;
          if (totalDelta > _shakeThreshold && (now - _lastShakeTime > 1200)) {
            _lastShakeTime = now;
            onShake?.call();
          }
        },
        onError: (_) {
          // 在无传感器设备 (如桌面 Windows/Linux 或模拟器) 静默优雅降级
          _isRunning = false;
        },
        cancelOnError: false,
      );
    } catch (_) {
      _isRunning = false;
    }
  }

  /// 停止监听
  static void stopListening() {
    _sub?.cancel();
    _sub = null;
    _isRunning = false;
    _tiltX = 0.0;
  }
}
