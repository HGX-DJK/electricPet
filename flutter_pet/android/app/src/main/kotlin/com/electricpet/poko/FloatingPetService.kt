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
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import org.json.JSONObject
import java.util.Calendar
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

    /**
     * 悬浮宠窗口当前是否真的挂在 WindowManager 上。
     *
     * ⚠️ 必须用**显式标记**判断，不能用 [android.view.View.getParent]。
     *
     * 原因（这是"宠物根本拖不动"的直接原因）：
     *   `WindowManager.addView()` 挂上去的视图，它的 parent 并不是常规意义上的父容器，
     *   拿 `parent != null` 当"还挂着"的判据，会把**好好挂着**误判成"已脱挂"。
     *   于是在 ACTION_DOWN 里调用 ensurePetWindowAttached() 时，
     *   每次按下都会 removeView + addView **重建窗口** ——
     *   而窗口一换，系统会把当前这根手指的触摸流一起丢掉（手势属于窗口，不属于屏幕）。
     *   结果就是：按下第一个事件还没处理完，手势就断了，
     *   后面 MOVE / UP 全部收不到 —— 表现为「按了完全没反应、宠物根本拖不动」。
     *
     * 同一个坑在快捷菜单上早就踩过（见 [isActionMenuAttached] 的注释），
     * 这里必须用同样的显式标记。
     */
    private var isPetWindowAttached: Boolean = false

    /**
     * 「窗口位置更新失败，需要重挂」的待办标记。
     *
     * 拖拽途中**绝不能**重建窗口：触摸手势是跟着窗口走的，
     * removeView + addView 换掉窗口的那一刻，系统会把当前这根手指的
     * MOVE / UP 一起丢掉 —— 日志里明明已经打了「进入拖拽」，宠物却纹丝不动。
     *
     * 所以拖拽里遇到更新失败只记这个标记，等手势彻底结束，
     * 由 attachWatchdog 统一重挂，既不丢手势又能自愈。
     */
    private var petWindowNeedsReattach: Boolean = false

    // 专属悬浮对话气泡
    private var bubbleView: TextView? = null
    private var bubbleParams: WindowManager.LayoutParams? = null
    /**
     * 气泡窗口是否已挂在 WindowManager 上。
     *
     * ⚠️ 和宠物窗口一样，不能用 `bubble.parent` 判断 ——
     * WindowManager.addView 挂上去的视图，parent 不是可靠信号。
     * 用 parent 判的话，每次弹气泡都会走 addView 分支（抛 "already added" 被吞掉），
     * 气泡的位置就再也更新不了 —— 表现就是"对话气泡在真机上脱离猫咪"。
     */
    private var isBubbleAttached: Boolean = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private var hideBubbleRunnable: Runnable? = null

    // 桌面萌宠身旁快捷控制悬浮菜单 (🐾 摸摸 / 🐟 喂食 / 🏠 小窝 / ✕ 收回)
    private var actionMenuView: LinearLayout? = null
    private var actionMenuParams: WindowManager.LayoutParams? = null
    private var hideActionMenuRunnable: Runnable? = null
    /** 菜单窗口当前是否已挂载到 WindowManager（用显式标记判断，避免依赖 View.parent 的回收时机） */
    private var isActionMenuAttached: Boolean = false

    // ---------- 悬浮窗 UI 配件的昼夜配色 ----------

    /**
     * 气泡 / 快捷菜单的配色常量。
     *
     * ⚠️ 昼夜切换**只作用在 UI 配件上**（气泡、快捷菜单），**绝不能改猫本体**：
     * App 里的猫本体永远是皮肤原色（见 `lib/renderers/pet_painter.dart`），
     * 桌面这边要是再给毛色压一层滤镜，同一只猫在两个地方就会长得不一样。
     *
     * 夜间配色与 App 内的夜间弹层同源（深靛底 0xFF1E1B4B / 浅字 / 靛紫描边）。
     */
    private val chromeDayBg = 0xFFFFFFFF.toInt()
    private val chromeDayMenuBg = 0xFFF8FAFC.toInt()
    private val chromeDayText = 0xFF0F172A.toInt()
    private val chromeDayStroke = 0xFFFED7AA.toInt()
    private val chromeDayDivider = 0xFFE2E8F0.toInt()

    private val chromeNightBg = 0xFF1E1B4B.toInt()
    private val chromeNightText = 0xFFE2E8F0.toInt()
    private val chromeNightStroke = 0xFF4C4585.toInt()
    private val chromeNightDivider = 0xFF332D73.toInt()

    // 四个菜单按钮的日/夜配色（夜间保留身份色相，只是提亮到深底上仍然可读）
    private val chromeBtnPetDay = 0xFF0F172A.toInt()
    private val chromeBtnFeedDay = 0xFF0284C7.toInt()
    private val chromeBtnHomeDay = 0xFF7C3AED.toInt()
    private val chromeBtnDismissDay = 0xFFEA580C.toInt()
    private val chromeBtnPetNight = 0xFFCBD5E1.toInt()
    private val chromeBtnFeedNight = 0xFF38BDF8.toInt()
    private val chromeBtnHomeNight = 0xFFA78BFA.toInt()
    private val chromeBtnDismissNight = 0xFFFB923C.toInt()

    /** 菜单里的分隔线，夜间要换颜色 */
    private val chromeDividers = mutableListOf<View>()

    // 双击与触控物理量
    private var lastClickTime: Long = 0
    private var edgeSnapAnimator: ValueAnimator? = null
    private var strollAnimator: ValueAnimator? = null
    private var isStrolling: Boolean = false

    // 边缘半收起探头避让模式状态与调度
    private var isPeeking: Boolean = false
    private var hasTouchDown: Boolean = false
    /**
     * 最近一次手指按下的时刻。
     *
     * 用途：万一某个 UP / CANCEL 没送达（窗口被换掉、系统吞了事件），
     * `hasTouchDown` 会永远停在 true —— 看门狗从此再也不肯修窗口，
     * 宠物就变成"永久拖不动"。看门狗靠这个时间戳把卡死的手势强制复位。
     */
    private var lastTouchDownAt: Long = 0L

    /**
     * 波可是否被用户"收进通知栏"。
     *
     * true = 服务还活着、通知还留着，但桌面上没有猫；
     * 用户点通知栏的「召回波可」就能把它叫回来。
     */
    private var isPetRecalled: Boolean = false
    private var peekAnimator: ValueAnimator? = null
    private var peekingRunnable: Runnable? = null

    /**
     * 排探头任务时波可所在的窗口坐标。
     *
     * 探头任务是 **延迟 5.5 秒** 才执行的，这 5.5 秒里波可完全可能
     * 被用户拖走、被甩飞、或者被别的动画挪走。
     * 任务真正跑起来时必须拿它对照一下：波可已经不在原地了就**放弃探头**，
     * 绝不能把一个不知跑到哪儿的宠物硬拽回边缘 —— 那是「拖着还乱飞」的观感来源。
     */
    private var peekScheduledX = 0
    private var peekScheduledY = 0
    // 拖拽溢出偏移的回收动画（与探头动画分开，避免互相打断）
    private var peekOffsetAnimator: ValueAnimator? = null
    // 「拉起主 App」后回收悬空前台标记的看门狗（见 openMainActivity）
    private var foregroundWatchdog: Runnable? = null

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

    // 悬浮窗挂载看门狗：定期体检，发现脱挂就在**手势之外**重挂。
    //
    // ⚠️ 为什么不能把"重挂"放进 ACTION_DOWN：
    //   触摸手势属于窗口而不是屏幕，removeView + addView 换掉窗口的那一刻，
    //   系统会把当前手势一起丢掉 —— MOVE / UP 再也收不到，宠物根本拖不动。
    //   所以修复必须发生在没有任何手指按着的时候。
    //
    // 有了它，"窗口静默脱挂"这类问题也能自愈：
    //   最多 1.5 秒内窗口就会回到 WindowManager 上，用户不必重装 App。
    private val attachWatchdog = object : Runnable {
        override fun run() {
            mainHandler.postDelayed(this, 1500)
            try {
                // 顺带清理"丢失的手势"：
                // 万一某个 UP / CANCEL 没送达（窗口被换掉、系统吞了事件），
                // hasTouchDown 会永远停在 true —— 看门狗从此再也不肯动手，
                // 宠物就变成"永久拖不动"。这里按时间戳强制复位。
                if (hasTouchDown && System.currentTimeMillis() - lastTouchDownAt > 5000) {
                    Log.w(TAG, "手势状态疑似卡死（超过 5 秒没有收到 UP/CANCEL），强制复位")
                    hasTouchDown = false
                    pokoView?.onDragStateChanged(false)
                }
                if (hasTouchDown) return          // 手势进行中绝不碰窗口
                val view = pokoView ?: return

                // 上一段手势里 updateViewLayout 失败过 → 手势已结束，现在可以安全重挂
                if (petWindowNeedsReattach) {
                    petWindowNeedsReattach = false
                    Log.w(TAG, "看门狗接手：上一段手势中窗口位置更新失败，现在重挂悬浮窗")
                    if (reattachPetWindow()) {
                        val params = pokoParams
                        if (params != null) {
                            clampPetPositionToScreen(params)
                            try {
                                windowManager?.updateViewLayout(view, params)
                            } catch (e: Exception) {
                                Log.e(TAG, "看门狗重挂后刷新布局失败", e)
                            }
                        }
                        refreshPetVisibility()
                        return
                    }
                }

                if (isPetWindowAttached && view.isAttachedToWindow) return
                Log.w(TAG, "看门狗发现悬浮窗脱挂，准备重新挂载")
                if (ensurePetWindowAttached()) {
                    // 重挂后位置可能被系统重置，重新钳回屏内并刷一次布局
                    val params = pokoParams
                    if (params != null) {
                        clampPetPositionToScreen(params)
                        try {
                            windowManager?.updateViewLayout(view, params)
                        } catch (e: Exception) {
                            Log.e(TAG, "看门狗重挂后刷新布局失败", e)
                        }
                    }
                    refreshPetVisibility()
                }
            } catch (e: Exception) {
                // 看门狗抛异常会直接掀掉前台服务，绝不能发生
                Log.e(TAG, "挂载看门狗执行异常", e)
            }
        }
    }

    // 触摸可达性心跳：定期把"窗口现在健不健康"和"上一次收到触摸是什么时候"打出来。
    //
    // 为什么必须有它：
    //   「拖不动」有两种完全不同的成因，日志长得很像，光看现象分不出来 ——
    //     ① 触摸**根本没进窗口**（可触达区域陈旧 / 被别的窗口盖住 / 视图不可见）
    //        → 日志里只有心跳，压根没有「触摸按下」
    //     ② 触摸进来了但算法没跟上 → 日志里有「触摸按下」「进入拖拽」
    //        → 再看「手势轨迹」里的 winTravel 就能定论
    //
    // 之前好几轮都在猜是哪一种，因为日志里只有"有反应时"的记录，
    // 没有"该有反应却没有"的记录 —— 缺了这一半就永远定位不了。
    private val touchHeartbeat = object : Runnable {
        override fun run() {
            mainHandler.postDelayed(this, 30000)
            try {
                val view = pokoView ?: return
                if (!screenOn || view.visibility != View.VISIBLE) return
                val params = pokoParams ?: return
                val idleMs = System.currentTimeMillis() - lastTouchDownAt
                Log.i(
                    TAG,
                    "触摸心跳: attached=${view.isAttachedToWindow} wm=$isPetWindowAttached " +
                        "vis=${view.visibility} win=(${params.x},${params.y}) " +
                        "peekOffset=${view.peekOffsetX} " +
                        "距上次触摸=${idleMs / 1000}s"
                )
            } catch (e: Exception) {
                Log.e(TAG, "触摸心跳异常", e)
            }
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
        const val DRAG_FIX_VERSION = "drag-fix-v11"

        /**
         * 「拉起主 App」后回收悬空前台标记的看门狗超时（毫秒）。
         *
         * 拉起一个 Activity 通常在几百毫秒内完成 resume，2.5 秒足够宽松；
         * 超时仍未 resume 就说明那次手工置位是悬空的，必须收回。
         */
        const val FOREGROUND_WATCHDOG_DELAY_MS = 2500L

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

        /**
         * 主 Activity 是否**真的**处于前台（onResume 置位、onPause 复位）。
         *
         * 它和 [isAppForeground] 的区别很关键：
         * [isAppForeground] 会被 [openMainActivity] 提前手工置成 true（先让猫隐身再拉起 App），
         * 那时候 Activity 其实还没 resume。如果拉起失败或被系统拦下，
         * 这个 true 就成了**悬空标记**——没人来复位它，
         * 宠物会永久停在不可见/不可触摸状态（View.GONE 的视图根本不参与触摸分发），
         * 表现出来就是「关掉 App 再打开悬浮宠后拖不动」。
         *
         * 所以要用这个"真值"做交叉校验：标记说前台、但 Activity 从未 resume 过 → 悬空，收回。
         */
        @Volatile
        var isMainActivityResumed: Boolean = false

        /** 当前运行中的服务实例，供主 Activity 前后台切换时即时同步悬浮猫显隐 */
        @Volatile
        var instance: FloatingPetService? = null

        /** 主 Activity 前后台切换时调用，驱动悬浮猫显隐 */
        @JvmStatic
        fun notifyAppForegroundChanged(foreground: Boolean) {
            isAppForeground = foreground
            isMainActivityResumed = foreground
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

        // 5. 绑定触控、拖拽、果冻回弹挤压与自由停驻事件
        setupTouchListener(density)

        try {
            if (!isPetWindowAttached) {
                windowManager?.addView(pokoView, pokoParams)
                isPetWindowAttached = true
            }
            pokoView?.alpha = petOpacity
            Log.i(TAG, "悬浮宠服务启动 · 交互增强版 $DRAG_FIX_VERSION · sizeDp=$petSizeDp")
            Toast.makeText(this, "🐾 波可已跃上手机桌面！(v3) 摸摸头试试～", Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            e.printStackTrace()
            stopSelf()
            return
        }

        // 启动挂载看门狗：窗口万一静默脱挂，最多 1.5 秒内自愈，
        // 而且修复发生在**没有任何手指按着**的时候，不会打断正在进行的拖拽。
        mainHandler.removeCallbacks(attachWatchdog)
        mainHandler.postDelayed(attachWatchdog, 1500)

        // 启动触摸心跳：给"拖不动"留下一条可对照的基线
        // （没有它就分不清"触摸没进窗口"和"算法没跟上"）
        lastTouchDownAt = System.currentTimeMillis()
        mainHandler.removeCallbacks(touchHeartbeat)
        mainHandler.postDelayed(touchHeartbeat, 30000)

        // 6. 初始可见性与动画状态: 屏幕点亮 且 小窝不在前台
        screenOn = isScreenInteractive()
        refreshPetVisibility()

        // 7. 监听息屏 / 亮屏: 看不见的时候停掉动画, 别白烧电
        registerScreenReceiver()
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
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 每次启动或自启重新加固前台服务优先级
        startAsForeground()

        // ⚠️ 前后台状态自愈：
        // 服务可能被系统重建（START_STICKY），也可能被 App 侧重新拉起，
        // 这时全局静态的前台标记有可能与主 Activity 的真实状态对不上
        //（比如"关掉 App 再打开悬浮宠"这条路上，标记悬空留在 true）。
        // 标记一旦悬空，悬浮猫就会一直停在 View.GONE ——
        // 而 GONE 的视图根本不参与触摸分发，用户只会看到"拖不动"。
        // 这里用 Activity 的真实 resume 状态做一次交叉校验并纠正。
        if (isAppForeground != isMainActivityResumed) {
            Log.w(
                TAG,
                "前后台标记失同步（isAppForeground=$isAppForeground " +
                    "isMainActivityResumed=$isMainActivityResumed），按 Activity 真实状态纠正"
            )
            isAppForeground = isMainActivityResumed
            refreshPetVisibility()
        }

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

        // 若波可之前被收进通知栏，App 侧或小组件再次启动时自动召回桌面
        if (isPetRecalled) {
            isPetRecalled = false
            refreshPetVisibility()
        }

        val skinId = intent?.getStringExtra("skinId")
        val petName = intent?.getStringExtra("petName")
        // 每次启动/推送都同步外观：空值表示保持原样，非空则实时换品种
        pokoView?.applyConfig(skinId, petName)

        // 昼夜状态：App 按真实太阳节律算好后推过来，桌面猫跟着换配色
        // 边界（当天第几分钟）用来让桌面端在 App 被杀掉时也能自己判断昼夜
        if (intent?.hasExtra(OverlayChannel.ARG_NIGHT_MODE) == true) {
            applyNightModeFromApp(
                intent.getBooleanExtra(OverlayChannel.ARG_NIGHT_MODE, false),
                intent.getIntExtra(OverlayChannel.ARG_DAY_START_MINUTE, -1),
                intent.getIntExtra(OverlayChannel.ARG_NIGHT_START_MINUTE, -1),
            )
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

    /**
     * 单次手势的"轨迹账本"。
     *
     * 拖拽到底正不正常，肉眼很难判断，但账本一算就清楚：
     *   · rawTravel  —— 手指按 raw 坐标口径实际走了多远
     *   · localTravel —— 手指按「窗口位置 + 局部坐标」口径实际走了多远
     *   · winTravel  —— 窗口**真的**挪了多远
     * 三者一对账，就能立刻分辨出四种情况：
     *   ① 两者都 ≈ winTravel → 拖拽完全正常
     *   ② rawTravel ≈ 0 而 localTravel ≠ 0 → 该 ROM 的 rawX 是窗口内坐标
     *   ③ winTravel 明显大于 rawTravel → 窗口冲过头了（乱飞）
     *   ④ winTravel ≈ 0 而手指明明走了 → 窗口压根没跟上（拖不动）
     */
    private class GestureTrace {
        var rawStartX = 0f
        var rawStartY = 0f
        var rawEndX = 0f
        var rawEndY = 0f
        var localStartX = 0f
        var localStartY = 0f
        var localEndX = 0f
        var localEndY = 0f
        var winStartX = 0
        var winStartY = 0
        var moveCount = 0

        fun reset(
            rawX: Float, rawY: Float,
            localX: Float, localY: Float,
            winX: Int, winY: Int
        ) {
            rawStartX = rawX
            rawStartY = rawY
            rawEndX = rawX
            rawEndY = rawY
            localStartX = localX
            localStartY = localY
            localEndX = localX
            localEndY = localY
            winStartX = winX
            winStartY = winY
            moveCount = 0
        }

        fun move(rawX: Float, rawY: Float, localX: Float, localY: Float) {
            rawEndX = rawX
            rawEndY = rawY
            localEndX = localX
            localEndY = localY
            moveCount++
        }

        fun summary(endWinX: Int, endWinY: Int): String {
            val rawTravelX = (rawEndX - rawStartX).toInt()
            val rawTravelY = (rawEndY - rawStartY).toInt()
            val winTravelX = endWinX - winStartX
            val winTravelY = endWinY - winStartY
            val localTravelX = (endWinX + localEndX) - (winStartX + localStartX)
            val localTravelY = (endWinY + localEndY) - (winStartY + localStartY)
            return "moves=$moveCount " +
                "rawTravel=($rawTravelX,$rawTravelY) " +
                "localTravel=($localTravelX,$localTravelY) " +
                "winTravel=($winTravelX,$winTravelY) " +
                "win=($winStartX,$winStartY)->($endWinX,$endWinY)"
        }
    }

    /**
     * 把一次手势的轨迹账本打出来。
     *
     * 这是给真机排查留的"现场证据"：用户复现一次，把这一行贴回来就够定位了。
     */
    private fun logGestureTrace(
        reason: String,
        mode: String,
        trace: GestureTrace,
        endWinX: Int,
        endWinY: Int
    ) {
        Log.i(
            TAG,
            "手势轨迹[$DRAG_FIX_VERSION] $reason mode=$mode ${trace.summary(endWinX, endWinY)}"
        )
    }

    private fun setupTouchListener(density: Float) {
        val touchSlop = ViewConfiguration.get(this).scaledTouchSlop
        var initialX = 0
        var initialY = 0

        // ⚠️⚠️⚠️ 拖拽位移必须用**手指的屏幕绝对位置**来算，
        // 而手指的屏幕绝对位置要用「窗口当前位置 + 窗口局部坐标」推出来，
        // 绝对不能用 event.rawX / event.rawY。
        //
        // 原因（"有时候可以拖、有时候拖不动"的机制性原因）：
        //   `MotionEvent.getRawX()` 对 `WindowManager.addView()` 挂上去的悬浮窗，
        //   在不同 ROM / 不同版本上"原始坐标"到底是**屏幕绝对坐标**还是**窗口内坐标**
        //   并不一致（它取决于窗口的 raw offset 怎么算）。
        //
        //   旧实现把整个拖拽数学建在 rawX 上：
        //       dx = event.rawX - initialTouchX
        //       params.x = initialX + dx
        //   只要窗口在拖拽过程中自己移动了，rawX 的语义就会让 dx 归零：
        //       · rawX 是屏幕绝对坐标 → 手指没动、窗口动了 → dx 恒为 0；
        //       · rawX 是窗口内坐标   → 窗口移动后 rawX 跟着变 → dx 也只生效一帧。
        //   两种情况都是"**窗口只跟第一帧就卡住**"，
        //   能不能看出"动了"完全取决于第一帧位移有没有超过 touchSlop ——
        //   这正是用户看到的「有时候可以拖动，有时候又拖不动」。
        //
        // 现在的做法（两种 raw 语义下都正确）：
        //   手指屏幕绝对位置 F = 窗口屏幕位置 W + 窗口局部坐标 l   ← 这个等式恒成立
        //   窗口跟着手指走：W_new = W_0 + (F_now - F_0)
        //
        //   · event.x / event.y 是 View 局部坐标，定义上没有歧义；
        //   · params.x / params.y 是我们自己写的窗口位置；
        //   · 两者相加就是手指此刻真实的屏幕绝对位置，
        //     而且窗口被屏幕边界钳制时也算得对（钳制后 params.x 变了，l 跟着补回来）。
        var initialFingerX = 0f
        var initialFingerY = 0f
        // 本次手势开始时手指的屏幕绝对位置（**不可变基线**）。
        //
        // ⚠️ 拖拽阈值必须用它，不能用 initialFingerX：
        //   initialFingerX 会被"边界钳制消费"改写（贴边继续外推时它不再增长），
        //   拿它判阈值就会出现「明明推了一大段，日志里却始终没有『进入拖拽』」。
        //   用户看到的就是"有时好像没有进入拖拽"。
        var gestureStartFingerX = 0f
        var gestureStartFingerY = 0f
        // 上一帧的手指屏幕绝对位置（用于算这一帧的位移与速度）
        var lastFingerX = 0f
        var lastFingerY = 0f
        // 上一帧真正写进窗口的坐标（用于诊断"进入了拖拽但窗口纹丝不动"）
        var lastAppliedX = 0
        var lastAppliedY = 0

        // 本次手势里是否出现过"手指在动、窗口却一帧没动"（且不是被屏幕边界钳住）
        // —— 这是窗口布局更新失效的特征，收手时据此触发一次重建自愈。
        var windowStuckWhileMoving = false

        // ⚠️ event.rawX 的语义判定结果（见 ACTION_DOWN 里的详细说明）
        // true  = rawX 是屏幕绝对坐标 → 用 rawX 算位移（不会被"窗口落后一帧"带偏）
        // false = rawX 不是屏幕绝对坐标 → 退回「窗口位置 + 窗口局部坐标」
        var rawIsScreenAbsolute = true
        // rawX → 窗口坐标系的锚点（吸收状态栏 / 挖孔等常量偏移）
        var rawAnchorX = 0f
        var rawAnchorY = 0f

        // ---------- 手势轨迹记录（给下一轮定位用，一次手势只打一行） ----------
        val trace = GestureTrace()

        // 自行推算的释放速度（px/s）：由位移 + eventTime 得出，不依赖 rawX 语义
        var velocityX = 0f
        var velocityY = 0f
        var lastEventTime = 0L

        var isClick = false
        var hasDragged = false
        // 拖拽过程中的朝向：跟随水平移动方向（被拖着走会侧身迎向运动方向），
        // 松手后由落位逻辑恢复成"面向屏幕中心"。
        var dragFacingLeft = false
        // 朝向切换的累积位移 + 滞后阈值（避免镜像翻面时来回抖动）
        var dragDxAccum = 0f
        val facingFlipThreshold = 14f * density
        // 双指捏合的触发阈值：两指距离要真的拉开/收拢到这个量级，才认定用户在做捏合。
        // 之前是"第二根手指一落下就切到捏合模式"，于是用户想用力拖一把、手掌误触屏幕，
        // 拖拽都会被整段吞掉（宠物纹丝不动），表现出来就是"有时能拖有时拖不动"。
        val pinchTriggerDistance = 26f * density
        // 单次手势只打一条移动日志，便于用一条 logcat 判定"跟手了没有"
        var hasLoggedMove = false
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
                    lastTouchDownAt = System.currentTimeMillis()
                    lastInteractionAt = System.currentTimeMillis()
                    // ⚠️ 按下第一件事先给悬浮窗做体检 —— 但这里**只看不修**。
                    //
                    // 「View 还在、窗口却已经从 WindowManager 脱挂」是"时好时坏"的经典成因，
                    // 此时所有触摸都收不到，而且永远不会自愈。
                    //
                    // ⚠️⚠️ 绝对不能在这里重建窗口（removeView + addView）：
                    // 触摸手势是**跟着窗口**走的，窗口一换，
                    // 系统会把当前这根手指的触摸流一起丢掉 ——
                    // MOVE / UP 全部收不到，表现为「按下完全没反应、宠物根本拖不动」。
                    //
                    // 以前这里直接调 ensurePetWindowAttached()，而它又是拿
                    // `view.parent != null` 判"是否还挂着"（对 WindowManager 挂上去的视图不可靠），
                    // 于是**每次按下都重建一次窗口**，手势在第一个事件就断了 ——
                    // 这就是"宠物完全拖不动"的直接原因。
                    //
                    // 现在：这里只记录状态，真正的重建交给手势之外的看门狗
                    // （attachWatchdog）去做。
                    if (!isPetWindowAttached || pokoView?.isAttachedToWindow != true) {
                        Log.w(TAG, "按下时发现悬浮窗未挂载，本次手势不重建（交给看门狗处理）")
                    }
                    cancelEdgePeeking()
                    // 按下瞬间立即完全露出（只复位绘制偏移，窗口坐标一动不动），
                    // 保证下面采集到的 initialX/initialY 就是宠物真实落点
                    restoreFromPeeking(animated = false)
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
                    // 手指此刻的**屏幕绝对位置** = 窗口位置 + 窗口局部坐标。
                    initialFingerX = params.x + event.x
                    initialFingerY = params.y + event.y

                    // ⚠️⚠️⚠️ 判定 event.rawX 的语义 —— 这一步是拖拽跟不跟手的关键。
                    //
                    // 手指的屏幕绝对位置有两种拿法，各自的致命缺陷完全不同：
                    //
                    //   ① finger = params.x + event.x（窗口位置 + 窗口局部坐标）
                    //      ⚠️ 缺陷：params.x 是**我们请求**的窗口位置，
                    //         而 event.x 是相对**窗口真实位置**算出来的。
                    //         updateViewLayout 是跨进程异步的 —— 窗口真正挪到新位置
                    //         要等到下一帧的 traversal，而同一帧里可能还有 2~3 个 MOVE 事件。
                    //         于是同一个 MOVE 事件里混进了两个时间点：
                    //         新的 params.x 配旧的 event.x。
                    //         算出来的"手指位置"凭空多出一大截，
                    //         窗口每帧都往前冲一截 —— 这就是**拖拽乱飞**。
                    //
                    //   ② finger = event.rawX（原始坐标）
                    //      ✅ 优点：rawX 是**输入管线里的屏幕绝对坐标**，
                    //         完全不受窗口"什么时候真正挪过去"的影响，
                    //         一帧内有几个 MOVE 都不会错位。
                    //      ⚠️ 风险：个别 ROM / 特殊窗口下 rawX 的语义可能不是屏幕绝对坐标，
                    //         这时用它算位移会得到"窗口相对位移"，窗口只跟第一帧就卡住。
                    //
                    // 所以：**按下这一刻就把语义判出来，之后整段手势都用对的那一种**。
                    // 判定不靠猜，靠比对 ——
                    // 按下这一刻 params.x 就是窗口真实的屏幕原点（还没动过），
                    // 所以 rawX - event.x 必然等于"窗口原点"（rawX 是屏幕绝对坐标）
                    // 或者 0（rawX 是窗口内坐标）。
                    val rawOriginX = event.rawX - event.x
                    val rawOriginY = event.rawY - event.y
                    // 两个轴里挑判据更硬的那个来定夺：
                    // 窗口越靠边，那个轴上"原点 ≈ 0"与"原点 ≈ params"越难区分。
                    val xEvidence = abs(params.x)
                    val yEvidence = abs(params.y)
                    rawIsScreenAbsolute = if (xEvidence >= yEvidence) {
                        abs(rawOriginX - params.x) <= abs(rawOriginX)
                    } else {
                        abs(rawOriginY - params.y) <= abs(rawOriginY)
                    }
                    // 锚点：把 rawX 换算到"窗口坐标系"，
                    // 顺手吸收状态栏 / 挖孔 / 折叠屏带来的常量偏移。
                    // 有了它，窗口位移就等于 rawX 的**纯增量**，绝不夹带任何常量偏差。
                    rawAnchorX = initialFingerX - event.rawX
                    rawAnchorY = initialFingerY - event.rawY
                    // 不可变的"手势起点"基线：只用于判定是否进入拖拽
                    gestureStartFingerX = initialFingerX
                    gestureStartFingerY = initialFingerY
                    lastFingerX = initialFingerX
                    lastFingerY = initialFingerY
                    lastAppliedX = params.x
                    lastAppliedY = params.y
                    // 轨迹记录：给"窗口实际挪了多远"和"手指实际走了多远"各留一份账
                    trace.reset(
                        rawX = event.rawX, rawY = event.rawY,
                        localX = event.x, localY = event.y,
                        winX = params.x, winY = params.y
                    )
                    velocityX = 0f
                    velocityY = 0f
                    lastEventTime = event.eventTime
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
                        "触摸按下 local=(${event.x}, ${event.y}) raw=(${event.rawX}, ${event.rawY}) " +
                            "win=($initialX, $initialY) " +
                            "raw语义=${if (rawIsScreenAbsolute) "屏幕绝对" else "窗口内"} " +
                            "peekOffset=${pokoView?.peekOffsetX} sizePx=$petSizePx " +
                            "vis=${pokoView?.visibility} attached=${pokoView?.isAttachedToWindow} " +
                            "wm=${isPetWindowAttached} " +
                            "screen=($gestureScreenWidth, $gestureScreenHeight)"
                    )
                    true
                }
                MotionEvent.ACTION_POINTER_DOWN -> {
                    // 第二根手指落下：**这里只记基线，不立刻接管手势**。
                    //
                    // 之前一看到第二根手指就 isPinching = true，此后的 MOVE 全部被
                    // handlePinchGesture 吃掉 —— 用户想用力拖一把、或者手掌误触碰到屏幕，
                    // 拖拽就被整段吞掉，宠物纹丝不动，还顺带把宠物改了尺寸，
                    // 触摸区跟着变小，越发"按不到、拖不动"。
                    //
                    // 现在改成"两指距离真的拉开/收拢到阈值之外"才认定为捏合，
                    // 否则继续老老实实走拖拽。
                    if (event.pointerCount >= 2 && !isPinching) {
                        pinchStartDistance = pointerDistance(event)
                        pinchStartSizeDp = petSizeDp
                        pinchStartAngle = pointerAngle(event)
                        pinchStartFacingLeft = pokoView?.facingLeft ?: false
                    }
                    true
                }
                MotionEvent.ACTION_POINTER_UP -> {
                    // 抬起一根手指：结束双指手势并重新锚定拖拽起点，避免宠物瞬移
                    if (event.pointerCount <= 2) {
                        isPinching = false
                        initialX = params.x
                        initialY = params.y
                        // 重新锚定：以此刻的手指屏幕绝对位置为新基线
                        // （必须与 MOVE 分支用同一套算法，否则锚点会错位）
                        initialFingerX = if (rawIsScreenAbsolute) {
                            event.rawX + rawAnchorX
                        } else {
                            params.x + event.x
                        }
                        initialFingerY = if (rawIsScreenAbsolute) {
                            event.rawY + rawAnchorY
                        } else {
                            params.y + event.y
                        }
                        lastFingerX = initialFingerX
                        lastFingerY = initialFingerY
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    // 视线跟随：眼珠始终追着指尖
                    pokoView?.setGazeTarget(event.x, event.y)

                    // 双指手势优先：捏合改大小、旋转翻朝向
                    //
                    // ⚠️ 必须是"两指距离变化超过阈值"才认定为捏合，不能是"第二根手指一落下就算"。
                    // 否则用户单手想拖、不小心用上第二根手指时，整段拖拽会被捏合逻辑吃掉，
                    // 宠物一动不动 —— 这正是"有时可以拖动、有时又拖不动"的主要来源之一。
                    if (!isPinching && event.pointerCount >= 2 && pinchStartDistance > 1f) {
                        val dist = pointerDistance(event)
                        if (abs(dist - pinchStartDistance) > pinchTriggerDistance) {
                            isPinching = true
                            isClick = false
                            hasDragged = false
                            // 以"判定为捏合的这一刻"重新取基线，
                            // 免得第一帧就把尺寸改掉一大截
                            pinchStartDistance = dist
                            pinchStartSizeDp = petSizeDp
                            pinchStartAngle = pointerAngle(event)
                            pinchStartFacingLeft = pokoView?.facingLeft ?: false
                            longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                            hideActionMenu(animated = false)
                        }
                    }
                    if (isPinching && event.pointerCount >= 2) {
                        handlePinchGesture(event)
                        return@setOnTouchListener true
                    }

                    val screenWidth = gestureScreenWidth
                    val screenHeight = gestureScreenHeight

                    // ⚠️⚠️ 手指此刻的屏幕绝对位置。
                    //
                    // 首选 rawX：它是输入管线里的屏幕绝对坐标，
                    // **不受窗口"真正挪过去要等下一帧"的影响** ——
                    // 同一帧里来几个 MOVE 都不会算错位。
                    //
                    // 绝对不能用「params.x + event.x」当首选：
                    // params.x 是我们**请求**的位置，event.x 却相对窗口**真实**位置算，
                    // 两者差着一帧的窗口位移，
                    // 算出来的手指位置会凭空多出一截 —— 窗口每帧往前冲一截，
                    // 表现就是「拖拽乱飞」。
                    //
                    // 只有在个别 ROM 上 rawX 不是屏幕绝对坐标时，才退回局部坐标算法
                    // （ACTION_DOWN 已经把语义判出来了）。
                    val fingerX = if (rawIsScreenAbsolute) {
                        event.rawX + rawAnchorX
                    } else {
                        params.x + event.x
                    }
                    val fingerY = if (rawIsScreenAbsolute) {
                        event.rawY + rawAnchorY
                    } else {
                        params.y + event.y
                    }

                    // 轨迹：记下这一帧的原始坐标与局部坐标，收手时一次性打出来
                    trace.move(event.rawX, event.rawY, event.x, event.y)

                    // 本帧手指移动了多少（真实位移，不受窗口是否被钳制影响）
                    val stepX = (fingerX - lastFingerX).toInt()
                    val stepY = (fingerY - lastFingerY).toInt()
                    lastFingerX = fingerX
                    lastFingerY = fingerY

                    // 窗口跟着手指走：起点 + 手指的累计位移
                    val wantedX = initialX + (fingerX - initialFingerX).toInt()
                    val wantedY = initialY + (fingerY - initialFingerY).toInt()
                    val totalDx = wantedX - initialX
                    val totalDy = wantedY - initialY

                    // 手指**真实走过的行程**（相对手势起点，永不被边界钳制改写）。
                    // 判定"是否进入拖拽"必须用它：
                    //   贴着屏幕边缘继续往外推时，窗口没地方去了（totalDx 不再增长），
                    //   但手指明明推了很远 —— 用 totalDx 判阈值就永远进不了拖拽态，
                    //   用户看到的就是"有时好像没有进入"。
                    val travelDx = (fingerX - gestureStartFingerX).toInt()
                    val travelDy = (fingerY - gestureStartFingerY).toInt()

                    // 自行推算速度（px/s）：用 eventTime 做时间基准，
                    // 同样不依赖 rawX 语义，甩出去的惯性方向才不会反。
                    val dt = (event.eventTime - lastEventTime).coerceAtLeast(1L)
                    lastEventTime = event.eventTime
                    val instVx = stepX * 1000f / dt
                    val instVy = stepY * 1000f / dt
                    velocityX = velocityX * 0.5f + instVx * 0.5f
                    velocityY = velocityY * 0.5f + instVy * 0.5f
                    pokoView?.updateDragVelocity(stepX.toFloat())

                    // 朝向跟随拖动方向：往左拖就侧身朝左、往右拖就朝右。
                    // 之前是按"宠物在屏幕左半边还是右半边"硬切，
                    // 结果往左拖时猫脸还朝右，跟手感完全对不上。
                    //
                    // 注意朝向是靠整幅画面镜像实现的（canvas.scale(-1,1)），
                    // 翻面是"啪"的一下突变，所以这里用累积位移 + 滞后阈值：
                    // 累计移动超过阈值才允许翻面，翻完清零 —— 既跟手又不会来回抖。
                    dragDxAccum += stepX
                    if (abs(dragDxAccum) > facingFlipThreshold) {
                        val wantLeft = dragDxAccum < 0
                        if (wantLeft != dragFacingLeft) {
                            dragFacingLeft = wantLeft
                            pokoView?.facingLeft = wantLeft
                        }
                        dragDxAccum = 0f
                    }

                    if (!hasDragged &&
                        (abs(travelDx) > touchSlop || abs(travelDy) > touchSlop)
                    ) {
                        isClick = false
                        hasDragged = true
                        hideActionMenu(animated = false)
                        longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                        // 真正开始拖动才"拎起悬空"，单击不再出现拎起-落地的抽搐
                        pokoView?.onDragStateChanged(true)
                        Log.d(
                            TAG,
                            "进入拖拽 dx=$totalDx dy=$totalDy " +
                                "(手指行程=$travelDx,$travelDy 本帧 step=($stepX, $stepY))"
                        )
                    }

                    // 限制移动在屏幕边界之内，动态适应状态栏与手势条避让
                    val maxX = (screenWidth - petSizePx).coerceAtLeast(0)
                    val (minY, maxY) = getSafeVerticalBounds(density, screenHeight, petSizePx)

                    val clampedX = wantedX.coerceIn(0, maxX)
                    val clampedY = wantedY.coerceIn(minY, maxY)

                    // ⚠️ 被屏幕边界吃掉的位移必须**消费掉**（记回基线）。
                    //
                    // 不消费的话，手指往回拉时宠物会先在屏幕边缘"粘"一段距离
                    // 才跟得回来 —— 那段粘滞正是用户感知到的「拖不动 / 粘手」。
                    // 消费掉之后，窗口位移与手指位移始终 1:1，贴边拖也跟手。
                    initialFingerX += (wantedX - clampedX)
                    initialFingerY += (wantedY - clampedY)

                    params.x = clampedX
                    params.y = clampedY

                    // 🔍 诊断：已经进入拖拽，窗口位置却一帧都没变。
                    //
                    // 排除掉"被屏幕边界钳住"这种正常情况（wantedX == clampedX），
                    // 剩下的就只剩两种可能：
                    //   ① updateViewLayout 没真正生效（窗口没动）
                    //   ② 有别的东西在同一帧把窗口坐标改回去了
                    // 两种都会让用户看到「日志里已经打了『进入拖拽』，宠物却不动」。
                    // 把现场记下来，下一轮定位就不用再靠猜。
                    if (hasDragged && (stepX != 0 || stepY != 0) &&
                        wantedX == clampedX && wantedY == clampedY &&
                        params.x == lastAppliedX && params.y == lastAppliedY
                    ) {
                        Log.w(
                            TAG,
                            "拖拽中窗口位置没有变化 step=($stepX, $stepY) " +
                                "窗口=(${params.x}, ${params.y}) 期望=($clampedX, $clampedY) " +
                                "attached=${pokoView?.isAttachedToWindow} wm=$isPetWindowAttached"
                        )
                        // 🔧 记一笔：**手指在动、位置没被钳制、窗口却一帧没动** ——
                        // 这说明窗口的布局更新根本没生效（热区 / frame 陈旧）。
                        // 收手时据此打上"待重挂"标记，让看门狗重建窗口，
                        // 下一次按就能恢复 —— 这就是"有时拖不动"的自愈路径。
                        windowStuckWhileMoving = true
                    }
                    lastAppliedX = params.x
                    lastAppliedY = params.y
                    windowStuckWhileMoving = false

                    // 拖出屏幕的部分用"绘制偏移"表现：窗口本身绝不越界，
                    // 既能拖出半只猫，又不会重现坐标钳制把宠物钉死在边缘的问题
                    //
                    // ⚠️ overflow 是**屏幕坐标系**的位移（正 = 往屏幕右侧），
                    // 所以手指往右推时猫就往右被"推出"屏幕边缘，
                    // 不会因为猫面朝左而反向跑 —— 跟手方向必须和手指一致。
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
                        // ⚠️⚠️ 这里**绝不能**立刻 reattachPetWindow()。
                        //
                        // 触摸手势属于**窗口**而不是屏幕：removeView + addView 换掉窗口的那一刻，
                        // 系统会把当前这根手指的触摸流一起丢掉 ——
                        // MOVE / UP 全部收不到。
                        // 用户看到的就是：日志里明明打了「进入拖拽」，宠物却纹丝不动。
                        //
                        // 正确做法：只记一个"待重挂"标记，等手势彻底结束，
                        // 由 attachWatchdog 在**没有任何手指按着**的时候统一重挂 ——
                        // 既不丢手势，又能自愈。
                        petWindowNeedsReattach = true
                    }

                    if (!hasLoggedMove) {
                        hasLoggedMove = true
                        Log.d(
                            TAG,
                            "首次移动 dx=$totalDx dy=$totalDy (单帧 step=($stepX, $stepY)) " +
                                "-> 窗口位置 x=${params.x} y=${params.y} " +
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
                    // 手势状态必须彻底复位，否则下一次按下会继承上一次的
                    // "正在拖拽"标记，落位逻辑会走错分支。
                    isClick = false
                    hasDragged = false
                    isLongPressing = false
                    isPinching = false
                    velocityX = 0f
                    velocityY = 0f
                    logGestureTrace(
                        "CANCEL",
                        if (rawIsScreenAbsolute) "raw" else "local",
                        trace, params.x, params.y
                    )
                    Log.w(
                        TAG,
                        "拖拽被系统中断 (ACTION_CANCEL)，波可保持原地不动 " +
                            "(按住时长=${System.currentTimeMillis() - lastTouchDownAt}ms) " +
                            "—— 若松手前几乎没动过，多半是屏幕边缘的系统手势抢走了这一把"
                    )
                    true
                }
                MotionEvent.ACTION_UP -> {
                    hasTouchDown = false
                    lastInteractionAt = System.currentTimeMillis()
                    longPressRunnable?.let { mainHandler.removeCallbacks(it) }
                    pokoView?.onDragStateChanged(false)
                    pokoView?.clearGazeTarget()
                    // 释放速度：由局部位移 + eventTime 自行推算，
                    // 不再依赖 VelocityTracker（它同样建立在 raw 坐标上，语义不稳定）。
                    val releaseVx = velocityX
                    val releaseVy = velocityY

                    // 轨迹对账：这一行就是"这次拖拽正不正常"的答案
                    logGestureTrace(
                        "UP",
                        if (rawIsScreenAbsolute) "raw" else "local",
                        trace, params.x, params.y
                    )

                    // 🔧 自愈：这次手势里窗口"该动却一帧没动"过
                    // （且不是被屏幕边界钳住造成的）——
                    // 说明窗口的布局更新失效了，很可能就是可触达区域 / frame 陈旧。
                    // 打个待重挂标记，等手势结束后由看门狗重建窗口，
                    // 下一次按就能恢复 —— 这是"有时拖不动"唯一可靠的自动修复路径。
                    if (windowStuckWhileMoving) {
                        Log.w(TAG, "本次拖拽窗口始终没动，标记待重挂（下次按就能恢复）")
                        petWindowNeedsReattach = true
                    }

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
     * 体检：悬浮窗是否还挂在 WindowManager 上。
     *
     * 「View 还在、窗口却已经脱挂」是"时好时坏"的经典成因：
     * 这种状态下所有触摸事件都收不到，用户只会看到"按下去没反应、拖不动"，
     * 而且它自己永远不会恢复 —— 除非有人主动把它重新挂上去。
     *
     * 历史上 updateViewLayout 抛异常只被记一行日志就吞掉，
     * 窗口从此脱挂，用户只能靠重装 App 才能救回来。
     *
     * ⚠️ 判据只能用 [isPetWindowAttached] + [android.view.View.isAttachedToWindow]，
     * **绝不能用 `view.parent`**：
     *   WindowManager.addView 挂上去的视图，parent 不是"是否挂在窗口上"的可靠信号，
     *   拿它判定会把"好好挂着"误判成"已脱挂"，
     *   结果每次按下都重建窗口 —— 手势在第一个事件就被打断，宠物根本拖不动。
     *
     * ⚠️ 本方法**绝不能在手势进行中被调用**（见 ACTION_DOWN 分支的说明）。
     *
     * @return true 表示窗口健在（或已当场修好）
     */
    private fun ensurePetWindowAttached(): Boolean {
        val view = pokoView ?: return false
        if (isPetWindowAttached && view.isAttachedToWindow) return true
        Log.w(TAG, "悬浮窗已从 WindowManager 脱挂，准备重新挂载")
        return reattachPetWindow()
    }

    /**
     * 把悬浮窗重新挂回 WindowManager。
     *
     * 挂之前先摘一次，避免 "View already added" 抛异常被静默吞掉、
     * 结果窗口再也挂不上去的情况。
     *
     * ⚠️ 重新挂载等价于"开一扇新窗"：WMS 会为它建一个新的 WindowState，
     * 可触达区域（Touchable Region）从头算一遍。
     * 这正是"悬浮窗从 View.GONE 恢复后按不动"这类问题的解药 ——
     * 只 updateViewLayout 走的是 relayout，frame 没变就不会重算热区。
     */
    private fun reattachPetWindow(): Boolean {
        val view = pokoView ?: return false
        val params = pokoParams ?: return false

        // ⚠️⚠️ **总闸**：手势进行中一律不换窗口。
        //
        // 触摸手势属于**窗口**而不是屏幕：removeView + addView 换掉窗口的那一刻，
        // 系统会把当前这根手指的 MOVE / UP 一起丢掉 ——
        // 表现出来就是「日志里明明打了『进入拖拽』，宠物却纹丝不动」。
        //
        // 这个函数是所有重建路径的总入口（看门狗、挂载体检、显隐恢复、
        // 拖拽失败重试），把闸门放在这里，才能保证**没有任何一条路径**
        // 会在用户正按着宠物的时候把窗口换掉。
        //
        // 只记标记，等手势彻底结束由 attachWatchdog 接手重挂：既不丢手势，又能自愈。
        if (hasTouchDown) {
            petWindowNeedsReattach = true
            Log.w(TAG, "手势进行中不能重建悬浮窗，已记待重挂标记")
            return false
        }

        try {
            windowManager?.removeView(view)
        } catch (_: Exception) {}
        isPetWindowAttached = false
        try {
            windowManager?.addView(view, params)
            isPetWindowAttached = true
            Log.i(TAG, "悬浮窗已重新挂载，拖拽链路恢复")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "悬浮窗重新挂载失败", e)
            return false
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
                // ⚠️ 单写者原则：手指按着的时候，窗口坐标只属于手势处理器。
                // 动画器若在这时继续写 params.x/y，宠物就会一边跟手指一边往动画目标跑，
                // 表现出来就是「拖着还乱飞」。
                if (!hasTouchDown) {
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
            }
            addListener(object : AnimatorListenerAdapter() {
                // ⚠️ Android 在 cancel() 时会**先**回调 onAnimationCancel，**再**回调 onAnimationEnd。
                // 不区分二者的话：用户在惯性滑行途中重新按住宠物 → ACTION_DOWN 里 cancel()
                // → onAnimationEnd 照样触发 → settleAfterDrag() 又启动新的落位吸附动画 →
                // 宠物在新手势进行中自己往边缘滑走。
                // 这就是「有时候拖着还乱飞」的确切来源之一。
                //
                // 注意：不能用 Animator.isCanceled 判定 —— 它不是公开 SDK API，会编译失败。
                private var cancelled = false

                override fun onAnimationCancel(animation: Animator) {
                    cancelled = true
                }

                override fun onAnimationEnd(animation: Animator) {
                    if (cancelled) return
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
        // 记录"恢复之前是不是不可见"，用来区分「刚恢复」和「一直可见」两种路径：
        // 刚恢复的那一次必须重建窗口（见 restorePetWindowForInteraction）。
        val wasVisible = view.visibility == View.VISIBLE
        val target = if (visible) View.VISIBLE else View.GONE
        if (view.visibility != target) {
            view.visibility = target
            Log.d(TAG, "悬浮猫显隐切换 visible=$visible")
        }
        view.setAnimationEnabled(visible)

        if (visible) {
            if (wasVisible) {
                // 一直可见：窗口理应还挂着，位置也得在屏内。
                // 这里只做体检，不重建窗口（重建会让猫闪一下）。
                ensurePetWindowAttached()
                // ⚠️ 手势进行中绝不碰窗口坐标：
                // 一旦在这里改了位置，宠物就会从用户的手指底下跳走。
                if (!hasTouchDown) {
                    val params = pokoParams
                    if (params != null) {
                        clampPetPositionToScreen(params)
                        try {
                            windowManager?.updateViewLayout(view, params)
                        } catch (e: Exception) {
                            Log.e(TAG, "悬浮窗位置刷新失败", e)
                        }
                    }
                }
            } else {
                // ⚠️ 关掉 App 再打开悬浮宠后拖不动 的核心修复点：
                //
                // 悬浮窗在这段时间是 View.GONE，GONE 的视图不参与触摸分发。
                // 恢复成 VISIBLE 之后，**能不能被按住取决于系统给这个窗口算出来的
                // 可触达区域（Touchable Region）是否已经刷新**。
                //
                // 上一版（drag-fix-v5）用的是 updateViewLayout + requestLayout，
                // 实际只是触发了一次 relayout：窗口的 frame 没变，
                // WMS 也就没有理由重算可触达区域，部分 ROM（尤其国产 ROM）上
                // 旧的可触达区域会被保留下来 —— 于是"看得见、点不动"。
                //
                // 真正可靠的做法是**重建窗口**（removeView + addView）：
                // WMS 会为它创建一个全新的 WindowState，可触达区域从头算一遍。
                // 这和"窗口脱挂后重新挂载"是同一条已经被验证过的自愈路径。
                restorePetWindowForInteraction()
            }
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

    /**
     * 把悬浮窗恢复到"可交互"状态：重建窗口 + 位置归位。
     *
     * 什么时候用：悬浮窗刚从 View.GONE 恢复成 VISIBLE 的时候。
     *
     * 为什么必须重建窗口而不是只 updateViewLayout：
     *   可触达区域是 WMS 按窗口的 frame 算出来的，
     *   updateViewLayout 走的是 relayout —— frame 没变就不会重算。
     *   removeView + addView 则会在 WMS 里建一个全新的 WindowState，
     *   可触达区域从头算，"看得见但按不动"的状态被彻底清掉。
     *
     * 重建还会顺带修好两件事：
     *   - 位置跑到屏幕外（旋转 / 分屏 / 存下来的坐标失效）→ 重新钳回屏内；
     *   - 重建会触发 View 的 detach/attach，动画需要重新启动（见末尾）。
     */
    private fun restorePetWindowForInteraction() {
        val view = pokoView ?: return
        val params = pokoParams ?: return

        // ⚠️ 手势进行中不做任何位置/窗口改动（reattachPetWindow 内部也有同样的总闸）。
        // 此刻用户正按着宠物，窗口一动，手势就断了。
        if (hasTouchDown) {
            Log.w(TAG, "手势进行中跳过悬浮窗恢复，交给看门狗")
            return
        }

        // 位置先归位：窗口在屏幕外的话，可触达区域也在屏幕外，用户根本碰不到它
        clampPetPositionToScreen(params)

        // 重建窗口
        val rebuilt = reattachPetWindow()
        if (rebuilt) {
            Log.i(TAG, "悬浮窗已重建，触控热区刷新，拖拽链路恢复 (v$DRAG_FIX_VERSION)")
        } else {
            // 重建失败（多半是悬浮窗权限被收回）：退一步至少把布局刷一次
            Log.e(TAG, "悬浮窗重建失败，退化为 updateViewLayout")
            try {
                windowManager?.updateViewLayout(view, params)
                view.requestLayout()
            } catch (e: Exception) {
                Log.e(TAG, "悬浮窗恢复失败，悬浮宠将无法交互", e)
            }
        }

        // 重建会让 View 走一遍 detach/attach，onDetachedFromWindow 会停掉动画，
        // 这里必须重新把动画拉起来，否则猫会"僵"在桌面上不动。
        view.setAnimationEnabled(true)
    }

    /**
     * 把悬浮窗坐标钳回当前屏幕范围内。
     *
     * 窗口跑到屏幕外的情况比想象中常见：旋转、分屏、折叠屏展开，
     * 或者上次存下来的横向比例在新的屏幕宽度下已经失效。
     * 屏幕外的窗口看得见（如果只露一条边）却摸不到，
     * 因为它的可触达区域同样在屏幕之外。
     */
    private fun clampPetPositionToScreen(params: WindowManager.LayoutParams) {
        val density = resources.displayMetrics.density
        val sizePx = if (params.width > 0) params.width else petSizePx
        val (screenWidth, screenHeight) = getScreenDimensions()
        val maxX = (screenWidth - sizePx).coerceAtLeast(0)
        val (minY, maxY) = getSafeVerticalBounds(density, screenHeight, sizePx)
        val clampedX = params.x.coerceIn(0, maxX)
        val clampedY = params.y.coerceIn(minY, maxY)
        if (clampedX != params.x || clampedY != params.y) {
            Log.w(TAG, "悬浮窗坐标超出屏幕范围，已钳回 ($clampedX, $clampedY)")
            params.x = clampedX
            params.y = clampedY
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
                // ⚠️ 单写者原则：手指按着的时候，窗口坐标只属于手势处理器。
                // 吸附动画若在这时继续把宠物往边缘拉，就会和用户的手指抢方向盘 ——
                // 表现就是「拖着还乱飞」。
                if (!hasTouchDown) {
                    val f = anim.animatedValue as Float
                    params.x = (startX + (targetX - startX) * f).toInt()
                    try {
                        windowManager?.updateViewLayout(pokoView, params)
                        updateBubblePosition()
                    } catch (_: Exception) {}
                }
            }
            addListener(object : AnimatorListenerAdapter() {
                // ⚠️ cancel() 会先回调 onAnimationCancel 再回调 onAnimationEnd。
                // 不区分二者的话，用户按住宠物的瞬间取消吸附动画，
                // onAnimationEnd 里的 scheduleEdgePeeking() 照样会执行 ——
                // 等于在手势进行中又排了一个"把宠物拽回边缘"的任务。
                private var cancelled = false

                override fun onAnimationCancel(animation: Animator) {
                    cancelled = true
                }

                override fun onAnimationEnd(animation: Animator) {
                    if (cancelled) return
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
                // ⚠️ 单写者原则：手指按着的时候，窗口坐标只属于手势处理器。
                // 自主散步若在这时继续挪动 params.y，宠物会一边跟手指一边自己溜达。
                if (!hasTouchDown) {
                    val f = anim.animatedValue as Float
                    params.y = (startY + (targetY - startY) * f).toInt()
                    view.updateWalkingStep(f)
                    try {
                        windowManager?.updateViewLayout(view, params)
                        updateBubblePosition()
                    } catch (_: Exception) {}
                }
            }
            addListener(object : AnimatorListenerAdapter() {
                // ⚠️ cancel() 会先回调 onAnimationCancel 再回调 onAnimationEnd。
                // 不区分二者的话，用户按住宠物打断散步后，
                // onAnimationEnd 里的 scheduleEdgePeeking() 照样执行 ——
                // 5.5 秒后宠物被拽回边缘，而用户此刻正在拖它 → 「拖着还乱飞」。
                private var cancelled = false

                override fun onAnimationCancel(animation: Animator) {
                    cancelled = true
                    isStrolling = false
                    view.stopWalking()
                }

                override fun onAnimationEnd(animation: Animator) {
                    isStrolling = false
                    view.stopWalking()
                    if (cancelled) return
                    scheduleEdgePeeking(!view.facingLeft)
                }
            })
        }
        strollAnimator?.start()
    }

    private fun initSpeechBubble(layoutType: Int, density: Float) {
        val bubble = TextView(this).apply {
            setTextColor(chromeDayText)
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
                setColor(chromeDayBg)
                cornerRadius = 14 * density
                setStroke((1.5f * density).toInt(), chromeDayStroke)
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
                setColor(chromeDayMenuBg)
                cornerRadius = 18 * density
                setStroke((1.5f * density).toInt(), chromeDayStroke)
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
                setBackgroundColor(chromeDayDivider)
                // 登记一下，夜间切换时要一起换色
                chromeDividers.add(this)
            }
        }

        val btnPadH = (9 * density).toInt()
        val btnPadV = (6 * density).toInt()

        val btnPet = TextView(this).apply {
            text = "🐾 摸摸"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
            setTextColor(chromeBtnPetDay)
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
            setTextColor(chromeBtnFeedDay)
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
            setTextColor(chromeBtnHomeDay)
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
            setTextColor(chromeBtnDismissDay)
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
        val edge = (4 * density).toInt()
        val (minY, maxY) = getSafeVerticalBounds(density, screenHeight, menuH)

        // ⚠️ 菜单窗口的 z 序在宠物窗口**之上**。一旦菜单与宠物窗口重叠，
        // 重叠那一块的点击会被菜单吃掉 —— 用户明明按在猫身上，猫却一动不动。
        // 旧实现用 coerceAtMost / coerceAtLeast 把菜单夹在屏幕内，
        // 夹的过程中正好会把菜单拉回宠物身上（屏幕越窄越明显），
        // 于是"拖到屏幕中间就拖不动、拖到边上就能拖" —— 典型的时好时坏。
        //
        // 现在菜单必须整体落在宠物窗口之外；两侧都放不下就改放猫的上方 / 下方。
        val rightX = pParams.x + pokoW + gap
        val leftX = pParams.x - menuW - gap
        val rightFits = rightX >= edge && rightX + menuW + edge <= screenWidth
        val leftFits = leftX >= edge && leftX + menuW + edge <= screenWidth

        var targetX: Int
        var targetY: Int
        if (rightFits || leftFits) {
            targetX = if (rightFits) rightX else leftX
            val preferredY = pParams.y + (pokoH - menuH) / 2
            targetY = preferredY.coerceIn(minY, maxY)
        } else {
            // 两侧都塞不下：改放宠物上方（顶到屏幕边则放下方），同样不压住宠物
            val aboveY = pParams.y - menuH - gap
            val belowY = pParams.y + pokoH + gap
            targetY = if (aboveY >= minY) aboveY else belowY.coerceAtMost(maxY)
            targetX = (pParams.x + (pokoW - menuW) / 2)
                .coerceIn(edge, (screenWidth - menuW - edge).coerceAtLeast(edge))
        }

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

    /**
     * 重建悬浮窗以刷新可触达区域（Touchable Region）。
     *
     * 「看得见、但按不动」在部分国产 ROM 上只有**重建窗口**才能治好：
     * 可触达区域是 WMS 按窗口 frame 算出来的，
     * updateViewLayout 走的是 relayout —— frame 没变就不会重算；
     * removeView + addView 则会在 WMS 里建一个全新的 WindowState，热区从头算。
     *
     * 触发场景（都不依赖"宠物能被按住"，所以是个真正可用的自救入口）：
     *   · 用户从通知栏点「摸摸波可」→ 顺手把窗口重建一次
     *   · 用户从快捷菜单点「摸摸」→ 同上
     *
     * @return true 表示确实重建了
     */
    private fun repairPetWindowForUser(): Boolean {
        if (hasTouchDown) return false
        if (pokoView == null || pokoParams == null) return false
        // 复用"显隐恢复"那条已经验证过的重建路径：
        // 它会 removeView + addView 重建窗口（WMS 重新计算可触达区域），
        // 再把坐标钳回屏内、把动画重新拉起来。
        restorePetWindowForInteraction()
        Log.i(TAG, "已重建悬浮窗（v$DRAG_FIX_VERSION），触控热区已刷新")
        return true
    }

    private fun handleDesktopPet() {
        hideActionMenu()
        // 快捷菜单的「摸摸」也是不依赖宠物可触摸的入口，顺手修一次热区
        repairPetWindowForUser()
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
        // 与宠物本体同一套算法：手指屏幕绝对位置 = 窗口位置 + 窗口局部坐标。
        // 不用 ev.rawX —— 悬浮窗上 raw 坐标的语义（屏幕绝对 / 窗口内）并不稳定，
        // 用它算位移会让小鱼干只跟第一帧就卡住。
        var downFingerX = 0f
        var downFingerY = 0f

        fish.setOnTouchListener { _, ev ->
            when (ev.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    fishStartX = fParams.x
                    fishStartY = fParams.y
                    downFingerX = fParams.x + ev.x
                    downFingerY = fParams.y + ev.y
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val fingerX = fParams.x + ev.x
                    val fingerY = fParams.y + ev.y
                    fParams.x = (fishStartX + (fingerX - downFingerX)).toInt()
                    fParams.y = (fishStartY + (fingerY - downFingerY)).toInt()
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
        if (pokoParams == null) return
        // ⚠️ 拖拽进行中**不能**复位探头偏移：
        //   MOVE 分支每帧都会把 peekOffsetX 写成"拖出屏幕的那一段"，
        //   这里要是把它清零，猫就会在手指底下突然弹回原位 ——
        //   用户看到的是"按着按着猫自己跳了一下"。
        if (isPeeking && !hasTouchDown) {
            restoreFromPeeking()
        }

        bubble.text = text

        val density = resources.displayMetrics.density
        val (screenWidth, _) = getScreenDimensions()

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

        // ⚠️ 位置必须与 updateBubblePosition() 用**同一套**算法，
        // 否则会出现"气泡刚弹出来贴着猫，拖两步就离猫老远"这种前后不一致。
        val (bubbleX, bubbleY) = computeBubblePosition(bubbleW, bubbleH, density)
        bParams.x = bubbleX
        bParams.y = bubbleY

        if (!isBubbleAttached) {
            try {
                windowManager?.addView(bubble, bParams)
                isBubbleAttached = true
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
        // ⚠️ 通知栏的「摸摸」是**完全不依赖宠物能被按住**的唯一入口，
        // 所以它必须兼做一件别的事：把悬浮窗重建一次，刷新可触达区域。
        // 「看得见但点不动」只有重建窗口才能治好（见 repairPetWindowForUser）。
        //
        // 这给用户留了一条自救通道：猫按不动的时候，
        // 下拉通知栏点一下「摸摸波可」，猫就又能拖了。
        repairPetWindowForUser()
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

    // ---------- 昼夜模式 ----------

    /** App 推送过来的昼夜状态（null 表示还没收到过推送） */
    private var appNightMode: Boolean? = null

    /**
     * App 推送过来的昼夜边界（当天第几分钟）。
     *
     * dayStartMinute   —— 白天的起始（日出前 0.6 小时，破晓晨曦）
     * nightStartMinute —— 夜间的起始（日落后 0.5 小时，暮色四合）
     *
     * 这两个边界来自 App 的真实太阳天文算法（SolarService），
     * 桌面这边只负责"拿当前时间比一比"，**不重复实现天文算法**，
     * 这样即使 App 被杀掉，桌面上的昼夜也依然跟着太阳走。
     *
     * 手动切换光影模式（破晓/晴空/晚霞/星夜）时 App 会推 -1，
     * 表示"以推送的昼夜布尔值为准"。
     *
     * 用"分钟数"而不是"小时小数"传，是为了躲开 Flutter Double →
     * Bundle 的类型坑（Double 存进去，`getFloatExtra` 只会静默返回默认值）。
     */
    private var appDayStartMinute: Int = -1
    private var appNightStartMinute: Int = -1

    /** 当前是否处于夜间 */
    private var isNightMode: Boolean = false

    /**
     * 判定当前该不该用夜间配色。
     *
     * 优先级：
     * 1. App 推来的日出/日落边界 + 当前本地时间 → 最准，跟真实太阳一致
     * 2. App 推来的昼夜布尔值（手动切换光影模式时用这个）
     * 3. 系统深色模式（App 从来没接管过时的兜底）
     */
    private fun resolveNightMode(): Boolean {
        if (appDayStartMinute >= 0 && appNightStartMinute >= 0) {
            val minuteOfDay = currentMinuteOfDay()
            return minuteOfDay >= appNightStartMinute || minuteOfDay < appDayStartMinute
        }
        appNightMode?.let { return it }
        return try {
            val uiMode = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
            uiMode?.nightMode == UiModeManager.MODE_NIGHT_YES
        } catch (_: Exception) {
            false
        }
    }

    /** 当前本地时间在当天的第几分钟（0 ~ 1439） */
    private fun currentMinuteOfDay(): Int {
        val calendar = Calendar.getInstance()
        return calendar.get(Calendar.HOUR_OF_DAY) * 60 + calendar.get(Calendar.MINUTE)
    }

    /** 把夜间配色应用到悬浮窗 */
    private fun applyNightMode(enabled: Boolean) {
        isNightMode = enabled
        // 注意：这里直接赋值属性，而不是调 view.setNightMode(enabled) ——
        // PokoPetView 的 public 属性 isNightMode 的隐式 setter 就是 setNightMode，
        // 那边不能再定义同名函数（JVM 签名会撞车）。
        //
        // 夜间在猫身上**只影响瞳孔**（夜里瞳孔自然舒张，与 App 一致），
        // 毛色一律保持皮肤原色 —— 同一个 App 里，桌面的猫和窝里的猫必须一模一样。
        pokoView?.isNightMode = enabled
        applyNightChrome(enabled)
    }

    /**
     * 把悬浮窗的 UI 配件（气泡 / 快捷菜单）按昼夜切换配色。
     *
     * ⚠️ 这里**只改配件、不改猫本体**：App 里的猫本体永远是皮肤原色，
     * 桌面这边也必须一样，否则同一只猫在两个地方会长得不一样。
     * 夜间配色与 App 内的夜间弹层同源（深靛底 0xFF1E1B4B + 浅字 + 靛紫描边）。
     */
    private fun applyNightChrome(enabled: Boolean) {
        val density = resources.displayMetrics.density
        // 变量名刻意加 Color 后缀：太通用的名字（bg / text / stroke）很容易和
        // 别的函数里的局部变量撞名，守护测试会当成"跨函数引用局部变量"而报警。
        val bgColor = if (enabled) chromeNightBg else chromeDayBg
        val textColor = if (enabled) chromeNightText else chromeDayText
        val strokeColor = if (enabled) chromeNightStroke else chromeDayStroke
        val dividerColor = if (enabled) chromeNightDivider else chromeDayDivider

        // 注意 lambda 参数名也不能和别的函数里的局部变量重名
        bubbleView?.let { bubbleTarget ->
            bubbleTarget.setTextColor(textColor)
            bubbleTarget.background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(bgColor)
                cornerRadius = 14 * density
                setStroke((1.5f * density).toInt(), strokeColor)
            }
        }

        actionMenuView?.let { menuTarget ->
            menuTarget.background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(if (enabled) chromeNightBg else chromeDayMenuBg)
                cornerRadius = 18 * density
                setStroke((1.5f * density).toInt(), strokeColor)
            }
            applyChromeTextColor(menuTarget)
            chromeDividers.forEach { it.setBackgroundColor(dividerColor) }
        }
    }

    /**
     * 遍历菜单子树，把按钮文字在"日间配色 ↔ 夜间配色"之间来回切换。
     *
     * 用的是**对合映射**（日→夜、夜→日），所以反复切换不会跑偏。
     */
    private fun applyChromeTextColor(root: View) {
        if (root is TextView) {
            root.setTextColor(chromeTextColorFor(root.currentTextColor))
        }
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                applyChromeTextColor(root.getChildAt(i))
            }
        }
    }

    /** 日夜文字色对合映射 */
    private fun chromeTextColorFor(color: Int): Int = when (color) {
        chromeBtnPetDay -> chromeBtnPetNight
        chromeBtnFeedDay -> chromeBtnFeedNight
        chromeBtnHomeDay -> chromeBtnHomeNight
        chromeBtnDismissDay -> chromeBtnDismissNight
        chromeBtnPetNight -> chromeBtnPetDay
        chromeBtnFeedNight -> chromeBtnFeedDay
        chromeBtnHomeNight -> chromeBtnHomeDay
        chromeBtnDismissNight -> chromeBtnDismissDay
        else -> color
    }

    /** 接收 App 推送的昼夜状态（以及可选的日出/日落边界，单位：当天第几分钟） */
    fun applyNightModeFromApp(
        enabled: Boolean,
        dayStartMinute: Int = -1,
        nightStartMinute: Int = -1,
    ) {
        appNightMode = enabled
        appDayStartMinute = dayStartMinute
        appNightStartMinute = nightStartMinute
        applyNightMode(resolveNightMode())
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

    /**
     * 气泡该摆在哪：统一由这里算，**显示**与**跟随**两条路径共用同一套算法。
     *
     * ⚠️ 以前"弹出来的时候算一次位置"和"拖拽时更新位置"是两段各写各的代码，
     * 规则还不一样 —— 于是会出现"气泡一出现就贴着猫，拖两步就离猫老远"。
     *
     * 两个必须处理好的点：
     *
     * ① **气泡要跟着"看得见的猫"走，而不是跟着窗口走**。
     *    探头避让、把猫推出屏幕边缘时，猫是用**绘制偏移**画在窗口之外的
     *    （见 PokoPetView.peekOffsetX），窗口坐标一点没动。
     *    只按窗口坐标摆气泡，贴边时气泡就会离猫老远 —— 用户看到的就是"气泡和猫对不上"。
     *
     * ② **气泡比猫宽得多**（猫 82dp，气泡最多 200dp）。
     *    一律"与猫居中对齐"的话，气泡会从猫身上歪出去一大截；
     *    贴边时再被屏幕边界钳一下，气泡就被推得离猫更远。
     *    所以放不下时要**贴着猫的那一侧**摆，而不是让屏幕边界把气泡推离猫。
     */
    private fun computeBubblePosition(
        bubbleW: Int,
        bubbleH: Int,
        density: Float
    ): Pair<Int, Int> {
        val pParams = pokoParams ?: return 0 to 0
        val (screenWidth, screenHeight) = getScreenDimensions()
        val pokoW = pokoView?.width?.takeIf { it > 0 } ?: petSizePx

        // 猫**实际画出来**的位置：窗口位置 + 绘制偏移
        val catX = pParams.x + (pokoView?.peekOffsetX ?: 0f)
        val catRight = catX + pokoW
        val catCenter = catX + pokoW / 2f

        // 上下：气泡挂在猫头顶上方；顶到屏幕上沿就翻到猫下方
        val minY = (28 * density).toInt()
        val preferredY = pParams.y - bubbleH - (6 * density).toInt()
        val newY = if (preferredY < minY) {
            (pParams.y + pokoW + (6 * density).toInt())
                .coerceAtMost((screenHeight - bubbleH - (16 * density).toInt()).coerceAtLeast(0))
        } else {
            preferredY
        }

        // 左右：先尝试与猫居中对齐
        val minX = (10 * density).toInt()
        val maxX = (screenWidth - bubbleW - (10 * density).toInt()).coerceAtLeast(minX)
        val centered = (catCenter - bubbleW / 2f).toInt()
        val newX = if (centered in minX..maxX) {
            centered
        } else {
            // 居中放不下：让气泡贴着猫的一侧，而不是被屏幕边界推离猫
            if (catCenter < screenWidth / 2f) {
                // 猫在左半屏：气泡左边缘与猫左边缘对齐
                catX.toInt().coerceIn(minX, maxX)
            } else {
                // 猫在右半屏：气泡右边缘与猫右边缘对齐
                (catRight - bubbleW).toInt().coerceIn(minX, maxX)
            }
        }
        return newX to newY
    }

    private fun updateBubblePosition() {
        val bubble = bubbleView ?: return
        val bParams = bubbleParams ?: return
        if (bubble.visibility != View.VISIBLE || !isBubbleAttached) return

        val density = resources.displayMetrics.density
        val (screenWidth, _) = getScreenDimensions()
        val bubbleW = bubble.width.coerceAtLeast((100 * density).toInt())
        val bubbleH = bubble.height.coerceAtLeast((36 * density).toInt())

        val (newX, newY) = computeBubblePosition(bubbleW, bubbleH, density)

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
                return
            }

            // ⚠️ 看门狗：上面那次 `isAppForeground = true` 是**手工**置位的，
            // 正常情况下要靠主 Activity 的 onPause 复位。可一旦 startActivity 没能
            // 真正把 Activity 拉起来（被系统拦、任务栈异常、进程正在退出），
            // 这个 true 就悬空了 —— 没人复位它，宠物会永久停在 GONE，
            // 而 GONE 的视图根本不参与触摸分发，用户只会看到「关掉 App 再打开悬浮宠后拖不动」。
            //
            // 这里兜底：超时后如果主 Activity 从未 resume 过，就把悬空标记收回。
            // ⚠️ Handler.removeCallbacks 的参数在 Android SDK 里是**非空**的，
            // 直接把可空的 foregroundWatchdog 传进去会编译失败（CI 上就是这么炸的）。
            foregroundWatchdog?.let { mainHandler.removeCallbacks(it) }
            foregroundWatchdog = Runnable {
                if (!isMainActivityResumed) {
                    Log.w(TAG, "主 Activity 未真正前台化，收回悬空的前台标记，悬浮猫恢复可触摸")
                    isAppForeground = false
                    refreshPetVisibility()
                }
            }
            mainHandler.postDelayed(foregroundWatchdog!!, FOREGROUND_WATCHDOG_DELAY_MS)
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

        // 记下"排任务时波可停在哪"，等任务真正执行时用来判断它有没有被挪走
        val scheduledParams = pokoParams
        peekScheduledX = scheduledParams?.x ?: 0
        peekScheduledY = scheduledParams?.y ?: 0

        peekingRunnable = Runnable {
            if (!screenOn || isAppForeground || isStrolling || hasTouchDown) return@Runnable
            val params = pokoParams ?: return@Runnable
            val view = pokoView ?: return@Runnable
            val (screenWidth, _) = getScreenDimensions()
            val density = resources.displayMetrics.density
            val sizePx = petSizePx
            val edgeThreshold = (4 * density).toInt()

            // ⚠️⚠️ 运行时必须**重新**确认波可此刻还停在边缘。
            //
            // 排任务时判定在边缘，5.5 秒之后完全可能早就不在边缘了
            // （用户把它拖到了屏幕中间，或者甩到了另一边）。
            // 旧实现只在排任务时检查一次，运行时就直接
            //   params.x = dockedX      ← 把窗口硬拽回边缘
            // 于是：宠物明明停在屏幕中间，却突然自己跑到边缘；
            // 更糟的是 dockedX 用的是 **5.5 秒前捕获的 isLeft**，
            // 宠物被拖到另一侧时会被"横跨屏幕"瞬移回原来那侧。
            // 用户看到的就是「有时候拖着还乱飞」——
            // 而且 5.5 秒的时序窗口，恰好解释了「时好时坏」。
            if (!isPetDockedAtEdge()) return@Runnable

            // 也确认波可没被挪到别处去（拖走 / 甩飞 / 被别的动画挪走）
            val driftTolerance = (24 * density).toInt()
            if (abs(params.x - peekScheduledX) > driftTolerance ||
                abs(params.y - peekScheduledY) > driftTolerance
            ) {
                Log.d(
                    TAG,
                    "探头任务放弃：波可已从排任务时的位置 (${peekScheduledX}, ${peekScheduledY}) " +
                        "挪到 (${params.x}, ${params.y})"
                )
                return@Runnable
            }

            // ⚠️ 停靠侧必须按**当前**窗口位置判定，不能沿用排任务时传入的 isLeft：
            // 5.5 秒里宠物可能被拖到另一侧，沿用旧值会把它瞬移回原来的边。
            val maxX = (screenWidth - sizePx).coerceAtLeast(0)
            val snapRange = (10 * density).toInt()
            val dockedOnLeft = params.x <= snapRange

            // 探头前先把窗口贴到对应边缘；探头过程只靠"窗口内绘制偏移"完成，窗口不再移动
            val dockedX = if (dockedOnLeft) {
                edgeThreshold
            } else {
                (screenWidth - sizePx - edgeThreshold).coerceAtLeast(0)
            }
            // 只允许"贴边"级别的微调；位移过大说明状态已经不可信，宁可不碰
            if (abs(params.x - dockedX) <= snapRange && params.x != dockedX) {
                params.x = dockedX
                try {
                    windowManager?.updateViewLayout(view, params)
                } catch (e: Exception) {
                    Log.e(TAG, "探头前贴边失败", e)
                }
            }

            Log.d(
                TAG,
                "探头执行：当前在${if (dockedOnLeft) "左" else "右"}侧 " +
                    "(排任务时的参考侧=${if (isLeft) "左" else "右"}) x=${params.x}"
            )

            // 向屏幕边缘外侧避让收纳 32%：左侧边缘向左藏、右侧边缘向右藏
            //
            // ⚠️ peekOffsetX 是**屏幕坐标系**的位移（正 = 向屏幕右侧），
            // 与猫面朝哪边无关（见 PokoPetView.peekOffsetX 的约定说明）。
            // 镜像只翻"猫面朝哪边"，不翻偏移方向 ——
            // 否则贴右边躲的波可会往屏幕内侧滑，探头完全反了向。
            //
            // 偏移发生在绘制层，窗口坐标不变 —— 拖拽起点与手指位移始终一一对应
            val peekOffset = if (dockedOnLeft) (-sizePx * 0.32f) else (sizePx * 0.32f)

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

        // ⚠️ 复位动画必须纳入 peekOffsetAnimator 统一托管。
        // 之前这里是匿名 ValueAnimator：既不持有引用、也没人取消它，
        // 于是它会在拖拽期间继续改写 peekOffsetX，和探头动画、溢出回收动画抢同一个属性。
        // 一旦三者打架，"看到的猫"就和"能按到的窗口区域"对不上，
        // 手指按在猫身上却落在窗口之外 —— 表现出来就是间歇性拖不动。
        peekOffsetAnimator = ValueAnimator.ofFloat(currentOffset, 0f).apply {
            duration = 200
            interpolator = OvershootInterpolator(1.8f)
            addUpdateListener { anim ->
                view.peekOffsetX = anim.animatedValue as Float
            }
        }
        peekOffsetAnimator?.start()
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
        isPetWindowAttached = false
        mainHandler.removeCallbacks(attachWatchdog)
        mainHandler.removeCallbacks(touchHeartbeat)
        cancelEdgePeeking()
        isPeeking = false
        unregisterPetDataListener()
        longPressRunnable?.let { mainHandler.removeCallbacks(it) }
        soundPool?.release()
        soundPool = null
        mainHandler.removeCallbacks(edgeStrollRunnable)
        mainHandler.removeCallbacks(autoChatRunnable)
        foregroundWatchdog?.let { mainHandler.removeCallbacks(it) }
        foregroundWatchdog = null
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
        isBubbleAttached = false

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
