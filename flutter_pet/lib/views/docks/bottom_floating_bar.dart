import 'package:flutter/material.dart';
import '../../widgets/bouncy_touch_feedback.dart';

/// 底部五灵动悬浮胶囊 (背包 + 换装 + 小窝 + 盲盒 + 绝活，1-Tap 直达，零层级深度)
class BottomFloatingBar extends StatelessWidget {
  final bool isNight;
  final VoidCallback onBackpackTap;
  final VoidCallback onWardrobeTap;
  final VoidCallback onHabitatTap;
  final VoidCallback onGachaTap;
  final VoidCallback onActionTap;

  const BottomFloatingBar({
    super.key,
    required this.isNight,
    required this.onBackpackTap,
    required this.onWardrobeTap,
    required this.onHabitatTap,
    required this.onGachaTap,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const ValueKey('bottom_floating_bar'),
      bottom: 16,
      left: 8,
      right: 8,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 奇妙背包
              BouncyTouchFeedback(
                scaleDown: 0.92,
                onTap: onBackpackTap,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! < -50) {
                    onBackpackTap();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF1E1A40).withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isNight
                          ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                          : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isNight
                            ? const Color(0xFF0F0C24).withValues(alpha: 0.5)
                            : const Color(0xFF6366F1).withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎒', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 3.5),
                      Text(
                        '奇妙背包',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isNight ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 1),
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 15,
                        color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // 2. 魔法换装
              BouncyTouchFeedback(
                scaleDown: 0.92,
                onTap: onWardrobeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF311E66).withValues(alpha: 0.9)
                        : const Color(0xFFFAF5FF).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isNight
                          ? const Color(0xFFA855F7).withValues(alpha: 0.5)
                          : const Color(0xFFE9D5FF),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.14),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👗', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 3.5),
                      Text(
                        '魔法换装',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // 3. 小窝场景
              BouncyTouchFeedback(
                scaleDown: 0.92,
                onTap: onHabitatTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF133E2B).withValues(alpha: 0.9)
                        : const Color(0xFFF0FDF4).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isNight
                          ? const Color(0xFF10B981).withValues(alpha: 0.5)
                          : const Color(0xFFBBF7D0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.16),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🏠', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 3.5),
                      Text(
                        '小窝场景',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isNight ? const Color(0xFFA7F3D0) : const Color(0xFF15803D),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // 4. 星愿盲盒
              BouncyTouchFeedback(
                scaleDown: 0.92,
                onTap: onGachaTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF162D4A).withValues(alpha: 0.9)
                        : const Color(0xFFF0F9FF).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isNight
                          ? const Color(0xFF0EA5E9).withValues(alpha: 0.55)
                          : const Color(0xFFBAE6FD),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔮', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 3.5),
                      Text(
                        '星愿盲盒',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isNight ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // 5. 专属绝活
              BouncyTouchFeedback(
                scaleDown: 0.92,
                onTap: onActionTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF3D2714).withValues(alpha: 0.9)
                        : const Color(0xFFFFFBEB).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isNight
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
                          : const Color(0xFFFDE68A),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 13)),
                      const SizedBox(width: 3.5),
                      Text(
                        '专属绝活',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isNight ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
