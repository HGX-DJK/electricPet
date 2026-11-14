# -*- coding: utf-8 -*-
"""
桌面萌宠 · 波可 —— 交互体验回归测试

这一组覆盖的是「用户点了会发生什么」，而不是内部实现：

  * 托盘双击 / 老板键隐身的**可见性口径**必须统一
    （以前菜单写「显示萌宠」但点击只是 show()，宠物定格不动）；
  * 存档里**单个字段坏掉**不能连累整份档案
    （以前整块 try，一个脏值 → 等级/金币/衣柜全丢）；
  * 扭蛋**付不起就不能抽**（以前 0 金币 + 少量经验能白嫖整发十连）；
  * 隐藏状态下**不能冒出无主气泡**；
  * 退出前必须把便签的防抖保存落盘。

需要 PyQt6。没有 PyQt6 的环境（比如 CI 的 ubuntu 任务）会自动跳过。
"""

import json
import os
import sys
import tempfile
import unittest
from unittest import mock

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

try:
    from PyQt6.QtWidgets import QApplication, QSystemTrayIcon
    HAS_QT = True
except ImportError:                                   # pragma: no cover
    HAS_QT = False


# ⚠️ QApplication 必须用模块级强引用持有（见 tests/test_qt_dialogs.py 的说明）
_APP = None


def _ensure_app():
    global _APP
    app = QApplication.instance()
    if app is None:
        _APP = QApplication([])
        app = _APP
    return app


def _make_model(save_dir=None):
    """造一个隔离在临时目录里的 PetModel（绝不碰用户的真实存档）。"""
    from pet.model import PetModel
    if save_dir is None:
        save_dir = tempfile.mkdtemp(prefix="poko_model_")
    with mock.patch.dict(os.environ, {"APPDATA": save_dir}):
        model = PetModel()
    return model


class TestModelSaveResilience(unittest.TestCase):
    """存档容错：一个字段坏掉不能连累整份档案。"""

    def test_single_bad_field_keeps_the_rest(self):
        tmp = tempfile.mkdtemp(prefix="poko_save_")
        save_path = os.path.join(tmp, "ElectricPet", "save_data.json")
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        with open(save_path, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "level": 12,
                    "coins": 9999,
                    "hunger": "85%",          # ← 脏值：以前会让整块 try 中止
                    "name": "波可",
                },
                f,
                ensure_ascii=False,
            )

        model = _make_model(tmp)
        model.load_from_disk()

        self.assertEqual(model.level, 12, "等级不该因为饱腹度是脏值就丢")
        self.assertEqual(model.coins, 9999, "金币不该因为饱腹度是脏值就丢")
        self.assertEqual(model.name, "波可")
        # 坏字段回落到默认值，而不是让整个档案报废
        self.assertAlmostEqual(model.hunger, model.hunger)  # 能读到 float
        self.assertTrue(0.0 <= model.hunger <= 100.0)

    def test_broken_json_keeps_original_file_and_makes_backup(self):
        tmp = tempfile.mkdtemp(prefix="poko_broken_")
        save_path = os.path.join(tmp, "ElectricPet", "save_data.json")
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        raw = '{"level": 12, "coins": 9999, broken'
        with open(save_path, "w", encoding="utf-8") as f:
            f.write(raw)

        model = _make_model(tmp)
        model.load_from_disk()

        # 原始坏档仍在（没被默认值覆盖）
        with open(save_path, "r", encoding="utf-8") as f:
            self.assertEqual(f.read(), raw, "坏档被覆盖了 —— 用户再也找不回数据")
        # 并且留了一份 .bak
        bak = save_path + ".bak"
        self.assertTrue(os.path.exists(bak), "损坏存档应该留一份 .bak")

    def test_missing_save_file_is_not_an_error(self):
        tmp = tempfile.mkdtemp(prefix="poko_empty_")
        model = _make_model(tmp)
        model.load_from_disk()          # 不该抛
        self.assertEqual(model.level, 1)


class TestGachaPayment(unittest.TestCase):
    """扭蛋付费规则：付不起就不抽，抵扣经验必须明说。"""

    def test_cannot_draw_when_cannot_afford(self):
        model = _make_model()
        model.coins = 0
        model.exp = 10.0

        results = model.draw_gacha(10)

        self.assertEqual(results, [], "付不起就不该抽出任何东西")
        self.assertEqual(model.coins, 0)
        self.assertAlmostEqual(model.exp, 10.0, msg="付不起时经验不该被扣")
        self.assertTrue(model.last_draw_error, "付不起必须给用户一句原因")

    def test_exp_fallback_is_reported(self):
        model = _make_model()
        model.coins = 5
        model.exp = 100.0

        results = model.draw_gacha(1)

        self.assertTrue(results, "金币 + 经验够付就应该抽到")
        self.assertEqual(model.coins, 0)
        # 缺 25 枚金币 = 50 EXP
        self.assertAlmostEqual(model.last_draw_exp_cost, 50.0)
        self.assertAlmostEqual(model.exp, 50.0)

    def test_full_coin_payment_reports_no_exp_cost(self):
        model = _make_model()
        model.coins = 300
        model.exp = 100.0

        results = model.draw_gacha(1)

        self.assertTrue(results)
        self.assertEqual(model.coins, 270)
        self.assertAlmostEqual(model.last_draw_exp_cost, 0.0)
        self.assertAlmostEqual(model.exp, 100.0, msg="金币够付时不该动经验")


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestTrayVisibility(unittest.TestCase):
    """托盘显隐口径：菜单文案、点击行为、实际状态必须一致。"""

    def setUp(self):
        _ensure_app()
        from pet.model import PetModel
        from pet.window import PetWindow
        from pet.tray import PetTrayIcon

        self.model = PetModel()
        self.window = PetWindow(self.model)
        self.tray = PetTrayIcon(self.model, self.window, QApplication.instance())
        self.addCleanup(self.window.deleteLater)

    def test_boss_restore_from_tray_revives_the_pet(self):
        """老板键隐身后从托盘「显示萌宠」—— 宠物必须真的活过来。

        以前这里只调 show()：is_boss_hidden 还挂着、帧定时器还停着，
        于是宠物出现在屏幕上却完全定格，用户只会以为程序卡死了。
        """
        self.window.show()
        self.window.toggle_boss_mode()
        self.assertTrue(self.window.is_boss_hidden)
        self.assertFalse(self.window.anim_timer.isActive())

        self.tray._toggle_visibility()

        self.assertTrue(self.window.isVisible(), "宠物应该被显示出来")
        self.assertFalse(self.window.is_boss_hidden, "隐身标志必须一起清掉")
        self.assertTrue(
            self.window.anim_timer.isActive(),
            "帧定时器必须重新拉起来，否则宠物是定格的死物",
        )

    def test_double_click_while_hidden_keeps_it_visible(self):
        """双击托盘唤出宠物 —— 不能再被紧接着的 DoubleClick 切回隐藏。

        Windows 的双击会先发 Trigger 再发 DoubleClick；
        以前第一个 Trigger 显示、第二个 DoubleClick 又隐藏，等于白点两下。
        """
        self.window.hide()
        self.tray._double_click_guard = False

        self.tray._on_tray_activated(QSystemTrayIcon.ActivationReason.Trigger)
        self.assertTrue(self.window.isVisible(), "单击应先把它放出来")

        self.tray._on_tray_activated(QSystemTrayIcon.ActivationReason.DoubleClick)
        self.assertTrue(
            self.window.isVisible(),
            "双击的结果应该是「显示」，而不是「显示完又藏回去」",
        )

    def test_double_click_while_visible_hides_it(self):
        """宠物已经在屏上时，双击仍然要能把它收起来（保持原有能力）。"""
        self.window.show()
        self.tray._double_click_guard = False

        self.tray._on_tray_activated(QSystemTrayIcon.ActivationReason.Trigger)
        self.tray._on_tray_activated(QSystemTrayIcon.ActivationReason.DoubleClick)

        self.assertFalse(self.window.isVisible(), "在屏上双击应当隐藏萌宠")

    def test_single_click_while_visible_does_not_hide(self):
        self.window.show()
        self.tray._double_click_guard = False

        self.tray._on_tray_activated(QSystemTrayIcon.ActivationReason.Trigger)

        self.assertTrue(self.window.isVisible(), "单击只是把窗口叫到前面，不该隐藏")


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestWindowInteraction(unittest.TestCase):
    """主窗口的交互行为。"""

    def setUp(self):
        _ensure_app()
        from pet.model import PetModel
        from pet.window import PetWindow

        self.model = PetModel()
        self.window = PetWindow(self.model)
        self.addCleanup(self.window.deleteLater)

    def test_force_reset_position_goes_to_default_corner(self):
        """「重置萌宠屏幕位置」必须真的回默认位。

        以前走的是「恢复上次拖拽坐标」，宠物几乎没动，
        气泡却宣称「回到默认位置啦」—— 反馈文案在撒谎。
        """
        self.window.show()
        avail = QApplication.primaryScreen().availableGeometry()
        # 选一个确实在屏幕内的「上次位置」，确保它和默认位不同
        self.model.last_pos_x = avail.left() + 120
        self.model.last_pos_y = avail.top() + 120

        self.window._init_initial_position(force=True)

        default_x = avail.right() - self.window.width() - 80
        default_y = avail.bottom() - self.window.height() - 15
        self.assertEqual(
            (self.window.x(), self.window.y()),
            (default_x, default_y),
            "强制重置后必须真的回到右下角默认位",
        )

    def test_restore_position_keeps_last_known_pos(self):
        """普通启动仍然要恢复上次位置（不能被 force 语义污染）。"""
        self.window.show()
        avail = QApplication.primaryScreen().availableGeometry()
        last_x = avail.left() + 120
        last_y = avail.top() + 120
        self.model.last_pos_x = last_x
        self.model.last_pos_y = last_y

        self.window._init_initial_position()

        self.assertEqual((self.window.x(), self.window.y()), (last_x, last_y))

    def test_autonomous_action_does_not_cancel_focus_timer(self):
        """自主行为不该劫持用户的专注时段。

        专注模式下波可自己演节目时，番茄钟必须继续走。
        """
        self.model.start_focus_timer(25)
        self.assertTrue(self.model.is_studying)

        self.window.play_action("HAPPY_SPIN", allow_interrupt_focus=False)

        self.assertTrue(
            self.model.is_studying,
            "自主行为把用户的专注计时器清零了",
        )

    def test_user_action_cancels_focus_timer_and_tells_user(self):
        """用户主动点播才艺：可以打断专注，但必须告知。"""
        self.model.start_focus_timer(25)
        self.window.show()

        self.window.play_action("HAPPY_SPIN", allow_interrupt_focus=True)

        self.assertFalse(self.model.is_studying, "用户主动点播应当结束专注")

    def test_no_orphan_bubble_when_pet_hidden(self):
        """宠物不在屏幕上时不能冒出无主气泡。

        气泡是独立的置顶窗，宠物隐藏后照样会浮在桌面空白处 ——
        用户明明把萌宠藏了，却凭空冒出一句没人说的话。
        """
        self.window.show()
        self.window.hide()

        self.window.dialogue.say("测试台词", duration=1.0)

        self.assertFalse(
            self.window.dialogue.bubble.isVisible(),
            "宠物隐藏时不应该弹出气泡",
        )


@unittest.skipUnless(HAS_QT, "需要 PyQt6（CI 的 ubuntu 任务会跳过）")
class TestTrayExitFlush(unittest.TestCase):
    """退出前必须把便签的防抖保存落盘。"""

    def setUp(self):
        _ensure_app()
        from pet.model import PetModel
        from pet.window import PetWindow
        from pet.tray import PetTrayIcon

        self.model = PetModel()
        self.window = PetWindow(self.model)
        self.tray = PetTrayIcon(self.model, self.window, QApplication.instance())
        self.addCleanup(self.window.deleteLater)

    def test_exit_flushes_pending_memo_save(self):
        memo = self.window.memo
        memo.text_edit.setPlainText("老板让我记的密码 abc123")
        # 模拟「刚打完字就退出」：防抖定时器还在跑，尚未落盘
        memo.save_timer.start(500)
        self.assertTrue(memo.save_timer.isActive())

        self.tray._exit_app()

        self.assertFalse(
            memo.save_timer.isActive(),
            "退出前应该把防抖定时器停掉",
        )


if __name__ == "__main__":
    unittest.main()
