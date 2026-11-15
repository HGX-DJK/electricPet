import 'package:flutter/material.dart';

import '../../theme/poko_theme.dart';
import '../../widgets/poko_press_scale.dart';
import '../../widgets/bouncy_touch_feedback.dart';
/// 底部沉浸式美食投喂坞 (Live Feeding Dock - 位于底部黄金触控区，零中景遮挡，轻触飞喂或向上拖拽喂猫)
class LiveFeedingDock extends StatelessWidget {
  final bool isNight;
  final List<Map<String, dynamic>> foodMenu;
  final double currentHunger;
  final bool isFull;
  final void Function(String id, String name, String icon, int hunger, int intimacyGain) onFoodTap;
  final void Function(String id, String name, String icon, DragStartDetails details) onFoodPanStart;
  final void Function(DragUpdateDetails details) onFoodPanUpdate;
  final void Function(int hunger, int intimacyGain) onFoodPanEnd;
  final VoidCallback onClose;

  const LiveFeedingDock({
    super.key,
    required this.isNight,
    required this.foodMenu,
    this.currentHunger = 85.0,
    this.isFull = false,
    required this.onFoodTap,
    required this.onFoodPanStart,
    required this.onFoodPanUpdate,
    required this.onFoodPanEnd,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final hungerPct = (currentHunger / 100.0).clamp(0.0, 1.0);

    return Positioned(
      key: const ValueKey('drag_to_feed_tray'),
      bottom: 14,
      left: 14,
      right: 14,
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
            color: isNight
                ? const Color(0xFF161334).withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(PokoRadius.xl),
            border: Border.all(
              color: isNight ? PokoPalette.rose_400.withValues(alpha: 0.45) : PokoPalette.rose_300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: PokoPalette.rose_500.withValues(alpha: isNight ? 0.28 : 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶栏：实时饱腹度指示 + 状态胶囊 + 完成收起按钮
              Row(
                children: [
                  const Text('🥣', style: TextStyle(fontSize: PokoFont.titleSm)),
                  const SizedBox(width: 6),
                  Text(
                    '饱腹度',
                    style: TextStyle(
                      fontSize: PokoFont.small,
                      fontWeight: FontWeight.bold,
                      color: isNight ? Colors.white70 : PokoPalette.slate_500,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${currentHunger.toInt()}%',
                    style: TextStyle(
                      fontSize: PokoFont.small,
                      fontWeight: FontWeight.bold,
                      color: isFull ? PokoPalette.emerald_500 : PokoPalette.rose_600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 饱腹进度条
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        height: 7,
                        color: isNight ? Colors.white12 : PokoPalette.slate_100,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: hungerPct,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isFull
                                    ? const [PokoPalette.emerald_500, PokoPalette.emerald_600]
                                    : const [PokoPalette.rose_300, PokoPalette.rose_600],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 状态徽章 (已吃饱 / 待投喂)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isFull
                          ? (isNight ? const Color(0xFF064E3B) : PokoPalette.mint_100)
                          : (isNight ? const Color(0xFF4C0519) : PokoPalette.rose_50),
                      borderRadius: BorderRadius.circular(PokoRadius.xs),
                      border: Border.all(
                        color: isFull
                            ? PokoPalette.emerald_500.withValues(alpha: 0.4)
                            : PokoPalette.rose_300.withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isFull ? '🌟 已吃饱啦' : '😋 点击直接投喂',
                      style: TextStyle(
                        fontSize: PokoFont.microSm,
                        fontWeight: FontWeight.bold,
                        color: isFull ? PokoPalette.emerald_600 : PokoPalette.rose_600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  BouncyTouchFeedback(
                    scaleDown: 0.94,
        onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: isNight ? const Color(0xFF2E2652) : PokoPalette.slate_100,
                        borderRadius: BorderRadius.circular(PokoRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close, size: 13, color: isNight ? Colors.white70 : PokoPalette.slate_500),
                          const SizedBox(width: 2),
                          Text(
                            '完成',
                            style: TextStyle(
                              fontSize: PokoFont.tiny,
                              fontWeight: FontWeight.bold,
                              color: isNight ? Colors.white70 : PokoPalette.slate_500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 全品类横向滚动美食卡片 (轻触直投飞喂，上滑向上拖拽至猫嘴)
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
                    Color pColor = PokoPalette.rose_600;
                    if (isFull) {
                      pBadge = '🌟 肚子饱饱';
                      pColor = PokoPalette.emerald_500;
                    } else if (pData is List && pData.isNotEmpty) {
                      final pType = pData[0].toString().toLowerCase();
                      final pVal = (pData.length > 1 && pData[1] is num) ? (pData[1] as num).toInt() : 1;
                      if (pType == 'tech') {
                        pBadge = '⚡极客+$pVal';
                        pColor = PokoPalette.sky_500;
                      } else if (pType == 'sport') {
                        pBadge = '🏃运动+$pVal';
                        pColor = PokoPalette.red_500;
                      } else if (pType == 'lazy') {
                        pBadge = '🍵佛系+$pVal';
                        pColor = PokoPalette.emerald_500;
                      }
                    }

                    return Container(
                      width: 78,
                      margin: const EdgeInsets.only(right: 8),
                      child: PokoPressScale(
                        scaleDown: 0.92,
                        child: GestureDetector(
                        onTap: () => onFoodTap(id, name, icon, hunger, intimacyGain),
                        // 纵向拖拽向上滑动喂食，横向滑动专供列表滚动，彻底避免手势冲突！
                        onVerticalDragStart: (details) => onFoodPanStart(id, name, icon, DragStartDetails(globalPosition: details.globalPosition)),
                        onVerticalDragUpdate: (details) => onFoodPanUpdate(DragUpdateDetails(globalPosition: details.globalPosition)),
                        onVerticalDragEnd: (_) => onFoodPanEnd(hunger, intimacyGain),
                        child: AnimatedOpacity(
                          duration: PokoDuration.base,
                          opacity: isFull ? 0.72 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: isNight
                                    ? [const Color(0xFF2E2652), PokoPalette.night_surface]
                                    : [const Color(0xFFFFF5F5), const Color(0xFFFFECEF)],
                              ),
                              borderRadius: BorderRadius.circular(PokoRadius.md),
                              border: Border.all(
                                color: isFull
                                    ? PokoPalette.emerald_500.withValues(alpha: 0.5)
                                    : PokoPalette.rose_300.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: PokoPalette.rose_400.withValues(alpha: 0.08),
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
                                        color: PokoPalette.rose_400.withValues(alpha: 0.18),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(icon, style: const TextStyle(fontSize: PokoFont.subtitle)),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: PokoFont.tiny,
                                    fontWeight: FontWeight.bold,
                                    color: isNight ? Colors.white : PokoPalette.slate_800,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  pBadge,
                                  style: TextStyle(
                                    fontSize: PokoFont.micro,
                                    fontWeight: FontWeight.w700,
                                    color: pColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
