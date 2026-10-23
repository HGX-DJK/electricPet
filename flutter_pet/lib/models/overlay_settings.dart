import '../services/overlay_channel.dart';

/// 桌面悬浮宠设置（大小 / 透明度 / 行为开关）。
///
/// 与原生侧 `OverlaySettings` 一一对应，字段名同时也是 MethodChannel 传输的键名，
/// 两端必须保持一致（守护测试会逐项比对协议常量表）。
class OverlaySettings {
  /// 悬浮宠尺寸（dp），对应原生窗口宽度/高度
  final int sizeDp;

  /// 不透明度 0.35 ~ 1.0
  final double opacity;

  /// 闲置时是否探头避让
  final bool peeking;

  /// 是否自主在屏幕边缘散步
  final bool strolling;

  /// 是否主动搭话（长时间没人理时自己冒泡）
  final bool autoChat;

  /// 松手时是否磁吸贴边（关闭则任何位置都自由停留）
  final bool edgeSnap;

  const OverlaySettings({
    this.sizeDp = 82,
    this.opacity = 1.0,
    this.peeking = true,
    this.strolling = true,
    this.autoChat = true,
    this.edgeSnap = true,
  });

  /// 从原生返回的 Map 解析（缺字段时回落到默认值）
  factory OverlaySettings.fromMap(Map<Object?, Object?> raw) {
    return OverlaySettings(
      sizeDp: (raw[OverlayChannel.argSettingSizeDp] as num?)?.toInt() ?? 82,
      opacity: (raw[OverlayChannel.argSettingOpacity] as num?)?.toDouble() ?? 1.0,
      peeking: raw[OverlayChannel.argSettingPeeking] as bool? ?? true,
      strolling: raw[OverlayChannel.argSettingStrolling] as bool? ?? true,
      autoChat: raw[OverlayChannel.argSettingAutoChat] as bool? ?? true,
      edgeSnap: raw[OverlayChannel.argSettingEdgeSnap] as bool? ?? true,
    );
  }

  /// 转成 MethodChannel 传输用的 Map
  Map<String, dynamic> toMap() {
    return {
      OverlayChannel.argSettingSizeDp: sizeDp,
      OverlayChannel.argSettingOpacity: opacity,
      OverlayChannel.argSettingPeeking: peeking,
      OverlayChannel.argSettingStrolling: strolling,
      OverlayChannel.argSettingAutoChat: autoChat,
      OverlayChannel.argSettingEdgeSnap: edgeSnap,
    };
  }

  OverlaySettings copyWith({
    int? sizeDp,
    double? opacity,
    bool? peeking,
    bool? strolling,
    bool? autoChat,
    bool? edgeSnap,
  }) {
    return OverlaySettings(
      sizeDp: sizeDp ?? this.sizeDp,
      opacity: opacity ?? this.opacity,
      peeking: peeking ?? this.peeking,
      strolling: strolling ?? this.strolling,
      autoChat: autoChat ?? this.autoChat,
      edgeSnap: edgeSnap ?? this.edgeSnap,
    );
  }

  /// 预设尺寸档位（与原生 MIN/MAX 范围对齐）
  static const List<int> sizePresets = <int>[60, 82, 110];
}
