import 'package:flutter/material.dart';
import '../../theme/poko_theme.dart';
import '../../services/haptic_service.dart';
import '../../widgets/bouncy_touch_feedback.dart';

/// 画布级无遮挡专属绝活滑轨点播台 (彻底消灭阻塞弹窗，全屏无暗色遮罩，零多余操作)
class LiveActionDock extends StatelessWidget {
  final bool isNight;
  final String currentState;
  final List<Map<String, String>> actions;
  final void Function(String actionId) onActionSelected;
  final VoidCallback onClose;

  const LiveActionDock({
    super.key,
    required this.isNight,
    required this.currentState,
    required this.actions,
    required this.onActionSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isNight
        ? const Color(0xFF14122C).withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.98);
    final borderColor = isNight
        ? PokoPalette.amber_500.withValues(alpha: 0.55)
        : PokoPalette.amber_200;
    final cardBg = isNight ? const Color(0xFF231B45) : PokoPalette.amber_50;

    final isActing = actions.any((act) => act['id'] == currentState);
    final currentAct = isActing
        ? actions.firstWhere((act) => act['id'] == currentState)
        : null;

    final headerText = isActing
        ? '🎭 正在表演：${currentAct!['name']} · ${currentAct['desc']}'
        : '✨ 绝活点播台 · 点击下方卡片即刻开演 (共${actions.length}项)';

    return Positioned(
      key: const ValueKey('live_action_dock'),
      bottom: 12,
      left: 12,
      right: 12,
      child: TweenAnimationBuilder<double>(
        duration: PokoDuration.settle,
        curve: PokoCurves.standard,
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, animVal, child) {
          return Transform.translate(
            offset: Offset(0, (1.0 - animVal) * 20.0),
            child: Opacity(
              opacity: animVal.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(PokoRadius.xl),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isNight
                  ? const Color(0xFF0F0C24).withValues(alpha: 0.65)
                  : PokoPalette.amber_500.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶层栏：动态表演状态指示 + 完成退出按钮
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isActing
                              ? PokoPalette.red_500.withValues(alpha: isNight ? 0.3 : 0.12)
                              : PokoPalette.amber_500.withValues(alpha: isNight ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(PokoRadius.sm),
                          border: Border.all(
                            color: isActing
                                ? PokoPalette.red_500.withValues(alpha: 0.5)
                                : PokoPalette.amber_500.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          isActing ? '🔴 LIVE' : '✨ 才艺',
                          style: TextStyle(
                            fontSize: PokoFont.tiny,
                            fontWeight: FontWeight.bold,
                            color: isActing
                                ? (isNight ? PokoPalette.red_300 : PokoPalette.red_600)
                                : (isNight ? PokoPalette.amber_200 : PokoPalette.amber_700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          headerText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: PokoFont.caption,
                            fontWeight: FontWeight.w600,
                            color: isActing
                                ? (isNight ? Colors.white : PokoPalette.slate_900)
                                : (isNight ? PokoPalette.slate_300 : PokoPalette.slate_600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 完成退出点播按钮
                BouncyTouchFeedback(
                  scaleDown: 0.96,
        onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [PokoPalette.amber_500, PokoPalette.amber_600],
                      ),
                      borderRadius: BorderRadius.circular(PokoRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: PokoPalette.amber_500.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 3),
                        Text(
                          '完成',
                          style: TextStyle(
                            fontSize: PokoFont.small,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 水平滑动卡片展示列表
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final act = actions[index];
                  final isCurrent = (currentState == act['id']);

                  return BouncyTouchFeedback(
                    scaleDown: 0.94,
                    onTap: () {
                      HapticService.light();
                      onActionSelected(act['id']!);
                    },
                    child: AnimatedContainer(
                      duration: PokoDuration.base,
                      width: 78,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? (isNight ? const Color(0xFF581C87) : PokoPalette.amber_100)
                            : cardBg,
                        borderRadius: BorderRadius.circular(PokoRadius.md),
                        border: Border.all(
                          color: isCurrent
                              ? PokoPalette.amber_500
                              : (isNight ? PokoPalette.indigo_700.withValues(alpha: 0.35) : PokoPalette.amber_200.withValues(alpha: 0.7)),
                          width: isCurrent ? 2.2 : 1.0,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: PokoPalette.amber_500.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Text(act['icon']!, style: const TextStyle(fontSize: PokoFont.displayMd)),
                              if (isCurrent)
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: PokoPalette.red_500,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            act['name']!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: PokoFont.tiny,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: isCurrent
                                  ? (isNight ? PokoPalette.amber_200 : PokoPalette.orange_800)
                                  : (isNight ? PokoPalette.slate_200 : PokoPalette.slate_700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
