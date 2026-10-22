package com.electricpet.poko

import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.TextView
import android.widget.Toast
import org.json.JSONObject
import kotlin.math.abs

class FloatingPetService : Service() {

    private var windowManager: WindowManager? = null
    private var pokoView: PokoPetView? = null
    private var pokoParams: WindowManager.LayoutParams? = null

    // 专属悬浮对话气泡
    private var bubbleView: TextView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var hideBubbleRunnable: Runnable? = null

    // 双击与触控物理量
    private var lastClickTime: Long = 0
    private var edgeSnapAnimator: ValueAnimator? = null

    companion object {
        var isRunning = false
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        // 1. 尝试以轻量前台常驻服务运行，防系统在后台强杀，同时提供快捷返回小窝的常驻通知
        startAsForeground()

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val density = resources.displayMetrics.density
        val sizePx = (78 * density).toInt()

        // 2. 初始化悬浮猫咪窗口属性
        pokoParams = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (resources.displayMetrics.widthPixels - sizePx - (12 * density).toInt())
            y = (resources.displayMetrics.heightPixels * 0.45).toInt()
        }

        // 3. 构建原生高精度矢量动画猫咪 View
        pokoView = PokoPetView(this).apply {
            val (savedSkin, savedName) = loadSavedPetConfig()
            applyConfig(savedSkin, savedName)
            facingLeft = true // 初始停靠在右侧边缘，面向屏幕内
        }

        // 4. 构建桌面悬浮萌言萌语气泡 View
        initSpeechBubble(layoutType, density)

        // 5. 绑定触控、拖拽、果冻回弹挤压与智能贴边吸附事件
        setupTouchListener(sizePx, density)

        try {
            windowManager?.addView(pokoView, pokoParams)
            Toast.makeText(this, "🐾 波可已跃上手机桌面！拖动可自由挪动，轻戳可互动哦~", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val skinId = intent?.getStringExtra("skinId")
        val petName = intent?.getStringExtra("petName")
        if (!skinId.isNullOrBlank() || !petName.isNullOrBlank()) {
            pokoView?.applyConfig(skinId, petName)
        }
        return START_STICKY
    }

    private fun setupTouchListener(sizePx: Int, density: Float) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isClick = false

        pokoView?.setOnTouchListener { _, event ->
            val params = pokoParams ?: return@setOnTouchListener false
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    edgeSnapAnimator?.cancel()
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isClick = true
                    pokoView?.onDragStateChanged(false)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()
                    if (abs(dx) > 10 || abs(dy) > 10) {
                        isClick = false
                        pokoView?.onDragStateChanged(true)
                    }
                    params.x = initialX + dx
                    params.y = initialY + dy
                    try {
                        windowManager?.updateViewLayout(pokoView, params)
                        updateBubblePosition()
                    } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP -> {
                    pokoView?.onDragStateChanged(false)
                    if (isClick) {
                        val now = System.currentTimeMillis()
                        if (now - lastClickTime < 380) {
                            // 双击萌宠：震动反馈并极速拉起主应用返回小窝
                            vibrate(60)
                            openMainActivity()
                        } else {
                            // 单击萌宠：震动、果冻 Q 弹挤压物理动画、萌言萌语对话气泡
                            lastClickTime = now
                            vibrate(35)
                            pokoView?.onPetTapped()
                            showSpeechBubble()
                        }
                    } else {
                        // 拖拽释放后执行丝滑智能贴边
                        snapToEdge(sizePx, density)
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun snapToEdge(sizePx: Int, density: Float) {
        val params = pokoParams ?: return
        val screenWidth = resources.displayMetrics.widthPixels
        val screenHeight = resources.displayMetrics.heightPixels

        val midX = params.x + sizePx / 2
        val targetX = if (midX < screenWidth / 2) {
            (4 * density).toInt()
        } else {
            screenWidth - sizePx - (4 * density).toInt()
        }

        // 视线自适应：停靠在右侧面向左，停靠在左侧面向右
        pokoView?.facingLeft = (targetX > screenWidth / 2)

        val minY = (40 * density).toInt()
        val maxY = screenHeight - sizePx - (50 * density).toInt()
        val clampedY = params.y.coerceIn(minY, maxY)

        val startX = params.x
        val startY = params.y

        edgeSnapAnimator?.cancel()
        edgeSnapAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 260
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                val f = anim.animatedValue as Float
                params.x = (startX + (targetX - startX) * f).toInt()
                params.y = (startY + (clampedY - startY) * f).toInt()
                try {
                    windowManager?.updateViewLayout(pokoView, params)
                    updateBubblePosition()
                } catch (_: Exception) {}
            }
        }
        edgeSnapAnimator?.start()
    }

    private fun initSpeechBubble(layoutType: Int, density: Float) {
        val bubble = TextView(this).apply {
            setTextColor(Color.parseColor("#0F172A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            val padH = (12 * density).toInt()
            val padV = (8 * density).toInt()
            setPadding(padH, padV, padH, padV)
            gravity = Gravity.CENTER
            maxWidth = (200 * density).toInt()

            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.WHITE)
                cornerRadius = 14 * density
                setStroke((1.5f * density).toInt(), Color.parseColor("#FED7AA"))
            }
            background = bg
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                elevation = 8 * density
            }
            visibility = View.GONE
        }

        bubbleParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        bubbleView = bubble
    }

    private fun showSpeechBubble() {
        val bubble = bubbleView ?: return
        val bParams = bubbleParams ?: return
        val pParams = pokoParams ?: return

        val greetings = listOf(
            "喵呜~ 主人，波可随时在屏幕边陪着你呢！(ฅ'ω'ฅ)",
            "咕噜咕噜... 戳戳小肚腩好舒服~ 💕",
            "主人看屏幕累了吗？眨眨眼喝口水休息一下吧！✨",
            "双击我可以快速打开小窝哦！🐾",
            "今天也是元气满满的一天，波可最喜欢主人啦！🌸",
            "蹭蹭屏幕~ 感觉主人今天超级棒！✨"
        )
        bubble.text = greetings.random()
        bubble.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)

        val density = resources.displayMetrics.density
        val screenWidth = resources.displayMetrics.widthPixels
        val bubbleW = bubble.measuredWidth
        val bubbleH = bubble.measuredHeight
        val pokoW = pokoView?.width ?: (78 * density).toInt()

        bParams.x = (pParams.x + (pokoW - bubbleW) / 2).coerceIn((10 * density).toInt(), screenWidth - bubbleW - (10 * density).toInt())
        bParams.y = (pParams.y - bubbleH - (6 * density).toInt()).coerceAtLeast((28 * density).toInt())

        if (bubble.parent == null) {
            try {
                windowManager?.addView(bubble, bParams)
            } catch (_: Exception) {}
        } else {
            try {
                windowManager?.updateViewLayout(bubble, bParams)
            } catch (_: Exception) {}
        }

        bubble.visibility = View.VISIBLE
        bubble.alpha = 0f
        bubble.scaleX = 0.8f
        bubble.scaleY = 0.8f
        bubble.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(200)
            .start()

        hideBubbleRunnable?.let { mainHandler.removeCallbacks(it) }
        hideBubbleRunnable = Runnable {
            bubble.animate()
                .alpha(0f)
                .scaleX(0.85f)
                .scaleY(0.85f)
                .setDuration(220)
                .withEndAction {
                    bubble.visibility = View.GONE
                }
                .start()
        }
        mainHandler.postDelayed(hideBubbleRunnable!!, 3200)
    }

    private fun updateBubblePosition() {
        val bubble = bubbleView ?: return
        val bParams = bubbleParams ?: return
        val pParams = pokoParams ?: return
        if (bubble.visibility != View.VISIBLE || bubble.parent == null) return

        val density = resources.displayMetrics.density
        val screenWidth = resources.displayMetrics.widthPixels
        val bubbleW = bubble.width.coerceAtLeast((100 * density).toInt())
        val bubbleH = bubble.height.coerceAtLeast((36 * density).toInt())
        val pokoW = pokoView?.width ?: (78 * density).toInt()

        bParams.x = (pParams.x + (pokoW - bubbleW) / 2).coerceIn((10 * density).toInt(), screenWidth - bubbleW - (10 * density).toInt())
        bParams.y = (pParams.y - bubbleH - (6 * density).toInt()).coerceAtLeast((28 * density).toInt())
        try {
            windowManager?.updateViewLayout(bubble, bParams)
        } catch (_: Exception) {}
    }

    private fun openMainActivity() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
        }
        if (launchIntent != null) {
            startActivity(launchIntent)
        }
    }

    private fun loadSavedPetConfig(): Pair<String, String> {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val rawJson = prefs.getString("flutter.poko_pet_data", null)
            if (!rawJson.isNullOrBlank()) {
                val json = JSONObject(rawJson)
                val skinId = json.optString("skinId", "cat_calico")
                val name = json.optString("name", "波可")
                return Pair(skinId, name)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return Pair("cat_calico", "波可")
    }

    private fun startAsForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "floating_pet_channel"
            val channelName = "桌面悬浮萌宠"
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            if (notificationManager != null && notificationManager.getNotificationChannel(channelId) == null) {
                val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW).apply {
                    description = "保持波可在手机桌面悬浮陪伴"
                    setShowBadge(false)
                }
                notificationManager.createNotificationChannel(channel)
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            val pendingIntent = PendingIntent.getActivity(
                this,
                0,
                launchIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            )

            val notification = Notification.Builder(this, channelId)
                .setContentTitle("波可正在桌面上陪着您~ 🐾")
                .setContentText("点击返回小窝，双击桌面悬浮猫咪也可快速唤醒！")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .build()

            try {
                startForeground(1001, notification)
            } catch (_: Exception) {}
        }
    }

    private fun vibrate(durationMs: Long = 45) {
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(durationMs)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        edgeSnapAnimator?.cancel()
        hideBubbleRunnable?.let { mainHandler.removeCallbacks(it) }

        bubbleView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        bubbleView = null

        pokoView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        pokoView = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.ECLAIR) {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }

        Toast.makeText(this, "桌面悬浮宠已收回小窝~ 🐾", Toast.LENGTH_SHORT).show()
    }
}
