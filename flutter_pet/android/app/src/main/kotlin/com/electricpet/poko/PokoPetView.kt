package com.electricpet.poko

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.view.animation.LinearInterpolator
import android.view.animation.OvershootInterpolator
import java.util.Random
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * 桌面悬浮萌宠 · 波可 (Poko) 终极高活力原生矢量动效渲染 View
 *
 * 核心动效矩阵：
 * 1. 自主萌趣行为状态机：伸懒腰打哈欠、洗脸舔爪、歪头萌看、原地小跳步、踩奶踏踏、困困瞌睡冒 Zzz
 * 2. 悬空物理拖拽：拎起后颈皮、小短腿自然悬空蹬爪、惯性物理摆动、松手果冻回弹着陆缓冲
 * 3. 丰富微表情：水灵大眼睛、开怀眯眼笑 (^ ‿ ^)、伸懒腰紧闭眼 (> ‿ <)、瞌睡平闭 (-- ‿ --)、拎起呆萌大圆眼 (o . o)
 * 4. 多重粒子生态：治愈红粉爱心、梦幻漂浮 Zzz 气泡、欢快金光星芒
 * 5. 全面性能优化：对象池复用，onDraw 零内存分配，支持无损暂停省电
 */
class PokoPetView(context: Context) : View(context) {

    private val density = resources.displayMetrics.density
    private val random = Random()

    // ---------- 皮肤与外观配置 ----------
    var skinId: String = "cat_calico"
        set(value) {
            field = value
            updateColors()
            invalidate()
        }

    var petName: String = "波可"

    // 屏幕朝向：贴在右边缘时面朝左 (facingLeft = true)；贴在左边缘时面朝右
    var facingLeft: Boolean = false
        set(value) {
            if (field != value) {
                field = value
                invalidate()
            }
        }

    // ---------- 动作与表情枚举 ----------
    enum class PetAction {
        IDLE,         // 待机呼吸 (起伏呼吸、尾巴轻摇、耳朵微动)
        STRETCH,      // 伸大懒腰打哈欠 (前爪探伸、身躯拉长、猫嘴大张、抖抖毛)
        WASH_FACE,    // 洗脸舔爪爪 (右爪抬起至脸颊、吐小粉舌舔舔、轻柔揉脸3次)
        HEAD_TILT,    // 歪头好奇萌看 (大头倾斜16°、眼珠子灵动机灵转动)
        HAPPY_BOUNCE, // 快乐小跳步 (原地欢脱连蹦两下、尾巴高翘甩动、金星迸发)
        KNEADING,     // 软糯踩奶踏踏 (左右前爪交替轻踩、身躯软糯左右微晃)
        SLEEPY,       // 困困打瞌睡 (小脑袋一点一点、深层慢呼吸、缓缓升起Zzz气泡)
        SPIN_TAIL,    // 追尾巴原地打转 (360°旋转转圈圈、尾巴弯折翘起、星芒四射)
        WALKING,      // 桌面边缘小碎步漫步 (四爪交替踏步、轻快身躯微颠、小尾巴轻摆)
        DRAGGING,     // 拎起悬空 (身体纵向拉长、四爪悬空扑腾乱蹬、惯性倾斜)
        PETTED        // 抚摸享受 (Q弹果冻回弹、双眼眯成月牙笑、大量爱心喷发)
    }

    enum class EyeMood {
        NORMAL,       // 晶莹明亮大眸子
        HAPPY_SMILE,  // 欢快弯弯月牙眯眯笑 (^ ‿ ^)
        SLEEPY,       // 困困安详平闭眼 (-- ‿ --)
        SQUINT_YAWN,  // 伸懒腰用力紧闭眼 (> ‿ <)
        WIDE_SURPRISE // 拎起悬空圆溜溜大眼 (o . o)
    }

    enum class MouthState {
        NORMAL_OMEGA, // 治愈经典 ω 小猫嘴
        YAWN_OPEN,    // 伸懒腰大张嘴打哈欠
        BLEP_TONGUE,  // 吐露小粉舌 (舔爪/卖萌)
        HAPPY_OPEN    // 开心大嘴欢呼
    }

    var currentAction: PetAction = PetAction.IDLE
        private set

    // ---------- 动画状态量与骨骼参数 ----------
    private var breathY: Float = 0f
    private var scaleXVal: Float = 1f
    private var scaleYVal: Float = 1f
    private var tailAngle: Float = 0f
    private var earTwitch: Float = 0f
    private var isBlinking: Boolean = false
    private var isDragging: Boolean = false

    // 头部变换
    private var headTiltAngle: Float = 0f
    private var headOffsetY: Float = 0f
    private var pupilOffsetX: Float = 0f
    private var pupilOffsetY: Float = 0f

    // 爪爪动态偏移 (洗脸、踩奶、伸懒腰、悬空乱蹬)
    private var leftPawOffsetX: Float = 0f
    private var leftPawOffsetY: Float = 0f
    private var rightPawOffsetX: Float = 0f
    private var rightPawOffsetY: Float = 0f

    // 身体起伏与跳跃
    private var jumpOffsetY: Float = 0f
    private var bodyStretchX: Float = 1f
    private var bodyStretchY: Float = 1f
    private var bodyLeanAngle: Float = 0f
    private var spinAngle: Float = 0f

    // 触控果冻回弹挤压形变
    private var squishScaleX: Float = 1f
    private var squishScaleY: Float = 1f

    // 表情状态
    private var eyeMood: EyeMood = EyeMood.NORMAL
    private var mouthState: MouthState = MouthState.NORMAL_OMEGA

    // 动画运行器
    private var idleAnimator: ValueAnimator? = null
    private var currentActionAnimator: ValueAnimator? = null
    private var squishAnimator: ValueAnimator? = null
    private var isAnimationEnabled: Boolean = true

    // 粒子系统 (爱心 + 梦幻 Zzz + 金星芒)
    private val particles = mutableListOf<Particle>()

    // ---------- 颜色系统 ----------
    private var primaryColor: Int = Color.parseColor("#FED7AA")
    private var secondaryColor: Int = Color.parseColor("#EA580C")
    private var eyeColor: Int = Color.parseColor("#10B981")
    private var darkPatchColor: Int = Color.parseColor("#334155")

    // ---------- 画笔与路径缓存 (严格避免 onDraw 分配内存) ----------
    private val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val headPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bellyPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val earPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val innerEarPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val blushPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val irisPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val pupilPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val sparklePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
    private val smileEyePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val nosePaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val mouthPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val tonguePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#FB7185") }
    private val whiskerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val pawPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val pawBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
    }
    private val tailPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
    }
    private val shadowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val particlePaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textParticlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        textAlign = Paint.Align.CENTER
    }

    private val earPath = Path()
    private val innerEarPath = Path()
    private val nosePath = Path()
    private val mouthPath = Path()
    private val tailPath = Path()
    private val patchPath = Path()
    private val eyePath = Path()
    private val heartPath = Path()
    private val starPath = Path()

    // 眨眼定时调度
    private val blinkRunnable = object : Runnable {
        override fun run() {
            if (!isDragging && currentAction == PetAction.IDLE && eyeMood == EyeMood.NORMAL) {
                isBlinking = true
                invalidate()
                postDelayed({
                    isBlinking = false
                    invalidate()
                }, 160)
            }
            val nextDelay = (2800 + random.nextInt(2200)).toLong()
            postDelayed(this, nextDelay)
        }
    }

    // 自主随机动作调度器 (每隔 5~9 秒自动演绎一个超级生动的猫咪日常动作)
    private val autonomousActionRunnable = object : Runnable {
        override fun run() {
            if (isAnimationEnabled && !isDragging && currentAction == PetAction.IDLE) {
                triggerRandomAutonomousAction()
            }
            val nextInterval = (5200 + random.nextInt(3800)).toLong()
            postDelayed(this, nextInterval)
        }
    }

    init {
        setLayerType(LAYER_TYPE_HARDWARE, null)
        isClickable = true
        isFocusable = false
        initParticlePaths()
        updateColors()
        startIdleAnimation()
        postDelayed(blinkRunnable, 2200)
        postDelayed(autonomousActionRunnable, 4000)
    }

    private fun initParticlePaths() {
        heartPath.reset()
        heartPath.moveTo(0f, 3.5f * density)
        heartPath.cubicTo(
            -4.5f * density, -1.5f * density,
            -4.5f * density, -5.5f * density,
            0f, -2.5f * density
        )
        heartPath.cubicTo(
            4.5f * density, -5.5f * density,
            4.5f * density, -1.5f * density,
            0f, 3.5f * density
        )
        heartPath.close()

        starPath.reset()
        starPath.moveTo(0f, -5f * density)
        starPath.lineTo(1.5f * density, -1.5f * density)
        starPath.lineTo(5f * density, 0f)
        starPath.lineTo(1.5f * density, 1.5f * density)
        starPath.lineTo(0f, 5f * density)
        starPath.lineTo(-1.5f * density, 1.5f * density)
        starPath.lineTo(-5f * density, 0f)
        starPath.lineTo(-1.5f * density, -1.5f * density)
        starPath.close()
    }

    override fun performClick(): Boolean {
        super.performClick()
        return true
    }

    fun applyConfig(newSkinId: String?, newPetName: String?) {
        if (!newSkinId.isNullOrBlank()) {
            skinId = newSkinId
        }
        if (!newPetName.isNullOrBlank()) {
            petName = newPetName
        }
    }

    private fun updateColors() {
        when (skinId) {
            "cat_calico" -> {
                primaryColor = Color.parseColor("#FFFDF8")
                secondaryColor = Color.parseColor("#FF9E7D")
                darkPatchColor = Color.parseColor("#475569")
                eyeColor = Color.parseColor("#10B981")
            }
            "cat_golden_shaded" -> {
                primaryColor = Color.parseColor("#FED7AA")
                secondaryColor = Color.parseColor("#D97706")
                darkPatchColor = Color.parseColor("#92400E")
                eyeColor = Color.parseColor("#059669")
            }
            "cat_orange" -> {
                primaryColor = Color.parseColor("#FED7AA")
                secondaryColor = Color.parseColor("#EA580C")
                darkPatchColor = Color.parseColor("#C2410C")
                eyeColor = Color.parseColor("#FBBF24")
            }
            "cat_british_blue" -> {
                primaryColor = Color.parseColor("#64748B")
                secondaryColor = Color.parseColor("#475569")
                darkPatchColor = Color.parseColor("#334155")
                eyeColor = Color.parseColor("#F59E0B")
            }
            "cat_ragdoll" -> {
                primaryColor = Color.parseColor("#FFFDF8")
                secondaryColor = Color.parseColor("#8E9AAF")
                darkPatchColor = Color.parseColor("#64748B")
                eyeColor = Color.parseColor("#0284C7")
            }
            "cat_tuxedo" -> {
                primaryColor = Color.parseColor("#1E293B")
                secondaryColor = Color.parseColor("#FFFFFF")
                darkPatchColor = Color.parseColor("#0F172A")
                eyeColor = Color.parseColor("#FACC15")
            }
            "cat_siamese" -> {
                primaryColor = Color.parseColor("#FAF5EF")
                secondaryColor = Color.parseColor("#5C3D2E")
                darkPatchColor = Color.parseColor("#3E2723")
                eyeColor = Color.parseColor("#38BDF8")
            }
            "cat_black" -> {
                primaryColor = Color.parseColor("#0F172A")
                secondaryColor = Color.parseColor("#1E293B")
                darkPatchColor = Color.parseColor("#020617")
                eyeColor = Color.parseColor("#FACC15")
            }
            "cat_sakura_peach" -> {
                primaryColor = Color.parseColor("#FFF0F5")
                secondaryColor = Color.parseColor("#F472B6")
                darkPatchColor = Color.parseColor("#FB7185")
                eyeColor = Color.parseColor("#FB7185")
            }
            else -> {
                primaryColor = Color.parseColor("#FED7AA")
                secondaryColor = Color.parseColor("#EA580C")
                darkPatchColor = Color.parseColor("#C2410C")
                eyeColor = Color.parseColor("#10B981")
            }
        }
    }

    // ---------- 核心待机基础动画 ----------
    private fun startIdleAnimation() {
        idleAnimator?.cancel()
        idleAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2200
            repeatCount = ValueAnimator.INFINITE
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                if (currentAction != PetAction.IDLE && currentAction != PetAction.DRAGGING) return@addUpdateListener

                val f = anim.animatedValue as Float
                val rad = (f * 2.0 * Math.PI).toFloat()

                if (currentAction == PetAction.IDLE) {
                    // 大幅度有生命感的有机呼吸与骨骼微缩放
                    breathY = sin(rad) * 3.8f * density
                    scaleXVal = 1f - sin(rad) * 0.038f
                    scaleYVal = 1f + sin(rad) * 0.048f
                    // 柔和优雅的猫尾波浪甩尾
                    tailAngle = sin(rad * 1.4f) * 20f
                    // 周期机灵轻抖耳朵
                    earTwitch = if (sin(rad * 3f) > 0.88f) sin(rad * 20f) * 4.5f * density else 0f
                } else if (currentAction == PetAction.DRAGGING) {
                    // 悬空时四肢轻轻蹬踩扑腾
                    val paddleRad = (f * 4.0 * Math.PI).toFloat()
                    leftPawOffsetY = sin(paddleRad) * 4.5f * density
                    rightPawOffsetY = -sin(paddleRad) * 4.5f * density
                    tailAngle = -18f + sin(paddleRad * 0.5f) * 10f
                }

                invalidate()
            }
        }
        idleAnimator?.start()
    }

    // ---------- 自主萌宠行为状态机 ----------
    private fun triggerRandomAutonomousAction() {
        val actions = listOf(
            PetAction.STRETCH,       // 伸懒腰打哈欠
            PetAction.WASH_FACE,     // 洗脸舔爪
            PetAction.HEAD_TILT,     // 歪头萌看
            PetAction.HAPPY_BOUNCE,  // 快乐小跳步
            PetAction.KNEADING,      // 踩奶踏踏
            PetAction.SLEEPY,        // 困困瞌睡冒 Zzz
            PetAction.SPIN_TAIL      // 追尾巴转圈打转
        )
        val selected = actions[random.nextInt(actions.size)]
        executeAction(selected)
    }

    fun executeAction(action: PetAction) {
        if (isDragging) return
        currentActionAnimator?.cancel()
        currentAction = action

        when (action) {
            PetAction.STRETCH -> performStretchAction()
            PetAction.WASH_FACE -> performWashFaceAction()
            PetAction.HEAD_TILT -> performHeadTiltAction()
            PetAction.HAPPY_BOUNCE -> performHappyBounceAction()
            PetAction.KNEADING -> performKneadingAction()
            PetAction.SLEEPY -> performSleepyAction()
            PetAction.SPIN_TAIL -> performSpinTailAction()
            else -> resetToIdleState()
        }
    }

    /** 1. 伸懒腰打哈欠：前爪向前深探、身体舒展拉长、猫嘴大张、用力眯眼、抖抖身子 */
    private fun performStretchAction() {
        currentActionAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2600
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                val p = anim.animatedValue as Float
                when {
                    p < 0.25f -> { // 向前下俯舒展探爪
                        val sub = p / 0.25f
                        bodyStretchX = 1f + sub * 0.16f
                        bodyStretchY = 1f - sub * 0.14f
                        leftPawOffsetY = sub * 7.5f * density
                        rightPawOffsetY = sub * 7.5f * density
                        headOffsetY = sub * 4.5f * density
                        tailAngle = sub * 32f
                        eyeMood = EyeMood.SQUINT_YAWN
                        mouthState = MouthState.NORMAL_OMEGA
                    }
                    p < 0.70f -> { // 张开小嘴打大哈欠~ 身体微抖舒缓
                        bodyStretchX = 1.16f
                        bodyStretchY = 0.86f
                        leftPawOffsetY = 7.5f * density
                        rightPawOffsetY = 7.5f * density
                        headOffsetY = 4.5f * density
                        tailAngle = 32f + sin((p - 0.25f) * 40f) * 6f
                        eyeMood = EyeMood.SQUINT_YAWN
                        mouthState = MouthState.YAWN_OPEN
                    }
                    else -> { // 收回懒腰，恢复饱满精神
                        val sub = (p - 0.70f) / 0.30f
                        bodyStretchX = 1.16f - sub * 0.16f
                        bodyStretchY = 0.86f + sub * 0.14f
                        leftPawOffsetY = (1f - sub) * 7.5f * density
                        rightPawOffsetY = (1f - sub) * 7.5f * density
                        headOffsetY = (1f - sub) * 4.5f * density
                        tailAngle = (1f - sub) * 32f
                        eyeMood = if (sub > 0.7f) EyeMood.NORMAL else EyeMood.HAPPY_SMILE
                        mouthState = MouthState.NORMAL_OMEGA
                    }
                }
                invalidate()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    resetToIdleState()
                }
            })
        }
        currentActionAnimator?.start()
    }

    /** 2. 洗脸舔爪：右爪抬起至嘴边、吐小粉舌舔舔、揉脸揉耳3次 */
    private fun performWashFaceAction() {
        currentActionAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2700
            interpolator = LinearInterpolator()
            addUpdateListener { anim ->
                val p = anim.animatedValue as Float
                when {
                    p < 0.20f -> { // 右爪抬起至嘴角
                        val sub = p / 0.20f
                        rightPawOffsetX = -sub * 5f * density
                        rightPawOffsetY = -sub * 16f * density
                        headTiltAngle = sub * 6f
                        mouthState = MouthState.BLEP_TONGUE
                        eyeMood = EyeMood.HAPPY_SMILE
                    }
                    p < 0.80f -> { // 绕脸颊揉圆洗脸 3 次
                        val cycleRad = ((p - 0.20f) / 0.60f * 6.0 * Math.PI).toFloat()
                        rightPawOffsetX = -5f * density + sin(cycleRad) * 4.5f * density
                        rightPawOffsetY = -16f * density + cos(cycleRad) * 4.5f * density
                        headTiltAngle = 6f + sin(cycleRad) * 3f
                        mouthState = if (sin(cycleRad) > 0.3f) MouthState.BLEP_TONGUE else MouthState.NORMAL_OMEGA
                        eyeMood = EyeMood.HAPPY_SMILE
                    }
                    else -> { // 放下爪子回原位
                        val sub = (p - 0.80f) / 0.20f
                        rightPawOffsetX = -5f * density * (1f - sub)
                        rightPawOffsetY = -16f * density * (1f - sub)
                        headTiltAngle = 6f * (1f - sub)
                        mouthState = MouthState.NORMAL_OMEGA
                        eyeMood = EyeMood.NORMAL
                    }
                }
                invalidate()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    resetToIdleState()
                }
            })
        }
        currentActionAnimator?.start()
    }

    /** 3. 歪头萌看：大脑袋倾斜18°、大眼珠机灵左右转动看主人 */
    private fun performHeadTiltAction() {
        val tiltSign = if (random.nextBoolean()) 1f else -1f
        currentActionAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2200
            interpolator = OvershootInterpolator(1.4f)
            addUpdateListener { anim ->
                val p = anim.animatedValue as Float
                when {
                    p < 0.25f -> { // 歪头
                        val sub = p / 0.25f
                        headTiltAngle = sub * 18f * tiltSign
                        pupilOffsetX = sub * 3.5f * density * tiltSign
                        pupilOffsetY = -sub * 1.5f * density
                        earTwitch = sub * 5f * density
                        eyeMood = EyeMood.NORMAL
                    }
                    p < 0.75f -> { // 定住好奇注视，眼珠灵动微动
                        headTiltAngle = 18f * tiltSign
                        pupilOffsetX = 3.5f * density * tiltSign + sin((p - 0.25f) * 20f) * 1.2f * density
                        pupilOffsetY = -1.5f * density
                        earTwitch = 5f * density
                        eyeMood = EyeMood.NORMAL
                    }
                    else -> { // 回正
                        val sub = (p - 0.75f) / 0.25f
                        headTiltAngle = (1f - sub) * 18f * tiltSign
                        pupilOffsetX = (1f - sub) * 3.5f * density * tiltSign
                        pupilOffsetY = (1f - sub) * -1.5f * density
                        earTwitch = (1f - sub) * 5f * density
                    }
                }
                invalidate()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    resetToIdleState()
                }
            })
        }
        currentActionAnimator?.start()
    }

    /** 4. 快乐小跳步：双脚离地欢快蹦跳两下，金星芒粒子迸发 */
    private fun performHappyBounceAction() {
        currentActionAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2000
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                val p = anim.animatedValue as Float
                // 两次蹦跳周期
                val bounceRad = (p * 4.0 * Math.PI).toFloat()
                val jumpF = sin(bounceRad).coerceAtLeast(0f)
                jumpOffsetY = -jumpF * 14f * density

                if (jumpF > 0.05f) {
                    bodyStretchX = 0.92f
                    bodyStretchY = 1.12f
                    eyeMood = EyeMood.HAPPY_SMILE
                    tailAngle = sin(bounceRad * 2f) * 38f
                } else {
                    bodyStretchX = 1.08f
                    bodyStretchY = 0.94f
                    eyeMood = EyeMood.HAPPY_SMILE
                    tailAngle = 10f
                }
                invalidate()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationStart(animation: Animator) {
                    spawnStars()
                }
                override fun onAnimationEnd(animation: Animator) {
                    resetToIdleState()
                }
            })
        }
        currentActionAnimator?.start()
    }

    /** 5. 软糯踩奶：左右前爪交替踏步，身躯软糯左右晃动 */
    private fun performKneadingAction() {
        currentActionAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2400
            interpolator = LinearInterpolator()
            addUpdateListener { anim ->
                val p = anim.animatedValue as Float
                val kneadRad = (p * 6.0 * Math.PI).toFloat()
                leftPawOffsetY = sin(kneadRad) * 4.5f * density
                rightPawOffsetY = -sin(kneadRad) * 4.5f * density
                bodyLeanAngle = sin(kneadRad * 0.5f) * 4f
                eyeMood = EyeMood.HAPPY_SMILE
                mouthState = MouthState.NORMAL_OMEGA
                invalidate()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    resetToIdleState()
                }
            })
        }
        currentActionAnimator?.start()
    }

    /** 6. 困困打瞌睡：双眼安详闭合，身体变扁，缓缓升起 Zzz 气泡 */
    private fun performSleepyAction() {
        currentActionAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 3400
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                val p = anim.animatedValue as Float
                when {
                    p < 0.20f -> { // 慢慢耷拉脑袋闭眼
                        val sub = p / 0.20f
                        eyeMood = EyeMood.SLEEPY
                        headOffsetY = sub * 4f * density
                        bodyStretchY = 1f - sub * 0.08f
                        bodyStretchX = 1f + sub * 0.08f
                    }
                    p < 0.85f -> { // 深度睡眠，平稳深呼吸
                        eyeMood = EyeMood.SLEEPY
                        headOffsetY = 4f * density + sin(p * 20f) * 1.5f * density
                        bodyStretchY = 0.92f
                        bodyStretchX = 1.08f
                    }
                    else -> { // 慢慢醒来
                        val sub = (p - 0.85f) / 0.15f
                        eyeMood = if (sub > 0.5f) EyeMood.NORMAL else EyeMood.SLEEPY
                        headOffsetY = 4f * density * (1f - sub)
                        bodyStretchY = 0.92f + sub * 0.08f
                        bodyStretchX = 1.08f - sub * 0.08f
                    }
                }
                invalidate()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationStart(animation: Animator) {
                    spawnZzzParticles()
                }
                override fun onAnimationEnd(animation: Animator) {
                    resetToIdleState()
                }
            })
        }
        currentActionAnimator?.start()
    }

    /** 7. 追尾巴原地打转转：两圈 360° 欢乐高速旋转，尾巴兴奋高翘，小爪蹬步，金星迸发 */
    private fun performSpinTailAction() {
        currentActionAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2400
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                val p = anim.animatedValue as Float
                when {
                    p < 0.15f -> { // 准备起转：小猫盯向尾巴，身体微曲
                        val sub = p / 0.15f
                        spinAngle = sub * 25f
                        tailAngle = sub * 40f
                        eyeMood = EyeMood.WIDE_SURPRISE
                        mouthState = MouthState.NORMAL_OMEGA
                        headTiltAngle = -sub * 12f
                    }
                    p < 0.75f -> { // 连续两圈高速转圈圈 (25° -> 720°)！
                        val sub = (p - 0.15f) / 0.60f
                        spinAngle = 25f + sub * 695f
                        tailAngle = 40f + sin(sub * 20f) * 15f
                        // 爪子快速交替踏动
                        leftPawOffsetY = sin(sub * 30f) * 4f * density
                        rightPawOffsetY = -sin(sub * 30f) * 4f * density
                        eyeMood = EyeMood.HAPPY_SMILE
                        mouthState = MouthState.BLEP_TONGUE
                    }
                    p < 0.90f -> { // 转完停下，微有眩晕晃头 (摇摇晃晃)
                        val sub = (p - 0.75f) / 0.15f
                        spinAngle = 720f
                        headTiltAngle = sin(sub * 16f) * (8f * (1f - sub))
                        leftPawOffsetY = 0f
                        rightPawOffsetY = 0f
                        eyeMood = EyeMood.WIDE_SURPRISE
                        mouthState = MouthState.BLEP_TONGUE
                    }
                    else -> { // 恢复常态
                        val sub = (p - 0.90f) / 0.10f
                        spinAngle = 0f
                        headTiltAngle = 0f
                        eyeMood = EyeMood.NORMAL
                        mouthState = MouthState.NORMAL_OMEGA
                        tailAngle = (1f - sub) * 20f
                    }
                }
                invalidate()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationStart(animation: Animator) {
                    spawnStars()
                }
                override fun onAnimationEnd(animation: Animator) {
                    spinAngle = 0f
                    resetToIdleState()
                }
            })
        }
        currentActionAnimator?.start()
    }

    // ---------- 边缘漫步走动接口 ----------
    fun startWalking() {
        if (isDragging) return
        currentActionAnimator?.cancel()
        currentAction = PetAction.WALKING
        eyeMood = EyeMood.NORMAL
        mouthState = MouthState.NORMAL_OMEGA
    }

    fun updateWalkingStep(progress: Float) {
        if (currentAction != PetAction.WALKING) return
        val rad = (progress * 6.0 * Math.PI).toFloat()
        // 前爪交替迈步踏动
        leftPawOffsetY = sin(rad) * 4.5f * density
        rightPawOffsetY = -sin(rad) * 4.5f * density
        // 身体轻快微颠跳步
        jumpOffsetY = -abs(sin(rad)) * 2.8f * density
        // 身体小幅度欢快左右微摆
        bodyLeanAngle = sin(rad * 0.5f) * 4f
        // 尾巴随步子有节奏左右微甩
        tailAngle = sin(rad * 0.7f) * 16f
        invalidate()
    }

    fun stopWalking() {
        if (currentAction == PetAction.WALKING) {
            resetToIdleState()
        }
    }

    private fun resetToIdleState() {
        currentAction = PetAction.IDLE
        headTiltAngle = 0f
        headOffsetY = 0f
        pupilOffsetX = 0f
        pupilOffsetY = 0f
        leftPawOffsetX = 0f
        leftPawOffsetY = 0f
        rightPawOffsetX = 0f
        rightPawOffsetY = 0f
        jumpOffsetY = 0f
        bodyStretchX = 1f
        bodyStretchY = 1f
        bodyLeanAngle = 0f
        spinAngle = 0f
        eyeMood = EyeMood.NORMAL
        mouthState = MouthState.NORMAL_OMEGA
        invalidate()
    }

    // ---------- 触控抚摸与果冻物理 ----------
    fun onPetTapped() {
        currentActionAnimator?.cancel()
        currentAction = PetAction.PETTED
        squishAnimator?.cancel()

        // 阶段一：受力瞬间横向挤压膨胀、纵向压扁
        val squishDown = ValueAnimator.ofFloat(1f, 1.25f).apply {
            duration = 90
            addUpdateListener {
                squishScaleX = it.animatedValue as Float
                squishScaleY = 2f - squishScaleX
                eyeMood = EyeMood.HAPPY_SMILE
                mouthState = MouthState.BLEP_TONGUE
                invalidate()
            }
        }

        // 阶段二：释放瞬间 Overshoot 弹性回弹缓冲
        val squishBounce = ValueAnimator.ofFloat(1.25f, 1f).apply {
            duration = 380
            interpolator = OvershootInterpolator(2.8f)
            addUpdateListener {
                squishScaleX = it.animatedValue as Float
                squishScaleY = 2f - squishScaleX
                invalidate()
            }
        }

        squishDown.addListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator) {
                squishBounce.start()
            }
        })
        squishBounce.addListener(object : AnimatorListenerAdapter() {
            override fun onAnimationEnd(animation: Animator) {
                resetToIdleState()
            }
        })
        squishDown.start()

        // 喷发治愈爱心粒子
        spawnHearts()
    }

    // ---------- 拖拽拎起悬空物理系统 ----------
    fun onDragStateChanged(dragging: Boolean) {
        if (isDragging != dragging) {
            isDragging = dragging
            currentActionAnimator?.cancel()

            if (dragging) {
                currentAction = PetAction.DRAGGING
                eyeMood = EyeMood.WIDE_SURPRISE
                mouthState = MouthState.NORMAL_OMEGA
                bodyStretchX = 0.88f
                bodyStretchY = 1.16f
                tailAngle = -18f
            } else {
                // 放手瞬间触发果冻落地缓冲回弹！
                triggerLandingBounce()
            }
            invalidate()
        }
    }

    fun updateDragVelocity(vx: Float) {
        if (!isDragging) return
        bodyLeanAngle = (vx * 0.12f).coerceIn(-22f, 22f)
        invalidate()
    }

    fun triggerLandingBounce() {
        val landAnim = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 360
            interpolator = OvershootInterpolator(2.4f)
            addUpdateListener { anim ->
                val f = anim.animatedValue as Float
                // 先压缩压扁、后弹性归位
                val compression = sin(f * Math.PI.toFloat())
                bodyStretchX = 1f + compression * 0.18f
                bodyStretchY = 1f - compression * 0.18f
                jumpOffsetY = 0f
                bodyLeanAngle = 0f
                invalidate()
            }
            addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: Animator) {
                    resetToIdleState()
                }
            })
        }
        landAnim.start()
        spawnHearts()
    }

    fun setAnimationEnabled(enabled: Boolean) {
        isAnimationEnabled = enabled
        if (enabled) {
            if (idleAnimator?.isRunning != true) {
                startIdleAnimation()
            }
            removeCallbacks(blinkRunnable)
            postDelayed(blinkRunnable, 2200)
            removeCallbacks(autonomousActionRunnable)
            postDelayed(autonomousActionRunnable, 3500)
        } else {
            idleAnimator?.cancel()
            currentActionAnimator?.cancel()
            squishAnimator?.cancel()
            removeCallbacks(blinkRunnable)
            removeCallbacks(autonomousActionRunnable)
            particles.clear()
        }
    }

    // ---------- 粒子生成生态 ----------
    private fun spawnHearts() {
        val cx = width / 2f
        val cy = height * 0.35f
        for (i in 0..2) {
            val offsetX = (random.nextFloat() - 0.5f) * 26f * density
            val speedX = (random.nextFloat() - 0.5f) * 1.8f * density
            val speedY = -(2.8f + random.nextFloat() * 2.2f) * density
            val scale = 0.85f + random.nextFloat() * 0.55f
            particles.add(Particle(ParticleType.HEART, cx + offsetX, cy, speedX, speedY, scale, 1f))
        }
        invalidate()
    }

    private fun spawnStars() {
        val cx = width / 2f
        val cy = height * 0.40f
        for (i in 0..3) {
            val angle = random.nextFloat() * 2.0 * Math.PI
            val speed = (2.0f + random.nextFloat() * 2.5f) * density
            val speedX = (cos(angle) * speed).toFloat()
            val speedY = (sin(angle) * speed - 1.5f * density).toFloat()
            val scale = 0.7f + random.nextFloat() * 0.5f
            particles.add(Particle(ParticleType.STAR, cx, cy, speedX, speedY, scale, 1f))
        }
        invalidate()
    }

    private fun spawnZzzParticles() {
        val cx = width / 2f + 16f * density
        val cy = height * 0.28f
        for (i in 0..2) {
            val delayY = i * 8f * density
            val speedX = (0.5f + random.nextFloat() * 0.4f) * density
            val speedY = -(1.2f + random.nextFloat() * 0.8f) * density
            val scale = 0.7f + i * 0.25f
            particles.add(Particle(ParticleType.ZZZ, cx, cy - delayY, speedX, speedY, scale, 1f, text = if (i == 2) "Z" else "z"))
        }
        invalidate()
    }

    // ---------- 绘制核心管线 ----------
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        val size = MeasureSpec.getSize(widthMeasureSpec)
        setMeasuredDimension(size, size)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0 || h <= 0) return

        canvas.save()

        // 1. 边缘停驻朝向镜像 (贴在屏幕右边缘时面向内测左方)
        if (facingLeft) {
            canvas.scale(-1f, 1f, w / 2f, h / 2f)
        }

        val cx = w / 2f
        val cy = h * 0.53f + jumpOffsetY

        // 2. 独立物理环境阴影 (跳跃或悬空时阴影变小虚化)
        val shadowScale = (1f + jumpOffsetY / (30f * density)).coerceIn(0.4f, 1.2f)
        val shadowAlpha = (28 * shadowScale).toInt().coerceIn(6, 35)
        shadowPaint.color = Color.argb(shadowAlpha, 15, 23, 42)
        canvas.drawOval(
            cx - 24f * density * shadowScale,
            h * 0.53f + 22f * density,
            cx + 24f * density * shadowScale,
            h * 0.53f + 29f * density,
            shadowPaint
        )

        // 3. 骨骼与动作形变坐标变换
        canvas.save()
        canvas.translate(cx, cy + breathY)
        canvas.rotate(bodyLeanAngle + spinAngle)
        canvas.scale(scaleXVal * squishScaleX * bodyStretchX, scaleYVal * squishScaleY * bodyStretchY)
        canvas.translate(-cx, -cy)

        // 4. 灵动猫尾 (位于身体后侧摇曳)
        drawTail(canvas, cx, cy)

        // 5. 浑圆身躯与腹部花纹
        drawBody(canvas, cx, cy)

        // 6. 呆萌大头与动态歪头/眨眼/双耳
        drawHead(canvas, cx, cy)

        // 7. 灵巧动态肉爪 (洗脸/踩奶/悬空乱蹬/伸懒腰)
        drawPaws(canvas, cx, cy)

        canvas.restore() // 恢复身体变换

        // 8. 绘制漂浮上升的粒子群 (爱心 / 闪烁星芒 / 梦幻 Zzz)
        drawParticles(canvas)

        canvas.restore() // 恢复朝向矩阵
    }

    private fun drawTail(canvas: Canvas, cx: Float, cy: Float) {
        val tailBaseX = cx + 13f * density
        val tailBaseY = cy + 12f * density
        val angleRad = (tailAngle * Math.PI / 180.0).toFloat()
        val tailTipX = cx + 25f * density + sin(angleRad) * 13f * density
        val tailTipY = cy - 13f * density + cos(angleRad) * 5f * density

        tailPath.reset()
        tailPath.moveTo(tailBaseX, tailBaseY)
        tailPath.cubicTo(
            cx + 26f * density, cy + 16f * density,
            cx + 33f * density, cy - 2f * density,
            tailTipX, tailTipY
        )

        tailPaint.color = if (skinId == "cat_siamese") secondaryColor else primaryColor
        tailPaint.strokeWidth = 7.5f * density
        canvas.drawPath(tailPath, tailPaint)

        // 尾尖绒球
        val tipColor = when (skinId) {
            "cat_tuxedo" -> Color.WHITE
            "cat_calico", "cat_ragdoll", "cat_siamese" -> secondaryColor
            else -> primaryColor
        }
        val tipPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = tipColor }
        canvas.drawCircle(tailTipX, tailTipY, 4.4f * density, tipPaint)
    }

    private fun drawBody(canvas: Canvas, cx: Float, cy: Float) {
        val bodyRect = RectF(cx - 24f * density, cy - 6f * density, cx + 24f * density, cy + 25f * density)

        // 3D 渐变体积光影
        bodyPaint.shader = RadialGradient(
            cx - 6f * density, cy - 2f * density, 34f * density,
            lightenColor(primaryColor, 0.20f), primaryColor, Shader.TileMode.CLAMP
        )
        canvas.drawOval(bodyRect, bodyPaint)

        // 软糯雪白肚腩
        val bellyRect = RectF(cx - 15f * density, cy + 1f * density, cx + 15f * density, cy + 23f * density)
        bellyPaint.color = Color.parseColor("#FFFDF8")
        canvas.drawOval(bellyRect, bellyPaint)

        // 品种专属斑纹 (三花斑块 / 橘猫虎斑)
        if (skinId == "cat_calico") {
            val patchPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = secondaryColor }
            canvas.drawOval(
                RectF(cx + 9f * density, cy + 3f * density, cx + 21f * density, cy + 16f * density),
                patchPaint
            )
            val darkPatch = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = darkPatchColor }
            canvas.drawOval(
                RectF(cx - 21f * density, cy + 7f * density, cx - 11f * density, cy + 19f * density),
                darkPatch
            )
        } else if (skinId == "cat_orange" || skinId == "cat_golden_shaded") {
            val stripePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = secondaryColor
                style = Paint.Style.STROKE
                strokeWidth = 1.8f * density
                strokeCap = Paint.Cap.ROUND
            }
            canvas.drawLine(cx + 12f * density, cy + 4f * density, cx + 21f * density, cy + 8f * density, stripePaint)
            canvas.drawLine(cx + 10f * density, cy + 9f * density, cx + 20f * density, cy + 13f * density, stripePaint)
            canvas.drawLine(cx - 12f * density, cy + 4f * density, cx - 21f * density, cy + 8f * density, stripePaint)
            canvas.drawLine(cx - 10f * density, cy + 9f * density, cx - 20f * density, cy + 13f * density, stripePaint)
        }
    }

    private fun drawHead(canvas: Canvas, cx: Float, cy: Float) {
        val headY = cy - 10f * density + headOffsetY
        val headW = 27f * density
        val headH = 21f * density

        // 歪头动作坐标系
        canvas.save()
        if (headTiltAngle != 0f) {
            canvas.rotate(headTiltAngle, cx, headY)
        }

        // 1. 双耳 (位于头部后侧)
        drawEars(canvas, cx, headY)

        // 2. 圆润大头轮廓 (微包子脸发腮)
        val headRect = RectF(cx - headW, headY - headH, cx + headW, headY + headH)
        headPaint.shader = RadialGradient(
            cx - 5f * density, headY - 6f * density, 34f * density,
            lightenColor(primaryColor, 0.22f), primaryColor, Shader.TileMode.CLAMP
        )
        canvas.drawOval(headRect, headPaint)

        // 额头斑纹
        if (skinId == "cat_calico") {
            patchPath.reset()
            patchPath.moveTo(cx + 5f * density, headY - 20f * density)
            patchPath.quadTo(cx + 22f * density, headY - 14f * density, cx + 21f * density, headY - 2f * density)
            patchPath.quadTo(cx + 11f * density, headY - 8f * density, cx + 5f * density, headY - 20f * density)
            val patchPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = secondaryColor }
            canvas.drawPath(patchPath, patchPaint)
        } else if (skinId == "cat_tuxedo") {
            val blazePath = Path().apply {
                moveTo(cx, headY - 14f * density)
                lineTo(cx - 7f * density, headY + 5f * density)
                quadTo(cx, headY + 8f * density, cx + 7f * density, headY + 5f * density)
                close()
            }
            canvas.drawPath(blazePath, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
        }

        // 3. 粉嫩腮红
        val blushAlpha = if (eyeMood == EyeMood.HAPPY_SMILE || squishScaleX > 1.05f) 140 else 80
        blushPaint.color = Color.argb(blushAlpha, 251, 113, 133)
        canvas.drawOval(
            RectF(cx - 19f * density, headY + 2f * density, cx - 11f * density, headY + 8f * density),
            blushPaint
        )
        canvas.drawOval(
            RectF(cx + 11f * density, headY + 2f * density, cx + 19f * density, headY + 8f * density),
            blushPaint
        )

        // 4. 水灵大眼与丰富表情
        drawEyes(canvas, cx, headY)

        // 5. 心形小肉鼻与治愈猫嘴
        drawNoseAndMouth(canvas, cx, headY)

        // 6. 柔和触须
        drawWhiskers(canvas, cx, headY)

        canvas.restore() // 恢复歪头旋转
    }

    private fun drawEars(canvas: Canvas, cx: Float, headY: Float) {
        val earBaseColor = if (skinId == "cat_siamese") secondaryColor else primaryColor
        earPaint.color = earBaseColor
        innerEarPaint.color = Color.parseColor("#FDA4AF")

        // 左耳
        earPath.reset()
        earPath.moveTo(cx - 22f * density, headY - 7f * density)
        earPath.lineTo(cx - 19f * density - earTwitch, headY - 25f * density)
        earPath.lineTo(cx - 6f * density, headY - 16f * density)
        earPath.close()
        canvas.drawPath(earPath, earPaint)

        innerEarPath.reset()
        innerEarPath.moveTo(cx - 18f * density, headY - 9f * density)
        innerEarPath.lineTo(cx - 17f * density - earTwitch, headY - 21f * density)
        innerEarPath.lineTo(cx - 9f * density, headY - 15f * density)
        innerEarPath.close()
        canvas.drawPath(innerEarPath, innerEarPaint)

        // 右耳
        earPath.reset()
        earPath.moveTo(cx + 22f * density, headY - 7f * density)
        earPath.lineTo(cx + 19f * density + earTwitch, headY - 25f * density)
        earPath.lineTo(cx + 6f * density, headY - 16f * density)
        earPath.close()
        canvas.drawPath(earPath, earPaint)

        innerEarPath.reset()
        innerEarPath.moveTo(cx + 18f * density, headY - 9f * density)
        innerEarPath.lineTo(cx + 17f * density + earTwitch, headY - 21f * density)
        innerEarPath.lineTo(cx + 9f * density, headY - 15f * density)
        innerEarPath.close()
        canvas.drawPath(innerEarPath, innerEarPaint)
    }

    private fun drawEyes(canvas: Canvas, cx: Float, headY: Float) {
        val eyeY = headY - 2.5f * density
        val leftEyeX = cx - 11f * density
        val rightEyeX = cx + 11f * density

        val effectiveMood = when {
            isBlinking -> EyeMood.HAPPY_SMILE
            squishScaleX > 1.05f -> EyeMood.HAPPY_SMILE
            else -> eyeMood
        }

        when (effectiveMood) {
            EyeMood.HAPPY_SMILE -> {
                // 开心欢畅月牙笑眼 ⌒ ⌒
                smileEyePaint.color = Color.parseColor("#1E293B")
                smileEyePaint.strokeWidth = 2.4f * density

                eyePath.reset()
                eyePath.moveTo(leftEyeX - 4.5f * density, eyeY)
                eyePath.quadTo(leftEyeX, eyeY - 4.5f * density, leftEyeX + 4.5f * density, eyeY)
                canvas.drawPath(eyePath, smileEyePaint)

                eyePath.reset()
                eyePath.moveTo(rightEyeX - 4.5f * density, eyeY)
                eyePath.quadTo(rightEyeX, eyeY - 4.5f * density, rightEyeX + 4.5f * density, eyeY)
                canvas.drawPath(eyePath, smileEyePaint)
            }
            EyeMood.SLEEPY -> {
                // 困困安详平闭眼 ── ──
                smileEyePaint.color = Color.parseColor("#334155")
                smileEyePaint.strokeWidth = 2.0f * density

                canvas.drawLine(leftEyeX - 4.2f * density, eyeY, leftEyeX + 4.2f * density, eyeY, smileEyePaint)
                canvas.drawLine(rightEyeX - 4.2f * density, eyeY, rightEyeX + 4.2f * density, eyeY, smileEyePaint)
            }
            EyeMood.SQUINT_YAWN -> {
                // 伸懒腰紧闭双眼 > <
                smileEyePaint.color = Color.parseColor("#1E293B")
                smileEyePaint.strokeWidth = 2.2f * density

                // 左眼 >
                eyePath.reset()
                eyePath.moveTo(leftEyeX - 3.8f * density, eyeY - 3f * density)
                eyePath.lineTo(leftEyeX + 2.5f * density, eyeY)
                eyePath.lineTo(leftEyeX - 3.8f * density, eyeY + 3f * density)
                canvas.drawPath(eyePath, smileEyePaint)

                // 右眼 <
                eyePath.reset()
                eyePath.moveTo(rightEyeX + 3.8f * density, eyeY - 3f * density)
                eyePath.lineTo(rightEyeX - 2.5f * density, eyeY)
                eyePath.lineTo(rightEyeX + 3.8f * density, eyeY + 3f * density)
                canvas.drawPath(eyePath, smileEyePaint)
            }
            EyeMood.WIDE_SURPRISE -> {
                // 拎起悬空呆萌圆溜溜大眼 (o . o)
                val eyeRadius = 6.2f * density
                for (eyeX in listOf(leftEyeX, rightEyeX)) {
                    irisPaint.color = eyeColor
                    canvas.drawCircle(eyeX, eyeY, eyeRadius, irisPaint)

                    // 巨型黑曜石圆瞳
                    pupilPaint.color = Color.parseColor("#070B14")
                    canvas.drawCircle(eyeX, eyeY, 4.6f * density, pupilPaint)

                    // 闪耀高光
                    canvas.drawCircle(eyeX - 1.8f * density, eyeY - 1.8f * density, 1.8f * density, sparklePaint)
                    canvas.drawCircle(eyeX + 1.8f * density, eyeY + 1.8f * density, 1.0f * density, sparklePaint)
                }
            }
            EyeMood.NORMAL -> {
                // 晶莹璀璨大眼球，随注视偏移动态对焦
                val eyeRadiusW = 4.6f * density
                val eyeRadiusH = 5.8f * density

                for (eyeX in listOf(leftEyeX, rightEyeX)) {
                    irisPaint.color = eyeColor
                    canvas.drawOval(
                        RectF(eyeX - eyeRadiusW, eyeY - eyeRadiusH, eyeX + eyeRadiusW, eyeY + eyeRadiusH),
                        irisPaint
                    )

                    // 黑曜石瞳孔 (带注视偏移)
                    pupilPaint.color = Color.parseColor("#070B14")
                    canvas.drawOval(
                        RectF(
                            eyeX - 3.0f * density + pupilOffsetX,
                            eyeY - 4.5f * density + pupilOffsetY,
                            eyeX + 3.0f * density + pupilOffsetX,
                            eyeY + 4.5f * density + pupilOffsetY
                        ),
                        pupilPaint
                    )

                    // 双重高光星芒
                    canvas.drawCircle(eyeX - 1.4f * density, eyeY - 2.0f * density, 1.6f * density, sparklePaint)
                    canvas.drawCircle(eyeX + 1.5f * density, eyeY + 1.6f * density, 0.9f * density, sparklePaint)
                }
            }
        }
    }

    private fun drawNoseAndMouth(canvas: Canvas, cx: Float, headY: Float) {
        val noseY = headY + 3.2f * density

        // 心形粉嫩肉鼻
        nosePath.reset()
        nosePath.moveTo(cx - 2.5f * density, noseY - 1.4f * density)
        nosePath.quadTo(cx, noseY - 2.2f * density, cx + 2.5f * density, noseY - 1.4f * density)
        nosePath.quadTo(cx + 2.0f * density, noseY + 1.5f * density, cx, noseY + 2.4f * density)
        nosePath.quadTo(cx - 2.0f * density, noseY + 1.5f * density, cx - 2.5f * density, noseY - 1.4f * density)
        nosePaint.color = Color.parseColor("#FB7185")
        canvas.drawPath(nosePath, nosePaint)

        // 嘴部与舌头形态
        when (mouthState) {
            MouthState.YAWN_OPEN -> {
                // 打哈欠大张嘴：深粉嫩大口腔 + 柔和舌头
                val mouthRect = RectF(cx - 4.8f * density, noseY + 2.5f * density, cx + 4.8f * density, noseY + 10f * density)
                val innerMouthPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#E11D48") }
                canvas.drawOval(mouthRect, innerMouthPaint)
                canvas.drawOval(
                    RectF(cx - 3f * density, noseY + 6.5f * density, cx + 3f * density, noseY + 10.5f * density),
                    tonguePaint
                )
            }
            MouthState.BLEP_TONGUE -> {
                // 治愈 ω 嘴 + 萌吐舌尖 (Blep)
                drawOmegaMouth(canvas, cx, noseY)
                canvas.drawOval(
                    RectF(cx - 2.4f * density, noseY + 4.2f * density, cx + 2.4f * density, noseY + 8.2f * density),
                    tonguePaint
                )
            }
            MouthState.HAPPY_OPEN -> {
                // 开心欢笑微张口
                val smileRect = RectF(cx - 4.2f * density, noseY + 2.8f * density, cx + 4.2f * density, noseY + 8f * density)
                val happyMouth = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#F43F5E") }
                canvas.drawOval(smileRect, happyMouth)
            }
            MouthState.NORMAL_OMEGA -> {
                // 经典治愈微笑嘴 ω
                drawOmegaMouth(canvas, cx, noseY)
                // 触碰挤压时微露粉舌
                if (squishScaleX > 1.05f) {
                    canvas.drawOval(
                        RectF(cx - 2.2f * density, noseY + 4.2f * density, cx + 2.2f * density, noseY + 7.8f * density),
                        tonguePaint
                    )
                }
            }
        }
    }

    private fun drawOmegaMouth(canvas: Canvas, cx: Float, noseY: Float) {
        mouthPaint.color = Color.parseColor("#334155")
        mouthPaint.strokeWidth = 1.4f * density

        mouthPath.reset()
        mouthPath.moveTo(cx, noseY + 2.4f * density)
        mouthPath.lineTo(cx, noseY + 4.0f * density)
        mouthPath.quadTo(cx - 3.2f * density, noseY + 7.0f * density, cx - 6.2f * density, noseY + 4.8f * density)
        mouthPath.moveTo(cx, noseY + 4.0f * density)
        mouthPath.quadTo(cx + 3.2f * density, noseY + 7.0f * density, cx + 6.2f * density, noseY + 4.8f * density)
        canvas.drawPath(mouthPath, mouthPaint)
    }

    private fun drawWhiskers(canvas: Canvas, cx: Float, headY: Float) {
        val whiskerColor = if (skinId == "cat_black" || skinId == "cat_tuxedo") Color.parseColor("#F1F5F9") else Color.parseColor("#8094A3B8")
        whiskerPaint.color = whiskerColor
        whiskerPaint.strokeWidth = 1.1f * density

        val baseNoseY = headY + 3.5f * density

        // 左侧 3 根微垂胡须
        canvas.drawLine(cx - 7f * density, baseNoseY + 0.5f * density, cx - 21f * density, baseNoseY - 2f * density, whiskerPaint)
        canvas.drawLine(cx - 7f * density, baseNoseY + 2.5f * density, cx - 23f * density, baseNoseY + 3f * density, whiskerPaint)
        canvas.drawLine(cx - 7f * density, baseNoseY + 4.5f * density, cx - 20f * density, baseNoseY + 8f * density, whiskerPaint)

        // 右侧 3 根微垂胡须
        canvas.drawLine(cx + 7f * density, baseNoseY + 0.5f * density, cx + 21f * density, baseNoseY - 2f * density, whiskerPaint)
        canvas.drawLine(cx + 7f * density, baseNoseY + 2.5f * density, cx + 23f * density, baseNoseY + 3f * density, whiskerPaint)
        canvas.drawLine(cx + 7f * density, baseNoseY + 4.5f * density, cx + 20f * density, baseNoseY + 8f * density, whiskerPaint)
    }

    private fun drawPaws(canvas: Canvas, cx: Float, cy: Float) {
        pawPaint.color = Color.parseColor("#FFFDF8")
        pawBorderPaint.color = Color.argb(26, 0, 0, 0)
        pawBorderPaint.strokeWidth = 1.0f * density

        val pawW = 5.6f * density
        val pawH = 4.3f * density
        val basePawY = cy + 22f * density

        // 动态计算左爪位置 (支持洗脸/踩奶/伸懒腰/悬空乱蹬)
        val leftX = cx - 9.5f * density + leftPawOffsetX
        val leftY = basePawY + leftPawOffsetY
        val leftRect = RectF(leftX - pawW, leftY - pawH, leftX + pawW, leftY + pawH)
        canvas.drawOval(leftRect, pawPaint)
        canvas.drawOval(leftRect, pawBorderPaint)
        canvas.drawLine(leftX, leftY - 0.5f * density, leftX, leftY + pawH, pawBorderPaint)

        // 动态计算右爪位置
        val rightX = cx + 9.5f * density + rightPawOffsetX
        val rightY = basePawY + rightPawOffsetY
        val rightRect = RectF(rightX - pawW, rightY - pawH, rightX + pawW, rightY + pawH)
        canvas.drawOval(rightRect, pawPaint)
        canvas.drawOval(rightRect, pawBorderPaint)
        canvas.drawLine(rightX, rightY - 0.5f * density, rightX, rightY + pawH, pawBorderPaint)
    }

    // ---------- 多元粒子系统绘制 (爱心 + 梦幻 Zzz + 金星芒) ----------
    private fun drawParticles(canvas: Canvas) {
        if (particles.isEmpty()) return

        val it = particles.iterator()
        while (it.hasNext()) {
            val p = it.next()
            p.x += p.vx
            p.y += p.vy
            p.alpha -= p.fadeSpeed

            if (p.alpha <= 0f) {
                it.remove()
                continue
            }

            canvas.save()
            canvas.translate(p.x, p.y)
            canvas.scale(p.scale, p.scale)

            when (p.type) {
                ParticleType.HEART -> {
                    particlePaint.color = Color.argb((p.alpha * 240).toInt(), 244, 63, 94)
                    particlePaint.style = Paint.Style.FILL
                    canvas.drawPath(heartPath, particlePaint)
                }
                ParticleType.STAR -> {
                    particlePaint.color = Color.argb((p.alpha * 245).toInt(), 250, 204, 21) // 璀璨金黄
                    particlePaint.style = Paint.Style.FILL
                    canvas.drawPath(starPath, particlePaint)
                }
                ParticleType.ZZZ -> {
                    textParticlePaint.color = Color.argb((p.alpha * 220).toInt(), 96, 165, 250) // 治愈天青蓝
                    textParticlePaint.textSize = 13f * density * p.scale
                    canvas.drawText(p.text, 0f, 0f, textParticlePaint)
                }
            }
            canvas.restore()
        }

        if (particles.isNotEmpty()) {
            postInvalidateOnAnimation()
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        idleAnimator?.cancel()
        currentActionAnimator?.cancel()
        squishAnimator?.cancel()
        removeCallbacks(blinkRunnable)
        removeCallbacks(autonomousActionRunnable)
    }

    private fun lightenColor(color: Int, amount: Float): Int {
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        val nr = (r + (255 - r) * amount).toInt().coerceIn(0, 255)
        val ng = (g + (255 - g) * amount).toInt().coerceIn(0, 255)
        val nb = (b + (255 - b) * amount).toInt().coerceIn(0, 255)
        return Color.argb(Color.alpha(color), nr, ng, nb)
    }

    private enum class ParticleType { HEART, STAR, ZZZ }

    private data class Particle(
        val type: ParticleType,
        var x: Float,
        var y: Float,
        var vx: Float,
        var vy: Float,
        var scale: Float,
        var alpha: Float,
        val fadeSpeed: Float = 0.028f,
        val text: String = "z"
    )
}
