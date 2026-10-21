import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/poko_theme.dart';
import '../../widgets/bouncy_touch_feedback.dart';

/// 独立发光微动扭蛋机悬浮球 (Cyber Gacha FAB)
/// 悬浮于右侧上方，仪式感拉满，支持微光呼吸动效与高光 SSR 保底角标
class CyberGachaFab extends StatefulWidget {
  final bool isNight;
  final VoidCallback onTap;

  const CyberGachaFab({
    super.key,
    required this.isNight,
    required this.onTap,
  });

  @override
  State<CyberGachaFab> createState() => _CyberGachaFabState();
}

class _CyberGachaFabState extends State<CyberGachaFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poko(widget.isNight);

    return BouncyTouchFeedback(
      key: const ValueKey('cyber_gacha_fab'),
      scaleDown: 0.90,
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          final scale = _glowAnimation.value;
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // 1. 底层呼吸扩散霓虹辉光
              Container(
                width: 54 * scale,
                height: 54 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      PokoPalette.violet.withValues(alpha: widget.isNight ? 0.35 : 0.22),
                      PokoPalette.skyGlow.withValues(alpha: widget.isNight ? 0.18 : 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // 2. 主体水晶拟态微动扭蛋球
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isNight
                        ? [t.surfaceAlt, t.accentAlt]
                        : const [PokoPalette.violetSoft, PokoPalette.skySoft],
                  ),
                  border: Border.all(
                    color: widget.isNight
                        ? PokoPalette.violet.withValues(alpha: 0.7)
                        : PokoPalette.violet,
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: PokoPalette.violet.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: PokoPalette.skyGlow.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🔮',
                    style: TextStyle(fontSize: 24),
                  ),
                ),
              ),

              // 3. 顶部高光闪耀 SSR 保底微型胶囊角标
              Positioned(
                top: -6,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [PokoPalette.amber, PokoPalette.rose],
                    ),
                    borderRadius: BorderRadius.circular(PokoRadius.xs),
                    border: Border.all(color: Colors.white, width: 1.0),
                    boxShadow: [
                      BoxShadow(
                        color: PokoPalette.rose.withValues(alpha: 0.45),
                        blurRadius: 5,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '✨保底',
                        style: TextStyle(
                          fontSize: PokoFont.micro,
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
