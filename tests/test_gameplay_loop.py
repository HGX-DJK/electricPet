# -*- coding: utf-8 -*-
"""第五轮：可玩性 / 可交互性回归测试。

这一组测的是「养成数值到底有没有变成玩法」以及「交互有没有层次」。

覆盖四件事：

1. **摸头要返回数值增量** —— 桌面端此前**从不显示**摸头拿到了什么，
   而 Flutter 端每一次交互都有飘字。现在两端都返回增量供 UI 兑现。
   且必须返回**实际**增量：心情已经 99 时只加了 1 点，台词不能写「+8 心情」。

2. **连摸连击** —— 摸头反馈此前完全是平的（连摸 10 次和摸 1 次没区别），
   桌面端现在有 2.6 秒窗口的 5 连击惊喜，与 Flutter 端一致。

3. **扭卡奖池是唯一真源** —— 奖池从 draw_gacha() 函数体提到模块级 GACHA_POOL，
   界面上的「图鉴」面板才能读到它；两端的重复件退款金额也必须一致。

4. **重复件退款由 UI 兑现** —— 模型只返回 refund_coins，不直接改金币。
   放模型层会让「抽一次花多少金币」变成随机数（既有测试正是靠它做确定性断言）。

运行：
    python -m unittest discover -s tests -t . -v
    （Windows 无头环境请先设 QT_QPA_PLATFORM=offscreen）
"""

import os
import sys
import tempfile
import unittest

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from pet.audio import sound_manager  # noqa: E402
from pet.model import GACHA_POOL, PetModel  # noqa: E402

try:
    from PyQt6.QtWidgets import QApplication
    HAS_QT = True
except ImportError:                                   # pragma: no cover
    HAS_QT = False

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
        self._tmpdir = tempfile.TemporaryDirectory(prefix="poko_gameplay_")
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


class TestPetHeadFeedback(_IsolatedModelTestBase):
    """摸头必须返回数值增量，且是**实际**增量。"""

    def test_pet_head_returns_deltas(self):
        model = self._new_model()
        model.mood = 50.0
        model.exp = 0.0

        gain = model.pet_head()

        self.assertIn("mood", gain)
        self.assertIn("exp", gain)
        self.assertIn("intimacy", gain)
        self.assertAlmostEqual(gain["mood"], 8.0, msg="心情应加满 8 点")
        self.assertAlmostEqual(gain["exp"], 5.0)
        self.assertEqual(gain["intimacy"], 4)
        self.assertAlmostEqual(model.mood, 58.0)
        self.assertAlmostEqual(model.exp, 5.0)

    def test_pet_head_reports_actual_mood_delta_when_capped(self):
        """⚠️ 心情已经 99 时只加了 1 点 —— 台词不能写「+8 心情」。

        这是「反馈必须诚实」的底线：数字和实际到账对不上，
        玩家很快就再也不信这些飘字了。
        """
        model = self._new_model()
        model.mood = 99.0

        gain = model.pet_head()

        self.assertAlmostEqual(model.mood, 100.0)
        self.assertAlmostEqual(
            gain["mood"], 1.0,
            msg="封顶时必须报实际增量（1），不能报标称值（8）",
        )

    def test_pet_head_actually_raises_intimacy(self):
        model = self._new_model()
        before = model.intimacy
        model.pet_head()
        self.assertEqual(model.intimacy, before + 4)


class TestGachaPoolIsSingleSource(_IsolatedModelTestBase):
    """扭卡奖池：唯一真源 + 重复件退款的同源同语义。"""

    def test_pool_is_module_level_and_unique(self):
        self.assertGreaterEqual(len(GACHA_POOL), 15, "奖池不该是空的")
        codes = [item[2] for item in GACHA_POOL]
        self.assertEqual(
            len(codes), len(set(codes)),
            "奖池里出现了重复的物品代号 —— 抽卡会永远抽不到其中一件",
        )

    def test_draw_gacha_uses_the_same_pool(self):
        """draw_gacha 抽出来的每一件都必须来自 GACHA_POOL。"""
        model = self._new_model()
        model.coins = 5000
        results = model.draw_gacha(10)
        pool_codes = {item[2] for item in GACHA_POOL}
        for r in results:
            self.assertIn(r["code"], pool_codes)

    def test_duplicate_refund_is_reported_but_not_applied_in_model(self):
        """模型只报「该退多少」，**不直接改金币** —— 兑现交给 UI。

        放模型层的话，「抽一次实际花多少金币」就变成随机数了
        （既有测试 test_ten_draw_costs_270_coins 正是靠这个确定性断言的）。
        """
        model = self._new_model()
        model.coins = 1000
        # 把整个奖池都设为已拥有 ⇒ 抽到的必然全是重复件（无随机性）
        model.unlocked_items = [item[2] for item in GACHA_POOL]

        before = model.coins
        results = model.draw_gacha(10)
        refunded = [r for r in results if r["refund_coins"] > 0]

        self.assertEqual(len(refunded), 10, "全已拥有时抽到的应全是重复件")
        for r in refunded:
            self.assertEqual(r["refund_coins"], PetModel.GACHA_DUPLICATE_REFUND)
        self.assertEqual(
            model.coins, before - 270,
            "模型层不该直接退币 —— 退币由 UI 统一兑现（与 Flutter 端同构）",
        )

    def test_new_item_has_no_refund(self):
        model = self._new_model()
        model.coins = 1000
        model.unlocked_items = []

        results = model.draw_gacha(1)

        self.assertEqual(results[0]["refund_coins"], 0)
        self.assertTrue(results[0]["is_new"])

    def test_duplicate_refund_amount_matches_flutter(self):
        """两端退款金额必须一致（Flutter: gachaDuplicateRefund = 15）。"""
        self.assertEqual(PetModel.GACHA_DUPLICATE_REFUND, 15)


class TestRefundIsDurable(_IsolatedModelTestBase):
    """退款必须落盘：App 被强杀也不能「扣了币、退款没了」。

    ⚠ draw_gacha() 自己在返回前已经 save_to_disk() 过，
    而退款是在它**之后**由界面兑现的 —— 不补这一次落盘，
    玩家就会莫名其妙少一笔钱（这个仓库最在意的一类 bug）。
    """

    def test_credit_refund_adds_coins_and_persists_them(self):
        import json

        model = self._new_model()
        model.coins = 1000
        model.unlocked_items = [item[2] for item in GACHA_POOL]
        before = model.coins

        results = model.draw_gacha(10)
        refund = sum(int(r["refund_coins"]) for r in results)
        self.assertEqual(refund, 10 * PetModel.GACHA_DUPLICATE_REFUND)

        model.credit_refund(refund)

        self.assertEqual(model.coins, before - 270 + refund)

        # 盘上的金币必须也是退完之后的数
        with open(model.save_file, "r", encoding="utf-8") as fh:
            saved = json.load(fh)
        self.assertEqual(
            int(saved["coins"]), before - 270 + refund,
            "退款只在内存里 —— App 被强杀这笔钱就没了",
        )

    def test_credit_refund_of_zero_does_nothing(self):
        model = self._new_model()
        before = model.coins
        self.assertEqual(model.credit_refund(0), before)
        self.assertEqual(model.coins, before)


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestPetTouchCombo(_IsolatedModelTestBase):
    """连摸连击：让最自然的交互有层次（对齐 Flutter 端的 5 连击）。"""

    def setUp(self):
        super().setUp()
        _ensure_app()
        from pet.window import PET_COMBO_TARGET, PET_COMBO_WINDOW_MS, PetWindow
        self.PetWindow = PetWindow
        self.TARGET = PET_COMBO_TARGET
        self.WINDOW = PET_COMBO_WINDOW_MS

    def _make_window(self):
        model = self._new_model()
        w = self.PetWindow(model)
        self.addCleanup(w.deleteLater)
        return w

    def test_combo_counter_increments_and_resets(self):
        w = self._make_window()

        self.assertEqual(w._pet_combo, 0)
        w._register_pet_touch()
        self.assertEqual(w._pet_combo, 1)
        w._register_pet_touch()
        self.assertEqual(w._pet_combo, 2)

        # 窗口期过了就该断开（用户不是连着摸的）
        w._reset_pet_combo()
        self.assertEqual(w._pet_combo, 0)

    def test_combo_target_rewards_the_player(self):
        """连摸到目标次数 → 真奖励（金币 + 经验），不能只是嘴上说说。"""
        w = self._make_window()
        model = w.model
        coins_before = model.coins
        exp_before = model.exp

        for _ in range(self.TARGET):
            w._handle_pet_touch()

        self.assertEqual(w._pet_combo, 0, "触发后连击计数要归零")
        self.assertGreater(model.coins, coins_before, "连击必须给出金币奖励")
        self.assertGreater(model.exp, exp_before, "连击必须给出经验奖励")

    def test_combo_does_not_reward_below_target(self):
        w = self._make_window()
        model = w.model
        coins_before = model.coins

        for _ in range(self.TARGET - 1):
            w._handle_pet_touch()

        self.assertEqual(
            model.coins, coins_before,
            "没摸够次数不该发奖励",
        )

    def test_combo_window_matches_flutter(self):
        """2.6 秒窗口 —— 与 Flutter 端 _comboResetTimer 一致。"""
        self.assertEqual(self.WINDOW, 2600)
        self.assertEqual(self.TARGET, 5)


if __name__ == "__main__":
    unittest.main()
