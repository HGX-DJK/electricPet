package com.electricpet.poko

import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.DisplayMetrics
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
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

        // 1. 启动轻量高保活前台常驻服务 (支持 Android 14+ specialUse)，防系统在主应用关闭时强杀/冻结事件分发
        startAsForeground()

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val density = resources.displayMetrics.density
        val sizePx = (78 * density).toInt()
        val (screenWidth, screenHeight) = getScreenDimensions()

        // 2. 初始化悬浮猫咪窗口属性 (采用 FLAG_LAYOUT_NO_LIMITS 与 START 重力，杜绝拖动至边缘时的事件丢失)
        pokoParams = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (screenWidth - sizePx - (12 * density).toInt()).coerceAtLeast(0)
            y = (screenHeight * 0.45).toInt()
        }

        // 3. 构建原生高精度矢量动画猫咪 View
        pokoView = PokoPetView(this).apply {
            val (savedSkin, savedName) = loadSavedPetConfig()
            applyConfig(savedSkin, savedName)
            facingLeft = true // 初始停靠在右侧边缘，面向屏幕内
        }

        // 4. 构建桌面悬浮萌言萌语气泡 View
        initSpeechBubble(layoutType, density)

        // 5. 绑定触控、拖拽、果冻回弹挤压与自由停驻事件
        setupTouchListener(sizePx, density)

        try {
            windowManager?.addView(pokoView, pokoParams)
            Toast.makeText(this, "🐾 波可已跃上手机桌面！无论App是否关闭均可自由拖动挪移哦~", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 每次启动或自启重新加固前台服务优先级
        startAsForeground()

        val skinId = intent?.getStringExtra("skinId")
        val petName = intent?.getStringExtra("petName")
        if (!skinId.isNullOrBlank() || !petName.isNullOrBlank()) {
            pokoView?.applyConfig(skinId, petName)
        }
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // 核心：当用户在手机多任务列表中划掉关闭主App时，前台服务依然健壮保持运行，绝不自我杀死，桌面猫咪依然可以自由拖拽！
    }

    private fun getScreenDimensions(): Pair<Int, Int> {
        val wm = windowManager ?: getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        wm.defaultDisplay?.getRealMetrics(metrics)
        val w = if (metrics.widthPixels > 0) metrics.widthPixels else resources.displayMetrics.widthPixels
        val h = if (metrics.heightPixels > 0) metrics.heightPixels else resources.displayMetrics.heightPixels
        return Pair(w, h)
    }

    private fun setupTouchListener(sizePx: Int, density: Float) {
        val touchSlop = ViewConfiguration.get(this).scaledTouchSlop
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isClick = false

        pokoView?.setOnTouchListener { _, event ->
            val params = pokoParams ?: return@setOnTouchListener false
            val (screenWidth, screenHeight) = getScreenDimensions()

            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    edgeSnapAnimator?.cancel()
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isClick = true
                    pokoView?.onDragStateChanged(true)
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()

                    if (abs(dx) > touchSlop || abs(dy) > touchSlop) {
                        isClick = false
                    }

                    // 限制移动在屏幕边界之内，防止被拖离屏幕视野
                    val maxX = (screenWidth - sizePx).coerceAtLeast(0)
                    val minY = (16 * density).toInt()
                    val maxY = (screenHeight - sizePx - (24 * density).toInt()).coerceAtLeast(minY)

                    params.x = (initialX + dx).coerceIn(0, maxX)
                    params.y = (initialY + dy).coerceIn(minY, maxY)

                    // 拖拽时视线随屏幕左右侧自适应（靠左向右看，靠右向左看）
                    pokoView?.facingLeft = (params.x > screenWidth / 2)

                    try {
                        windowManager?.updateViewLayout(pokoView, params)
                        updateBubblePosition()
                    } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    pokoView?.onDragStateChanged(false)
                    if (isClick && event.actionMasked == MotionEvent.ACTION_UP) {
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
                            pokoView?.performClick()
                            showSpeechBubble()
                        }
                    } else {
                        // 拖拽释放：波可自由停留在用户放置的位置！
                        // 仅当用户拖拽很接近边缘时（< 20dp）轻柔靠边吸附；若放置在屏幕中间任意位置均自由保留
                        maybeGentleSnapEdge(params, sizePx, density, screenWidth)
                    }
                    true
                }
                else -> false
            }
        }
    }

    private fun maybeGentleSnapEdge(params: WindowManager.LayoutParams, sizePx: Int, density: Float, screenWidth: Int) {
        val edgeThreshold = (20 * density).toInt()
        val targetX = when {
            params.x < edgeThreshold -> (4 * density).toInt()
            params.x > (screenWidth - sizePx - edgeThreshold) -> screenWidth - sizePx - (4 * density).toInt()
            else -> return // 自由保留在屏幕中间或任意自定义桌面位置，绝不强制拉回边缘！
        }

        val startX = params.x
        edgeSnapAnimator?.cancel()
        edgeSnapAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 180
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                val f = anim.animatedValue as Float
                params.x = (startX + (targetX - startX) * f).toInt()
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
        val (screenWidth, _) = getScreenDimensions()
        val bubbleW = bubble.measuredWidth
        val bubbleH = bubble.measuredHeight
        val pokoW = pokoView?.width ?: (78 * density).toInt()

        bParams.x = (pParams.x + (pokoW - bubbleW) / 2).coerceIn((10 * density).toInt(), (screenWidth - bubbleW - (10 * density).toInt()).coerceAtLeast(0))
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
        val (screenWidth, _) = getScreenDimensions()
        val bubbleW = bubble.width.coerceAtLeast((100 * density).toInt())
        val bubbleH = bubble.height.coerceAtLeast((36 * density).toInt())
        val pokoW = pokoView?.width ?: (78 * density).toInt()

        bParams.x = (pParams.x + (pokoW - bubbleW) / 2).coerceIn((10 * density).toInt(), (screenWidth - bubbleW - (10 * density).toInt()).coerceAtLeast(0))
        bParams.y = (pParams.y - bubbleH - (6 * density).toInt()).coerceAtLeast((28 * density).toInt())
        try {
            windowManager?.updateViewLayout(bubble, bParams)
        } catch (_: Exception) {}
    }

    private fun openMainActivity() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
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

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
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
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        1001,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                    )
                } else {
                    startForeground(1001, notification)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
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
