import 'package:flutter/material.dart';
import '../../widgets/bouncy_touch_feedback.dart';

// 底部三灵动黄金大胶囊 (背包 + 装扮小窝 + 绝活，宽大舒适，零层级深度)
class BottomFloatingBar extends StatelessWidget {
  final bool isNight;
  final VoidCallback onBackpackTap;
  final VoidCallback onWardrobeTap;
  final VoidCallback onActionTap;
  final VoidCallback? onVoiceChatTap;
  final VoidCallback? onHabitatTap;
  final VoidCallback? onGachaTap;

  const BottomFloatingBar({
    super.key,
    required this.isNight,
    required this.onBackpackTap,
    required this.onWardrobeTap,
    required this.onActionTap,
    this.onVoiceChatTap,
    this.onHabitatTap,
    this.onGachaTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const ValueKey('bottom_floating_bar'),
      bottom: 16,
      left: 12,
      right: 12,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, animVal, child) {
          return Transform.translate(
            offset: Offset(0, (1.0 - animVal) * 16.0),
            child: Opacity(
              opacity: animVal.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
              // 1. 奇妙背包
              BouncyTouchFeedback(
                scaleDown: 0.93,
                onTap: onBackpackTap,
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null && details.primaryVelocity! < -50) {
                    onBackpackTap();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF1E1A40).withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isNight
                          ? const Color(0xFF6366F1).withValues(alpha: 0.45)
                          : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isNight
                            ? const Color(0xFF0F0C24).withValues(alpha: 0.5)
                            : const Color(0xFF6366F1).withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎒', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        '奇妙背包',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isNight ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 16,
                        color: isNight ? const Color(0xFFA5B4FC) : const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. 装扮小窝 (整合猫咪装扮与小窝全景，一键进入双层零滑动空间)
              BouncyTouchFeedback(
                scaleDown: 0.93,
                onTap: onWardrobeTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8.5),
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF2C194D).withValues(alpha: 0.92)
                        : const Color(0xFFFAF5FF).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isNight
                          ? const Color(0xFFA855F7).withValues(alpha: 0.6)
                          : const Color(0xFFE9D5FF),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withValues(alpha: 0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👗', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        '装扮小窝',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 3. 专属绝活 (直达 1-Tap 开启悬浮点播坞)
              BouncyTouchFeedback(
                scaleDown: 0.93,
                onTap: onActionTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                  decoration: BoxDecoration(
                    color: isNight
                        ? const Color(0xFF3B2412).withValues(alpha: 0.92)
                        : const Color(0xFFFFFBEB).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isNight
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
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
                      const Text('✨', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        '专属绝活',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isNight ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (onVoiceChatTap != null) ...[
                const SizedBox(width: 8),
                BouncyTouchFeedback(
                  scaleDown: 0.93,
                  onTap: onVoiceChatTap!,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                    decoration: BoxDecoration(
                      color: isNight
                          ? const Color(0xFF1E153D).withValues(alpha: 0.92)
                          : const Color(0xFFEFF6FF).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isNight
                            ? const Color(0xFF818CF8).withValues(alpha: 0.6)
                            : const Color(0xFFBFDBFE),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.20),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🎙️', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 5),
                        Text(
                          'AI语聊',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isNight ? const Color(0xFFC7D2FE) : const Color(0xFF2563EB),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
}
