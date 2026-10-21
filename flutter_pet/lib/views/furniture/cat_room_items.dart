import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../widgets/bouncy_touch_feedback.dart';

/// 舒睡暖垫羽绒被绗缝暗纹绘制器 (Quilting Diamond Stitches)
class BlanketQuiltPainter extends CustomPainter {
  final bool isNight;
  const BlanketQuiltPainter({required this.isNight});

  @override
  void paint(Canvas canvas, Size size) {
    final stitchPaint = Paint()
      ..color = (isNight ? const Color(0xFFC4B5FD) : Colors.white).withValues(alpha: 0.24)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const step = 22.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 12), Offset(x + size.height, size.height), stitchPaint);
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 12), stitchPaint);
    }
  }

  @override
  bool shouldRepaint(covariant BlanketQuiltPainter oldDelegate) => oldDelegate.isNight != isNight;
}

/// 顶部浪漫温馨小串灯 (白天晶莹，夜晚散发微黄暖芒，轻触闪耀)
class FairyLightsRow extends StatelessWidget {
  final bool isNight;
  final VoidCallback onTap;

  const FairyLightsRow({
    super.key,
    required this.isNight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildFairyLight('💡', isNight),
            _buildFairyWire(isNight),
            _buildFairyLight('✨', isNight),
            _buildFairyWire(isNight),
            _buildFairyLight('🌟', isNight),
            _buildFairyWire(isNight),
            _buildFairyLight('💡', isNight),
          ],
        ),
      ),
    );
  }

  Widget _buildFairyLight(String icon, bool isNight) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isNight
            ? const Color(0xFFFEF08A).withValues(alpha: 0.18)
            : const Color(0xFFFEF3C7).withValues(alpha: 0.6),
        shape: BoxShape.circle,
        boxShadow: isNight
            ? [
                BoxShadow(
                  color: const Color(0xFFFDE047).withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Text(icon, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildFairyWire(bool isNight) {
    return Expanded(
      child: Container(
        height: 1.2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isNight
              ? const Color(0xFF94A3B8).withValues(alpha: 0.3)
              : const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

/// 墙面拍立得相框 (初遇温馨纪念，轻触阻尼微晃与触感微缩放)
class PolaroidFrame extends StatelessWidget {
  final bool isNight;
  final double photoAngle;
  final VoidCallback onTap;

  const PolaroidFrame({
    super.key,
    required this.isNight,
    required this.photoAngle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTouchFeedback(
      scaleDown: 0.94,
      onTap: onTap,
      child: AnimatedRotation(
        turns: photoAngle / (2 * math.pi),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 6),
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF241D49) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isNight ? const Color(0xFF6366F1).withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isNight ? 0.35 : 0.10),
                blurRadius: 8,
                offset: const Offset(1, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 和纸胶带
              Container(
                width: 20,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFF472B6).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 3),
              // 照片内框
              Container(
                width: 44,
                height: 38,
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFF161131) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text('🐾❤️', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Day 1 · 相遇',
                style: TextStyle(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                  color: isNight ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 软装家具 1：萌宠有机猫草盆栽 (轻触轻摇，散发清香与青草粒子，静立于木地板墙角)
class CatGrassPlanter extends StatelessWidget {
  final bool isNight;
  final double plantTilt;
  final VoidCallback onTap;

  const CatGrassPlanter({
    super.key,
    required this.isNight,
    required this.plantTilt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTouchFeedback(
      scaleDown: 0.92,
      onTap: onTap,
      child: Transform.rotate(
        angle: plantTilt,
        origin: const Offset(0, 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isNight ? const Color(0xFF1E1838) : Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isNight ? const Color(0xFF10B981).withValues(alpha: 0.6) : const Color(0xFFA7F3D0),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: isNight ? 0.22 : 0.16),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 鲜嫩多层次猫草盆栽 (陶瓷花盆 + 肥沃土壤 + 鲜翠麦苗)
              SizedBox(
                width: 38,
                height: 32,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // 陶瓷花盆底座
                    Container(
                      width: 32,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isNight
                              ? [const Color(0xFF334155), const Color(0xFF1E293B)]
                              : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                          topLeft: Radius.circular(3),
                          topRight: Radius.circular(3),
                        ),
                        border: Border.all(
                          color: isNight ? const Color(0xFF475569) : const Color(0xFFF59E0B),
                          width: 1.0,
                        ),
                      ),
                    ),
                    // 肥沃土壤表层
                    Positioned(
                      bottom: 12,
                      child: Container(
                        width: 30,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFF451A03),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // 鲜嫩挺拔的猫草青叶 (多株交错麦苗)
                    Positioned(
                      bottom: 11,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Transform.rotate(
                            angle: -0.15,
                            child: const Text('🌱', style: TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(width: 1),
                          Transform.translate(
                            offset: const Offset(0, -3),
                            child: const Text('🌿', style: TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 1),
                          Transform.rotate(
                            angle: 0.15,
                            child: const Text('🌱', style: TextStyle(fontSize: 15)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFF065F46) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '猫草',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: isNight ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
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

/// 软装家具 2：原木剑麻猫抓柱 (磨爪解压，轻触咔嚓磨爪与木屑火花，立于右上角木地板)
class CatScratchingPost extends StatelessWidget {
  final bool isNight;
  final double postWiggle;
  final VoidCallback onTap;

  const CatScratchingPost({
    super.key,
    required this.isNight,
    required this.postWiggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isScratching = postWiggle.abs() > 0.1;
    return GestureDetector(
      onTap: onTap,
      child: Transform.translate(
        offset: Offset(postWiggle, 0),
        child: Transform.scale(
          scaleX: 1.0 + (postWiggle.abs() * 0.04),
          scaleY: 1.0 - (postWiggle.abs() * 0.03),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isNight
                  ? (isScratching ? const Color(0xFF2C2250) : const Color(0xFF1E1838))
                  : (isScratching ? const Color(0xFFFEF9C3) : Colors.white.withValues(alpha: 0.96)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isScratching
                    ? const Color(0xFFF59E0B)
                    : (isNight ? const Color(0xFFF59E0B).withValues(alpha: 0.6) : const Color(0xFFFDE68A)),
                width: isScratching ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: isScratching ? 0.38 : (isNight ? 0.22 : 0.14)),
                  blurRadius: isScratching ? 14 : 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isScratching ? '🐾' : '🪵', style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isScratching
                        ? const Color(0xFFF59E0B)
                        : (isNight ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isScratching ? '解压中' : '磨爪',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isScratching
                          ? Colors.white
                          : (isNight ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 空间环境 1：法式优雅复古拱窗 (French Arch Window)
class FrenchArchWindow extends StatelessWidget {
  final bool isNight;
  final int windowWeather;
  final double windowScale;
  final VoidCallback onTap;

  const FrenchArchWindow({
    super.key,
    required this.isNight,
    required this.windowWeather,
    required this.windowScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 0: ☀️ 暖阳晴空, 1: 🌧️ 治愈雨季, 2: 🌸 春日落樱, 3: 🌙 浪漫星空
    final gradients = [
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF38BDF8), Color(0xFFBAE6FD)],
      ),
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF475569), Color(0xFF94A3B8)],
      ),
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF472B6), Color(0xFFFCE7F3)],
      ),
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F172A), Color(0xFF312E81)],
      ),
    ];

    final weatherTags = ['☀️ 晴空', '🌧️ 细雨', '🌸 落樱', '🌙 星夜'];

    return GestureDetector(
      key: const ValueKey('french_arch_window'),
      onTap: onTap,
      child: AnimatedScale(
        scale: windowScale,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Container(
          width: 86,
          height: 112,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(43), bottom: Radius.circular(6)),
            border: Border.all(
              color: isNight ? const Color(0xFF4338CA).withValues(alpha: 0.8) : const Color(0xFFE2E8F0),
              width: 3.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isNight ? 0.35 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(39), bottom: Radius.circular(3)),
            child: Stack(
              children: [
                Container(decoration: BoxDecoration(gradient: gradients[windowWeather])),
                if (windowWeather == 0) ...[
                  const Positioned(top: 10, right: 10, child: Text('☀️', style: TextStyle(fontSize: 16))),
                  const Positioned(bottom: 22, left: 10, child: Text('☁️', style: TextStyle(fontSize: 14))),
                ] else if (windowWeather == 1) ...[
                  const Positioned(top: 8, left: 12, child: Text('🌧️', style: TextStyle(fontSize: 16))),
                  Positioned(
                    bottom: 20,
                    right: 14,
                    child: Text('💧', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
                  ),
                  Positioned(
                    top: 36,
                    left: 22,
                    child: Container(
                      width: 1.5,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 55,
                    right: 28,
                    child: Container(
                      width: 1.5,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ] else if (windowWeather == 2) ...[
                  const Positioned(top: 12, left: 10, child: Text('🌸', style: TextStyle(fontSize: 14))),
                  const Positioned(bottom: 22, right: 10, child: Text('🌸', style: TextStyle(fontSize: 11))),
                ] else ...[
                  const Positioned(top: 8, right: 10, child: Text('🌙', style: TextStyle(fontSize: 14))),
                  const Positioned(bottom: 22, left: 12, child: Text('✨', style: TextStyle(fontSize: 11))),
                ],
                Center(
                  child: Container(
                    width: 2.0,
                    height: double.infinity,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                Positioned(
                  top: 48,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 2.0,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                Positioned(
                  bottom: 3,
                  left: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        weatherTags[windowWeather],
                        style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 空间环境 2：阳光光斑 (Sunbeam Patch - 晴空暖阳下映照在木地板上的柔和光斑 + 丁达尔浮动金尘)
class SunbeamPatch extends StatelessWidget {
  final double nestX;
  final double nestY;
  final Animation<double> idleAnimation;

  const SunbeamPatch({
    super.key,
    required this.nestX,
    required this.nestY,
    required this.idleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: nestX + 32,
      top: nestY - 22,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: idleAnimation,
          builder: (context, _) {
            final animVal = idleAnimation.value * 2 * math.pi;
            return Transform.rotate(
              angle: -0.16,
              child: Container(
                width: 120,
                height: 62,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.elliptical(60, 31)),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFFEF08A).withValues(alpha: 0.36),
                      const Color(0xFFFDE047).withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Opacity(
                      opacity: 0.28,
                      child: Text('☀️', style: TextStyle(fontSize: 18, color: Color(0xFFF59E0B))),
                    ),
                    // 丁达尔金光微尘 (Dust Motes ✨ ⭐)
                    Positioned(
                      top: 14 + math.sin(animVal) * 3,
                      left: 28 + math.cos(animVal) * 4,
                      child: Opacity(
                        opacity: (0.45 + math.sin(animVal).abs() * 0.35).clamp(0.0, 1.0),
                        child: const Text('✨', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                    Positioned(
                      bottom: 12 - math.sin(animVal) * 3,
                      right: 24 - math.cos(animVal) * 4,
                      child: Opacity(
                        opacity: (0.35 + math.cos(animVal).abs() * 0.35).clamp(0.0, 1.0),
                        child: const Text('⭐', style: TextStyle(fontSize: 9)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 暖绒云朵舒睡圆垫主体 (置于猫咪身下地板，极简轻奢)
class CatRugBed extends StatelessWidget {
  final double nestX;
  final double nestY;
  final bool isNight;
  final VoidCallback onTap;

  const CatRugBed({
    super.key,
    required this.nestX,
    required this.nestY,
    required this.isNight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const rugWidth = 148.0;
    const rugHeight = 68.0;

    return Positioned(
      left: nestX - rugWidth / 2,
      top: nestY + 12.0,
      width: rugWidth,
      height: rugHeight,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: 2,
              child: Container(
                width: rugWidth * 0.92,
                height: rugHeight * 0.44,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.elliptical(rugWidth * 0.92 / 2, rugHeight * 0.44 / 2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isNight ? 0.25 : 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: rugWidth,
              height: rugHeight,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.elliptical(rugWidth / 2, rugHeight / 2)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isNight
                      ? [const Color(0xFF2B2252).withValues(alpha: 0.55), const Color(0xFF1D1739).withValues(alpha: 0.60)]
                      : [const Color(0xFFFFFDF5).withValues(alpha: 0.68), const Color(0xFFFEF3C7).withValues(alpha: 0.45)],
                ),
                border: Border.all(
                  color: isNight
                      ? const Color(0xFF6366F1).withValues(alpha: 0.28)
                      : const Color(0xFFFDE68A).withValues(alpha: 0.60),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Opacity(
                  opacity: isNight ? 0.14 : 0.16,
                  child: Text(
                    '🐾',
                    style: TextStyle(
                      fontSize: 16,
                      color: isNight ? const Color(0xFFC7D2FE) : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 暖绒圆垫前侧轻触响应区 (位于圆垫前缘，零遮挡猫爪，支持轻触触发幸福踩奶，长按一键就寝)
class CozyCatRug extends StatelessWidget {
  final double nestX;
  final double nestY;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const CozyCatRug({
    super.key,
    required this.nestX,
    required this.nestY,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: const ValueKey('cozy_cat_rug'),
      left: nestX - 85.0,
      top: nestY + 65.0,
      width: 170.0,
      height: 28.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

/// 舒睡暖垫小被子 (Tuck-in Blanket - 支持盖被被与掀被被微互动)
class CoveredBlanket extends StatelessWidget {
  final double nestX;
  final double nestY;
  final double petX;
  final double petY;
  final bool isNight;
  final bool isCoveredWithBlanket;
  final Animation<double> idleAnimation;
  final VoidCallback onToggleBlanket;
  final VoidCallback onBlanketTap;
  final bool isWardrobeMode;

  const CoveredBlanket({
    super.key,
    required this.nestX,
    required this.nestY,
    required this.petX,
    required this.petY,
    required this.isNight,
    required this.isCoveredWithBlanket,
    required this.idleAnimation,
    required this.onToggleBlanket,
    required this.onBlanketTap,
    this.isWardrobeMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCatAtBed = (petX - nestX).abs() < 45 && (petY - nestY).abs() < 45;
    if (!isCatAtBed && !isCoveredWithBlanket) {
      return const Positioned(child: SizedBox.shrink());
    }

    if (!isCoveredWithBlanket) {
      return Positioned(
        key: const ValueKey('tuck_in_blanket_button'),
        left: nestX + 48,
        top: nestY + 28,
        child: AnimatedOpacity(
          opacity: isWardrobeMode ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: isWardrobeMode,
            child: BouncyTouchFeedback(
              scaleDown: 0.92,
              onTap: onToggleBlanket,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFB7185), Color(0xFFF43F5E)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🛏️', style: TextStyle(fontSize: 10)),
                    SizedBox(width: 2.5),
                    Text('盖被被', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final breathOffset = math.sin(idleAnimation.value * 2 * math.pi) * 2.2;

    return Positioned(
      key: const ValueKey('covered_blanket'),
      left: petX - 62,
      top: petY + 18 + breathOffset,
      child: AnimatedOpacity(
        opacity: isWardrobeMode ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: IgnorePointer(
          ignoring: isWardrobeMode,
          child: BouncyTouchFeedback(
            scaleDown: 0.95,
            onTap: onBlanketTap,
            child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 124,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isNight
                      ? const [Color(0xFF4C1D95), Color(0xFF312E81)]
                      : const [Color(0xFFFECDD3), Color(0xFFFDA4AF)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  topRight: Radius.circular(22),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(
                  color: isNight ? const Color(0xFF8B5CF6) : const Color(0xFFF43F5E),
                  width: 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      child: CustomPaint(
                        painter: BlanketQuiltPainter(isNight: isNight),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        border: Border(
                          bottom: BorderSide(
                            color: (isNight ? const Color(0xFF8B5CF6) : const Color(0xFFF43F5E)).withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    height: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.14),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 22,
                    left: 18,
                    child: Text('🐾', style: TextStyle(fontSize: 10, color: Colors.white70)),
                  ),
                  const Positioned(
                    top: 32,
                    right: 22,
                    child: Text('⭐', style: TextStyle(fontSize: 10, color: Colors.white70)),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -8,
              right: -6,
              child: BouncyTouchFeedback(
                scaleDown: 0.90,
                onTap: onToggleBlanket,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF43F5E), width: 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4),
                    ],
                  ),
                  child: const Text('掀被 ☀️', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFFE11D48))),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
}
}

/// 软装家具 4：萌猫床头立式暖光小台灯 (陶瓷底座 + 复古褶皱柔光灯罩 + 实体拉绳“啪嗒”开关)
class KittenNightLamp extends StatelessWidget {
  final bool isNight;
  final bool isNightLampOn;
  final bool isLampSwitchDepressed;
  final String ambientMode;
  final VoidCallback? onAmbientTap;
  final VoidCallback onLampTap;

  const KittenNightLamp({
    super.key,
    required this.isNight,
    required this.isNightLampOn,
    required this.isLampSwitchDepressed,
    this.ambientMode = 'none',
    this.onAmbientTap,
    required this.onLampTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTouchFeedback(
      key: const ValueKey('cat_night_lamp_furniture'),
      scaleDown: 0.94,
      onTap: onLampTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. 复古柔光小灯罩 (带微光猫爪暗纹与温润暖黄光晕)
            Container(
              width: 38,
              height: 24,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isNightLampOn
                      ? [
                          const Color(0xFFFEF3C7),
                          const Color(0xFFFDE68A),
                          const Color(0xFFF59E0B),
                        ]
                      : (isNight
                          ? [const Color(0xFF334155), const Color(0xFF1E293B)]
                          : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)]),
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                  bottomLeft: Radius.circular(5),
                  bottomRight: Radius.circular(5),
                ),
                border: Border.all(
                  color: isNightLampOn
                      ? const Color(0xFFF59E0B)
                      : (isNight ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                  width: 1.2,
                ),
                boxShadow: isNightLampOn
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          blurRadius: 14,
                          spreadRadius: 2,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
              ),
              child: Center(
                child: Text(
                  isNightLampOn ? '🐾' : '💡',
                  style: TextStyle(
                    fontSize: 12,
                    color: isNightLampOn
                        ? const Color(0xFFB45309).withValues(alpha: 0.8)
                        : (isNight ? Colors.white38 : Colors.black26),
                  ),
                ),
              ),
            ),

            // 2. 拟真中轴灯柱与垂落拉绳开关 (拉绳随点击位移动态回弹)
            SizedBox(
              width: 34,
              height: 12,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 中轴细灯柱
                  Container(
                    width: 3,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  // 右侧垂挂拉绳开关 (拉拽位移)
                  Positioned(
                    right: 6,
                    top: 0,
                    child: Transform.translate(
                      offset: Offset(0, isLampSwitchDepressed ? 3.5 : 0.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 1.2,
                            height: 6,
                            color: isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          Container(
                            width: 4.5,
                            height: 4.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isNightLampOn
                                  ? const Color(0xFFF59E0B)
                                  : (isNight ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              boxShadow: isNightLampOn
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                                        blurRadius: 3,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. 复古实木/陶瓷圆形底座 + 铭刻 ON/OFF 开关铭牌 (满足测试并模拟真实开关状态)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isNight ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isNightLampOn
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                      : (isNight ? const Color(0xFF475569) : const Color(0xFFE2E8F0)),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isNight ? 0.3 : 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isNightLampOn ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    isNightLampOn ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: isNightLampOn
                          ? (isNight ? const Color(0xFFFDE68A) : const Color(0xFFD97706))
                          : (isNight ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 空间环境 3：春日落樱花瓣 (Sakura Petals)
class SakuraPetalsBuilder {
  static List<Widget> build({
    required Size screenSize,
    required Animation<double> idleAnimation,
    required void Function(int index, double x, double y) onPetalTap,
  }) {
    final basePositions = [
      Offset(screenSize.width * 0.22, 175),
      Offset(screenSize.width * 0.76, 215),
      Offset(screenSize.width * 0.48, 290),
    ];

    return List.generate(basePositions.length, (index) {
      final base = basePositions[index];
      final phase = index * 1.8;
      final animVal = idleAnimation.value * 2 * math.pi;
      final floatX = base.dx + math.sin(animVal + phase) * 14;
      final floatY = base.dy + math.cos(animVal + phase) * 10;
      final angle = math.sin(animVal + phase) * 0.35;

      return Positioned(
        key: ValueKey('sakura_petal_$index'),
        left: floatX,
        top: floatY,
        child: GestureDetector(
          onTap: () => onPetalTap(index, floatX, floatY),
          child: Transform.rotate(
            angle: angle,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: const Text('🌸', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      );
    });
  }
}
