# -*- coding: utf-8 -*-
"""
桌面萌宠 · 波可 —— Python 侧核心逻辑单元测试

设计约束（刻意为之，别改）：
1. 只用标准库 unittest，不引入 pytest。理由：CI 里 `python -m unittest` 开箱即跑，
   不需要在 Windows + PyQt6 + Pillow 的环境里再装一个测试框架。
2. 只测「纯逻辑模块」。pet/model.py 只依赖 pet/audio.py，而 audio.py 只用标准库
   （winsound / wave / struct），所以本文件 **不需要 PyQt6**，可以在 ubuntu CI 上跑。
   需要 Qt 的 UI 模块（window/menus/dock/renderer）留到有头显环境的机器上测。
3. PetModel 构造时会往 %APPDATA%/ElectricPet 写真档，所以每个用例都把 APPDATA
   指向临时目录，绝不碰玩家真实的存档。

运行：
    python -m unittest discover -s tests -t . -v
"""

import os
import sys
import tempfile
import unittest

# 保证从任意工作目录调用都能 import 到仓库根的 pet 包
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from pet.audio import sound_manager  # noqa: E402
from pet.model import PetModel  # noqa: E402


class PetModelTestBase(unittest.TestCase):
    """把存档目录隔离到临时区，并静音音效线程。"""

    def setUp(self):
        self._tmpdir = tempfile.TemporaryDirectory(prefix="poko_test_")
        self._saved_appdata = os.environ.get("APPDATA")
        os.environ["APPDATA"] = self._tmpdir.name

        # 静音：否则每次 feed()/add_exp() 都会往音频队列塞真实 wav
        self._saved_muted = sound_manager.muted
        sound_manager.muted = True

        self.model = PetModel()

    def tearDown(self):
        sound_manager.muted = self._saved_muted
        if self._saved_appdata is None:
            os.environ.pop("APPDATA", None)
        else:
            os.environ["APPDATA"] = self._saved_appdata
        self._tmpdir.cleanup()


class TestGrowthStage(PetModelTestBase):
    """成长阶段划分：growth 100 / 300 / 700 三道分界线。"""

    def test_stage_boundaries(self):
        cases = [
            (0.0, "BABY"),
            (99.99, "BABY"),
            (100.0, "CHILD"),
            (299.99, "CHILD"),
            (300.0, "ADULT"),
            (699.99, "ADULT"),
            (700.0, "ULTIMATE"),
            (1500.0, "ULTIMATE"),
        ]
        for growth, expected in cases:
            with self.subTest(growth=growth):
                self.model.growth = growth
                self.assertEqual(self.model.stage, expected)

    def test_stage_info_matches_stage(self):
        self.model.growth = 350.0
        self.assertEqual(self.model.stage_info["name"], "成熟期 👑")
        self.model.growth = 10.0
        self.assertEqual(self.model.stage_info["name"], "幼崽期 🍼")

    def test_visual_scale_grows_with_growth(self):
        self.model.growth = 10.0
        small = self.model.visual_scale
        self.model.growth = 90.0
        bigger = self.model.visual_scale
        self.assertGreater(bigger, small)

    def test_visual_scale_respects_user_offset(self):
        self.model.growth = 150.0
        self.model.user_scale_offset = 1.0
        base = self.model.visual_scale
        self.model.user_scale_offset = 1.2
        self.assertAlmostEqual(self.model.visual_scale, base * 1.2, places=5)


class TestPersonality(PetModelTestBase):
    """性格判定：单项 >= 15 分且领先第二名 >= 3 分，否则 BALANCED。"""

    def test_balanced_by_default(self):
        self.assertEqual(self.model.personality, "BALANCED")

    def test_threshold_requires_15_points(self):
        self.model.personality_stats = {"tech": 14, "sport": 0, "lazy": 0}
        self.assertEqual(self.model.personality, "BALANCED")
        self.model.personality_stats = {"tech": 15, "sport": 0, "lazy": 0}
        self.assertEqual(self.model.personality, "HACKER")

    def test_threshold_requires_3_point_lead(self):
        # tech=16 但 sport=14，只领先 2 分 -> 不足以判定专属性格
        self.model.personality_stats = {"tech": 16, "sport": 14, "lazy": 0}
        self.assertEqual(self.model.personality, "BALANCED")
        self.model.personality_stats = {"tech": 17, "sport": 14, "lazy": 0}
        self.assertEqual(self.model.personality, "HACKER")

    def test_add_personality_point_notifies_on_awaken(self):
        fired = []
        self.model.on_personality_change = lambda p, n: fired.append(p)
        self.model.add_personality_point("sport", 15)
        self.assertEqual(fired, ["ATHLETE"])
        self.assertEqual(self.model.personality, "ATHLETE")

    def test_add_personality_point_ignores_unknown_category(self):
        self.model.add_personality_point("unknown_cat", 5)
        self.assertIn("unknown_cat", self.model.personality_stats)
        self.assertEqual(self.model.personality, "BALANCED")


class TestExperience(PetModelTestBase):
    """经验与等级：连升多级、99 级封顶。"""

    def test_max_exp_formula(self):
        self.model.level = 1
        self.assertEqual(self.model.max_exp, 50)
        self.model.level = 3
        self.assertEqual(self.model.max_exp, 120)

    def test_add_exp_can_level_up_multiple_times(self):
        self.model.level = 1
        self.model.exp = 0.0
        self.model.add_exp(200.0)
        # 50 -> 升到 2 级(阈值 85) -> 升到 3 级(阈值 120)
        self.assertGreaterEqual(self.model.level, 3)
        self.assertLess(self.model.exp, self.model.max_exp)

    def test_level_capped_at_99(self):
        self.model.level = 98
        self.model.add_exp(100000.0)
        self.assertEqual(self.model.level, 99)
        self.assertLessEqual(self.model.exp, self.model.max_exp)

    def test_intimacy_grows_with_exp(self):
        before = self.model.intimacy
        self.model.add_exp(10.0)
        self.assertEqual(self.model.intimacy, before + 8)


class TestFeeding(PetModelTestBase):
    """投喂：数值封顶、成长值/体重/金币累加、性格倾向。"""

    def test_feed_caps_hunger_and_mood_at_100(self):
        self.model.hunger = 99.0
        self.model.mood = 99.0
        self.model.feed("steak")  # hunger +45, mood +25
        self.assertEqual(self.model.hunger, 100.0)
        self.assertEqual(self.model.mood, 100.0)

    def test_feed_increases_growth_weight_and_coins(self):
        growth, weight, coins = self.model.growth, self.model.weight, self.model.coins
        self.model.feed("steak")
        self.assertEqual(self.model.growth, growth + 35.0)
        self.assertEqual(self.model.weight, round(weight + 0.18, 2))
        self.assertEqual(self.model.coins, coins + 5)
        self.assertEqual(self.model.total_fed_count, 1)

    def test_unknown_food_falls_back_to_milk(self):
        name, growth = self.model.feed("not_a_real_food")
        self.assertEqual(name, "幼宠温热奶粉")
        self.assertEqual(growth, 12.0)

    def test_food_drives_personality_tendency(self):
        self.model.feed("steak")   # sport +3
        self.assertEqual(self.model.personality_stats["sport"], 3)
        self.model.feed("milk")    # lazy +2
        self.assertEqual(self.model.personality_stats["lazy"], 2)

    def test_feed_triggers_evolve_callback(self):
        fired = []
        self.model.on_evolve = lambda stage, name: fired.append(stage)
        self.model.growth = 95.0
        self.model.feed("steak")  # +35 -> 130, 跨过 100 进入 CHILD
        self.assertEqual(fired, ["CHILD"])
        self.assertEqual(self.model.stage, "CHILD")


class TestGacha(PetModelTestBase):
    """扭蛋：扣费逻辑、保底、结果结构。"""

    def test_single_draw_costs_30_coins(self):
        self.model.coins = 100
        results = self.model.draw_gacha(1)
        self.assertEqual(len(results), 1)
        self.assertEqual(self.model.coins, 70)

    def test_ten_draw_costs_270_coins(self):
        self.model.coins = 1000
        results = self.model.draw_gacha(10)
        self.assertEqual(len(results), 10)
        self.assertEqual(self.model.coins, 730)

    def test_insufficient_coins_falls_back_to_exp(self):
        self.model.coins = 0
        self.model.exp = 100.0
        self.model.draw_gacha(1)
        # 30 币换算成 60 经验
        self.assertEqual(self.model.exp, 40.0)
        self.assertEqual(self.model.coins, 0)

    def test_result_structure_has_required_keys(self):
        results = self.model.draw_gacha(1)
        item = results[0]
        for key in ("rarity", "slot", "code", "name", "icon", "is_new"):
            self.assertIn(key, item)

    def test_ten_draw_last_pull_is_ssr_or_better(self):
        self.model.coins = 5000
        results = self.model.draw_gacha(10)
        self.assertIn(results[-1]["rarity"], ("SSR", "UR"))

    def test_draw_unlocks_new_item(self):
        self.model.unlocked_items = []
        results = self.model.draw_gacha(1)
        self.assertIn(results[0]["code"], self.model.unlocked_items)


class TestSkinAndDecorations(PetModelTestBase):
    """皮肤 -> 骨骼大类映射与饰品插槽。"""

    def test_set_skin_maps_pet_type(self):
        cases = [
            ("dog_shiba", "dog"),
            ("dog_corgi", "dog"),
            ("slime_ocean", "slime"),
            ("penguin_tuxedo", "penguin"),
            ("cat_calico", "cat"),
        ]
        for skin, expected in cases:
            with self.subTest(skin=skin):
                self.model.set_skin(skin)
                self.assertEqual(self.model.pet_type, expected)

    def test_set_decoration_only_accepts_known_slots(self):
        self.model.set_decoration("head", "crown")
        self.assertEqual(self.model.decorations["head"], "crown")
        self.model.set_decoration("not_a_slot", "crown")
        self.assertNotIn("not_a_slot", self.model.decorations)

    def test_toggle_gravity_flips_flag(self):
        before = self.model.enable_gravity
        self.assertEqual(self.model.toggle_gravity(), not before)


class TestTickAndFocus(PetModelTestBase):
    """状态流逝与番茄钟。"""

    def test_tick_decreases_hunger_and_energy(self):
        self.model.hunger = 80.0
        self.model.energy = 80.0
        self.model.tick(60.0)
        self.assertLess(self.model.hunger, 80.0)
        self.assertLess(self.model.energy, 80.0)

    def test_tick_ignores_non_positive_delta(self):
        self.model.hunger = 80.0
        self.model.tick(0)
        self.model.tick(-10)
        self.assertEqual(self.model.hunger, 80.0)

    def test_sleeping_restores_energy(self):
        self.model.is_sleeping = True
        self.model.energy = 50.0
        self.model.tick(60.0)
        self.assertGreater(self.model.energy, 50.0)

    def test_values_never_exceed_bounds(self):
        for _ in range(50):
            self.model.tick(120.0)
        for value in (self.model.hunger, self.model.mood, self.model.energy, self.model.cleanliness):
            self.assertGreaterEqual(value, 0.0)
            self.assertLessEqual(value, 100.0)

    def test_focus_timer_finishes_and_notifies(self):
        fired = []
        self.model.on_focus_finish = lambda: fired.append(True)
        self.model.start_focus_timer(minutes=1)
        self.assertTrue(self.model.is_studying)
        self.assertEqual(self.model.study_time_left, 60)
        self.model.tick(61.0)
        self.assertFalse(self.model.is_studying)
        self.assertEqual(fired, [True])

    def test_cancel_focus_timer(self):
        self.model.start_focus_timer(minutes=25)
        self.model.cancel_focus_timer()
        self.assertFalse(self.model.is_studying)


class TestPersistence(PetModelTestBase):
    """存档读写：保存后重新构造必须能完整还原。"""

    def test_save_and_reload_roundtrip(self):
        self.model.set_skin("dog_shiba")
        self.model.growth = 345.0
        self.model.coins = 777
        self.model.level = 4
        self.model.hunger = 42.5
        self.model.set_decoration("head", "crown")
        self.model.set_habitat("neon_matrix")
        self.model.save_to_disk()

        reloaded = PetModel()
        self.assertEqual(reloaded.skin_id, "dog_shiba")
        self.assertEqual(reloaded.pet_type, "dog")
        self.assertEqual(reloaded.growth, 345.0)
        self.assertEqual(reloaded.coins, 777)
        self.assertEqual(reloaded.level, 4)
        self.assertAlmostEqual(reloaded.hunger, 42.5)
        self.assertEqual(reloaded.decorations["head"], "crown")
        self.assertEqual(reloaded.habitat, "neon_matrix")

    def test_reload_clamps_out_of_range_values(self):
        self.model.hunger = 999.0
        self.model.level = 500
        self.model.user_scale_offset = 99.0
        self.model.save_to_disk()

        reloaded = PetModel()
        self.assertLessEqual(reloaded.hunger, 100.0)
        self.assertLessEqual(reloaded.level, 99)
        self.assertLessEqual(reloaded.user_scale_offset, 1.35)

    def test_corrupt_save_file_does_not_crash(self):
        with open(self.model.save_file, "w", encoding="utf-8") as f:
            f.write("{ this is not valid json ")
        reloaded = PetModel()  # 不应抛异常
        self.assertEqual(reloaded.level, 1)

    def test_missing_save_file_yields_defaults(self):
        if os.path.exists(self.model.save_file):
            os.remove(self.model.save_file)
        fresh = PetModel()
        self.assertEqual(fresh.level, 1)
        self.assertEqual(fresh.skin_id, "cat_calico")


class TestSystemMonitor(unittest.TestCase):
    """系统监控：节流缓存与字段契约（纯标准库，无 Qt 依赖）。"""

    def test_get_system_stats_shape(self):
        from pet.system_monitor import get_system_stats

        stats = get_system_stats()
        for key in ("cpu", "memory", "mem_total_gb", "uptime"):
            self.assertIn(key, stats)
        self.assertGreaterEqual(stats["cpu"], 0)
        self.assertLessEqual(stats["cpu"], 100)
        self.assertGreaterEqual(stats["memory"], 0)
        self.assertLessEqual(stats["memory"], 100)

    def test_repeated_calls_are_throttled(self):
        from pet.system_monitor import get_system_stats

        first = get_system_stats()
        second = get_system_stats()
        self.assertEqual(first, second, "0.8s 节流窗口内应直接命中缓存")


if __name__ == "__main__":
    unittest.main(verbosity=2)
