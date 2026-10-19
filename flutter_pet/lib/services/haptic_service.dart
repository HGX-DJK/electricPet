import 'package:flutter/services.dart';

/// 移动端线性马达与多阶沉浸触觉反馈服务
class HapticService {
  static bool enabled = true;

  /// 按键与轻量点选触感 (Selection Click)
  static Future<void> selection() async {
    if (!enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// 灵动轻触 (摸头初触、选项切换)
  static Future<void> light() async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// 沉钝中度触感 (弹跳着地、投喂咀嚼)
  static Future<void> medium() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// 重度冲击感 (眩晕摇晃达标、重大升级)
  static Future<void> heavy() async {
    if (!enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// 摸头/挠下巴喉腔微震仿真 (Purr ASMR Haptic)
  static Future<void> purrHaptic() async {
    if (!enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// 盲盒爆出 SSR / UR 绝品神装的三连欢庆脉冲震动
  static Future<void> jackpotHaptic() async {
    if (!enabled) return;
    try {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 120));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 140));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
