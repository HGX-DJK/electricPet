import 'package:flutter/material.dart';
import '../../models/pet_model.dart';
import '../../services/haptic_service.dart';
import '../../services/sound_service.dart';
import '../../theme/poko_theme.dart';

/// 🌸 历史波可档案一键继承弹窗 (Heritage Backup Inheritance Dialog)
/// 当用户卸载重装后首次启动，自动探测到外部公用目录历史备份时主动呼出
class HeritageBackupDialog extends StatelessWidget {
  final Map<String, dynamic> backupData;
  final VoidCallback onInherit;
  final VoidCallback? onDecline;
  final bool isNight;

  const HeritageBackupDialog({
    super.key,
    required this.backupData,
    required this.onInherit,
    this.onDecline,
    this.isNight = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    final pet = (backupData['pet'] as Map<String, dynamic>?) ?? {};
    final name = pet['name'] as String? ?? '波可 (Poko)';
    final level = (pet['level'] as num?)?.toInt() ?? 1;
    final coins = (pet['coins'] as num?)?.toInt() ?? 200;
    final intimacy = (pet['intimacy'] as num?)?.toInt() ?? 100;
    final unlockedItems = (pet['unlockedItems'] as List?)?.cast<String>() ?? [];
    final skinId = pet['skinId'] as String? ?? 'cat_calico';
    final skinName = PetModel.availableSkins[skinId]?.name ?? '三花猫';
    final savedAt = backupData['savedAt'] as String? ?? '';
    String timeFormatted = '';
    if (savedAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(savedAt).toLocal();
        timeFormatted = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Dialog(
      key: const ValueKey('heritage_backup_dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: PokoSpacing.xxl,
        vertical: PokoSpacing.xxl,
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(PokoRadius.xl),
          border: Border.all(
            color: PokoPalette.amber.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: PokoShadow.card(t.shadow),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: PokoSpacing.xl,
          vertical: PokoSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶层暖金发光徽章与大标题
            Container(
              padding: const EdgeInsets.all(PokoSpacing.md),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    PokoPalette.amberSoft,
                    PokoPalette.amber.withValues(alpha: 0.35),
                  ],
                ),
                boxShadow: PokoShadow.card(PokoPalette.amber),
              ),
              child: const Text('👑', style: TextStyle(fontSize: 34)),
            ),
            const SizedBox(height: PokoSpacing.md),
            const Text(
              '🎉 发现历史波可档案！',
              style: TextStyle(
                fontSize: PokoFont.headline,
                fontWeight: FontWeight.bold,
                color: PokoPalette.amberDeep,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: PokoSpacing.xs),
            Text(
              '检测到您曾经在手机上培养的波可伙伴\n即使卸载重装，它的成长记忆依然被完整守护着',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: PokoFont.small,
                height: 1.45,
                color: PokoPalette.amberDeep.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: PokoSpacing.lg),

            // 核心档案预览卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: PokoSpacing.lg,
                vertical: PokoSpacing.md,
              ),
              decoration: BoxDecoration(
                color: PokoPalette.amberSoft,
                borderRadius: BorderRadius.circular(PokoRadius.lg),
                border: Border.all(
                  color: PokoPalette.amber.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // 昵称与等级
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🐱 ', style: TextStyle(fontSize: 18)),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: PokoFont.bodyLg,
                              fontWeight: FontWeight.bold,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(width: PokoSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: PokoSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: PokoPalette.amber.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(
                                PokoRadius.xs,
                              ),
                            ),
                            child: Text(
                              skinName,
                              style: const TextStyle(
                                fontSize: PokoFont.caption,
                                color: PokoPalette.amberDeep,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PokoSpacing.sm,
                          vertical: PokoSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [PokoPalette.amber, PokoPalette.amberDeep],
                          ),
                          borderRadius: BorderRadius.circular(PokoRadius.sm),
                        ),
                        child: Text(
                          'Lv. $level',
                          style: const TextStyle(
                            fontSize: PokoFont.small,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: PokoSpacing.sm,
                    ),
                    child: Divider(
                      height: 1,
                      color: PokoPalette.amber.withValues(alpha: 0.45),
                    ),
                  ),
                  // 三维数据矩阵
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem('🪙 能量币', '$coins'),
                      _buildMetricItem('👗 已解锁装扮', '${unlockedItems.length} 件'),
                      _buildMetricItem('💖 亲密度', '$intimacy'),
                    ],
                  ),
                  if (timeFormatted.isNotEmpty) ...[
                    const SizedBox(height: PokoSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.history_rounded,
                          size: 12,
                          color: PokoPalette.sky,
                        ),
                        const SizedBox(width: PokoSpacing.xs),
                        Text(
                          '上次冒险存档: $timeFormatted',
                          style: TextStyle(
                            fontSize: PokoFont.tiny,
                            color: t.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: PokoSpacing.xl),

            // 操作按钮
            // 1. 主按钮：一键继承档案
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const ValueKey('inherit_backup_button'),
                onPressed: () {
                  HapticService.heavy();
                  SoundService.playClick();
                  Navigator.of(context).pop(true);
                  onInherit();
                },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PokoRadius.md),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [PokoPalette.amber, PokoPalette.amberDeep],
                    ),
                    borderRadius: BorderRadius.circular(PokoRadius.md),
                    boxShadow: PokoShadow.card(PokoPalette.amber),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: PokoSpacing.sm),
                        Text(
                          '一键继承档案，欢迎回家',
                          style: TextStyle(
                            fontSize: PokoFont.bodyLg,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: PokoSpacing.sm),

            // 2. 次按钮：从头开启新旅程
            SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton(
                key: const ValueKey('decline_backup_button'),
                onPressed: () {
                  HapticService.light();
                  Navigator.of(context).pop(false);
                  onDecline?.call();
                },
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PokoRadius.sm),
                  ),
                ),
                child: Text(
                  '从头开始新旅程 🐾',
                  style: TextStyle(
                    fontSize: PokoFont.body,
                    color: t.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: PokoFont.bodyLg,
            fontWeight: FontWeight.bold,
            color: PokoPalette.amberDeep,
          ),
        ),
        const SizedBox(height: PokoSpacing.xxs),
        Text(
          label,
          style: const TextStyle(
            fontSize: PokoFont.tiny,
            color: PokoPalette.amberDeep,
          ),
        ),
      ],
    );
  }
}
