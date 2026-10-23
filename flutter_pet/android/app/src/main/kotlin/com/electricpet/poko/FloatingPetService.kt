package com.electricpet.poko

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.UiModeManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.content.res.Configuration
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.text.TextUtils
import android.util.DisplayMetrics
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.VelocityTracker
import android.view.View
import android.view.ViewConfiguration
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import org.json.JSONObject
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.exp
import kotlin.math.sqrt

/**
 * 悬浮宠设置项：大小 / 透明度 / 行为开关。
 *
 * 顶层声明，原生服务与 MethodChannel 两侧共用同一份结构。
 */
data class OverlaySettings(
    val sizeDp: Int = FloatingPetService.DEFAULT_PET_SIZE_DP,
    val opacity: Float = 1f,
    val peeking: Boolean = true,
    val strolling: Boolean = true,
    val autoChat: Boolean = true,
    val edgeSnap: Boolean = true,
)

class FloatingPetService : Service() {

    private var windowManager: WindowManager? = null
    private var pokoView: PokoPetView? = null
    private var pokoParams: WindowManager.LayoutParams? = null

    // 专属悬浮对话气泡
    private var bubbleView: TextView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var hideBubbleRunnable: Runnable? = null

    // 桌面萌宠身旁快捷控制悬浮菜单 (🐾 摸摸 / 🐟 喂食 / 🏠 小窝 / ✕ 收回)
    private var actionMenuView: LinearLayout? = null
    private var actionMenuParams: WindowManager.LayoutParams? = null
    private var hideActionMenuRunnable: Runnable? = null
    /** 菜单窗口当前是否已挂载到 WindowManager（用显式标记判断，避免依赖 View.parent 的回收时机） */
    private var isActionMenuAttached: Boolean = false

    // 双击与触控物理量
    private var lastClickTime: Long = 0
    private var edgeSnapAnimator: ValueAnimator? = null
    private var strollAnimator: ValueAnimator? = null
    private var isStrolling: Boolean = false

    // 边缘半收起探头避让模式状态与调度
    private var isPeeking: Boolean = false
    private var hasTouchDown: Boolean = false

    /**
     * 波可是否被用户"收进通知栏"。
     *
     * true = 服务还活着、通知还留着，但桌面上没有猫；
     * 用户点通知栏的「召回波可」就能把它叫回来。
     */
    private var isPetRecalled: Boolean = false
    private var peekAnimator: ValueAnimator? = null
    private var peekingRunnable: Runnable? = null
    // 拖拽溢出偏移的回收动画（与探头动画分开，避免互相打断）
    private var peekOffsetAnimator: ValueAnimator? = null

    // 音频音效系统
    private var soundPool: SoundPool? = null
    private var soundMeowId: Int = 0
    private var soundPurrId: Int = 0
    private var isSoundEnabled: Boolean = true

    // 长按蓄力深度互动
    private var isLongPressing: Boolean = false
    private var longPressRunnable: Runnable? = null

    // ---------- 双指手势：捏合缩放大小 / 旋转翻朝向 ----------
    // 这些必须是类成员：手势状态要跨 ACTION_POINTER_DOWN / MOVE / POINTER_UP 多次回调，
    // 而处理函数 handlePinchGesture() 是独立成员函数，读不到 setupTouchListener 的局部变量。
    private var isPinching: Boolean = false
    private var pinchStartDistance: Float = 0f
    private var pinchStartSizeDp: Int = DEFAULT_PET_SIZE_DP
    private var pinchStartAngle: Float = 0f
    private var pinchStartFacingLeft: Boolean = false

    // ---------- 悬浮宠设置 (大小 / 透明度 / 行为开关) ----------
    private var overlayType: Int = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
    private var petSizeDp: Int = DEFAULT_PET_SIZE_DP
    private var petSizePx: Int = 0
    private var petOpacity: Float = 1f
    private var enablePeeking: Boolean = true
    private var enableStrolling: Boolean = true
    private var enableAutoChat: Boolean = true
    private var enableEdgeSnap: Boolean = true

    // 互动时间戳：用于"多久没人理它了"的主动搭话
    private var lastInteractionAt: Long = 0L
    private var lastAutoChatAt: Long = 0L

    // ---------- 屏幕与安全区缓存 ----------
    // 拖拽时每帧都要用屏幕尺寸和系统栏避让边距，
    // 原来每次都现算（new DisplayMetrics + getIdentifier 资源表查找），
    // 60fps 下明显拖慢渲染。缓存起来，只在屏幕配置变化时刷新。
    private var cachedScreenWidth: Int = 0
    private var cachedScreenHeight: Int = 0
    private var safeTopInset: Int = 0
    private var safeBottomInset: Int = 0

    // 小鱼干投喂小游戏
    private var foodWindowView: View? = null
    private var foodWindowParams: WindowManager.LayoutParams? = null
    private var isFoodGameActive: Boolean = false

    // 惯性滑行动画
    private var flingAnimator: ValueAnimator? = null

    // 自主在桌面边缘漫步溜达定时任务 (支持省电低功耗模式动态降频)
    private val edgeStrollRunnable = object : Runnable {
        override fun run() {
            if (screenOn && !isAppForeground && !isStrolling && edgeSnapAnimator?.isRunning != true && !hasTouchDown) {
                val isLowPower = isLowPowerMode()
                if (!isLowPower || Math.random() > 0.5) {
                    maybeStrollAlongEdge()
                }
            }
            val baseDelay = if (isLowPowerMode()) 26000L else 14000L
            val jitter = if (isLowPowerMode()) 12000L else 8000L
            val nextDelay = (baseDelay + (Math.random() * jitter).toLong())
            mainHandler.postDelayed(this, nextDelay)
        }
    }

    // 屏幕点亮状态: 息屏时悬浮猫不可见, 顺带停掉动画省电
    private var screenOn = true
    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    screenOn = false
                    refreshPetVisibility()
                }
                Intent.ACTION_SCREEN_ON -> {
                    screenOn = true
                    refreshPetVisibility()
                }
            }
        }
    }

    companion object {
        var isRunning = false
        const val TAG = "PokoOverlay"

        /**
         * 拖拽修复版本标记：启动日志会带上它，
         * 用户一看就知道手机上跑的是不是包含拖拽修复的新包。
         */
        const val DRAG_FIX_VERSION = "drag-fix-v3"

        // ---------- 悬浮宠设置 ----------
        const val DEFAULT_PET_SIZE_DP = 82
        const val MIN_PET_SIZE_DP = 56
        const val MAX_PET_SIZE_DP = 132
        /** 探头避让时的透明度系数（在用户设置的透明度之上再淡化一层） */
        const val PEEK_ALPHA_FACTOR = 0.68f
        /** 主动搭话的巡检间隔 */
        const val AUTO_CHAT_INTERVAL_MS = 60_000L
        /** 超过这么久没人互动，波可就会主动冒泡 */
        const val AUTO_CHAT_IDLE_MS = 12 * 60 * 1000L
        /**
         * 两次"状态变差"播报之间的最小间隔（毫秒）。
         * 防止 App 里连续操作时反复弹同样的提醒。
         */
        const val STATE_BROADCAST_COOLDOWN_MS = 10 * 60 * 1000L

        /**
         * 状态衰减速率（每秒）。
         *
         * ⚠️ 必须与 Dart 侧 `PetModel.decayRates` 完全一致，
         * 否则 App 里的波可和桌面上的波可会算出不同的饱腹度/心情。
         * 守护测试会逐项比对这两张表。
         */
        val DECAY_RATES: Map<String, Float> = mapOf(
            "hunger" to 0.45f,
            "mood" to 0.35f,
            "cleanliness" to 0.15f,
            "energy" to 0.25f,
        )

        /** 单次最多补算的离线时长（秒，12 小时）—— 防止改系统时间造成数值爆炸 */
        const val MAX_OFFLINE_DECAY_SECONDS = 43200.0

        // ---------- 触觉反馈（震动语义表） ----------

        /**
         * 一次触觉反馈的波形定义。
         *
         * 背景：此前所有触摸反馈用的都是同一个 `vibrate(30)`，
         * 摸头和被踩尾巴的手感一模一样 —— 用户盯着屏幕时表情够用，
         * 但视线一离开屏幕，震动就是唯一还能传达"你摸到哪儿了"的通道。
         * 它零延迟、几乎不耗电，是最便宜也最容易被忽略的反馈通道。
         *
         * timings 是"开/关"交替的波形（首个 0 表示起始延迟）；
         * amplitudes 必须与 timings **等长**，
         * 否则 `VibrationEffect.createWaveform` 会抛 IllegalArgumentException 直接崩。
         * 守护测试会逐项断言两者长度一致。
         */
        class HapticPattern(val timings: LongArray, val amplitudes: IntArray)

        /** 摸头：轻快两下，像被顺毛 */
        val HAPTIC_PET_HEAD = HapticPattern(
            longArrayOf(0, 16, 55, 16), intArrayOf(0, 80, 0, 80)
        )

        /** 挠身体：三下细碎的痒痒感 */
        val HAPTIC_PET_BODY = HapticPattern(
            longArrayOf(0, 10, 35, 10, 35, 10), intArrayOf(0, 55, 0, 55, 0, 55)
        )

        /** 踩尾巴：一下重震，警觉炸毛 */
        val HAPTIC_PET_TAIL = HapticPattern(
            longArrayOf(0, 70), intArrayOf(0, 210)
        )

        /** 戳爪爪：两下短促 */
        val HAPTIC_PET_PAW = HapticPattern(
            longArrayOf(0, 22, 60, 22), intArrayOf(0, 120, 0, 120)
        )

        /** 普通单击：一下轻震 */
        val HAPTIC_TAP = HapticPattern(
            longArrayOf(0, 20), intArrayOf(0, 100)
        )

        /** 长按抚摸：一下绵长舒服的震 */
        val HAPTIC_PET_LONG = HapticPattern(
            longArrayOf(0, 45), intArrayOf(0, 90)
        )

        /** 菜单开合 / 跳转 */
        val HAPTIC_MENU = HapticPattern(
            longArrayOf(0, 12, 45, 12), intArrayOf(0, 70, 0, 70)
        )

        /** 喂食成功：三下递增的愉快节奏 */
        val HAPTIC_FEED = HapticPattern(
            longArrayOf(0, 14, 45, 14, 45, 14), intArrayOf(0, 80, 0, 105, 0, 130)
        )

        /** 收回：一重一轻，像"拜拜" */
        val HAPTIC_DISMISS = HapticPattern(
            longArrayOf(0, 45, 60, 25), intArrayOf(0, 140, 0, 70)
        )

        /** 追尾巴：两下轻快 */
        val HAPTIC_SPIN = HapticPattern(
            longArrayOf(0, 16, 45, 16), intArrayOf(0, 85, 0, 85)
        )

        // ---------- 状态快照（服务与桌面小组件共用） ----------

        /**
         * 读取宠物状态快照：只解析一次 JSON，并按 stateSavedAt 补算离线期间的衰减。
         *
         * 桌面悬浮宠和桌面小组件都走这一份逻辑，
         * 保证"猫身上的状态"和"小组件上写的状态"永远是同一个值。
         */
        fun readStateSnapshot(context: Context): PetState {
            return try {
                val prefs = context.getSharedPreferences(PREFS_PET, Context.MODE_PRIVATE)
                val rawJson = prefs.getString(KEY_PET_DATA, null)
                if (rawJson.isNullOrBlank()) {
                    defaultPetState()
                } else {
                    val json = JSONObject(rawJson)
                    val elapsed = elapsedDecaySeconds(json.optLong("stateSavedAt", 0L))
                    PetState(
                        hunger = decayedValue(json, "hunger", 80, elapsed),
                        mood = decayedValue(json, "mood", 80, elapsed),
                        energy = decayedValue(json, "energy", 80, elapsed),
                        cleanliness = decayedValue(json, "cleanliness", 80, elapsed),
                        intimacy = json.optInt("intimacy", 50),
                        skinId = json.optString("skinId", "cat_calico"),
                        petName = json.optString("name", "波可"),
                        enableSound = json.optBoolean("enableSound", true),
                    )
                }
            } catch (_: Exception) {
                defaultPetState()
            }
        }

        private fun defaultPetState() = PetState(
            hunger = 80,
            mood = 80,
            energy = 80,
            cleanliness = 80,
            intimacy = 50,
            skinId = "cat_calico",
            petName = "波可",
            enableSound = true,
        )

        /** 距离上次状态结算过去了多少秒（最多补算 12 小时） */
        private fun elapsedDecaySeconds(stateSavedAt: Long): Float {
            if (stateSavedAt <= 0L) return 0f
            val diffMs = System.currentTimeMillis() - stateSavedAt
            if (diffMs <= 0L) return 0f
            return (diffMs / 1000.0).coerceAtMost(MAX_OFFLINE_DECAY_SECONDS).toFloat()
        }

        /** 某个状态值按流逝时间补算后的结果（0~100 整数） */
        private fun decayedValue(json: JSONObject, key: String, fallback: Int, elapsed: Float): Int {
            val base = json.optDouble(key, fallback.toDouble()).toFloat()
            val rate = DECAY_RATES[key] ?: 0f
            return (base - rate * elapsed).coerceIn(0f, 100f).toInt()
        }

        /** 与 Dart 侧共用的宠物数据存档键（SharedPreferences 的 key 前缀由插件自动加 flutter.） */
        private const val PREFS_PET = "FlutterSharedPreferences"
        private const val KEY_PET_DATA = "flutter.poko_pet_data"

        private const val PREFS_OVERLAY = "poko_overlay_settings"
        private const val KEY_SIZE_DP = "pet_size_dp"
        private const val KEY_OPACITY = "pet_opacity"
        private const val KEY_PEEKING = "enable_peeking"
        private const val KEY_STROLLING = "enable_strolling"
        private const val KEY_AUTO_CHAT = "enable_auto_chat"
        private const val KEY_EDGE_SNAP = "enable_edge_snap"
        private const val ACTION_NOTIFICATION_PET = "com.electricpet.poko.ACTION_NOTIFICATION_PET"
        const val ACTION_NOTIFICATION_FEED = "com.electricpet.poko.ACTION_NOTIFICATION_FEED"
        const val ACTION_NOTIFICATION_STOP = "com.electricpet.poko.ACTION_NOTIFICATION_STOP"

        /**
         * 通知栏「召回波可」：把收回小窝的波可重新叫回桌面。
         *
         * 之前"收回"直接 stopSelf()，服务一停悬浮窗和通知都没了，
         * 想再叫回来只能开 App —— 用户反馈"收起来就找不到了"。
         * 现在改成"收进通知栏"：服务留着，通知栏留「召回」和「关闭」两个按钮。
         */
        const val ACTION_NOTIFICATION_RECALL = "com.electricpet.poko.ACTION_NOTIFICATION_RECALL"

        /** 主 App 是否正处于前台：前台时悬浮猫需要让位，避免与 App 内的同一只波可重叠成两只 */
        @Volatile
        var isAppForeground: Boolean = false

        /** 当前运行中的服务实例，供主 Activity 前后台切换时即时同步悬浮猫显隐 */
        @Volatile
        var instance: FloatingPetService? = null

        /** 主 Activity 前后台切换时调用，驱动悬浮猫显隐 */
        @JvmStatic
        fun notifyAppForegroundChanged(foreground: Boolean) {
            isAppForeground = foreground
            instance?.refreshPetVisibility()
        }

        /**
         * 读取悬浮宠设置（服务未运行时也能读）。
         * MethodChannel 与服务共用同一份存储，避免两边各写一套。
         */
        @JvmStatic
        fun readSettings(context: Context): OverlaySettings {
            return try {
                val prefs = context.getSharedPreferences(PREFS_OVERLAY, Context.MODE_PRIVATE)
                OverlaySettings(
                    sizeDp = prefs.getInt(KEY_SIZE_DP, DEFAULT_PET_SIZE_DP)
                        .coerceIn(MIN_PET_SIZE_DP, MAX_PET_SIZE_DP),
                    opacity = prefs.getFloat(KEY_OPACITY, 1f).coerceIn(0.35f, 1f),
                    peeking = prefs.getBoolean(KEY_PEEKING, true),
                    strolling = prefs.getBoolean(KEY_STROLLING, true),
                    autoChat = prefs.getBoolean(KEY_AUTO_CHAT, true),
                    edgeSnap = prefs.getBoolean(KEY_EDGE_SNAP, true),
                )
            } catch (_: Exception) {
                OverlaySettings()
            }
        }

        /** 写入悬浮宠设置（服务未运行时也会持久化，下次启动生效） */
        @JvmStatic
        fun writeSettings(context: Context, settings: OverlaySettings) {
            try {
                context.getSharedPreferences(PREFS_OVERLAY, Context.MODE_PRIVATE).edit()
                    .putInt(KEY_SIZE_DP, settings.sizeDp)
                    .putFloat(KEY_OPACITY, settings.opacity)
                    .putBoolean(KEY_PEEKING, settings.peeking)
                    .putBoolean(KEY_STROLLING, settings.strolling)
                    .putBoolean(KEY_AUTO_CHAT, settings.autoChat)
                    .putBoolean(KEY_EDGE_SNAP, settings.edgeSnap)
                    .apply()
            } catch (_: Exception) {}
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        isRunning = true

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        instance = this

        // 屏幕尺寸与系统栏避让边距先算好缓存起来（拖拽时每帧都要用）
        invalidateScreenCache()

        // 1. 启动轻量高保活前台常驻服务 (支持 Android 14+ specialUse)，防系统在主应用关闭时强杀/冻结事件分发
        startAsForeground()

        val layoutType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        overlayType = layoutType

        // 先加载悬浮宠设置（大小 / 透明度 / 行为开关），窗口按设置创建
        val settings = loadOverlaySettings()
        petSizeDp = settings.sizeDp
        petOpacity = settings.opacity
        enablePeeking = settings.peeking
        enableStrolling = settings.strolling
        enableAutoChat = settings.autoChat
        enableEdgeSnap = settings.edgeSnap

        val density = resources.displayMetrics.density
        val sizePx = (petSizeDp * density).toInt()
        petSizePx = sizePx
        val (screenWidth, screenHeight) = getScreenDimensions()

        // 2. 初始化悬浮猫咪窗口属性
        //    FLAG_NOT_TOUCH_MODAL : 宠物以外的区域触摸透传给下层应用，避免悬浮窗吞掉整屏点击
        //    FLAG_LAYOUT_IN_SCREEN: 窗口按物理屏幕坐标系布局，可触达区域(touchable region)计算正确 —— 能拖动的关键
        //    禁用 FLAG_LAYOUT_NO_LIMITS: 它让窗口脱离屏幕裁剪，Android 10+ 上可触达区域会失效，触摸打不到宠物
        val (savedDockLeft, savedYRatio, savedXRatio) = loadSavedDockConfig()
        val (minY, maxY) = getSafeVerticalBounds(density, screenHeight, sizePx)
        val initialY = (screenHeight * savedYRatio).toInt().coerceIn(minY, maxY)

        pokoParams = WindowManager.LayoutParams(
            sizePx,
            sizePx,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = (screenWidth - sizePx - (12 * density).toInt()).coerceAtLeast(0)
            if (savedDockLeft) {
                x = (4 * density).toInt()
            }
            // 还原用户上次自由放置的横向位置（比例）；从未自由放置过则保持贴边停靠
            if (savedXRatio >= 0f) {
                x = ((screenWidth - sizePx) * savedXRatio).toInt()
                    .coerceIn(0, (screenWidth - sizePx).coerceAtLeast(0))
            }
            y = initialY
        }

        // 3. 构建原生高精度矢量动画猫咪 View
        pokoView = PokoPetView(this).apply {
            val (savedSkin, savedName) = loadSavedPetConfig()
            applyConfig(savedSkin, savedName)
            facingLeft = !savedDockLeft // 靠右面向左，靠左面向右
            // 无障碍：TalkBack 至少要能念出这是什么、怎么玩
            contentDescription = "桌面悬浮萌宠 ${petName}。可拖动到任意位置，" +
                "摸头摸身会有反应，长按可抚摸"
            isFocusable = true
            importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
        }

        // 4. 构建桌面悬浮萌言萌语气泡 View 与快捷控制菜单、音效系统
        initSpeechBubble(layoutType, density)
        initActionMenu(layoutType, density)
        initSoundEffects()

        // 5. 初始可见性与动画状态: 屏幕点亮 且 小窝不在前台
        screenOn = isScreenInteractive()
        refreshPetVisibility()

        // 6. 监听息屏 / 亮屏: 看不见的时候停掉动画, 别白烧电
        registerScreenReceiver()

        // 7. 绑定触控、拖拽、果冻回弹挤压与自由停驻事件
        setupTouchListener(density)
        scheduleEdgePeeking(savedDockLeft)

        // 8. 把饱食度 / 心情同步给悬浮猫，让表情与自主动作跟着状态走
        lastInteractionAt = System.currentTimeMillis()
        syncPetMood()

        // 9. 主动搭话调度：长时间没人理它时会自己冒泡
        mainHandler.postDelayed(autoChatRunnable, AUTO_CHAT_INTERVAL_MS)

        // 10. 监听 App 侧的宠物存档变更：喂食 / 换装 / 改音效开关都实时生效
        registerPetDataListener()

        // 11. 夜间配色：跟随 App 的昼夜节律（收不到时退回系统深色模式）
        applyNightMode(resolveNightMode())

        try {
            windowManager?.addView(pokoView, pokoParams)
            pokoView?.alpha = petOpacity
            Log.i(TAG, "悬浮宠服务启动 · 交互增强版 $DRAG_FIX_VERSION · sizeDp=$petSizeDp")
            Toast.makeText(this, "🐾 波可已跃上手机桌面！(v3) 摸摸头试试～", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 每次启动或自启重新加固前台服务优先级
        startAsForeground()

        when (intent?.action) {
            ACTION_NOTIFICATION_PET -> {
                handleNotificationPet()
                return START_STICKY
            }
            ACTION_NOTIFICATION_FEED -> {
                handleNotificationFeed()
                return START_STICKY
            }
            ACTION_NOTIFICATION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_NOTIFICATION_RECALL -> {
                recallPet()
                return START_STICKY
            }
        }

        val skinId = intent?.getStringExtra("skinId")
        val petName = intent?.getStringExtra("petName")
        // 每次启动/推送都同步外观：空值表示保持原样，非空则实时换品种
        pokoView?.applyConfig(skinId, petName)

        // 昼夜状态：App 按真实太阳节律算好后推过来，桌面猫跟着换配色
        if (intent?.hasExtra(OverlayChannel.ARG_NIGHT_MODE) == true) {
            applyNightModeFromApp(intent.getBooleanExtra(OverlayChannel.ARG_NIGHT_MODE, false))
        }
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // 核心：当用户在手机多任务列表中划掉关闭主App时，前台服务依然健壮保持运行，绝不自我杀死，桌面猫咪依然可以自由拖拽！
    }

    /**
     * 屏幕尺寸（带缓存）。
     *
     * 拖拽时每一帧都会用到屏幕尺寸，而原来的实现每次都要 new 一个 DisplayMetrics
     * 再去问系统，60fps 下纯属浪费。现在缓存起来，只在屏幕配置变化时刷新。
     */
    private fun getScreenDimensions(): Pair<Int, Int> {
        if (cachedScreenWidth > 0 && cachedScreenHeight > 0) {
            return Pair(cachedScreenWidth, cachedScreenHeight)
        }

        val wm = windowManager ?: getSystemService(Context.WINDOW_SERVICE) as WindowManager
        var w = 0
        var h = 0

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // API 30+ 用 maximumWindowMetrics：defaultDisplay.getRealMetrics 在
            // 分屏 / 折叠屏 / 多窗口下拿到的尺寸经常不对
            val bounds = wm.maximumWindowMetrics.bounds
            w = bounds.width()
            h = bounds.height()
        } else {
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay?.getRealMetrics(metrics)
            w = metrics.widthPixels
            h = metrics.heightPixels
        }

        if (w <= 0) w = resources.displayMetrics.widthPixels
        if (h <= 0) h = resources.displayMetrics.heightPixels

        cachedScreenWidth = w
        cachedScreenHeight = h
        return Pair(w, h)
    }

    /** 屏幕配置变化（旋转 / 分屏 / 折叠展开）后让缓存失效 */
    private fun invalidateScreenCache() {
        cachedScreenWidth = 0
        cachedScreenHeight = 0
        refreshSafeInsets()
    }

    // ---------- 悬浮宠设置读写 ----------

    private fun loadOverlaySettings(): OverlaySettings = readSettings(this)

    private fun saveOverlaySettings(settings: OverlaySettings) {
        writeSettings(this, settings)
    }

    /**
     * 供 MethodChannel 实时更新设置：服务正在运行就立刻生效，
     * 没在运行也会持久化，下次启动自动套用。
     */
    fun applySettingsFromChannel(settings: OverlaySettings) {
        saveOverlaySettings(settings)
        applyOverlaySettings(settings)
    }

    /**
     * 把设置立刻应用到悬浮窗：改尺寸、改透明度、开关行为。
     * 尺寸变化会让 PokoPetView 重新测量，整套矢量绘制按比例跟着缩放。
     */
    private fun applyOverlaySettings(settings: OverlaySettings) {
        petSizeDp = settings.sizeDp
        petOpacity = settings.opacity
        enablePeeking = settings.peeking
        enableStrolling = settings.strolling
        enableAutoChat = settings.autoChat
        enableEdgeSnap = settings.edgeSnap

        val params = pokoParams ?: return
        val density = resources.displayMetrics.density
        val newSize = (petSizeDp * density).toInt()
        val sizeChanged = params.width != newSize || params.height != newSize
        params.width = newSize
        params.height = newSize
        petSizePx = newSize

        // 透明度是"底色"，探头时的半透明要在它之上再叠一层
        pokoView?.alpha = currentPetAlpha()

        if (sizeChanged) {
            // 尺寸变大后要保证窗口仍在屏幕内，否则会有一半跑到屏幕外抓不到
            val (screenWidth, screenHeight) = getScreenDimensions()
            val maxX = (screenWidth - newSize).coerceAtLeast(0)
            params.x = params.x.coerceIn(0, maxX)
            val (minY, maxY) = getSafeVerticalBounds(density, screenHeight, newSize)
            params.y = params.y.coerceIn(minY, maxY)
            try {
                windowManager?.updateViewLayout(pokoView, params)
            } catch (_: Exception) {}
        }
    }

    /** 当前应显示的透明度 = 用户设置 × (探头时的淡化系数) */
    private fun currentPetAlpha(): Float {
        return if (isPeeking) petOpacity * PEEK_ALPHA_FACTOR else petOpacity
    }

    private fun setupTouchListener(density: Float) {
        val touchSlop = ViewConfiguration.get(this).scaledTouchSlop
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var lastRawX = 0f
        var isClick = false
        var hasDragged = false
        // 拖拽过程中的朝向：跟随水平移动方向（被拖着走会侧身迎向运动方向），
        // 松手后由落位逻辑恢复成"面向屏幕中心"。
        var dragFacingLeft = false
        // 朝向切换的累积位移 + 滞后阈值（避免镜像翻面时来回抖动）
        var dragDxAccum = 0f
        val facingFlipThreshold = 14f * density
        // 单次手势只打一条移动日志，便于用一条 logcat 判定"跟手了没有"
        var hasLoggedMove = false
        var velocityTracker: VelocityTracker? = null
        // 单次手势内锁定屏幕尺寸，避免坐标空间在手势中途跳变导致宠物瞬移
        var gestureScreenWidth = 0
        var gestureScreenHeight = 0
        // 注意：双指手势的基线数据（isPinching / pinchStart*）是类成员，
        // 因为 handlePinchGesture() 是独立成员函数，读不到这里的局部变量。
        // 曾经把这几个状态写成局部变量，导致 CI 编译报 Unresolved reference。

        pokoView?.setOnTouchListener { _, event ->
            val params = pokoParams ?: return@setOnTouchListener false

            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    hasTouchDown = true
                    lastInteractionAt = System.currentTimeMillis()
                    cancelEdgePeeking()
                    // 按下瞬间立即完全露出（只复位绘制偏移，窗口坐标一动不动），
                    // 保证下面采集到的 initialX/initialY 就是宠物真实落点
                    restoreFromPeeking(animated = false)
                    velocityTracker?.recycle()
                    velocityTracker = VelocityTracker.obtain()
                    velocityTracker?.addMovement(event)
                    edgeSnapAnimator?.cancel()
                    flingAnimator?.cancel()
                    strollAnimator?.cancel()
                    isStrolling = false
                    pokoView?.stopWalking()
                    val (sw, sh) = getScreenDimensions()
                    gestureScreenWidth = sw
                    gestureScreenHeight = sh
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    lastRawX = event.rawX
                    isClick = true
                    hasDragged = false
                    hasLoggedMove = false
                    isLongPressing = false
                    isPinching = false
                    dragFacingLeft = pokoView?.facingLeft ?: false

                    // 视线跟随：指尖一落下，眼珠就开始盯着看
                    pokoView?.setGazeTarget(event.x, event.y)

                    // 长按蓄力深度抚摸计时
                    longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                    longPressRunnable = Runnable {
                        if (hasTouchDown && !hasDragged) {
                            isLongPressing = true
                            isClick = false
                            haptic(Companion.HAPTIC_PET_LONG)
                            playSound("purr")
                            pokoView?.onPetTapped()
                            showCustomSpeechBubble("呼噜噜... 被主人长按抚摸好温暖呀，幸福感爆棚！💖✨")
                        }
                    }
                    mainHandler.postDelayed(longPressRunnable!!, 480)

                    // 注意：这里刻意不把宠物切到"拎起悬空"状态。
                    // 拎起要等真正超过拖拽阈值才触发，否则单击会先拎起再落地，出现一下抽搐。
                    Log.d(
                        TAG,
                        "触摸按下 raw=(${event.rawX}, ${event.rawY}) win=($initialX, $initialY) " +
                            "peekOffset=${pokoView?.peekOffsetX} sizePx=$petSizePx"
                    )
                    true
                }
                MotionEvent.ACTION_POINTER_DOWN -> {
                    // 第二根手指落下：进入双指手势（捏合缩放 / 旋转翻面）
                    if (event.pointerCount >= 2) {
                        isPinching = true
                        isClick = false
                        hasDragged = false
                        pinchStartDistance = pointerDistance(event)
                        pinchStartSizeDp = petSizeDp
                        pinchStartAngle = pointerAngle(event)
                        pinchStartFacingLeft = pokoView?.facingLeft ?: false
                        longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                        hideActionMenu(animated = false)
                    }
                    true
                }
                MotionEvent.ACTION_POINTER_UP -> {
                    // 抬起一根手指：结束双指手势并重新锚定拖拽起点，避免宠物瞬移
                    if (event.pointerCount <= 2) {
                        isPinching = false
                        initialX = params.x
                        initialY = params.y
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    velocityTracker?.addMovement(event)
                    // 视线跟随：眼珠始终追着指尖
                    pokoView?.setGazeTarget(event.x, event.y)

                    // 双指手势优先：捏合改大小、旋转翻朝向
                    if (isPinching && event.pointerCount >= 2) {
                        handlePinchGesture(event)
                        return@setOnTouchListener true
                    }

                    val screenWidth = gestureScreenWidth
                    val screenHeight = gestureScreenHeight
                    val dx = (event.rawX - initialTouchX).toInt()
                    val dy = (event.rawY - initialTouchY).toInt()

                    val vx = event.rawX - lastRawX
                    lastRawX = event.rawX
                    pokoView?.updateDragVelocity(vx)

                    // 朝向跟随拖动方向：往左拖就侧身朝左、往右拖就朝右。
                    // 之前是按"宠物在屏幕左半边还是右半边"硬切，
                    // 结果往左拖时猫脸还朝右，跟手感完全对不上。
                    //
                    // 注意朝向是靠整幅画面镜像实现的（canvas.scale(-1,1)），
                    // 翻面是"啪"的一下突变，所以这里用累积位移 + 滞后阈值：
                    // 累计移动超过阈值才允许翻面，翻完清零 —— 既跟手又不会来回抖。
                    dragDxAccum += vx
                    if (abs(dragDxAccum) > facingFlipThreshold) {
                        val wantLeft = dragDxAccum < 0
                        if (wantLeft != dragFacingLeft) {
                            dragFacingLeft = wantLeft
                            pokoView?.facingLeft = wantLeft
                        }
                        dragDxAccum = 0f
                    }

                    if (!hasDragged && (abs(dx) > touchSlop || abs(dy) > touchSlop)) {
                        isClick = false
                        hasDragged = true
                        hideActionMenu(animated = false)
                        longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                        // 真正开始拖动才"拎起悬空"，单击不再出现拎起-落地的抽搐
                        pokoView?.onDragStateChanged(true)
                        Log.d(TAG, "进入拖拽 dx=$dx dy=$dy")
                    }

                    // 限制移动在屏幕边界之内，动态适应状态栏与手势条避让
                    val maxX = (screenWidth - petSizePx).coerceAtLeast(0)
                    val (minY, maxY) = getSafeVerticalBounds(density, screenHeight, petSizePx)

                    val wantedX = initialX + dx
                    params.x = wantedX.coerceIn(0, maxX)
                    params.y = (initialY + dy).coerceIn(minY, maxY)

                    // 拖出屏幕的部分用"绘制偏移"表现：窗口本身绝不越界，
                    // 既能拖出半只猫，又不会重现坐标钳制把宠物钉死在边缘的问题
                    val maxOverflow = (petSizePx * 0.4f).toInt()
                    val overflow = (wantedX - params.x).coerceIn(-maxOverflow, maxOverflow)
                    pokoView?.peekOffsetX = overflow.toFloat()

                    // 拖拽时视线随屏幕左右侧自适应（靠左向右看，靠右向左看）
                    // 注意：朝向在上面的"跟随拖动方向"里已经处理过了，
                    // 这里不再按屏幕半区硬切，否则会把刚翻好的面又掰回去。

                    try {
                        windowManager?.updateViewLayout(pokoView, params)
                        updateBubblePosition()
                    } catch (e: Exception) {
                        // 之前这里被静默吞掉，导致"宠物按不动/拖不动"完全无从排查
                        Log.e(TAG, "悬浮窗位置更新失败", e)
                    }

                    if (!hasLoggedMove) {
                        hasLoggedMove = true
                        Log.d(
                            TAG,
                            "首次移动 dx=$dx dy=$dy -> 窗口位置 x=${params.x} y=${params.y} " +
                                "(初始 win=($initialX, $initialY))"
                        )
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    // 系统中断手势（来电、通知栏下拉、系统导航手势）时绝不能当成松手处理，
                    // 否则宠物会被误判为"拖拽结束"而吸附回边缘，看起来又像拖不动
                    hasTouchDown = false
                    longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                    pokoView?.onDragStateChanged(false)
                    pokoView?.clearGazeTarget()
                    // 取消时不会走落位逻辑，拖出屏幕的那段绘制偏移必须在这里收回，
                    // 否则宠物会一直歪在窗口旁边悬在屏幕外（要等下次触摸才自愈）
                    animatePeekOffsetBack()
                    velocityTracker?.recycle()
                    velocityTracker = null
                    Log.w(TAG, "拖拽被系统中断 (ACTION_CANCEL)，波可保持原地不动")
                    true
                }
                MotionEvent.ACTION_UP -> {
                    hasTouchDown = false
                    lastInteractionAt = System.currentTimeMillis()
                    longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                    pokoView?.onDragStateChanged(false)
                    pokoView?.clearGazeTarget()
                    var releaseVx = 0f
                    var releaseVy = 0f
                    velocityTracker?.let { vt ->
                        vt.addMovement(event)
                        vt.computeCurrentVelocity(1000)
                        releaseVx = vt.xVelocity
                        releaseVy = vt.yVelocity
                        vt.recycle()
                    }
                    velocityTracker = null

                    if (isLongPressing) {
                        isLongPressing = false
                        // 只有完全没有拖动时才吞掉释放；已经拖动过则继续走拖拽落位逻辑，
                        // 否则"先按住半秒再拖"与"快速拖"会得到两种完全不同的结果
                        if (!hasDragged) {
                            scheduleEdgePeeking(!(pokoView?.facingLeft ?: true))
                            return@setOnTouchListener true
                        }
                    }

                    if (isClick) {
                        val now = System.currentTimeMillis()
                        if (now - lastClickTime < 380) {
                            // 双击：不再抢走手势去拉起小窝，改为原地转圈卖萌
                            // （回小窝改由快捷菜单里的 🏠 完成，避免"想逗猫"却被拽出 App）
                            lastClickTime = now
                            vibrateDoubleTick()
                            playSound("meow")
                            pokoView?.executeAction(PokoPetView.PetAction.SPIN_TAIL)
                            showCustomSpeechBubble("转圈圈给你看～ 想回小窝就点旁边的小房子哦 ✨")
                        } else {
                            // 单击：按命中的身体分区给出不同反应，落在空白处才退回默认摸摸
                            lastClickTime = now
                            handleZoneTap(event.x, event.y)
                        }
                    } else if (hasDragged) {
                        // 拖拽释放：先按释放速度惯性滑行一段，再落位
                        flingAndSettle(
                            params, petSizePx, density,
                            gestureScreenWidth, gestureScreenHeight,
                            releaseVx, releaseVy
                        )
                    }
                    true
                }
                else -> false
            }
        }
    }

    /**
     * 单击分区处理：摸头 / 摸身 / 摸尾 / 戳爪 四种反应；
     * 落在空白处才退回"默认摸摸 + 弹出快捷菜单"。
     */
    private fun handleZoneTap(touchX: Float, touchY: Float) {
        val zone = pokoView?.hitTest(touchX, touchY) ?: PokoPetView.TouchZone.NONE
        val handled = pokoView?.reactToTouch(zone) ?: false
        if (handled) {
            // 触觉按部位区分：摸头轻快两下，踩尾巴一下重震，戳爪爪两下短促。
            // 表情在屏幕里，震动在手里 —— 视线一移开，全靠它区分摸到了哪儿。
            when (zone) {
                PokoPetView.TouchZone.HEAD -> {
                    haptic(Companion.HAPTIC_PET_HEAD)
                    playSound("purr")
                    showCustomSpeechBubble("呼噜噜～ 被摸到头了，好舒服呀主人！💕")
                }
                PokoPetView.TouchZone.BODY -> {
                    haptic(Companion.HAPTIC_PET_BODY)
                    playSound("purr")
                    showCustomSpeechBubble("嘿嘿痒痒的～ 主人在摸我身体呢 ✨")
                }
                PokoPetView.TouchZone.TAIL -> {
                    haptic(Companion.HAPTIC_PET_TAIL)
                    playSound("meow")
                    showCustomSpeechBubble("喵！尾巴不许碰啦，再摸我要炸毛咯～ 🫧")
                }
                PokoPetView.TouchZone.PAW -> {
                    haptic(Companion.HAPTIC_PET_PAW)
                    playSound("meow")
                    showCustomSpeechBubble("爪爪被戳到啦！轻一点嘛～ 🐾")
                }
                else -> haptic(Companion.HAPTIC_TAP)
            }
            return
        }

        // 空白处：**只**负责开菜单。
        //
        // 之前这里一次点击同时做了三件事：摸摸（喵一声 + 挤压动画）、弹出菜单、
        // 再冒一句随机气泡。三个反馈叠在一起，用户既说不清自己在按什么，
        // 菜单也像是"自己冒出来的"。
        //
        // 现在分工明确：点身体 = 逗它玩，点旁边 = 打开操作菜单。
        // 菜单弹出时猫歪个头看你，表示"菜单是我开的"，保持"它是活的"的感觉。
        haptic(Companion.HAPTIC_MENU)
        if (isActionMenuVisible()) {
            hideActionMenu()
        } else {
            pokoView?.executeAction(PokoPetView.PetAction.HEAD_TILT)
            showActionMenu()
        }
        scheduleEdgePeeking(!(pokoView?.facingLeft ?: true))
    }

    /**
     * 松手后的惯性滑行：按释放速度带摩擦地滑行一段，再交给落位逻辑。
     * 之前只有"fling 判方向"，宠物是瞬间停住的，缺少物理感。
     */
    private fun flingAndSettle(
        params: WindowManager.LayoutParams,
        sizePx: Int,
        density: Float,
        screenWidth: Int,
        screenHeight: Int,
        releaseVx: Float,
        releaseVy: Float
    ) {
        val vx = releaseVx.coerceIn(-5000f, 5000f)
        val vy = releaseVy.coerceIn(-5000f, 5000f)
        val maxX = (screenWidth - sizePx).coerceAtLeast(0)
        val (minY, maxY) = getSafeVerticalBounds(density, screenHeight, sizePx)

        // 摩擦模型：位移 = v · τ · (1 - e^(-t/τ))
        val tau = 0.16f
        val endTime = 0.55f
        val decay = 1f - exp(-endTime / tau)
        val distX = vx * tau * decay
        val distY = vy * tau * decay

        // 速度太小就直接落位，不做无意义的滑行
        if (abs(distX) < 24f && abs(distY) < 24f) {
            settleAfterDrag(params, sizePx, density, screenWidth, releaseVx)
            return
        }

        val startX = params.x
        val startY = params.y
        val targetX = (startX + distX).coerceIn(0f, maxX.toFloat())
        val targetY = (startY + distY).coerceIn(minY.toFloat(), maxY.toFloat())
        // 滑行过程中窗口会回到屏内，之前拖出去的那段绘制偏移要同步收回
        val startPeek = pokoView?.peekOffsetX ?: 0f

        flingAnimator?.cancel()
        flingAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = (endTime * 1000).toLong()
            interpolator = DecelerateInterpolator(1.4f)
            addUpdateListener { anim ->
                val f = anim.animatedValue as Float
                params.x = (startX + (targetX - startX) * f).toInt()
                params.y = (startY + (targetY - startY) * f).toInt()
                if (startPeek != 0f) {
                    pokoView?.peekOffsetX = startPeek * (1f - f)
                }
                try {
                    windowManager?.updateViewLayout(pokoView, params)
                    updateBubblePosition()
                } catch (_: Exception) {}
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    settleAfterDrag(params, sizePx, density, screenWidth, releaseVx)
                }
            })
        }
        flingAnimator?.start()
    }

    /**
     * 双指手势：捏合改变悬浮宠大小，旋转翻面朝向。
     * 大小变化会立即写回设置，下次启动依然生效。
     */
    private fun handlePinchGesture(event: MotionEvent) {
        val dist = pointerDistance(event)
        if (pinchStartDistance > 1f && dist > 1f) {
            val ratio = (dist / pinchStartDistance).coerceIn(0.6f, 1.8f)
            val newDp = (pinchStartSizeDp * ratio).toInt()
                .coerceIn(MIN_PET_SIZE_DP, MAX_PET_SIZE_DP)
            if (newDp != petSizeDp) {
                val settings = loadOverlaySettings().copy(sizeDp = newDp)
                saveOverlaySettings(settings)
                applyOverlaySettings(settings)
            }
        }

        // 旋转手指：翻面朝向
        val angle = pointerAngle(event)
        var delta = angle - pinchStartAngle
        while (delta > 180f) delta -= 360f
        while (delta < -180f) delta += 360f
        if (abs(delta) > 40f) {
            pokoView?.facingLeft = !pinchStartFacingLeft
        }
    }

    /** 两指之间的距离 */
    private fun pointerDistance(event: MotionEvent): Float {
        if (event.pointerCount < 2) return 0f
        val dx = event.getX(0) - event.getX(1)
        val dy = event.getY(0) - event.getY(1)
        return sqrt(dx * dx + dy * dy)
    }

    /** 两指连线与水平方向的夹角（度） */
    private fun pointerAngle(event: MotionEvent): Float {
        if (event.pointerCount < 2) return 0f
        val dx = event.getX(1) - event.getX(0)
        val dy = event.getY(1) - event.getY(0)
        return atan2(dy, dx) * 180f / Math.PI.toFloat()
    }

    /**
     * 统一决定悬浮猫的显隐: 只有「屏幕点亮 且 小窝不在前台」时才可见。
     *
     * - 小窝在前台时隐藏, 避免与 App 内的同一只波可重叠成两只
     * - 息屏时隐藏, 因为没人看得见
     * - 隐藏期间同时停掉 60fps 呼吸动画与眨眼定时器: 前台服务常驻, 这部分功耗纯属浪费
     */
    private fun refreshPetVisibility() {
        val view = pokoView ?: return
        // 注意 isPetRecalled：用户主动"收进通知栏"之后，
        // 不能再因为 App 前后台切换就把猫自己放回桌面 —— 那等于收回无效。
        val visible = screenOn && !isAppForeground && !isPetRecalled
        val target = if (visible) View.VISIBLE else View.GONE
        if (view.visibility != target) {
            view.visibility = target
            Log.d(TAG, "悬浮猫显隐切换 visible=$visible")
        }
        view.setAnimationEnabled(visible)

        if (visible) {
            mainHandler.removeCallbacks(edgeStrollRunnable)
            mainHandler.postDelayed(edgeStrollRunnable, 7000)
            scheduleEdgePeeking(!view.facingLeft)
        } else {
            cancelEdgePeeking()
            isPeeking = false
            view.alpha = petOpacity
            peekOffsetAnimator?.cancel()
            view.peekOffsetX = 0f
            mainHandler.removeCallbacks(edgeStrollRunnable)
            strollAnimator?.cancel()
            isStrolling = false
            view.stopWalking()
            // 顺带收掉气泡与快捷菜单，避免隐藏后残留在桌面上
            hideBubbleRunnable?.let { mainHandler.removeCallbacks(it) }
            bubbleView?.visibility = View.GONE
            hideActionMenu(animated = false)
        }
    }

    /** 注册息屏 / 亮屏监听 (运行时注册, 不受 Android 8+ 隐式广播限制影响) */
    private fun registerScreenReceiver() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                registerReceiver(screenReceiver, filter)
            }
        } catch (e: Exception) {
            Log.e(TAG, "注册屏幕状态监听失败", e)
        }
    }

    /** 当前屏幕是否处于点亮交互状态 */
    private fun isScreenInteractive(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return true
        return pm.isInteractive
    }

    /**
     * 拖拽释放后的落位策略（自由拖动 + 近边轻吸附）：
     *
     * 历史教训：早期版本无条件强制磁吸到最近边缘，用户反馈"宠物拖不动"——
     * 手指按住时确实跟手，一抬手就被拽回屏幕边，放哪儿都不算数。
     * 现在只有当波可本来就停在边缘附近（或被甩向边缘）时才轻柔吸附，
     * 其余情况一律自由停留在用户放置的位置。
     *
     * 视线始终朝向屏幕中心，着陆时触发果冻弹性缓冲。
     */
    private fun settleAfterDrag(
        params: WindowManager.LayoutParams,
        sizePx: Int,
        density: Float,
        screenWidth: Int,
        releaseVx: Float = 0f
    ) {
        // 拖拽时溢出屏幕的那段绘制偏移要在这里收回，否则宠物会歪在窗口旁边
        animatePeekOffsetBack()

        // 贴边吸附停靠边距
        val edgeThreshold = (4 * density).toInt()
        val centerX = params.x + sizePx / 2

        // 结合手势释放瞬时横向加速度判定目标吸附侧
        val isLeftHalf = when {
            releaseVx < -700f -> true
            releaseVx > 700f -> false
            else -> centerX < screenWidth / 2
        }
        val targetX = if (isLeftHalf) edgeThreshold else (screenWidth - sizePx - edgeThreshold).coerceAtLeast(0)

        // 朝向屏幕中心：在左侧面向右边 (facingLeft = false)，在右侧面向左边 (facingLeft = true)
        pokoView?.facingLeft = !isLeftHalf
        pokoView?.alpha = 1.0f

        val startX = params.x

        // 自由放置：未落在边缘附近时原地停留，绝不强制拉回边缘
        // （设置里关掉磁吸贴边时，任何位置都自由停留）
        if (!enableEdgeSnap || !isDockedAtEdge(params, sizePx, density, screenWidth)) {
            pokoView?.triggerLandingBounce()
            saveDockPreference(isLeftHalf, params.x, params.y)
            scheduleEdgePeeking(isLeftHalf)
            return
        }

        if (startX == targetX) {
            pokoView?.triggerLandingBounce()
            saveDockPreference(isLeftHalf, params.x, params.y)
            scheduleEdgePeeking(isLeftHalf)
            return
        }

        val snapDuration = if (abs(releaseVx) > 900f) 190L else 260L

        edgeSnapAnimator?.cancel()
        edgeSnapAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = snapDuration
            interpolator = DecelerateInterpolator(1.8f)
            addUpdateListener { anim ->
                val f = anim.animatedValue as Float
                params.x = (startX + (targetX - startX) * f).toInt()
                try {
                    windowManager?.updateViewLayout(pokoView, params)
                    updateBubblePosition()
                } catch (_: Exception) {}
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    pokoView?.triggerLandingBounce()
                    saveDockPreference(isLeftHalf, params.x, params.y)
                    scheduleEdgePeeking(isLeftHalf)
                }
            })
        }
        edgeSnapAnimator?.start()
    }

    /**
     * 波可当前是否停在屏幕左右边缘附近。
     *
     * 自主边缘散步、探头避让等"边缘动效"以及松手时的磁吸吸附都只在此条件下触发，
     * 自由停放在屏幕中间的波可不会被这些边缘行为打扰，也不会被强行拽回边缘。
     */
    private fun isDockedAtEdge(
        params: WindowManager.LayoutParams,
        sizePx: Int,
        density: Float,
        screenWidth: Int
    ): Boolean {
        val snapRange = (10 * density).toInt()
        val maxX = (screenWidth - sizePx).coerceAtLeast(0)
        return params.x <= snapRange || params.x >= (maxX - snapRange).coerceAtLeast(0)
    }

    /**
     * 自主在桌面屏幕边缘小步溜达漫步：
     * 每隔十余秒，猫咪在停靠边缘自主向上或向下挪步小步漫步 28~45dp，
     * 伴随真实小肉爪交替踏步与轻快身躯微颠，为桌面带来灵动生机！
     */
    private fun maybeStrollAlongEdge() {
        val params = pokoParams ?: return
        val view = pokoView ?: return
        if (view.currentAction != PokoPetView.PetAction.IDLE || hasTouchDown) return
        // 设置里关掉边缘散步就不散步
        if (!enableStrolling) return

        if (isPeeking) {
            restoreFromPeeking()
            return
        }
        if (isActionMenuVisible()) {
            hideActionMenu(animated = false)
        }

        val density = resources.displayMetrics.density
        val sizePx = petSizePx
        val (screenWidth, screenHeight) = getScreenDimensions()
        val (minY, maxY) = getSafeVerticalBounds(density, screenHeight, sizePx)
        val currentY = params.y

        // 自由放在屏幕中间的波可不做边缘散步，尊重用户指定的桌面位置
        if (!isDockedAtEdge(params, sizePx, density, screenWidth)) return

        // 随机向上或向下溜达 28 ~ 45dp
        val strollDistance = ((28 + Math.random() * 17) * density).toInt()
        val moveDown = if (currentY - strollDistance < minY) {
            true
        } else if (currentY + strollDistance > maxY) {
            false
        } else {
            Math.random() > 0.5
        }

        val targetY = if (moveDown) {
            (currentY + strollDistance).coerceAtMost(maxY)
        } else {
            (currentY - strollDistance).coerceAtLeast(minY)
        }

        if (abs(targetY - currentY) < (6 * density).toInt()) return

        val startY = currentY
        isStrolling = true
        view.startWalking()

        strollAnimator?.cancel()
        strollAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 1500
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                val f = anim.animatedValue as Float
                params.y = (startY + (targetY - startY) * f).toInt()
                view.updateWalkingStep(f)
                try {
                    windowManager?.updateViewLayout(view, params)
                    updateBubblePosition()
                } catch (_: Exception) {}
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    isStrolling = false
                    view.stopWalking()
                    scheduleEdgePeeking(!view.facingLeft)
                }
                override fun onAnimationCancel(animation: Animator) {
                    isStrolling = false
                    view.stopWalking()
                }
            })
        }
        strollAnimator?.start()
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
            // 气泡最多三行，超出省略。
            // 桌面上一个四五行高的气泡会挡住半块屏幕，用户还没看完就自己消失了。
            maxLines = 3
            ellipsize = TextUtils.TruncateAt.END

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
            // 气泡可点：点一下直接回小窝，让"它说话了"能接得上话
            isClickable = true
            isFocusable = false
            setOnClickListener {
                hideBubbleRunnable?.let { mainHandler.removeCallbacks(it) }
                bubbleView?.visibility = View.GONE
                openMainActivity()
            }
        }

        bubbleParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        bubbleView = bubble
    }

    private fun initActionMenu(layoutType: Int, density: Float) {
        val menuLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL

            val bg = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.parseColor("#F8FAFC"))
                cornerRadius = 18 * density
                setStroke((1.5f * density).toInt(), Color.parseColor("#FED7AA"))
            }
            background = bg
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                elevation = 10 * density
            }

            val padH = (4 * density).toInt()
            val padV = (3 * density).toInt()
            setPadding(padH, padV, padH, padV)
            visibility = View.GONE
        }

        fun applyButtonPressEffect(view: View) {
            view.setOnTouchListener { v, event ->
                when (event.actionMasked) {
                    MotionEvent.ACTION_DOWN -> {
                        v.animate().scaleX(0.92f).scaleY(0.92f).setDuration(80).start()
                    }
                    MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                        v.animate().scaleX(1.0f).scaleY(1.0f).setDuration(80).start()
                    }
                }
                false
            }
        }

        fun createDivider(): View {
            return View(this).apply {
                layoutParams = LinearLayout.LayoutParams((1 * density).toInt(), (14 * density).toInt()).apply {
                    gravity = Gravity.CENTER_VERTICAL
                    val m = (1 * density).toInt()
                    setMargins(m, 0, m, 0)
                }
                setBackgroundColor(Color.parseColor("#E2E8F0"))
            }
        }

        val btnPadH = (9 * density).toInt()
        val btnPadV = (6 * density).toInt()

        val btnPet = TextView(this).apply {
            text = "🐾 摸摸"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTextColor(Color.parseColor("#0F172A"))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(btnPadH, btnPadV, btnPadH, btnPadV)
            isClickable = true
            isFocusable = false
            applyButtonPressEffect(this)
            setOnClickListener {
                handleDesktopPet()
            }
        }

        val btnFeed = TextView(this).apply {
            text = "🐟 喂食"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTextColor(Color.parseColor("#0284C7"))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(btnPadH, btnPadV, btnPadH, btnPadV)
            isClickable = true
            isFocusable = false
            applyButtonPressEffect(this)
            setOnClickListener {
                // 喂食变成"把小鱼干拖到嘴边"的小游戏，而不是直接加数值
                startFeedingGame()
            }
        }

        val btnHome = TextView(this).apply {
            text = "🏠 小窝"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTextColor(Color.parseColor("#7C3AED"))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(btnPadH, btnPadV, btnPadH, btnPadV)
            isClickable = true
            isFocusable = false
            applyButtonPressEffect(this)
            setOnClickListener {
                handleDesktopHome()
            }
        }

        val btnDismiss = TextView(this).apply {
            text = "🗂 收起"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTextColor(Color.parseColor("#EA580C"))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(btnPadH, btnPadV, btnPadH, btnPadV)
            isClickable = true
            isFocusable = false
            applyButtonPressEffect(this)
            setOnClickListener {
                handleDesktopDismiss()
            }
        }

        menuLayout.addView(btnPet)
        menuLayout.addView(createDivider())
        menuLayout.addView(btnFeed)
        menuLayout.addView(createDivider())
        menuLayout.addView(btnHome)
        menuLayout.addView(createDivider())
        menuLayout.addView(btnDismiss)

        actionMenuParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                // 与宠物窗口保持一致：没有 FLAG_NOT_TOUCH_MODAL 的窗口在将来一旦可获焦，
                // 会立刻变成触摸模态窗口吞掉整屏点击，导致宠物彻底拖不动
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        actionMenuView = menuLayout
    }

    private fun isActionMenuVisible(): Boolean {
        val menu = actionMenuView ?: return false
        return menu.visibility == View.VISIBLE && isActionMenuAttached
    }

    private fun showActionMenu() {
        if (isAppForeground || !screenOn) return
        val menu = actionMenuView ?: return
        val mParams = actionMenuParams ?: return
        val pParams = pokoParams ?: return
        if (isPeeking) {
            restoreFromPeeking()
        }

        menu.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)
        val density = resources.displayMetrics.density
        val (screenWidth, screenHeight) = getScreenDimensions()
        val menuW = menu.measuredWidth.coerceAtLeast((160 * density).toInt())
        val menuH = menu.measuredHeight.coerceAtLeast((34 * density).toInt())
        val pokoW = pokoView?.width ?: petSizePx
        val pokoH = pokoView?.height ?: petSizePx

        val gap = (6 * density).toInt()
        val targetX = if (pParams.x < screenWidth / 2) {
            (pParams.x + pokoW + gap).coerceAtMost(screenWidth - menuW - (4 * density).toInt())
        } else {
            (pParams.x - menuW - gap).coerceAtLeast((4 * density).toInt())
        }

        val preferredY = pParams.y + (pokoH - menuH) / 2
        val (minY, maxY) = getSafeVerticalBounds(density, screenHeight, menuH)
        val targetY = preferredY.coerceIn(minY, maxY)

        mParams.x = targetX
        mParams.y = targetY

        if (!isActionMenuAttached) {
            try {
                windowManager?.addView(menu, mParams)
                isActionMenuAttached = true
            } catch (_: Exception) {}
        } else {
            try {
                windowManager?.updateViewLayout(menu, mParams)
            } catch (_: Exception) {}
        }

        menu.visibility = View.VISIBLE
        menu.alpha = 0f
        menu.scaleX = 0.7f
        menu.scaleY = 0.7f
        menu.animate()
            .alpha(1f)
            .scaleX(1f)
            .scaleY(1f)
            .setDuration(220)
            .setInterpolator(OvershootInterpolator(1.2f))
            .start()

        hideActionMenuRunnable?.let { mainHandler.removeCallbacks(it) }
        hideActionMenuRunnable = Runnable {
            hideActionMenu()
        }
        mainHandler.postDelayed(hideActionMenuRunnable!!, 3600)
    }

    private fun hideActionMenu(animated: Boolean = true) {
        hideActionMenuRunnable?.let { mainHandler.removeCallbacks(it) }
        val menu = actionMenuView ?: return
        if (menu.visibility != View.VISIBLE) return

        if (animated) {
            menu.animate()
                .alpha(0f)
                .scaleX(0.75f)
                .scaleY(0.75f)
                .setDuration(180)
                .withEndAction {
                    menu.visibility = View.GONE
                    removeActionMenuWindow()
                }
                .start()
        } else {
            menu.animate().cancel()
            menu.visibility = View.GONE
            removeActionMenuWindow()
        }
    }

    /**
     * 把快捷菜单窗口真正从 WindowManager 上摘下来。
     * 之前只是把 View 置为 GONE 却始终挂着窗口，白占系统窗口资源，
     * 也让"菜单是否已添加"难以判断（重复 addView 会抛异常被静默吞掉，菜单再也不会出现）。
     */
    private fun removeActionMenuWindow() {
        if (!isActionMenuAttached) return
        val menu = actionMenuView ?: return
        try {
            windowManager?.removeView(menu)
        } catch (_: Exception) {}
        isActionMenuAttached = false
    }

    private fun handleDesktopPet() {
        hideActionMenu()
        haptic(Companion.HAPTIC_PET_BODY)
        playSound("meow")
        pokoView?.onPetTapped()
        pokoView?.executeAction(PokoPetView.PetAction.HAPPY_BOUNCE)
        showCustomSpeechBubble("呼噜噜... 收到主人的摸摸啦，好舒服呀~ 🐾💕")
    }

    /** 回小窝：双击手势让位给"逗猫"后，回 App 的入口挪到这里 */
    private fun handleDesktopHome() {
        hideActionMenu(animated = false)
        haptic(Companion.HAPTIC_MENU)
        openMainActivity()
    }

    // ---------- 小鱼干投喂小游戏 ----------
    /**
     * 启动投喂小游戏：弹出一只能用手指拖着走的小鱼干，
     * 把它送到猫嘴边才算喂到 —— 拖偏了猫会扑空、喵一声不服气。
     * 把"喂食 +15"这种纯数值操作，变成一个有参与感的小仪式。
     */
    private fun startFeedingGame() {
        if (isFoodGameActive) return
        val mParams = actionMenuParams ?: return
        val density = resources.displayMetrics.density

        val fish = TextView(this).apply {
            text = "🐟"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 26f)
            gravity = Gravity.CENTER
            setPadding(
                (6 * density).toInt(), (2 * density).toInt(),
                (6 * density).toInt(), (2 * density).toInt()
            )
            visibility = View.VISIBLE
        }

        val fParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            overlayType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = mParams.x
            y = (mParams.y - (46 * density).toInt()).coerceAtLeast(0)
        }

        var fishStartX = fParams.x
        var fishStartY = fParams.y
        var downRawX = 0f
        var downRawY = 0f

        fish.setOnTouchListener { _, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    fishStartX = fParams.x
                    fishStartY = fParams.y
                    downRawX = ev.rawX
                    downRawY = ev.rawY
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    fParams.x = (fishStartX + (ev.rawX - downRawX)).toInt()
                    fParams.y = (fishStartY + (ev.rawY - downRawY)).toInt()
                    try {
                        windowManager?.updateViewLayout(fish, fParams)
                    } catch (_: Exception) {}
                    true
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    resolveFeeding(fish, fParams)
                    true
                }
                else -> false
            }
        }

        try {
            windowManager?.addView(fish, fParams)
            foodWindowView = fish
            foodWindowParams = fParams
            isFoodGameActive = true
            hideActionMenu(animated = false)
            showCustomSpeechBubble("把小鱼干拖到我嘴边吧～ 我想吃！🐟")
        } catch (_: Exception) {
            // 弹不出小鱼干就退回普通投喂，保证功能不至于完全不可用
            handleNotificationFeed()
        }
    }

    /** 小鱼干松手：够到嘴边就喂到，够不到就扑空 */
    private fun resolveFeeding(fish: View, fParams: WindowManager.LayoutParams) {
        val pParams = pokoParams ?: return
        val sizePx = petSizePx
        val density = resources.displayMetrics.density
        // 猫嘴大致在窗口中心偏上
        val mouthX = pParams.x + sizePx / 2
        val mouthY = pParams.y + (sizePx * 0.32f).toInt()
        val fishX = fParams.x + (12 * density).toInt()
        val fishY = fParams.y + (12 * density).toInt()
        val dx = (fishX - mouthX).toFloat()
        val dy = (fishY - mouthY).toFloat()
        val dist = sqrt(dx * dx + dy * dy)

        if (dist <= sizePx * 0.85f) {
            // 喂到了：结算饱食度，猫开心蹦跶
            removeFoodWindow()
            applyFeeding(15)
            pokoView?.executeAction(PokoPetView.PetAction.HAPPY_BOUNCE)
            pokoView?.onPetTapped()
            playSound("purr")
            haptic(Companion.HAPTIC_FEED)
            showCustomSpeechBubble("呜姆～ 小鱼干真香！饱食度 +15 🐟💕")
        } else {
            // 喂偏了：猫扑空，歪着头盯着小鱼干看
            pokoView?.executeAction(PokoPetView.PetAction.HEAD_TILT)
            pokoView?.setGazeTarget((fishX - pParams.x).toFloat(), (fishY - pParams.y).toFloat())
            mainHandler.postDelayed({ pokoView?.clearGazeTarget() }, 3000)
            playSound("meow")
            showCustomSpeechBubble("喵呜～ 小鱼干在哪儿呢？再靠近我一点嘛 🐟")
            animateFoodAway(fish, fParams)
        }
    }

    /** 小鱼干飘走后自动移除 */
    private fun animateFoodAway(fish: View, fParams: WindowManager.LayoutParams) {
        val startY = fParams.y
        val lift = (36 * resources.displayMetrics.density).toInt()
        ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 420
            interpolator = DecelerateInterpolator(1.6f)
            addUpdateListener { anim ->
                val f = anim.animatedValue as Float
                fParams.y = (startY - lift * f).toInt()
                try {
                    windowManager?.updateViewLayout(fish, fParams)
                } catch (_: Exception) {}
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    removeFoodWindow()
                }
            })
        }.start()
    }

    private fun removeFoodWindow() {
        val fish = foodWindowView ?: return
        try {
            windowManager?.removeView(fish)
        } catch (_: Exception) {}
        foodWindowView = null
        foodWindowParams = null
        isFoodGameActive = false
    }

    private fun handleDesktopDismiss() {
        hideActionMenu(animated = false)
        haptic(Companion.HAPTIC_DISMISS)
        hidePetToTray()
    }

    /**
     * 把波可"收进通知栏"：桌面上不再显示，但服务与通知都留着，
     * 用户点通知栏的「召回波可」就能立刻把它叫回桌面。
     *
     * 用 setVisibility(GONE) 而不是 removeView：
     * 窗口对象和坐标原封不动，召回时只要改回 VISIBLE 就行，
     * 彻底避开"重新 addView 可能抛异常 / 位置丢失"这一类窗口生命周期问题。
     */
    private fun hidePetToTray() {
        val view = pokoView ?: return
        cancelEdgePeeking()
        isPeeking = false
        view.visibility = View.GONE
        isPetRecalled = true
        // 通知栏按钮要跟着变（召回 / 关闭），所以重新发一次前台通知
        startAsForeground()
        Toast.makeText(this, "🐾 波可收进通知栏啦，点通知里的「召回」就能叫它回来～", Toast.LENGTH_LONG).show()
    }

    /**
     * 把收进通知栏的波可重新叫回桌面。
     */
    private fun recallPet() {
        val view = pokoView ?: return
        isPetRecalled = false
        // 显隐统一交给 refreshPetVisibility 决定（App 在前台时依然不显示悬浮猫）
        refreshPetVisibility()
        view.alpha = petOpacity
        // 通知栏按钮切回常规的一组
        startAsForeground()
        haptic(Companion.HAPTIC_PET_HEAD)
        playSound("meow")
        view.onPetTapped()
        view.executeAction(PokoPetView.PetAction.HAPPY_BOUNCE)
        showCustomSpeechBubble("我回来啦！主人是不是想我了呀～ 💕")
    }

    private fun showSpeechBubble() {
        val hunger = readPetState().hunger
        if (hunger < 35 && Math.random() > 0.4) {
            val hungryQuotes = listOf(
                "肚子有点咕噜咕噜了喵... 主人，小鱼干在呼唤我~ 🐟",
                "波可饿瘪肚肚了，可以下拉通知栏喂我吃好吃的嘛~ 🐾",
                "喵呜~ 想吃小零食了，主人摸摸我或者投喂一下嘛~ ✨"
            )
            showCustomSpeechBubble(hungryQuotes.random())
            return
        }

        val action = pokoView?.currentAction
        val greetings = when (action) {
            PokoPetView.PetAction.STRETCH -> listOf(
                "喵呼~ 舒舒服服伸个大懒腰，浑身充满力量！(ฅ'ω'ฅ)",
                "呼哇~ 打个甜甜的大哈欠，主人也活动一下身体嘛~ ✨"
            )
            PokoPetView.PetAction.WASH_FACE -> listOf(
                "舔爪爪洗脸中... 今天波可也是屏幕前最靓的猫猫！🐾",
                "认真洗脸搓耳朵~ 感觉今天会发生好事呢！🌸"
            )
            PokoPetView.PetAction.HEAD_TILT -> listOf(
                "歪头好奇萌看~ 主人正在手机上忙什么神奇的大事呀？(o.o)",
                "眨眨眼~ 歪着脑袋看主人，感觉主人更帅气/漂亮啦！💕"
            )
            PokoPetView.PetAction.HAPPY_BOUNCE -> listOf(
                "原地欢脱小蹦跳！见到主人心情超级大好！✨(≧∇≦)",
                "开心蹦跶~ 传递元气小星星，主人接住啦！🌟"
            )
            PokoPetView.PetAction.KNEADING -> listOf(
                "呼噜呼噜... 软糯小爪踩踩奶，好舒服好安心呀~ 🐾",
                "在主人桌面上踏踏步，送你一整天的软绵绵治愈~ 💕"
            )
            PokoPetView.PetAction.SLEEPY -> listOf(
                "困困打个小瞌睡... 趴在桌角眯一会儿，Zzz...",
                "小脑袋一点一点... 梦里也有好多小鱼干和主人呢~ 🐟"
            )
            PokoPetView.PetAction.SPIN_TAIL -> listOf(
                "呜哇！我的小尾巴别跑呀~ 追尾巴转圈圈中！(≧∇≦)ﾉ🌀",
                "原地 360 度打转转！哎呀呀... 转得有点晕呼呼了喵~ ⭐"
            )
            PokoPetView.PetAction.WALKING -> listOf(
                "踩着小碎步在屏幕边缘溜达溜达~ 巡视主人的手机领地！🐾",
                "吧唧吧唧踏步漫步中... 散步有益身体健康喵~ ✨"
            )
            else -> listOf(
                "喵呜~ 主人，波可随时在屏幕边陪着你呢！(ฅ'ω'ฅ)",
                "咕噜咕噜... 戳戳小肚腩好舒服~ 💕",
                "主人看屏幕累了吗？眨眨眼喝口水休息一下吧！✨",
                "双击我可以原地转圈圈哦！🐾",
                "今天也是元气满满的一天，波可最喜欢主人啦！🌸",
                "蹭蹭屏幕~ 感觉主人今天超级棒！✨"
            )
        }
        showCustomSpeechBubble(greetings.random())
    }

    private fun showCustomSpeechBubble(text: String) {
        // 悬浮猫隐身时 (小窝在前台 / 息屏) 不弹气泡
        if (isAppForeground || !screenOn) return
        val bubble = bubbleView ?: return
        val bParams = bubbleParams ?: return
        val pParams = pokoParams ?: return
        if (isPeeking) {
            restoreFromPeeking()
        }

        bubble.text = text

        val density = resources.displayMetrics.density
        val (screenWidth, screenHeight) = getScreenDimensions()

        // ⚠️ 必须用 AT_MOST 而不是 UNSPECIFIED 来测量：
        // TextView 的 maxWidth 在 UNSPECIFIED 下是不生效的，
        // 长文案会把气泡撑到超出屏幕宽度。AT_MOST 才会让它按可用宽度换行。
        val maxBubbleW = ((screenWidth * 0.62f).toInt())
            .coerceAtMost((220 * density).toInt())
            .coerceAtLeast((120 * density).toInt())
        bubble.measure(
            View.MeasureSpec.makeMeasureSpec(maxBubbleW, View.MeasureSpec.AT_MOST),
            View.MeasureSpec.UNSPECIFIED
        )

        val bubbleW = bubble.measuredWidth
        val bubbleH = bubble.measuredHeight
        val pokoW = pokoView?.width ?: petSizePx

        val preferredY = pParams.y - bubbleH - (6 * density).toInt()
        val minY = (28 * density).toInt()
        bParams.x = (pParams.x + (pokoW - bubbleW) / 2).coerceIn((10 * density).toInt(), (screenWidth - bubbleW - (10 * density).toInt()).coerceAtLeast(0))
        bParams.y = if (preferredY < minY) {
            // 贴近屏幕顶部时，气泡智能展示在宠物下方，避免遮挡宠物
            (pParams.y + pokoW + (6 * density).toInt()).coerceAtMost(screenHeight - bubbleH - (16 * density).toInt())
        } else {
            preferredY
        }

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
                    scheduleEdgePeeking(!(pokoView?.facingLeft ?: true))
                }
                .start()
        }
        mainHandler.postDelayed(hideBubbleRunnable!!, 3200)
    }

    private fun handleNotificationPet() {
        haptic(Companion.HAPTIC_TAP)
        playSound("meow")
        pokoView?.onPetTapped()
        showCustomSpeechBubble("呼噜噜... 收到主人在通知栏的抚摸！💕(ฅ'ω'ฅ)")
    }

    private fun handleNotificationFeed() {
        haptic(Companion.HAPTIC_FEED)
        playSound("purr")
        pokoView?.onPetTapped()
        pokoView?.executeAction(PokoPetView.PetAction.HAPPY_BOUNCE)

        // 双向持久化同步饱食度与亲密度
        applyFeeding(15)

        showCustomSpeechBubble("吧唧吧唧~ 收到主人投喂的小鱼干！饱食度+15 🐟✨")
    }

    /**
     * 宠物的实时状态快照。
     *
     * 数值都已经按"距上次结算过去了多久"补算过，
     * 所以桌面悬浮宠读到的就是此刻的真实状态 —— App 关着它也一样会饿、会无聊。
     *
     * 桌面小组件（`PokoWidgetProvider`）也复用这一个快照，
     * 保证小组件上显示的状态和桌面猫看到的状态是同一份。
     */
    data class PetState(
        val hunger: Int,
        val mood: Int,
        val energy: Int,
        val cleanliness: Int,
        val intimacy: Int,
        val skinId: String,
        val petName: String,
        val enableSound: Boolean,
    ) {
        /**
         * 桌面小组件上显示的大表情。
         *
         * 阈值与 [PokoPetView] 的状态徽标完全一致（同一组常量），
         * 所以小组件和桌面猫不会出现"一个说饿一个说不饿"的矛盾。
         */
        val emoji: String
            get() = when {
                hunger < PokoPetView.BADGE_THRESHOLD_HUNGER -> "🍖"
                cleanliness < PokoPetView.BADGE_THRESHOLD_CLEAN -> "🧼"
                energy < PokoPetView.BADGE_THRESHOLD_ENERGY -> "💤"
                mood < PokoPetView.BADGE_THRESHOLD_MOOD -> "😿"
                else -> "😺"
            }

        /** 桌面小组件上显示的状态文案 */
        val statusLine: String
            get() = when {
                hunger < PokoPetView.BADGE_THRESHOLD_HUNGER -> "肚子饿了，想吃小鱼干～"
                cleanliness < PokoPetView.BADGE_THRESHOLD_CLEAN -> "身上脏兮兮的，需要搓澡"
                energy < PokoPetView.BADGE_THRESHOLD_ENERGY -> "困得睁不开眼，眯一会儿…"
                mood < PokoPetView.BADGE_THRESHOLD_MOOD -> "有点小情绪，陪我玩会儿嘛"
                else -> "心情不错，陪你待机～"
            }
    }

    /**
     * 读取宠物状态：只解析一次 JSON，并按 stateSavedAt 补算离线期间的衰减。
     *
     * 与 Dart 侧 PetModel 的约定完全对称：
     *   - 谁写盘谁盖 stateSavedAt 时间戳
     *   - 读取方按 (now - stateSavedAt) 补算
     * 这样同一段时间只会被扣一次，App 里和桌面上的波可状态始终一致。
     *
     * ⚠️ 字段名必须是 `mood`（Dart 侧 PetModel 用的就是 mood）。
     * 历史上原生侧写的是 `happiness`，Dart 侧根本不认这个 key，
     * 导致心情在两端彻底断链：桌面永远读到兜底值，App 里喂食也涨不上去。
     */
    private fun readPetState(): PetState = readStateSnapshot(this)

    /**
     * 给猫加餐：写入饱食度 / 心情 / 亲密度，并同步到悬浮猫的表情与行为权重。
     * 通知栏投喂与拖拽投喂共用这一份结算逻辑。
     */
    private fun applyFeeding(hungerDelta: Int) {
        try {
            val prefs = getSharedPreferences(PREFS_PET, Context.MODE_PRIVATE)
            val rawJson = prefs.getString(KEY_PET_DATA, null)
            if (!rawJson.isNullOrBlank()) {
                val json = JSONObject(rawJson)
                val elapsed = elapsedDecaySeconds(json.optLong("stateSavedAt", 0L))

                // 先把离线期间的衰减补上再结算投喂，
                // 这样写回盘里的数值就是"此刻"的真实值，不会把 App 攒下的状态抹掉
                fun decayed(key: String, fallback: Int): Double {
                    val base = json.optDouble(key, fallback.toDouble())
                    val rate = (DECAY_RATES[key] ?: 0f).toDouble()
                    return (base - rate * elapsed).coerceIn(0.0, 100.0)
                }

                json.put("hunger", (decayed("hunger", 80) + hungerDelta).coerceIn(0.0, 100.0))
                json.put("mood", (decayed("mood", 80) + 10.0).coerceIn(0.0, 100.0))
                json.put("energy", decayed("energy", 80))
                json.put("cleanliness", decayed("cleanliness", 80))
                json.put("intimacy", (json.optInt("intimacy", 50) + 5).coerceAtMost(100))
                // 写盘即盖时间戳：这份值是"此刻"的真实值
                json.put("stateSavedAt", System.currentTimeMillis())
                // 旧版本误写过 `happiness`（Dart 侧不认这个 key），顺手清掉别留在存档里
                json.remove("happiness")
                prefs.edit().putString(KEY_PET_DATA, json.toString()).apply()
            }
        } catch (_: Exception) {}

        syncPetMood()
    }

    /**
     * 把饱食度 / 心情 / 体力 / 洁净度同步给悬浮猫：
     * 状态会直接影响表情与自主行为的权重，
     * 饿的时候它会更多地东张西望找吃的，而不是照常卖萌。
     */
    private fun syncPetMood() {
        val state = readPetState()
        val view = pokoView ?: return
        view.hungerLevel = state.hunger
        view.happinessLevel = state.mood
        view.energyLevel = state.energy
        view.cleanlinessLevel = state.cleanliness
        // 状态徽标：让"它其实饿了"在桌面上一眼可见（一切正常时不显示）
        view.refreshStateBadge()
        // 桌面小组件也跟着刷新：小组件读的是同一份快照，所以显示的一定一致
        PokoWidgetProvider.refreshAll(this)
        // 音效开关也一起同步：用户在 App 里关掉声音，桌面上的波可立刻闭嘴
        isSoundEnabled = state.enableSound
        // 状态刚跌破阈值时主动说一声，补上"时间过去 → 状态变差"的反馈闭环
        maybeBroadcastStateChange(state)
    }

    // ---------- 状态变化播报 ----------

    /**
     * 上一次同步时各维度"是否处于异常"的标记。
     *
     * 顺序与 [stateAlertOrder] 一致：饥饿 / 清洁 / 能量 / 心情。
     * null 表示还没同步过（服务刚起来）。
     */
    private var lastStateAlerts: IntArray? = null

    /** 上次播报的时间戳，用于节流 */
    private var lastStateBroadcastAt = 0L

    /**
     * 状态刚变差时主动冒个泡。
     *
     * 背景：状态衰减（尤其"App 关着 8 小时回来猫饿扁了"）算得再对，
     * 用户看不见因果 —— 桌上只是一只蔫掉的猫。这里在状态**跌破阈值的那一刻**
     * 让它自己说一声，因果链才闭合。
     *
     * 阈值与 PokoPetView 的状态徽标完全一致（同一组常量），
     * 否则会出现"徽标亮了但没播报"的割裂感。
     */
    private fun maybeBroadcastStateChange(state: PetState) {
        val now = System.currentTimeMillis()
        if (now - lastStateBroadcastAt < STATE_BROADCAST_COOLDOWN_MS) return

        val alerts = intArrayOf(
            if (state.hunger < PokoPetView.BADGE_THRESHOLD_HUNGER) 1 else 0,
            if (state.cleanliness < PokoPetView.BADGE_THRESHOLD_CLEAN) 1 else 0,
            if (state.energy < PokoPetView.BADGE_THRESHOLD_ENERGY) 1 else 0,
            if (state.mood < PokoPetView.BADGE_THRESHOLD_MOOD) 1 else 0,
        )

        val prev = lastStateAlerts
        if (prev == null) {
            // 第一次同步：状态已经很差就直接说一声（用户离开很久回来正是这种场景）
            lastStateAlerts = alerts
            var firstBad = -1
            for (i in alerts.indices) {
                if (alerts[i] == 1) {
                    firstBad = i
                    break
                }
            }
            if (firstBad >= 0) {
                lastStateBroadcastAt = now
                showCustomSpeechBubble(stateAlertLine(firstBad))
            }
            return
        }

        for (idx in alerts.indices) {
            // 只播报"刚刚跌破阈值"的那一项，已经异常的不重复说
            if (alerts[idx] == 1 && prev[idx] == 0) {
                lastStateAlerts = alerts
                lastStateBroadcastAt = now
                showCustomSpeechBubble(stateAlertLine(idx))
                return
            }
        }
        lastStateAlerts = alerts
    }

    /** 状态异常时说的话（idx 与 stateAlertOrder 一致） */
    private fun stateAlertLine(idx: Int): String = when (idx) {
        0 -> "肚子咕咕叫啦…主人我好饿呀，想吃小鱼干～ 🐟"
        1 -> "身上脏兮兮的…主人帮我搓搓澡好不好嘛～ 🧼"
        2 -> "困得睁不开眼啦…让我先眯一小会儿 zzz… 💤"
        else -> "有点想主人了…今天都不理我，是不是把我忘了呀… 🥺"
    }

    // ---------- 夜间模式 ----------

    /** App 推送过来的昼夜状态（null 表示还没收到过推送） */
    private var appNightMode: Boolean? = null

    /** 当前是否处于夜间配色 */
    private var isNightMode: Boolean = false

    /**
     * 判定当前该不该用夜间配色。
     *
     * 优先用 App 推送的值 —— App 内部按真实太阳节律（SolarService）算昼夜，
     * 比系统深色模式准得多；还没收到过推送时退回系统深色模式，
     * 保证深夜桌面上不至于亮得刺眼。
     */
    private fun resolveNightMode(): Boolean {
        appNightMode?.let { return it }
        return try {
            val uiMode = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
            uiMode?.nightMode == UiModeManager.MODE_NIGHT_YES
        } catch (_: Exception) {
            false
        }
    }

    /** 把夜间配色应用到悬浮猫 */
    private fun applyNightMode(enabled: Boolean) {
        isNightMode = enabled
        // 注意：这里直接赋值属性，而不是调 view.setNightMode(enabled) ——
        // PokoPetView 的 public 属性 isNightMode 的隐式 setter 就是 setNightMode，
        // 那边不能再定义同名函数（JVM 签名会撞车）。
        pokoView?.isNightMode = enabled
    }

    /** 接收 App 推送的昼夜状态 */
    fun applyNightModeFromApp(enabled: Boolean) {
        appNightMode = enabled
        applyNightMode(enabled)
    }

    /**
     * 主动搭话调度：长时间没人理它时，波可会自己冒泡说句话，
     * 把"单向表演"变成"会主动找你"的陪伴感。
     */
    private val autoChatRunnable = object : Runnable {
        override fun run() {
            if (screenOn && !isAppForeground && enableAutoChat) {
                val now = System.currentTimeMillis()
                val idleMs = now - lastInteractionAt
                val sinceChat = now - lastAutoChatAt
                if (idleMs > AUTO_CHAT_IDLE_MS && sinceChat > AUTO_CHAT_IDLE_MS) {
                    lastAutoChatAt = now
                    showCustomSpeechBubble(autoChatLine())
                }
                // 顺带刷新一次状态，桌面上喂食后表情也能跟上
                syncPetMood()
            }
            mainHandler.postDelayed(this, AUTO_CHAT_INTERVAL_MS)
        }
    }

    /** 主动搭话的话术：按当前状态挑一句 */
    private fun autoChatLine(): String {
        val state = readPetState()
        val hunger = state.hunger
        val mood = state.mood
        return when {
            hunger < 35 -> "主人～小鱼干告急啦，我肚子已经咕咕叫了 🐟🥺"
            mood < 40 -> "有点无聊喵… 摸摸我好不好？🥺"
            else -> listOf(
                "主人好久没来看我啦，我一直在桌上乖乖等着呢～ 💕",
                "偷偷看一眼：今天也要开开心心的哦 ✨",
                "我一直都在这里哦，想我了就点我一下～ 🐾",
                "在忙吗？我就安静待一会儿，你忙完再来看我 🐾"
            ).random()
        }
    }

    private fun initSoundEffects() {
        try {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            soundPool = SoundPool.Builder()
                .setMaxStreams(2)
                .setAudioAttributes(audioAttributes)
                .build()

            try {
                val afdMeow = assets.openFd("flutter_assets/assets/audio/meow_soft.wav")
                soundMeowId = soundPool?.load(afdMeow, 1) ?: 0
            } catch (_: Exception) {}

            try {
                val afdPurr = assets.openFd("flutter_assets/assets/audio/purr.wav")
                soundPurrId = soundPool?.load(afdPurr, 1) ?: 0
            } catch (_: Exception) {}
        } catch (_: Exception) {}
    }

    private fun playSound(type: String) {
        if (!isSoundEnabled || soundPool == null) return
        val soundId = if (type == "purr") soundPurrId else soundMeowId
        if (soundId > 0) {
            soundPool?.play(soundId, 0.7f, 0.7f, 1, 0, 1.0f)
        }
    }

    private fun updateBubblePosition() {
        val bubble = bubbleView ?: return
        val bParams = bubbleParams ?: return
        val pParams = pokoParams ?: return
        if (bubble.visibility != View.VISIBLE || bubble.parent == null) return

        val density = resources.displayMetrics.density
        val (screenWidth, screenHeight) = getScreenDimensions()
        val bubbleW = bubble.width.coerceAtLeast((100 * density).toInt())
        val bubbleH = bubble.height.coerceAtLeast((36 * density).toInt())
        val pokoW = pokoView?.width ?: petSizePx

        val preferredY = pParams.y - bubbleH - (6 * density).toInt()
        val minY = (28 * density).toInt()
        val newX = (pParams.x + (pokoW - bubbleW) / 2).coerceIn((10 * density).toInt(), (screenWidth - bubbleW - (10 * density).toInt()).coerceAtLeast(0))
        val newY = if (preferredY < minY) {
            (pParams.y + pokoW + (6 * density).toInt()).coerceAtMost(screenHeight - bubbleH - (16 * density).toInt())
        } else {
            preferredY
        }

        // 位置没变就别再动窗口：拖拽时每帧都会调到这里，
        // 一次多余的 updateViewLayout 就多一次跨进程窗口重排
        if (newX == bParams.x && newY == bParams.y) return

        bParams.x = newX
        bParams.y = newY
        try {
            windowManager?.updateViewLayout(bubble, bParams)
        } catch (_: Exception) {}
    }

    private fun openMainActivity() {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        if (launchIntent != null) {
            // 先让悬浮猫隐身，避免 Activity 拉起动画期间与 App 内的波可重叠成两只
            isAppForeground = true
            refreshPetVisibility()
            try {
                startActivity(launchIntent)
            } catch (e: Exception) {
                Log.e(TAG, "拉起主应用失败", e)
                isAppForeground = false
                refreshPetVisibility()
            }
        }
    }

    private fun loadSavedPetConfig(): Pair<String, String> {
        val state = readPetState()
        isSoundEnabled = state.enableSound
        return Pair(state.skinId, state.petName)
    }

    /**
     * 宠物存档变更监听。
     *
     * Dart 侧的 shared_preferences 插件和原生侧共用同一个 `FlutterSharedPreferences` 文件，
     * 所以 App 里一写盘（喂食、换装、改音效开关），这里立刻就能收到通知，
     * 桌面悬浮宠的状态与表情不必再等 60 秒的巡检。
     */
    private val petDataChangeListener =
        SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == KEY_PET_DATA) {
                syncPetMood()
            }
        }

    /** 注册宠物存档监听（服务启动时调用） */
    private fun registerPetDataListener() {
        try {
            getSharedPreferences(PREFS_PET, Context.MODE_PRIVATE)
                .registerOnSharedPreferenceChangeListener(petDataChangeListener)
        } catch (_: Exception) {}
    }

    /** 注销宠物存档监听（服务销毁时调用，避免泄漏） */
    private fun unregisterPetDataListener() {
        try {
            getSharedPreferences(PREFS_PET, Context.MODE_PRIVATE)
                .unregisterOnSharedPreferenceChangeListener(petDataChangeListener)
        } catch (_: Exception) {}
    }

    /**
     * 读取停靠偏好：左侧/右侧、纵向比例、横向比例。
     * 横向比例为 -1f 表示用户尚未自由放置过波可，此时沿用贴边停靠规则。
     */
    private fun loadSavedDockConfig(): Triple<Boolean, Float, Float> {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isLeft = prefs.getBoolean("flutter.poko_dock_left", false)
            val yRatio = prefs.getFloat("flutter.poko_dock_y_ratio", 0.45f).coerceIn(0.1f, 0.85f)
            val xRatio = prefs.getFloat("flutter.poko_dock_x_ratio", -1f)
            Triple(isLeft, yRatio, xRatio)
        } catch (_: Exception) {
            Triple(false, 0.45f, -1f)
        }
    }

    /**
     * 保存停靠偏好：横向位置按比例持久化，波可下次启动仍停在用户放的地方，
     * 而不是被强行拉回屏幕边缘（否则用户会觉得"拖了等于没拖"）。
     */
    private fun saveDockPreference(isLeft: Boolean, currentX: Int, currentY: Int) {
        try {
            val (screenWidth, screenHeight) = getScreenDimensions()
            val density = resources.displayMetrics.density
            val sizePx = petSizePx
            val yRatio = if (screenHeight > 0) (currentY.toFloat() / screenHeight.toFloat()).coerceIn(0.1f, 0.85f) else 0.45f
            val travelRange = (screenWidth - sizePx).coerceAtLeast(1)
            val xRatio = (currentX.toFloat() / travelRange.toFloat()).coerceIn(0f, 1f)
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean("flutter.poko_dock_left", isLeft)
                .putFloat("flutter.poko_dock_y_ratio", yRatio)
                .putFloat("flutter.poko_dock_x_ratio", xRatio)
                .apply()
        } catch (_: Exception) {}
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        cancelEdgePeeking()
        isPeeking = false
        hideActionMenu(animated = false)
        // 旋转 / 分屏 / 折叠展开之后屏幕尺寸与系统栏边距都变了，缓存必须失效
        invalidateScreenCache()
        val params = pokoParams ?: return
        val view = pokoView ?: return
        view.alpha = 1.0f
        view.peekOffsetX = 0f
        val density = resources.displayMetrics.density
        val sizePx = petSizePx
        val (screenWidth, screenHeight) = getScreenDimensions()
        val edgeThreshold = (4 * density).toInt()

        // 手机屏幕横竖屏旋转或分屏时：按比例还原用户放置的横向位置，
        // 只有从未自由放置过的波可才回退到贴边停靠，避免旋转一次就被拽回边缘
        val isLeft = !view.facingLeft
        val (_, _, savedXRatio) = loadSavedDockConfig()
        val maxX = (screenWidth - sizePx).coerceAtLeast(0)
        params.x = if (savedXRatio >= 0f) {
            (maxX * savedXRatio).toInt().coerceIn(0, maxX)
        } else {
            if (isLeft) edgeThreshold else (screenWidth - sizePx - edgeThreshold).coerceAtLeast(0)
        }
        val (minY, maxY) = getSafeVerticalBounds(density, screenHeight, sizePx)
        params.y = params.y.coerceIn(minY, maxY)

        try {
            windowManager?.updateViewLayout(view, params)
            updateBubblePosition()
        } catch (_: Exception) {}

        scheduleEdgePeeking(isLeft)
    }

    /**
     * 重新计算系统栏避让边距。
     *
     * 原来的实现在 [getSafeVerticalBounds] 里每次都做一遍
     * `resources.getIdentifier(...)` + `getDimensionPixelSize(...)`，
     * 而拖拽时这个函数每帧都会被调到 —— 资源表查找在 60fps 下是实打实的开销。
     * 现在只在启动与屏幕配置变化时算一次。
     */
    private fun refreshSafeInsets() {
        val density = resources.displayMetrics.density
        var topInset = (24 * density).toInt()
        var bottomInset = (36 * density).toInt()

        // 动态获取系统状态栏真实高度，避让各类挖孔与异形屏
        val statusResId = resources.getIdentifier("status_bar_height", "dimen", "android")
        if (statusResId > 0) {
            val h = resources.getDimensionPixelSize(statusResId)
            if (h > topInset) topInset = h + (4 * density).toInt()
        }

        // 动态获取系统底部导航栏/手势条高度
        val navResId = resources.getIdentifier("navigation_bar_height", "dimen", "android")
        if (navResId > 0) {
            val h = resources.getDimensionPixelSize(navResId)
            if (h > (16 * density).toInt()) bottomInset = h + (8 * density).toInt()
        }

        safeTopInset = topInset
        safeBottomInset = bottomInset
    }

    /**
     * 宠物可停靠的纵向范围（避开状态栏与手势条）。
     * 边距来自 [refreshSafeInsets] 的缓存，不再每帧做资源表查找。
     */
    private fun getSafeVerticalBounds(density: Float, screenHeight: Int, sizePx: Int): Pair<Int, Int> {
        if (safeTopInset <= 0) refreshSafeInsets()
        val minY = safeTopInset
        val maxY = (screenHeight - sizePx - safeBottomInset).coerceAtLeast(minY)
        return Pair(minY, maxY)
    }

    private fun isLowPowerMode(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
        if (pm?.isPowerSaveMode == true) return true
        return try {
            val batteryIntent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = batteryIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            if (level > 0 && scale > 0) {
                (level * 100 / scale) <= 15
            } else {
                false
            }
        } catch (_: Exception) {
            false
        }
    }

    private fun scheduleEdgePeeking(isLeft: Boolean) {
        cancelEdgePeeking()
        if (!screenOn || isAppForeground) return
        // 设置里关掉探头就永远不探头
        if (!enablePeeking) return

        // 只有真正停在屏幕左右边缘的波可才会探头避让；
        // 自由放在屏幕中间的波可保持完整可见，不该被边缘动效拽走
        if (!isPetDockedAtEdge()) return

        peekingRunnable = Runnable {
            if (!screenOn || isAppForeground || isStrolling || hasTouchDown) return@Runnable
            val params = pokoParams ?: return@Runnable
            val view = pokoView ?: return@Runnable
            val (screenWidth, _) = getScreenDimensions()
            val density = resources.displayMetrics.density
            val sizePx = petSizePx
            val edgeThreshold = (4 * density).toInt()

            // 探头前先把窗口贴到对应边缘；探头过程只靠"窗口内绘制偏移"完成，窗口不再移动
            val dockedX = if (isLeft) {
                edgeThreshold
            } else {
                (screenWidth - sizePx - edgeThreshold).coerceAtLeast(0)
            }
            if (params.x != dockedX) {
                params.x = dockedX
                try {
                    windowManager?.updateViewLayout(view, params)
                } catch (_: Exception) {}
            }

            // 向屏幕边缘外侧避让收纳 32%：左侧边缘向左藏、右侧边缘向右藏
            // 偏移发生在绘制层，窗口坐标不变 —— 拖拽起点与手指位移始终一一对应
            val peekOffset = if (isLeft) (-sizePx * 0.32f) else (sizePx * 0.32f)

            peekAnimator?.cancel()
            peekAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = 380
                interpolator = DecelerateInterpolator()
                addUpdateListener { anim ->
                    val f = anim.animatedValue as Float
                    view.peekOffsetX = peekOffset * f
                    view.alpha = petOpacity * (1f - f * 0.32f) // 半透明淡化至 0.68f
                }
                addListener(object : AnimatorListenerAdapter() {
                    // Android 在 cancel() 时会先回调 onAnimationCancel 再回调 onAnimationEnd，
                    // 用本地标记区分"探头完成"与"被中途取消"；
                    // 否则每次按下宠物都会被误判成探头状态并强行拉回边缘。
                    // 注意：不能用 Animator.isCanceled 判定 —— 它不是公开 SDK API，会编译失败。
                    private var cancelled = false

                    override fun onAnimationCancel(animation: Animator) {
                        cancelled = true
                    }

                    override fun onAnimationEnd(animation: Animator) {
                        isPeeking = !cancelled
                    }
                })
            }
            peekAnimator?.start()
        }
        mainHandler.postDelayed(peekingRunnable!!, 5500)
    }

    /** 便捷判断：波可此刻是否正停在屏幕左右边缘附近 */
    private fun isPetDockedAtEdge(): Boolean {
        val params = pokoParams ?: return false
        val density = resources.displayMetrics.density
        val sizePx = petSizePx
        val (screenWidth, _) = getScreenDimensions()
        return isDockedAtEdge(params, sizePx, density, screenWidth)
    }

    private fun cancelEdgePeeking() {
        peekingRunnable?.let { mainHandler.removeCallbacks(it) }
        peekingRunnable = null
        peekAnimator?.cancel()
    }

    /**
     * 从探头状态恢复完整可见。
     *
     * 只复位"绘制偏移"，**绝不移动窗口**：
     * 移动窗口会让拖拽起始坐标落到屏幕之外，被坐标钳制钉死在边缘，表现为拖不动。
     *
     * @param animated false 表示立即完全露出（手指按下的瞬间使用）
     */
    private fun restoreFromPeeking(animated: Boolean = true) {
        cancelEdgePeeking()
        // 别让"回收溢出偏移"的动画跟探头复位抢同一个属性
        peekOffsetAnimator?.cancel()
        val view = pokoView ?: return
        view.alpha = petOpacity

        // 探头状态无论是否被取消都要复位：
        // 若探头动画刚跑到一半就被手指打断，isPeeking 已被判为 false，
        // 但绘制偏移还停在半路上，宠物会歪在屏幕外且手指落空 —— 拖拽直接夭折。
        isPeeking = false

        val currentOffset = view.peekOffsetX
        if (currentOffset == 0f) return

        if (!animated) {
            // 立即完全露出：仅复位绘制偏移，窗口坐标一动不动
            view.peekOffsetX = 0f
            return
        }

        ValueAnimator.ofFloat(currentOffset, 0f).apply {
            duration = 200
            interpolator = OvershootInterpolator(1.8f)
            addUpdateListener { anim ->
                view.peekOffsetX = anim.animatedValue as Float
            }
        }.start()
    }

    /**
     * 把"绘制偏移"平滑收回 0（拖拽溢出用）。
     *
     * 拖拽时超出屏幕的那部分是用绘制偏移表达的（窗口坐标绝不越界），
     * 松手后窗口坐标已经落在屏内，这时偏移必须跟着归零，
     * 否则宠物会歪在窗口旁边、看起来像"掉出屏幕"。
     */
    private fun animatePeekOffsetBack(duration: Long = 220L) {
        val view = pokoView ?: return
        val current = view.peekOffsetX
        if (current == 0f) return

        peekOffsetAnimator?.cancel()
        peekOffsetAnimator = ValueAnimator.ofFloat(current, 0f).apply {
            this.duration = duration
            interpolator = DecelerateInterpolator(1.6f)
            addUpdateListener { anim ->
                view.peekOffsetX = anim.animatedValue as Float
            }
        }
        peekOffsetAnimator?.start()
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

            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
            val petIntent = Intent(this, FloatingPetService::class.java).apply {
                action = ACTION_NOTIFICATION_PET
            }
            val pendingPetIntent = PendingIntent.getService(this, 101, petIntent, flags)

            val feedIntent = Intent(this, FloatingPetService::class.java).apply {
                action = ACTION_NOTIFICATION_FEED
            }
            val pendingFeedIntent = PendingIntent.getService(this, 102, feedIntent, flags)

            val stopIntent = Intent(this, FloatingPetService::class.java).apply {
                action = ACTION_NOTIFICATION_STOP
            }
            val pendingStopIntent = PendingIntent.getService(this, 103, stopIntent, flags)

            val recallIntent = Intent(this, FloatingPetService::class.java).apply {
                action = ACTION_NOTIFICATION_RECALL
            }
            val pendingRecallIntent = PendingIntent.getService(this, 104, recallIntent, flags)

            // 通知栏按钮跟着当前状态走：
            // 猫在桌面上 -> 摸摸 / 喂食 / 收回
            // 猫被收进通知栏 -> 召回 / 关闭（这样"收回"不等于"消失不见"）
            val builder = Notification.Builder(this, channelId)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(pendingIntent)
                .setOngoing(true)

            if (isPetRecalled) {
                builder.setContentTitle("波可在小窝里休息中~ 🐾")
                    .setContentText("点「召回」把它叫回桌面，点「关闭」彻底收起")
                    .addAction(Notification.Action.Builder(0, "🐾 召回", pendingRecallIntent).build())
                    .addAction(Notification.Action.Builder(0, "✕ 关闭", pendingStopIntent).build())
            } else {
                builder.setContentTitle("波可正在桌面上陪着您~ 🐾")
                    .setContentText("点击返回小窝，也可在下方快捷互动！")
                    .addAction(Notification.Action.Builder(0, "🐾 摸摸", pendingPetIntent).build())
                    .addAction(Notification.Action.Builder(0, "🐟 喂食", pendingFeedIntent).build())
                    .addAction(Notification.Action.Builder(0, "🏠 收回", pendingStopIntent).build())
            }

            val notification = builder.build()

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

    /**
     * 播放一次触觉反馈。
     *
     * ⚠️ `VibrationEffect.createWaveform(timings, amplitudes, repeat)` 在
     * amplitudes 长度与 timings 不一致时会抛 IllegalArgumentException 直接崩，
     * 所以这里做了长度兜底：长度对不上就退化成不带振幅的波形。
     * （长度一致性由守护测试逐项断言，这里只是防止手滑写错就闪退。）
     */
    private fun haptic(pattern: Companion.HapticPattern) {
        val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = if (pattern.amplitudes.size == pattern.timings.size) {
                VibrationEffect.createWaveform(pattern.timings, pattern.amplitudes, -1)
            } else {
                VibrationEffect.createWaveform(pattern.timings, -1)
            }
            vibrator.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(pattern.timings, -1)
        }
    }

    /** 追尾巴旋转时的两下轻快震动 */
    private fun vibrateDoubleTick() {
        haptic(Companion.HAPTIC_SPIN)
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        instance = null
        cancelEdgePeeking()
        isPeeking = false
        unregisterPetDataListener()
        longPressRunnable?.let { mainHandler.removeCallbacks(it) }
        soundPool?.release()
        soundPool = null
        mainHandler.removeCallbacks(edgeStrollRunnable)
        mainHandler.removeCallbacks(autoChatRunnable)
        removeFoodWindow()
        flingAnimator?.cancel()
        strollAnimator?.cancel()
        isStrolling = false
        edgeSnapAnimator?.cancel()
        hideBubbleRunnable?.let { mainHandler.removeCallbacks(it) }
        hideActionMenuRunnable?.let { mainHandler.removeCallbacks(it) }
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {}

        actionMenuView?.let {
            try {
                windowManager?.removeView(it)
            } catch (_: Exception) {}
        }
        actionMenuView = null
        isActionMenuAttached = false

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
