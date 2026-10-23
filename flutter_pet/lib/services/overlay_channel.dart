/// Dart 端与原生端共享的 MethodChannel 协议常量。
///
/// 背景：此前通道名、方法名、参数名全部在两端手写字符串，没有任何约束，
/// 改错一边只能靠人肉发现 (例如新增 `updateFloatingPet` 时就存在失配风险)。
///
/// 约定：任何一侧新增 / 改名方法或参数，都必须同步另一侧。
/// `flutter_pet/test/floating_overlay_native_test.dart` 会逐项比对两端的常量表，
/// 不一致时 CI 直接变红。
class OverlayChannel {
  OverlayChannel._();

  /// 通道名
  static const String name = 'com.electricpet.poko/overlay';

  // ---------- 方法名 ----------

  /// 检查是否拥有悬浮窗权限
  static const String checkOverlayPermission = 'checkOverlayPermission';

  /// 跳转系统设置申请悬浮窗权限
  static const String requestOverlayPermission = 'requestOverlayPermission';

  /// 启动桌面悬浮宠服务
  static const String startFloatingService = 'startFloatingService';

  /// 停止桌面悬浮宠服务
  static const String stopFloatingService = 'stopFloatingService';

  /// 把最新外观配置实时推给运行中的悬浮宠 (切换品种 / 改名)
  static const String updateFloatingPet = 'updateFloatingPet';

  /// 悬浮宠服务是否正在运行
  static const String isFloatingServiceRunning = 'isFloatingServiceRunning';

  /// 申请 Android 13+ 通知权限 (前台服务通知需要)
  static const String requestNotificationPermission = 'requestNotificationPermission';

  /// 检查是否拥有存储权限
  static const String checkStoragePermission = 'checkStoragePermission';

  /// 申请存储权限
  static const String requestStoragePermission = 'requestStoragePermission';

  /// 写入公共存储备份
  static const String writePublicBackup = 'writePublicBackup';

  /// 读取公共存储备份
  static const String readPublicBackup = 'readPublicBackup';

  /// 读取桌面悬浮宠设置 (大小 / 透明度 / 行为开关)
  static const String getOverlaySettings = 'getOverlaySettings';

  /// 更新桌面悬浮宠设置 (服务运行中会立即生效)
  static const String updateOverlaySettings = 'updateOverlaySettings';

  // ---------- 参数名 ----------

  /// 皮肤 / 品种 ID
  static const String argSkinId = 'skinId';

  /// 宠物名字
  static const String argPetName = 'petName';

  /// 昼夜状态：App 按真实太阳节律算好后推给桌面悬浮宠
  static const String argNightMode = 'nightMode';

  /// 设置项集合
  static const String argSettings = 'settings';

  // ---------- 设置项字段名 (与原生 OverlaySettings 字段一一对应) ----------
  static const String argSettingSizeDp = 'sizeDp';
  static const String argSettingOpacity = 'opacity';
  static const String argSettingPeeking = 'peeking';
  static const String argSettingStrolling = 'strolling';
  static const String argSettingAutoChat = 'autoChat';
  static const String argSettingEdgeSnap = 'edgeSnap';

  // ---------- 供守护测试比对的完整清单 ----------

  /// 全部方法名 (常量名 -> 方法名)，必须与 Kotlin 侧 `OverlayChannel.ALL_METHODS` 逐项一致
  static const Map<String, String> allMethods = {
    'CHECK_OVERLAY_PERMISSION': 'checkOverlayPermission',
    'REQUEST_OVERLAY_PERMISSION': 'requestOverlayPermission',
    'START_FLOATING_SERVICE': 'startFloatingService',
    'STOP_FLOATING_SERVICE': 'stopFloatingService',
    'UPDATE_FLOATING_PET': 'updateFloatingPet',
    'IS_FLOATING_SERVICE_RUNNING': 'isFloatingServiceRunning',
    'REQUEST_NOTIFICATION_PERMISSION': 'requestNotificationPermission',
    'CHECK_STORAGE_PERMISSION': 'checkStoragePermission',
    'REQUEST_STORAGE_PERMISSION': 'requestStoragePermission',
    'WRITE_PUBLIC_BACKUP': 'writePublicBackup',
    'READ_PUBLIC_BACKUP': 'readPublicBackup',
    'GET_OVERLAY_SETTINGS': 'getOverlaySettings',
    'UPDATE_OVERLAY_SETTINGS': 'updateOverlaySettings',
  };

  /// 全部参数名 (常量名 -> 参数名)，必须与 Kotlin 侧 `OverlayChannel.ALL_ARGS` 逐项一致
  static const Map<String, String> allArgs = {
    'ARG_SKIN_ID': 'skinId',
    'ARG_PET_NAME': 'petName',
    'ARG_NIGHT_MODE': 'nightMode',
    'ARG_SETTINGS': 'settings',
    'ARG_SETTING_SIZE_DP': 'sizeDp',
    'ARG_SETTING_OPACITY': 'opacity',
    'ARG_SETTING_PEEKING': 'peeking',
    'ARG_SETTING_STROLLING': 'strolling',
    'ARG_SETTING_AUTO_CHAT': 'autoChat',
    'ARG_SETTING_EDGE_SNAP': 'edgeSnap',
  };
}
