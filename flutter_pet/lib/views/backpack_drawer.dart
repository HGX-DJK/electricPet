import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pet_model.dart';

/// 波可的奇妙背包 (优雅上拉抽屉 / 萌宠工具箱面板)
class PokoBackpackDrawer extends StatelessWidget {
  final PetModel model;
  final bool isNight;
  final VoidCallback onFeedTap;
  final VoidCallback onTeaseTap;
  final VoidCallback onWardrobeTap;
  final VoidCallback onActionTap;
  final VoidCallback onMemoTap;
  final VoidCallback onBathTap;
  final VoidCallback onSleepTap;
  final VoidCallback onToggleFloating;

  const PokoBackpackDrawer({
    super.key,
    required this.model,
    required this.isNight,
    required this.onFeedTap,
    required this.onTeaseTap,
    required this.onWardrobeTap,
    required this.onActionTap,
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

            // 2. 标题与快捷关闭
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF262054)
                        : const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🎒', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text(
                      '日常照料、玩具道具与实用功能',
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

            // 3. 规整双列功能卡片网格
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.25,
              children: [
                // 1. 美味投喂
                _BackpackCard(
                  icon: '🍱',
                  title: '美味投喂',
                  subtitle: '补充饱腹度与好感经验',
                  accentColor: const Color(0xFFF59E0B),
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onFeedTap();
                  },
                ),
                // 2. 指尖逗趣
                _BackpackCard(
                  icon: '🧶',
                  title: '指尖逗趣',
                  subtitle: '抛弹毛线球，让波可飞扑',
                  accentColor: const Color(0xFFEC4899),
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onTeaseTap();
                  },
                ),
                // 3. 萌宠衣橱
                _BackpackCard(
                  icon: '👗',
                  title: '萌宠衣橱',
                  subtitle: '换上可爱帽子与领结饰品',
                  accentColor: const Color(0xFF8B5CF6),
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onWardrobeTap();
                  },
                ),
                // 4. 专属绝活
                _BackpackCard(
                  icon: '✨',
                  title: '专属绝活',
                  subtitle: '后空翻、魔术与萌趣打滚',
                  accentColor: const Color(0xFFF43F5E),
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onActionTap();
                  },
                ),
                // 5. 贴心便签
                _BackpackCard(
                  icon: '📝',
                  title: '贴心便签',
                  subtitle: '记录生活备忘与待办灵感',
                  accentColor: const Color(0xFFEAB308),
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onMemoTap();
                  },
                ),
                // 6. 泡泡沐浴
                _BackpackCard(
                  icon: '🫧',
                  title: '泡泡沐浴',
                  subtitle: '洗个香香，提升心情活力',
                  accentColor: const Color(0xFF10B981),
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onBathTap();
                  },
                ),
                // 7. 伴眠哄睡
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
                // 8. 桌面悬浮
                _BackpackCard(
                  icon: '📱',
                  title: '桌面悬浮',
                  subtitle: '全局常驻手机桌面伴侣',
                  accentColor: const Color(0xFF06B6D4),
                  isNight: isNight,
                  onTap: () {
                    Navigator.of(context).pop();
                    onToggleFloating();
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
  final Color accentColor;
  final bool isNight;
  final VoidCallback onTap;

  const _BackpackCard({
    required this.icon,
    required this.title,
    required this.subtitle,
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
                  color: widget.accentColor.withOpacity(widget.isNight ? 0.2 : 0.12),
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
                    Text(
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
                    const SizedBox(height: 1),
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
