import 'package:flutter/material.dart';
import '../theme/poko_theme.dart';
import '../widgets/bouncy_touch_feedback.dart';
import 'package:flutter/services.dart';
import '../models/pet_model.dart';
import '../widgets/poko_tap_target.dart';

/// 波可的奇妙背包 (优雅上拉抽屉 / 萌宠日常照料与生活工具箱)
/// 专注于日常护理、逗猫玩具与实用工具，不与外层换装/绝活重复
class PokoBackpackDrawer extends StatelessWidget {
  final PetModel model;
  final bool isNight;
  final int memoCount;
  final VoidCallback onFeedTap;
  final VoidCallback onLaserTap;
  final VoidCallback onTeaseTap;
  final VoidCallback onMemoTap;
  final VoidCallback onBathTap;
  final VoidCallback onSleepTap;
  final VoidCallback onToggleFloating;
  final VoidCallback? onScanBackupTap;
  final VoidCallback? onCopySaveCodeTap;
  final VoidCallback? onPasteSaveCodeTap;
  final VoidCallback? onForceBackupTap;

  const PokoBackpackDrawer({
    super.key,
    required this.model,
    required this.isNight,
    this.memoCount = 0,
    required this.onFeedTap,
    required this.onLaserTap,
    required this.onTeaseTap,
    required this.onMemoTap,
    required this.onBathTap,
    required this.onSleepTap,
    required this.onToggleFloating,
    this.onScanBackupTap,
    this.onCopySaveCodeTap,
    this.onPasteSaveCodeTap,
    this.onForceBackupTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isNight
            ? const Color(0xFF161334).withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(PokoRadius.xl)),
        border: Border.all(
          color: isNight
              ? PokoPalette.indigo_700.withValues(alpha: 0.5)
              : PokoPalette.slate_200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isNight
                ? const Color(0xFF09071A).withValues(alpha: 0.7)
                : PokoPalette.indigo_500.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // 1. 顶部拖拽把手
            Center(
              child: Container(
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isNight
                      ? PokoPalette.slate_600.withValues(alpha: 0.8)
                      : PokoPalette.slate_300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. 标题栏与实时健康状态小胶囊 + 资产看板
            //
            // ⚠️ 这里必须拆成两行。
            // 旧版把「标题 + 状态胶囊 + 金币 + 桌面悬浮 + 关闭」全塞进同一个 Row：
            // 胶囊们是固定宽度的非弹性子项，合计约 210px，而 390dp 手机上这一行
            // 只剩约 110px —— 于是标题「波可的奇妙背包」被压成 22px，屏幕上只剩
            // 一个省略号；再窄一点（360/320dp）整行还会直接溢出。
            // 现在标题独占一行，胶囊们下沉一行，各得其所。
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF262054)
                        : PokoPalette.amber_100,
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🎒', style: TextStyle(fontSize: PokoFont.subtitle)),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '波可的奇妙背包',
                        style: TextStyle(
                          fontSize: PokoFont.titleSm,
                          fontWeight: FontWeight.bold,
                          color: isNight ? Colors.white : PokoPalette.slate_800,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '日常照料与逗猫玩具',
                        style: TextStyle(
                          fontSize: PokoFont.caption,
                          color: isNight
                              ? PokoPalette.slate_400
                              : PokoPalette.slate_500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 实时健康状态小胶囊
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: PokoPalette.emerald_500.withValues(alpha: isNight ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(PokoRadius.sm),
                    border: Border.all(
                      color: PokoPalette.emerald_500.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    model.isSleeping ? '💤 伴眠中' : '✨ 元气满满',
                    style: TextStyle(
                      fontSize: PokoFont.tiny,
                      fontWeight: FontWeight.bold,
                      color: isNight ? PokoPalette.emerald_300 : PokoPalette.emerald_600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PokoTapTarget(
                  semanticLabel: '关闭背包',
                  // ⚠️ 不扩展命中区：抽屉标题栏在 320dp 窄屏上本就很挤，
                  // 关闭键占宽一点就会把「日常照料与逗猫玩具」挤成省略号。
                  // 它在右上角角落，本来就很好点 —— 留个读屏名字就够了。
                  expandHitArea: false,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isNight
                          ? const Color(0xFF241F48)
                          : PokoPalette.slate_100,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isNight
                            ? const Color(0xFF3B336A)
                            : PokoPalette.slate_200,
                      ),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isNight
                          ? PokoPalette.slate_300
                          : PokoPalette.slate_500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2.1 资产与桌面端联动胶囊行 (右对齐)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 3. 实时能量币资产看板胶囊
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: isNight ? const Color(0xFF2E2452) : PokoPalette.amber_50,
                    borderRadius: BorderRadius.circular(PokoRadius.sm),
                    border: Border.all(
                      color: PokoPalette.amber_500.withValues(alpha: 0.5),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: PokoFont.small)),
                      const SizedBox(width: 3.5),
                      Text(
                        '${model.coins}',
                        style: TextStyle(
                          fontSize: PokoFont.caption,
                          fontWeight: FontWeight.bold,
                          color: isNight ? PokoPalette.amber_200 : PokoPalette.amber_700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // 4. 全局桌面悬浮宠快捷开关
                BouncyTouchFeedback(
                  scaleDown: 0.94,
        onTap: () {
                    Navigator.of(context).pop();
                    onToggleFloating();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isNight ? PokoPalette.night_canvas : PokoPalette.indigo_50,
                      borderRadius: BorderRadius.circular(PokoRadius.sm),
                      border: Border.all(
                        color: PokoPalette.indigo_500.withValues(alpha: 0.6),
                        width: 1.0,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('📱', style: TextStyle(fontSize: PokoFont.small)),
                        SizedBox(width: 3.5),
                        Text(
                          '桌面悬浮',
                          style: TextStyle(
                            fontSize: PokoFont.caption,
                            fontWeight: FontWeight.bold,
                            color: PokoPalette.indigo_500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. 规整清爽 6 宫格功能卡片矩阵 (2列 x 3行，无冗余去重)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.1,
              children: [
                // 1. 美味投喂
                // ⚠️ 饱腹度是**每秒都在变**的数值，而这个抽屉是在打开时
                // 一次性构造好的（不会跟着主界面一起重建）——
                // 所以这张卡片必须自己监听模型，否则读数会一直停在打开那一刻。
                AnimatedBuilder(
                  animation: model,
                  builder: (context, _) => _BackpackCard(
                    icon: '🍱',
                    title: '美味投喂',
                    subtitle: '饱腹又涨好感',
                    badgeText: '${model.hunger.toInt()}%',
                    badgeColor: PokoPalette.amber_500,
                    accentColor: PokoPalette.amber_500,
                    isNight: isNight,
                    onTap: () {
                      Navigator.of(context).pop();
                      onFeedTap();
                    },
                  ),
                ),
                // 2. 神奇激光笔逗猫 (全新超高趣味交互)
                // 标题压在 4 字以内：卡片右半区还要给「新玩具」角标留位置，
                // 5 个字的标题在 360dp 窄屏上会被角标挤成省略号。
                _BackpackCard(
                  icon: '🔴',
                  title: '激光笔',
                  subtitle: '红点逗猫飞扑',
                  badgeText: '新玩具',
                  badgeColor: PokoPalette.red_500,
                  accentColor: PokoPalette.red_500,
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onLaserTap();
                  },
                ),
                // 3. 抛掷毛线球
                _BackpackCard(
                  icon: '🧶',
                  title: '抛毛线球',
                  subtitle: '抛球满地打滚',
                  accentColor: PokoPalette.pink_500,
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onTeaseTap();
                  },
                ),
                // 4. 泡泡沐浴
                // 同上：精力值也是逐秒变化的实时读数
                AnimatedBuilder(
                  animation: model,
                  builder: (context, _) => _BackpackCard(
                    icon: '🫧',
                    title: '泡泡沐浴',
                    subtitle: '香波洗香香',
                    badgeText: '${model.energy.toInt()}%',
                    badgeColor: PokoPalette.emerald_500,
                    accentColor: PokoPalette.emerald_500,
                    isNight: isNight,
                    onTap: () {
                      Navigator.of(context).pop();
                      onBathTap();
                    },
                  ),
                ),
                // 5. 伴眠哄睡 / 唤醒
                _BackpackCard(
                  icon: model.isSleeping ? '☀️' : '🌙',
                  title: model.isSleeping ? '唤醒波可' : '伴眠哄睡',
                  subtitle: model.isSleeping ? '元气满满起床' : '呼噜甜甜梦乡',
                  accentColor: PokoPalette.indigo_500,
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onSleepTap();
                  },
                ),
                // 6. 贴心便签 / 桌面悬浮 (便签 + 悬浮融合或便签优先)
                _BackpackCard(
                  icon: '📝',
                  title: '贴心便签',
                  subtitle: '生活备忘待办',
                  badgeText: memoCount > 0 ? '$memoCount 条' : null,
                  badgeColor: const Color(0xFFEAB308),
                  accentColor: const Color(0xFFEAB308),
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onMemoTap();
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4. 档案安全与防丢继承快捷工具栏 (Heritage & Backup Bar)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isNight
                    ? PokoPalette.night_canvas.withValues(alpha: 0.8)
                    : PokoPalette.slate_50,
                borderRadius: BorderRadius.circular(PokoRadius.md),
                border: Border.all(
                  color: isNight
                      ? PokoPalette.indigo_700.withValues(alpha: 0.4)
                      : PokoPalette.slate_200,
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🛡️ ', style: TextStyle(fontSize: PokoFont.body)),
                          Text(
                            '档案守护与防丢继承',
                            style: TextStyle(
                              fontSize: PokoFont.small,
                              fontWeight: FontWeight.bold,
                              color: isNight ? PokoPalette.slate_200 : PokoPalette.slate_700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '防卸载 · 免登录',
                        style: TextStyle(
                          fontSize: PokoFont.tiny,
                          color: isNight ? PokoPalette.indigo_400 : PokoPalette.indigo_500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // 1. 扫描历史档案
                      Expanded(
                        child: _BackupActionChip(
                          icon: '🔄',
                          label: '扫描历史档案',
                          isNight: isNight,
                          onTap: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                            onScanBackupTap?.call();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 2. 复制存档码
                      Expanded(
                        child: _BackupActionChip(
                          icon: '📋',
                          label: '复制存档口令',
                          isNight: isNight,
                          onTap: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                            onCopySaveCodeTap?.call();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 3. 粘贴口令恢复
                      Expanded(
                        child: _BackupActionChip(
                          icon: '📥',
                          label: '导入口令恢复',
                          isNight: isNight,
                          onTap: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                            onPasteSaveCodeTap?.call();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _BackupActionChip extends StatelessWidget {
  final String icon;
  final String label;
  final bool isNight;
  final VoidCallback onTap;

  const _BackupActionChip({
    required this.icon,
    required this.label,
    required this.isNight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PokoRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        decoration: BoxDecoration(
          color: isNight ? const Color(0xFF2E2A66) : Colors.white,
          borderRadius: BorderRadius.circular(PokoRadius.sm),
          border: Border.all(
            color: isNight ? PokoPalette.indigo_700.withValues(alpha: 0.5) : PokoPalette.slate_300,
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isNight ? 0.2 : 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: PokoFont.bodyMd)),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: PokoFont.tiny,
                fontWeight: FontWeight.w600,
                color: isNight ? Colors.white : PokoPalette.slate_700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _BackpackCard extends StatefulWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final Color accentColor;
  final bool isNight;
  final VoidCallback onTap;

  const _BackpackCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
    required this.accentColor,
    required this.isNight,
    required this.onTap,
  });

  @override
  State<_BackpackCard> createState() => _BackpackCardState();
}

class _BackpackCardState extends State<_BackpackCard> {
  @override
  Widget build(BuildContext context) {
    // 缩放手感统一交给 BouncyTouchFeedback ——
    // 原先这里自己维护 _pressed + AnimatedScale，和全 App 的按压反馈是两套实现。
    return BouncyTouchFeedback(
      scaleDown: 0.94,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isNight
                ? const Color(0xFF221D46)
                : PokoPalette.slate_50,
            borderRadius: BorderRadius.circular(PokoRadius.md),
            border: Border.all(
              color: widget.isNight
                  ? widget.accentColor.withValues(alpha: 0.35)
                  : PokoPalette.slate_200,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isNight
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: widget.isNight ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(PokoRadius.sm),
                ),
                alignment: Alignment.center,
                child: Text(widget.icon, style: const TextStyle(fontSize: PokoFont.headline)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: PokoFont.small,
                              fontWeight: FontWeight.bold,
                              color: widget.isNight
                                  ? Colors.white
                                  : PokoPalette.slate_800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.badgeText != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: (widget.badgeColor ?? widget.accentColor).withValues(alpha: widget.isNight ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(PokoRadius.xs),
                            ),
                            child: Text(
                              widget.badgeText!,
                              style: TextStyle(
                                fontSize: PokoFont.micro,
                                fontWeight: FontWeight.bold,
                                color: widget.badgeColor ?? widget.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // 副标题宽度预算：2 列宫格在 320dp 窄屏上，卡片右半区只剩
                    // 约 75px，扣掉 9.5px 字号 → 最多 7 个全角汉字。
                    // 所以文案统一压在 6 字以内留出余量，超了会被省略号切掉
                    // （见 test/mobile_features_test.dart 的守门断言）。
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: PokoFont.microSm,
                        color: widget.isNight
                            ? PokoPalette.slate_400
                            : PokoPalette.slate_500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    );
  }
}
