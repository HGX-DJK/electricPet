import 'package:flutter/material.dart';

/// 底部沉浸式美食投喂坞 (Live Feeding Dock - 位于底部黄金触控区，零中景遮挡，轻触或向上拖拽喂猫)
class LiveFeedingDock extends StatelessWidget {
  final bool isNight;
  final List<Map<String, dynamic>> foodMenu;
  final void Function(String id, String name, String icon, int hunger, int intimacyGain) onFoodTap;
  final void Function(String id, String name, String icon, DragStartDetails details) onFoodPanStart;
  final void Function(DragUpdateDetails details) onFoodPanUpdate;
  final void Function(int hunger, int intimacyGain) onFoodPanEnd;
  final VoidCallback onClose;

  const LiveFeedingDock({
    super.key,
    required this.isNight,
    required this.foodMenu,
    required this.onFoodTap,
    required this.onFoodPanStart,
    required this.onFoodPanUpdate,
    required this.onFoodPanEnd,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const ValueKey('drag_to_feed_tray'),
      bottom: 14,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
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
            color: isNight
                ? const Color(0xFF161334).withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isNight ? const Color(0xFFFB7185).withValues(alpha: 0.45) : const Color(0xFFFDA4AF),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF43F5E).withValues(alpha: isNight ? 0.28 : 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶栏：标题说明 + 提示 + 完成关闭按钮
              Row(
                children: [
                  const Text('🥣', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '美味投喂 · 轻触或向上拖拽给波可',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isNight ? Colors.white : const Color(0xFF9F1239),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // 拖拽手势轻提示胶囊
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E).withValues(alpha: isNight ? 0.28 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_upward_rounded, size: 9.5, color: Color(0xFFE11D48)),
                        SizedBox(width: 1.5),
                        Text(
                          '可上滑',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF2E2652) : const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDA4AF).withValues(alpha: 0.5), width: 0.9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 12, color: isNight ? const Color(0xFFCBD5E1) : const Color(0xFFE11D48)),
                        const SizedBox(width: 2),
                        Text(
                          '完成',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isNight ? Colors.white : const Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // 全品类横向滚动美食卡片 (10种专属美食，支持轻触喂食或向上拖拽)
            SizedBox(
              height: 86,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: foodMenu.length,
                itemBuilder: (context, index) {
                  final food = foodMenu[index];
                  final id = food['id'] as String;
                  final name = food['name'] as String;
                  final icon = food['icon'] as String;
                  final hunger = (food['hunger'] as num).toInt();
                  const intimacyGain = 8;

                  final pData = food['personality'];
                  String pBadge = '+$hunger 饱腹';
                  Color pColor = const Color(0xFFE11D48);
                  if (pData is List && pData.isNotEmpty) {
                    final pType = pData[0].toString().toLowerCase();
                    final pVal = (pData.length > 1 && pData[1] is num) ? (pData[1] as num).toInt() : 1;
                    if (pType == 'tech') {
                      pBadge = '⚡极客+$pVal';
                      pColor = const Color(0xFF0EA5E9);
                    } else if (pType == 'sport') {
                      pBadge = '🏃运动+$pVal';
                      pColor = const Color(0xFFEF4444);
                    } else if (pType == 'lazy') {
                      pBadge = '🍵佛系+$pVal';
                      pColor = const Color(0xFF10B981);
                    }
                  }

                  return Container(
                    width: 78,
                    margin: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onFoodTap(id, name, icon, hunger, intimacyGain),
                      onPanStart: (details) => onFoodPanStart(id, name, icon, details),
                      onPanUpdate: onFoodPanUpdate,
                      onPanEnd: (_) => onFoodPanEnd(hunger, intimacyGain),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isNight
                                ? [const Color(0xFF2E2652), const Color(0xFF1E1838)]
                                : [const Color(0xFFFFF5F5), const Color(0xFFFFECEF)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFDA4AF).withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFB7185).withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isNight ? const Color(0xFF3F356B) : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFB7185).withValues(alpha: 0.18),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(icon, style: const TextStyle(fontSize: 18)),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isNight ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              pBadge,
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: pColor,
                              ),
                            ),
                          ],
                        ),
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
