package com.electricpet.poko

import android.animation.Animator
import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.content.Context
import android.graphics.*
import android.view.View
import android.view.animation.DecelerateInterpolator
import android.view.animation.OvershootInterpolator
import java.util.Random
import kotlin.math.cos
import kotlin.math.sin

/**
 * 桌面悬浮萌宠 · 波可 (Poko) 原生矢量动效渲染 View
 * 具备灵动机体呼吸、猫尾轻摇、周期自然眨眼、戳戳果冻 Q 弹挤压物理、双向屏幕视线自适应与爱心气泡粒子
 */
class PokoPetView(context: Context) : View(context) {

    private val density = resources.displayMetrics.density
    private val random = Random()

    // 皮肤与外观配置
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

    // 颜色系统
    private var primaryColor: Int = Color.parseColor("#FED7AA")
    private var secondaryColor: Int = Color.parseColor("#EA580C")
    private var eyeColor: Int = Color.parseColor("#10B981")
    private var darkPatchColor: Int = Color.parseColor("#334155")

    // 动画状态量
    private var breathY: Float = 0f
    private var scaleXVal: Float = 1f
    private var scaleYVal: Float = 1f
    private var tailAngle: Float = 0f
    private var earTwitch: Float = 0f
    private var isBlinking: Boolean = false
    private var isDragging: Boolean = false

    // 触控果冻回弹挤压形变
    private var squishScaleX: Float = 1f
    private var squishScaleY: Float = 1f
    private var squishAnimator: ValueAnimator? = null

    // 待机呼吸循环动画
    private var idleAnimator: ValueAnimator? = null

    // 爱心粒子系统
    private val hearts = mutableListOf<HeartParticle>()
    private val heartPaint = Paint(Paint.ANTI_ALIAS_FLAG)

    // 画笔缓存池
    private val bodyPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val headPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bellyPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val earPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val innerEarPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val blushPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val eyePaint = Paint(Paint.ANTI_ALIAS_FLAG)
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

    // 路径缓存
    private val earPath = Path()
    private val innerEarPath = Path()
    private val nosePath = Path()
    private val mouthPath = Path()
    private val tailPath = Path()
    private val patchPath = Path()
    private val eyePath = Path()
    private val heartPath = Path()

    // 眨眼定时调度
    private val blinkRunnable = object : Runnable {
        override fun run() {
            if (!isDragging) {
                isBlinking = true
                invalidate()
                postDelayed({
                    isBlinking = false
                    invalidate()
                }, 160)
            }
            // 每隔 2.8 ~ 4.8 秒眨一次眼
            val nextDelay = (2800 + random.nextInt(2000)).toLong()
            postDelayed(this, nextDelay)
        }
    }

    init {
        updateColors()
        startIdleAnimation()
        postDelayed(blinkRunnable, 2500)
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
                // 中华三花：柔润暖白身躯、日系软杏与暖灰斑块、碧玉明眸
                primaryColor = Color.parseColor("#FFFDF8")
                secondaryColor = Color.parseColor("#FF9E7D")
                darkPatchColor = Color.parseColor("#475569")
                eyeColor = Color.parseColor("#10B981")
            }
            "cat_golden_shaded" -> {
                // 金渐层英短：暖金杏桃渐变被毛、祖母绿宝石眸
                primaryColor = Color.parseColor("#FED7AA")
                secondaryColor = Color.parseColor("#D97706")
                darkPatchColor = Color.parseColor("#92400E")
                eyeColor = Color.parseColor("#059669")
            }
            "cat_orange" -> {
                // 中华大橘：阳光大暖炉、活力蜜橙斑纹、琥珀明眸
                primaryColor = Color.parseColor("#FED7AA")
                secondaryColor = Color.parseColor("#EA580C")
                darkPatchColor = Color.parseColor("#C2410C")
                eyeColor = Color.parseColor("#FBBF24")
            }
            "cat_british_blue" -> {
                // 经典蓝胖子：英短蓝灰缎面、琥珀金圆眼
                primaryColor = Color.parseColor("#64748B")
                secondaryColor = Color.parseColor("#475569")
                darkPatchColor = Color.parseColor("#334155")
                eyeColor = Color.parseColor("#F59E0B")
            }
            "cat_ragdoll" -> {
                // 海蓝双色布偶：仙女雪白、银蓝八字面罩、海蓝宝石眸
                primaryColor = Color.parseColor("#FFFDF8")
                secondaryColor = Color.parseColor("#8E9AAF")
                darkPatchColor = Color.parseColor("#64748B")
                eyeColor = Color.parseColor("#0284C7")
            }
            "cat_tuxedo" -> {
                // 警长奶牛猫：帅气燕尾黑、雪白衬衫领、亮金眼眸
                primaryColor = Color.parseColor("#1E293B")
                secondaryColor = Color.parseColor("#FFFFFF")
                darkPatchColor = Color.parseColor("#0F172A")
                eyeColor = Color.parseColor("#FACC15")
            }
            "cat_siamese" -> {
                // 暹罗猫：焦糖拿铁重点色、天青蓝双眸
                primaryColor = Color.parseColor("#FAF5EF")
                secondaryColor = Color.parseColor("#5C3D2E")
                darkPatchColor = Color.parseColor("#3E2723")
                eyeColor = Color.parseColor("#38BDF8")
            }
            "cat_black" -> {
                // 暗夜玄猫：玄夜黑曜石、星火澄澈明眸
                primaryColor = Color.parseColor("#0F172A")
                secondaryColor = Color.parseColor("#1E293B")
                darkPatchColor = Color.parseColor("#020617")
                eyeColor = Color.parseColor("#FACC15")
            }
            "cat_sakura_peach" -> {
                // 樱花蜜桃粉晶猫：梦幻仙境蜜桃粉、玫瑰星芒眸
                primaryColor = Color.parseColor("#FFF0F5")
                secondaryColor = Color.parseColor("#F472B6")
                darkPatchColor = Color.parseColor("#FB7185")
                eyeColor = Color.parseColor("#FB7185")
            }
            else -> {
                // 默认经典暖金波可
                primaryColor = Color.parseColor("#FED7AA")
                secondaryColor = Color.parseColor("#EA580C")
                darkPatchColor = Color.parseColor("#C2410C")
                eyeColor = Color.parseColor("#10B981")
            }
        }
    }

    private fun startIdleAnimation() {
        idleAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2400
            repeatCount = ValueAnimator.INFINITE
            interpolator = DecelerateInterpolator()
            addUpdateListener { anim ->
                val f = anim.animatedValue as Float
                val rad = (f * 2.0 * Math.PI).toFloat()

                // 生物有机起伏与呼吸骨骼微缩放
                breathY = sin(rad) * 2.4f * density
                scaleXVal = 1f - sin(rad) * 0.016f
                scaleYVal = 1f + sin(rad) * 0.022f

                // 尾巴波浪涟漪摆动
                tailAngle = sin(rad * 1.5f) * 14f

                // 周期轻微动耳
                earTwitch = if (sin(rad * 3f) > 0.85f) sin(rad * 18f) * 3f else 0f

                invalidate()
            }
        }
        idleAnimator?.start()
    }

    /**
     * 响应用户点击/抚摸：触发果冻 Q 弹物理挤压、爱心粒子迸发与开心眯眼笑
     */
    fun onPetTapped() {
        squishAnimator?.cancel()

        // 阶段一：受力瞬间横向挤压膨胀、纵向压扁
        val squishDown = ValueAnimator.ofFloat(1f, 1.20f).apply {
            duration = 90
            addUpdateListener {
                squishScaleX = it.animatedValue as Float
                squishScaleY = 2f - squishScaleX
                invalidate()
            }
        }

        // 阶段二：释放瞬间 Overshoot 弹性回弹缓冲
        val squishBounce = ValueAnimator.ofFloat(1.20f, 1f).apply {
            duration = 340
            interpolator = OvershootInterpolator(2.4f)
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
        squishDown.start()

        // 喷发 2~3 颗治愈粉嫩爱心
        spawnHearts()

        // 触碰享受眯眯笑眼
        isBlinking = true
        postDelayed({
            isBlinking = false
            invalidate()
        }, 450)
    }

    /**
     * 拖动状态感知：拎起时身体微微拉长，放下时平缓归位
     */
    fun onDragStateChanged(dragging: Boolean) {
        if (isDragging != dragging) {
            isDragging = dragging
            if (dragging) {
                squishScaleX = 0.94f
                squishScaleY = 1.08f
            } else {
                squishScaleX = 1f
                squishScaleY = 1f
            }
            invalidate()
        }
    }

    private fun spawnHearts() {
        val cx = width / 2f
        val cy = height * 0.35f
        for (i in 0..2) {
            val offsetX = (random.nextFloat() - 0.5f) * 24f * density
            val speedX = (random.nextFloat() - 0.5f) * 1.5f * density
            val speedY = -(2.5f + random.nextFloat() * 2.0f) * density
            val scale = 0.8f + random.nextFloat() * 0.5f
            hearts.add(HeartParticle(cx + offsetX, cy, speedX, speedY, scale, 1f))
        }
        invalidate()
    }

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

        // 1. 边缘依附镜像翻转 (贴在右侧时面向屏幕左侧内景)
        if (facingLeft) {
            canvas.scale(-1f, 1f, w / 2f, h / 2f)
        }

        val cx = w / 2f
        val cy = h * 0.53f

        // 2. 呼吸与骨骼形变坐标变换
        canvas.save()
        canvas.translate(cx, cy + breathY)
        canvas.scale(scaleXVal * squishScaleX, scaleYVal * squishScaleY)
        canvas.translate(-cx, -cy)

        // 3. 独立柔和地面环境阴影
        shadowPaint.color = Color.argb(28, 15, 23, 42)
        canvas.drawOval(
            cx - 24f * density,
            cy + 22f * density,
            cx + 24f * density,
            cy + 30f * density,
            shadowPaint
        )

        // 4. 灵动猫尾 (位于身体后层摇曳)
        drawTail(canvas, cx, cy)

        // 5. 浑圆身躯与腹部花纹
        drawBody(canvas, cx, cy)

        // 6. 呆萌大头与俏皮双耳
        drawHead(canvas, cx, cy)

        // 7. 肉嘟嘟前爪
        drawPaws(canvas, cx, cy)

        canvas.restore() // 恢复呼吸与形变矩阵

        // 8. 绘制漂浮上升的爱心粒子
        drawHearts(canvas)

        canvas.restore() // 恢复朝向矩阵
    }

    private fun drawTail(canvas: Canvas, cx: Float, cy: Float) {
        val tailBaseX = cx + 13f * density
        val tailBaseY = cy + 12f * density
        val angleRad = (tailAngle * Math.PI / 180.0).toFloat()
        val tailTipX = cx + 25f * density + sin(angleRad) * 11f * density
        val tailTipY = cy - 13f * density + cos(angleRad) * 4f * density

        tailPath.reset()
        tailPath.moveTo(tailBaseX, tailBaseY)
        tailPath.cubicTo(
            cx + 26f * density, cy + 16f * density,
            cx + 33f * density, cy - 2f * density,
            tailTipX, tailTipY
        )

        tailPaint.color = if (skinId == "cat_siamese") secondaryColor else primaryColor
        tailPaint.strokeWidth = 7f * density
        canvas.drawPath(tailPath, tailPaint)

        // 尾尖重点色小绒球
        val tipColor = when (skinId) {
            "cat_tuxedo" -> Color.WHITE
            "cat_calico", "cat_ragdoll", "cat_siamese" -> secondaryColor
            else -> primaryColor
        }
        val tipPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = tipColor }
        canvas.drawCircle(tailTipX, tailTipY, 4.2f * density, tipPaint)
    }

    private fun drawBody(canvas: Canvas, cx: Float, cy: Float) {
        val bodyRect = RectF(cx - 24f * density, cy - 6f * density, cx + 24f * density, cy + 25f * density)

        // 3D 渐变体积光影
        bodyPaint.shader = RadialGradient(
            cx - 6f * density, cy - 2f * density, 32f * density,
            lightenColor(primaryColor, 0.18f), primaryColor, Shader.TileMode.CLAMP
        )
        canvas.drawOval(bodyRect, bodyPaint)

        // 软糯雪白肚腩
        val bellyRect = RectF(cx - 15f * density, cy + 1f * density, cx + 15f * density, cy + 23f * density)
        bellyPaint.color = Color.parseColor("#FFFDF8")
        canvas.drawOval(bellyRect, bellyPaint)

        // 品种专属斑纹 (三花 / 橘猫)
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
        val headY = cy - 10f * density
        val headW = 27f * density
        val headH = 21f * density

        // 1. 双耳 (位于头部后侧)
        drawEars(canvas, cx, headY)

        // 2. 圆润大头轮廓 (微包子脸发腮)
        val headRect = RectF(cx - headW, headY - headH, cx + headW, headY + headH)
        headPaint.shader = RadialGradient(
            cx - 5f * density, headY - 6f * density, 34f * density,
            lightenColor(primaryColor, 0.20f), primaryColor, Shader.TileMode.CLAMP
        )
        canvas.drawOval(headRect, headPaint)

        // 额头斑纹 (三花/美短/橘猫额头活力 M 纹)
        if (skinId == "cat_calico") {
            patchPath.reset()
            patchPath.moveTo(cx + 5f * density, headY - 20f * density)
            patchPath.quadTo(cx + 22f * density, headY - 14f * density, cx + 21f * density, headY - 2f * density)
            patchPath.quadTo(cx + 11f * density, headY - 8f * density, cx + 5f * density, headY - 20f * density)
            val patchPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = secondaryColor }
            canvas.drawPath(patchPath, patchPaint)
        } else if (skinId == "cat_tuxedo") {
            // 奶牛开脸八字白面罩
            val blazePath = Path().apply {
                moveTo(cx, headY - 14f * density)
                lineTo(cx - 7f * density, headY + 5f * density)
                quadTo(cx, headY + 8f * density, cx + 7f * density, headY + 5f * density)
                close()
            }
            canvas.drawPath(blazePath, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE })
        }

        // 3. 粉嫩腮红
        blushPaint.color = if (squishScaleX > 1.05f) Color.argb(130, 251, 113, 133) else Color.argb(75, 251, 113, 133)
        canvas.drawOval(
            RectF(cx - 19f * density, headY + 2f * density, cx - 11f * density, headY + 8f * density),
            blushPaint
        )
        canvas.drawOval(
            RectF(cx + 11f * density, headY + 2f * density, cx + 19f * density, headY + 8f * density),
            blushPaint
        )

        // 4. 水灵大眼与眨眼
        drawEyes(canvas, cx, headY)

        // 5. 心形小肉鼻与治愈 ω 猫嘴
        drawNoseAndMouth(canvas, cx, headY)

        // 6. 柔和触须
        drawWhiskers(canvas, cx, headY)
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

        if (isBlinking || squishScaleX > 1.05f) {
            // 开心眯眯笑眼 ⌒ ⌒
            smileEyePaint.color = Color.parseColor("#1E293B")
            smileEyePaint.strokeWidth = 2.4f * density

            eyePath.reset()
            eyePath.moveTo(leftEyeX - 4.5f * density, eyeY)
            eyePath.quadTo(leftEyeX, eyeY - 4f * density, leftEyeX + 4.5f * density, eyeY)
            canvas.drawPath(eyePath, smileEyePaint)

            eyePath.reset()
            eyePath.moveTo(rightEyeX - 4.5f * density, eyeY)
            eyePath.quadTo(rightEyeX, eyeY - 4f * density, rightEyeX + 4.5f * density, eyeY)
            canvas.drawPath(eyePath, smileEyePaint)
        } else {
            // 晶莹璀璨大眼球
            val eyeRadiusW = 4.6f * density
            val eyeRadiusH = 5.8f * density

            for (eyeX in listOf(leftEyeX, rightEyeX)) {
                // 虹膜底色
                irisPaint.color = eyeColor
                canvas.drawOval(
                    RectF(eyeX - eyeRadiusW, eyeY - eyeRadiusH, eyeX + eyeRadiusW, eyeY + eyeRadiusH),
                    irisPaint
                )

                // 黑曜石巨瞳
                pupilPaint.color = Color.parseColor("#070B14")
                canvas.drawOval(
                    RectF(eyeX - 3.0f * density, eyeY - 4.5f * density, eyeX + 3.0f * density, eyeY + 4.5f * density),
                    pupilPaint
                )

                // 双重高光星芒
                canvas.drawCircle(eyeX - 1.4f * density, eyeY - 2.0f * density, 1.6f * density, sparklePaint)
                canvas.drawCircle(eyeX + 1.5f * density, eyeY + 1.6f * density, 0.9f * density, sparklePaint)
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

        // 治愈微笑嘴 ω
        mouthPaint.color = Color.parseColor("#334155")
        mouthPaint.strokeWidth = 1.4f * density

        mouthPath.reset()
        mouthPath.moveTo(cx, noseY + 2.4f * density)
        mouthPath.lineTo(cx, noseY + 4.0f * density)
        mouthPath.quadTo(cx - 3.2f * density, noseY + 7.0f * density, cx - 6.2f * density, noseY + 4.8f * density)
        mouthPath.moveTo(cx, noseY + 4.0f * density)
        mouthPath.quadTo(cx + 3.2f * density, noseY + 7.0f * density, cx + 6.2f * density, noseY + 4.8f * density)
        canvas.drawPath(mouthPath, mouthPaint)

        // 触碰挤压时吐露粉色舌尖 (Blep)
        if (squishScaleX > 1.05f) {
            val tonguePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#FB7185") }
            canvas.drawOval(
                RectF(cx - 2f * density, noseY + 4.2f * density, cx + 2f * density, noseY + 7.5f * density),
                tonguePaint
            )
        }
    }

    private fun drawWhiskers(canvas: Canvas, cx: Float, headY: Float) {
        val whiskerColor = if (skinId == "cat_black" || skinId == "cat_tuxedo") Color.parseColor("#F1F5F9") else Color.parseColor("#8094A3B8")
        whiskerPaint.color = whiskerColor
        whiskerPaint.strokeWidth = 1.1f * density

        val baseNoseY = headY + 3.5f * density

        // 左侧 3 根优雅微垂胡须
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

        val pawW = 5.5f * density
        val pawH = 4.2f * density
        val pawY = cy + 22f * density

        // 左爪
        val leftPaw = RectF(cx - 15f * density, pawY - pawH, cx - 4f * density, pawY + pawH)
        canvas.drawOval(leftPaw, pawPaint)
        canvas.drawOval(leftPaw, pawBorderPaint)
        canvas.drawLine(cx - 9.5f * density, pawY - 0.5f * density, cx - 9.5f * density, pawY + pawH, pawBorderPaint)

        // 右爪
        val rightPaw = RectF(cx + 4f * density, pawY - pawH, cx + 15f * density, pawY + pawH)
        canvas.drawOval(rightPaw, pawPaint)
        canvas.drawOval(rightPaw, pawBorderPaint)
        canvas.drawLine(cx + 9.5f * density, pawY - 0.5f * density, cx + 9.5f * density, pawY + pawH, pawBorderPaint)
    }

    private fun drawHearts(canvas: Canvas) {
        if (hearts.isEmpty()) return

        val it = hearts.iterator()
        while (it.hasNext()) {
            val h = it.next()
            h.x += h.vx
            h.y += h.vy
            h.alpha -= 0.032f

            if (h.alpha <= 0f) {
                it.remove()
                continue
            }

            canvas.save()
            canvas.translate(h.x, h.y)
            canvas.scale(h.scale, h.scale)

            heartPaint.color = Color.argb((h.alpha * 240).toInt(), 244, 63, 94)
            heartPaint.style = Paint.Style.FILL

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
            canvas.drawPath(heartPath, heartPaint)

            canvas.restore()
        }

        // 保持粒子刷新
        if (hearts.isNotEmpty()) {
            postInvalidateOnAnimation()
        }
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        idleAnimator?.cancel()
        squishAnimator?.cancel()
        removeCallbacks(blinkRunnable)
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

    private data class HeartParticle(
        var x: Float,
        var y: Float,
        var vx: Float,
        var vy: Float,
        var scale: Float,
        var alpha: Float
    )
}
