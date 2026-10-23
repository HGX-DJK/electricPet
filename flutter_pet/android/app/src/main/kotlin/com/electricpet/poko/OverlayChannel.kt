package com.electricpet.poko

/**
 * Dart 端与原生端共享的 MethodChannel 协议常量。
 *
 * 背景：此前通道名、方法名、参数名全部在两端手写字符串，没有任何约束，
 * 改错一边只能靠人肉发现 (例如新增 `updateFloatingPet` 时就存在失配风险)。
 *
 * 约定：任何一侧新增 / 改名方法或参数，都必须同步另一侧。
 * `flutter_pet/test/floating_overlay_native_test.dart` 会逐项比对两端的常量表，
 * 不一致时 CI 直接变红。
 */
object OverlayChannel {

    /** 通道名 */
    const val NAME = "com.electricpet.poko/overlay"

    // ---------- 方法名 ----------

    /** 检查是否拥有悬浮窗权限 */
    const val CHECK_OVERLAY_PERMISSION = "checkOverlayPermission"

    /** 跳转系统设置申请悬浮窗权限 */
    const val REQUEST_OVERLAY_PERMISSION = "requestOverlayPermission"

    /** 启动桌面悬浮宠服务 */
    const val START_FLOATING_SERVICE = "startFloatingService"

    /** 停止桌面悬浮宠服务 */
    const val STOP_FLOATING_SERVICE = "stopFloatingService"

    /** 把最新外观配置实时推给运行中的悬浮宠 (切换品种 / 改名) */
    const val UPDATE_FLOATING_PET = "updateFloatingPet"

    /** 悬浮宠服务是否正在运行 */
    const val IS_FLOATING_SERVICE_RUNNING = "isFloatingServiceRunning"

    /** 申请 Android 13+ 通知权限 (前台服务通知需要) */
    const val REQUEST_NOTIFICATION_PERMISSION = "requestNotificationPermission"

    /** 检查是否拥有存储权限 */
    const val CHECK_STORAGE_PERMISSION = "checkStoragePermission"

    /** 申请存储权限 */
    const val REQUEST_STORAGE_PERMISSION = "requestStoragePermission"

    /** 写入公共存储备份 */
    const val WRITE_PUBLIC_BACKUP = "writePublicBackup"

    /** 读取公共存储备份 */
    const val READ_PUBLIC_BACKUP = "readPublicBackup"

    /** 读取桌面悬浮宠设置 (大小 / 透明度 / 行为开关) */
    const val GET_OVERLAY_SETTINGS = "getOverlaySettings"

    /** 更新桌面悬浮宠设置 (服务运行中会立即生效) */
    const val UPDATE_OVERLAY_SETTINGS = "updateOverlaySettings"

    /** 打开系统的小组件选择界面 (用于添加「波可桌面萌宠」桌面小组件) */
    const val OPEN_WIDGET_PICKER = "openWidgetPicker"

    // ---------- 参数名 ----------

    /** 皮肤 / 品种 ID */
    const val ARG_SKIN_ID = "skinId"

    /** 宠物名字 */
    const val ARG_PET_NAME = "petName"

    /** 昼夜状态：App 按真实太阳节律算好后推给桌面悬浮宠 */
    const val ARG_NIGHT_MODE = "nightMode"

    /** 设置项集合 */
    const val ARG_SETTINGS = "settings"

    // ---------- 设置项字段名 (与 Dart 端 OverlaySettings 字段一一对应) ----------
    const val ARG_SETTING_SIZE_DP = "sizeDp"
    const val ARG_SETTING_OPACITY = "opacity"
    const val ARG_SETTING_PEEKING = "peeking"
    const val ARG_SETTING_STROLLING = "strolling"
    const val ARG_SETTING_AUTO_CHAT = "autoChat"
    const val ARG_SETTING_EDGE_SNAP = "edgeSnap"

    // ---------- 供守护测试比对的完整清单 ----------

    /**
     * 全部方法名 (常量名 -> 方法名)。
     * Dart 端的 `OverlayChannel.allMethods` 必须与本表逐项一致。
     */
    val ALL_METHODS: Map<String, String> = mapOf(
        "CHECK_OVERLAY_PERMISSION" to CHECK_OVERLAY_PERMISSION,
        "REQUEST_OVERLAY_PERMISSION" to REQUEST_OVERLAY_PERMISSION,
        "START_FLOATING_SERVICE" to START_FLOATING_SERVICE,
        "STOP_FLOATING_SERVICE" to STOP_FLOATING_SERVICE,
        "UPDATE_FLOATING_PET" to UPDATE_FLOATING_PET,
        "IS_FLOATING_SERVICE_RUNNING" to IS_FLOATING_SERVICE_RUNNING,
        "REQUEST_NOTIFICATION_PERMISSION" to REQUEST_NOTIFICATION_PERMISSION,
        "CHECK_STORAGE_PERMISSION" to CHECK_STORAGE_PERMISSION,
        "REQUEST_STORAGE_PERMISSION" to REQUEST_STORAGE_PERMISSION,
        "WRITE_PUBLIC_BACKUP" to WRITE_PUBLIC_BACKUP,
        "READ_PUBLIC_BACKUP" to READ_PUBLIC_BACKUP,
        "GET_OVERLAY_SETTINGS" to GET_OVERLAY_SETTINGS,
        "UPDATE_OVERLAY_SETTINGS" to UPDATE_OVERLAY_SETTINGS,
        "OPEN_WIDGET_PICKER" to OPEN_WIDGET_PICKER,
    )

    /**
     * 全部参数名 (常量名 -> 参数名)。
     * Dart 端的 `OverlayChannel.allArgs` 必须与本表逐项一致。
     */
    val ALL_ARGS: Map<String, String> = mapOf(
        "ARG_SKIN_ID" to ARG_SKIN_ID,
        "ARG_PET_NAME" to ARG_PET_NAME,
        "ARG_NIGHT_MODE" to ARG_NIGHT_MODE,
        "ARG_SETTINGS" to ARG_SETTINGS,
        "ARG_SETTING_SIZE_DP" to ARG_SETTING_SIZE_DP,
        "ARG_SETTING_OPACITY" to ARG_SETTING_OPACITY,
        "ARG_SETTING_PEEKING" to ARG_SETTING_PEEKING,
        "ARG_SETTING_STROLLING" to ARG_SETTING_STROLLING,
        "ARG_SETTING_AUTO_CHAT" to ARG_SETTING_AUTO_CHAT,
        "ARG_SETTING_EDGE_SNAP" to ARG_SETTING_EDGE_SNAP,
    )
}
