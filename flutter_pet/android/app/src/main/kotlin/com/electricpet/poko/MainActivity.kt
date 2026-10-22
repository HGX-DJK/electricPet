package com.electricpet.poko

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.electricpet.poko/overlay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(true)
                }
                "startFloatingService" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                        result.success(false)
                    } else {
                        val intent = Intent(this, FloatingPetService::class.java).apply {
                            putExtra("skinId", call.argument<String>("skinId"))
                            putExtra("petName", call.argument<String>("petName"))
                        }
                        startService(intent)
                        result.success(true)
                    }
                }
                "stopFloatingService" -> {
                    val intent = Intent(this, FloatingPetService::class.java)
                    stopService(intent)
                    result.success(true)
                }
                "isFloatingServiceRunning" -> {
                    result.success(FloatingPetService.isRunning)
                }
                "checkStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        result.success(Environment.isExternalStorageManager())
                    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val granted = checkSelfPermission(android.Manifest.permission.READ_EXTERNAL_STORAGE) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "requestStoragePermission" -> {
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
                "writePublicBackup" -> {
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
                "readPublicBackup" -> {
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
