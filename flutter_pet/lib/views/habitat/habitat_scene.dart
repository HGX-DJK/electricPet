import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'habitat_painters.dart';

/// 小窝全景地面组件：根据 4 大家园小窝场景 + 默认原木基底渲染立体地面
class HabitatFlooring extends StatelessWidget {
  final String habitat;
  final bool isNight;
  final Animation<double> idleAnimation;

  const HabitatFlooring({
    super.key,
    required this.habitat,
    required this.isNight,
    required this.idleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    switch (habitat) {
      case 'neon_matrix':
        return _buildNeonMatrixFlooring();
      case 'retro_arcade':
        return _buildRetroArcadeFlooring();
      case 'summer_beach':
        return _buildSummerBeachFlooring(isNight);
      case 'zen_tatami':
        return _buildZenTatamiFlooring(isNight);
      case 'none':
      case 'default':
      default:
        return _buildCozyFlooring(isNight);
    }
  }

  /// 场景 1：暗夜霓虹极客房地面 (Matrix 透视全息网格地面与青绿光脉冲)
  Widget _buildNeonMatrixFlooring() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF020617),
            Color(0xFF0B132B),
            Color(0xFF031E2E),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2.5,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF00F0FF),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF00F0FF),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: CyberPerspectiveGridPainter(
                gridColor: const Color(0xFF00F0FF),
                accentColor: const Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 场景 2：复古像素电玩厅地面 (Synthwave 紫红脉冲网格跑道)
  Widget _buildRetroArcadeFlooring() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF130924),
            Color(0xFF22083D),
            Color(0xFF3B0764),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2.5,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFEC4899),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFEC4899),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: CyberPerspectiveGridPainter(
                gridColor: const Color(0xFFD946EF),
                accentColor: const Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 场景 3：夏日阳光海滩地面 (金黄细沙与动态起伏的碧波白浪边缘)
  Widget _buildSummerBeachFlooring(bool isNight) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isNight
              ? const [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF475569)]
              : const [Color(0xFFFED7AA), Color(0xFFFDE68A), Color(0xFFFBBF24)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 28,
            child: AnimatedBuilder(
              animation: idleAnimation,
              builder: (context, _) {
                final shift = math.sin(idleAnimation.value * 2 * math.pi) * 3.0;
                return Container(
                  height: 24 + shift,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF06B6D4).withValues(alpha: 0.55),
                        const Color(0xFF67E8F9).withValues(alpha: 0.35),
                        Colors.white.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.elliptical(200, 16)),
                  ),
                );
              },
            ),
          ),
          const Positioned(
            top: 36,
            left: 30,
            child: Text('🐚', style: TextStyle(fontSize: 14)),
          ),
          const Positioned(
            top: 75,
            right: 45,
            child: Text('⭐', style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B))),
          ),
          const Positioned(
            top: 130,
            left: 70,
            child: Text('🐚', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  /// 场景 4：佛系禅意蒲团室地面 (纯正日式蔺草榻榻米地席与黑绿锦缎滚边)
  Widget _buildZenTatamiFlooring(bool isNight) {
    final tatamiBg = isNight
        ? const [Color(0xFF23201D), Color(0xFF1C1917)]
        : const [Color(0xFFEBE3D3), Color(0xFFDFD6C1)];
    final borderTape = isNight ? const Color(0xFF0F172A) : const Color(0xFF1E2D24);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: tatamiBg,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 8,
            child: Container(
              color: isNight ? const Color(0xFF110E0C) : const Color(0xFF78350F),
            ),
          ),
          Positioned(
            top: 8,
            bottom: 0,
            left: 90,
            width: 7,
            child: Container(
              color: borderTape,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: const Color(0xFFD97706).withValues(alpha: 0.3),
              ),
            ),
          ),
          Positioned(
            top: 8,
            bottom: 0,
            right: 100,
            width: 7,
            child: Container(
              color: borderTape,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: const Color(0xFFD97706).withValues(alpha: 0.3),
              ),
            ),
          ),
          for (int i = 1; i <= 14; i++)
            Positioned(
              top: 8.0 + i * 36.0,
              left: 0,
              right: 0,
              height: 1.0,
              child: Container(
                color: (isNight ? Colors.white : const Color(0xFF854D0E)).withValues(alpha: 0.06),
              ),
            ),
        ],
      ),
    );
  }

  /// 房间立体景深：木质地台与高光踢脚线 (白天浅橡木纹，夜间静谧胡桃木)
  Widget _buildCozyFlooring(bool isNight) {
    final baseboardColor = isNight ? const Color(0xFF1E1738) : const Color(0xFFD4A373);
    final baseboardHighlight = isNight ? const Color(0xFF332A55) : const Color(0xFFFAEDCD);
    final floorGradient = isNight
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF16122C),
              Color(0xFF110D24),
              Color(0xFF0C091A),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFBF4EB),
              Color(0xFFF4E3D0),
              Color(0xFFECD2BA),
            ],
          );
    final plankLineColor = isNight
        ? Colors.white.withValues(alpha: 0.04)
        : const Color(0xFFB07D53).withValues(alpha: 0.12);

    return Container(
      decoration: BoxDecoration(
        gradient: floorGradient,
      ),
      child: Stack(
        children: [
          // 踢脚线顶面高光线
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 3,
            child: Container(color: baseboardHighlight),
          ),
          // 踢脚线主体
          Positioned(
            top: 3,
            left: 0,
            right: 0,
            height: 12,
            child: Container(color: baseboardColor),
          ),
          // 踢脚线下立体阴影
          Positioned(
            top: 15,
            left: 0,
            right: 0,
            height: 8,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: isNight ? 0.35 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // 木地板横向接缝细线
          for (int i = 1; i <= 10; i++)
            Positioned(
              top: 25.0 + i * 52.0,
              left: 0,
              right: 0,
              height: 1.0,
              child: Container(color: plankLineColor),
            ),
        ],
      ),
    );
  }
}

/// 小窝全景背景与定制全屏装饰生成辅助类
class HabitatBackdropBuilder {
  /// 根据 4 大家园小窝场景定制墙面背景与专属全景道具
  static List<Widget> buildBackdrop({
    required String habitat,
    required bool isNight,
    required Size screenSize,
    required double floorTop,
    required Animation<double> idleAnimation,
    required List<Widget> defaultDecorations,
  }) {
    switch (habitat) {
      case 'neon_matrix':
        return _buildNeonMatrixBackdrop(screenSize, floorTop, idleAnimation);
      case 'retro_arcade':
        return _buildRetroArcadeBackdrop(screenSize, floorTop);
      case 'summer_beach':
        return _buildSummerBeachBackdrop(isNight, screenSize, floorTop);
      case 'zen_tatami':
        return _buildZenTatamiBackdrop(isNight, screenSize, floorTop, idleAnimation);
      case 'none':
      case 'default':
      default:
        return defaultDecorations;
    }
  }

  /// 场景 1 背景：暗夜极客全屏代码雨与 HUD 终端
  static List<Widget> _buildNeonMatrixBackdrop(Size screenSize, double floorTop, Animation<double> idleAnimation) {
    return [
      for (int col = 0; col < 8; col++)
        Positioned(
          left: 12.0 + (col * (screenSize.width - 24) / 7),
          top: ((col * 37.0 + idleAnimation.value * 280.0) % (floorTop - 20)),
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('λ', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.bold)),
                Text('0', style: TextStyle(fontSize: 10, color: const Color(0xFF00F0FF).withValues(alpha: 0.7))),
                Text('1', style: TextStyle(fontSize: 10, color: const Color(0xFF10B981).withValues(alpha: 0.6))),
                Text('{', style: TextStyle(fontSize: 9, color: const Color(0xFF10B981).withValues(alpha: 0.35))),
              ],
            ),
          ),
        ),
      Positioned(
        top: 66,
        left: screenSize.width * 0.5 - 110,
        width: 220,
        child: Container(
          key: const ValueKey('matrix_hud'),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF030712).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.7), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  const Text(
                    'POKO MATRIX LAB',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF00F0FF), letterSpacing: 1.2),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '全息算力过载 +20% · 专注无 BUG',
                style: TextStyle(fontSize: 9.5, color: const Color(0xFF67E8F9).withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        left: 20,
        top: floorTop - 25,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF0A192F).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('💾', style: TextStyle(fontSize: 18)),
              SizedBox(width: 4),
              Text('SERVER', style: TextStyle(fontSize: 8, color: Color(0xFF00F0FF), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      Positioned(
        right: 20,
        top: floorTop - 25,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF0A192F).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 4),
              Text('RADAR', style: TextStyle(fontSize: 8, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    ];
  }

  /// 场景 2 背景：复古电玩合成波落日与街机
  static List<Widget> _buildRetroArcadeBackdrop(Size screenSize, double floorTop) {
    return [
      Positioned(
        top: 60,
        left: screenSize.width * 0.5 - 50,
        width: 100,
        height: 100,
        child: Container(
          key: const ValueKey('retro_sun'),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFBBF24), Color(0xFFF43F5E), Color(0xFF9333EA)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF43F5E).withValues(alpha: 0.5),
                blurRadius: 24,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(height: 30),
              for (int i = 0; i < 4; i++)
                Container(
                  height: 3.5,
                  margin: EdgeInsets.symmetric(horizontal: 10.0 + i * 5),
                  color: const Color(0xFF1E1035),
                ),
            ],
          ),
        ),
      ),
      const Positioned(top: 80, left: 35, child: Text('👾', style: TextStyle(fontSize: 20))),
      const Positioned(top: 110, right: 40, child: Text('✨', style: TextStyle(fontSize: 18))),
      Positioned(
        right: 18,
        top: floorTop - 38,
        child: Container(
          key: const ValueKey('arcade_cabinet'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B0764), Color(0xFF1E1035)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEC4899), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🕹️', style: TextStyle(fontSize: 20)),
              SizedBox(width: 4),
              Text(
                'POKO 1984',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFDE047)),
              ),
            ],
          ),
        ),
      ),
      Positioned(
        left: 18,
        top: floorTop - 38,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2E1065).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD946EF).withValues(alpha: 0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📼', style: TextStyle(fontSize: 18)),
              SizedBox(width: 4),
              Text('8-BIT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFF472B6))),
            ],
          ),
        ),
      ),
    ];
  }

  /// 场景 3 背景：夏日海滩椰树与遮阳伞
  static List<Widget> _buildSummerBeachBackdrop(bool isNight, Size screenSize, double floorTop) {
    return [
      Positioned(
        top: 75,
        left: screenSize.width * 0.5 - 40,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isNight ? '🌙' : '☀️', style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            const Text('🕊️', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
      Positioned(
        top: 110,
        left: 50,
        child: Text(isNight ? '✨' : '☁️', style: TextStyle(fontSize: 22, color: Colors.white.withValues(alpha: 0.7))),
      ),
      const Positioned(
        top: 125,
        right: 55,
        child: Text('⛵', style: TextStyle(fontSize: 20)),
      ),
      Positioned(
        key: const ValueKey('beach_palm'),
        left: 12,
        top: floorTop - 85,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌴', style: TextStyle(fontSize: 48)),
            SizedBox(height: 2),
            Text('🥥', style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
      Positioned(
        key: const ValueKey('beach_parasol'),
        right: 18,
        top: floorTop - 65,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('⛱️', style: TextStyle(fontSize: 40)),
            SizedBox(height: 2),
            Text('🏐', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    ];
  }

  /// 场景 4 背景：和风障子推拉门、落樱与静心挂轴
  static List<Widget> _buildZenTatamiBackdrop(
    bool isNight,
    Size screenSize,
    double floorTop,
    Animation<double> idleAnimation,
  ) {
    return [
      Positioned(
        top: 55,
        left: 20,
        right: 20,
        height: floorTop - 65,
        child: Container(
          decoration: BoxDecoration(
            color: (isNight ? const Color(0xFF292524) : const Color(0xFFFFFDF9)).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNight ? const Color(0xFF44403C) : const Color(0xFF78350F),
              width: 2.0,
            ),
          ),
          child: CustomPaint(
            painter: ShojiLatticePainter(
              frameColor: isNight ? const Color(0xFF44403C) : const Color(0xFFB45309),
            ),
          ),
        ),
      ),
      Positioned(
        key: const ValueKey('zen_scroll'),
        top: 66,
        left: screenSize.width * 0.5 - 28,
        width: 56,
        height: 94,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF78350F), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('静', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF451A03), fontFamily: 'serif')),
              SizedBox(height: 2),
              Text('🐾', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
      Positioned(
        left: 24,
        top: floorTop - 25,
        child: const Text('🪴', style: TextStyle(fontSize: 26)),
      ),
      Positioned(
        right: 24,
        top: floorTop - 25,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🍵', style: TextStyle(fontSize: 22)),
            SizedBox(width: 2),
            Text('🫖', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
      for (int i = 0; i < 7; i++)
        Positioned(
          left: ((i * 53.0 + idleAnimation.value * 240.0) % screenSize.width),
          top: ((i * 41.0 + idleAnimation.value * 320.0) % (floorTop + 120.0)),
          child: IgnorePointer(
            child: Transform.rotate(
              angle: i * 0.7 + idleAnimation.value * 3.14,
              child: const Text('🌸', style: TextStyle(fontSize: 14)),
            ),
          ),
        ),
    ];
  }
}
