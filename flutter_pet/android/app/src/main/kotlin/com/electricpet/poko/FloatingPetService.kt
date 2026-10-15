package com.electricpet.poko

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.ImageView
import android.widget.Toast
import kotlin.math.abs

class FloatingPetService : Service() {

    private var windowManager: WindowManager? = null
    private var floatingView: View? = null

    companion object {
        var isRunning = false
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val density = resources.displayMetrics.density
        val sizePx = (72 * density).toInt()

        val params = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (resources.displayMetrics.widthPixels - sizePx - (16 * density).toInt())
            y = (resources.displayMetrics.heightPixels * 0.45).toInt()
        }

        val imageView = ImageView(this).apply {
            setImageResource(R.mipmap.ic_launcher)
            scaleType = ImageView.ScaleType.FIT_CENTER
            contentDescription = "波可桌面悬浮萌宠"
        }

        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isClick = false

        imageView.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isClick = true
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (abs(dx) > 10 || abs(dy) > 10) {
                        isClick = false
                    }
                    params.x = initialX + dx
                    params.y = initialY + dy
                    windowManager?.updateViewLayout(imageView, params)
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (isClick) {
                        // 点击悬浮猫咪轻微震动与萌宠问候
                        vibrate()
                        val greetings = listOf(
                            "喵呜~ 主人，波可随时在手机屏幕上陪着您呢！(ฅ'ω'ฅ)",
                            "咕噜咕噜... 戳戳小肚腩好舒服~ 💕",
                            "主人看屏幕累了吗？眨眨眼休息一下吧！✨",
                            "双击我或者点击通知可随时返回小窝哦！🐾"
                        )
                        Toast.makeText(this@FloatingPetService, greetings.random(), Toast.LENGTH_SHORT).show()
                    }
                    true
                }
                else -> false
            }
        }

        floatingView = imageView
        try {
            windowManager?.addView(floatingView, params)
            Toast.makeText(this, "🐾 桌面悬浮宠已启动！波可已常驻在屏幕边缘~", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }

    private fun vibrate() {
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(45, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(45)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        floatingView?.let {
            try {
                windowManager?.removeView(it)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        floatingView = null
        Toast.makeText(this, "桌面悬浮宠已收回小窝~", Toast.LENGTH_SHORT).show()
    }
}
