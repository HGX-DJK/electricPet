import 'package:flutter/material.dart';
import '../../theme/poko_theme.dart';
import '../../widgets/bouncy_touch_feedback.dart';

/// 软装家具：左侧就餐角 · 萌宠立式三联食水一体托盘
class CatDiningStation extends StatelessWidget {
  final bool isNight;
  final bool isHungry;
  final bool showFoodTray;
  final bool isWaterRippling;
  final bool isDrinking;
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
    this.isDrinking = false,
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
        borderRadius: BorderRadius.circular(PokoRadius.lg),
        border: Border.all(
          color: isNight
              ? PokoPalette.indigo_500.withValues(alpha: 0.35)
              : PokoPalette.slate_200,
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
                ? PokoPalette.indigo_500.withValues(alpha: 0.12)
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
                : PokoPalette.slate_200,
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
                : PokoPalette.slate_200,
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
                  ? PokoPalette.rose_500.withValues(alpha: 0.18)
                  : (isNight ? const Color(0xFF140F2A) : PokoPalette.slate_100),
              borderRadius: BorderRadius.circular(PokoRadius.md),
              border: Border.all(
                color: showFoodTray
                    ? PokoPalette.rose_500
                    : (isHungry
                        ? PokoPalette.rose_500
                        : (isNight
                            ? PokoPalette.indigo_700.withValues(alpha: 0.3)
                            : PokoPalette.slate_200)),
                width: isHungry ? 1.4 : 1.0,
              ),
              boxShadow: isHungry
                  ? [
                      BoxShadow(
                        color: PokoPalette.rose_500.withValues(alpha: 0.28),
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
                    Text('🥣', style: TextStyle(fontSize: PokoFont.bodyMd)),
                    SizedBox(width: 2),
                    Text('🐟', style: TextStyle(fontSize: PokoFont.caption)),
                  ],
                ),
                const SizedBox(height: 1.5),
                Text(
                  showFoodTray ? '投喂中' : '食碗',
                  style: TextStyle(
                    fontSize: PokoFont.micro,
                    fontWeight: FontWeight.bold,
                    color: showFoodTray
                        ? PokoPalette.rose_500
                        : (isNight ? PokoPalette.indigo_300 : PokoPalette.slate_500),
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
                      colors: [PokoPalette.red_500, Color(0xFFF97316)],
                    ),
                    borderRadius: BorderRadius.circular(PokoRadius.xs),
                    boxShadow: [
                      BoxShadow(
                        color: PokoPalette.red_500.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Text(
                    '求投喂 🥣',
                    style: TextStyle(
                      fontSize: PokoFont.nano,
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

  /// 水碗组件 (精致陶瓷浅盆 · 动态清泉水面与同心水波涟漪)
  Widget _buildWaterBowl() {
    final active = isWaterRippling || isDrinking;
    return BouncyTouchFeedback(
      key: const ValueKey('cat_water_bowl'),
      scaleDown: 0.92,
      onTap: onWaterBowlTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isNight
              ? (active ? PokoPalette.slate_800 : const Color(0xFF140F2A))
              : (active ? PokoPalette.sky_100 : PokoPalette.slate_50),
          borderRadius: BorderRadius.circular(PokoRadius.md),
          border: Border.all(
            color: active
                ? PokoPalette.sky_600
                : (isNight
                    ? PokoPalette.sky_400.withValues(alpha: 0.4)
                    : PokoPalette.sky_200),
            width: active ? 1.4 : 1.0,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: PokoPalette.sky_600.withValues(alpha: 0.28),
                    blurRadius: 6,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 真实陶瓷注水碗 (含水面反光与同心涟漪波纹)
            SizedBox(
              width: 32,
              height: 20,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 陶瓷碗外壁与厚度阴影
                  Container(
                    width: 32,
                    height: 19,
                    decoration: BoxDecoration(
                      color: isNight ? PokoPalette.slate_700 : PokoPalette.slate_200,
                      borderRadius: BorderRadius.circular(PokoRadius.sm),
                      border: Border.all(
                        color: isNight ? PokoPalette.slate_600 : Colors.white,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 3,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                  ),
                  // 碗内湛蓝清泉水体
                  Container(
                    width: 26,
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [PokoPalette.sky_400, PokoPalette.sky_600],
                      ),
                      borderRadius: BorderRadius.circular(PokoRadius.xs),
                    ),
                  ),
                  // 水面高光与波光涟漪
                  if (active)
                    _WaterRippleEffect(isNight: isNight)
                  else
                    // 静止微光高光点
                    Positioned(
                      top: 4,
                      left: 6,
                      child: Container(
                        width: 5,
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                  // 漂浮小水珠或小气泡
                  Center(
                    child: Text(
                      isDrinking ? '🫧' : (active ? '💧' : ''),
                      style: const TextStyle(fontSize: PokoFont.micro),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isDrinking ? '舔水中' : (active ? '波光粼粼' : '水碗'),
              style: TextStyle(
                fontSize: PokoFont.micro,
                fontWeight: FontWeight.bold,
                color: active
                    ? PokoPalette.sky_600
                    : (isNight ? PokoPalette.sky_300 : PokoPalette.sky_700),
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
          color: isNight ? const Color(0xFF140F2A) : PokoPalette.slate_100,
          borderRadius: BorderRadius.circular(PokoRadius.md),
          border: Border.all(
            color: isNight
                ? PokoPalette.amber_500.withValues(alpha: 0.4)
                : PokoPalette.amber_200,
            width: 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🥫', style: TextStyle(fontSize: PokoFont.bodyMd)),
                SizedBox(width: 2),
                Text('🔔', style: TextStyle(fontSize: PokoFont.caption)),
              ],
            ),
            const SizedBox(height: 1.5),
            Text(
              '敲罐',
              style: TextStyle(
                fontSize: PokoFont.micro,
                fontWeight: FontWeight.bold,
                color: isNight ? PokoPalette.amber_400 : PokoPalette.amber_600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// 水碗动态水波涟漪组件 (Concentric Water Ripples)
class _WaterRippleEffect extends StatefulWidget {
  final bool isNight;
  const _WaterRippleEffect({required this.isNight});

  @override
  State<_WaterRippleEffect> createState() => _WaterRippleEffectState();
}

class _WaterRippleEffectState extends State<_WaterRippleEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return CustomPaint(
          size: const Size(26, 14),
          painter: _RipplePainter(val),
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  _RipplePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 2; i++) {
      final p = (progress + i * 0.5) % 1.0;
      final radiusX = 4.0 + p * 8.0;
      final radiusY = 2.0 + p * 4.0;
      final opacity = (1.0 - p).clamp(0.0, 0.85);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawOval(
        Rect.fromCenter(center: center, width: radiusX * 2, height: radiusY * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
