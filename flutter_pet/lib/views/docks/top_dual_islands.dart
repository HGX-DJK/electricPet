import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../models/pet_model.dart';
import '../../services/sound_service.dart';
import '../../theme/poko_theme.dart';
import '../../widgets/bouncy_touch_feedback.dart';

/// 顶部双灵动岛浮空栏：左侧萌宠身份水晶勋章 + 右侧活力状态与微晶操控台。
///
/// 视觉与布局重构要点:
///  1. 完美双岛等高基准：两侧高度统一(约56-58px)，彻底消除原先“左瘪右鼓”的失衡视觉倾斜；
///  2. 极光毛玻璃微拟态：引入 [BackdropFilter] 柔和高斯模糊与 1.2px 高光微描边，呈现浮空透气晶体质感；
///  3. 萌宠身份温度：左侧增加立体头像萌猫光环与外嵌 Lv 徽章，名字、亲密度、羁绊勋章呼吸排布；
///  4. 状态与控制去拥挤：右侧上层使用精巧双联芯片展示饱腹、心情与天象，下层统一使用水滴微晶圆纽，
///     消除花里胡哨的五彩方块贴纸感，交互手感丝滑。
class TopDualIslands extends StatelessWidget {
  final PetModel petModel;
  final Size screenSize;
  final bool isNight;
  final Map<String, dynamic> circadianTheme;
  final bool isManualSky;
  final String ambientMode;
  final VoidCallback? onAmbientToggle;
  final VoidCallback onIntimacyTap;
  final VoidCallback onSoundToggle;
  final VoidCallback onFootprintsToggle;
  final VoidCallback onSkyRhythmToggle;

  const TopDualIslands({
    super.key,
    required this.petModel,
    required this.screenSize,
    required this.isNight,
    required this.circadianTheme,
    required this.isManualSky,
    this.ambientMode = 'none',
    this.onAmbientToggle,
    required this.onIntimacyTap,
    required this.onSoundToggle,
    required this.onFootprintsToggle,
    required this.onSkyRhythmToggle,
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
            // 左岛上限 47%, 右岛 51% —— 自然避开正中央的天窗景致
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

  /// 左侧灵动岛：萌宠头像勋章 + 等级 + 名字 + 亲密胶囊 + 羁绊成就
  Widget _leftIsland(
    BuildContext context,
    PokoTokens t,
    Map<String, dynamic> bondInfo,
    Color bondColor,
    double avail,
  ) {
    return _islandShell(
      context,
      minHeight: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 萌宠头像 + 嵌套 Lv 气泡
          _petAvatarBadge(context, t),
          const SizedBox(width: 6),
          // 名字、亲密值与称号 (弹性自适应排版)
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 上行：名字 + 亲密爱心小胶囊
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        petModel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: 0.2,
                          color: t.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3.5),
                    // 亲密度药丸
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: isNight
                            ? PokoPalette.rose.withValues(alpha: 0.2)
                            : const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(PokoRadius.pill),
                        border: Border.all(
                          color: PokoPalette.rose.withValues(alpha: isNight ? 0.45 : 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('❤️', style: TextStyle(fontSize: 8)),
                          const SizedBox(width: 2),
                          Text(
                            '${petModel.intimacy}',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: isNight ? PokoPalette.rose : PokoPalette.roseDeep,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // 下行：亲密羁绊称号勋章 (支持点按弹窗)
                Flexible(
                  child: LayoutBuilder(
                    builder: (context, badgeConstraints) {
                      if (badgeConstraints.maxWidth < 18) {
                        return const SizedBox.shrink();
                      }
                      final bool showTitle = badgeConstraints.maxWidth >= 32;
                      return BouncyTouchFeedback(
                        key: const ValueKey('intimacy_bond_badge'),
                        scaleDown: 0.94,
                        onTap: onIntimacyTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: bondColor.withValues(
                              alpha: isNight ? 0.22 : 0.12,
                            ),
                            borderRadius: BorderRadius.circular(PokoRadius.pill),
                            border: Border.all(
                              color: bondColor.withValues(
                                alpha: isNight ? 0.6 : 0.45,
                              ),
                              width: 0.9,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                bondInfo['icon'] as String,
                                style: const TextStyle(fontSize: 8.5),
                              ),
                              if (showTitle) ...[
                                const SizedBox(width: 2.5),
                                Flexible(
                                  child: Text(
                                    bondInfo['title'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      height: 1.15,
                                      color: bondColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 1),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 10,
                                  color: bondColor.withValues(alpha: 0.75),
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
          ),
        ],
      ),
    );
  }

  /// 萌猫微头像 + 嵌套 Lv 等级气泡
  Widget _petAvatarBadge(BuildContext context, PokoTokens t) {
    return BouncyTouchFeedback(
      scaleDown: 0.92,
      onTap: onIntimacyTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // 头像圆形光环底座
          Container(
            width: 35,
            height: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isNight
                    ? const [Color(0xFF3730A3), Color(0xFF581C87)]
                    : const [Color(0xFFFFF7ED), Color(0xFFFEE2E2), Color(0xFFF3E8FF)],
              ),
              border: Border.all(
                color: isNight
                    ? const Color(0xFF6366F1).withValues(alpha: 0.6)
                    : Colors.white,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isNight ? const Color(0xFF0F0B2E) : const Color(0xFF7C3AED))
                      .withValues(alpha: isNight ? 0.35 : 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text('🐱', style: TextStyle(fontSize: 17)),
          ),
          // 悬浮右下角等级微标
          Positioned(
            bottom: -2,
            right: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 0.8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: PokoPalette.brandGradient,
                ),
                borderRadius: BorderRadius.circular(PokoRadius.pill),
                border: Border.all(
                  color: Colors.white,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                'Lv.${petModel.level}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 右侧灵动岛：双联状态微晶胶囊 + 微晶操作圆钮
  Widget _rightIsland(BuildContext context, PokoTokens t) {
    return _islandShell(
      context,
      minHeight: 56.0,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 上排：饱腹/心情 + 天象环境徽章
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 饱腹 & 心情双联药丸 (自然流线尺寸，紧凑呼吸)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: t.surfaceAlt.withValues(
                    alpha: isNight ? 0.65 : 0.85,
                  ),
                  borderRadius: BorderRadius.circular(PokoRadius.pill),
                  border: Border.all(
                    color: t.border.withValues(alpha: isNight ? 0.35 : 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🍗', style: TextStyle(fontSize: 8.5)),
                    const SizedBox(width: 1.5),
                    Text(
                      '${petModel.hunger.toInt()}%',
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: PokoPalette.amberDeep,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      color: t.border.withValues(alpha: 0.8),
                    ),
                    const Text('💖', style: TextStyle(fontSize: 8.5)),
                    const SizedBox(width: 1.5),
                    Text(
                      '${petModel.mood.toInt()}%',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: isNight
                            ? const Color(0xFF34D399)
                            : PokoPalette.emeraldDeep,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 3),
              // 天象环境徽章 (轻触流转天光，可收缩适配窄屏)
              Flexible(
                child: BouncyTouchFeedback(
                  scaleDown: 0.94,
                  onTap: onSkyRhythmToggle,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (!isManualSky
                              ? (isNight ? PokoPalette.indigoDeep : PokoPalette.mintSoft)
                              : (isNight ? PokoPalette.violetDeep : PokoPalette.amberSoft))
                          .withValues(alpha: isNight ? 0.35 : 0.85),
                      borderRadius: BorderRadius.circular(PokoRadius.pill),
                      border: Border.all(
                        color: (!isManualSky
                                ? (isNight ? PokoPalette.indigo : PokoPalette.mintDeep)
                                : (isNight ? PokoPalette.violet : PokoPalette.amberDeep))
                            .withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          circadianTheme['icon'] as String,
                          style: const TextStyle(fontSize: 8.5),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            circadianTheme['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: t.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.6),
                          decoration: BoxDecoration(
                            color: !isManualSky
                                ? (isNight ? PokoPalette.indigo : PokoPalette.mintDeep)
                                : (isNight ? PokoPalette.violet : PokoPalette.amberDeep),
                            borderRadius: BorderRadius.circular(PokoRadius.xs),
                          ),
                          child: Text(
                            !isManualSky ? '自然' : '模式',
                            style: const TextStyle(
                              fontSize: 7.0,
                              fontWeight: FontWeight.w900,
                              height: 1.1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // 下排：微晶水滴操控组 (声音、白噪音、足迹、天象)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _actionPearlButton(
                context,
                t,
                key: const ValueKey('sound_toggle_button'),
                active: SoundService.soundEnabled,
                activeAccent: PokoPalette.indigo,
                tooltip: '音效开关',
                onTap: onSoundToggle,
                child: Text(
                  SoundService.soundEnabled ? '🔊' : '🔇',
                  style: const TextStyle(fontSize: 12.0),
                ),
              ),
              if (onAmbientToggle != null)
                _actionPearlButton(
                  context,
                  t,
                  key: const ValueKey('ambient_asmr_toggle_button'),
                  active: ambientMode != 'none',
                  activeAccent: ambientMode == 'rain'
                      ? const Color(0xFF0284C7)
                      : const Color(0xFF9333EA),
                  tooltip: '助眠音效',
                  onTap: onAmbientToggle!,
                  child: Text(
                    ambientMode == 'rain'
                        ? '🌧️'
                        : (ambientMode == 'purr' ? '🐱' : '🎵'),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
              _actionPearlButton(
                context,
                t,
                key: const ValueKey('footprint_toggle_button'),
                active: petModel.enableFootprints,
                activeAccent: PokoPalette.rose,
                tooltip: '肉垫爪印',
                onTap: onFootprintsToggle,
                child: Text(
                  petModel.enableFootprints ? '🐾' : '🧹',
                  style: const TextStyle(fontSize: 12.0),
                ),
              ),
              _actionPearlButton(
                context,
                t,
                key: const ValueKey('sky_rhythm_toggle_button'),
                active: isManualSky,
                activeAccent: PokoPalette.amber,
                tooltip: '流转天象',
                onTap: onSkyRhythmToggle,
                child: Text(
                  circadianTheme['icon'] as String,
                  style: const TextStyle(fontSize: 12.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 通用毛玻璃灵动外壳 (统一 22px 药丸圆角 + 高光微描边 + 柔和双层阴影)
  Widget _islandShell(
    BuildContext context, {
    required Widget child,
    double? minHeight,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  }) {
    final t = context.poko(isNight);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: minHeight != null
              ? BoxConstraints(minHeight: minHeight)
              : null,
          padding: padding,
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: isNight ? 0.85 : 0.90),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isNight
                  ? const Color(0xFF4C4282).withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.95),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: t.shadow.withValues(alpha: isNight ? 0.32 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: (isNight ? Colors.black : t.accent)
                    .withValues(alpha: isNight ? 0.18 : 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  /// 水滴微晶按键：触控果冻弹性回弹 + 统一视觉状态
  Widget _actionPearlButton(
    BuildContext context,
    PokoTokens t, {
    Key? key,
    required bool active,
    required Widget child,
    required VoidCallback onTap,
    Color? activeAccent,
    String? tooltip,
  }) {
    Widget content = BouncyTouchFeedback(
      key: key,
      scaleDown: 0.88,
      onTap: onTap,
      child: Container(
        width: 27,
        height: 25,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? (activeAccent ?? PokoPalette.indigo)
                  .withValues(alpha: isNight ? 0.30 : 0.14)
              : (isNight
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.035)),
          borderRadius: BorderRadius.circular(8.5),
          border: Border.all(
            color: active
                ? (activeAccent ?? PokoPalette.indigo)
                    .withValues(alpha: isNight ? 0.65 : 0.40)
                : t.border.withValues(alpha: isNight ? 0.25 : 0.45),
            width: 0.9,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: (activeAccent ?? PokoPalette.indigo)
                        .withValues(alpha: isNight ? 0.25 : 0.12),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );

    if (tooltip != null) {
      content = Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: content,
      );
    }

    return Flexible(
      child: content,
    );
  }
}
