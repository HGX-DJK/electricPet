import 'package:flutter/material.dart';
import '../../theme/poko_theme.dart';
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
      case 'cat_golden_shaded':
        return '富贵金渐层 · 绿宝石大眼 · 包子发腮';
      case 'cat_silver_shaded':
        return '仙气银霜 · 薄荷绿大眼 · 软萌白胖';
      case 'cat_ragdoll':
        return '蓝双开脸 · 宝石海蓝眸 · 仙气领圈';
      case 'cat_tuxedo':
        return '黑白燕尾服 · 四蹄踏雪 · 琥珀明眸';
      case 'cat_maine_coon':
        return '猞猁耳尖羽 · 霸气狮鬃领 · 狐尾丛林';
      case 'cat_sakura_peach':
        return '蜜桃粉晶 · 樱花肉垫 · 梦幻仙境';
      case 'cat_british_blue':
        return '包子脸发腮 · 矮胖躯干 · 水獭尾';
      case 'cat_orange':
        return '大橘肚腩 · 虎斑环纹尾 · 肥肉爪';
      case 'cat_persian_white':
        return '金银双眸异瞳 · 飘逸鬃毛 · 纯白羽尾';
      case 'cat_calico':
        return '日系甜心 · 柔杏软灰斑 · 招财吉猫';
      case 'cat_american_tabby':
        return '虎斑M纹 · 大理石回旋 · 斑纹尾';
      case 'cat_siamese':
        return '焦糖拿铁脸 · 电光天青眸 · 灵动敏捷';
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
        ? PokoPalette.violet_600.withValues(alpha: 0.5)
        : PokoPalette.violet_200;
    final cardBg = isNight ? const Color(0xFF231B45) : PokoPalette.slate_50;
    final titleColor = isNight ? Colors.white : PokoPalette.slate_800;

    final skins = PetModel.availableSkins.values
        .where((s) => s.id != 'cat_white')
        .toList();


    return Positioned(
      key: const ValueKey('live_wardrobe_dock'),
      bottom: 12,
      left: 12,
      right: 12,
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
          color: bgColor,
          borderRadius: BorderRadius.circular(PokoRadius.xl),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isNight
                  ? const Color(0xFF0F0C24).withValues(alpha: 0.65)
                  : PokoPalette.indigo_500.withValues(alpha: 0.14),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 【第一层级】顶层模式切换与快捷操作条 (轻量呼吸胶囊)
            Row(
              children: [
                // 1. 核心轻量分段切换 (👗 猫咪装扮 ⇄ 🏠 小窝场景)
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: isNight ? const Color(0xFF1E1A40) : PokoPalette.slate_100,
                    borderRadius: BorderRadius.circular(PokoRadius.md),
                    border: Border.all(
                      color: isNight ? PokoPalette.indigo_700.withValues(alpha: 0.3) : PokoPalette.slate_200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 👗 猫咪装扮模式
                      BouncyTouchFeedback(
                        scaleDown: 0.96,
        onTap: () {
                          if (wardrobeTab == 6) {
                            if (petModel.enableHaptics) HapticFeedback.selectionClick();
                            onTabChanged(0);
                          }
                        },
                        child: AnimatedContainer(
                          duration: PokoDuration.base,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            gradient: wardrobeTab != 6
                                ? const LinearGradient(
                                    colors: [PokoPalette.violet_500, PokoPalette.violet_700],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(PokoRadius.sm),
                            boxShadow: wardrobeTab != 6
                                ? [
                                    BoxShadow(
                                      color: PokoPalette.violet_500.withValues(alpha: 0.28),
                                      blurRadius: 5,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('👗', style: TextStyle(fontSize: PokoFont.caption)),
                              const SizedBox(width: 3.5),
                              Text(
                                '猫咪装扮',
                                style: TextStyle(
                                  fontSize: PokoFont.caption,
                                  fontWeight: wardrobeTab != 6 ? FontWeight.bold : FontWeight.w500,
                                  color: wardrobeTab != 6
                                      ? Colors.white
                                      : (isNight ? PokoPalette.slate_400 : PokoPalette.slate_500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),

                      // 🏠 小窝场景模式
                      BouncyTouchFeedback(
                        scaleDown: 0.96,
        onTap: () {
                          if (wardrobeTab != 6) {
                            if (petModel.enableHaptics) HapticFeedback.selectionClick();
                            onTabChanged(6);
                          }
                        },
                        child: AnimatedContainer(
                          duration: PokoDuration.base,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            gradient: wardrobeTab == 6
                                ? const LinearGradient(
                                    colors: [PokoPalette.emerald_500, PokoPalette.emerald_600],
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(PokoRadius.sm),
                            boxShadow: wardrobeTab == 6
                                ? [
                                    BoxShadow(
                                      color: PokoPalette.emerald_500.withValues(alpha: 0.28),
                                      blurRadius: 5,
                                      offset: const Offset(0, 1.5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🏠', style: TextStyle(fontSize: PokoFont.caption)),
                              const SizedBox(width: 3.5),
                              Text(
                                '小窝全景',
                                style: TextStyle(
                                  fontSize: PokoFont.caption,
                                  fontWeight: wardrobeTab == 6 ? FontWeight.bold : FontWeight.w500,
                                  color: wardrobeTab == 6
                                      ? Colors.white
                                      : (isNight ? PokoPalette.slate_400 : PokoPalette.slate_500),
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

                // 2. 🔮 赛博盲盒快捷微胶囊 (轻盈不抢眼)
                if (wardrobeTab != 6) ...[
                  BouncyTouchFeedback(
                    scaleDown: 0.94,
                    onTap: onGachaTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: isNight ? const Color(0xFF262054) : PokoPalette.violet_100,
                        borderRadius: BorderRadius.circular(PokoRadius.sm),
                        border: Border.all(
                          color: isNight ? PokoPalette.violet_600.withValues(alpha: 0.4) : PokoPalette.violet_300,
                          width: 1.0,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🔮', style: TextStyle(fontSize: PokoFont.caption)),
                          SizedBox(width: 3),
                          Text(
                            '盲盒',
                            style: TextStyle(
                              fontSize: PokoFont.caption,
                              fontWeight: FontWeight.bold,
                              color: PokoPalette.violet_700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // 3. 完成退出按钮 (优雅半透明微胶囊，轻量收敛)
                BouncyTouchFeedback(
                  scaleDown: 0.94,
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF241F48) : PokoPalette.slate_100,
                      borderRadius: BorderRadius.circular(PokoRadius.sm),
                      border: Border.all(
                        color: isNight ? const Color(0xFF3B336A) : PokoPalette.slate_300,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, color: isNight ? PokoPalette.slate_300 : PokoPalette.slate_500, size: 13),
                        const SizedBox(width: 2),
                        Text(
                          '完成',
                          style: TextStyle(
                            fontSize: PokoFont.caption,
                            fontWeight: FontWeight.w600,
                            color: isNight ? PokoPalette.slate_300 : PokoPalette.slate_500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 【第二层级】零滑动直选栏 (极简呼吸标签，无重框堆叠)
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
                  color: isNight ? const Color(0xFF1E1A40) : PokoPalette.emerald_50,
                  borderRadius: BorderRadius.circular(PokoRadius.sm),
                  border: Border.all(
                    color: isNight ? PokoPalette.emerald_500.withValues(alpha: 0.3) : PokoPalette.mint_200,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🏡', style: TextStyle(fontSize: PokoFont.small)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '4大家园主题 DIY · 实时变换全屏房间与环境光影',
                        style: TextStyle(
                          fontSize: PokoFont.tiny,
                          fontWeight: FontWeight.w600,
                          color: isNight ? PokoPalette.emerald_200 : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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

                        return BouncyTouchFeedback(
                          scaleDown: 0.95,
        onTap: () {
                            if (petModel.enableHaptics) HapticFeedback.mediumImpact();
                            onSkinSelected(skin.id);
                          },
                          child: AnimatedContainer(
                            duration: PokoDuration.base,
                            width: 72,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isNight ? PokoPalette.indigo_shadow : PokoPalette.violet_100)
                                  : cardBg,
                              borderRadius: BorderRadius.circular(PokoRadius.md),
                              border: Border.all(
                                color: isSelected
                                    ? PokoPalette.violet_500
                                    : (isNight ? PokoPalette.indigo_700.withValues(alpha: 0.4) : PokoPalette.slate_200),
                                width: isSelected ? 2.2 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: PokoPalette.violet_500.withValues(alpha: 0.35),
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
                                        child: Text(skin.icon, style: const TextStyle(fontSize: PokoFont.bodyMd)),
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
                                    fontSize: PokoFont.tiny,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? (isNight ? PokoPalette.violet_200 : PokoPalette.violet_800)
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

                            return BouncyTouchFeedback(
                              scaleDown: 0.95,
        onTap: () {
                                if (petModel.enableHaptics) HapticService.light();
                                onHabitatSelected(id, item['icon']!);
                              },
                              child: AnimatedContainer(
                                duration: PokoDuration.base,
                                width: 72,
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isNight ? PokoPalette.indigo_shadow : PokoPalette.violet_100)
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(PokoRadius.md),
                                  border: Border.all(
                                    color: isSelected
                                        ? PokoPalette.violet_500
                                        : (isNight ? PokoPalette.indigo_700.withValues(alpha: 0.4) : PokoPalette.slate_200),
                                    width: isSelected ? 2.2 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(item['icon']!, style: const TextStyle(fontSize: PokoFont.headline)),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['name']!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: PokoFont.microSm,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected
                                            ? (isNight ? PokoPalette.violet_200 : PokoPalette.violet_800)
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

                                return BouncyTouchFeedback(
                                  scaleDown: 0.95,
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
                                    duration: PokoDuration.base,
                                    width: 72,
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isNight ? PokoPalette.indigo_shadow : PokoPalette.violet_100)
                                          : cardBg,
                                      borderRadius: BorderRadius.circular(PokoRadius.md),
                                      border: Border.all(
                                        color: isSelected
                                            ? PokoPalette.violet_500
                                            : (isNight ? PokoPalette.indigo_700.withValues(alpha: 0.4) : PokoPalette.slate_200),
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
                                                child: Text(item['icon']!, style: const TextStyle(fontSize: PokoFont.subtitle)),
                                              ),
                                              const Icon(Icons.lock_rounded, size: 14, color: PokoPalette.amber_500),
                                            ],
                                          )
                                        else
                                          Text(item['icon']!, style: const TextStyle(fontSize: PokoFont.headline)),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['name']!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: PokoFont.microSm,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isLocked
                                                ? PokoPalette.slate_400
                                                : (isSelected
                                                    ? (isNight ? PokoPalette.violet_200 : PokoPalette.violet_800)
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
    ),
  );
}

  Widget _buildZeroScrollTabPill(int index, String label, bool isNight) {
    final isSelected = (wardrobeTab == index);
    return Expanded(
      child: BouncyTouchFeedback(
        scaleDown: 0.94,
        onTap: () {
          if (petModel.enableHaptics) {
            HapticFeedback.selectionClick();
          }
          onTabChanged(index);
        },
        child: AnimatedContainer(
          duration: PokoDuration.fast,
          padding: const EdgeInsets.symmetric(vertical: 5.5, horizontal: 1),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [PokoPalette.violet_500, PokoPalette.violet_700],
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(PokoRadius.sm),
            border: Border.all(
              color: isSelected
                  ? PokoPalette.violet_500
                  : Colors.transparent,
              width: 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: PokoPalette.violet_500.withValues(alpha: 0.3),
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
                fontSize: PokoFont.tiny,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isNight ? PokoPalette.slate_400 : PokoPalette.slate_500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
