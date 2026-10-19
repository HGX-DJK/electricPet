import 'package:flutter/material.dart';

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
        ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
        : const Color(0xFFFDE68A);
    final cardBg = isNight ? const Color(0xFF231B45) : const Color(0xFFFFFBEB);

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
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isNight
                  ? const Color(0xFF0F0C24).withValues(alpha: 0.65)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.14),
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
                              ? const Color(0xFFEF4444).withValues(alpha: isNight ? 0.3 : 0.12)
                              : const Color(0xFFF59E0B).withValues(alpha: isNight ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActing
                                ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                                : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          isActing ? '🔴 LIVE' : '✨ 才艺',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isActing
                                ? (isNight ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626))
                                : (isNight ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
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
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isActing
                                ? (isNight ? Colors.white : const Color(0xFF0F172A))
                                : (isNight ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 完成退出点播按钮
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
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
                            fontSize: 12,
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

                  return GestureDetector(
                    onTap: () => onActionSelected(act['id']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 78,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? (isNight ? const Color(0xFF581C87) : const Color(0xFFFEF3C7))
                            : cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrent
                              ? const Color(0xFFF59E0B)
                              : (isNight ? const Color(0xFF4338CA).withValues(alpha: 0.35) : const Color(0xFFFDE68A).withValues(alpha: 0.7)),
                          width: isCurrent ? 2.2 : 1.0,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
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
                              Text(act['icon']!, style: const TextStyle(fontSize: 22)),
                              if (isCurrent)
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
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
                              fontSize: 10,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: isCurrent
                                  ? (isNight ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
                                  : (isNight ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
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
    );
  }
}
