import os
import json
import time
import random
from pet.audio import sound_manager

class PetModel:
    """
    电子宠物核心数据模型与状态仿真器
    支持成长进化阶段 (幼崽期 -> 成长期 -> 成熟期 -> 究极体)、
    多部位自由装扮与丰富皮肤毛色切换
    """
    def __init__(self):
        self.app_dir = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), "ElectricPet")
        os.makedirs(self.app_dir, exist_ok=True)
        self.save_file = os.path.join(self.app_dir, "save_data.json")

        # 基础属性
        self.name = "波可 (Poko)"
        self.skin_id = "cat_calico"  # 默认三花猫
        self.pet_type = "cat"        # 基础骨骼大类: "cat", "dog", "slime", "penguin"
        self.hunger = 85.0           # 饱食度 (0-100)
        self.mood = 90.0             # 心情值 (0-100)
        self.energy = 95.0           # 精力值 (0-100)
        self.cleanliness = 90.0      # 清洁度 (0-100)
        self.level = 1               # 陪伴等级 (1-99)
        self.exp = 0.0               # 经验值
        self.intimacy = 10           # 亲密度
        self.total_days = 1          # 陪伴天数
        self.birth_time = time.time()
        self.last_tick_time = time.time()

        # 成长与进化系统 (喂食累积成长值，体型逐渐变大并进化形态)
        self.growth = 0.0            # 成长值 (0 ~ 1000+)
        self.weight = 1.20           # 体重 (kg)
        self.total_fed_count = 0     # 累计投喂次数

        # 多部位个性化自由装扮 (5大插槽: 头、面、颈、背、手持道具)
        self.decorations = {
            "head": "none",   # none, crown, halo, hat_wizard, horns, hat_party, chef, band_sport
            "face": "none",   # none, hacker_viser, sunglasses, glasses, blush_hearts
            "neck": "none",   # none, bow, scarf, bell, tie
            "back": "none",   # none, wings, balloon, cushion_zen
            "hand": "none"    # none, keyboard, fish_wand, coffee, gamepad, dumbbell
        }

        # 赛博家园与小窝场景 (none, neon_matrix, retro_arcade, summer_beach, zen_tatami)
        self.habitat = "none"

        # 性格树与行为塑造积分 (tech: 极客黑客, sport: 元气运动, lazy: 佛系大懒)
        self.personality_stats = {"tech": 0, "sport": 0, "lazy": 0}

        # 赛博扭蛋与物品图鉴
        self.coins = 150
        self.unlocked_items = [
            "cat_calico", "crown", "glasses", "bow", "wings", "keyboard", "neon_matrix"
        ]

        # 状态标志
        self.is_sleeping = False
        self.is_studying = False
        self.study_duration = 25 * 60
        self.study_time_left = 25 * 60

        # 系统设置
        self.user_scale_offset = 1.0  # 用户自定义缩放调节 (0.8 ~ 1.3)
        self.always_on_top = True
        self.sound_enabled = True
        self.auto_roam = True
        self.health_reminders = True
        self.auto_start = False
        self.enable_gravity = False  # 桌面物理重力 (False: 自由悬停立在任意高度; True: 贴地下落)
        self.last_pos_x = None       # 上次桌面停靠 X 坐标
        self.last_pos_y = None       # 上次桌面停靠 Y 坐标

        # 回调通知
        self.on_state_change = None
        self.on_level_up = None
        self.on_evolve = None
        self.on_focus_finish = None
        self.on_personality_change = None
        self.on_daily_milestone = None

        self.load_from_disk()

    @property
    def stage(self):
        """当前成长进化阶段"""
        if self.growth < 100:
            return "BABY"      # 幼崽期
        elif self.growth < 300:
            return "CHILD"     # 成长期
        elif self.growth < 700:
            return "ADULT"     # 成熟期
        else:
            return "ULTIMATE"  # 究极觉醒体

    @property
    def stage_info(self):
        """阶段名称与信息"""
        stages = {
            "BABY": {
                "name": "幼崽期 🍼",
                "title": "软糯初生幼宠",
                "next_target": 100,
                "base_scale": 0.85,
                "desc": "小巧圆滚滚的幼崽，大脑袋小短腿，充满稚气与好奇！"
            },
            "CHILD": {
                "name": "成长期 🐾",
                "title": "活泼元气伙伴",
                "next_target": 300,
                "base_scale": 1.00,
                "desc": "身体逐渐抽条，步履敏捷欢快，喜欢在桌面四处溜达！"
            },
            "ADULT": {
                "name": "成熟期 👑",
                "title": "威风忠诚守护",
                "next_target": 700,
                "base_scale": 1.15,
                "desc": "毛发丰盈体态优雅，亲和度满分，最贴心的工作伴侣！"
            },
            "ULTIMATE": {
                "name": "究极星辉体 ✨",
                "title": "天界星辉神宠",
                "next_target": 1500,
                "base_scale": 1.28,
                "desc": "觉醒神圣星辉光环，通体流转星尘粒子，拥有最强守护力！"
            }
        }
        return stages[self.stage]

    @property
    def visual_scale(self):
        """综合体型缩放 = 阶段基础缩放 * 用户微调缩放"""
        stage_base = self.stage_info["base_scale"]
        # 在同一个阶段内部，随着成长值积累也会有微微的长大平滑过渡
        stage_prog = 0.0
        if self.stage == "BABY":
            stage_prog = (self.growth / 100.0) * 0.06
        elif self.stage == "CHILD":
            stage_prog = ((self.growth - 100.0) / 200.0) * 0.06
        elif self.stage == "ADULT":
            stage_prog = ((self.growth - 300.0) / 400.0) * 0.06
        else:
            stage_prog = min(0.06, (self.growth - 700.0) / 1000.0 * 0.06)

        return (stage_base + stage_prog) * self.user_scale_offset

    @property
    def personality(self) -> str:
        """主导性格判定: HACKER (极客黑客喵), ATHLETE (元气运动喵), LAZY (佛系大懒喵), BALANCED (纯萌平衡喵)"""
        tech = self.personality_stats.get("tech", 0)
        sport = self.personality_stats.get("sport", 0)
        lazy = self.personality_stats.get("lazy", 0)

        scores = [("HACKER", tech), ("ATHLETE", sport), ("LAZY", lazy)]
        scores.sort(key=lambda x: x[1], reverse=True)
        top_name, top_score = scores[0]
        second_name, second_score = scores[1]

        # 门槛设定：单项至少达到 15 点，且领先其他项至少 3 点
        if top_score >= 15 and (top_score - second_score >= 3):
            return top_name
        return "BALANCED"

    @property
    def personality_info(self) -> dict:
        """性格详细特征、加成档案与专属装备"""
        traits = {
            "HACKER": {
                "name": "极客黑客喵 ⚡",
                "badge": "⚡ 极客黑客喵",
                "title": "赛博算力核心 · 极客黑客喵",
                "desc": "常食能量芯片与冷萃咖啡，精通各种语言代码，警报 Bug 灵敏度 100%！",
                "bonus": "专注模式算力效率提升 +20%，周围伴随矩阵代码流",
                "color": "#0EA5E9",
                "exclusive_item": "hacker_viser",
                "exclusive_item_name": "战术全息目镜"
            },
            "ATHLETE": {
                "name": "元气运动喵 🏃",
                "badge": "🏃 元气运动喵",
                "title": "桌面闪电飞人 · 元气运动喵",
                "desc": "热爱追逐玩耍与敏捷翻滚，身手矫健活力四射，浑身充满热血能量！",
                "bonus": "漫步移动速度提升 +25%，互动兴奋度翻倍",
                "color": "#10B981",
                "exclusive_item": "band_sport",
                "exclusive_item_name": "热血运动发带"
            },
            "LAZY": {
                "name": "佛系大懒喵 🍵",
                "badge": "🍵 佛系大懒喵",
                "title": "躺平禅意宗师 · 佛系大懒喵",
                "desc": "随遇而安发呆大师，享受温暖日光与软垫小憩，万物皆空小鱼干独尊！",
                "bonus": "睡眠精力恢复加速 +30%，更持久的心情稳定度",
                "color": "#F59E0B",
                "exclusive_item": "cushion_zen",
                "exclusive_item_name": "禅意榻榻米软垫"
            },
            "BALANCED": {
                "name": "纯真软萌体 🐾",
                "badge": "🐾 纯真萌宠",
                "title": "元气初生伙伴 · 纯真萌体",
                "desc": "性格均衡可爱，对桌面上的一切新鲜事物保持着天真好奇与探索欲。",
                "bonus": "均衡成长，各项属性消耗平缓",
                "color": "#EC4899",
                "exclusive_item": "none",
                "exclusive_item_name": "无"
            }
        }
        return traits[self.personality]

    def add_personality_point(self, category: str, pts: int = 1):
        """累积性格积分并检测性格觉醒演进"""
        if category not in self.personality_stats:
            self.personality_stats[category] = 0
        old_personality = self.personality
        self.personality_stats[category] += pts
        new_personality = self.personality
        if new_personality != old_personality and new_personality != "BALANCED":
            sound_manager.play("level_up")
            if self.on_personality_change:
                self.on_personality_change(new_personality, self.personality_info["name"])
        self._notify_change()

    def set_habitat(self, habitat_id: str):
        """切换赛博小窝家园主题"""
        self.habitat = habitat_id
        sound_manager.play("pop")
        self._notify_change()

    def draw_gacha(self, count=1):
        """
        赛博盲盒扭蛋抽奖
        单抽消耗 30 金币，十连抽消耗 270 金币
        返回: list of won items dict
        """
        pool = [
            # 稀有度, 插槽类型, 物品代号, 物品名称, 图标, 权重
            ("UR", "habitat", "neon_matrix", "暗夜霓虹极客房", "🌃", 4),
            ("UR", "habitat", "retro_arcade", "复古像素游戏机房", "🕹️", 4),
            ("UR", "back", "wings", "反重力光子羽翼", "🪽", 5),
            ("UR", "head", "crown", "黄金华贵王冠", "👑", 5),
            ("SSR", "face", "hacker_viser", "赛博战术目镜", "🥽", 10),
            ("SSR", "head", "band_sport", "热血运动发带", "🥊", 10),
            ("SSR", "back", "cushion_zen", "禅意榻榻米软垫", "🍵", 10),
            ("SSR", "hand", "keyboard", "RGB机械键盘", "⌨️", 12),
            ("SSR", "hand", "gamepad", "8-bit 复古掌机", "🎮", 12),
            ("SSR", "habitat", "summer_beach", "夏日阳光海滩", "🏖️", 10),
            ("SSR", "habitat", "zen_tatami", "佛系禅意蒲团室", "🌸", 10),
            ("SR", "hand", "fish_wand", "全息光纤逗猫棒", "🪄", 18),
            ("SR", "hand", "coffee", "极客外带咖啡", "☕", 18),
            ("SR", "hand", "dumbbell", "能量健身哑铃", "🏋️", 18),
            ("SR", "face", "sunglasses", "酷炫战术黑超", "🕶️", 20),
            ("SR", "head", "hat_wizard", "魔法巫师尖帽", "🧙", 20),
            ("R", "neck", "bow", "优雅赤红蝴蝶结", "🎀", 25),
            ("R", "neck", "bell", "招财金小挂铃", "🔔", 25),
            ("R", "face", "blush_hearts", "心动爱心面贴", "💖", 25)
        ]

        cost = 30 if count == 1 else 270
        if self.coins >= cost:
            self.coins -= cost
        else:
            # 金币不足时可用经验值抵扣
            exp_cost = cost * 2
            self.exp = max(0.0, self.exp - exp_cost)

        results = []
        total_weight = sum(item[5] for item in pool)

        for i in range(count):
            # 十连抽第 10 发保底 SSR 以上
            if count >= 10 and i == count - 1:
                high_pool = [x for x in pool if x[0] in ("SSR", "UR")]
                high_weight = sum(x[5] for x in high_pool)
                r = random.uniform(0, high_weight)
                upto = 0
                chosen = high_pool[0]
                for item in high_pool:
                    if upto + item[5] >= r:
                        chosen = item
                        break
                    upto += item[5]
            else:
                r = random.uniform(0, total_weight)
                upto = 0
                chosen = pool[0]
                for item in pool:
                    if upto + item[5] >= r:
                        chosen = item
                        break
                    upto += item[5]

            rarity, slot, code, name, icon, _ = chosen
            is_new = code not in self.unlocked_items
            if is_new:
                self.unlocked_items.append(code)

            results.append({
                "rarity": rarity,
                "slot": slot,
                "code": code,
                "name": name,
                "icon": icon,
                "is_new": is_new
            })

        sound_manager.play("sparkle")
        self.save_to_disk()
        self._notify_change()
        return results

    @property
    def max_exp(self):
        return 50 + (self.level - 1) * 35

    def add_exp(self, amount):
        self.exp += amount
        self.intimacy += int(amount * 0.8)
        leveled_up = False
        while self.exp >= self.max_exp and self.level < 99:
            self.exp -= self.max_exp
            self.level += 1
            leveled_up = True

        if self.level >= 99:
            self.exp = min(self.exp, self.max_exp)

        if leveled_up:
            sound_manager.play("level_up")
            if self.on_level_up:
                self.on_level_up(self.level)
        self._notify_change()

    def feed(self, food_code):
        """投喂食物并获得营养与成长值"""
        old_stage = self.stage

        foods = {
            "milk": {
                "name": "幼宠温热奶粉", "hunger": 20, "mood": 15, "exp": 10,
                "growth": 12.0, "weight_add": 0.06, "desc": "温润细腻，促进幼宠骨骼发育", "sound": "chew",
                "personality": ("lazy", 2)
            },
            "cake": {
                "name": "草莓鲜奶蛋糕", "hunger": 25, "mood": 25, "exp": 15,
                "growth": 18.0, "weight_add": 0.08, "desc": "香甜松软，心情大悦", "sound": "chew"
            },
            "fish": {
                "name": "深海极品烤鱼", "hunger": 35, "mood": 20, "exp": 20,
                "growth": 26.0, "weight_add": 0.12, "desc": "富含深海鱼油，毛发油亮顺滑", "sound": "chew",
                "personality": ("sport", 2)
            },
            "steak": {
                "name": "极品多汁厚牛排", "hunger": 45, "mood": 25, "exp": 25,
                "growth": 35.0, "weight_add": 0.18, "desc": "肉香四溢，大块长肉肉！", "sound": "chew",
                "personality": ("sport", 3)
            },
            "cyber_chip": {
                "name": "⚡ 赛博能量芯片", "hunger": 25, "mood": 25, "exp": 25,
                "growth": 28.0, "weight_add": 0.04, "desc": "超导量子能量芯片，注入纯净极客算力！", "sound": "sparkle",
                "personality": ("tech", 4)
            },
            "hacker_coffee": {
                "name": "☕ 极客黑客冷萃", "hunger": 15, "mood": 30, "exp": 20,
                "growth": 15.0, "weight_add": 0.02, "desc": "零度冰滴冷萃，思维敏锐警报 Bug！", "sound": "chew",
                "personality": ("tech", 3)
            },
            "elixir": {
                "name": "神奇仙灵仙果", "hunger": 30, "mood": 35, "exp": 40,
                "growth": 55.0, "weight_add": 0.10, "desc": "蕴含天地灵气，快速激活进化潜能！", "sound": "sparkle"
            },
            "boba": {
                "name": "珍珠温奶茶", "hunger": 18, "mood": 22, "exp": 12,
                "growth": 14.0, "weight_add": 0.07, "desc": "Q弹软糯，快乐加倍", "sound": "chew",
                "personality": ("lazy", 2)
            }
        }

        item = foods.get(food_code, foods["milk"])
        self.hunger = min(100.0, self.hunger + item["hunger"])
        self.mood = min(100.0, self.mood + item["mood"])
        self.growth += item["growth"]
        self.weight = round(self.weight + item["weight_add"], 2)
        self.total_fed_count += 1
        self.coins += 5  # 每次投喂奖励 5 枚赛博金币

        # 触发性格倾向积分积累
        pers = item.get("personality")
        if pers:
            self.add_personality_point(pers[0], pers[1])

        sound_manager.play(item["sound"])
        self.add_exp(item["exp"])

        # 检查是否触发进化！
        new_stage = self.stage
        if new_stage != old_stage:
            sound_manager.play("level_up")
            if self.on_evolve:
                self.on_evolve(new_stage, self.stage_info["name"])

        self._notify_change()
        return item["name"], item["growth"]

    def set_skin(self, skin_id):
        """更换宠物皮肤"""
        self.skin_id = skin_id
        # 同步骨骼大类
        if skin_id.startswith("dog"):
            self.pet_type = "dog"
        elif skin_id.startswith("slime"):
            self.pet_type = "slime"
        elif skin_id.startswith("penguin"):
            self.pet_type = "penguin"
        else:
            self.pet_type = "cat"
        self._notify_change()

    def set_decoration(self, slot, item_code):
        """装备或卸下特定部位的装饰配件"""
        if slot in self.decorations:
            self.decorations[slot] = item_code
            sound_manager.play("pop")
            self._notify_change()

    def pet_head(self):
        self.mood = min(100.0, self.mood + 8.0)
        sound_manager.play("purr")
        self.add_exp(5)

    def play_minigame(self, game_type="rps"):
        self.mood = min(100.0, self.mood + 25.0)
        self.energy = max(10.0, self.energy - 12.0)
        sound_manager.play("sparkle")
        self.add_exp(20)

    def bath(self):
        self.cleanliness = 100.0
        self.mood = min(100.0, self.mood + 15.0)
        sound_manager.play("pop")
        self.add_exp(15)

    def toggle_sleep(self):
        self.is_sleeping = not self.is_sleeping
        if self.is_sleeping:
            self.add_personality_point("lazy", 2)
            sound_manager.play("snore")
        else:
            sound_manager.play("meow")
        self._notify_change()
        return self.is_sleeping

    def wake_up(self):
        """唤醒宠物"""
        if self.is_sleeping:
            self.is_sleeping = False
            sound_manager.play("meow")
            self._notify_change()

    def stop_focus_timer(self):
        """停止专注计时器（cancel_focus_timer 别名）"""
        self.cancel_focus_timer()

    def start_focus_timer(self, minutes=25):
        self.is_studying = True
        self.study_duration = minutes * 60
        self.study_time_left = self.study_duration
        self.is_sleeping = False
        sound_manager.play("focus_chime")
        self._notify_change()

    def cancel_focus_timer(self):
        self.is_studying = False
        self._notify_change()

    def tick(self, delta_seconds):
        if delta_seconds <= 0:
            return

        # 每日跨天陪伴里程碑自动检测与签到奖励
        current_days = max(1, int((time.time() - self.birth_time) / 86400) + 1)
        if current_days > self.total_days:
            self.total_days = current_days
            self.add_exp(30.0)
            self.coins += 20
            sound_manager.play("level_up")
            if self.on_daily_milestone:
                self.on_daily_milestone(self.total_days)
            self.save_to_disk()

        if self.is_sleeping:
            self.energy = min(100.0, self.energy + delta_seconds * 0.12)
            self.hunger = max(0.0, self.hunger - delta_seconds * 0.005)
            self._sleep_seconds = getattr(self, "_sleep_seconds", 0.0) + delta_seconds
            if self._sleep_seconds >= 20.0:
                self._sleep_seconds = 0.0
                self.add_personality_point("lazy", 1)
        else:
            self.energy = max(0.0, self.energy - delta_seconds * 0.008)
            self.hunger = max(0.0, self.hunger - delta_seconds * 0.012)
            self.cleanliness = max(0.0, self.cleanliness - delta_seconds * 0.004)

        if self.hunger < 20 or self.cleanliness < 20:
            self.mood = max(0.0, self.mood - delta_seconds * 0.015)
        else:
            self.mood = min(100.0, self.mood + delta_seconds * 0.002)

        if self.is_studying:
            self.study_time_left -= delta_seconds
            if self.study_time_left <= 0:
                self.is_studying = False
                sound_manager.play("alarm")
                self.add_exp(50)
                self.mood = min(100.0, self.mood + 30.0)
                self.add_personality_point("tech", 5)
                self.coins += 10
                if self.on_focus_finish:
                    self.on_focus_finish()

        self._notify_change()

    def _notify_change(self):
        if self.on_state_change:
            self.on_state_change()

    def check_system_autostart(self) -> bool:
        """从 Windows 注册表检测当前是否实际配置了开机自启"""
        try:
            import winreg
            key = winreg.OpenKey(
                winreg.HKEY_CURRENT_USER,
                r"Software\Microsoft\Windows\CurrentVersion\Run",
                0, winreg.KEY_READ
            )
            try:
                winreg.QueryValueEx(key, "DesktopElectricPet")
                winreg.CloseKey(key)
                return True
            except FileNotFoundError:
                winreg.CloseKey(key)
                return False
        except Exception:
            return getattr(self, "auto_start", False)

    def toggle_gravity(self):
        """切换自由悬停 / 物理重力模式"""
        self.enable_gravity = not self.enable_gravity
        self.save_to_disk()
        return self.enable_gravity

    def save_to_disk(self):
        data = {
            "name": self.name,
            "skin_id": self.skin_id,
            "pet_type": self.pet_type,
            "hunger": self.hunger,
            "mood": self.mood,
            "energy": self.energy,
            "cleanliness": self.cleanliness,
            "level": self.level,
            "exp": self.exp,
            "intimacy": self.intimacy,
            "total_days": self.total_days,
            "birth_time": self.birth_time,
            "last_tick_time": time.time(),
            "growth": self.growth,
            "weight": self.weight,
            "total_fed_count": self.total_fed_count,
            "decorations": self.decorations,
            "habitat": self.habitat,
            "personality_stats": self.personality_stats,
            "coins": self.coins,
            "unlocked_items": self.unlocked_items,
            "user_scale_offset": self.user_scale_offset,
            "always_on_top": self.always_on_top,
            "sound_enabled": self.sound_enabled,
            "auto_roam": self.auto_roam,
            "health_reminders": self.health_reminders,
            "auto_start": self.auto_start,
            "enable_gravity": self.enable_gravity,
            "last_pos_x": self.last_pos_x,
            "last_pos_y": self.last_pos_y
        }
        tmp_file = self.save_file + ".tmp"
        try:
            with open(tmp_file, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            os.replace(tmp_file, self.save_file)
        except Exception as e:
            print(f"[PetModel] Save error: {e}")
            if os.path.exists(tmp_file):
                try:
                    os.remove(tmp_file)
                except Exception:
                    pass

    def load_from_disk(self):
        if not os.path.exists(self.save_file):
            return
        try:
            with open(self.save_file, "r", encoding="utf-8") as f:
                data = json.load(f)
            self.name = data.get("name", self.name)
            self.skin_id = data.get("skin_id", data.get("pet_type", "cat_calico"))
            self.set_skin(self.skin_id)
            self.hunger = max(0.0, min(100.0, float(data.get("hunger", self.hunger))))
            self.mood = max(0.0, min(100.0, float(data.get("mood", self.mood))))
            self.energy = max(0.0, min(100.0, float(data.get("energy", self.energy))))
            self.cleanliness = max(0.0, min(100.0, float(data.get("cleanliness", self.cleanliness))))
            self.level = max(1, min(99, int(data.get("level", self.level))))
            self.exp = max(0.0, float(data.get("exp", self.exp)))
            if self.level >= 99:
                self.exp = min(self.exp, self.max_exp)
            self.intimacy = int(data.get("intimacy", self.intimacy))
            self.total_days = int(data.get("total_days", self.total_days))
            self.birth_time = float(data.get("birth_time", self.birth_time))
            self.growth = float(data.get("growth", 0.0))
            self.weight = float(data.get("weight", 1.20))
            self.total_fed_count = int(data.get("total_fed_count", 0))

            loaded_decs = data.get("decorations", {})
            for k in self.decorations:
                if k in loaded_decs:
                    self.decorations[k] = loaded_decs[k]
            # 兼容旧版本单饰品
            old_acc = data.get("current_accessory", "none")
            if old_acc != "none" and self.decorations["head"] == "none":
                if old_acc in ("glasses",):
                    self.decorations["face"] = old_acc
                elif old_acc in ("bow", "scarf"):
                    self.decorations["neck"] = old_acc
                else:
                    self.decorations["head"] = old_acc

            self.habitat = data.get("habitat", "none")
            self.personality_stats = data.get("personality_stats", {"tech": 0, "sport": 0, "lazy": 0})
            self.coins = int(data.get("coins", 150))
            loaded_unlocked = data.get("unlocked_items", None)
            if loaded_unlocked and isinstance(loaded_unlocked, list):
                self.unlocked_items = loaded_unlocked

            self.user_scale_offset = float(data.get("user_scale_offset", data.get("scale", 1.0)))
            self.user_scale_offset = max(0.75, min(1.35, self.user_scale_offset))
            self.always_on_top = bool(data.get("always_on_top", self.always_on_top))
            self.sound_enabled = bool(data.get("sound_enabled", self.sound_enabled))
            sound_manager.muted = not self.sound_enabled
            self.auto_roam = bool(data.get("auto_roam", self.auto_roam))
            self.health_reminders = bool(data.get("health_reminders", self.health_reminders))
            self.auto_start = self.check_system_autostart()
            self.enable_gravity = bool(data.get("enable_gravity", False))
            self.last_pos_x = data.get("last_pos_x", None)
            self.last_pos_y = data.get("last_pos_y", None)

            days_passed = max(1, int((time.time() - self.birth_time) / 86400) + 1)
            self.total_days = days_passed
        except Exception as e:
            print(f"[PetModel] Load error: {e}")
