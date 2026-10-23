package com.electricpet.poko

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = OverlayChannel.NAME

    /** 通知权限申请的结果回调 (Android 13+ 前台服务通知需要) */
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun getRenderMode(): RenderMode = RenderMode.texture

    private companion object {
        /** 通知权限申请的 requestCode */
        const val REQUEST_NOTIFICATION_PERMISSION_CODE = 2002
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // 小窝在前台时让桌面悬浮猫暂时隐身，避免与 App 内的同一只波可重叠成两只
        FloatingPetService.notifyAppForegroundChanged(true)
    }

    override fun onPause() {
        FloatingPetService.notifyAppForegroundChanged(false)
        super.onPause()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATION_PERMISSION_CODE) {
            val granted = grantResults.isNotEmpty() &&
                (grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED)
            pendingNotificationPermissionResult?.success(granted)
            pendingNotificationPermissionResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                OverlayChannel.CHECK_OVERLAY_PERMISSION -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                OverlayChannel.REQUEST_OVERLAY_PERMISSION -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(true)
                }
                OverlayChannel.START_FLOATING_SERVICE -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(false)
                    } else {
                        val intent = Intent(this, FloatingPetService::class.java).apply {
                            putExtra(OverlayChannel.ARG_SKIN_ID, call.argument<String>(OverlayChannel.ARG_SKIN_ID))
                            putExtra(OverlayChannel.ARG_PET_NAME, call.argument<String>(OverlayChannel.ARG_PET_NAME))
                            // 昼夜状态：App 按真实太阳节律算好后推过来，桌面猫一开始就配上对应配色
                            call.argument<Boolean>(OverlayChannel.ARG_NIGHT_MODE)?.let {
                                putExtra(OverlayChannel.ARG_NIGHT_MODE, it)
                            }
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                }
                OverlayChannel.STOP_FLOATING_SERVICE -> {
                    val intent = Intent(this, FloatingPetService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                OverlayChannel.UPDATE_FLOATING_PET -> {
                    // 悬浮服务运行中时，把最新外观配置推给它实时换品种
                    if (FloatingPetService.isRunning) {
                        val intent = Intent(this, FloatingPetService::class.java).apply {
                            putExtra(OverlayChannel.ARG_SKIN_ID, call.argument<String>(OverlayChannel.ARG_SKIN_ID))
                            putExtra(OverlayChannel.ARG_PET_NAME, call.argument<String>(OverlayChannel.ARG_PET_NAME))
                            // 昼夜状态：App 按真实太阳节律算好后推过来，桌面猫跟着换配色
                            call.argument<Boolean>(OverlayChannel.ARG_NIGHT_MODE)?.let {
                                putExtra(OverlayChannel.ARG_NIGHT_MODE, it)
                            }
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                OverlayChannel.REQUEST_NOTIFICATION_PERMISSION -> {
                    // Android 13+ 必须运行时申请通知权限, 否则前台服务通知不显示,
                    // 用户看不到"悬浮宠正在运行", 点通知回小窝的入口也会失效
                    val needsRequest = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED
                    } else {
                        false
                    }
                    if (needsRequest) {
                        // 上一次申请还没回调就先应答掉, 避免连点时 Dart 侧的 Future 永久挂起
                        pendingNotificationPermissionResult?.success(false)
                        // 结果在 onRequestPermissionsResult 里异步回传
                        pendingNotificationPermissionResult = result
                        requestPermissions(
                            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                            REQUEST_NOTIFICATION_PERMISSION_CODE
                        )
                    } else {
                        result.success(true)
                    }
                }
                OverlayChannel.IS_FLOATING_SERVICE_RUNNING -> {
                    result.success(FloatingPetService.isRunning)
                }
                OverlayChannel.GET_OVERLAY_SETTINGS -> {
                    val s = FloatingPetService.readSettings(this)
                    result.success(
                        mapOf(
                            OverlayChannel.ARG_SETTING_SIZE_DP to s.sizeDp,
                            OverlayChannel.ARG_SETTING_OPACITY to s.opacity.toDouble(),
                            OverlayChannel.ARG_SETTING_PEEKING to s.peeking,
                            OverlayChannel.ARG_SETTING_STROLLING to s.strolling,
                            OverlayChannel.ARG_SETTING_AUTO_CHAT to s.autoChat,
                            OverlayChannel.ARG_SETTING_EDGE_SNAP to s.edgeSnap,
                        )
                    )
                }
                OverlayChannel.UPDATE_OVERLAY_SETTINGS -> {
                    val raw = call.argument<Map<String, Any?>>(OverlayChannel.ARG_SETTINGS) ?: emptyMap()
                    val current = FloatingPetService.readSettings(this)
                    val updated = current.copy(
                        sizeDp = (raw[OverlayChannel.ARG_SETTING_SIZE_DP] as? Number)?.toInt() ?: current.sizeDp,
                        opacity = (raw[OverlayChannel.ARG_SETTING_OPACITY] as? Number)?.toFloat() ?: current.opacity,
                        peeking = raw[OverlayChannel.ARG_SETTING_PEEKING] as? Boolean ?: current.peeking,
                        strolling = raw[OverlayChannel.ARG_SETTING_STROLLING] as? Boolean ?: current.strolling,
                        autoChat = raw[OverlayChannel.ARG_SETTING_AUTO_CHAT] as? Boolean ?: current.autoChat,
                        edgeSnap = raw[OverlayChannel.ARG_SETTING_EDGE_SNAP] as? Boolean ?: current.edgeSnap,
                    )
                    val service = FloatingPetService.instance
                    if (service != null) {
                        // 服务正在运行：立刻生效
                        service.applySettingsFromChannel(updated)
                    } else {
                        // 服务没运行：先持久化，下次启动自动套用
                        FloatingPetService.writeSettings(this, updated)
                    }
                    result.success(true)
                }
                OverlayChannel.CHECK_STORAGE_PERMISSION -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(Environment.isExternalStorageManager())
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val granted = checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                OverlayChannel.REQUEST_STORAGE_PERMISSION -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        if (!Environment.isExternalStorageManager()) {
                            try {
                                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                    data = Uri.parse("package:$packageName")
                                }
                                startActivity(intent)
                            } catch (e: Exception) {
                                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                                startActivity(intent)
                            }
                        }
                        result.success(true)
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        requestPermissions(
                            arrayOf(
                                android.Manifest.permission.READ_EXTERNAL_STORAGE,
                                android.Manifest.permission.WRITE_EXTERNAL_STORAGE
                            ),
                            2001
                        )
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                OverlayChannel.WRITE_PUBLIC_BACKUP -> {
                    val content = call.argument<String>("content") ?: ""
                    var written = false
                    try {
                        val dirs = mutableListOf<File>()
                        // 1. Download/ElectricPet
                        val downloadDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "ElectricPet")
                        dirs.add(downloadDir)
                        // 2. Documents/ElectricPet
                        val docDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS), "ElectricPet")
                        dirs.add(docDir)
                        // 3. App-specific external storage (survives app updates)
                        getExternalFilesDir(null)?.let { dirs.add(it) }

                        for (dir in dirs) {
                            try {
                                if (!dir.exists()) {
                                    dir.mkdirs()
                                }
                                val file = File(dir, "poko_backup.json")
                                file.writeText(content, Charsets.UTF_8)
                                written = true
                            } catch (_: Exception) {}
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(written)
                }
                OverlayChannel.READ_PUBLIC_BACKUP -> {
                    var readContent: String? = null
                    try {
                        val dirs = mutableListOf<File>()
                        val downloadDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "ElectricPet")
                        dirs.add(downloadDir)
                        val docDir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS), "ElectricPet")
                        dirs.add(docDir)
                        getExternalFilesDir(null)?.let { dirs.add(it) }

                        for (dir in dirs) {
                            try {
                                val file = File(dir, "poko_backup.json")
                                if (file.exists() && file.length() > 0) {
                                    readContent = file.readText(Charsets.UTF_8)
                                    if (readContent.isNotBlank()) {
                                        break
                                    }
                                }
                            } catch (_: Exception) {}
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(readContent)
                }
                else -> result.notImplemented()
            }
        }
    }
}
