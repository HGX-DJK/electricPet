import 'package:flutter/material.dart';
import '../../widgets/bouncy_touch_feedback.dart';
import '../../models/pet_model.dart';
import '../../services/haptic_service.dart';
import '../../services/sound_service.dart';
import '../../theme/poko_theme.dart';
import '../../widgets/poko_tap_target.dart';

/// 扭蛋机专属「落日珊瑚」品牌色。
/// 设计令牌 (PokoPalette) 暂未收录该色相, 故在此集中定义一处, 便于后续并入令牌体系。
const Color _sunsetCoral = Color(0xFFFF7A55);

class GachaItem {
  final String rarity;
  final String slot;
  final String id;
  final String name;
  final String icon;
  final String desc;
  final bool isNew;
  final int refundCoins;

  const GachaItem({
    required this.rarity,
    required this.slot,
    required this.id,
    required this.name,
    required this.icon,
    this.desc = '',
    this.isNew = false,
    this.refundCoins = 0,
  });

  String get slotName {
    switch (slot) {
      case 'head': return '头部装扮';
      case 'face': return '面部装扮';
      case 'neck': return '颈部装扮';
      case 'back': return '背部装扮';
      case 'hand': return '手持道具';
      case 'habitat': return '小窝场景';
      default: return '专属饰品';
    }
  }

  factory GachaItem.fromMap(Map<String, dynamic> map) {
    return GachaItem(
      rarity: map['rarity'] as String? ?? 'R',
      slot: map['slot'] as String? ?? 'head',
      id: map['code'] as String? ?? '',
      name: map['name'] as String? ?? '未知道具',
      icon: map['icon'] as String? ?? '🎁',
      desc: map['desc'] as String? ?? '专属配件与萌宠增益',
      isNew: map['isNew'] as bool? ?? false,
      refundCoins: (map['refundCoins'] as num?)?.toInt() ?? 0,
    );
  }
}

/// ✨ 奇迹星愿扭蛋机面板 (Dream Capsule Pod)
/// 30 币单抽与 270 币十连抽 (100% 保底 SSR/UR 绝品发光配件)
/// 采用温暖治愈日落奶油美学，支持开箱品质辉光卡片与一键穿戴/布置小窝
class GachaDialog extends StatefulWidget {
  final PetModel model;
  final VoidCallback onUpdated;
  final bool isNight;

  const GachaDialog({
    super.key,
    required this.model,
    required this.onUpdated,
    this.isNight = false,
  });

  @override
  State<GachaDialog> createState() => _GachaDialogState();
}

class _GachaDialogState extends State<GachaDialog> with SingleTickerProviderStateMixin {
  List<GachaItem>? _recentResults;
  bool _isPulling = false;
  late AnimationController _animCtrl;
  String? _lastEquippedMessage;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: PokoDuration.grand,
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleDraw(int count) {
    // 重入守卫：按钮虽然会在 _isPulling 期间置灰，但 setState -> 重建之间
    // 仍有一个帧的窗口期，快速连点可能连发两次抽取。
    // 这里在函数入口再挡一次，保证一次抽取只对应一次扣币。
    if (_isPulling) return;

    final cost = count == 1 ? 30 : 270;
    if (widget.model.coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ 能量币不足 (需 $cost 币)，多陪波可玩耍或投喂可获得能量币！'),
          backgroundColor: PokoPalette.rose_500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PokoRadius.sm),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      HapticService.light();
      return;
    }

    setState(() {
      _isPulling = true;
      _lastEquippedMessage = null;
    });
    SoundService.playPop();
    HapticService.medium();
    _animCtrl.forward(from: 0.0);

    Future.delayed(const Duration(milliseconds: 450), () async {
      // ⚠️ 必须先判「面板还在不在」，再抽卡：
      // 抽卡动画期间（这 450ms）用户可以点右上角 ✕ 或遮罩把面板关掉。
      // 以前这里是无条件抽取的 —— 面板没了、结果卡没了，**币却扣了**，
      // 用户只能事后去衣橱里看到新装扮，完全不知道发生了什么。
      // 现在面板已经关闭就整笔放弃：不扣币、不产出，权当没点过。
      //
      // ⚠️ 光看 mounted 不够：关闭动画播完之前 State 仍然是 mounted 的，
      // 但用户已经明确关掉了面板。所以还要看路由是不是还是当前路由。
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;

      final rawResults = widget.model.drawGacha(count);
      final results = rawResults.map((m) => GachaItem.fromMap(m)).toList();
      final hasHighRarity = results.any((item) => item.rarity == 'UR' || item.rarity == 'SSR');

      if (hasHighRarity) {
        HapticService.jackpotHaptic();
        SoundService.playMeow(tone: MeowTone.sweet);
      } else {
        HapticService.heavy();
        SoundService.playMeow(tone: MeowTone.short);
      }

      if (mounted) {
        int totalRefund = 0;
        for (final item in results) {
          totalRefund += item.refundCoins;
        }
        if (totalRefund > 0) {
          // 退款由模型统一兑现（加币 + 立刻落盘），不能只改内存 ——
          // 否则 App 被杀就是「扣了币、退款没了」。
          await widget.model.creditRefund(totalRefund);
        }
        if (!mounted) return;
        setState(() {
          _isPulling = false;
          _recentResults = results;
        });
        widget.onUpdated();
      }
    });
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'UR':
        return PokoPalette.rose_500; // 绝品梦幻粉金
      case 'SSR':
        return PokoPalette.amber_500; // 璀璨曜金
      case 'SR':
        return PokoPalette.violet_500; // 幻梦星紫
      case 'R':
      default:
        return PokoPalette.sky_400; // 清晨天青
    }
  }

  String _getRarityLabel(String rarity) {
    switch (rarity) {
      case 'UR':
        return 'UR 绝品';
      case 'SSR':
        return 'SSR 典藏';
      case 'SR':
        return 'SR 灵动';
      case 'R':
      default:
        return 'R 萌趣';
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final isNight = widget.isNight;
    final t = context.poko(isNight);

    return PokoSheetShell(
      isNight: isNight,
      maxHeightFactor: 0.78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PokoSpacing.xl,
          0,
          PokoSpacing.xl,
          PokoSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏：心愿扭蛋机、代币余额、关闭按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              PokoPalette.amber_50,
                              PokoPalette.amber_500.withValues(alpha: 0.35),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(PokoRadius.sm),
                        ),
                        alignment: Alignment.center,
                        child: const Text('✨', style: TextStyle(fontSize: PokoFont.subtitle)),
                      ),
                      const SizedBox(width: PokoSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '奇迹星愿扭蛋机',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: PokoFont.title,
                                fontWeight: FontWeight.bold,
                                color: t.textPrimary,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'DREAM CAPSULE POD',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: PokoFont.micro,
                                fontWeight: FontWeight.w700,
                                color: _sunsetCoral,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: PokoSpacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 能量币余额胶囊
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PokoSpacing.sm,
                        vertical: PokoSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: t.surfaceAlt,
                        borderRadius: BorderRadius.circular(PokoRadius.md),
                        border: Border.all(
                          color: PokoPalette.amber_500.withValues(alpha: 0.5),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: PokoFont.small)),
                          const SizedBox(width: PokoSpacing.xs),
                          Text(
                            '${model.coins}',
                            style: TextStyle(
                              fontSize: PokoFont.small,
                              fontWeight: FontWeight.bold,
                              color: isNight
                                  ? PokoPalette.amber_500
                                  : PokoPalette.amber_700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: PokoSpacing.xs),
                    PokoTapTarget(
                      semanticLabel: '关闭扭蛋机',
                      onTap: () {
                        SoundService.playClick();
                        Navigator.of(context).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(PokoSpacing.xs),
                        decoration: BoxDecoration(
                          color: t.surfaceAlt,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: t.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (_lastEquippedMessage != null) ...[
              const SizedBox(height: PokoSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PokoSpacing.md,
                  vertical: PokoSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: PokoPalette.emerald_500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(PokoRadius.xs),
                  border: Border.all(
                    color: PokoPalette.emerald_500.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🐾', style: TextStyle(fontSize: PokoFont.body)),
                    const SizedBox(width: PokoSpacing.xs),
                    Expanded(
                      child: Text(
                        _lastEquippedMessage!,
                        style: const TextStyle(
                          fontSize: PokoFont.caption,
                          fontWeight: FontWeight.w600,
                          color: PokoPalette.emerald_700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: PokoSpacing.md),

            // 核心内容展示区 (机舱外观 / 抽取结果卡片流)
            Expanded(
              child: _recentResults != null
                  ? _buildResultsView(isNight)
                  : _buildPodShowcase(isNight),
            ),

            const SizedBox(height: PokoSpacing.md),

            // 底部抽卡祈愿按钮区
            _buildActionButtons(isNight),
          ],
        ),
      ),
    );
  }

  /// 扭蛋图鉴：把「在收集什么」和「还差几件」摆到台面上。
  ///
  /// ⚠️ 背景：此前扭卡面板只有钱袋数字和一行宣传文案，
  /// 玩家看不到自己在收集什么 —— 抽到什么是随机的、还差几件是未知的。
  /// 而 unlockedItems 一直存在，只是从没被展示过。
  Widget _buildCodex(bool isNight) {
    final owned = widget.model.unlockedItems.toSet();
    const pool = PetModel.gachaPool;
    final got = pool.where((e) => owned.contains(e['code'])).length;

    Color rarityColor(String rarity) {
      switch (rarity) {
        case 'UR':
          return PokoPalette.violet_400;
        case 'SSR':
          return PokoPalette.amber_400;
        case 'SR':
          return PokoPalette.sky_400;
        default:
          return PokoPalette.slate_400;
      }
    }

    return Container(
      padding: const EdgeInsets.all(PokoSpacing.sm),
      decoration: BoxDecoration(
        color: isNight
            ? PokoPalette.slate_800.withValues(alpha: 0.55)
            : PokoPalette.slate_100,
        borderRadius: BorderRadius.circular(PokoRadius.md),
        border: Border.all(
          color: PokoPalette.slate_300.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎖', style: TextStyle(fontSize: PokoFont.body)),
              const SizedBox(width: PokoSpacing.xs),
              Text(
                '扭蛋图鉴 · 已收集 $got/${pool.length}',
                style: TextStyle(
                  fontSize: PokoFont.caption,
                  fontWeight: FontWeight.bold,
                  color: isNight
                      ? PokoPalette.amber_400
                      : PokoPalette.amber_700,
                ),
              ),
              const Spacer(),
              Text(
                '带框=已收集 · 虚线=还没出',
                style: TextStyle(
                  fontSize: PokoFont.micro,
                  color: isNight
                      ? PokoPalette.slate_400
                      : PokoPalette.slate_500,
                ),
              ),
            ],
          ),
          const SizedBox(height: PokoSpacing.xs),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (final e in pool)
                Tooltip(
                  message: '${e['name']}\n${e['rarity']}\n'
                      '${owned.contains(e['code']) ? '已收集 ✓' : '尚未获得'}',
                  child: Container(
                    width: 26,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: owned.contains(e['code'])
                          ? (isNight ? PokoPalette.slate_700 : Colors.white)
                          : (isNight ? PokoPalette.slate_900 : PokoPalette.slate_200),
                      borderRadius: BorderRadius.circular(PokoRadius.xs),
                      border: Border.all(
                        color: owned.contains(e['code'])
                            ? rarityColor(e['rarity'] as String)
                            : PokoPalette.slate_400.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Opacity(
                      opacity: owned.contains(e['code']) ? 1.0 : 0.45,
                      child: Text(
                        e['icon'] as String,
                        style: const TextStyle(fontSize: PokoFont.body),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 萌趣梦幻扭蛋机展示视图
  Widget _buildPodShowcase(bool isNight) {
    final t = context.poko(isNight);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 梦幻水晶球扭蛋仓
        RotationTransition(
          turns: Tween(begin: 0.0, end: _isPulling ? 1.0 : 0.0).animate(
            CurvedAnimation(parent: _animCtrl, curve: PokoCurves.balanced),
          ),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  PokoPalette.amber_50,
                  PokoPalette.amber_500.withValues(alpha: 0.35),
                  PokoPalette.amber_500.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
            child: Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      PokoPalette.amber_50,
                      _sunsetCoral,
                      PokoPalette.amber_500,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _sunsetCoral.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text('🔮', style: TextStyle(fontSize: 48)),
                    Positioned(
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: PokoSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(PokoRadius.xs),
                        ),
                        child: const Text(
                          'POKO POD',
                          style: TextStyle(
                            fontSize: PokoFont.micro,
                            fontWeight: FontWeight.w900,
                            color: PokoPalette.amber_700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: PokoSpacing.lg),

        // 保底特权横幅 (十连必出 SSR / UR)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PokoSpacing.lg,
            vertical: PokoSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                PokoPalette.amber_50,
                PokoPalette.amber_500.withValues(alpha: 0.22),
              ],
            ),
            borderRadius: BorderRadius.circular(PokoRadius.md),
            border: Border.all(
              color: PokoPalette.amber_500.withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: PokoShadow.soft(PokoPalette.amber_500),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✨', style: TextStyle(fontSize: PokoFont.bodyMd)),
              SizedBox(width: PokoSpacing.xs),
              Flexible(
                child: Text(
                  '十连抽享 9 折且 100% 保底 SSR / UR 绝品神装！',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: PokoFont.caption,
                    fontWeight: FontWeight.bold,
                    color: PokoPalette.amber_700,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: PokoSpacing.md),

        // 图鉴：把「在收集什么」摆到台面上
        _buildCodex(isNight),

        const SizedBox(height: PokoSpacing.md),

        // 奖池爆款配件预览
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PokoSpacing.xl),
          child: Text(
            '🌟 绝品装扮涵盖：战术目镜、RGB机械键盘、全息光纤逗猫棒、夏日阳光海滩、暗夜霓虹极客房、圣洁天使羽翼',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: PokoFont.caption,
              height: 1.4,
              color: t.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// 抽取结果卡片流
  Widget _buildResultsView(bool isNight) {
    final t = context.poko(isNight);
    final results = _recentResults!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: PokoFont.titleSm)),
                const SizedBox(width: PokoSpacing.xs),
                Text(
                  '愿望启封达成 (${results.length} 件心愿之礼)',
                  style: TextStyle(
                    fontSize: PokoFont.body,
                    fontWeight: FontWeight.bold,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
            BouncyTouchFeedback(
              scaleDown: 0.94,
        onTap: () {
                SoundService.playClick();
                setState(() => _recentResults = null);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PokoSpacing.sm,
                  vertical: PokoSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  borderRadius: BorderRadius.circular(PokoRadius.sm),
                  border: Border.all(
                    color: _sunsetCoral.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 13,
                      color: _sunsetCoral,
                    ),
                    SizedBox(width: PokoSpacing.xxs),
                    Text(
                      '返回机舱',
                      style: TextStyle(
                        fontSize: PokoFont.caption,
                        fontWeight: FontWeight.bold,
                        color: _sunsetCoral,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PokoSpacing.sm),
        Expanded(
          child: GridView.builder(
            itemCount: results.length,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.28,
              crossAxisSpacing: PokoSpacing.sm,
              mainAxisSpacing: PokoSpacing.sm,
            ),
            itemBuilder: (context, index) {
              final item = results[index];
              final rarityColor = _getRarityColor(item.rarity);
              final isHabitat = item.slot == 'habitat';
              final isEquipped = isHabitat
                  ? widget.model.habitat == item.id
                  : widget.model.decorations[item.slot] == item.id;
              final isHighRarity = item.rarity == 'UR' || item.rarity == 'SSR';

              return TweenAnimationBuilder<double>(
                key: ValueKey('${item.id}_${index}_reveal'),
                duration: Duration(milliseconds: 180 + (index * 35).clamp(0, 350)),
                curve: PokoCurves.playful,
                tween: Tween<double>(begin: 0.0, end: 1.0),
                builder: (context, animVal, child) {
                  return Transform.scale(
                    scale: 0.85 + 0.15 * animVal,
                    child: Opacity(
                      opacity: animVal.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(PokoRadius.md),
                    border: Border.all(
                      color: rarityColor.withValues(alpha: isHighRarity ? 0.85 : 0.65),
                      width: isHighRarity ? 1.5 : 1,
                    ),
                    boxShadow: [
                      ...PokoShadow.card(rarityColor),
                      if (isHighRarity)
                        BoxShadow(
                          color: PokoPalette.amber_500.withValues(alpha: 0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                    ],
                  ),
                  padding: const EdgeInsets.all(PokoSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 图标与品质/回收徽章
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: rarityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(PokoRadius.xs),
                            ),
                            alignment: Alignment.center,
                            child: Text(item.icon, style: const TextStyle(fontSize: PokoFont.headline)),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.refundCoins > 0)
                                Container(
                                  margin: const EdgeInsets.only(
                                    right: PokoSpacing.xs,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: PokoSpacing.xs,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PokoPalette.emerald_500.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(
                                      PokoRadius.xs,
                                    ),
                                    border: Border.all(
                                      color: PokoPalette.emerald_500.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Text(
                                    '♻️+15🪙',
                                    style: TextStyle(
                                      fontSize: PokoFont.micro,
                                      fontWeight: FontWeight.bold,
                                      color: PokoPalette.emerald_700,
                                    ),
                                  ),
                                )
                              else if (item.isNew)
                                Container(
                                  margin: const EdgeInsets.only(
                                    right: PokoSpacing.xs,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: PokoSpacing.xs,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        PokoPalette.rose_500,
                                        PokoPalette.amber_500,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      PokoRadius.xs,
                                    ),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      fontSize: PokoFont.micro,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: PokoSpacing.xs,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: rarityColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(PokoRadius.xs),
                                  border: Border.all(
                                    color: rarityColor.withValues(alpha: 0.8),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _getRarityLabel(item.rarity),
                                  style: TextStyle(
                                    fontSize: PokoFont.tiny,
                                    fontWeight: FontWeight.w800,
                                    color: rarityColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // 名称与技能增益描述
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: PokoFont.small,
                              fontWeight: FontWeight.bold,
                              color: t.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: PokoSpacing.xxs),
                          Text(
                            item.desc.isNotEmpty ? item.desc : item.slotName,
                            style: TextStyle(
                              fontSize: PokoFont.tiny,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                              color: t.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),

                      // 一键穿戴 / 布置小窝按钮
                      SizedBox(
                        width: double.infinity,
                        height: 26,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEquipped ? t.surfaceAlt : rarityColor,
                            padding: EdgeInsets.zero,
                            elevation: isEquipped ? 0 : 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(PokoRadius.xs),
                            ),
                          ),
                          onPressed: isEquipped
                              ? null
                              : () {
                                  if (isHabitat) {
                                    widget.model.setHabitat(item.id);
                                  } else {
                                    widget.model.setDecoration(item.slot, item.id);
                                  }
                                  HapticService.medium();
                                  SoundService.playPop();
                                  setState(() {
                                    _lastEquippedMessage = isHabitat
                                        ? '小窝场景已切换为【${item.name}】！'
                                        : '已为波可穿戴【${item.name}】！';
                                  });
                                  widget.onUpdated();
                                },
                          child: Text(
                            isEquipped
                                ? (isHabitat ? '已布置' : '已穿戴')
                                : (isHabitat ? '布置小窝 🏠' : '一键穿戴 ✨'),
                            style: TextStyle(
                              fontSize: PokoFont.caption,
                              fontWeight: FontWeight.bold,
                              color: isEquipped ? t.textMuted : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 底部抽卡按钮区
  Widget _buildActionButtons(bool isNight) {
    final t = context.poko(isNight);
    return Row(
      children: [
        // 单抽
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: t.surface,
              foregroundColor: _sunsetCoral,
              padding: const EdgeInsets.symmetric(vertical: PokoSpacing.sm),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PokoRadius.md),
                side: const BorderSide(color: _sunsetCoral, width: 1.5),
              ),
            ),
            onPressed: _isPulling ? null : () => _handleDraw(1),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🌟 开启心愿',
                  style: TextStyle(
                    fontSize: PokoFont.body,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: PokoSpacing.xxs),
                Text(
                  '30 能量币',
                  style: TextStyle(
                    fontSize: PokoFont.caption,
                    color: PokoPalette.amber_700,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: PokoSpacing.md),

        // 十连抽 (保底)
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_sunsetCoral, PokoPalette.amber_500],
              ),
              borderRadius: BorderRadius.circular(PokoRadius.md),
              boxShadow: [
                BoxShadow(
                  color: _sunsetCoral.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: PokoSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PokoRadius.md),
                ),
              ),
              onPressed: _isPulling ? null : () => _handleDraw(10),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '🚀 幸运十连',
                        style: TextStyle(
                          fontSize: PokoFont.bodyLg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: PokoSpacing.xs),
                      Text(
                        '保底SSR/UR',
                        style: TextStyle(
                          fontSize: PokoFont.tiny,
                          color: PokoPalette.amber_50,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: PokoSpacing.xxs),
                  Text(
                    '270 能量币 (限时9折)',
                    style: TextStyle(
                      fontSize: PokoFont.caption,
                      color: PokoPalette.amber_50,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
