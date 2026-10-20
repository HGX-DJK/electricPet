import 'package:flutter/material.dart';
import '../../models/pet_model.dart';
import '../../services/sound_service.dart';

/// 顶部双灵动岛浮空栏：左侧身份好感 + 右侧饱腹心情小窝，紧凑优雅，严防窄屏溢出
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
    final bondInfo = petModel.intimacyBondInfo;
    final bondColor = Color(bondInfo['color'] as int);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 左侧灵动岛：萌宠等级、名称与亲密称号徽章 (双层精简卡片，绝不挤压横向空间)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
          decoration: BoxDecoration(
            color: isNight
                ? const Color(0xFF181534).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNight ? const Color(0xFF6366F1).withValues(alpha: 0.35) : Colors.white,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: isNight
                    ? const Color(0xFF0F0C24).withValues(alpha: 0.5)
                    : const Color(0xFF6366F1).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 等级徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Lv.${petModel.level}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              // 垂直布局：上方名称，下方亲密度与称号徽章
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: (screenSize.width * 0.22).clamp(55.0, 85.0)),
                    child: Text(
                      petModel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isNight ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 1.5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '❤️ ${petModel.intimacy}',
                        style: TextStyle(
                          fontSize: 8.0,
                          fontWeight: FontWeight.w600,
                          color: isNight ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
                        ),
                      ),
                      const SizedBox(width: 3.5),
                      // 亲密羁绊称号勋章胶囊 (点按呼出成就卡片)
                      GestureDetector(
                        key: const ValueKey('intimacy_bond_badge'),
                        onTap: onIntimacyTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
                          decoration: BoxDecoration(
                            color: bondColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: bondColor.withValues(alpha: 0.55),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(bondInfo['icon'] as String, style: const TextStyle(fontSize: 7.5)),
                              const SizedBox(width: 1.5),
                              Text(
                                bondInfo['title'] as String,
                                style: TextStyle(
                                  fontSize: 7.0,
                                  fontWeight: FontWeight.bold,
                                  color: bondColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. 右侧灵动岛：饱腹与心情 + 快捷工具组 (双层设计，通透呼吸，绝不溢出)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: isNight
                ? const Color(0xFF181534).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isNight ? const Color(0xFF6366F1).withValues(alpha: 0.35) : Colors.white,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: isNight
                    ? const Color(0xFF0F0C24).withValues(alpha: 0.5)
                    : const Color(0xFF6366F1).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 上排：饱腹与心情状态数值 + 真实天象时空徽章
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🍗', style: TextStyle(fontSize: 8.5)),
                  const SizedBox(width: 1.5),
                  Text(
                    '${petModel.hunger.toInt()}%',
                    style: const TextStyle(
                      fontSize: 8.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    width: 2.0,
                    height: 2.0,
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Text('💖', style: TextStyle(fontSize: 8.5)),
                  const SizedBox(width: 1.5),
                  Text(
                    '${petModel.mood.toInt()}%',
                    style: const TextStyle(
                      fontSize: 8.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 3.5),
                  Container(
                    width: 1.0,
                    height: 7.5,
                    color: isNight ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                  ),
                  const SizedBox(width: 3.5),
                  // 时空天光微徽章 (轻触亦可流转天光)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSkyRhythmToggle,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          circadianTheme['name'] as String,
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                            color: isNight ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: !isManualSky
                                ? (isNight ? const Color(0xFF312E81) : const Color(0xFFDCFCE7))
                                : (isNight ? const Color(0xFF4C1D95) : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            !isManualSky ? '自然' : '模式',
                            style: TextStyle(
                              fontSize: 6.5,
                              fontWeight: FontWeight.bold,
                              color: !isManualSky
                                  ? (isNight ? const Color(0xFFC7D2FE) : const Color(0xFF166534))
                                  : (isNight ? const Color(0xFFDDD6FE) : const Color(0xFFB45309)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2.5),
              // 下排：一体化半透明磨砂快捷微胶囊群 (声音、爪印、天光、回窝)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 2.0),
                decoration: BoxDecoration(
                  color: isNight
                      ? const Color(0xFF1E1A40).withValues(alpha: 0.65)
                      : const Color(0xFFF8FAFC).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isNight
                        ? const Color(0xFF6366F1).withValues(alpha: 0.22)
                        : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. 音效开关
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onSoundToggle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: SoundService.soundEnabled
                              ? (isNight ? const Color(0xFF4338CA).withValues(alpha: 0.6) : const Color(0xFFEEF2FF))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          SoundService.soundEnabled ? '🔊' : '🔇',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2.5),
                    // 2. 地板猫爪印开关
                    GestureDetector(
                      key: const ValueKey('footprint_toggle_button'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onFootprintsToggle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: petModel.enableFootprints
                              ? (isNight ? const Color(0xFFBE185D).withValues(alpha: 0.45) : const Color(0xFFFFF1F2))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          petModel.enableFootprints ? '🐾' : '🧹',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2.5),
                    // 3. 天光罗盘开关
                    GestureDetector(
                      key: const ValueKey('sky_rhythm_toggle_button'),
                      behavior: HitTestBehavior.opaque,
                      onTap: onSkyRhythmToggle,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isManualSky
                              ? (isNight ? const Color(0xFF581C87).withValues(alpha: 0.5) : const Color(0xFFFEF3C7))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          circadianTheme['icon'] as String,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2.5),
                    // 4. 回到小窝按钮
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onResetToMat,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.home_rounded,
                          size: 13.5,
                          color: isNight ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
