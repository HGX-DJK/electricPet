import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pet_model.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isNight
            ? const Color(0xFF161334).withOpacity(0.96)
            : Colors.white.withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isNight
              ? const Color(0xFF4338CA).withOpacity(0.5)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isNight
                ? const Color(0xFF09071A).withOpacity(0.7)
                : const Color(0xFF6366F1).withOpacity(0.12),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: SafeArea(
        top: false,
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
                      ? const Color(0xFF475569).withOpacity(0.8)
                      : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 2. 标题栏与实时健康状态小胶囊
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF262054)
                        : const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🎒', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 9),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '波可的奇妙背包',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isNight ? Colors.white : const Color(0xFF1E293B),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(isNight ? 0.25 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            model.isSleeping ? '💤 伴眠中' : '✨ 元气满满',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isNight ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '日常照料、逗猫玩具与生活贴心工具',
                      style: TextStyle(
                        fontSize: 11,
                        color: isNight
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isNight
                          ? const Color(0xFF241F48)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isNight
                            ? const Color(0xFF3B336A)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: isNight
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

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
                _BackpackCard(
                  icon: '🍱',
                  title: '美味投喂',
                  subtitle: '补充饱腹与好感经验',
                  badgeText: '${model.hunger.toInt()}%',
                  badgeColor: const Color(0xFFF59E0B),
                  accentColor: const Color(0xFFF59E0B),
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onFeedTap();
                  },
                ),
                // 2. 神奇激光笔逗猫 (全新超高趣味交互)
                _BackpackCard(
                  icon: '🔴',
                  title: '神奇激光笔',
                  subtitle: '指尖红点，小猫疯狂飞扑',
                  badgeText: '新玩具',
                  badgeColor: const Color(0xFFEF4444),
                  accentColor: const Color(0xFFEF4444),
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
                  subtitle: '抛弹毛线球追逐打滚',
                  accentColor: const Color(0xFFEC4899),
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onTeaseTap();
                  },
                ),
                // 4. 泡泡沐浴
                _BackpackCard(
                  icon: '🫧',
                  title: '泡泡沐浴',
                  subtitle: '草莓香波洗香香提升心情',
                  badgeText: '${model.energy.toInt()}%',
                  badgeColor: const Color(0xFF10B981),
                  accentColor: const Color(0xFF10B981),
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onBathTap();
                  },
                ),
                // 5. 伴眠哄睡 / 唤醒
                _BackpackCard(
                  icon: model.isSleeping ? '☀️' : '🌙',
                  title: model.isSleeping ? '唤醒波可' : '伴眠哄睡',
                  subtitle: model.isSleeping ? '元气满满起床迎接主人' : '进入呼噜呼噜甜甜梦乡',
                  accentColor: const Color(0xFF6366F1),
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
                  subtitle: '生活备忘与灵感待办',
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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isNight
                ? const Color(0xFF221D46)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isNight
                  ? widget.accentColor.withOpacity(0.35)
                  : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isNight
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.02),
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
                  color: widget.accentColor.withOpacity(widget.isNight ? 0.22 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(widget.icon, style: const TextStyle(fontSize: 20)),
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
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: widget.isNight
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
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
                              color: (widget.badgeColor ?? widget.accentColor).withOpacity(widget.isNight ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.badgeText!,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: widget.badgeColor ?? widget.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: widget.isNight
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
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
      ),
    );
  }
}
