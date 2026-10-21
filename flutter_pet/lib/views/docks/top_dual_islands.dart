import 'package:flutter/material.dart';
import '../../models/pet_model.dart';
import '../../services/sound_service.dart';
import '../../theme/poko_theme.dart';

/// 顶部双灵动岛浮空栏：左侧身份好感 + 右侧饱腹心情小窝。
///
/// 统一后的规范:
///  - 卡片外观全部走设计令牌 (同一张底色 / 1px 描边 / 同一档阴影);
///  - 字号下限提到 8pt, 正文不低于 9pt (原先最小 6.5pt, 在高密度屏上几乎不可读);
///  - 图标按钮触摸区从 ~19x16 提升到 30x30, 贴近移动端可用尺寸;
///  - 窄屏自适应: 外层用 [LayoutBuilder] 按可用宽度给两侧灵动岛分配上限,
///    岛内文本一律走 [Flexible] + 省略号收缩, 因此 360px 窄屏也不会溢出。
class TopDualIslands extends StatelessWidget {
  final PetModel petModel;
  final Size screenSize;
  final bool isNight;
  final Map<String, dynamic> circadianTheme;
  final bool isManualSky;
  final VoidCallback onIntimacyTap;
  final VoidCallback onSoundToggle;
  final VoidCallback onFootprintsToggle;
  final VoidCallback onSkyRhythmToggle;
  final VoidCallback onResetToMat;

  const TopDualIslands({
    super.key,
    required this.petModel,
    required this.screenSize,
    required this.isNight,
    required this.circadianTheme,
    required this.isManualSky,
    required this.onIntimacyTap,
    required this.onSoundToggle,
    required this.onFootprintsToggle,
    required this.onSkyRhythmToggle,
    required this.onResetToMat,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    final bondInfo = petModel.intimacyBondInfo;
    final bondColor = Color(bondInfo['color'] as int);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double avail =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左岛上限 47%, 右岛 51% —— 合计 98%, 天然留出安全间隙
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: avail * 0.47),
              child: _leftIsland(context, t, bondInfo, bondColor, avail),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: avail * 0.51),
              child: _rightIsland(context, t),
            ),
          ],
        );
      },
    );
  }

  /// 左侧灵动岛：等级、名称与亲密称号徽章
  Widget _leftIsland(
    BuildContext context,
    PokoTokens t,
    Map<String, dynamic> bondInfo,
    Color bondColor,
    double avail,
  ) {
    return _islandShell(
      context,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 等级徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: PokoPalette.brandGradient),
              borderRadius: BorderRadius.circular(PokoRadius.xs),
            ),
            child: Text(
              'Lv.${petModel.level}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: PokoSpacing.xs),
          // 名称 + 亲密度 + 称号 (文本可收缩, 窄屏自动省略)
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (avail * 0.22).clamp(40.0, 88.0),
                  ),
                  child: Text(
                    petModel.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: PokoFont.caption,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '❤️ ${petModel.intimacy}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: isNight ? PokoPalette.rose : PokoPalette.roseDeep,
                      ),
                    ),
                    const SizedBox(width: 3),
                    // 亲密羁绊称号勋章 (点按呼出成就卡片)
                    // 空间不足时逐级降级: 完整称号 -> 仅图标 -> 整体隐藏, 保证不溢出
                    Flexible(
                      child: LayoutBuilder(
                        builder: (context, badgeConstraints) {
                          if (badgeConstraints.maxWidth < 19) {
                            return const SizedBox.shrink();
                          }
                          final bool showTitle = badgeConstraints.maxWidth >= 32;
                          return GestureDetector(
                            key: const ValueKey('intimacy_bond_badge'),
                            behavior: HitTestBehavior.opaque,
                            onTap: onIntimacyTap,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: bondColor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(PokoRadius.xs),
                                border: Border.all(
                                    color: bondColor.withValues(alpha: 0.55), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(bondInfo['icon'] as String,
                                      style: const TextStyle(fontSize: PokoFont.micro)),
                                  if (showTitle) ...[
                                    const SizedBox(width: 2),
                                    Flexible(
                                      child: Text(
                                        bondInfo['title'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: PokoFont.micro,
                                          fontWeight: FontWeight.bold,
                                          height: 1.2,
                                          color: bondColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 右侧灵动岛：状态数值 + 快捷工具组
  Widget _rightIsland(BuildContext context, PokoTokens t) {
    return _islandShell(
      context,
      padding: const EdgeInsets.symmetric(horizontal: PokoSpacing.sm, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 上排：饱腹 / 心情 / 天象
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🍗', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 3),
              Text(
                '${petModel.hunger.toInt()}%',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  color: PokoPalette.amber,
                ),
              ),
              const SizedBox(width: PokoSpacing.xs),
              const Text('💖', style: TextStyle(fontSize: 9)),
              const SizedBox(width: 3),
              Text(
                '${petModel.mood.toInt()}%',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  color: PokoPalette.emerald,
                ),
              ),
              const SizedBox(width: 3),
              // 天象徽章 (轻触亦可流转天光) —— 名称可省略, 模式标签空间不足时隐藏
              Flexible(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onSkyRhythmToggle,
                  child: LayoutBuilder(
                    builder: (context, badgeConstraints) {
                      final bool showMode = badgeConstraints.maxWidth >= 32;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              circadianTheme['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                color: t.textSecondary,
                              ),
                            ),
                          ),
                          if (showMode) ...[
                            const SizedBox(width: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                              decoration: BoxDecoration(
                                color: !isManualSky
                                    ? (isNight
                                        ? PokoPalette.indigoDeep
                                        : PokoPalette.mintSoft)
                                    : (isNight
                                        ? PokoPalette.violetDeep
                                        : PokoPalette.amberSoft),
                                borderRadius: BorderRadius.circular(PokoRadius.xs),
                              ),
                              child: Text(
                                !isManualSky ? '自然' : '模式',
                                style: TextStyle(
                                  fontSize: PokoFont.micro,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                  color: !isManualSky
                                      ? (isNight
                                          ? PokoPalette.indigoSoft
                                          : PokoPalette.mintDeep)
                                      : (isNight
                                          ? PokoPalette.violetSoft
                                          : PokoPalette.amberDeep),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 下排：快捷开关组
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _toggleButton(
                context,
                key: const ValueKey('sound_toggle_button'),
                active: SoundService.soundEnabled,
                activeColor: isNight
                    ? PokoPalette.indigo.withValues(alpha: 0.38)
                    : PokoPalette.indigoSoft,
                child: Text(SoundService.soundEnabled ? '🔊' : '🔇',
                    style: const TextStyle(fontSize: 13)),
                onTap: onSoundToggle,
              ),
              const SizedBox(width: PokoSpacing.xs),
              _toggleButton(
                context,
                key: const ValueKey('footprint_toggle_button'),
                active: petModel.enableFootprints,
                activeColor: isNight
                    ? PokoPalette.rose.withValues(alpha: 0.32)
                    : PokoPalette.roseSoft,
                child: Text(petModel.enableFootprints ? '🐾' : '🧹',
                    style: const TextStyle(fontSize: 13)),
                onTap: onFootprintsToggle,
              ),
              const SizedBox(width: PokoSpacing.xs),
              _toggleButton(
                context,
                key: const ValueKey('sky_rhythm_toggle_button'),
                active: isManualSky,
                activeColor: isNight
                    ? PokoPalette.violet.withValues(alpha: 0.38)
                    : PokoPalette.amberSoft,
                child: Text(circadianTheme['icon'] as String,
                    style: const TextStyle(fontSize: 13)),
                onTap: onSkyRhythmToggle,
              ),
              const SizedBox(width: PokoSpacing.xs),
              _toggleButton(
                context,
                active: false,
                activeColor: Colors.transparent,
                child: Icon(
                  Icons.home_rounded,
                  size: 15,
                  color: t.textSecondary,
                ),
                onTap: onResetToMat,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 灵动岛统一外壳
  Widget _islandShell(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: PokoSpacing.sm, vertical: 6),
  }) {
    final t = context.poko(isNight);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: isNight ? 0.88 : 0.94),
        borderRadius: BorderRadius.circular(PokoRadius.lg),
        border: Border.all(color: t.border, width: 1),
        boxShadow: PokoShadow.soft(t.shadow),
      ),
      child: child,
    );
  }

  /// 快捷开关按钮 (触摸区 30x30, 极端窄屏下等比收缩)
  Widget _toggleButton(
    BuildContext context, {
    required bool active,
    required Color activeColor,
    required Widget child,
    required VoidCallback onTap,
    Key? key,
  }) {
    return Flexible(
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(PokoRadius.xs),
          ),
          child: child,
        ),
      ),
    );
  }
}
