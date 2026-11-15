# -*- coding: utf-8 -*-
"""
桌面萌宠 · 波可 —— 留存钩子回归测试

这一组测的是**「用户为什么愿意明天还来」**这条链路上最容易回归的地方。

覆盖三件事：

1. **每日陪伴津贴在重启后仍能领到**
   —— 以前签到判断用的是 ``total_days``，而 ``load_from_disk`` 末尾会把
   ``total_days`` 覆盖成"按出生时间推算的当前天数"，于是
   ``current_days > total_days`` 永远不成立：
   用户「关掉程序、明天再打开」这种**最常见**的用法，一次奖励都拿不到。
   现在改用独立的 ``last_daily_claim_day`` 做幂等凭据。

2. **首次运行引导只播一次**
   —— 引导是"给第一次的人看的"，第二遍出现就变成打扰。

3. **生理需求提醒不复读**
   —— 以前 ``update()`` 跟着 60FPS 定时器走（每秒 60 次），配上
   ``random.random() < 0.003`` ⇒ 期望约 5.6 秒就弹一次「肚肚好饿」，
   而且这条分支没有任何时间闸门。现在改成**边沿触发**：
   只在状态刚跌破阈值那一刻说一次。

运行：
    python -m unittest discover -s tests -t . -v
    （Windows 无头环境请先设 QT_QPA_PLATFORM=offscreen）
"""

import os
import sys
import tempfile
import time
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from pet.audio import sound_manager  # noqa: E402
from pet.model import PetModel  # noqa: E402

try:
    from PyQt6.QtWidgets import QApplication
    HAS_QT = True
except ImportError:                                   # pragma: no cover
    HAS_QT = False

# ⚠️ QApplication 必须用模块级强引用持有，否则函数返回后被 GC，
#    紧接着构造 QWidget 会抛 "Must construct a QApplication before a QWidget"。
_APP = None


def _ensure_app():
    global _APP
    app = QApplication.instance()
    if app is None:
        _APP = QApplication([])
        app = _APP
    return app


class _IsolatedModelTestBase(unittest.TestCase):
    """把存档目录隔离到临时区，并静音音效线程。"""

    def setUp(self):
        self._tmpdir = tempfile.TemporaryDirectory(prefix="poko_retention_")
        self._saved_appdata = os.environ.get("APPDATA")
        os.environ["APPDATA"] = self._tmpdir.name
        self._saved_muted = sound_manager.muted
        sound_manager.muted = True

    def tearDown(self):
        sound_manager.muted = self._saved_muted
        if self._saved_appdata is None:
            os.environ.pop("APPDATA", None)
        else:
            os.environ["APPDATA"] = self._saved_appdata
        self._tmpdir.cleanup()

    def _new_model(self):
        return PetModel()


class TestDailyClaim(_IsolatedModelTestBase):
    """每日跨天陪伴津贴。"""

    def _make_day_two(self, model):
        """把模型推到「第二天」——出生时间往回拨 24 小时。"""
        model.birth_time = time.time() - 86400
        model.last_daily_claim_day = 1
        model.total_days = 1

    def test_claim_fires_when_day_rolls_over(self):
        model = self._new_model()
        self._make_day_two(model)
        model.coins = 100
        model.tick(1.0)
        self.assertEqual(model.coins, 120, "跨天应当发放 +20 金币")
        self.assertEqual(model.last_daily_claim_day, 2)

    def test_claim_is_idempotent_within_same_day(self):
        """同一天反复 tick 只能领一次 —— 否则每秒都在发奖。"""
        model = self._new_model()
        self._make_day_two(model)
        model.coins = 100
        model.tick(1.0)
        after_first = model.coins
        for _ in range(5):
            model.tick(1.0)
        self.assertEqual(model.coins, after_first, "同一天不该重复发奖")

    def test_claim_still_fires_after_restart(self):
        """⚠️ 这条是本轮的核心回归。

        用户「关掉程序、明天再打开」——这条路径以前**一次奖励都拿不到**。
        """
        model = self._new_model()
        self._make_day_two(model)
        model.coins = 100
        model.save_to_disk()

        # 模拟重启：重新构造模型（会走 load_from_disk）
        reborn = self._new_model()
        reborn.coins = 100
        reborn.tick(1.0)
        self.assertEqual(
            reborn.coins, 120,
            "重启后跨天的每日陪伴津贴必须照常发放",
        )

    def test_old_save_without_claim_field_does_not_double_pay(self):
        """老存档没有 last_daily_claim_day 键 —— 不能因此重复发奖。"""
        model = self._new_model()
        self._make_day_two(model)
        model.coins = 100
        model.save_to_disk()

        # 手工把存档里的新字段抹掉，模拟旧版本存档
        import json
        path = model.save_file
        with open(path, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        data.pop("last_daily_claim_day", None)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False)

        reborn = self._new_model()
        # 老存档的 total_days 是 1，而当前是第 2 天 → 应当补发一次
        self.assertEqual(reborn.last_daily_claim_day, 1)
        reborn.coins = 100
        reborn.tick(1.0)
        self.assertEqual(reborn.coins, 120)


class TestFirstRunGuide(_IsolatedModelTestBase):
    """首次运行引导只播一次。"""

    def test_fresh_install_is_first_run(self):
        model = self._new_model()
        self.assertTrue(model.first_run, "全新安装应当是首次运行")

    def test_first_run_flag_persists_after_being_consumed(self):
        model = self._new_model()
        model.first_run = False
        model.save_to_disk()

        reborn = self._new_model()
        self.assertFalse(reborn.first_run, "引导播过之后不该再播")


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestNeedAlertThrottle(_IsolatedModelTestBase):
    """生理需求提醒：边沿触发，不复读。"""

    def setUp(self):
        super().setUp()
        _ensure_app()
        from pet.dialogue import DialogueManager
        self._dlg_cls = DialogueManager

    def _make_dialogue(self):
        model = self._new_model()
        dlg = self._dlg_cls(model)
        self.addCleanup(dlg.bubble.close)
        return dlg

    def test_alert_fires_once_on_threshold_crossing(self):
        dlg = self._make_dialogue()
        dlg.model.hunger = 24.0
        now = time.time()
        self.assertIsNotNone(dlg._pick_need_alert(now), "跌破阈值那一刻应当提醒一次")
        self.assertIsNone(
            dlg._pick_need_alert(now + 1),
            "状态没变就不该再说 —— 这是以前变成每 5.6 秒复读的根因",
        )

    def test_alert_repeats_after_state_recovers(self):
        dlg = self._make_dialogue()
        dlg.model.hunger = 24.0
        now = time.time()
        self.assertIsNotNone(dlg._pick_need_alert(now))

        dlg.model.hunger = 90.0          # 喂饱了
        self.assertIsNone(dlg._pick_need_alert(now + 1), "状态回升时不该提醒")

        dlg.model.hunger = 20.0          # 又饿了
        self.assertIsNotNone(
            dlg._pick_need_alert(now + 2),
            "状态回落后再次跌破，应当重新提醒",
        )

    def test_long_neglect_escalates_tone(self):
        """长时间没人管 → 换一种语气再说一次，而不是复读同一句。"""
        dlg = self._make_dialogue()
        dlg.model.hunger = 24.0
        now = time.time()
        first = dlg._pick_need_alert(now)
        self.assertIsNotNone(first)

        later = dlg._pick_need_alert(now + dlg._NEED_ALERT_COOLDOWN + 1)
        self.assertIsNotNone(later, "冷却到期应当升级提醒一次")
        self.assertNotEqual(first, later, "升级提醒应当换一句文案")

    def test_hidden_pet_does_not_consume_the_alert(self):
        """⚠宠物被隐藏时，告警不能被「吞掉」。

        say() 在宠物不可见（老板键 / 托盘隐藏）时静默返回，
        但边沿状态却已经被标记成「已提醒」——
        用户从托盘把波可唤回来时，它明明饿着却一句话不说。
        """
        dlg = self._make_dialogue()
        dlg.model.hunger = 24.0

        class _HiddenWindow:
            def isVisible(self):
                return False

        # 构造时那句问候气泡会一直挂着，isVisible() 为真时 update() 整段被跳过，
        # 所以这里直接 hide()（dismiss 是渐隐，isVisible() 还会true一会儿）。
        dlg.bubble.hide()
        self.assertFalse(dlg.bubble.isVisible())
        dlg.set_pet_window(_HiddenWindow())  # 假装宠物被老板键藏起来了

        dlg.update(0.016)
        self.assertFalse(
            dlg._need_low.get("hunger", False),
            "宠物不可见时不应该消耗掉这次提醒",
        )

        # 唤回来之后：这次提醒应该补上
        dlg.set_pet_window(None)
        dlg.update(0.016)
        self.assertTrue(
            dlg._need_low.get("hunger", False),
            "宠物回到屏幕上后应当立刻开口说饿",
        )

    def test_healthy_pet_is_never_alerted(self):
        dlg = self._make_dialogue()
        dlg.model.hunger = 90.0
        dlg.model.cleanliness = 90.0
        dlg.model.mood = 90.0
        self.assertIsNone(dlg._pick_need_alert(time.time()))


if __name__ == "__main__":
    unittest.main()
