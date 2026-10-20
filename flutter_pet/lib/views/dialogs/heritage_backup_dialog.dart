import 'package:flutter/material.dart';
import '../../models/pet_model.dart';
import '../../services/haptic_service.dart';
import '../../services/sound_service.dart';

/// 🌸 历史波可档案一键继承弹窗 (Heritage Backup Inheritance Dialog)
/// 当用户卸载重装后首次启动，自动探测到外部公用目录历史备份时主动呼出
class HeritageBackupDialog extends StatelessWidget {
  final Map<String, dynamic> backupData;
  final VoidCallback onInherit;
  final VoidCallback? onDecline;

  const HeritageBackupDialog({
    super.key,
    required this.backupData,
    required this.onInherit,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF78350F).withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶层暖金发光徽章与大标题
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Text('👑', style: TextStyle(fontSize: 34)),
            ),
            const SizedBox(height: 12),
            const Text(
              '🎉 发现历史波可档案！',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF78350F),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '检测到您曾经在手机上培养的波可伙伴\n即使卸载重装，它的成长记忆依然被完整守护着',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: const Color(0xFF92400E).withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 16),

            // 核心档案预览卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFED7AA), width: 1.2),
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFED7AA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              skinName,
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF9A3412), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8A65), Color(0xFFEA580C)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Lv. $level',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: Color(0xFFFED7AA)),
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
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_rounded, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          '上次冒险存档: $timeFormatted',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7A55), Color(0xFFEA580C)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          '一键继承档案，欢迎回家',
                          style: TextStyle(
                            fontSize: 15,
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
            const SizedBox(height: 10),

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
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '从头开始新旅程 🐾',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF9A3412),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: Color(0xFFB45309),
          ),
        ),
      ],
    );
  }
}
