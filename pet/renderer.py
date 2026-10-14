import math
import random
import time
from PyQt6.QtCore import Qt, QRectF, QPointF
from PyQt6.QtGui import (
    QPainter, QColor, QBrush, QPen, QRadialGradient, QLinearGradient,
    QFont, QPainterPath, QPolygonF
)

class Particle:
    """浮动特效粒子 (爱心、星星、泡泡、Zzz、进化金辉)"""
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

    def trigger_eat(self, food_type):
        food_emojis = {
            "milk": "🍼", "cake": "🍰", "fish": "🐟", "steak": "🥩",
            "elixir": "🌟", "boba": "🧋", "pudding": "🍮", "burger": "🍔"
        }
        self.current_food_icon = food_emojis.get(food_type, "🍖")
        self.eating_timer = 2.2
        for _ in range(6):
            p = Particle(100 + random.uniform(-30, 30), 100, "sparkle")
            self.particles.append(p)

    def trigger_pet(self):
        self.petting_timer = 1.5
        for _ in range(2):
            p = Particle(100 + random.uniform(-20, 20), 70, "heart")
            self.particles.append(p)

    def trigger_bath(self):
        self.bath_timer = 3.0
        for _ in range(8):
            p = Particle(100 + random.uniform(-40, 40), 90, "bubble")
            self.particles.append(p)

    def trigger_evolution(self):
        """蜕变进化庆祝特效"""
        self.evolution_aura_timer = 4.0
        for _ in range(24):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2.5, 6.0)
            vx = math.cos(angle) * speed
            vy = math.sin(angle) * speed
            p = Particle(100, 100, "sparkle", vx=vx, vy=vy)
            p.decay = random.uniform(0.008, 0.018)
            p.size = random.uniform(18, 30)
            self.particles.append(p)

    def update_animation(self, delta_time, current_state):
        self.anim_time += delta_time

        # 眨眼逻辑
        now = time.time()
        if now >= self.next_blink_time:
            self.is_blinking = True
            self.blink_progress += delta_time * 8.0
            if self.blink_progress >= 1.0:
                self.is_blinking = False
                self.blink_progress = 0.0
                self.next_blink_time = now + random.uniform(2.5, 6.0)

        if self.eating_timer > 0:
            self.eating_timer -= delta_time
        if self.petting_timer > 0:
            self.petting_timer -= delta_time
        if self.bath_timer > 0:
            self.bath_timer -= delta_time
        if self.evolution_aura_timer > 0:
            self.evolution_aura_timer -= delta_time

        # 动作专属动态粒子发射
        if current_state == "HEAD_BOB_MUSIC" and random.random() < 0.14:
            note = random.choice(["♪", "♫", "♬"])
            p = Particle(100 + random.uniform(-30, 30), 45, "text", text=note)
            p.size = random.uniform(16, 22)
            self.particles.append(p)

        elif current_state == "HAPPY_SPIN" and random.random() < 0.35:
            p = Particle(100 + random.uniform(-40, 40), 75, "sparkle")
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

    def render(self, painter: QPainter, width, height, state, facing_left=False):
        painter.setRenderHint(QPainter.RenderHint.Antialiasing, True)
        painter.setRenderHint(QPainter.RenderHint.SmoothPixmapTransform, True)
        painter.setRenderHint(QPainter.RenderHint.TextAntialiasing, True)

        cx = width / 2.0
        cy = height / 2.0 + 15.0

        # 呼吸与多样化动作形变参数
        stage = self.model.stage
        breath_speed = 4.5 if stage == "BABY" else (2.0 if self.model.is_sleeping else 3.2)
        breath_offset = math.sin(self.anim_time * breath_speed) * 3.0
        squash_x = 1.0
        squash_y = 1.0
        tilt_angle = 0.0

        if state == "FALLING":
            squash_x = 0.88
            squash_y = 1.15
        elif state == "BOUNCE":
            squash_x = 1.25
            squash_y = 0.78
        elif state == "DRAGGING":
            squash_x = 0.90
            squash_y = 1.12
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
            breath_offset = -28.0 * abs(math.sin(self.anim_time * 6.0))
            squash_x = math.cos(self.anim_time * 10.0)
        elif state == "DOZE_OFF":
            tilt_angle = max(0.0, math.sin(self.anim_time * 2.2) * 18.0)
            breath_offset = 4.0
        elif state == "DIZZY":
            tilt_angle = math.sin(self.anim_time * 12.0) * 6.0
            squash_x = 1.05
            squash_y = 0.95
        elif self.model.is_sleeping:
            breath_offset = math.sin(self.anim_time * 1.8) * 2.0

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

        # 2. 背部装饰 (如翅膀、气球)
        self._draw_back_decorations(painter)

        # 3. 底部双层立体地面投影 (Ground Dual-Layer 3D Shadow)
        shadow_w = 96 * abs(squash_x)
        if stage == "BABY":
            shadow_w *= 0.85
        elif stage == "ULTIMATE":
            shadow_w *= 1.15

        # 漫反射羽化大阴影 (羽化环境落影)
        shadow_rect = QRectF(-shadow_w / 2.0, 44 - breath_offset * 0.3, shadow_w, 20)
        shadow_grad = QRadialGradient(shadow_rect.center(), shadow_w / 2.0)
        shadow_grad.setColorAt(0.0, QColor(0, 0, 0, 48))
        shadow_grad.setColorAt(0.55, QColor(0, 0, 0, 20))
        shadow_grad.setColorAt(1.0, QColor(0, 0, 0, 0))
        painter.setBrush(QBrush(shadow_grad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(shadow_rect)

        # 紧贴足底重力接触阴影 (Contact Shadow, 强化实体着地重力感)
        contact_w = shadow_w * 0.72
        contact_rect = QRectF(-contact_w / 2.0, 47 - breath_offset * 0.2, contact_w, 9)
        contact_grad = QRadialGradient(contact_rect.center(), contact_w / 2.0)
        contact_grad.setColorAt(0.0, QColor(0, 0, 0, 80))
        contact_grad.setColorAt(0.65, QColor(0, 0, 0, 25))
        contact_grad.setColorAt(1.0, QColor(0, 0, 0, 0))
        painter.setBrush(QBrush(contact_grad))
        painter.drawEllipse(contact_rect)

        painter.translate(0, breath_offset)
        if tilt_angle != 0.0:
            painter.rotate(tilt_angle)
        painter.scale(squash_x, squash_y)

        # 4. 根据皮肤绘制本体
        skin_id = self.model.skin_id
        if skin_id.startswith("dog"):
            self._draw_dog(painter, state, skin_id)
        elif skin_id.startswith("slime"):
            self._draw_slime(painter, state, skin_id)
        elif skin_id.startswith("penguin"):
            self._draw_penguin(painter, state)
        else:
            self._draw_cat(painter, state, skin_id)

        # 5. 脖饰 (领结、围巾、铃铛)
        self._draw_neck_decorations(painter)

        # 6. 面饰 (眼镜、墨镜、心动贴纸)
        self._draw_face_decorations(painter)

        # 7. 头饰 (魔法帽、派对帽、光环、王冠)
        self._draw_head_decorations(painter)

        # 8. 动作专属覆盖物 (听歌耳机、追逐蝴蝶、眩晕星星)
        if state == "HEAD_BOB_MUSIC":
            self._draw_headphones(painter)
        elif state == "CHASE_BUTTERFLY":
            self._draw_butterfly(painter)
        elif state == "DIZZY":
            self._draw_dizzy_stars(painter)

        # 9. 正在进行的进食/洗澡覆盖物
        if self.eating_timer > 0:
            self._draw_eating_food(painter)
        if self.bath_timer > 0:
            self._draw_bath_bubbles(painter)

        painter.restore()

        # 10. 独立粒子特效绘制
        self._draw_particles(painter, cx, cy)

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

    def _draw_back_decorations(self, painter: QPainter):
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

    # ================= 猫咪皮肤绘制 (3D 立体手办质感) =================
    def _draw_cat(self, painter: QPainter, state, skin_id):
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

        # 1. 立体圆润尾巴
        tail_angle = math.sin(self.anim_time * 4.0) * 18.0
        painter.save()
        painter.translate(35, 25)
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

        # 2. 立体双耳 (外耳轮廓光 + 内耳凹陷立体阴影)
        ear_twitch = math.sin(self.anim_time * 6.0) * 3.0 if state == "IDLE" else 0.0
        # 左耳
        left_ear = QPainterPath()
        left_ear.moveTo(-35, -28)
        left_ear.cubicTo(-42, -50, -56, -72 + ear_twitch, -54, -75 + ear_twitch)
        left_ear.cubicTo(-46, -72 + ear_twitch, -26, -56, -12, -45)
        left_ear.closeSubpath()
        ear_grad_l = QLinearGradient(-54, -75, -12, -28)
        ear_grad_l.setColorAt(0.0, QColor(palette["ear_l_t"]))
        ear_grad_l.setColorAt(1.0, QColor(palette["ear_l_b"]))
        painter.setBrush(QBrush(ear_grad_l))
        painter.setPen(QPen(QColor(palette["outline"]), 3.2))
        painter.drawPath(left_ear)

        # 左内耳凹陷阴影
        left_inner = QPainterPath()
        left_inner.moveTo(-34, -34)
        left_inner.lineTo(-48, -68 + ear_twitch)
        left_inner.lineTo(-18, -45)
        left_inner.closeSubpath()
        inner_grad_l = QLinearGradient(-48, -68, -26, -34)
        inner_grad_l.setColorAt(0.0, QColor(palette["inner_ear_t"]))
        inner_grad_l.setColorAt(1.0, QColor(palette["inner_ear_b"]))
        painter.setBrush(QBrush(inner_grad_l))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawPath(left_inner)

        # 右耳
        right_ear = QPainterPath()
        right_ear.moveTo(35, -28)
        right_ear.cubicTo(42, -50, 56, -72 - ear_twitch, 54, -75 - ear_twitch)
        right_ear.cubicTo(46, -72 - ear_twitch, 26, -56, 12, -45)
        right_ear.closeSubpath()
        ear_grad_r = QLinearGradient(54, -75, 12, -28)
        ear_grad_r.setColorAt(0.0, QColor(palette["ear_r_t"]))
        ear_grad_r.setColorAt(1.0, QColor(palette["ear_r_b"]))
        painter.setBrush(QBrush(ear_grad_r))
        painter.setPen(QPen(QColor(palette["outline"]), 3.2))
        painter.drawPath(right_ear)

        # 右内耳凹陷阴影
        right_inner = QPainterPath()
        right_inner.moveTo(34, -34)
        right_inner.lineTo(48, -68 - ear_twitch)
        right_inner.lineTo(18, -45)
        right_inner.closeSubpath()
        painter.setBrush(QBrush(inner_grad_l))
        painter.drawPath(right_inner)

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
            spot_path.moveTo(15, -45)
            spot_path.cubicTo(45, -42, 52, -15, 45, 10)
            spot_path.cubicTo(32, 0, 20, -20, 15, -45)
            spot_grad = QLinearGradient(20, -40, 48, 5)
            spot_grad.setColorAt(0.0, palette["spot_t"])
            spot_grad.setColorAt(1.0, palette["spot_b"])
            painter.setBrush(QBrush(spot_grad))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawPath(spot_path)

        # 5. 软萌凸起白肚皮 (Belly Volume Highlight)
        belly_rect = QRectF(-30, 2, 60, 44)
        belly_grad = QRadialGradient(0, 15, 32, 0, 8)
        belly_grad.setColorAt(0.0, QColor(255, 255, 255, 220))
        belly_grad.setColorAt(0.7, QColor(255, 250, 245, 170))
        belly_grad.setColorAt(1.0, QColor(255, 235, 220, 0))
        painter.setBrush(QBrush(belly_grad))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(belly_rect)

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

        # 7. 柔和羽化立体腮红 (带微光)
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

        # 8. 灵动弧线胡须
        whisk_col = QColor(palette["outline"]).lighter(120)
        painter.setPen(QPen(whisk_col, 2.2, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        w_l1 = QPainterPath(); w_l1.moveTo(-42, 2); w_l1.cubicTo(-50, 1, -58, -1, -64, -3); painter.drawPath(w_l1)
        w_l2 = QPainterPath(); w_l2.moveTo(-42, 7); w_l2.cubicTo(-50, 8, -58, 11, -62, 13); painter.drawPath(w_l2)
        w_r1 = QPainterPath(); w_r1.moveTo(42, 2); w_r1.cubicTo(50, 1, 58, -1, 64, -3); painter.drawPath(w_r1)
        w_r2 = QPainterPath(); w_r2.moveTo(42, 7); w_r2.cubicTo(50, 8, 58, 11, 62, 13); painter.drawPath(w_r2)

        # 9. 眼睛与嘴巴 (支持异色瞳与全部动作面容)
        self._draw_cat_face(painter, state, skin_id)

        # 10. 立体胖嘟嘟小爪爪 (3D Plush Paws)
        self._draw_plush_paws(painter, state, palette)

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

            # 3D 粉嫩果冻肉垫
            pad_rect = QRectF(pad_x, pad_y, pad_w, pad_h)
            pad_grad = QRadialGradient(pad_x + pad_w * 0.4, pad_y + pad_h * 0.4, max(pad_w, pad_h))
            pad_grad.setColorAt(0.0, QColor("#FFAAAA"))
            pad_grad.setColorAt(0.8, QColor("#FF7B90"))
            pad_grad.setColorAt(1.0, QColor("#DE596F"))
            painter.setBrush(QBrush(pad_grad))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawEllipse(pad_rect)
            painter.setBrush(QBrush(QColor(255, 255, 255, 190)))
            painter.drawEllipse(QRectF(pad_x + 2, pad_y + 1.5, pad_w * 0.35, pad_h * 0.3))

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
    def _draw_dog(self, painter: QPainter, state, skin_id):
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

        # 1. 3D 卷尾巴
        tail_wag = math.sin(self.anim_time * 8.0) * 12.0
        painter.save()
        painter.translate(35, 20)
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

        # 2. 立体双耳 (外耳高光 + 凹陷立体感)
        left_ear = QPainterPath()
        left_ear.moveTo(-35, -28)
        left_ear.lineTo(-50, -78)
        left_ear.lineTo(-12, -45)
        left_ear.closeSubpath()
        ear_g_l = QLinearGradient(-50, -78, -12, -28)
        ear_g_l.setColorAt(0.0, QColor(pal["fur_hl"]))
        ear_g_l.setColorAt(1.0, QColor(pal["fur_mid"]))
        painter.setBrush(QBrush(ear_g_l))
        painter.setPen(QPen(QColor(pal["outline"]), 3.2))
        painter.drawPath(left_ear)

        right_ear = QPainterPath()
        right_ear.moveTo(35, -28)
        right_ear.lineTo(50, -78)
        right_ear.lineTo(12, -45)
        right_ear.closeSubpath()
        ear_g_r = QLinearGradient(50, -78, 12, -28)
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

        # 4. 柴犬白色面罩 (立体浮雕渐变)
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

        # 5. 柴犬标志性白眉毛 (立体微高光圆球)
        for bx in [-28, 16]:
            brow_g = QRadialGradient(bx + 6, -28, 8)
            brow_g.setColorAt(0.0, QColor(pal["brow"]))
            brow_g.setColorAt(1.0, QColor(pal["muzzle_b"]))
            painter.setBrush(QBrush(brow_g))
            painter.drawEllipse(QRectF(bx, -32, 12, 10))

        # 6. 3D 顶面高光
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

        # 7. 柔和羽化立体腮红
        for bx, by in [(-33, 6), (33, 6)]:
            b_grad = QRadialGradient(bx, by, 12)
            b_grad.setColorAt(0.0, QColor(255, 120, 145, 140))
            b_grad.setColorAt(0.6, QColor(255, 145, 170, 70))
            b_grad.setColorAt(1.0, QColor(255, 160, 180, 0))
            painter.setBrush(QBrush(b_grad))
            painter.drawEllipse(QRectF(bx - 12, by - 8, 24, 16))

        # 8. 面部表情
        self._draw_face_by_state(painter, state, QColor("#3D2923"), QColor("#3D2923"))

        # 9. 立体肉垫爪爪
        self._draw_plush_paws(painter, state, pal)

    # ================= 史莱姆皮肤绘制 (3D 晶莹果冻质感) =================
    def _draw_slime(self, painter: QPainter, state, skin_id):
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

        # 腮红
        for bx, by in [(-36, 10), (24, 10)]:
            b_grad = QRadialGradient(bx, by, 10)
            b_grad.setColorAt(0.0, QColor(255, 100, 170, 160))
            b_grad.setColorAt(1.0, QColor(255, 100, 170, 0))
            painter.setBrush(QBrush(b_grad))
            painter.drawEllipse(QRectF(bx - 9, by - 6, 18, 12))

        # 史莱姆动态面部表情
        self._draw_face_by_state(painter, state, QColor("#1E293B"), QColor("#1E293B"))

    # ================= 帝企鹅皮肤绘制 (3D 饱满企鹅手办) =================
    def _draw_penguin(self, painter: QPainter, state):
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

        for fx, fa in [(-45, -flipper_angle), (45, flipper_r_angle)]:
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

        # 腮红
        for bx, by in [(-25, 4), (25, 4)]:
            b_grad = QRadialGradient(bx, by, 10)
            b_grad.setColorAt(0.0, QColor(255, 120, 140, 140))
            b_grad.setColorAt(1.0, QColor(255, 120, 140, 0))
            painter.setBrush(QBrush(b_grad))
            painter.drawEllipse(QRectF(bx - 8, by - 5, 16, 10))

        # 企鹅面容表情
        self._draw_face_by_state(painter, state, QColor("#0F172A"), QColor("#0F172A"))

        # 橙黄小企鹅喙 (3D 分面立体光泽)
        beak_left = QPolygonF([QPointF(0, 3), QPointF(-8, 3), QPointF(0, 14)])
        beak_right = QPolygonF([QPointF(0, 3), QPointF(8, 3), QPointF(0, 14)])
        painter.setBrush(QBrush(QColor("#FB923C")))
        painter.setPen(QPen(QColor("#C2410C"), 1.2))
        painter.drawPolygon(beak_left)
        painter.setBrush(QBrush(QColor("#EA580C")))
        painter.drawPolygon(beak_right)

        # 企鹅立体小脚丫
        leg_offset = math.sin(self.anim_time * 8.0) * 5.0 if state in ("WALK_LEFT", "WALK_RIGHT") else 0.0
        for fx, fo in [(-20, leg_offset), (20, -leg_offset)]:
            foot_g = QRadialGradient(fx, 45 + fo, 14)
            foot_g.setColorAt(0.0, QColor("#FDBA74"))
            foot_g.setColorAt(0.8, QColor("#EA580C"))
            foot_g.setColorAt(1.0, QColor("#C2410C"))
            painter.setBrush(QBrush(foot_g))
            painter.setPen(QPen(QColor("#9A3412"), 1.8))
            painter.drawEllipse(QRectF(fx - 11, 41 + fo, 22, 13))

    # ================= 通用面部与动作特效绘制 =================
    def _draw_face_by_state(self, painter: QPainter, state, eye_l_col=None, eye_r_col=None):
        if eye_l_col is None:
            eye_l_col = QColor("#3D2923")
        if eye_r_col is None:
            eye_r_col = QColor("#3D2923")

        if self.model.is_sleeping:
            self._draw_sleeping_face(painter)
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

        if state == "TILT_HEAD":
            self._draw_curious_face(painter, eye_l_col, eye_r_col)
            return

        if self.petting_timer > 0 or self.eating_timer > 0 or state == "HAPPY_SPIN" or self.model.mood > 92:
            self._draw_happy_face(painter)
            return

        if self.is_blinking:
            self._draw_blinking_eyes(painter)
        else:
            self._draw_normal_eyes(painter, eye_l_col, eye_r_col)
        self._draw_standard_mouth(painter)

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
        # 歪头好奇大眼睛 (左眼水汪汪超大，右眼萌眨)
        painter.setPen(QPen(col_l, 1))
        painter.setBrush(QBrush(col_l))
        painter.drawEllipse(QRectF(-29, -17, 20, 24))
        painter.drawEllipse(QRectF(10, -14, 16, 20))

        # 亮闪闪大高光
        painter.setBrush(QBrush(QColor(255, 255, 255, 245)))
        painter.setPen(Qt.PenStyle.NoPen)
        painter.drawEllipse(QRectF(-26, -15, 9, 11))
        painter.drawEllipse(QRectF(13, -12, 7, 9))
        painter.drawEllipse(QRectF(-17, -4, 5, 5))

        self._draw_standard_mouth(painter)

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
        painter.setPen(QPen(QColor("#543D37"), 3.5, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        painter.drawLine(-27, -4, -9, -4)
        painter.drawLine(9, -4, 27, -4)

    def _draw_normal_eyes(self, painter: QPainter, col_l: QColor, col_r: QColor):
        # 幼年期眼睛更大更萌
        eye_w, eye_h = (18, 23) if self.model.stage == "BABY" else (16, 21)

        for ex, col in [(-19, col_l), (19, col_r)]:
            eye_rect = QRectF(ex - eye_w / 2.0, -15, eye_w, eye_h)

            # 3D 琉璃眼眶渐变 (顶部眼睑暗影 -> 中部虹膜色 -> 底部剔透光泽)
            e_grad = QLinearGradient(ex, -15, ex, 6)
            e_grad.setColorAt(0.0, QColor("#1A0C08"))
            e_grad.setColorAt(0.5, col.darker(115))
            e_grad.setColorAt(1.0, col.lighter(135))
            painter.setBrush(QBrush(e_grad))
            painter.setPen(QPen(QColor("#150A06"), 1.2))
            painter.drawEllipse(eye_rect)

            # 下眼眶琉璃月牙光泽 (Caustic Glow)
            iris_glow = QPainterPath()
            iris_glow.addEllipse(QRectF(ex - eye_w / 2.0 + 2, -5, eye_w - 4, 9))
            g_iris = QLinearGradient(ex, -5, ex, 5)
            g_iris.setColorAt(0.0, QColor(255, 255, 255, 0))
            g_iris.setColorAt(1.0, QColor(col.red(), col.green(), col.blue(), 155))
            painter.setBrush(QBrush(g_iris))
            painter.setPen(Qt.PenStyle.NoPen)
            painter.drawPath(iris_glow)

            # 璀璨星芒高光 (主大高光 + 副灵动星芒)
            painter.setBrush(QBrush(QColor(255, 255, 255, 250)))
            painter.drawEllipse(QRectF(ex - 6.5, -13, 6.5, 9.0))
            painter.drawEllipse(QRectF(ex + 1.5, -4.5, 3.8, 3.8))
            painter.setBrush(QBrush(QColor(255, 255, 255, 180)))
            painter.drawEllipse(QRectF(ex - 4, 1, 2.5, 2.5))

    def _draw_standard_mouth(self, painter: QPainter):
        painter.setBrush(QBrush(QColor("#FFA5A5")))
        painter.setPen(Qt.PenStyle.NoPen)
        nose = QPolygonF([QPointF(-3, 2), QPointF(3, 2), QPointF(0, 5)])
        painter.drawPolygon(nose)

        painter.setPen(QPen(QColor("#543D37"), 2.2, Qt.PenStyle.SolidLine, Qt.PenCapStyle.RoundCap))
        mouth = QPainterPath()
        mouth.moveTo(-9, 7)
        mouth.cubicTo(-5, 11, -1, 11, 0, 7)
        mouth.cubicTo(1, 11, 5, 11, 9, 7)
        painter.drawPath(mouth)

    # ================= 多插槽装扮渲染 =================
    def _draw_head_decorations(self, painter: QPainter):
        head = self.model.decorations.get("head", "none")
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
            painter.setBrush(QBrush(QColor(255, 240, 150, 70)))
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

    def _draw_face_decorations(self, painter: QPainter):
        face = self.model.decorations.get("face", "none")
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

    def _draw_neck_decorations(self, painter: QPainter):
        neck = self.model.decorations.get("neck", "none")
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

            painter.restore()
