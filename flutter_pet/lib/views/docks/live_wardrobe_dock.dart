import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pet_model.dart';
import '../../services/haptic_service.dart';
import '../../widgets/bouncy_touch_feedback.dart';

/// 双层零滑动换装坞 (Live Wardrobe Dock)
class LiveWardrobeDock extends StatelessWidget {
  final PetModel petModel;
  final bool isNight;
  final int wardrobeTab;
  final void Function(int tab) onTabChanged;
  final void Function(String skinId) onSkinSelected;
  final void Function(String slot, String itemId) onDecorationSelected;
  final void Function(String habitatId, String icon) onHabitatSelected;
  final VoidCallback onGachaTap;
  final VoidCallback onClose;
  final void Function(String message)? onShowDialogue;

  const LiveWardrobeDock({
    super.key,
    required this.petModel,
    required this.isNight,
    required this.wardrobeTab,
    required this.onTabChanged,
    required this.onSkinSelected,
    required this.onDecorationSelected,
    required this.onHabitatSelected,
    required this.onGachaTap,
    required this.onClose,
    this.onShowDialogue,
  });

  static const headDecos = [
    {'id': 'none', 'name': '无帽子', 'icon': '🚫'},
    {'id': 'band_sport', 'name': '运动发带', 'icon': '🏃'},
    {'id': 'gold_crown_sparkle', 'name': '星辉皇冠', 'icon': '✨', 'minStage': '4'},
    {'id': 'crown', 'name': '璀璨金冠', 'icon': '👑'},
    {'id': 'wizard_hat', 'name': '魔法巫师帽', 'icon': '🧙‍♂️'},
    {'id': 'straw_hat', 'name': '田园草帽', 'icon': '👒'},
    {'id': 'sailor_cap', 'name': '蔚蓝水手帽', 'icon': '⚓'},
  ];

  static const faceDecos = [
    {'id': 'none', 'name': '无面饰', 'icon': '🚫'},
    {'id': 'glasses_black', 'name': '黑框平光镜', 'icon': '🤓'},
    {'id': 'sunglasses_cool', 'name': '飞行员墨镜', 'icon': '😎'},
    {'id': 'hacker_viser', 'name': '战术全息目镜', 'icon': '🕶️'},
  ];

  static const neckDecos = [
    {'id': 'none', 'name': '无配饰', 'icon': '🚫'},
    {'id': 'royal_cape', 'name': '皇家披风', 'icon': '🦸‍♂️', 'minStage': '3'},
    {'id': 'bell', 'name': '经典金铃铛', 'icon': '🔔'},
    {'id': 'ribbon', 'name': '俏皮蝴蝶结', 'icon': '🎀'},
    {'id': 'bowtie', 'name': '绅士领结', 'icon': '🤵'},
    {'id': 'scarf', 'name': '暖冬红围巾', 'icon': '🧣'},
  ];

  static const backDecos = [
    {'id': 'none', 'name': '无背饰', 'icon': '🚫'},
    {'id': 'cape_cyber', 'name': '赛博霓虹披风', 'icon': '🦸‍♂️'},
    {'id': 'wings_angel', 'name': '圣洁天使羽翼', 'icon': '🪽'},
    {'id': 'shell_turtle', 'name': '萌趣龟壳', 'icon': '🐢'},
  ];

  static const handDecos = [
    {'id': 'none', 'name': '空着小爪', 'icon': '🚫'},
    {'id': 'keyboard_rgb', 'name': 'RGB机械键盘', 'icon': '⌨️'},
    {'id': 'teaser_laser', 'name': '全息逗猫棒', 'icon': '🪄'},
    {'id': 'coffee_cyber', 'name': '极客冷萃杯', 'icon': '☕'},
    {'id': 'gamepad_retro', 'name': '8-bit复古掌机', 'icon': '🕹️'},
    {'id': 'dumbbell_power', 'name': '赛博能量哑铃', 'icon': '🏋️'},
  ];

  static const habitatDecos = [
    {'id': 'default', 'name': '极简空间', 'icon': '⚪'},
    {'id': 'neon_matrix', 'name': '霓虹极客房', 'icon': '💻'},
    {'id': 'retro_arcade', 'name': '像素电玩厅', 'icon': '🕹️'},
    {'id': 'summer_beach', 'name': '夏日海滩', 'icon': '🏖️'},
    {'id': 'zen_tatami', 'name': '禅意蒲团室', 'icon': '🍵'},
  ];

  static String getBreedSummary(String skinId) {
    switch (skinId) {
      case 'cat_ragdoll':
        return '八字开脸 · 蓬松羽尾 · 仙气胸毛';
      case 'cat_siamese':
        return '高耸尖耳 · 楔形V脸 · 细鞭尾';
      case 'cat_british_blue':
        return '包子脸发腮 · 矮胖躯干 · 水獭尾';
      case 'cat_orange':
        return '大橘肚腩 · 虎斑环纹尾 · 肥肉爪';
      case 'cat_persian_white':
        return '鸳鸯异瞳 · 飘逸鬃毛 · 纯白羽尾';
      case 'cat_calico':
        return '阴阳双色耳 · 锦鲤花斑 · 招财吉猫';
      case 'cat_american_tabby':
        return '虎斑M纹 · 大理石回旋 · 斑纹尾';
      case 'cat_black':
        return '曜石流线 · 踏雪寻梅白爪 · 金瞳';
      default:
        return '纯洁灵动小萌宠';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = isNight
        ? const Color(0xFF14122C).withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.98);
    final borderColor = isNight
        ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
        : const Color(0xFFE9D5FF);
    final cardBg = isNight ? const Color(0xFF231B45) : const Color(0xFFF8FAFC);
    final titleColor = isNight ? Colors.white : const Color(0xFF1E293B);
    final subColor = isNight ? const Color(0xFFA5B4FC) : const Color(0xFF64748B);

    final currentSkin = petModel.currentSkin;
    final skins = PetModel.availableSkins.values
        .where((s) => s.id != 'cat_white')
        .toList();

    String currentSummary = '';
    if (wardrobeTab == 0) {
      final tags = getBreedSummary(currentSkin.id);
      currentSummary = '🐱 当前品种：${currentSkin.name} ($tags)';
    } else if (wardrobeTab == 1) {
      final currentHead = petModel.decorations['head'] ?? 'none';
      final item = headDecos.firstWhere((h) => h['id'] == currentHead, orElse: () => headDecos.first);
      currentSummary = '🎩 头部装扮：${item['name']}';
    } else if (wardrobeTab == 2) {
      final currentFace = petModel.decorations['face'] ?? 'none';
      final item = faceDecos.firstWhere((f) => f['id'] == currentFace, orElse: () => faceDecos.first);
      currentSummary = '👓 面部目镜：${item['name']}';
    } else if (wardrobeTab == 3) {
      final currentNeck = petModel.decorations['neck'] ?? 'none';
      final item = neckDecos.firstWhere((n) => n['id'] == currentNeck, orElse: () => neckDecos.first);
      currentSummary = '🎀 颈部挂件：${item['name']}';
    } else if (wardrobeTab == 4) {
      final currentBack = petModel.decorations['back'] ?? 'none';
      final item = backDecos.firstWhere((b) => b['id'] == currentBack, orElse: () => backDecos.first);
      currentSummary = '🦸‍♂️ 背部装扮：${item['name']}';
    } else if (wardrobeTab == 5) {
      final currentHand = petModel.decorations['hand'] ?? 'none';
      final item = handDecos.firstWhere((h) => h['id'] == currentHand, orElse: () => handDecos.first);
      currentSummary = '🪄 前爪手持：${item['name']}';
    } else {
      final currentHab = petModel.habitat;
      final item = habitatDecos.firstWhere((h) => h['id'] == currentHab, orElse: () => habitatDecos.first);
      currentSummary = '🏠 赛博小窝：${item['name']}';
    }

    return Positioned(
      key: const ValueKey('live_wardrobe_dock'),
      bottom: 12,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isNight
                  ? const Color(0xFF0F0C24).withValues(alpha: 0.65)
                  : const Color(0xFF6366F1).withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 【第一层级】顶层模式切换与快捷操作条
            Row(
              children: [
                // 1. 核心分段控制器 (👗 猫咪装扮 ⇄ 🏠 小窝场景)
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: isNight ? const Color(0xFF1E1A40) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isNight ? const Color(0xFF4338CA).withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 👗 猫咪装扮模式
                      GestureDetector(
                        onTap: () {
                          if (wardrobeTab == 6) {
                            if (petModel.enableHaptics) HapticFeedback.selectionClick();
                            onTabChanged(0);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: wardrobeTab != 6
                                ? const LinearGradient(
                                    colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
                                  )
                                : null,
                            color: wardrobeTab != 6 ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: wardrobeTab != 6
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFA855F7).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('👗', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                '猫咪装扮',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: wardrobeTab != 6 ? FontWeight.bold : FontWeight.w500,
                                  color: wardrobeTab != 6
                                      ? Colors.white
                                      : (isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // 🏠 小窝场景模式
                      GestureDetector(
                        onTap: () {
                          if (wardrobeTab != 6) {
                            if (petModel.enableHaptics) HapticFeedback.selectionClick();
                            onTabChanged(6);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: wardrobeTab == 6
                                ? const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                                  )
                                : null,
                            color: wardrobeTab == 6 ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: wardrobeTab == 6
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🏠', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                '小窝全景',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: wardrobeTab == 6 ? FontWeight.bold : FontWeight.w500,
                                  color: wardrobeTab == 6
                                      ? Colors.white
                                      : (isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // 2. 🔮 赛博盲盒快捷入口
                BouncyTouchFeedback(
                  scaleDown: 0.94,
                  onTap: onGachaTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🔮', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 3),
                        Text(
                          '盲盒',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 3. 完成退出换装按钮
                BouncyTouchFeedback(
                  scaleDown: 0.94,
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 2),
                        Text(
                          '完成',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 【第二层级】零滑动直选栏
            if (wardrobeTab != 6) ...[
              Row(
                children: [
                  _buildZeroScrollTabPill(0, '🐱 品种', isNight),
                  const SizedBox(width: 4),
                  _buildZeroScrollTabPill(1, '🎩 头部', isNight),
                  const SizedBox(width: 4),
                  _buildZeroScrollTabPill(2, '👓 面部', isNight),
                  const SizedBox(width: 4),
                  _buildZeroScrollTabPill(3, '🎀 颈部', isNight),
                  const SizedBox(width: 4),
                  _buildZeroScrollTabPill(4, '🦸‍♂️ 背部', isNight),
                  const SizedBox(width: 4),
                  _buildZeroScrollTabPill(5, '🪄 手持', isNight),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFF1E1A40) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isNight ? const Color(0xFF10B981).withValues(alpha: 0.3) : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🏡', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '4大家园主题 DIY · 实时变换全屏房间、地平线与环境光影',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isNight ? const Color(0xFFA7F3D0) : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 7),

            // 状态指示摘要条
            Text(
              currentSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: subColor,
              ),
            ),
            const SizedBox(height: 8),

            // 水平滑动卡片展示列表
            SizedBox(
              height: 72,
              child: wardrobeTab == 0
                  ? ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: skins.length,
                      itemBuilder: (context, index) {
                        final skin = skins[index];
                        final isSelected = (petModel.skinId == skin.id);

                        return GestureDetector(
                          onTap: () {
                            if (petModel.enableHaptics) HapticFeedback.mediumImpact();
                            onSkinSelected(skin.id);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 72,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isNight ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF))
                                  : cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFA855F7)
                                    : (isNight ? const Color(0xFF4338CA).withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 2.2 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFA855F7).withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: Color(skin.primaryColor),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Color(skin.secondaryColor), width: 2.5),
                                      ),
                                      child: Center(
                                        child: Text(skin.icon, style: const TextStyle(fontSize: 14)),
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withValues(alpha: 0.35),
                                        ),
                                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  skin.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? (isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE))
                                        : titleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : (wardrobeTab == 6
                      ? ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: habitatDecos.length,
                          itemBuilder: (context, index) {
                            final item = habitatDecos[index];
                            final id = item['id']!;
                            final isSelected = (petModel.habitat == id);

                            return GestureDetector(
                              onTap: () {
                                if (petModel.enableHaptics) HapticService.light();
                                onHabitatSelected(id, item['icon']!);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 72,
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isNight ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF))
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFA855F7)
                                        : (isNight ? const Color(0xFF4338CA).withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 2.2 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(item['icon']!, style: const TextStyle(fontSize: 20)),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['name']!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected
                                            ? (isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE))
                                            : titleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        )
                      : Builder(
                          builder: (context) {
                            final slotMap = {
                              1: ('head', headDecos),
                              2: ('face', faceDecos),
                              3: ('neck', neckDecos),
                              4: ('back', backDecos),
                              5: ('hand', handDecos),
                            };
                            final tuple = slotMap[wardrobeTab] ?? ('head', headDecos);
                            final slot = tuple.$1;
                            final list = tuple.$2;
                            final current = petModel.decorations[slot] ?? 'none';

                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final item = list[index];
                                final id = item['id']!;
                                final isSelected = (current == id);
                                final minStageStr = item['minStage'];
                                final minStage = minStageStr != null ? int.parse(minStageStr) : 0;
                                final currentStage = (petModel.intimacyBondInfo['stage'] as int?) ?? 1;
                                final isLocked = minStage > currentStage;

                                return GestureDetector(
                                  onTap: () {
                                    if (isLocked) {
                                      if (petModel.enableHaptics) HapticService.heavy();
                                      onShowDialogue?.call('🔒 专属装扮：亲密度羁绊需达到第 $minStage 阶解锁！多与波可互动吧~ 💖');
                                      return;
                                    }
                                    if (petModel.enableHaptics) HapticService.light();
                                    onDecorationSelected(slot, id);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 72,
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isNight ? const Color(0xFF4C1D95) : const Color(0xFFF3E8FF))
                                          : cardBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFFA855F7)
                                            : (isNight ? const Color(0xFF4338CA).withValues(alpha: 0.4) : const Color(0xFFE2E8F0)),
                                        width: isSelected ? 2.2 : 1.0,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (isLocked)
                                          Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Opacity(
                                                opacity: 0.35,
                                                child: Text(item['icon']!, style: const TextStyle(fontSize: 18)),
                                              ),
                                              const Icon(Icons.lock_rounded, size: 14, color: Color(0xFFF59E0B)),
                                            ],
                                          )
                                        else
                                          Text(item['icon']!, style: const TextStyle(fontSize: 20)),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['name']!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isLocked
                                                ? const Color(0xFF94A3B8)
                                                : (isSelected
                                                    ? (isNight ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE))
                                                    : titleColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZeroScrollTabPill(int index, String label, bool isNight) {
    final isSelected = (wardrobeTab == index);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (petModel.enableHaptics) {
            HapticFeedback.selectionClick();
          }
          onTabChanged(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
                  )
                : null,
            color: isSelected
                ? null
                : (isNight ? const Color(0xFF262054) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFA855F7)
                  : (isNight ? const Color(0xFF4338CA).withValues(alpha: 0.3) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFA855F7).withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isNight ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
