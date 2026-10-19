import 'package:flutter/material.dart';
import '../../widgets/bouncy_touch_feedback.dart';

/// 软装家具：左侧就餐角 · 萌宠立式三联食水一体托盘
class CatDiningStation extends StatelessWidget {
  final bool isNight;
  final bool isHungry;
  final bool showFoodTray;
  final bool isWaterRippling;
  final VoidCallback onFoodBowlTap;
  final VoidCallback onFoodBowlDoubleTap;
  final VoidCallback onWaterBowlTap;
  final VoidCallback onCanSummonTap;

  const CatDiningStation({
    super.key,
    required this.isNight,
    required this.isHungry,
    required this.showFoodTray,
    required this.isWaterRippling,
    required this.onFoodBowlTap,
    required this.onFoodBowlDoubleTap,
    required this.onWaterBowlTap,
    required this.onCanSummonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 5),
      decoration: BoxDecoration(
        color: isNight
            ? const Color(0xFF1B1635).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNight
              ? const Color(0xFF6366F1).withValues(alpha: 0.35)
              : const Color(0xFFE2E8F0),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isNight ? 0.35 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: isNight
                ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.85),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：精致小食碗 (点击投喂，双击弹鲜鱼)
          _buildFoodBowl(),
          // 优雅陶瓷横向分隔微线
          Container(
            width: 24,
            height: 1.0,
            margin: const EdgeInsets.symmetric(vertical: 3),
            color: isNight
                ? const Color(0xFF3730A3).withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
          ),
          // 中间：清澈小水碗 (点击波光粼粼涟漪，解渴补水)
          _buildWaterBowl(),
          // 优雅陶瓷横向分隔微线
          Container(
            width: 24,
            height: 1.0,
            margin: const EdgeInsets.symmetric(vertical: 3),
            color: isNight
                ? const Color(0xFF3730A3).withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
          ),
          // 底部：敲敲罐头召唤按钮 (点击发出清脆开饭叮叮声，猫咪全速冲刺狂奔而来)
          _buildCanSummonButton(),
        ],
      ),
    );
  }

  /// 食碗组件
  Widget _buildFoodBowl() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        BouncyTouchFeedback(
          key: const ValueKey('cat_food_bowl'),
          scaleDown: 0.92,
          onTap: onFoodBowlTap,
          onDoubleTap: onFoodBowlDoubleTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: showFoodTray
                  ? const Color(0xFFF43F5E).withValues(alpha: 0.18)
                  : (isNight ? const Color(0xFF140F2A) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: showFoodTray
                    ? const Color(0xFFF43F5E)
                    : (isHungry
                        ? const Color(0xFFF43F5E)
                        : (isNight
                            ? const Color(0xFF4338CA).withValues(alpha: 0.3)
                            : const Color(0xFFE2E8F0))),
                width: isHungry ? 1.4 : 1.0,
              ),
              boxShadow: isHungry
                  ? [
                      BoxShadow(
                        color: const Color(0xFFF43F5E).withValues(alpha: 0.28),
                        blurRadius: 6,
                        offset: const Offset(0, 1.5),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🥣', style: TextStyle(fontSize: 14)),
                    SizedBox(width: 2),
                    Text('🐟', style: TextStyle(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 1.5),
                Text(
                  showFoodTray ? '投喂中' : '食碗',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: showFoodTray
                        ? const Color(0xFFF43F5E)
                        : (isNight ? const Color(0xFFA5B4FC) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isHungry)
          Positioned(
            top: -10,
            left: -4,
            right: -4,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Text(
                    '求投喂 🥣',
                    style: TextStyle(
                      fontSize: 7,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 水碗组件
  Widget _buildWaterBowl() {
    return BouncyTouchFeedback(
      key: const ValueKey('cat_water_bowl'),
      scaleDown: 0.92,
      onTap: onWaterBowlTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isWaterRippling
              ? const Color(0xFF38BDF8).withValues(alpha: 0.25)
              : (isNight ? const Color(0xFF140F2A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isWaterRippling
                ? const Color(0xFF0284C7)
                : (isNight
                    ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
                    : const Color(0xFFBAE6FD)),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🥣', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 2),
                Text(isWaterRippling ? '🫧' : '💧', style: const TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 1.5),
            Text(
              isWaterRippling ? '波光粼粼' : '水碗',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: isWaterRippling
                    ? const Color(0xFF0284C7)
                    : (isNight ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 敲罐召唤组件
  Widget _buildCanSummonButton() {
    return BouncyTouchFeedback(
      key: const ValueKey('can_summon_button'),
      scaleDown: 0.92,
      onTap: onCanSummonTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: isNight ? const Color(0xFF140F2A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isNight
                ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                : const Color(0xFFFDE68A),
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🥫', style: TextStyle(fontSize: 14)),
                SizedBox(width: 2),
                Text('🔔', style: TextStyle(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 1.5),
            Text(
              '敲罐',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: isNight ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
