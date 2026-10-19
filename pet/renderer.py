import math
import random
import time
from PyQt6.QtCore import Qt, QRectF, QPointF
from PyQt6.QtGui import (
    QPainter, QColor, QBrush, QPen, QRadialGradient, QLinearGradient,
    QFont, QPainterPath, QPolygonF
)
from pet.audio import sound_manager

class Particle:
    """浮动特效粒子 (爱心、星星、泡泡、Zzz、进化金辉、小脚印、软萌尘埃)"""
    def __init__(self, x, y, particle_type="heart", text=None, vx=None, vy=None, color=None):
        self.x = x
        self.y = y
        self.particle_type = particle_type
        self.text = text
        self.color = color
        self.vx = vx if vx is not None else random.uniform(-0.8, 0.8)
        self.vy = vy if vy is not None else random.uniform(-1.8, -0.9)
        self.alpha = 255
        self.life = 1.0
        self.decay = random.uniform(0.015, 0.025)
        self.size = random.uniform(14, 22)
        self.rotation = random.uniform(-15, 15)

    def update(self):
        self.x += self.vx
        self.y += self.vy
        if self.particle_type == "dust":
            # 尘埃减速消散并轻微膨胀
            self.vx *= 0.88
            self.vy *= 0.88
            self.size += 0.35
        elif self.particle_type == "pawprint":
            # 脚印贴地静止，仅随时间渐隐
            self.vx = 0.0
            self.vy = 0.0
        self.life -= self.decay
        self.alpha = max(0, int(self.life * 255))
        return self.life > 0

class PetRenderer:
    """
    电子宠物高精度矢量图形渲染引擎
    支持幼年/成长期/成年/究极体体型变化、多部位自由装扮与多套特色皮肤
    """
    def __init__(self, model):
        self.model = model
        self.particles = []
        self.anim_time = 0.0
        self.blink_progress = 0.0
        self.is_blinking = False
        self.next_blink_time = time.time() + 3.0

        # 临时互动特效计时
        self.eating_timer = 0.0
        self.current_food_icon = "🍰"
        self.petting_timer = 0.0
        self.bath_timer = 0.0
        self.evolution_aura_timer = 0.0

        # 灵性视觉与动态物理参数
        self.landing_timer = 0.0      # 落地触地果冻阻尼震颤计时
        self.drag_vx = 0.0            # 拖拽时水平速度 (用于身体风阻倾角与拉伸)
        self.target_gaze_x = 0.0      # 视线目标 X (-1.0 ~ 1.0)
        self.target_gaze_y = 0.0      # 视线目标 Y (-1.0 ~ 1.0)
        self.current_gaze_x = 0.0     # 当前平滑插值眼神 X
        self.current_gaze_y = 0.0     # 当前平滑插值眼神 Y

        # 生物级机敏偶发抖耳动作 (每 6~14 秒灵动轻弹单侧耳尖)
        self.ear_flick_timer = 0.0
        self.next_ear_flick_time = time.time() + 4.5
        self.ear_flick_side = "left"

        # 动态瞳孔放大与灵性双眨眼
        self.target_pupil_dilation = 0.0
        self.current_pupil_dilation = 0.0
        self.cursor_dist = 999.0
        self.blink_count = 0
        self.blink_total = 1
        self.blink_style = "normal"

        # 赛博全息生物扫描仪动效 (Holo-Scan Sweep)
        self.holo_scan_timer = 0.0
        self.is_sweating = False

    def trigger_holo_scan(self):
        """触发全息生物扫描仪扫光动效 (0.45s 激光扫描线从头扫到脚)"""
        self.holo_scan_timer = 0.45

    def set_cursor_gaze(self, gaze_x, gaze_y, dist_px=999.0):
        """设置鼠标光标引起的眼神注视目标方位与空间距离"""
        self.target_gaze_x = gaze_x
        self.target_gaze_y = gaze_y
        self.cursor_dist = dist_px

    def trigger_landing_bounce(self):
        """落地触地果冻弹性震颤与地面灰尘冲击环"""
        self.landing_timer = 0.42
        if getattr(self.model, "sound_enabled", True):
            sound_manager.play("pop")
        for _ in range(5):
            vx = random.uniform(-2.8, 2.8)
            vy = random.uniform(-0.9, -0.2)
            p = Particle(110 + vx * 6, 140, "dust", vx=vx, vy=vy)
            p.size = random.uniform(9, 15)
            p.decay = 0.045
            self.particles.append(p)

    def trigger_step_poof(self, facing_left):
        """漫步落脚时留下可爱小脚印与微尘烟圈"""
        foot_x = 110 + (16 if facing_left else -16)
        foot_y = 142
        # 生成小肉垫印
        p_paw = Particle(foot_x, foot_y, "pawprint")
        p_paw.decay = 0.025
        p_paw.rotation = random.uniform(-10, 10)
        self.particles.append(p_paw)
        # 生成微量轻盈小烟圈
        p_dust = Particle(foot_x, foot_y - 2, "dust", vx=random.uniform(-0.6, 0.6), vy=random.uniform(-0.5, -0.2))
        p_dust.size = random.uniform(6, 10)
        p_dust.decay = 0.06
        self.particles.append(p_dust)

    def trigger_eat(self, food_type):
        food_emojis = {
            "milk": "🍼", "cake": "🍰", "fish": "🐟", "steak": "🥩",
            "elixir": "🌟", "boba": "🧋", "pudding": "🍮", "burger": "🍔"
        }
        self.current_food_icon = food_emojis.get(food_type, "🍖")
        self.eating_timer = 2.2
        if getattr(self.model, "sound_enabled", True):
            sound_manager.play("chew")
        for _ in range(6):
            p = Particle(110 + random.uniform(-30, 30), 100, "sparkle")
            self.particles.append(p)

    def trigger_pet(self):
        self.petting_timer = 1.5
        if getattr(self.model, "sound_enabled", True):
            now_t = time.time()
            if now_t - getattr(self, "_last_purr_time", 0.0) > 0.8:
                self._last_purr_time = now_t
                sound_manager.play("purr")
        for _ in range(2):
            p = Particle(110 + random.uniform(-20, 20), 70, "heart")
            self.particles.append(p)

    def trigger_bath(self):
        self.bath_timer = 3.0
        if getattr(self.model, "sound_enabled", True):
            sound_manager.play("pop")
        for _ in range(8):
            p = Particle(110 + random.uniform(-40, 40), 90, "bubble")
            self.particles.append(p)

    def trigger_evolution(self):
        """蜕变进化庆祝特效"""
        self.evolution_aura_timer = 4.0
        if getattr(self.model, "sound_enabled", True):
            sound_manager.play("level_up")
        for _ in range(24):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2.5, 6.0)
            vx = math.cos(angle) * speed
            vy = math.sin(angle) * speed
            p = Particle(110, 100, "sparkle", vx=vx, vy=vy)
            p.decay = random.uniform(0.008, 0.018)
            p.size = random.uniform(18, 30)
            self.particles.append(p)

    def update_animation(self, delta_time, current_state):
        self.anim_time += delta_time

        # 平滑缓动眼神跟随 (注视光标)
        if self.model.is_sleeping or current_state in ("HAPPY_SPIN", "DIZZY", "WASH_FACE", "STRETCH_YAWN"):
            target_gx, target_gy = 0.0, 0.0
        else:
            target_gx, target_gy = self.target_gaze_x, self.target_gaze_y
        lerp_factor = min(1.0, delta_time * 9.0)
        self.current_gaze_x += (target_gx - self.current_gaze_x) * lerp_factor
        self.current_gaze_y += (target_gy - self.current_gaze_y) * lerp_factor

        # 落地果冻计时更新
        if self.landing_timer > 0:
            self.landing_timer -= delta_time

        # 动态瞳孔放大评估 (光标靠近 < 85px、抚摸陶醉、纸箱藏匿、贴边偷看、抓老鼠/毛线时放大瞳孔)
        if (self.petting_timer > 0 or 
            current_state in ("CARDBOARD_BOX", "PEEK_LEFT", "PEEK_RIGHT", "CATCH_MOUSE", "PLAY_YARN", "TILT_HEAD", "CHASE_BUTTERFLY") or
            getattr(self, "cursor_dist", 999.0) < 85.0):
            self.target_pupil_dilation = 1.0
        elif getattr(self, "cursor_dist", 999.0) < 140.0:
            self.target_pupil_dilation = 0.55
        else:
            self.target_pupil_dilation = 0.0

        dil_lerp = min(1.0, delta_time * 8.0)
        self.current_pupil_dilation += (self.target_pupil_dilation - self.current_pupil_dilation) * dil_lerp

        # 灵性眨眼逻辑 (含 25% 灵动双眨眼 与 15% 信任慢眨眼 Cat Slow Blink)
        now = time.time()
        if not self.is_blinking:
            if now >= self.next_blink_time:
                self.is_blinking = True
                self.blink_progress = 0.0
                self.blink_count = 0
                roll = random.random()
                if roll < 0.25:
                    self.blink_style = "double"
                    self.blink_total = 2
                elif roll < 0.40:
                    self.blink_style = "slow"
                    self.blink_total = 1
                else:
                    self.blink_style = "normal"
                    self.blink_total = 1
        else:
            speed = 5.0 if getattr(self, "blink_style", "normal") == "slow" else 11.0
            self.blink_progress += delta_time * speed
            if self.blink_progress >= 1.0:
                self.blink_count = getattr(self, "blink_count", 0) + 1
                if self.blink_count < getattr(self, "blink_total", 1):
                    self.blink_progress = 0.0  # 灵动双眨眼：连眨第二下
                else:
                    self.is_blinking = False
                    self.blink_progress = 0.0
                    self.next_blink_time = now + random.uniform(2.6, 6.2)

        # 偶发自然抖耳逻辑 (每 6~14 秒灵动机敏地轻弹耳尖)
        if now >= self.next_ear_flick_time and current_state not in ("HAPPY_SPIN", "DRAGGING", "FALLING"):
            self.ear_flick_timer = 0.30
            self.ear_flick_side = "left" if random.random() < 0.5 else "right"
            self.next_ear_flick_time = now + random.uniform(6.5, 13.5)

        if self.ear_flick_timer > 0:
            self.ear_flick_timer -= delta_time

        if self.eating_timer > 0:
            self.eating_timer -= delta_time
        if self.petting_timer > 0:
            self.petting_timer -= delta_time
            # 抚摸时持续冒出软萌爱心与微光
            if random.random() < 0.24:
                item_type = "heart" if random.random() < 0.75 else "sparkle"
                p = Particle(100 + random.uniform(-25, 25), 65, item_type)
                p.size = random.uniform(13, 19)
                self.particles.append(p)
        if self.bath_timer > 0:
            self.bath_timer -= delta_time
        if self.evolution_aura_timer > 0:
            self.evolution_aura_timer -= delta_time
        if self.holo_scan_timer > 0:
            self.holo_scan_timer = max(0.0, self.holo_scan_timer - delta_time)

        # 动作专属动态粒子发射
        if current_state == "HEAD_BOB_MUSIC" and random.random() < 0.14:
            note = random.choice(["♪", "♫", "♬"])
            p = Particle(110 + random.uniform(-30, 30), 45, "text", text=note)
            p.size = random.uniform(16, 22)
            self.particles.append(p)

        elif current_state == "HAPPY_SPIN" and random.random() < 0.35:
            p = Particle(110 + random.uniform(-40, 40), 75, "sparkle")
            p.size = random.uniform(14, 24)
            self.particles.append(p)

        elif current_state == "TILT_HEAD" and random.random() < 0.05:
            p = Particle(135, 45, "text", text="?")
            p.size = 20
            self.particles.append(p)

        elif current_state == "STRETCH_YAWN" and random.random() < 0.06:
            p = Particle(130, 75, "bubble")
            p.size = 14
            self.particles.append(p)

        elif current_state == "LOOK_AROUND" and random.random() < 0.08:
            p = Particle(110 + random.uniform(-25, 25), 55, "sparkle", QColor("#BAE6FD"))
            p.size = 12
            self.particles.append(p)

        elif current_state == "SIT_WAG_TAIL" and random.random() < 0.08:
            p = Particle(130, 80, "heart", QColor("#FDA4AF"))
            p.size = 14
            self.particles.append(p)

        elif current_state == "CATCH_MOUSE" and random.random() < 0.12:
            p = Particle(100 + random.uniform(15, 45), 140, "dust")
            p.size = random.uniform(8, 14)
            self.particles.append(p)

        elif current_state == "PLAY_YARN" and random.random() < 0.12:
            p = Particle(100 + random.uniform(0, 35), 135, "sparkle", QColor("#FDA4AF"))
            p.size = random.uniform(10, 16)
            self.particles.append(p)

        elif current_state in ("PEEK_LEFT", "PEEK_RIGHT") and random.random() < 0.08:
            px = 15 if current_state == "PEEK_LEFT" else -15
            p = Particle(110 + px, 55, "sparkle")
            p.size = 12
            self.particles.append(p)

        # 究极体自然散发星辉粒子
        if self.model.stage == "ULTIMATE" and random.random() < 0.15:
            p = Particle(100 + random.uniform(-40, 40), 100 + random.uniform(-40, 30), "sparkle")
            p.size = random.uniform(10, 16)
            self.particles.append(p)

        # 睡眠冒泡
        if self.model.is_sleeping and random.random() < 0.04:
            p = Particle(130, 70, "text", text="Z")
            p.size = random.uniform(14, 20)
            self.particles.append(p)

        self.particles = [p for p in self.particles if p.update()]
        if len(self.particles) > 60:
            self.particles = self.particles[-60:]

    def render(self, painter: QPainter, width, height, state, facing_left=False, drag_vx=0.0):
        self.drag_vx = drag_vx
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        painter.setRenderHint(QPainter.RenderHint.TextAntialiasing, True)

        scale_factor = width / 220.0
        painter.save()
        painter.scale(scale_factor, scale_factor)

        # 0. 赛博小窝家园 DIY 场景氛围 (全景最底层)
        self._draw_habitat_effects(painter, 220.0, 220.0)

        cx = 110.0
        cy = 125.0

        # 呼吸与多样化动作形变参数
        stage = self.model.stage
        breath_speed = 4.5 if stage == "BABY" else (2.0 if self.model.is_sleeping else 3.2)
        breath_offset = math.sin(self.anim_time * breath_speed) * 3.0
        squash_x = 1.0
        squash_y = 1.0
        tilt_angle = 0.0

        # 3D 旋转动力学解算
        is_spin = (state == "HAPPY_SPIN")
        spin_angle = (self.anim_time * 7.5) % (2.0 * math.pi) if is_spin else 0.0
        cos_a = math.cos(spin_angle) if is_spin else 1.0
        sin_a = math.sin(spin_angle) if is_spin else 0.0
        is_front = (cos_a >= 0.0) if is_spin else True

        # 3D 旋转时的立体厚度因子：侧面投影保持 75% 饱满厚度，绝不塌缩为 0 厚度纸片！
        spin_body_scale_x = math.sqrt(cos_a * cos_a + (0.75 * sin_a) ** 2) if is_spin else 1.0

        spin_info = {
            "is_spin": is_spin,
            "angle": spin_angle,
            "cos_a": cos_a,
            "sin_a": sin_a,
            "is_front": is_front,
            "scale_x": spin_body_scale_x,
            "face_offset_x": 32.0 * sin_a,
            "belly_offset_x": 24.0 * sin_a
        }

        if state == "FALLING":
            squash_x = 0.88
            squash_y = 1.15
        elif state == "BOUNCE":
            squash_x = 1.25
            squash_y = 0.78
        elif state == "DRAGGING":
            # 抓起悬空拎后颈皮风阻动力学：随拖拽水平速度产生倾角摆动与上下弹性拉伸
            drag_speed = abs(self.drag_vx)
            speed_stretch = min(0.15, drag_speed * 0.0003)
            squash_x = max(0.80, 0.90 - speed_stretch * 0.6)
            squash_y = min(1.24, 1.12 + speed_stretch)
            tilt_angle += max(-24.0, min(24.0, -self.drag_vx * 0.06))
        elif state in ("WALK_LEFT", "WALK_RIGHT"):
            breath_offset = abs(math.sin(self.anim_time * 8.0)) * 6.0
            squash_x = 1.0 + math.sin(self.anim_time * 8.0) * 0.05
        elif state == "STRETCH_YAWN":
            squash_x = 1.24
            squash_y = 0.80
            breath_offset = 6.0
        elif state == "WASH_FACE":
            squash_x = 0.97
            squash_y = 1.03
        elif state == "CHASE_BUTTERFLY":
            breath_offset = abs(math.sin(self.anim_time * 12.0)) * 6.0
            squash_x = 1.0 + math.sin(self.anim_time * 14.0) * 0.08
        elif state == "HEAD_BOB_MUSIC":
            tilt_angle = math.sin(self.anim_time * 8.0) * 12.0
            breath_offset = abs(math.sin(self.anim_time * 8.0)) * 4.0
        elif state == "TILT_HEAD":
            tilt_angle = 18.0
        elif state == "HAPPY_SPIN":
            breath_offset = -30.0 * abs(math.sin(self.anim_time * 5.5))
            squash_x = spin_body_scale_x
            squash_y = 1.0 + (1.0 - spin_body_scale_x) * 0.08
            tilt_angle = sin_a * 4.0
        elif state == "DOZE_OFF":
            tilt_angle = max(0.0, math.sin(self.anim_time * 2.2) * 18.0)
            breath_offset = 4.0
        elif state == "DIZZY":
            tilt_angle = math.sin(self.anim_time * 12.0) * 6.0
            squash_x = 1.05
            squash_y = 0.95
        elif state == "LOOK_AROUND":
            tilt_angle = math.sin(self.anim_time * 3.5) * 12.0
            breath_offset = 2.0
        elif state == "SIT_WAG_TAIL":
            squash_x = 1.06
            squash_y = 0.94
            breath_offset = 3.0
        elif state == "CATCH_MOUSE":
            # 捕鼠前摇：左右兴奋扭屁股蓄力，身体向前微扑
            tilt_angle = math.sin(self.anim_time * 14.0) * 4.5
            squash_x = 1.12 + math.sin(self.anim_time * 8.0) * 0.04
            squash_y = 0.90
            breath_offset = 4.0
        elif state == "PLAY_YARN":
            # 玩毛线：身体随拨球节奏欢快左右摆动
            tilt_angle = math.sin(self.anim_time * 6.0) * 8.0
            squash_x = 1.05 + math.sin(self.anim_time * 9.0) * 0.03
            squash_y = 0.96
            breath_offset = 2.0
        elif state == "CARDBOARD_BOX":
            # 纸箱藏猫猫：在箱子里惬意沉坐，好奇微探头
            squash_x = 0.96
            squash_y = 1.02
            breath_offset = 6.0 + math.sin(self.anim_time * 2.8) * 3.5
            tilt_angle = math.sin(self.anim_time * 2.0) * 3.0
        elif state in ("PEEK_LEFT", "PEEK_RIGHT"):
            # 贴边探头偷看：侧身向屏幕内部倾斜，好奇探出小脑袋
            squash_x = 1.02
            squash_y = 0.98
            tilt_angle = 14.0 if state == "PEEK_LEFT" else -14.0
            breath_offset = math.sin(self.anim_time * 3.5) * 2.5
        elif self.model.is_sleeping:
            breath_offset = math.sin(self.anim_time * 1.8) * 2.0
        elif state == "IDLE":
            # 眼神视线微倾头 (目光看哪边，脑袋轻轻微偏向哪边)
            tilt_angle += self.current_gaze_x * 4.5

        # 抚摸陶醉呼噜共振 (Purring Resonance, 高频微幅治愈颤动)
        if self.petting_timer > 0:
            purr_vibe = math.sin(self.anim_time * 28.0) * 0.024
            squash_x *= (1.0 + purr_vibe)
            squash_y *= (1.0 - purr_vibe)
            breath_offset += math.sin(self.anim_time * 24.0) * 1.2

        # 落地果冻 Q 弹动力学形变 (阻尼正弦衰减震颤)
        if self.landing_timer > 0:
            elapsed = 0.42 - self.landing_timer
            progress = min(1.0, elapsed / 0.42)
            decay = max(0.0, 1.0 - progress)
            jelly_wave = math.sin(progress * math.pi * 3.5) * 0.28 * decay
            squash_x *= (1.0 + jelly_wave)
            squash_y *= (1.0 - jelly_wave)
            breath_offset += jelly_wave * 14.0

        if stage == "BABY":
            squash_x *= 0.95
            squash_y *= 0.95

        painter.save()
        painter.translate(cx, cy)

        if facing_left:
            painter.scale(-1.0, 1.0)

        # 1. 究极体神圣光环底环 (在身体后方绘制)
        if stage == "ULTIMATE" or self.evolution_aura_timer > 0:
            self._draw_ultimate_aura(painter)

        # 2. 背景背部装饰 (正面时位于身体后方)
        self._draw_back_decorations(painter, spin_info, is_foreground=False)

        # 3. 底部双层立体地面投影 (Ground Dual-Layer 3D Shadow, 悬空时淡化扩散，旋转时不收缩为线)
        is_airborne = state in ("DRAGGING", "FALLING")
        if is_airborne:
            # 悬空状态：离地景深衰减，地面阴影扩散淡化
            shadow_w = 112.0 * abs(squash_x)
            ambient_alpha = 14
            contact_alpha = 0  # 彻底脱离地面，无紧贴接触阴影！
        elif is_spin:
            jump_ratio = min(1.0, abs(breath_offset) / 32.0)
            shadow_w = 92.0 * (1.0 - jump_ratio * 0.15)
            ambient_alpha = int(48 * (1.0 - jump_ratio * 0.35))
            contact_alpha = int(80 * (1.0 - jump_ratio * 0.7))
        else:
            shadow_w = 96 * abs(squash_x)
            ambient_alpha = 48
            contact_alpha = 80

        if stage == "BABY":
            shadow_w *= 0.85
        elif stage == "ULTIMATE":
            shadow_w *= 1.15

        # 漫反射羽化大阴影 (羽化环境落影)
        shadow_rect = QRectF(-shadow_w / 2.0, 44 - breath_offset * 0.3, shadow_w, 20)
        shadow_grad = QRadialGradient(shadow_rect.center(), shadow_w / 2.0)
        shadow_grad.setColorAt(0.0, QColor(0, 0, 0, ambient_alpha))
        shadow_grad.setColorAt(0.55, QColor(0, 0, 0, int(ambient_alpha * 0.42)))
        shadow_grad.setColorAt(1.0, QColor(0, 0, 0, 0))
        painter.setBrush(QBrush(shadow_grad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(shadow_rect)

        # 紧贴足底重力接触阴影 (Contact Shadow, 仅在触地时生效)
        if contact_alpha > 0:
            contact_w = shadow_w * 0.72
            contact_rect = QRectF(-contact_w / 2.0, 47 - breath_offset * 0.2, contact_w, 9)
            contact_grad = QRadialGradient(contact_rect.center(), contact_w / 2.0)
            contact_grad.setColorAt(0.0, QColor(0, 0, 0, contact_alpha))
            contact_grad.setColorAt(0.65, QColor(0, 0, 0, int(contact_alpha * 0.3)))
            contact_grad.setColorAt(1.0, QColor(0, 0, 0, 0))
            painter.setBrush(QBrush(contact_grad))
            painter.drawEllipse(contact_rect)

        # 3.5 3D 星尘环绕粒子 (背景层，位于身体后方)
        if is_spin:
            self._draw_spin_stardust_ring(painter, spin_angle, in_front=False)

        painter.translate(0, breath_offset)
        if tilt_angle != 0.0:
            painter.rotate(tilt_angle)
        painter.scale(squash_x, squash_y)

        # 4. 根据皮肤绘制本体 (支持 3D 旋转投影与立体背影)
        skin_id = self.model.skin_id
        if skin_id.startswith("dog"):
            self._draw_dog(painter, state, skin_id, spin_info)
        elif skin_id.startswith("slime"):
            self._draw_slime(painter, state, skin_id, spin_info)
        elif skin_id.startswith("penguin"):
            self._draw_penguin(painter, state, spin_info)
        else:
            self._draw_cat(painter, state, skin_id, spin_info)

        # 5. 前景背部装饰 (背面时翅膀展现在身体前方)
        self._draw_back_decorations(painter, spin_info, is_foreground=True)

        # 6. 脖饰 (领结、围巾、铃铛)
        self._draw_neck_decorations(painter, spin_info)

        # 7. 面饰 (眼镜、墨镜、心动贴纸，仅正面显示)
        self._draw_face_decorations(painter, spin_info)

        # 8. 头饰 (魔法帽、派对帽、光环、王冠)
        self._draw_head_decorations(painter, spin_info)

        # 8.2 手持道具 (RGB机械键盘、全息逗猫棒、极客咖啡、复古掌机、能量哑铃)
        self._draw_hand_decorations(painter, spin_info)

        # 8.5 3D 星尘环绕粒子 (前景层，位于身体前方，形成真实空间景深穿插)
        if is_spin:
            self._draw_spin_stardust_ring(painter, spin_angle, in_front=True)

        # 9. 动作专属覆盖物 (听歌耳机、追逐蝴蝶、眩晕星星)
        if state == "HEAD_BOB_MUSIC":
            self._draw_headphones(painter)
        elif state == "CHASE_BUTTERFLY":
            self._draw_butterfly(painter)
        elif state == "DIZZY":
            self._draw_dizzy_stars(painter)
        elif state == "CATCH_MOUSE":
            self._draw_scurrying_mouse(painter)
        elif state == "PLAY_YARN":
            self._draw_bouncing_yarn(painter)
        elif state == "CARDBOARD_BOX":
            self._draw_cardboard_box(painter)

        # 10. 正在进行的进食/洗澡覆盖物
        if self.eating_timer > 0:
            self._draw_eating_food(painter)
        if self.bath_timer > 0:
            self._draw_bath_bubbles(painter)

        painter.restore()

        # 10. 独立粒子特效绘制
        self._draw_particles(painter, cx, cy)

        # 11. 全息生物扫描仪扫光特效 (Holo-Scan Sweep)
        if self.holo_scan_timer > 0:
            self._draw_holo_scan(painter)

        # 12. 高负载流汗软萌水滴
        if getattr(self, "is_sweating", False):
            self._draw_sweat_drop(painter, cx, cy)

        painter.restore()

    def _draw_habitat_effects(self, painter: QPainter, width, height):
        """赛博小窝家园 DIY 背景环境特效图层 (最底层)"""
        habitat = getattr(self.model, "habitat", "none")
        if not habitat or habitat == "none":
            return

        painter.save()
        if habitat == "neon_matrix":
            # 暗夜霓虹极客房：天青与翠绿流光二进制代码雨 + 深空全息透视网格
            grid_pen = QPen(QColor(14, 165, 233, 40), 1.2)
            painter.setPen(grid_pen)
            for gx in range(10, int(width), 25):
                painter.drawLine(int(gx), int(height * 0.95), int(width * 0.5 + (gx - width * 0.5) * 0.25), int(height * 0.65))
            for gy in [0.65, 0.72, 0.81, 0.92]:
                painter.drawLine(15, int(height * gy), int(width - 15), int(height * gy))

            # 5 列自上而下缓缓滑落的二进制代码雨 (0101)
            painter.setFont(QFont("Consolas", 8, QFont.Weight.Bold))
            cols = [22, 60, 105, 160, 198]
            t = self.anim_time * 28.0
            chars = ["0", "1", "1", "0", "1", "0", "1", "0"]
            for ci, cx in enumerate(cols):
                base_y = int((t + ci * 43) % (height * 0.85))
                for ri in range(4):
                    cy = (base_y - ri * 14) % int(height * 0.85)
                    alpha = max(10, 140 - ri * 35)
                    painter.setPen(QColor(56, 189, 248, alpha) if ri > 0 else QColor(52, 211, 153, 200))
                    ch = chars[(ci * 3 + ri + int(self.anim_time * 2)) % len(chars)]
                    painter.drawText(cx, int(cy + 20), ch)

        elif habitat == "retro_arcade":
            # 复古像素游戏机房：Synthwave 霓虹洋红栅格 + 8-bit 浮空星辰
            grid_pen = QPen(QColor(217, 70, 239, 45), 1.2)
            painter.setPen(grid_pen)
            for gx in range(10, int(width), 25):
                painter.drawLine(int(gx), int(height * 0.96), int(width * 0.5 + (gx - width * 0.5) * 0.3), int(height * 0.66))
            for gy in [0.66, 0.74, 0.83, 0.93]:
                painter.drawLine(15, int(height * gy), int(width - 15), int(height * gy))

            stars = [(30, 42), (75, 28), (150, 36), (190, 58), (48, 90), (175, 95)]
            for si, (sx, sy) in enumerate(stars):
                pulse = (math.sin(self.anim_time * 4.5 + si * 1.7) + 1.0) * 0.5
                star_alpha = int(40 + pulse * 140)
                painter.setBrush(QBrush(QColor(244, 114, 182, star_alpha)))
                painter.setPen(Qt.PenStyle.NoPen)
                painter.drawRect(QRectF(sx - 1, sy - 4, 3, 9))
                painter.drawRect(QRectF(sx - 4, sy - 1, 9, 3))

        elif habitat == "summer_beach":
            # 夏日阳光海滩：温暖落日余晖斜光束 + 漂浮金光微尘
            sun_grad = QRadialGradient(width * 0.82, height * 0.18, 90)
            sun_grad.setColorAt(0.0, QColor(253, 224, 71, 55))
            sun_grad.setColorAt(0.6, QColor(251, 146, 60, 25))
            sun_grad.setColorAt(1.0, QColor(251, 146, 60, 0))
            painter.setBrush(QBrush(sun_grad))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(QRectF(width * 0.45, 0, width * 0.75, height * 0.6))

            beam = QPolygonF([
                QPointF(width * 0.75, 0),
                QPointF(width * 0.95, 0),
                QPointF(width * 0.45, height),
                QPointF(width * 0.15, height)
            ])
            painter.setBrush(QBrush(QColor(255, 255, 255, 18)))
            painter.drawPolygon(beam)

            for di in range(6):
                dx = (di * 37 + math.sin(self.anim_time * 1.8 + di) * 14) % width
                dy = (di * 41 + math.cos(self.anim_time * 2.2 + di) * 12 + height * 0.2) % (height * 0.75)
                mote_alpha = int(70 + math.sin(self.anim_time * 3.0 + di) * 45)
                painter.setBrush(QBrush(QColor(254, 240, 138, mote_alpha)))
                painter.drawEllipse(QRectF(dx, dy, 3.5, 3.5))

        elif habitat == "zen_tatami":
            # 佛系禅意蒲团室：静谧抹茶清竹微光 + 优雅徐徐飘落的樱花花瓣
            tatami_grad = QLinearGradient(0, height * 0.82, 0, height)
            tatami_grad.setColorAt(0.0, QColor(101, 163, 13, 0))
            tatami_grad.setColorAt(1.0, QColor(101, 163, 13, 26))
            painter.setBrush(QBrush(tatami_grad))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawRect(QRectF(0, height * 0.82, width, height * 0.18))

            for pi in range(7):
                px = (pi * 32 + math.sin(self.anim_time * 1.6 + pi * 1.9) * 26) % width
                py = (self.anim_time * 18.0 + pi * 36) % height
                prot = (self.anim_time * 25.0 + pi * 50) % 360
                p_alpha = int(120 + math.sin(self.anim_time * 2.0 + pi) * 40)

                painter.save()
                painter.translate(px, py)
                painter.rotate(prot)
                petal = QPainterPath()
                petal.moveTo(0, -5)
                petal.cubicTo(4, -3, 5, 4, 0, 6)
                petal.cubicTo(-5, 4, -4, -3, 0, -5)
                painter.setBrush(QBrush(QColor(244, 114, 182, p_alpha)))
                painter.drawPath(petal)
                painter.restore()

        painter.restore()

    def _draw_holo_scan(self, painter: QPainter):
        """绘制半透明天青流光全息生物扫描线与战术准星"""
        progress = max(0.0, min(1.0, 1.0 - (self.holo_scan_timer / 0.45)))
        # 扫描范围从头部 y=25 到脚底 y=185
        beam_y = 25.0 + progress * 160.0
        alpha = int(220 * math.sin(progress * math.pi))

        painter.save()
        # 激光扫光横梁 (带有高斯光晕质感渐变)
        grad = QLinearGradient(0, beam_y - 7, 0, beam_y + 7)
        grad.setColorAt(0.0, QColor(56, 189, 248, 0))
        grad.setColorAt(0.35, QColor(56, 189, 248, int(alpha * 0.55)))
        grad.setColorAt(0.5, QColor(240, 249, 255, alpha))
        grad.setColorAt(0.65, QColor(56, 189, 248, int(alpha * 0.55)))
        grad.setColorAt(1.0, QColor(56, 189, 248, 0))

        painter.setBrush(QBrush(grad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawRect(QRectF(25.0, beam_y - 7, 170.0, 14.0))

        # 左右两端科技刻度与小微标
        painter.setPen(QPen(QColor(56, 189, 248, alpha), 1.5))
        painter.drawLine(int(26), int(beam_y - 5), int(26), int(beam_y + 5))
        painter.drawLine(int(194), int(beam_y - 5), int(194), int(beam_y + 5))

        painter.setFont(QFont("Consolas", 7, QFont.Weight.Bold))
        painter.setPen(QColor(56, 189, 248, alpha))
        painter.drawText(QRectF(32.0, beam_y - 14, 110.0, 12.0), Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignVCenter, "BIO-SCAN // 99.8%")
        painter.restore()

    def _draw_sweat_drop(self, painter: QPainter, cx, cy):
        """绘制高负载流汗软萌水滴"""
        painter.save()
        sw_offset = (self.anim_time * 24.0) % 16.0
        sw_x = cx + 34.0
        sw_y = cy - 36.0 + sw_offset
        sw_alpha = int(max(0, min(230, (1.0 - sw_offset / 16.0) * 255)))

        path = QPainterPath()
        path.moveTo(sw_x, sw_y - 6)
        path.cubicTo(sw_x + 3.5, sw_y - 1, sw_x + 3.5, sw_y + 4, sw_x, sw_y + 5)
        path.cubicTo(sw_x - 3.5, sw_y + 4, sw_x - 3.5, sw_y - 1, sw_x, sw_y - 6)

        painter.setBrush(QBrush(QColor(56, 189, 248, sw_alpha)))
        painter.setPen(QPen(QColor(224, 242, 254, sw_alpha), 1.0))
        painter.drawPath(path)
        painter.restore()

    # ================= 究极体光环与背部装饰 =================
    def _draw_ultimate_aura(self, painter: QPainter):
        aura_rad = 75 + math.sin(self.anim_time * 3.0) * 8.0
        aura_grad = QRadialGradient(0, 0, aura_rad)
        aura_grad.setColorAt(0.0, QColor(255, 235, 120, 110))
        aura_grad.setColorAt(0.6, QColor(255, 180, 50, 45))
        aura_grad.setColorAt(1.0, QColor(255, 150, 0, 0))
        painter.setBrush(QBrush(aura_grad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-aura_rad, -aura_rad - 10, aura_rad * 2, aura_rad * 2))

    def _draw_spin_stardust_ring(self, painter: QPainter, spin_angle, in_front: bool):
        """3D 环绕星尘粒子系统：正面穿插角色前方，背面穿插角色后方，提供真实立体景深"""
        num_stars = 7
        radius_x = 66.0
        radius_y = 16.0
        center_y = 6.0

        for i in range(num_stars):
            angle = spin_angle * 1.35 + (i * 2.0 * math.pi / num_stars)
            cos_p = math.cos(angle)
            sin_p = math.sin(angle)

            # sin_p > 0 为前景 (in front)，sin_p <= 0 为背景 (behind)
            is_fg = (sin_p > 0)
            if is_fg != in_front:
                continue

            px = radius_x * cos_p
            py = center_y + radius_y * sin_p

            depth_norm = (sin_p + 1.0) / 2.0
            star_scale = 0.65 + 0.45 * depth_norm
            alpha = int(100 + 155 * depth_norm)

            painter.save()
            painter.translate(px, py)
            painter.scale(star_scale, star_scale)
            painter.rotate((self.anim_time * 160.0 + i * 50) % 360)

            star_path = QPainterPath()
            s = 9.0
            star_path.moveTo(0, -s)
            star_path.cubicTo(1.5, -2, 2, -1.5, s, 0)
            star_path.cubicTo(2, 1.5, 1.5, 2, 0, s)
            star_path.cubicTo(-1.5, 2, -2, 1.5, -s, 0)
            star_path.cubicTo(-2, -1.5, -1.5, -2, 0, -s)

            grad = QRadialGradient(0, 0, s)
            grad.setColorAt(0.0, QColor(255, 255, 255, alpha))
            grad.setColorAt(0.45, QColor(254, 240, 138, alpha))
            grad.setColorAt(1.0, QColor(245, 158, 11, 0))
            painter.setBrush(QBrush(grad))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawPath(star_path)

            painter.setBrush(QBrush(QColor(255, 255, 255, min(255, alpha + 40))))
            painter.drawEllipse(QRectF(-2, -2, 4, 4))
            painter.restore()

    def _draw_back_decorations(self, painter: QPainter, spin_info=None, is_foreground=False):
        # 旋转时根据正反面决定背部饰品位于身体后侧还是前侧
        if spin_info and spin_info.get("is_spin", False):
            is_back_view = not spin_info.get("is_front", True)
            if is_back_view != is_foreground:
                return
        elif is_foreground:
            return  # 普通状态下只在后景层绘制一次

        back_item = self.model.decorations.get("back", "none")
        if back_item == "wings":
            # 天使羽翼拍动
            wing_angle = math.sin(self.anim_time * 6.0) * 12.0
            painter.save()
            painter.setBrush(QBrush(QColor(255, 255, 255, 240)))
            painter.setPen(QPen(QColor(220, 230, 245), 1.5))
            # 左翼
            painter.save()
            painter.translate(-35, -5)
            painter.rotate(-wing_angle)
            left_w = QPainterPath()
            left_w.moveTo(0, 0)
            left_w.cubicTo(-25, -20, -50, -10, -45, 10)
            left_w.cubicTo(-35, 25, -15, 15, 0, 0)
            painter.drawPath(left_w)
            painter.restore()
            # 右翼
            painter.save()
            painter.translate(35, -5)
            painter.rotate(wing_angle)
            right_w = QPainterPath()
            right_w.moveTo(0, 0)
            right_w.cubicTo(25, -20, 50, -10, 45, 10)
            right_w.cubicTo(35, 25, 15, 15, 0, 0)
            painter.drawPath(right_w)
            painter.restore()
            painter.restore()

        elif back_item == "balloon":
            # 浮动爱心气球
            painter.save()
            balloon_y = -95 + math.sin(self.anim_time * 2.5) * 6.0
            # 绳线
            painter.setPen(QPen(QColor(180, 180, 180), 1.5))
            painter.drawLine(25, 20, 40, int(balloon_y + 20))
            # 气球本体
            painter.translate(40, balloon_y)
            heart = QPainterPath()
            s = 14
            heart.moveTo(0, s * 0.3)
            heart.cubicTo(-s, -s * 0.5, -s * 1.5, s * 0.3, 0, s * 1.4)
            heart.cubicTo(s * 1.5, s * 0.3, s, -s * 0.5, 0, s * 0.3)
            painter.setBrush(QBrush(QColor("#FF4D6D")))
            painter.setPen(QPen(QColor("#C9184A"), 1.5))
            painter.drawPath(heart)
            painter.restore()

        elif back_item == "cushion_zen" or (back_item == "none" and getattr(self.model, "personality", "") == "LAZY"):
            # 佛系大懒喵专属：禅意榻榻米软垫/蒲团 (置于身下地面)
            painter.save()
            cushion_rect = QRectF(-48, 36, 96, 26)
            cushion_grad = QRadialGradient(0, 48, 48)
            cushion_grad.setColorAt(0.0, QColor("#FDE68A"))
            cushion_grad.setColorAt(0.7, QColor("#F59E0B"))
            cushion_grad.setColorAt(1.0, QColor("#B45309"))
            painter.setBrush(QBrush(cushion_grad))
            painter.setPen(QPen(QColor("#78350F"), 2.2))
            painter.drawEllipse(cushion_rect)

            # 软垫内圈编织缝线
            painter.setPen(QPen(QColor("#D97706"), 1.5, Qt.PenStyle.DashLine))
            painter.drawEllipse(QRectF(-40, 40, 80, 18))

            # 蒲团边角飘落的两片娇嫩粉樱花瓣
            for sx, sy, rot in [(-34, 46, -20), (32, 48, 25)]:
                painter.save()
                painter.translate(sx, sy)
                painter.rotate(rot)
                petal = QPainterPath()
                petal.moveTo(0, -4)
                petal.cubicTo(4, -2, 4, 3, 0, 5)
                petal.cubicTo(-4, 3, -4, -2, 0, -4)
                painter.setBrush(QBrush(QColor("#FBCFE8")))
                painter.setPen(Qt.PenStyle.NoPen)
                painter.drawPath(petal)
                painter.restore()
            painter.restore()

    # ================= 猫咪皮肤绘制 (3D 立体手办质感) =================
    def _draw_cat(self, painter: QPainter, state, skin_id, spin_info=None):
        # 3D 渲染多级光源配色表
        colors = {
            "cat_calico": {
                "body_hl": "#FFFFFF", "body_light": "#FFFDF9", "body_mid": "#FFEAD8", "body_dark": "#F5D5BE", "body_shadow": "#E2B998",
                "outline": "#7D6456", "ear_l_t": "#FFFBF7", "ear_l_b": "#E2C4B0", "ear_r_t": "#FFD1A4", "ear_r_b": "#E0853D",
                "spot_t": QColor(255, 190, 120, 210), "spot_b": QColor(235, 140, 60, 200),
                "tail_l": "#A1887F", "tail_d": "#6D4C41", "paw_t": "#FFFFFF", "paw_b": "#F0DFD1",
                "inner_ear_t": "#FFA4A4", "inner_ear_b": "#D85A70"
            },
            "cat_orange": {
                "body_hl": "#FFECC8", "body_light": "#FFD6A4", "body_mid": "#FFA854", "body_dark": "#F08928", "body_shadow": "#D66B12",
                "outline": "#8C4614", "ear_l_t": "#FFC082", "ear_l_b": "#D66B12", "ear_r_t": "#FFC082", "ear_r_b": "#D66B12",
                "spot_t": QColor(240, 115, 20, 150), "spot_b": QColor(190, 75, 0, 170),
                "tail_l": "#FF9933", "tail_d": "#B84700", "paw_t": "#FFF5E6", "paw_b": "#F5CA9E",
                "inner_ear_t": "#FFB8B8", "inner_ear_b": "#E06868"
            },
            "cat_black": {
                "body_hl": "#666670", "body_light": "#46464C", "body_mid": "#2E2E32", "body_dark": "#1C1C20", "body_shadow": "#0F0F12",
                "outline": "#0A0A0C", "ear_l_t": "#56565C", "ear_l_b": "#1C1C20", "ear_r_t": "#56565C", "ear_r_b": "#1C1C20",
                "spot_t": None, "spot_b": None,
                "tail_l": "#38383E", "tail_d": "#121214", "paw_t": "#4C4C54", "paw_b": "#222226",
                "inner_ear_t": "#6E505E", "inner_ear_b": "#3E2B34"
            },
            "cat_white": {
                "body_hl": "#FFFFFF", "body_light": "#FFFFFF", "body_mid": "#F2F6FA", "body_dark": "#DEE8F2", "body_shadow": "#C4D5E6",
                "outline": "#7B92AB", "ear_l_t": "#FFFFFF", "ear_l_b": "#D2E0EE", "ear_r_t": "#FFFFFF", "ear_r_b": "#D2E0EE",
                "spot_t": None, "spot_b": None,
                "tail_l": "#F0F4F8", "tail_d": "#CBD7E4", "paw_t": "#FFFFFF", "paw_b": "#D8E4F0",
                "inner_ear_t": "#FFB8C6", "inner_ear_b": "#E8768C"
            }
        }
        palette = colors.get(skin_id, colors["cat_calico"])

        # 3D 旋转背面绘制 (Back View，彻底告别纸片镜像)
        if spin_info and spin_info.get("is_spin", False) and not spin_info.get("is_front", True):
            self._draw_cat_back(painter, palette, spin_info)
            return

        is_spin_front = bool(spin_info and spin_info.get("is_spin", False) and spin_info.get("is_front", True))
        sin_a = spin_info.get("sin_a", 0.0) if spin_info else 0.0
        cos_a = spin_info.get("cos_a", 1.0) if spin_info else 1.0
        face_offset_x = spin_info.get("face_offset_x", 0.0) if spin_info else 0.0
        belly_offset_x = spin_info.get("belly_offset_x", 0.0) if spin_info else 0.0

        # 1. 立体圆润尾巴
        if state != "CARDBOARD_BOX":
            if state == "SIT_WAG_TAIL":
                tail_angle = math.sin(self.anim_time * 9.0) * 28.0
            else:
                tail_angle = math.sin(self.anim_time * 4.0) * 18.0
            tail_x = 35 - sin_a * 15.0 if is_spin_front else 35
            painter.save()
            painter.translate(tail_x, 25)
            painter.rotate(tail_angle)
            tail_path = QPainterPath()
            tail_path.moveTo(0, 0)
            tail_path.cubicTo(24, 10, 32, -26, 20, -36)
            tail_path.cubicTo(12, -40, 4, -20, 0, -10)
            tail_grad = QLinearGradient(0, 0, 25, -30)
            tail_grad.setColorAt(0.0, QColor(palette["tail_l"]))
            tail_grad.setColorAt(1.0, QColor(palette["tail_d"]))
            painter.setBrush(QBrush(tail_grad))
            painter.setPen(QPen(QColor(palette["outline"]), 3.2))
            painter.drawPath(tail_path)
            painter.restore()

        # 2. 立体双耳 (外耳圆润柔和轮廓 + 内耳凹陷立体阴影 + 耳内萌绒毛，带 3D 轨道视差 + 偶发机敏抖耳)
        ear_twitch = math.sin(self.anim_time * 6.0) * 2.5 if state == "IDLE" else 0.0
        ear_shift = sin_a * 14.0 if is_spin_front else 0.0

        # 生物级单侧机敏轻弹抖耳 (flick)
        flick_val = 0.0
        if self.ear_flick_timer > 0:
            p = 1.0 - (self.ear_flick_timer / 0.30)
            flick_val = math.sin(p * math.pi * 3.5) * 8.0 * (1.0 - p)
        flick_l = flick_val if self.ear_flick_side == "left" else 0.0
        flick_r = flick_val if self.ear_flick_side == "right" else 0.0
        ear_twitch_l = ear_twitch + flick_l
        ear_twitch_r = -ear_twitch - flick_r

        # 左耳 (温润三角圆弧猫耳，彻底告别尖锐感)
        left_ear = QPainterPath()
        left_ear.moveTo(-43 + ear_shift, -26)
        left_ear.cubicTo(-48 + ear_shift, -38, -51 + ear_shift, -50, -46 + ear_shift, -58 + ear_twitch_l)
        left_ear.cubicTo(-43 + ear_shift, -63 + ear_twitch_l, -35 + ear_shift, -63 + ear_twitch_l, -32 + ear_shift, -57 + ear_twitch_l)
        left_ear.cubicTo(-26 + ear_shift, -49, -20 + ear_shift, -42, -14 + ear_shift, -38)
        left_ear.cubicTo(-22 + ear_shift, -32, -32 + ear_shift, -28, -43 + ear_shift, -26)
        left_ear.closeSubpath()
        ear_grad_l = QLinearGradient(-46 + ear_shift, -63, -14 + ear_shift, -26)
        ear_grad_l.setColorAt(0.0, QColor(palette["ear_l_t"]))
        ear_grad_l.setColorAt(1.0, QColor(palette["ear_l_b"]))
        painter.setBrush(QBrush(ear_grad_l))
        painter.setPen(QPen(QColor(palette["outline"]), 3.2))
        painter.drawPath(left_ear)

        # 左内耳凹陷立体柔和粉瓣
        left_inner = QPainterPath()
        left_inner.moveTo(-39 + ear_shift, -30)
        left_inner.cubicTo(-43 + ear_shift, -39, -44 + ear_shift, -48, -41 + ear_shift, -54 + ear_twitch_l)
        left_inner.cubicTo(-38 + ear_shift, -58 + ear_twitch_l, -33 + ear_shift, -58 + ear_twitch_l, -30 + ear_shift, -53 + ear_twitch_l)
        left_inner.cubicTo(-25 + ear_shift, -46, -20 + ear_shift, -40, -17 + ear_shift, -37)
        left_inner.cubicTo(-22 + ear_shift, -32, -30 + ear_shift, -30, -39 + ear_shift, -30)
        left_inner.closeSubpath()
        inner_grad_l = QLinearGradient(-41 + ear_shift, -58, -20 + ear_shift, -30)
        inner_grad_l.setColorAt(0.0, QColor(palette["inner_ear_t"]))
        inner_grad_l.setColorAt(1.0, QColor(palette["inner_ear_b"]))
        painter.setBrush(QBrush(inner_grad_l))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawPath(left_inner)

        # 左耳内软绒毛
        fluff_l = QPainterPath()
        fluff_l.moveTo(-32 + ear_shift, -33)
        fluff_l.cubicTo(-28 + ear_shift, -40, -25 + ear_shift, -41, -22 + ear_shift, -37)
        fluff_l.cubicTo(-21 + ear_shift, -34, -26 + ear_shift, -32, -30 + ear_shift, -32)
        fluff_l.closeSubpath()
        painter.setBrush(QBrush(QColor(255, 255, 255, 185)))
        painter.drawPath(fluff_l)

        # 右耳 (温润三角圆弧猫耳)
        right_ear = QPainterPath()
        right_ear.moveTo(43 + ear_shift, -26)
        right_ear.cubicTo(48 + ear_shift, -38, 51 + ear_shift, -50, 46 + ear_shift, -58 + ear_twitch_r)
        right_ear.cubicTo(43 + ear_shift, -63 + ear_twitch_r, 35 + ear_shift, -63 + ear_twitch_r, 32 + ear_shift, -57 + ear_twitch_r)
        right_ear.cubicTo(26 + ear_shift, -49, 20 + ear_shift, -42, 14 + ear_shift, -38)
        right_ear.cubicTo(22 + ear_shift, -32, 32 + ear_shift, -28, 43 + ear_shift, -26)
        right_ear.closeSubpath()
        ear_grad_r = QLinearGradient(46 + ear_shift, -63, 14 + ear_shift, -26)
        ear_grad_r.setColorAt(0.0, QColor(palette["ear_r_t"]))
        ear_grad_r.setColorAt(1.0, QColor(palette["ear_r_b"]))
        painter.setBrush(QBrush(ear_grad_r))
        painter.setPen(QPen(QColor(palette["outline"]), 3.2))
        painter.drawPath(right_ear)

        # 右内耳凹陷立体柔和粉瓣
        right_inner = QPainterPath()
        right_inner.moveTo(39 + ear_shift, -30)
        right_inner.cubicTo(43 + ear_shift, -39, 44 + ear_shift, -48, 41 + ear_shift, -54 + ear_twitch_r)
        right_inner.cubicTo(38 + ear_shift, -58 + ear_twitch_r, 33 + ear_shift, -58 + ear_twitch_r, 30 + ear_shift, -53 + ear_twitch_r)
        right_inner.cubicTo(25 + ear_shift, -46, 20 + ear_shift, -40, 17 + ear_shift, -37)
        right_inner.cubicTo(22 + ear_shift, -32, 30 + ear_shift, -30, 39 + ear_shift, -30)
        right_inner.closeSubpath()
        painter.setBrush(QBrush(inner_grad_l))
        painter.drawPath(right_inner)

        # 右耳内软绒毛
        fluff_r = QPainterPath()
        fluff_r.moveTo(32 + ear_shift, -33)
        fluff_r.cubicTo(28 + ear_shift, -40, 25 + ear_shift, -41, 22 + ear_shift, -37)
        fluff_r.cubicTo(21 + ear_shift, -34, 26 + ear_shift, -32, 30 + ear_shift, -32)
        fluff_r.closeSubpath()
        painter.setBrush(QBrush(QColor(255, 255, 255, 185)))
        painter.drawPath(fluff_r)

        # 3. 3D 球形漫反射身体 (Spherical Lighting Volume)
        body_rect = QRectF(-52, -48, 104, 100)
        body_rad = QRadialGradient(-18, -20, 75, -18, -20)
        body_rad.setColorAt(0.0, QColor(palette["body_hl"]))
        body_rad.setColorAt(0.35, QColor(palette["body_light"]))
        body_rad.setColorAt(0.72, QColor(palette["body_mid"]))
        body_rad.setColorAt(0.92, QColor(palette["body_dark"]))
        body_rad.setColorAt(1.0, QColor(palette["body_shadow"]))
        painter.setBrush(QBrush(body_rad))
        painter.setPen(QPen(QColor(palette["outline"]), 3.5))
        painter.drawEllipse(body_rect)

        # 4. 特色三花/斑纹 (贴合球体曲面的弧线渐变)
        if palette["spot_t"]:
            spot_path = QPainterPath()
            spot_shift = sin_a * 15.0 if is_spin_front else 0.0
            spot_path.moveTo(15 + spot_shift, -45)
            spot_path.cubicTo(45 + spot_shift, -42, 52 + spot_shift, -15, 45 + spot_shift, 10)
            spot_path.cubicTo(32 + spot_shift, 0, 20 + spot_shift, -20, 15 + spot_shift, -45)
            spot_grad = QLinearGradient(20 + spot_shift, -40, 48 + spot_shift, 5)
            spot_grad.setColorAt(0.0, palette["spot_t"])
            spot_grad.setColorAt(1.0, palette["spot_b"])
            painter.setBrush(QBrush(spot_grad))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawPath(spot_path)

        # 5. 软萌凸起白肚皮 (Belly Volume Highlight, 沿球体曲面透视投射)
        painter.save()
        if is_spin_front:
            painter.translate(belly_offset_x, 0)
            painter.scale(cos_a, 1.0)
        belly_rect = QRectF(-30, 2, 60, 44)
        belly_grad = QRadialGradient(0, 15, 32, 0, 8)
        belly_grad.setColorAt(0.0, QColor(255, 255, 255, 220))
        belly_grad.setColorAt(0.7, QColor(255, 250, 245, 170))
        belly_grad.setColorAt(1.0, QColor(255, 235, 220, 0))
        painter.setBrush(QBrush(belly_grad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(belly_rect)
        painter.restore()

        # 6. 3D 球体顶面光泽高光 (Specular Highlight)
        painter.save()
        painter.translate(-21, -30)
        painter.rotate(-22)
        spec_grad = QLinearGradient(-15, -7, 15, 7)
        spec_grad.setColorAt(0.0, QColor(255, 255, 255, 140))
        spec_grad.setColorAt(0.6, QColor(255, 255, 255, 60))
        spec_grad.setColorAt(1.0, QColor(255, 255, 255, 0))
        painter.setBrush(QBrush(spec_grad))
        painter.drawEllipse(QRectF(-15, -7, 30, 14))
        painter.restore()

        # 7. 面部层 (腮红、胡须、五官：旋转时在正面沿 3D 球体曲面透视投射移动)
        painter.save()
        if is_spin_front:
            painter.translate(face_offset_x, 0)
            painter.scale(cos_a, 1.0)

        # 柔和羽化立体腮红 (带微光)
        blush_alpha = 190 if (self.petting_timer > 0 or self.model.stage == "BABY") else 125
        for bx, by in [(-33, 4), (33, 4)]:
            b_grad = QRadialGradient(bx, by, 12)
            b_grad.setColorAt(0.0, QColor(255, 110, 145, blush_alpha))
            b_grad.setColorAt(0.55, QColor(255, 140, 170, int(blush_alpha * 0.6)))
            b_grad.setColorAt(1.0, QColor(255, 160, 180, 0))
            painter.setBrush(QBrush(b_grad))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(QRectF(bx - 12, by - 8, 24, 16))
            painter.setBrush(QBrush(QColor(255, 255, 255, 210)))
            painter.drawEllipse(QRectF(bx - 2, by - 4, 3.5, 3.5))

        # 灵动弧线胡须
        whisk_col = QColor(palette["outline"]).lighter(120)
        painter.setPen(QPen(whisk_col, 2.2, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        w_l1 = QPainterPath(); w_l1.moveTo(-42, 2); w_l1.cubicTo(-50, 1, -58, -1, -64, -3); painter.drawPath(w_l1)
        w_l2 = QPainterPath(); w_l2.moveTo(-42, 7); w_l2.cubicTo(-50, 8, -58, 11, -62, 13); painter.drawPath(w_l2)
        w_r1 = QPainterPath(); w_r1.moveTo(42, 2); w_r1.cubicTo(50, 1, 58, -1, 64, -3); painter.drawPath(w_r1)
        w_r2 = QPainterPath(); w_r2.moveTo(42, 7); w_r2.cubicTo(50, 8, 58, 11, 62, 13); painter.drawPath(w_r2)

        # 眼睛与嘴巴 (支持异色瞳与全部动作面容)
        self._draw_cat_face(painter, state, skin_id)
        painter.restore()

        # 8. 立体胖嘟嘟小爪爪 (3D Plush Paws)
        if state != "CARDBOARD_BOX":
            painter.save()
            if is_spin_front:
                painter.translate(sin_a * 8.0, 0)
            self._draw_plush_paws(painter, state, palette)
            painter.restore()

    def _draw_cat_back(self, painter: QPainter, palette, spin_info):
        """猫咪 3D 立体手办背影视角：展现圆润后脑勺、后背斑纹、前景甩动尾巴与可爱肉垫足跟"""
        sin_a = spin_info.get("sin_a", 0.0)
        ear_twitch = math.sin(self.anim_time * 6.0) * 3.0
        ear_shift = sin_a * 14.0

        flick_val = 0.0
        if self.ear_flick_timer > 0:
            p = 1.0 - (self.ear_flick_timer / 0.30)
            flick_val = math.sin(p * math.pi * 3.5) * 8.0 * (1.0 - p)
        flick_l = flick_val if self.ear_flick_side == "left" else 0.0
        flick_r = flick_val if self.ear_flick_side == "right" else 0.0
        ear_twitch_l = ear_twitch + flick_l
        ear_twitch_r = -ear_twitch - flick_r

        # 1. 背部立体耳朵 (无粉色内耳，呈现立体毛发外壳)
        # 左耳背 (温润三角圆弧猫耳)
        left_ear = QPainterPath()
        left_ear.moveTo(-43 + ear_shift, -26)
        left_ear.cubicTo(-48 + ear_shift, -38, -51 + ear_shift, -50, -46 + ear_shift, -58 + ear_twitch_l)
        left_ear.cubicTo(-43 + ear_shift, -63 + ear_twitch_l, -35 + ear_shift, -63 + ear_twitch_l, -32 + ear_shift, -57 + ear_twitch_l)
        left_ear.cubicTo(-26 + ear_shift, -49, -20 + ear_shift, -42, -14 + ear_shift, -38)
        left_ear.cubicTo(-22 + ear_shift, -32, -32 + ear_shift, -28, -43 + ear_shift, -26)
        left_ear.closeSubpath()
        ear_grad_l = QLinearGradient(-46 + ear_shift, -63, -14 + ear_shift, -26)
        ear_grad_l.setColorAt(0.0, QColor(palette["ear_l_t"]).darker(115))
        ear_grad_l.setColorAt(1.0, QColor(palette["ear_l_b"]).darker(120))
        painter.setBrush(QBrush(ear_grad_l))
        painter.setPen(QPen(QColor(palette["outline"]), 3.2))
        painter.drawPath(left_ear)

        # 右耳背 (温润三角圆弧猫耳)
        right_ear = QPainterPath()
        right_ear.moveTo(43 + ear_shift, -26)
        right_ear.cubicTo(48 + ear_shift, -38, 51 + ear_shift, -50, 46 + ear_shift, -58 + ear_twitch_r)
        right_ear.cubicTo(43 + ear_shift, -63 + ear_twitch_r, 35 + ear_shift, -63 + ear_twitch_r, 32 + ear_shift, -57 + ear_twitch_r)
        right_ear.cubicTo(26 + ear_shift, -49, 20 + ear_shift, -42, 14 + ear_shift, -38)
        right_ear.cubicTo(22 + ear_shift, -32, 32 + ear_shift, -28, 43 + ear_shift, -26)
        right_ear.closeSubpath()
        ear_grad_r = QLinearGradient(46 + ear_shift, -63, 14 + ear_shift, -26)
        ear_grad_r.setColorAt(0.0, QColor(palette["ear_r_t"]).darker(115))
        ear_grad_r.setColorAt(1.0, QColor(palette["ear_r_b"]).darker(120))
        painter.setBrush(QBrush(ear_grad_r))
        painter.setPen(QPen(QColor(palette["outline"]), 3.2))
        painter.drawPath(right_ear)

        # 2. 3D 球体后背与后脑勺 (Spherical Back Volume)
        body_rect = QRectF(-52, -48, 104, 100)
        body_rad = QRadialGradient(-15, -20, 75, -15, -20)
        body_rad.setColorAt(0.0, QColor(palette["body_hl"]))
        body_rad.setColorAt(0.35, QColor(palette["body_light"]))
        body_rad.setColorAt(0.72, QColor(palette["body_mid"]))
        body_rad.setColorAt(0.92, QColor(palette["body_dark"]))
        body_rad.setColorAt(1.0, QColor(palette["body_shadow"]))
        painter.setBrush(QBrush(body_rad))
        painter.setPen(QPen(QColor(palette["outline"]), 3.5))
        painter.drawEllipse(body_rect)

        # 3. 后背特色毛发斑纹
        if palette["spot_t"]:
            spot_path = QPainterPath()
            spot_path.moveTo(-10 - ear_shift, -45)
            spot_path.cubicTo(15 - ear_shift, -40, 22 - ear_shift, -10, 15 - ear_shift, 20)
            spot_path.cubicTo(-2 - ear_shift, 15, -15 - ear_shift, -20, -10 - ear_shift, -45)
            spot_grad = QLinearGradient(-10, -40, 20, 15)
            spot_grad.setColorAt(0.0, palette["spot_t"])
            spot_grad.setColorAt(1.0, palette["spot_b"])
            painter.setBrush(QBrush(spot_grad))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawPath(spot_path)

        # 4. 后脑勺 3D 光泽高光 (Specular Back Sheen)
        painter.save()
        painter.translate(-18, -32)
        painter.rotate(-18)
        spec_grad = QLinearGradient(-15, -7, 15, 7)
        spec_grad.setColorAt(0.0, QColor(255, 255, 255, 120))
        spec_grad.setColorAt(0.6, QColor(255, 255, 255, 40))
        spec_grad.setColorAt(1.0, QColor(255, 255, 255, 0))
        painter.setBrush(QBrush(spec_grad))
        painter.drawEllipse(QRectF(-14, -6, 28, 12))
        painter.restore()

        # 5. 立体前景尾巴 (位于身体前景层欢快甩动，呈现震撼真实前后纵深)
        tail_swing = math.sin(self.anim_time * 12.0) * 20.0
        tail_x = -sin_a * 18.0
        painter.save()
        painter.translate(tail_x, 24)
        painter.rotate(tail_swing)
        tail_path = QPainterPath()
        tail_path.moveTo(0, 0)
        tail_path.cubicTo(26, 8, 36, -26, 22, -38)
        tail_path.cubicTo(14, -42, 6, -22, 0, -10)
        tail_grad = QLinearGradient(0, 0, 25, -30)
        tail_grad.setColorAt(0.0, QColor(palette["tail_l"]))
        tail_grad.setColorAt(1.0, QColor(palette["tail_d"]))
        painter.setBrush(QBrush(tail_grad))
        painter.setPen(QPen(QColor(palette["outline"]), 3.2))
        painter.drawPath(tail_path)
        painter.restore()

        # 6. 立体后足脚跟 (Hind Paws)
        outline_col = QColor(palette["outline"])
        paw_col = QColor(palette.get("paw_b", "#F0DFD1"))
        for px in [-28, 12]:
            paw_rect = QRectF(px, 39, 20, 14)
            paw_g = QRadialGradient(px + 10, 45, 15)
            paw_g.setColorAt(0.0, QColor(palette.get("paw_t", "#FFFFFF")))
            paw_g.setColorAt(1.0, paw_col)
            painter.setBrush(QBrush(paw_g))
            painter.setPen(QPen(outline_col, 2.6))
            painter.drawEllipse(paw_rect)

    def _draw_plush_paws(self, painter: QPainter, state, palette):
        paw_col_t = QColor(palette.get("paw_t", "#FFFFFF"))
        paw_col_b = QColor(palette.get("paw_b", "#F0DFD1"))
        outline_col = QColor(palette["outline"])

        def draw_single_paw(x, y, w, h, pad_x, pad_y, pad_w, pad_h):
            paw_rect = QRectF(x, y, w, h)
            paw_grad = QRadialGradient(x + w * 0.4, y + h * 0.35, max(w, h))
            paw_grad.setColorAt(0.0, paw_col_t)
            paw_grad.setColorAt(0.7, paw_col_b)
            paw_grad.setColorAt(1.0, paw_col_b.darker(110))
            painter.setBrush(QBrush(paw_grad))
            painter.setPen(QPen(outline_col, 2.8))
            painter.drawEllipse(paw_rect)

            # 3D 粉嫩果冻主掌心肉垫 (Palm Pad)
            pad_rect = QRectF(pad_x, pad_y, pad_w, pad_h)
            pad_grad = QRadialGradient(pad_x + pad_w * 0.45, pad_y + pad_h * 0.35, max(pad_w, pad_h))
            pad_grad.setColorAt(0.0, QColor("#FFB2B2"))
            pad_grad.setColorAt(0.75, QColor("#FF768C"))
            pad_grad.setColorAt(1.0, QColor("#D94B62"))
            painter.setBrush(QBrush(pad_grad))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(pad_rect)
            # 主掌心高光
            painter.setBrush(QBrush(QColor(255, 255, 255, 210)))
            painter.drawEllipse(QRectF(pad_x + pad_w * 0.22, pad_y + pad_h * 0.16, pad_w * 0.34, pad_h * 0.28))

            # 3 颗萌萌趾尖肉垫 (3 Cute Toe Beans)
            toe_r = min(pad_w, pad_h) * 0.44
            toe_offsets = [
                (-pad_w * 0.36, -pad_h * 0.36),
                (0.0, -pad_h * 0.52),
                (pad_w * 0.36, -pad_h * 0.36)
            ]
            for tox, toy in toe_offsets:
                tx = pad_x + pad_w * 0.5 + tox - toe_r * 0.5
                ty = pad_y + pad_h * 0.5 + toy - toe_r * 0.5
                t_rect = QRectF(tx, ty, toe_r, toe_r)
                t_grad = QRadialGradient(tx + toe_r * 0.4, ty + toe_r * 0.35, toe_r)
                t_grad.setColorAt(0.0, QColor("#FFB8B8"))
                t_grad.setColorAt(0.8, QColor("#FF768C"))
                t_grad.setColorAt(1.0, QColor("#D94B62"))
                painter.setBrush(QBrush(t_grad))
                painter.drawEllipse(t_rect)
                painter.setBrush(QBrush(QColor(255, 255, 255, 225)))
                painter.drawEllipse(QRectF(tx + toe_r * 0.22, ty + toe_r * 0.2, toe_r * 0.36, toe_r * 0.36))

        if state == "WASH_FACE":
            draw_single_paw(-35, 40, 22, 14, -28, 45, 8, 6)
            rub_x = 18 + math.cos(self.anim_time * 12.0) * 6.0
            rub_y = 6 + math.sin(self.anim_time * 12.0) * 8.0
            draw_single_paw(rub_x, rub_y, 22, 16, rub_x + 5, rub_y + 4, 8, 7)
        elif state == "STRETCH_YAWN":
            draw_single_paw(-44, 46, 28, 12, -36, 48, 10, 6)
            draw_single_paw(16, 46, 28, 12, 24, 48, 10, 6)
        elif state == "CHASE_BUTTERFLY":
            draw_single_paw(-35, 40, 22, 14, -28, 45, 8, 6)
            swat_y = -10 + math.sin(self.anim_time * 14.0) * 12.0
            draw_single_paw(20, swat_y, 22, 16, 25, swat_y + 4, 8, 7)
        elif state == "CATCH_MOUSE":
            # 捕鼠前爪：前伸并扑按向地面小老鼠
            pounce_l = math.sin(self.anim_time * 8.0) * 4.0
            draw_single_paw(-32, 42 + pounce_l, 25, 17, -25, 48 + pounce_l, 11, 8)
            draw_single_paw(16, 42 - pounce_l, 25, 17, 23, 48 - pounce_l, 11, 8)
        elif state == "PLAY_YARN":
            # 玩毛线：左右前爪交替轻拍拨动毛线球
            bat_l = math.sin(self.anim_time * 9.0) * 8.0
            bat_r = math.cos(self.anim_time * 9.0) * 8.0
            draw_single_paw(-36, 38 + bat_l, 25, 17, -29, 44 + bat_l, 11, 8)
            draw_single_paw(12, 38 + bat_r, 25, 17, 19, 44 + bat_r, 11, 8)
        elif state in ("DRAGGING", "FALLING"):
            # 被拎起悬空或自由落体：小肉垫爪爪在空中紧张又可爱地交替快速乱蹬
            kick_l = math.sin(self.anim_time * 22.0) * 11.0
            kick_r = math.cos(self.anim_time * 22.0) * 11.0
            draw_single_paw(-34, 40 + kick_l, 24, 16, -27, 46 + kick_l, 10, 7)
            draw_single_paw(10, 40 + kick_r, 24, 16, 17, 46 + kick_r, 10, 7)
        else:
            leg_offset = math.sin(self.anim_time * 8.0) * 6.0 if state in ("WALK_LEFT", "WALK_RIGHT") else 0.0
            draw_single_paw(-36, 38 + leg_offset, 25, 17, -29, 44 + leg_offset, 11, 8)
            draw_single_paw(11, 38 - leg_offset, 25, 17, 18, 44 - leg_offset, 11, 8)

    def _draw_cat_face(self, painter: QPainter, state, skin_id):
        # 异色瞳处理 (白猫: 蓝瞳+翠绿瞳; 黑猫: 闪亮金瞳)
        eye_l_col = QColor("#3D2923")
        eye_r_col = QColor("#3D2923")

        if skin_id == "cat_white":
            eye_l_col = QColor("#38BDF8")  # 冰蓝
            eye_r_col = QColor("#10B981")  # 翡翠绿
        elif skin_id == "cat_black":
            eye_l_col = QColor("#FBBF24")  # 闪耀明金
            eye_r_col = QColor("#FBBF24")

        self._draw_face_by_state(painter, state, eye_l_col, eye_r_col)

    # ================= 柴犬与柯基皮肤绘制 (3D 立体手办质感) =================
    def _draw_dog(self, painter: QPainter, state, skin_id, spin_info=None):
        colors = {
            "dog_shiba": {
                "fur_hl": "#FFC082", "fur_light": "#FFA858", "fur_mid": "#E88B43", "fur_dark": "#C96A20", "fur_shadow": "#A84E0C",
                "outline": "#72482F", "muzzle_t": "#FFFFFF", "muzzle_b": "#F5EBE1", "brow": "#FFFFFF",
                "tail_l": "#FFA858", "tail_d": "#C96A20", "paw_t": "#FFFFFF", "paw_b": "#F0E4D8"
            },
            "dog_black": {
                "fur_hl": "#56565C", "fur_light": "#3C3C40", "fur_mid": "#29292B", "fur_dark": "#1A1A1C", "fur_shadow": "#0E0E10",
                "outline": "#151516", "muzzle_t": "#F5E8DC", "muzzle_b": "#D8C5B2", "brow": "#D8A070",
                "tail_l": "#3C3C40", "tail_d": "#1A1A1C", "paw_t": "#F5E8DC", "paw_b": "#D8C5B2"
            },
            "dog_corgi": {
                "fur_hl": "#FFD073", "fur_light": "#FFB833", "fur_mid": "#EE9B00", "fur_dark": "#CA7A00", "fur_shadow": "#A65C00",
                "outline": "#6B3D11", "muzzle_t": "#FFFFFF", "muzzle_b": "#F5EBE1", "brow": "#FFFFFF",
                "tail_l": "#FFB833", "tail_d": "#CA7A00", "paw_t": "#FFFFFF", "paw_b": "#F0E4D8"
            }
        }
        pal = colors.get(skin_id, colors["dog_shiba"])

        # 3D 旋转背面绘制 (Back View)
        if spin_info and spin_info.get("is_spin", False) and not spin_info.get("is_front", True):
            self._draw_dog_back(painter, pal, spin_info)
            return

        is_spin_front = bool(spin_info and spin_info.get("is_spin", False) and spin_info.get("is_front", True))
        sin_a = spin_info.get("sin_a", 0.0) if spin_info else 0.0
        cos_a = spin_info.get("cos_a", 1.0) if spin_info else 1.0
        face_offset_x = spin_info.get("face_offset_x", 0.0) if spin_info else 0.0

        # 1. 3D 卷尾巴
        if state != "CARDBOARD_BOX":
            tail_wag = math.sin(self.anim_time * 8.0) * 12.0
            tail_x = 35 - sin_a * 15.0 if is_spin_front else 35
            painter.save()
            painter.translate(tail_x, 20)
            painter.rotate(tail_wag)
            tail_path = QPainterPath()
            tail_path.moveTo(0, 0)
            tail_path.cubicTo(25, 5, 35, -20, 20, -30)
            tail_path.cubicTo(10, -35, 5, -15, 0, -5)
            tail_grad = QLinearGradient(0, 0, 25, -25)
            tail_grad.setColorAt(0.0, QColor(pal["tail_l"]))
            tail_grad.setColorAt(1.0, QColor(pal["tail_d"]))
            painter.setBrush(QBrush(tail_grad))
            painter.setPen(QPen(QColor(pal["outline"]), 3))
            painter.drawPath(tail_path)
            painter.restore()

        # 2. 立体双耳 (带 3D 轨道视差偏移)
        ear_shift = sin_a * 14.0 if is_spin_front else 0.0
        left_ear = QPainterPath()
        left_ear.moveTo(-35 + ear_shift, -28)
        left_ear.lineTo(-50 + ear_shift, -78)
        left_ear.lineTo(-12 + ear_shift, -45)
        left_ear.closeSubpath()
        ear_g_l = QLinearGradient(-50 + ear_shift, -78, -12 + ear_shift, -28)
        ear_g_l.setColorAt(0.0, QColor(pal["fur_hl"]))
        ear_g_l.setColorAt(1.0, QColor(pal["fur_mid"]))
        painter.setBrush(QBrush(ear_g_l))
        painter.setPen(QPen(QColor(pal["outline"]), 3.2))
        painter.drawPath(left_ear)

        right_ear = QPainterPath()
        right_ear.moveTo(35 + ear_shift, -28)
        right_ear.lineTo(50 + ear_shift, -78)
        right_ear.lineTo(12 + ear_shift, -45)
        right_ear.closeSubpath()
        ear_g_r = QLinearGradient(50 + ear_shift, -78, 12 + ear_shift, -28)
        ear_g_r.setColorAt(0.0, QColor(pal["fur_hl"]))
        ear_g_r.setColorAt(1.0, QColor(pal["fur_mid"]))
        painter.setBrush(QBrush(ear_g_r))
        painter.drawPath(right_ear)

        # 3. 头部身体 3D 球形漫反射光影 (Spherical Volume)
        body_rect = QRectF(-52, -48, 104, 100)
        fur_rad = QRadialGradient(-18, -20, 75, -18, -20)
        fur_rad.setColorAt(0.0, QColor(pal["fur_hl"]))
        fur_rad.setColorAt(0.35, QColor(pal["fur_light"]))
        fur_rad.setColorAt(0.72, QColor(pal["fur_mid"]))
        fur_rad.setColorAt(0.92, QColor(pal["fur_dark"]))
        fur_rad.setColorAt(1.0, QColor(pal["fur_shadow"]))
        painter.setBrush(QBrush(fur_rad))
        painter.setPen(QPen(QColor(pal["outline"]), 3.5))
        painter.drawEllipse(body_rect)

        # 4. 面部与腮红层 (旋转时沿 3D 球面透视投射)
        painter.save()
        if is_spin_front:
            painter.translate(face_offset_x, 0)
            painter.scale(cos_a, 1.0)

        # 柴犬白色面罩 (立体浮雕渐变)
        mask = QPainterPath()
        mask.moveTo(-36, -8)
        mask.cubicTo(-46, 25, -20, 48, 0, 48)
        mask.cubicTo(20, 48, 46, 25, 36, -8)
        mask.cubicTo(20, 10, -20, 10, -36, -8)
        mask_grad = QLinearGradient(0, -8, 0, 48)
        mask_grad.setColorAt(0.0, QColor(pal["muzzle_t"]))
        mask_grad.setColorAt(1.0, QColor(pal["muzzle_b"]))
        painter.setBrush(QBrush(mask_grad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawPath(mask)

        # 柴犬标志性白眉毛
        for bx in [-28, 16]:
            brow_g = QRadialGradient(bx + 6, -28, 8)
            brow_g.setColorAt(0.0, QColor(pal["brow"]))
            brow_g.setColorAt(1.0, QColor(pal["muzzle_b"]))
            painter.setBrush(QBrush(brow_g))
            painter.drawEllipse(QRectF(bx, -32, 12, 10))

        # 柔和羽化立体腮红
        for bx, by in [(-33, 6), (33, 6)]:
            b_grad = QRadialGradient(bx, by, 12)
            b_grad.setColorAt(0.0, QColor(255, 120, 145, 140))
            b_grad.setColorAt(0.6, QColor(255, 145, 170, 70))
            b_grad.setColorAt(1.0, QColor(255, 160, 180, 0))
            painter.setBrush(QBrush(b_grad))
            painter.drawEllipse(QRectF(bx - 12, by - 8, 24, 16))

        # 面部表情
        self._draw_face_by_state(painter, state, QColor("#3D2923"), QColor("#3D2923"))
        painter.restore()

        # 5. 3D 顶面高光
        painter.save()
        painter.translate(-21, -30)
        painter.rotate(-22)
        spec_grad = QLinearGradient(-15, -7, 15, 7)
        spec_grad.setColorAt(0.0, QColor(255, 255, 255, 130))
        spec_grad.setColorAt(0.6, QColor(255, 255, 255, 50))
        spec_grad.setColorAt(1.0, QColor(255, 255, 255, 0))
        painter.setBrush(QBrush(spec_grad))
        painter.drawEllipse(QRectF(-15, -7, 30, 14))
        painter.restore()

        # 6. 立体肉垫爪爪
        if state != "CARDBOARD_BOX":
            painter.save()
            if is_spin_front:
                painter.translate(sin_a * 8.0, 0)
            self._draw_plush_paws(painter, state, pal)
            painter.restore()

    def _draw_dog_back(self, painter: QPainter, pal, spin_info):
        """柴犬/柯基 3D 立体手办背影视角：毛绒后背、可爱蜜桃臀与摇摆卷尾"""
        sin_a = spin_info.get("sin_a", 0.0)
        ear_shift = sin_a * 14.0

        # 1. 耳朵背面 (暗部毛发)
        left_ear = QPainterPath()
        left_ear.moveTo(-35 + ear_shift, -28)
        left_ear.lineTo(-50 + ear_shift, -78)
        left_ear.lineTo(-12 + ear_shift, -45)
        left_ear.closeSubpath()
        ear_g_l = QLinearGradient(-50 + ear_shift, -78, -12 + ear_shift, -28)
        ear_g_l.setColorAt(0.0, QColor(pal["fur_hl"]).darker(115))
        ear_g_l.setColorAt(1.0, QColor(pal["fur_mid"]).darker(120))
        painter.setBrush(QBrush(ear_g_l))
        painter.setPen(QPen(QColor(pal["outline"]), 3.2))
        painter.drawPath(left_ear)

        right_ear = QPainterPath()
        right_ear.moveTo(35 + ear_shift, -28)
        right_ear.lineTo(50 + ear_shift, -78)
        right_ear.lineTo(12 + ear_shift, -45)
        right_ear.closeSubpath()
        ear_g_r = QLinearGradient(50 + ear_shift, -78, 12 + ear_shift, -28)
        ear_g_r.setColorAt(0.0, QColor(pal["fur_hl"]).darker(115))
        ear_g_r.setColorAt(1.0, QColor(pal["fur_mid"]).darker(120))
        painter.setBrush(QBrush(ear_g_r))
        painter.drawPath(right_ear)

        # 2. 身体背面 3D 球体
        body_rect = QRectF(-52, -48, 104, 100)
        fur_rad = QRadialGradient(-18, -20, 75, -18, -20)
        fur_rad.setColorAt(0.0, QColor(pal["fur_hl"]))
        fur_rad.setColorAt(0.35, QColor(pal["fur_light"]))
        fur_rad.setColorAt(0.72, QColor(pal["fur_mid"]))
        fur_rad.setColorAt(0.92, QColor(pal["fur_dark"]))
        fur_rad.setColorAt(1.0, QColor(pal["fur_shadow"]))
        painter.setBrush(QBrush(fur_rad))
        painter.setPen(QPen(QColor(pal["outline"]), 3.5))
        painter.drawEllipse(body_rect)

        # 3. 后背白毛心形蜜桃臀 (柴犬/柯基标志萌点)
        butt_w = QPainterPath()
        butt_w.moveTo(-24, 25)
        butt_w.cubicTo(-32, 42, -5, 46, 0, 36)
        butt_w.cubicTo(5, 46, 32, 42, 24, 25)
        butt_w.cubicTo(12, 18, -12, 18, -24, 25)
        painter.setBrush(QBrush(QColor(pal["muzzle_t"])))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawPath(butt_w)

        # 4. 前置 3D 卷尾巴
        tail_wag = math.sin(self.anim_time * 12.0) * 16.0
        tail_x = -sin_a * 15.0
        painter.save()
        painter.translate(tail_x, 22)
        painter.rotate(tail_wag)
        tail_path = QPainterPath()
        tail_path.moveTo(0, 0)
        tail_path.cubicTo(25, 5, 35, -20, 20, -30)
        tail_path.cubicTo(10, -35, 5, -15, 0, -5)
        tail_grad = QLinearGradient(0, 0, 25, -25)
        tail_grad.setColorAt(0.0, QColor(pal["tail_l"]))
        tail_grad.setColorAt(1.0, QColor(pal["tail_d"]))
        painter.setBrush(QBrush(tail_grad))
        painter.setPen(QPen(QColor(pal["outline"]), 3))
        painter.drawPath(tail_path)
        painter.restore()

        # 5. 后足小爪跟
        outline_col = QColor(pal["outline"])
        for px in [-28, 12]:
            paw_rect = QRectF(px, 39, 20, 14)
            paw_g = QRadialGradient(px + 10, 45, 15)
            paw_g.setColorAt(0.0, QColor(pal["paw_t"]))
            paw_g.setColorAt(1.0, QColor(pal["paw_b"]))
            painter.setBrush(QBrush(paw_g))
            painter.setPen(QPen(outline_col, 2.6))
            painter.drawEllipse(paw_rect)

    # ================= 史莱姆皮肤绘制 (3D 晶莹果冻质感) =================
    def _draw_slime(self, painter: QPainter, state, skin_id, spin_info=None):
        if spin_info and spin_info.get("is_spin", False) and not spin_info.get("is_front", True):
            self._draw_slime_back(painter, skin_id, spin_info)
            return

        is_spin_front = bool(spin_info and spin_info.get("is_spin", False) and spin_info.get("is_front", True))
        sin_a = spin_info.get("sin_a", 0.0) if spin_info else 0.0
        cos_a = spin_info.get("cos_a", 1.0) if spin_info else 1.0
        face_offset_x = spin_info.get("face_offset_x", 0.0) if spin_info else 0.0

        jelly_wobble = math.sin(self.anim_time * 5.0) * 4.0
        slime_path = QPainterPath()
        slime_path.moveTo(0, -60)
        slime_path.cubicTo(18, -40, 60 + jelly_wobble, -10, 54, 30)
        slime_path.cubicTo(48, 55, -48, 55, -54, 30)
        slime_path.cubicTo(-60 - jelly_wobble, -10, -18, -40, 0, -60)

        # 3D 果冻晶莹径向次表面渐变 (Subsurface Scattering)
        slime_grad = QRadialGradient(-15, -15, 68, -15, -20)
        if skin_id == "slime_pink":
            slime_grad.setColorAt(0.0, QColor(255, 210, 230, 245))
            slime_grad.setColorAt(0.5, QColor(255, 110, 180, 240))
            slime_grad.setColorAt(0.9, QColor(219, 39, 119, 250))
            slime_grad.setColorAt(1.0, QColor(157, 23, 77, 255))
            outline_col = QColor(157, 23, 77)
        elif skin_id == "slime_gold":
            slime_grad.setColorAt(0.0, QColor(255, 250, 160, 245))
            slime_grad.setColorAt(0.5, QColor(250, 204, 21, 240))
            slime_grad.setColorAt(0.9, QColor(202, 138, 4, 250))
            slime_grad.setColorAt(1.0, QColor(146, 64, 14, 255))
            outline_col = QColor(146, 64, 14)
        else:
            slime_grad.setColorAt(0.0, QColor(160, 240, 255, 245))
            slime_grad.setColorAt(0.5, QColor(38, 166, 254, 240))
            slime_grad.setColorAt(0.9, QColor(14, 116, 215, 250))
            slime_grad.setColorAt(1.0, QColor(7, 89, 170, 255))
            outline_col = QColor(7, 89, 170)

        painter.setBrush(QBrush(slime_grad))
        painter.setPen(QPen(outline_col, 3.2))
        painter.drawPath(slime_path)

        # 萌萌天线 (带 3D 金球高光)
        star_x = math.sin(self.anim_time * 4.0) * 6.0
        painter.setPen(QPen(outline_col, 2.5))
        painter.drawLine(0, -60, int(star_x), -76)
        star_g = QRadialGradient(star_x - 2, -85, 9)
        star_g.setColorAt(0.0, QColor(255, 255, 180))
        star_g.setColorAt(0.7, QColor(250, 204, 21))
        star_g.setColorAt(1.0, QColor(180, 120, 0))
        painter.setBrush(QBrush(star_g))
        painter.setPen(QPen(QColor(180, 120, 0), 1.5))
        painter.drawEllipse(QRectF(star_x - 7, -83, 14, 14))

        # 果冻晶莹双层高光 (顶面弧光 + 内部折射光)
        painter.setBrush(QBrush(QColor(255, 255, 255, 180)))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-32, -38, 22, 12))
        painter.drawEllipse(QRectF(-38, -22, 10, 7))

        # 内部下部焦散折射亮圈
        caustic = QPainterPath()
        caustic.addEllipse(QRectF(15, 12, 28, 16))
        c_grad = QLinearGradient(15, 12, 38, 28)
        c_grad.setColorAt(0.0, QColor(255, 255, 255, 0))
        c_grad.setColorAt(1.0, QColor(255, 255, 255, 90))
        painter.setBrush(QBrush(c_grad))
        painter.drawPath(caustic)

        # 旋转时面部层透视投射
        painter.save()
        if is_spin_front:
            painter.translate(face_offset_x, 0)
            painter.scale(cos_a, 1.0)

        # 腮红
        for bx, by in [(-36, 10), (24, 10)]:
            b_grad = QRadialGradient(bx, by, 10)
            b_grad.setColorAt(0.0, QColor(255, 100, 170, 160))
            b_grad.setColorAt(1.0, QColor(255, 100, 170, 0))
            painter.setBrush(QBrush(b_grad))
            painter.drawEllipse(QRectF(bx - 9, by - 6, 18, 12))

        # 史莱姆动态面部表情
        self._draw_face_by_state(painter, state, QColor("#1E293B"), QColor("#1E293B"))
        painter.restore()

    def _draw_slime_back(self, painter: QPainter, skin_id, spin_info):
        """史莱姆 3D 果冻背面：晶莹剔透次表面散射、折射焦散球与金星天线"""
        sin_a = spin_info.get("sin_a", 0.0)
        jelly_wobble = math.sin(self.anim_time * 5.0) * 4.0
        slime_path = QPainterPath()
        slime_path.moveTo(0, -60)
        slime_path.cubicTo(18, -40, 60 + jelly_wobble, -10, 54, 30)
        slime_path.cubicTo(48, 55, -48, 55, -54, 30)
        slime_path.cubicTo(-60 - jelly_wobble, -10, -18, -40, 0, -60)

        # 3D 果冻晶莹背面折射色
        slime_grad = QRadialGradient(15, -15, 68, 15, -20)
        if skin_id == "slime_pink":
            slime_grad.setColorAt(0.0, QColor(255, 220, 235, 245))
            slime_grad.setColorAt(0.5, QColor(244, 114, 182, 240))
            slime_grad.setColorAt(1.0, QColor(157, 23, 77, 255))
            outline_col = QColor(157, 23, 77)
        elif skin_id == "slime_gold":
            slime_grad.setColorAt(0.0, QColor(255, 252, 180, 245))
            slime_grad.setColorAt(0.5, QColor(250, 204, 21, 240))
            slime_grad.setColorAt(1.0, QColor(146, 64, 14, 255))
            outline_col = QColor(146, 64, 14)
        else:
            slime_grad.setColorAt(0.0, QColor(186, 230, 253, 245))
            slime_grad.setColorAt(0.5, QColor(56, 189, 248, 240))
            slime_grad.setColorAt(1.0, QColor(7, 89, 170, 255))
            outline_col = QColor(7, 89, 170)

        painter.setBrush(QBrush(slime_grad))
        painter.setPen(QPen(outline_col, 3.2))
        painter.drawPath(slime_path)

        # 内部焦散折射光球 (内部纵深折射)
        caustic = QPainterPath()
        caustic.addEllipse(QRectF(-20 + sin_a * 8, 10, 32, 20))
        c_grad = QRadialGradient(-10 + sin_a * 8, 18, 20)
        c_grad.setColorAt(0.0, QColor(255, 255, 255, 120))
        c_grad.setColorAt(1.0, QColor(255, 255, 255, 0))
        painter.setBrush(QBrush(c_grad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawPath(caustic)

        # 天线小星星
        star_x = math.sin(self.anim_time * 4.0) * 6.0
        painter.setPen(QPen(outline_col, 2.5))
        painter.drawLine(0, -60, int(star_x), -76)
        star_g = QRadialGradient(star_x - 2, -85, 9)
        star_g.setColorAt(0.0, QColor(255, 255, 180))
        star_g.setColorAt(0.7, QColor(250, 204, 21))
        star_g.setColorAt(1.0, QColor(180, 120, 0))
        painter.setBrush(QBrush(star_g))
        painter.setPen(QPen(QColor(180, 120, 0), 1.5))
        painter.drawEllipse(QRectF(star_x - 7, -83, 14, 14))

    # ================= 帝企鹅皮肤绘制 (3D 饱满企鹅手办) =================
    def _draw_penguin(self, painter: QPainter, state, spin_info=None):
        if spin_info and spin_info.get("is_spin", False) and not spin_info.get("is_front", True):
            self._draw_penguin_back(painter, spin_info)
            return

        is_spin_front = bool(spin_info and spin_info.get("is_spin", False) and spin_info.get("is_front", True))
        sin_a = spin_info.get("sin_a", 0.0) if spin_info else 0.0
        cos_a = spin_info.get("cos_a", 1.0) if spin_info else 1.0
        face_offset_x = spin_info.get("face_offset_x", 0.0) if spin_info else 0.0

        # 黑色球体身体 (3D 天鹅绒深邃漫反射)
        body_rect = QRectF(-50, -48, 100, 98)
        body_rad = QRadialGradient(-15, -18, 70, -15, -18)
        body_rad.setColorAt(0.0, QColor("#475569"))
        body_rad.setColorAt(0.4, QColor("#334155"))
        body_rad.setColorAt(0.8, QColor("#1E293B"))
        body_rad.setColorAt(1.0, QColor("#0F172A"))
        painter.setBrush(QBrush(body_rad))
        painter.setPen(QPen(QColor("#080D1A"), 3.2))
        painter.drawEllipse(body_rect)

        # 面部与白肚皮层 (旋转时沿 3D 球体透视位移)
        painter.save()
        if is_spin_front:
            painter.translate(face_offset_x, 0)
            painter.scale(cos_a, 1.0)

        # 企鹅 3D 饱满白肚皮 (向前隆起圆润光泽)
        belly = QRectF(-36, -24, 72, 68)
        belly_rad = QRadialGradient(0, -6, 38, 0, -12)
        belly_rad.setColorAt(0.0, QColor("#FFFFFF"))
        belly_rad.setColorAt(0.7, QColor("#F1F5F9"))
        belly_rad.setColorAt(1.0, QColor("#CBD5E1"))
        painter.setBrush(QBrush(belly_rad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(belly)

        # 企鹅黄色侧颊纹 (立体渐变)
        for cx, r_scale in [(-37, 1), (37, -1)]:
            cheek_g = QLinearGradient(cx, -32, cx + 10 * r_scale, -10)
            cheek_g.setColorAt(0.0, QColor("#FDE047"))
            cheek_g.setColorAt(1.0, QColor("#EAB308"))
            painter.setBrush(QBrush(cheek_g))
            painter.drawEllipse(QRectF(cx - 8, -32, 16, 22))

        # 腮红
        for bx, by in [(-25, 4), (25, 4)]:
            b_grad = QRadialGradient(bx, by, 10)
            b_grad.setColorAt(0.0, QColor(255, 120, 140, 140))
            b_grad.setColorAt(1.0, QColor(255, 120, 140, 0))
            painter.setBrush(QBrush(b_grad))
            painter.drawEllipse(QRectF(bx - 8, by - 5, 16, 10))

        # 企鹅面容表情
        self._draw_face_by_state(painter, state, QColor("#0F172A"), QColor("#0F172A"), draw_mouth=False)

        # 橙黄小企鹅喙 (3D 分面立体光泽)
        beak_left = QPolygonF([QPointF(0, 3), QPointF(-8, 3), QPointF(0, 14)])
        beak_right = QPolygonF([QPointF(0, 3), QPointF(8, 3), QPointF(0, 14)])
        painter.setBrush(QBrush(QColor("#FB923C")))
        painter.setPen(QPen(QColor("#C2410C"), 1.2))
        painter.drawPolygon(beak_left)
        painter.setBrush(QBrush(QColor("#EA580C")))
        painter.drawPolygon(beak_right)
        painter.restore()

        # 小翅膀 (立体弧光多样动作摆动)
        if state in ("HEAD_BOB_MUSIC", "HAPPY_SPIN"):
            flipper_angle = math.sin(self.anim_time * 16.0) * 32.0
            flipper_r_angle = flipper_angle
        elif state == "WASH_FACE":
            flipper_angle = 10.0
            flipper_r_angle = -55.0 + math.sin(self.anim_time * 12.0) * 12.0
        else:
            flipper_angle = math.sin(self.anim_time * 6.0) * 15.0
            flipper_r_angle = flipper_angle

        wing_shift = sin_a * 8.0 if is_spin_front else 0.0
        for fx, fa in [(-45 + wing_shift, -flipper_angle), (45 + wing_shift, flipper_r_angle)]:
            painter.save()
            painter.translate(fx, -5)
            painter.rotate(fa)
            f_grad = QLinearGradient(-8, -5, 10, 33)
            f_grad.setColorAt(0.0, QColor("#334155"))
            f_grad.setColorAt(1.0, QColor("#0F172A"))
            painter.setBrush(QBrush(f_grad))
            painter.setPen(QPen(QColor("#080D1A"), 2.5))
            painter.drawEllipse(QRectF(-9, -5, 18, 38))
            painter.restore()

        # 企鹅立体小脚丫
        leg_offset = math.sin(self.anim_time * 8.0) * 5.0 if state in ("WALK_LEFT", "WALK_RIGHT") else 0.0
        for fx, fo in [(-20 + wing_shift * 0.5, leg_offset), (20 + wing_shift * 0.5, -leg_offset)]:
            foot_g = QRadialGradient(fx, 45 + fo, 14)
            foot_g.setColorAt(0.0, QColor("#FDBA74"))
            foot_g.setColorAt(0.8, QColor("#EA580C"))
            foot_g.setColorAt(1.0, QColor("#C2410C"))
            painter.setBrush(QBrush(foot_g))
            painter.setPen(QPen(QColor("#9A3412"), 1.8))
            painter.drawEllipse(QRectF(fx - 11, 41 + fo, 22, 13))

    def _draw_penguin_back(self, painter: QPainter, spin_info):
        """帝企鹅 3D 立体手办背影视角：燕尾服后背、尖小翘尾羽与扇动小翅膀"""
        sin_a = spin_info.get("sin_a", 0.0)

        # 1. 企鹅燕尾服后背 (深邃天鹅绒黑立体球体)
        body_rect = QRectF(-50, -48, 100, 98)
        body_rad = QRadialGradient(-15, -18, 70, -15, -18)
        body_rad.setColorAt(0.0, QColor("#475569"))
        body_rad.setColorAt(0.4, QColor("#334155"))
        body_rad.setColorAt(0.8, QColor("#1E293B"))
        body_rad.setColorAt(1.0, QColor("#0F172A"))
        painter.setBrush(QBrush(body_rad))
        painter.setPen(QPen(QColor("#080D1A"), 3.2))
        painter.drawEllipse(body_rect)

        # 2. 后脑勺天鹅绒高光
        painter.save()
        painter.translate(-16, -30)
        painter.rotate(-18)
        spec_grad = QLinearGradient(-15, -7, 15, 7)
        spec_grad.setColorAt(0.0, QColor(255, 255, 255, 90))
        spec_grad.setColorAt(1.0, QColor(255, 255, 255, 0))
        painter.setBrush(QBrush(spec_grad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-14, -6, 28, 12))
        painter.restore()

        # 3. 企鹅小尾巴尖 (尖尖朝上黑色小尾羽)
        tail_path = QPolygonF([QPointF(-8 - sin_a * 6, 38), QPointF(8 - sin_a * 6, 38), QPointF(-sin_a * 6, 48)])
        painter.setBrush(QBrush(QColor("#0F172A")))
        painter.setPen(QPen(QColor("#080D1A"), 2))
        painter.drawPolygon(tail_path)

        # 4. 侧边欢快扇动小翅膀
        flipper_angle = math.sin(self.anim_time * 16.0) * 32.0
        for fx, fa in [(-45, -flipper_angle), (45, flipper_angle)]:
            painter.save()
            painter.translate(fx, -5)
            painter.rotate(fa)
            f_grad = QLinearGradient(-8, -5, 10, 33)
            f_grad.setColorAt(0.0, QColor("#334155"))
            f_grad.setColorAt(1.0, QColor("#0F172A"))
            painter.setBrush(QBrush(f_grad))
            painter.setPen(QPen(QColor("#080D1A"), 2.5))
            painter.drawEllipse(QRectF(-9, -5, 18, 38))
            painter.restore()

        # 5. 企鹅立体橙脚蹼跟
        for fx in [-20, 20]:
            foot_g = QRadialGradient(fx, 45, 14)
            foot_g.setColorAt(0.0, QColor("#FDBA74"))
            foot_g.setColorAt(0.8, QColor("#EA580C"))
            foot_g.setColorAt(1.0, QColor("#C2410C"))
            painter.setBrush(QBrush(foot_g))
            painter.setPen(QPen(QColor("#9A3412"), 2))
            painter.drawEllipse(QRectF(fx - 12, 42, 24, 12))

    # ================= 通用面部与动作特效绘制 =================
    def _draw_face_by_state(self, painter: QPainter, state, eye_l_col=None, eye_r_col=None, draw_mouth=True):
        if eye_l_col is None:
            eye_l_col = QColor("#3D2923")
        if eye_r_col is None:
            eye_r_col = QColor("#3D2923")

        if self.model.is_sleeping:
            self._draw_sleeping_face(painter)
            return

        if state in ("DRAGGING", "FALLING"):
            self._draw_surprised_dangle_face(painter, eye_l_col, eye_r_col)
            return

        if state == "STRETCH_YAWN":
            self._draw_yawn_face(painter)
            return

        if state == "DIZZY":
            self._draw_dizzy_face(painter)
            return

        if state == "WASH_FACE":
            self._draw_wash_face(painter)
            return

        if state == "DOZE_OFF":
            self._draw_dozing_face(painter)
            return

        if state in ("TILT_HEAD", "LOOK_AROUND"):
            self._draw_curious_face(painter, eye_l_col, eye_r_col)
            return

        if state == "CATCH_MOUSE":
            self._draw_hunting_face(painter, eye_l_col, eye_r_col)
            return

        if state == "PLAY_YARN":
            self._draw_playful_face(painter, eye_l_col, eye_r_col)
            return

        if self.petting_timer > 0 or self.eating_timer > 0 or state in ("HAPPY_SPIN", "SIT_WAG_TAIL"):
            self._draw_happy_face(painter)
            return

        if self.is_blinking:
            self._draw_blinking_eyes(painter)
        else:
            self._draw_normal_eyes(painter, eye_l_col, eye_r_col)
        if draw_mouth:
            self._draw_standard_mouth(painter)

    def _draw_surprised_dangle_face(self, painter: QPainter, col_l, col_r):
        # 拎起/下落时惊萌圆溜溜大眼 (O O) 与圆圆小口 ("o")
        gaze_ox = getattr(self, "current_gaze_x", 0.0) * 2.5
        gaze_oy = getattr(self, "current_gaze_y", 0.0) * 2.0
        for ex, col in [(-19, col_l), (19, col_r)]:
            # 超圆大眼框
            painter.setBrush(QBrush(col.darker(120)))
            painter.setPen(QPen(QColor("#150A06"), 1.8))
            painter.drawEllipse(QRectF(ex - 9, -15, 18, 20))
            # 惊吓小闪光大瞳仁 (随视线微动)
            painter.setBrush(QBrush(QColor(255, 255, 255, 250)))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(QRectF(ex - 5 + gaze_ox, -13 + gaze_oy, 7, 8))
            painter.drawEllipse(QRectF(ex + 1 + gaze_ox * 0.5, -6 + gaze_oy * 0.5, 4, 4))

        # 害羞/紧张小腮红
        for bx in [-30, 30]:
            painter.setBrush(QBrush(QColor(255, 120, 150, 160)))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(QRectF(bx - 8, 4, 16, 10))

        # 紧张张开的圆圆小口 ("o")
        painter.setBrush(QBrush(QColor("#D94F4F")))
        painter.setPen(QPen(QColor("#543D37"), 2))
        painter.drawEllipse(QRectF(-4, 7, 8, 9))
        painter.setBrush(QBrush(QColor("#FFAAAA")))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-2.5, 11, 5, 4))

    def _draw_yawn_face(self, painter: QPainter):
        # 眯眼打哈欠 (> <)
        painter.setPen(QPen(QColor("#543D37"), 3.5, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        painter.drawLine(-25, -12, -13, -6)
        painter.drawLine(-25, 0, -13, -6)
        painter.drawLine(25, -12, 13, -6)
        painter.drawLine(25, 0, 13, -6)

        # 张得大大的椭圆哈欠嘴巴
        painter.setBrush(QBrush(QColor("#C53030")))
        painter.setPen(QPen(QColor("#543D37"), 2.2))
        painter.drawEllipse(QRectF(-11, 4, 22, 17))
        # 小粉舌头
        painter.setBrush(QBrush(QColor("#FFAAAA")))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-7, 12, 14, 8))

    def _draw_wash_face(self, painter: QPainter):
        # 享受洗脸微笑闭眼 (^ ◡ ^)
        painter.setPen(QPen(QColor("#543D37"), 3.2, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        eye_l = QPainterPath()
        eye_l.moveTo(-26, -3)
        eye_l.cubicTo(-20, -12, -14, -12, -8, -3)
        painter.drawPath(eye_l)

        eye_r = QPainterPath()
        eye_r.moveTo(8, -3)
        eye_r.cubicTo(14, -12, 20, -12, 26, -3)
        painter.drawPath(eye_r)

        self._draw_standard_mouth(painter)

    def _draw_dizzy_face(self, painter: QPainter):
        # 眩晕螺旋圆盘眼 (@ @)
        painter.setPen(QPen(QColor("#543D37"), 2.5, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        for cx in [-18, 18]:
            painter.drawEllipse(QRectF(cx - 8, -13, 16, 16))
            painter.drawArc(QRectF(cx - 5, -10, 10, 10), int(self.anim_time * 720) % 5760, 270 * 16)

        # 晕头波浪嘴
        wavy = QPainterPath()
        wavy.moveTo(-10, 10)
        wavy.cubicTo(-5, 6, 0, 14, 10, 9)
        painter.drawPath(wavy)

    def _draw_dozing_face(self, painter: QPainter):
        # 犯困半闭垂落眼皮
        painter.setPen(QPen(QColor("#543D37"), 2.5))
        painter.setBrush(QBrush(QColor("#543D37")))
        painter.drawEllipse(QRectF(-25, -8, 14, 11))
        painter.drawEllipse(QRectF(11, -8, 14, 11))
        painter.setPen(QPen(QColor("#543D37"), 3, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        painter.drawLine(-27, -9, -9, -7)
        painter.drawLine(9, -7, 27, -9)

        # 微微微张的小圆嘴
        painter.setBrush(QBrush(QColor("#D94F4F")))
        painter.setPen(QPen(QColor("#543D37"), 1.8))
        painter.drawEllipse(QRectF(-4, 7, 8, 7))

    def _draw_curious_face(self, painter: QPainter, col_l, col_r):
        gaze_ox = getattr(self, "current_gaze_x", 0.0) * 3.5
        gaze_oy = getattr(self, "current_gaze_y", 0.0) * 2.5
        # 歪头好奇大眼睛 (左眼水汪汪超大，右眼萌眨)
        painter.setPen(QPen(col_l, 1))
        painter.setBrush(QBrush(col_l))
        painter.drawEllipse(QRectF(-29, -17, 20, 24))
        painter.drawEllipse(QRectF(10, -14, 16, 20))

        # 亮闪闪大高光 (随视线微动)
        painter.setBrush(QBrush(QColor(255, 255, 255, 245)))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-26 + gaze_ox, -15 + gaze_oy, 9, 11))
        painter.drawEllipse(QRectF(13 + gaze_ox, -12 + gaze_oy, 7, 9))
        painter.drawEllipse(QRectF(-17 + gaze_ox * 0.5, -4 + gaze_oy * 0.5, 5, 5))

        self._draw_standard_mouth(painter)

    def _draw_hunting_face(self, painter: QPainter, col_l, col_r):
        # 捕鼠专注猎手大瞳仁：瞳孔放大充满好奇与敏捷，眼神紧盯正前方小老鼠
        gaze_ox = 3.5 + getattr(self, "current_gaze_x", 0.0) * 1.5
        gaze_oy = 4.0 + getattr(self, "current_gaze_y", 0.0) * 1.2
        for ex, col in [(-18, col_l), (18, col_r)]:
            # 漆黑大眼眶
            painter.setBrush(QBrush(col.darker(130)))
            painter.setPen(QPen(QColor("#150A06"), 1.8))
            painter.drawEllipse(QRectF(ex - 8, -13, 16, 20))
            # 放大瞳孔 (狩猎专注模式)
            painter.setBrush(QBrush(QColor("#0F172A")))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(QRectF(ex - 6 + gaze_ox * 0.4, -10 + gaze_oy * 0.4, 12, 14))
            # 亮闪高光
            painter.setBrush(QBrush(QColor(255, 255, 255, 250)))
            painter.drawEllipse(QRectF(ex - 4 + gaze_ox * 0.5, -9 + gaze_oy * 0.5, 6, 7))
            painter.drawEllipse(QRectF(ex + 1 + gaze_ox * 0.5, -1 + gaze_oy * 0.5, 3.2, 3.2))

        # 专注可爱的猫咪小口 (:3)
        self._draw_standard_mouth(painter)

    def _draw_playful_face(self, painter: QPainter, col_l, col_r):
        # 玩毛线欢快扑闪大眼睛
        gaze_ox = 2.0 + math.sin(self.anim_time * 4.5) * 2.5
        gaze_oy = 3.0
        for ex, col in [(-18, col_l), (18, col_r)]:
            painter.setBrush(QBrush(col))
            painter.setPen(QPen(QColor("#150A06"), 1.8))
            painter.drawEllipse(QRectF(ex - 8, -13, 16, 20))
            # 晶莹瞳孔
            painter.setBrush(QBrush(QColor("#0F172A")))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(QRectF(ex - 5 + gaze_ox * 0.5, -9 + gaze_oy * 0.4, 10, 13))
            # 双重闪烁星星高光
            painter.setBrush(QBrush(QColor(255, 255, 255, 250)))
            painter.drawEllipse(QRectF(ex - 3 + gaze_ox * 0.6, -8 + gaze_oy * 0.5, 5.5, 6.5))
            painter.drawEllipse(QRectF(ex + 1 + gaze_ox * 0.6, -1 + gaze_oy * 0.5, 3.0, 3.0))

        # 开心微张嘴巴
        mouth = QPainterPath()
        mouth.moveTo(-7, 8)
        mouth.cubicTo(-4, 16, 4, 16, 7, 8)
        mouth.closeSubpath()
        painter.setBrush(QBrush(QColor("#D94F4F")))
        painter.setPen(QPen(QColor("#543D37"), 2.0))
        painter.drawPath(mouth)
        painter.setBrush(QBrush(QColor("#FFAAAA")))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-4, 10, 8, 5))

    def _draw_scurrying_mouse(self, painter: QPainter):
        painter.save()
        # 机械小老鼠在地面欢快穿梭
        mx = 36.0 + math.sin(self.anim_time * 5.0) * 20.0
        my = 44.0 + math.cos(self.anim_time * 10.0) * 1.5
        facing_r = math.cos(self.anim_time * 5.0) >= 0
        painter.translate(mx, my)
        if not facing_r:
            painter.scale(-1.0, 1.0)

        # 地面微阴影
        painter.setBrush(QBrush(QColor(15, 23, 42, 35)))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-16, 6, 32, 8))

        # 摇摆的小细尾巴
        tail_wiggle = math.sin(self.anim_time * 24.0) * 6.0
        tail = QPainterPath()
        tail.moveTo(-14, 1)
        tail.cubicTo(-22, -1, -26, 8 + tail_wiggle, -34, 4 + tail_wiggle)
        painter.setPen(QPen(QColor("#FDA4AF"), 1.8, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawPath(tail)

        # 小老鼠身体 (圆润水滴形)
        body = QPainterPath()
        body.moveTo(14, 2)
        body.cubicTo(8, -9, -10, -11, -14, 0)
        body.cubicTo(-16, 8, -4, 11, 14, 2)
        body.closeSubpath()
        m_grad = QLinearGradient(-14, -8, 12, 8)
        m_grad.setColorAt(0.0, QColor("#CBD5E1"))
        m_grad.setColorAt(0.65, QColor("#94A3B8"))
        m_grad.setColorAt(1.0, QColor("#64748B"))
        painter.setBrush(QBrush(m_grad))
        painter.setPen(QPen(QColor("#475569"), 1.6))
        painter.drawPath(body)

        # 粉嫩双耳
        painter.setBrush(QBrush(QColor("#FDA4AF")))
        painter.setPen(QPen(QColor("#CBD5E1"), 1.2))
        painter.drawEllipse(QRectF(-6, -12, 9, 11))
        painter.drawEllipse(QRectF(-1, -14, 10, 12))
        painter.setBrush(QBrush(QColor("#FB7185")))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-4, -10, 5, 7))
        painter.drawEllipse(QRectF(1, -12, 6, 8))

        # 黑亮小眼睛
        painter.setBrush(QBrush(QColor("#0F172A")))
        painter.drawEllipse(QRectF(6, -3, 3.8, 3.8))
        painter.setBrush(QBrush(QColor("#FFFFFF")))
        painter.drawEllipse(QRectF(7, -2.5, 1.5, 1.5))

        # 粉鼻头与胡须
        painter.setBrush(QBrush(QColor("#F43F5E")))
        painter.drawEllipse(QRectF(13, 0.5, 3.0, 3.0))
        painter.setPen(QPen(QColor("#64748B"), 1.0, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        painter.drawLine(12, 1, 20, -2)
        painter.drawLine(12, 3, 19, 5)

        # 背上旋转金色发条旋钮
        key_rot = (self.anim_time * 360.0) % 360
        painter.save()
        painter.translate(-6, -9)
        painter.rotate(key_rot)
        painter.setPen(QPen(QColor("#D97706"), 1.8))
        painter.setBrush(QBrush(QColor("#FCD34D")))
        painter.drawLine(0, 4, 0, -4)
        painter.drawEllipse(QRectF(-4, -8, 8, 7))
        painter.restore()

        painter.restore()

    def _draw_bouncing_yarn(self, painter: QPainter):
        painter.save()
        # 毛线球在猫爪前滚动弹跳
        ball_x = 24.0 + math.sin(self.anim_time * 4.5) * 18.0
        ball_y = 38.0 - abs(math.sin(self.anim_time * 9.0)) * 12.0
        ball_rot = (self.anim_time * 240.0) % 360

        # 地面动态投影 (随弹跳高度缩放与淡化)
        jump_norm = min(1.0, (38.0 - ball_y) / 12.0)
        shadow_w = 32.0 * (1.0 - jump_norm * 0.3)
        shadow_alpha = int(45 * (1.0 - jump_norm * 0.45))
        painter.setBrush(QBrush(QColor(15, 23, 42, shadow_alpha)))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(ball_x - shadow_w / 2.0, 46, shadow_w, 8))

        # 散开的毛线尾巴 (灵动曲线随球滚动飘舞，带自然卷曲小圈)
        tail_wave = math.sin(self.anim_time * 8.0) * 4.0
        thread = QPainterPath()
        thread.moveTo(ball_x - 6, ball_y + 6)
        thread.cubicTo(ball_x - 20, ball_y + 12, ball_x - 28, 48 + tail_wave, -20, 43)
        thread.cubicTo(-28, 41, -34, 46, -28, 48)
        painter.setPen(QPen(QColor("#F43F5E"), 2.4, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawPath(thread)

        # 毛线球本体 (旋转与 3D 渐变)
        painter.translate(ball_x, ball_y)
        painter.rotate(ball_rot)
        ball_rad = 16.0
        y_grad = QRadialGradient(-5, -5, ball_rad * 1.3)
        y_grad.setColorAt(0.0, QColor("#FDA4AF"))
        y_grad.setColorAt(0.5, QColor("#F43F5E"))
        y_grad.setColorAt(0.85, QColor("#E11D48"))
        y_grad.setColorAt(1.0, QColor("#9F1239"))
        painter.setBrush(QBrush(y_grad))
        painter.setPen(QPen(QColor("#881337"), 1.8))
        painter.drawEllipse(QRectF(-ball_rad, -ball_rad, ball_rad * 2, ball_rad * 2))

        # 毛线球交叉缠绕线纹
        painter.setPen(QPen(QColor("#FFE4E6"), 1.8, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        arc1 = QPainterPath()
        arc1.arcMoveTo(-13, -13, 26, 26, 40)
        arc1.arcTo(-13, -13, 26, 26, 40, 110)
        painter.drawPath(arc1)

        painter.setPen(QPen(QColor("#9F1239"), 1.8, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        arc2 = QPainterPath()
        arc2.arcMoveTo(-14, -10, 28, 20, 190)
        arc2.arcTo(-14, -10, 28, 20, 190, 120)
        painter.drawPath(arc2)

        # 毛线绒毛小结
        painter.setBrush(QBrush(QColor("#FDA4AF")))
        painter.setPen(QPen(QColor("#E11D48"), 1.2))
        painter.drawEllipse(QRectF(3, -13, 5, 5))

        painter.restore()

    def _draw_cardboard_box(self, painter: QPainter):
        """纸箱藏猫猫：牛皮纸箱、折叠翻盖、专属封箱胶带与侧边摇曳的小尾巴"""
        painter.save()
        box_w = 118.0
        box_h = 56.0
        box_x = -box_w / 2.0
        box_y = -1.0  # 挡住胸口与四肢，让猫猫头与大眼睛探在箱沿上方

        # 1. 纸箱正面外轮廓与牛皮纸质感双色渐变
        box_rect = QRectF(box_x, box_y, box_w, box_h)
        box_grad = QLinearGradient(box_x, box_y, box_x + box_w, box_y + box_h)
        box_grad.setColorAt(0.0, QColor("#DDB892"))
        box_grad.setColorAt(0.45, QColor("#B08968"))
        box_grad.setColorAt(1.0, QColor("#7F5539"))
        painter.setBrush(QBrush(box_grad))
        painter.setPen(QPen(QColor("#543D37"), 2.2))
        painter.drawRoundedRect(box_rect, 7, 7)

        # 2. 纸箱左右展开折边 (Flaps)
        flap_l = QPainterPath()
        flap_l.moveTo(box_x, box_y)
        flap_l.lineTo(box_x - 16, box_y - 12)
        flap_l.lineTo(box_x - 11, box_y + 14)
        flap_l.lineTo(box_x, box_y + 10)
        flap_l.closeSubpath()
        painter.setBrush(QBrush(QColor("#CDB08F")))
        painter.setPen(QPen(QColor("#543D37"), 1.8))
        painter.drawPath(flap_l)

        flap_r = QPainterPath()
        flap_r.moveTo(box_x + box_w, box_y)
        flap_r.lineTo(box_x + box_w + 16, box_y - 12)
        flap_r.lineTo(box_x + box_w + 11, box_y + 14)
        flap_r.lineTo(box_x + box_w, box_y + 10)
        flap_r.closeSubpath()
        painter.drawPath(flap_r)

        # 前侧下翻折边 (悬挂在箱子正面上方)
        flap_front = QPainterPath()
        flap_front.moveTo(box_x + 8, box_y)
        flap_front.lineTo(box_x + box_w - 8, box_y)
        flap_front.lineTo(box_x + box_w - 14, box_y + 15)
        flap_front.lineTo(box_x + 14, box_y + 15)
        flap_front.closeSubpath()
        painter.setBrush(QBrush(QColor("#E6CCB2")))
        painter.setPen(QPen(QColor("#543D37"), 1.8))
        painter.drawPath(flap_front)

        # 3. 封箱胶带贴纸与可爱印章
        tape_rect = QRectF(box_x + 30, box_y + 18, 58, 15)
        painter.setBrush(QBrush(QColor("#FFFBEB")))
        painter.setPen(QPen(QColor("#F59E0B"), 1.0))
        painter.drawRoundedRect(tape_rect, 3, 3)

        painter.setFont(QFont("Microsoft YaHei UI", 7, QFont.Weight.Bold))
        painter.setPen(QPen(QColor("#78350F")))
        painter.drawText(tape_rect, Qt.AlignmentFlag.AlignCenter, "📦 波可专递 🐾")

        # 易碎标记与向上箭头
        painter.setFont(QFont("Segoe UI Emoji", 7))
        painter.setPen(QPen(QColor("#451A03")))
        painter.drawText(int(box_x + 10), int(box_y + 44), "↑↑ FRAGILE")

        # 4. 挂在箱沿前方的两只萌萌小肉垫爪子
        paw_y = box_y + 3
        for px in [-24, 24]:
            painter.setBrush(QBrush(QColor("#FFF9F2")))
            painter.setPen(QPen(QColor("#543D37"), 2.0))
            paw = QPainterPath()
            paw.addRoundedRect(QRectF(px - 10, paw_y - 6, 20, 14), 7, 7)
            painter.drawPath(paw)
            painter.setBrush(QBrush(QColor("#FFAAAA")))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(QRectF(px - 6, paw_y + 1, 4, 3))
            painter.drawEllipse(QRectF(px + 2, paw_y + 1, 4, 3))
            painter.drawEllipse(QRectF(px - 2, paw_y + 2, 4, 3))

        # 5. 箱子侧边圆孔伸出的欢畅摆动尾巴
        tail_angle = math.sin(self.anim_time * 6.0) * 16.0
        painter.save()
        painter.translate(box_x + box_w - 4, box_y + 36)
        painter.rotate(tail_angle)
        # 纸箱通风小孔
        painter.setBrush(QBrush(QColor("#3E200C")))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-6, -6, 12, 12))
        # 钻出来晃动的尾巴尖
        tail_path = QPainterPath()
        tail_path.moveTo(0, 0)
        tail_path.cubicTo(12, -4, 20, -18, 26, -26)
        tail_path.cubicTo(20, -22, 12, -14, 0, 4)
        tail_path.closeSubpath()
        painter.setBrush(QBrush(QColor("#E76F51")))
        painter.setPen(QPen(QColor("#543D37"), 1.8))
        painter.drawPath(tail_path)
        painter.restore()

        painter.restore()


    def _draw_butterfly(self, painter: QPainter):
        painter.save()
        bf_x = math.cos(self.anim_time * 3.5) * 62.0
        bf_y = -35.0 + math.sin(self.anim_time * 7.0) * 20.0
        painter.translate(bf_x, bf_y)
        wing_flap = math.sin(self.anim_time * 26.0)
        painter.scale(wing_flap, 1.0)
        painter.setBrush(QBrush(QColor("#38BDF8")))
        painter.setPen(QPen(QColor("#0284C7"), 1.2))
        painter.drawEllipse(QRectF(-12, -14, 12, 14))
        painter.drawEllipse(QRectF(0, -14, 12, 14))
        painter.drawEllipse(QRectF(-9, 0, 9, 10))
        painter.drawEllipse(QRectF(0, 0, 9, 10))
        painter.setBrush(QBrush(QColor("#0F172A")))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-2, -8, 4, 16))
        painter.restore()

    def _draw_headphones(self, painter: QPainter):
        painter.save()
        painter.setPen(QPen(QColor("#3B82F6"), 5, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawArc(QRectF(-44, -58, 88, 56), 25 * 16, 130 * 16)
        painter.setBrush(QBrush(QColor("#1D4ED8")))
        painter.setPen(QPen(QColor("#60A5FA"), 2))
        painter.drawRoundedRect(QRectF(-50, -22, 14, 26), 7, 7)
        painter.drawRoundedRect(QRectF(36, -22, 14, 26), 7, 7)
        painter.setBrush(QBrush(QColor("#93C5FD")))
        painter.drawEllipse(QRectF(-47, -13, 8, 8))
        painter.drawEllipse(QRectF(39, -13, 8, 8))
        painter.restore()

    def _draw_dizzy_stars(self, painter: QPainter):
        painter.save()
        for i in range(3):
            star_angle = self.anim_time * 7.0 + i * (math.pi * 2 / 3)
            sx = math.cos(star_angle) * 36.0
            sy = -55.0 + math.sin(star_angle) * 12.0
            painter.save()
            painter.translate(sx, sy)
            painter.setBrush(QBrush(QColor("#FBBF24")))
            painter.setPen(QPen(QColor("#D97706"), 1))
            s = 7
            star = QPainterPath()
            star.moveTo(0, -s)
            star.lineTo(s * 0.3, -s * 0.3)
            star.lineTo(s, 0)
            star.lineTo(s * 0.3, s * 0.3)
            star.lineTo(0, s)
            star.lineTo(-s * 0.3, s * 0.3)
            star.lineTo(-s, 0)
            star.lineTo(-s * 0.3, -s * 0.3)
            star.closeSubpath()
            painter.drawPath(star)
            painter.restore()
        painter.restore()

    def _draw_sleeping_face(self, painter: QPainter):
        painter.setPen(QPen(QColor("#543D37"), 3, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        eye_left = QPainterPath()
        eye_left.moveTo(-28, -6)
        eye_left.cubicTo(-22, 2, -14, 2, -8, -6)
        painter.drawPath(eye_left)

        eye_right = QPainterPath()
        eye_right.moveTo(8, -6)
        eye_right.cubicTo(14, 2, 22, 2, 28, -6)
        painter.drawPath(eye_right)
        painter.drawArc(QRectF(-5, 8, 10, 8), 0, -180 * 16)

    def _draw_happy_face(self, painter: QPainter):
        painter.setPen(QPen(QColor("#543D37"), 3.5, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        eye_l = QPainterPath()
        eye_l.moveTo(-28, -2)
        eye_l.cubicTo(-22, -14, -14, -14, -8, -2)
        painter.drawPath(eye_l)

        eye_r = QPainterPath()
        eye_r.moveTo(8, -2)
        eye_r.cubicTo(14, -14, 22, -14, 28, -2)
        painter.drawPath(eye_r)

        mouth = QPainterPath()
        mouth.moveTo(-10, 8)
        mouth.cubicTo(-5, 20, 5, 20, 10, 8)
        mouth.closeSubpath()
        painter.setBrush(QBrush(QColor("#D94F4F")))
        painter.setPen(QPen(QColor("#543D37"), 2.5))
        painter.drawPath(mouth)
        painter.setBrush(QBrush(QColor("#FFAAAA")))
        painter.drawEllipse(QRectF(-6, 12, 12, 7))

    def _draw_blinking_eyes(self, painter: QPainter):
        painter.setPen(QPen(QColor("#543D37"), 3.2, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        left_eye = QPainterPath()
        left_eye.moveTo(-28, -3)
        left_eye.cubicTo(-23, -0.5, -14, -0.5, -9, -3)
        painter.drawPath(left_eye)
        right_eye = QPainterPath()
        right_eye.moveTo(9, -3)
        right_eye.cubicTo(14, -0.5, 23, -0.5, 28, -3)
        painter.drawPath(right_eye)

    def _draw_normal_eyes(self, painter: QPainter, col_l: QColor, col_r: QColor):
        # 幼年期眼睛更大更萌
        eye_w, eye_h = (18, 23) if self.model.stage == "BABY" else (16, 21)

        # 眼神视线追踪光标微动偏移 (范围：X轴 ±3.8px，Y轴 ±2.8px)
        gaze_ox = getattr(self, "current_gaze_x", 0.0) * 3.8
        gaze_oy = getattr(self, "current_gaze_y", 0.0) * 2.8

        # 动态瞳孔放大因子 (靠近/好奇/抚摸时放大瞳孔至软萌黑曜石状态)
        dil = getattr(self, "current_pupil_dilation", 0.0)
        pupil_ratio_w = 0.58 + dil * 0.28
        pupil_ratio_h = 0.65 + dil * 0.23

        for ex, col in [(-19, col_l), (19, col_r)]:
            eye_rect = QRectF(ex - eye_w / 2.0, -15, eye_w, eye_h)

            # 3D 琉璃眼眶渐变 (外轮廓眼眶保持头部原生位置)
            e_grad = QLinearGradient(ex, -15, ex, 6)
            e_grad.setColorAt(0.0, QColor("#1A0C08"))
            e_grad.setColorAt(0.5, col.darker(115))
            e_grad.setColorAt(1.0, col.lighter(135))
            painter.setBrush(QBrush(e_grad))
            painter.setPen(QPen(QColor("#150A06"), 1.2))
            painter.drawEllipse(eye_rect)

            # 内部深色瞳孔 (随眼神注视焦点平滑移动，随动态放大因子平滑膨胀)
            pupil_w, pupil_h = eye_w * pupil_ratio_w, eye_h * pupil_ratio_h
            pupil_rect = QRectF(ex - pupil_w / 2.0 + gaze_ox, -13 + gaze_oy, pupil_w, pupil_h)
            painter.setBrush(QBrush(QColor("#110805")))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(pupil_rect)

            # 下眼眶琉璃月牙光泽 (Caustic Glow，随虹膜微偏)
            iris_glow = QPainterPath()
            iris_glow.addEllipse(QRectF(ex - eye_w / 2.0 + 2 + gaze_ox * 0.35, -5 + gaze_oy * 0.35, eye_w - 4, 9))
            g_iris = QLinearGradient(ex, -5, ex, 5)
            g_iris.setColorAt(0.0, QColor(255, 255, 255, 0))
            g_iris.setColorAt(1.0, QColor(col.red(), col.green(), col.blue(), 165))
            painter.setBrush(QBrush(g_iris))
            painter.drawPath(iris_glow)

            # 璀璨星芒高光 (主大高光随角膜光照微偏，次高光跟随瞳孔形成真实晶状体视差)
            painter.setBrush(QBrush(QColor(255, 255, 255, 250)))
            painter.drawEllipse(QRectF(ex - 6.5 + gaze_ox * 0.25, -13 + gaze_oy * 0.25, 6.5, 9.0))
            painter.drawEllipse(QRectF(ex + 1.5 + gaze_ox * 0.7, -4.5 + gaze_oy * 0.7, 3.8, 3.8))
            painter.setBrush(QBrush(QColor(255, 255, 255, 180)))
            painter.drawEllipse(QRectF(ex - 4 + gaze_ox * 0.5, 1 + gaze_oy * 0.5, 2.5, 2.5))

            # 瞳孔放大时额外渲染萌系微闪钻石星芒 (Anime Kitten Eye Sparkle)
            if dil > 0.35:
                sparkle_alpha = int(min(255, (dil - 0.35) / 0.65 * 240))
                painter.setBrush(QBrush(QColor(255, 255, 255, sparkle_alpha)))
                sx = ex - 1.0 + gaze_ox * 0.75
                sy = -7.5 + gaze_oy * 0.75
                star_path = QPainterPath()
                star_path.moveTo(sx, sy - 2.8)
                star_path.lineTo(sx + 0.9, sy - 0.9)
                star_path.lineTo(sx + 2.8, sy)
                star_path.lineTo(sx + 0.9, sy + 0.9)
                star_path.lineTo(sx, sy + 2.8)
                star_path.lineTo(sx - 0.9, sy + 0.9)
                star_path.lineTo(sx - 2.8, sy)
                star_path.lineTo(sx - 0.9, sy - 0.9)
                star_path.closeSubpath()
                painter.drawPath(star_path)

    def _draw_standard_mouth(self, painter: QPainter):
        is_dark_skin = getattr(self.model, "skin_id", "") in ("cat_black", "dog_black")
        nose_col = QColor("#E8A0A0") if is_dark_skin else QColor("#FFA5A5")
        mouth_col = QColor("#9B8E85") if is_dark_skin else QColor("#543D37")

        painter.setBrush(QBrush(nose_col))
        painter.setPen(Qt.PenStyle.NoPen)
        nose = QPolygonF([QPointF(-3, 2), QPointF(3, 2), QPointF(0, 5)])
        painter.drawPolygon(nose)

        painter.setPen(QPen(mouth_col, 2.2, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        mouth = QPainterPath()
        mouth.moveTo(-9, 7)
        mouth.cubicTo(-5, 11, -1, 11, 0, 7)
        mouth.cubicTo(1, 11, 5, 11, 9, 7)
        painter.drawPath(mouth)

    # ================= 多插槽装扮渲染 =================
    def _draw_head_decorations(self, painter: QPainter, spin_info=None):
        head = self.model.decorations.get("head", "none")
        if head == "none" and getattr(self.model, "personality", "") != "ATHLETE":
            return

        is_spin = bool(spin_info and spin_info.get("is_spin", False))
        sin_a = spin_info.get("sin_a", 0.0) if is_spin else 0.0
        head_shift = sin_a * 10.0 if is_spin else 0.0

        painter.save()
        if is_spin:
            painter.translate(head_shift, 0)

        if head == "hat_wizard":
            # 魔法尖帽
            painter.save()
            painter.translate(0, -48)
            hat_brim = QPainterPath()
            hat_brim.moveTo(-45, 0)
            hat_brim.cubicTo(-20, 6, 20, 6, 45, 0)
            painter.setPen(QPen(QColor("#432E6A"), 7, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
            painter.drawPath(hat_brim)

            hat_cone = QPainterPath()
            hat_cone.moveTo(-30, -1)
            hat_cone.cubicTo(-10, -40, 5, -55, 25, -60)
            hat_cone.lineTo(15, -30)
            hat_cone.lineTo(30, -1)
            hat_cone.closeSubpath()
            painter.setBrush(QBrush(QColor("#5D3FD3")))
            painter.setPen(QPen(QColor("#3A2578"), 2))
            painter.drawPath(hat_cone)
            painter.setBrush(QBrush(QColor("#FFD700")))
            painter.drawRect(QRectF(-26, -9, 52, 7))
            painter.restore()

        elif head == "hat_party":
            # 派对生日帽
            painter.save()
            painter.translate(0, -50)
            cone = QPainterPath()
            cone.moveTo(-22, 0)
            cone.lineTo(0, -48)
            cone.lineTo(22, 0)
            cone.closeSubpath()
            painter.setBrush(QBrush(QColor("#EC4899")))
            painter.setPen(QPen(QColor("#BE185D"), 2))
            painter.drawPath(cone)
            # 顶端小绒球
            painter.setBrush(QBrush(QColor("#FBBF24")))
            painter.drawEllipse(QRectF(-7, -55, 14, 14))
            painter.restore()

        elif head == "halo":
            # 金色天使光环 (浮动)
            painter.save()
            halo_y = -68 + math.sin(self.anim_time * 3.0) * 3.0
            painter.setPen(QPen(QColor("#F59E0B"), 4))
            painter.setBrush(QBrush(QColor(255, 255, 255, 70)))
            painter.drawEllipse(QRectF(-32, halo_y, 64, 16))
            painter.restore()

        elif head == "horns":
            # 红色小恶魔角
            painter.save()
            painter.setBrush(QBrush(QColor("#DC2626")))
            painter.setPen(QPen(QColor("#991B1B"), 2))
            # 左角
            horn_l = QPainterPath()
            horn_l.moveTo(-30, -42)
            horn_l.cubicTo(-48, -55, -45, -75, -32, -70)
            horn_l.cubicTo(-25, -60, -22, -48, -20, -42)
            painter.drawPath(horn_l)
            # 右角
            horn_r = QPainterPath()
            horn_r.moveTo(30, -42)
            horn_r.cubicTo(48, -55, 45, -75, 32, -70)
            horn_r.cubicTo(25, -60, 22, -48, 20, -42)
            painter.drawPath(horn_r)
            painter.restore()

        elif head == "crown":
            # 黄金王冠
            painter.save()
            painter.translate(0, -52)
            crown = QPainterPath()
            crown.moveTo(-26, 0)
            crown.lineTo(-28, -22)
            crown.lineTo(-14, -10)
            crown.lineTo(0, -26)
            crown.lineTo(14, -10)
            crown.lineTo(28, -22)
            crown.lineTo(26, 0)
            crown.closeSubpath()
            painter.setBrush(QBrush(QColor("#F59E0B")))
            painter.setPen(QPen(QColor("#B45309"), 2))
            painter.drawPath(crown)
            # 宝石
            painter.setBrush(QBrush(QColor("#EF4444")))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(QRectF(-4, -12, 8, 8))
            painter.restore()

        elif head == "chef":
            # 厨师高帽
            painter.save()
            painter.translate(0, -50)
            painter.setBrush(QBrush(QColor("#FFFFFF")))
            painter.setPen(QPen(QColor("#D1D5DB"), 2))
            painter.drawRect(QRectF(-24, -10, 48, 14))
            painter.drawEllipse(QRectF(-32, -35, 30, 30))
            painter.drawEllipse(QRectF(-12, -42, 24, 28))
            painter.drawEllipse(QRectF(2, -35, 30, 30))
            painter.restore()

        elif head == "band_sport" or (head == "none" and getattr(self.model, "personality", "") == "ATHLETE"):
            # 元气运动喵专属：热血运动发带 (额前绑带 + 飘逸绑带尾巴 + 烈焰金星徽章)
            painter.save()
            painter.translate(0, -32)
            # 主系带 (弧形紧贴头部额顶)
            band_path = QPainterPath()
            band_path.moveTo(-36, -3)
            band_path.cubicTo(-18, 5, 18, 5, 36, -3)
            band_path.lineTo(34, 4)
            band_path.cubicTo(18, 11, -18, 11, -34, 4)
            band_path.closeSubpath()
            painter.setBrush(QBrush(QColor("#EF4444")))
            painter.setPen(QPen(QColor("#991B1B"), 1.8))
            painter.drawPath(band_path)

            # 白色元气运动条纹
            stripe = QPainterPath()
            stripe.moveTo(-30, 0)
            stripe.cubicTo(-15, 6, 15, 6, 30, 0)
            painter.setPen(QPen(QColor("#FFFFFF"), 2.0))
            painter.drawPath(stripe)

            # 右侧飘动的两条系带尾巴
            tail_wave = math.sin(self.anim_time * 8.0) * 4.0
            tail_path = QPainterPath()
            tail_path.moveTo(34, 2)
            tail_path.cubicTo(45, 6 + tail_wave, 52, 16 + tail_wave * 1.5, 48, 26 + tail_wave)
            tail_path.lineTo(44, 24 + tail_wave)
            tail_path.cubicTo(46, 15 + tail_wave * 1.2, 40, 8 + tail_wave, 33, 4)
            tail_path.closeSubpath()
            painter.setBrush(QBrush(QColor("#DC2626")))
            painter.setPen(QPen(QColor("#991B1B"), 1.5))
            painter.drawPath(tail_path)

            # 额头正中心闪耀运动徽章
            painter.setBrush(QBrush(QColor("#FBBF24")))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(QRectF(-4, 2, 8, 8))
            painter.restore()

        painter.restore()

    def _draw_face_decorations(self, painter: QPainter, spin_info=None):
        face = self.model.decorations.get("face", "none")
        if face == "none" and not self.model.is_studying and getattr(self.model, "personality", "") != "HACKER":
            return

        is_spin = bool(spin_info and spin_info.get("is_spin", False))
        if is_spin:
            # 3D 旋转时：若为背部视角，五官/眼镜等面饰自然隐藏
            if not spin_info.get("is_front", True):
                return
            painter.save()
            face_offset_x = spin_info.get("face_offset_x", 0.0)
            cos_a = spin_info.get("cos_a", 1.0)
            painter.translate(face_offset_x, 0)
            painter.scale(cos_a, 1.0)
        else:
            painter.save()

        if face == "glasses" or self.model.is_studying:
            # 博士金丝圆眼镜
            painter.setPen(QPen(QColor("#F0B429"), 2.5))
            painter.setBrush(QBrush(QColor(255, 255, 255, 60)))
            painter.drawEllipse(QRectF(-31, -18, 24, 24))
            painter.drawEllipse(QRectF(7, -18, 24, 24))
            painter.drawLine(-7, -6, 7, -6)

        elif face == "sunglasses":
            # 酷炫黑超墨镜
            painter.save()
            painter.setBrush(QBrush(QColor("#111827")))
            painter.setPen(QPen(QColor("#374151"), 2))
            painter.drawRoundedRect(QRectF(-34, -18, 28, 20), 4, 4)
            painter.drawRoundedRect(QRectF(6, -18, 28, 20), 4, 4)
            painter.drawLine(-6, -8, 6, -8)
            # 墨镜白色高光斜杠
            painter.setPen(QPen(QColor(255, 255, 255, 180), 2))
            painter.drawLine(-28, -14, -18, -4)
            painter.drawLine(12, -14, 22, -4)
            painter.restore()

        elif face == "hacker_viser" or (face == "none" and getattr(self.model, "personality", "") == "HACKER"):
            # 极客黑客喵专属：赛博全息发光战术目镜 (右眼 HUD 扫描目镜与战术数据流)
            painter.save()
            viser_rect = QRectF(5, -20, 30, 22)
            painter.setBrush(QBrush(QColor(14, 165, 233, 95)))
            painter.setPen(QPen(QColor("#38BDF8"), 2.2))
            painter.drawRoundedRect(viser_rect, 4, 4)

            # 耳侧高科技固定臂
            painter.setPen(QPen(QColor("#0284C7"), 2.5))
            painter.drawLine(35, -9, 46, -14)

            # 目镜内部战术十字准星与刻度
            painter.setPen(QPen(QColor("#34D399"), 1.2))
            painter.drawLine(16, -9, 24, -9)
            painter.drawLine(20, -13, 20, -5)

            # 目镜右上角动态扫描闪烁绿点
            if int(self.anim_time * 4) % 2 == 0:
                painter.setBrush(QBrush(QColor("#10B981")))
                painter.setPen(Qt.PenStyle.NoPen)
                painter.drawEllipse(QRectF(28, -17, 4, 4))
            painter.restore()

        elif face == "blush_hearts":
            # 心动爱心面贴
            painter.save()
            for hx in [-35, 35]:
                painter.save()
                painter.translate(hx, 10)
                heart = QPainterPath()
                s = 7
                heart.moveTo(0, s * 0.3)
                heart.cubicTo(-s, -s * 0.5, -s * 1.5, s * 0.3, 0, s * 1.4)
                heart.cubicTo(s * 1.5, s * 0.3, s, -s * 0.5, 0, s * 0.3)
                painter.setBrush(QBrush(QColor("#FF4D6D")))
                painter.setPen(Qt.PenStyle.NoPen)
                painter.drawPath(heart)
                painter.restore()
            painter.restore()

        painter.restore()

    def _draw_neck_decorations(self, painter: QPainter, spin_info=None):
        neck = self.model.decorations.get("neck", "none")
        if neck == "none":
            return

        is_spin = bool(spin_info and spin_info.get("is_spin", False))
        is_front = spin_info.get("is_front", True) if is_spin else True
        sin_a = spin_info.get("sin_a", 0.0) if is_spin else 0.0
        cos_a = spin_info.get("cos_a", 1.0) if is_spin else 1.0
        neck_shift = sin_a * 10.0 if is_spin else 0.0

        if not is_front:
            # 背面视角：展现后颈部的项圈皮带/系带扣或围巾后披，立体感拉满
            painter.save()
            painter.translate(-neck_shift * 0.8, 34)
            if neck in ("bow", "bell", "tie"):
                # 后颈项圈系带 (带小暗扣或系带结)
                strap_col = QColor("#B31237") if neck == "bow" else (QColor("#B45309") if neck == "bell" else QColor("#0F172A"))
                painter.setPen(QPen(strap_col, 4, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
                painter.drawLine(-22, 0, 22, 0)
                # 后背小搭扣
                painter.setBrush(QBrush(QColor("#FFD700") if neck != "tie" else QColor("#94A3B8")))
                painter.setPen(Qt.PenStyle.NoPen)
                painter.drawRoundedRect(QRectF(-4, -4, 8, 8), 2, 2)
            elif neck == "scarf":
                # 围巾后脑勺包裹与垂落后背小尾端
                scarf_back = QPainterPath()
                scarf_back.moveTo(-32, -4)
                scarf_back.cubicTo(-15, 6, 15, 6, 32, -4)
                scarf_back.lineTo(26, 8)
                scarf_back.cubicTo(12, 16, -12, 16, -26, 8)
                scarf_back.closeSubpath()
                painter.setBrush(QBrush(QColor("#B91C1C")))
                painter.setPen(QPen(QColor("#7F1D1D"), 2))
                painter.drawPath(scarf_back)
                # 围巾下垂后尾
                tail_scarf = QPolygonF([QPointF(-8, 6), QPointF(6, 6), QPointF(2, 26), QPointF(-12, 26)])
                painter.setBrush(QBrush(QColor("#DC2626")))
                painter.setPen(QPen(QColor("#991B1B"), 1.8))
                painter.drawPolygon(tail_scarf)
            painter.restore()
            return

        # 正面视角：带 3D 旋转透视与位移
        painter.save()
        if is_spin:
            painter.translate(neck_shift, 0)
            painter.scale(cos_a, 1.0)

        if neck == "bow":
            # 红色大蝴蝶结
            painter.save()
            painter.translate(0, 36)
            painter.setBrush(QBrush(QColor("#FF4D6D")))
            painter.setPen(QPen(QColor("#B31237"), 2))
            left_wing = QPolygonF([QPointF(0, 0), QPointF(-18, -10), QPointF(-18, 10)])
            right_wing = QPolygonF([QPointF(0, 0), QPointF(18, -10), QPointF(18, 10)])
            painter.drawPolygon(left_wing)
            painter.drawPolygon(right_wing)
            painter.setBrush(QBrush(QColor("#FFF0F3")))
            painter.drawEllipse(QRectF(-6, -6, 12, 12))
            painter.restore()

        elif neck == "scarf":
            # 英伦暖冬围巾
            painter.save()
            scarf_path = QPainterPath()
            scarf_path.moveTo(-42, 32)
            scarf_path.cubicTo(-20, 46, 20, 46, 42, 32)
            scarf_path.lineTo(36, 46)
            scarf_path.cubicTo(18, 56, -18, 56, -36, 46)
            scarf_path.closeSubpath()
            painter.setBrush(QBrush(QColor("#DC2626")))
            painter.setPen(QPen(QColor("#991B1B"), 2))
            painter.drawPath(scarf_path)
            # 下垂小飘带
            painter.drawRoundedRect(QRectF(12, 44, 14, 26), 3, 3)
            painter.restore()

        elif neck == "bell":
            # 招财金色挂铃
            painter.save()
            painter.translate(0, 38)
            painter.setBrush(QBrush(QColor("#FBBF24")))
            painter.setPen(QPen(QColor("#B45309"), 2))
            painter.drawEllipse(QRectF(-8, -4, 16, 16))
            painter.setBrush(QBrush(QColor("#78350F")))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(QRectF(-3, 3, 6, 6))
            painter.restore()

        elif neck == "tie":
            # 绅士黑红领结
            painter.save()
            painter.translate(0, 36)
            painter.setBrush(QBrush(QColor("#1E293B")))
            painter.setPen(QPen(QColor("#0F172A"), 1.5))
            painter.drawPolygon(QPolygonF([QPointF(0, 0), QPointF(-14, -8), QPointF(-14, 8)]))
            painter.drawPolygon(QPolygonF([QPointF(0, 0), QPointF(14, -8), QPointF(14, 8)]))
            painter.setBrush(QBrush(QColor("#DC2626")))
            painter.drawEllipse(QRectF(-4, -4, 8, 8))
            painter.restore()

        painter.restore()

    def _draw_hand_decorations(self, painter: QPainter, spin_info=None):
        hand = self.model.decorations.get("hand", "none")
        if hand == "none":
            return

        is_spin = bool(spin_info and spin_info.get("is_spin", False))
        if is_spin and not spin_info.get("is_front", True):
            return

        painter.save()
        if is_spin:
            face_offset_x = spin_info.get("face_offset_x", 0.0) * 0.6
            painter.translate(face_offset_x, 0)

        if hand == "keyboard":
            # 赛博 RGB 机械键盘 (双爪捧在胸前，微型按键彩虹发光)
            key_y = 36 + math.sin(self.anim_time * 14.0) * 1.5
            painter.save()
            painter.translate(0, key_y)

            painter.setBrush(QBrush(QColor("#0F172A")))
            painter.setPen(QPen(QColor("#38BDF8"), 1.8))
            painter.drawRoundedRect(QRectF(-25, 0, 50, 17), 3, 3)

            kb_grad = QLinearGradient(-22, 0, 22, 0)
            kb_grad.setColorAt(0.0, QColor("#06B6D4"))
            kb_grad.setColorAt(0.5, QColor("#EC4899"))
            kb_grad.setColorAt(1.0, QColor("#FBBF24"))
            painter.setPen(QPen(kb_grad, 1.2))
            painter.drawLine(-22, 14, 22, 14)

            key_cols = [QColor("#38BDF8"), QColor("#34D399"), QColor("#F472B6"), QColor("#FBBF24"), QColor("#A78BFA")]
            for r in range(2):
                ky = 3 + r * 5
                for c in range(5):
                    kx = -20 + c * 8
                    col = key_cols[(c + r + int(self.anim_time * 6)) % len(key_cols)]
                    painter.setBrush(QBrush(col))
                    painter.setPen(Qt.PenStyle.NoPen)
                    painter.drawRect(QRectF(kx, ky, 6, 4))
            painter.restore()

        elif hand == "fish_wand":
            # 全息光纤逗猫棒 (由右爪握持，前端摆动着全息激光小鱼)
            sway = math.sin(self.anim_time * 6.0) * 7.0
            painter.save()
            painter.setPen(QPen(QColor("#0284C7"), 2.2, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
            painter.drawLine(18, 44, 45, 12)

            tip_x = 45
            tip_y = 12
            fish_x = 42 + sway
            fish_y = 30 + abs(sway * 0.3)
            painter.setPen(QPen(QColor("#38BDF8"), 1.2, Qt.PenStyle.DashLine))
            painter.drawLine(tip_x, tip_y, int(fish_x), int(fish_y))

            painter.save()
            painter.translate(fish_x, fish_y)
            painter.rotate(sway * 1.8)
            fish_path = QPainterPath()
            fish_path.moveTo(-8, 0)
            fish_path.cubicTo(-4, -5, 2, -5, 6, 0)
            fish_path.cubicTo(2, 5, -4, 5, -8, 0)
            fish_path.lineTo(-12, -4)
            fish_path.lineTo(-12, 4)
            fish_path.closeSubpath()
            painter.setBrush(QBrush(QColor(56, 189, 248, 220)))
            painter.setPen(QPen(QColor("#00F0FF"), 1.2))
            painter.drawPath(fish_path)
            painter.restore()
            painter.restore()

        elif hand == "coffee":
            # 极客外带纸杯咖啡 (杯身带天青芯片印花，杯口冒出两缕优雅半透明微风蒸汽)
            painter.save()
            painter.translate(14, 30)

            cup_path = QPainterPath()
            cup_path.moveTo(-8, 2)
            cup_path.lineTo(8, 2)
            cup_path.lineTo(6, 22)
            cup_path.lineTo(-6, 22)
            cup_path.closeSubpath()
            painter.setBrush(QBrush(QColor("#1E293B")))
            painter.setPen(QPen(QColor("#0F172A"), 1.5))
            painter.drawPath(cup_path)

            painter.setBrush(QBrush(QColor("#F8FAFC")))
            painter.setPen(QPen(QColor("#CBD5E1"), 1.2))
            painter.drawRoundedRect(QRectF(-9, -2, 18, 5), 2, 2)

            painter.setPen(QPen(QColor("#38BDF8"), 1.2))
            painter.drawRect(QRectF(-3, 8, 6, 6))
            painter.drawLine(0, 6, 0, 8)
            painter.drawLine(0, 14, 0, 16)

            steam_phase = self.anim_time * 5.0
            for si, sx in enumerate([-3, 3]):
                sy = -5 - (steam_phase + si * 4) % 14
                s_alpha = max(0, int(180 * (1.0 - (-5 - sy) / 14.0)))
                swiggle = math.sin(steam_phase + si * 2) * 2.5
                painter.setPen(QPen(QColor(255, 255, 255, s_alpha), 1.2))
                painter.drawLine(int(sx + swiggle), int(sy), int(sx + swiggle * 1.4), int(sy - 4))
            painter.restore()

        elif hand == "gamepad":
            # 8-bit 复古荧光绿掌机 (薄荷绿外壳，十字键与微型亮屏)
            painter.save()
            painter.translate(0, 42)
            painter.setBrush(QBrush(QColor("#10B981")))
            painter.setPen(QPen(QColor("#047857"), 1.8))
            painter.drawRoundedRect(QRectF(-20, -10, 40, 20), 4, 4)

            painter.setBrush(QBrush(QColor("#064E3B")))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawRect(QRectF(-9, -7, 18, 14))

            painter.setPen(QPen(QColor("#34D399"), 1.2))
            painter.drawLine(-6, 0, -2, -3)
            painter.drawLine(-2, -3, 2, 2)
            painter.drawLine(2, 2, 6, -1)

            painter.setBrush(QBrush(QColor("#1F2937")))
            painter.drawRect(QRectF(-16, -4, 4, 8))
            painter.drawRect(QRectF(-18, -2, 8, 4))

            painter.setBrush(QBrush(QColor("#EF4444")))
            painter.drawEllipse(QRectF(11, -3, 3.5, 3.5))
            painter.setBrush(QBrush(QColor("#3B82F6")))
            painter.drawEllipse(QRectF(14, 0, 3.5, 3.5))
            painter.restore()

        elif hand == "dumbbell":
            # 能量健身哑铃 (黑红质感健身器械)
            painter.save()
            painter.translate(0, 46)
            painter.setPen(QPen(QColor("#94A3B8"), 3.5, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
            painter.drawLine(-24, 0, 24, 0)
            for dx in [-26, 21]:
                painter.setBrush(QBrush(QColor("#1F2937")))
                painter.setPen(QPen(QColor("#EF4444"), 1.5))
                painter.drawRoundedRect(QRectF(dx, -8, 6, 16), 2, 2)
            painter.restore()

        painter.restore()

    def _draw_eating_food(self, painter: QPainter):
        painter.save()
        chew_y = math.sin(self.anim_time * 14.0) * 4.0
        painter.setFont(QFont("Segoe UI Emoji", 26))
        painter.drawText(QPointF(28, 12 + chew_y), self.current_food_icon)
        painter.restore()

    def _draw_bath_bubbles(self, painter: QPainter):
        painter.save()
        painter.setBrush(QBrush(QColor(255, 255, 255, 220)))
        painter.setPen(QPen(QColor(220, 240, 255), 1.5))
        painter.drawEllipse(QRectF(-20, -58, 22, 20))
        painter.drawEllipse(QRectF(-6, -65, 26, 24))
        painter.drawEllipse(QRectF(10, -56, 18, 16))
        painter.restore()

    def _draw_particles(self, painter: QPainter, cx, cy):
        for p in self.particles:
            painter.save()
            painter.translate(p.x, p.y)
            painter.setOpacity(p.alpha / 255.0)

            if p.particle_type == "heart":
                painter.rotate(p.rotation)
                heart = QPainterPath()
                s = p.size * 0.5
                heart.moveTo(0, s * 0.3)
                heart.cubicTo(-s, -s * 0.5, -s * 1.5, s * 0.3, 0, s * 1.4)
                heart.cubicTo(s * 1.5, s * 0.3, s, -s * 0.5, 0, s * 0.3)
                painter.setBrush(QBrush(QColor(255, 90, 130, p.alpha)))
                painter.setPen(Qt.PenStyle.NoPen)
                painter.drawPath(heart)

            elif p.particle_type == "sparkle":
                painter.rotate(p.rotation)
                painter.setBrush(QBrush(QColor(255, 220, 50, p.alpha)))
                painter.setPen(Qt.PenStyle.NoPen)
                s = p.size * 0.5
                star = QPainterPath()
                star.moveTo(0, -s)
                star.cubicTo(s * 0.15, -s * 0.15, s * 0.15, -s * 0.15, s, 0)
                star.cubicTo(s * 0.15, s * 0.15, s * 0.15, s * 0.15, 0, s)
                star.cubicTo(-s * 0.15, s * 0.15, -s * 0.15, s * 0.15, -s, 0)
                star.cubicTo(-s * 0.15, -s * 0.15, -s * 0.15, -s * 0.15, 0, -s)
                painter.drawPath(star)

            elif p.particle_type == "bubble":
                painter.setBrush(QBrush(QColor(210, 240, 255, 180)))
                painter.setPen(QPen(QColor(180, 220, 255, p.alpha), 1.5))
                painter.drawEllipse(QRectF(-p.size / 2, -p.size / 2, p.size, p.size))

            elif p.particle_type == "text" and p.text:
                painter.setFont(QFont("Comic Sans MS", int(p.size), QFont.Weight.Bold))
                painter.setPen(QColor(120, 140, 230, p.alpha))
                painter.drawText(0, 0, p.text)

            elif p.particle_type == "dust":
                # 漫步或落地触地柔和微尘烟圈
                painter.setBrush(QBrush(QColor(240, 244, 255, int(p.alpha * 0.75))))
                painter.setPen(Qt.PenStyle.NoPen)
                painter.drawEllipse(QRectF(-p.size / 2, -p.size * 0.38, p.size, p.size * 0.75))

            elif p.particle_type == "pawprint":
                # 漫步时留在地面上的粉嫩可爱小肉垫爪印
                painter.rotate(p.rotation)
                paw_col = QColor(255, 155, 180, int(p.alpha * 0.65))
                painter.setBrush(QBrush(paw_col))
                painter.setPen(Qt.PenStyle.NoPen)
                # 掌心主肉垫
                painter.drawEllipse(QRectF(-5, -2, 10, 8))
                # 4个圆圆小脚趾
                for tox, toy in [(-5, -6), (-2, -8), (2, -8), (5, -6)]:
                    painter.drawEllipse(QRectF(tox - 1.5, toy - 1.5, 3.5, 4.0))

            painter.restore()
