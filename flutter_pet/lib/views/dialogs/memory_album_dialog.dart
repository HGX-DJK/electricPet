import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pet_model.dart';
import '../../services/sound_service.dart';
import '../../theme/poko_theme.dart';

/// 萌宠时光拍立得相册与成长纪念手账
///
/// ⚠️ 这里展示的**不是写死的假卡片**，而是 `PetModel.memories` 里
/// 真实发生过、并已落盘的纪念：
///   - 系统自动记下的里程碑（初遇 / 第一次投喂 / 第一次洗澡 / 升级 / 羁绊进阶 / 换装 / 陪伴满 N 天）
///   - 用户自己拍下的「今日纪念照」
/// 以前这里只有五张编好的卡片和编好的日期，「拍下一张今日纪念照」按钮
/// 只播了个音效、什么也没存 —— 现在每按一次都会真的多一张，并且重启还在。
class MemoryAlbumDialog extends StatefulWidget {
  final PetModel model;
  final bool isNight;

  const MemoryAlbumDialog({
    super.key,
    required this.model,
    this.isNight = false,
  });

  @override
  State<MemoryAlbumDialog> createState() => _MemoryAlbumDialogState();
}

/// 相册卡片的视觉配色（按纪念性质区分）
class _CardStyle {
  final Color badgeBg;
  final Color badgeColor;
  final Color photoBg;

  const _CardStyle(this.badgeBg, this.badgeColor, this.photoBg);
}

_CardStyle _styleOf(MemoryEntry entry) {
  final id = entry.id;
  if (entry.isSnapshot) {
    return _CardStyle(
      PokoPalette.rose.withValues(alpha: 0.16),
      PokoPalette.roseDeep,
      PokoPalette.rose.withValues(alpha: 0.14),
    );
  }
  if (id == 'meet') {
    return const _CardStyle(
      PokoPalette.skySoft,
      PokoPalette.skyDeep,
      Color(0x220E7490),
    );
  }
  if (id == 'first_feed') {
    return const _CardStyle(
      PokoPalette.amberSoft,
      PokoPalette.amberDeep,
      Color(0x22F59E0B),
    );
  }
  if (id == 'first_wash') {
    return const _CardStyle(
      PokoPalette.violetSoft,
      PokoPalette.violetDeep,
      Color(0x228B5CF6),
    );
  }
  if (id.startsWith('level_')) {
    return const _CardStyle(
      PokoPalette.amberSoft,
      PokoPalette.amber,
      Color(0x22FBBF24),
    );
  }
  if (id.startsWith('bond_')) {
    return const _CardStyle(
      PokoPalette.roseSoft,
      PokoPalette.roseDeep,
      Color(0x22F43F5E),
    );
  }
  if (id.startsWith('skin_')) {
    return const _CardStyle(
      PokoPalette.skySoft,
      PokoPalette.skyDeep,
      Color(0x220EA5E9),
    );
  }
  // 陪伴里程碑
  return const _CardStyle(
    PokoPalette.violetSoft,
    PokoPalette.violetDeep,
    Color(0x22A78BFA),
  );
}

class _MemoryAlbumDialogState extends State<MemoryAlbumDialog> {
  int _selectedCardIndex = 0;
  bool _isFlashing = false;
  String? _lastSnapMessage;

  /// 纪念发生的那天是"陪伴第几天"
  int _dayOf(MemoryEntry entry) {
    final birth = widget.model.birthTime;
    if (birth <= 0) return 1;
    final diff = entry.timestamp - birth;
    if (diff < 0) return 1;
    return (diff ~/ 86400000) + 1;
  }

  /// 点击“即时快门咔嚓”拍照留念 —— 真的会进相册
  void _takeSnapshot() {
    SoundService.playShutter();
    if (widget.model.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _isFlashing = true;
    });

    final entry = widget.model.takeSnapshot();
    setState(() {
      _selectedCardIndex = 0;
      _lastSnapMessage =
          '咔嚓！已把这一刻的波可收入纪念相册（${entry.dateText}）~ 📸💕';
    });

    Timer(const Duration(milliseconds: 220), () {
      if (mounted) {
        setState(() => _isFlashing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poko(widget.isNight);
    return PokoSheetShell(
      isNight: widget.isNight,
      maxHeightFactor: 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PokoSpacing.xl,
          0,
          PokoSpacing.xl,
          PokoSpacing.xxl,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: AnimatedBuilder(
            animation: widget.model,
            builder: (context, _) {
              final memories = widget.model.memories;
              final safeIndex = memories.isEmpty
                  ? 0
                  : (_selectedCardIndex.clamp(0, memories.length - 1));
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题与关闭按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(PokoSpacing.sm),
                            decoration: BoxDecoration(
                              color: PokoPalette.rose.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(PokoRadius.sm),
                            ),
                            child: const Text(
                              '📸',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: PokoSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '波可的时光纪念相册',
                                style: TextStyle(
                                  fontSize: PokoFont.title,
                                  fontWeight: FontWeight.bold,
                                  color: t.textPrimary,
                                ),
                              ),
                              Text(
                                '成长里程碑与随手拍都会真实留在这里 · 已收藏 ${memories.length} 张',
                                style: TextStyle(
                                  fontSize: PokoFont.caption,
                                  color: t.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(PokoSpacing.xs),
                          decoration: BoxDecoration(
                            color: t.surfaceAlt,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, size: 18, color: t.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: PokoSpacing.md),

                  // 陪伴羁绊数据横幅
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PokoSpacing.md,
                      vertical: PokoSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          PokoPalette.amberSoft,
                          PokoPalette.amber.withValues(alpha: 0.22),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(PokoRadius.md),
                      border: Border.all(
                        color: PokoPalette.amber.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                            '已陪伴', '${widget.model.totalDays} 天', '📅'),
                        Container(
                          width: 1,
                          height: 24,
                          color: PokoPalette.amber.withValues(alpha: 0.55),
                        ),
                        _buildStatItem(
                            '当前品种', widget.model.currentSkin.name, '🐾'),
                        Container(
                          width: 1,
                          height: 24,
                          color: PokoPalette.amber.withValues(alpha: 0.55),
                        ),
                        _buildStatItem(
                          '亲密羁绊',
                          'Lv.${widget.model.level} (${widget.model.intimacy}%)',
                          '💖',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: PokoSpacing.md),

                  // 拍立得照片卡片滑动区（真实纪念，最新在前）
                  if (memories.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: PokoSpacing.md,
                        vertical: PokoSpacing.xl,
                      ),
                      decoration: BoxDecoration(
                        color: t.surfaceAlt,
                        borderRadius: BorderRadius.circular(PokoRadius.md),
                        border: Border.all(color: t.border),
                      ),
                      child: Column(
                        children: [
                          const Text('📭', style: TextStyle(fontSize: 34)),
                          const SizedBox(height: PokoSpacing.sm),
                          Text(
                            '还没有回忆呢',
                            style: TextStyle(
                              fontSize: PokoFont.body,
                              fontWeight: FontWeight.bold,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: PokoSpacing.xs),
                          Text(
                            '喂一次小鱼干、搓一次澡、换一次造型，\n都会自动变成一张纪念照。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: PokoFont.caption,
                              color: t.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      height: 220,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: memories.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: PokoSpacing.md),
                        itemBuilder: (context, index) {
                          final card = memories[index];
                          final isSelected = safeIndex == index;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              SoundService.playMeow(tone: MeowTone.short);
                              setState(() => _selectedCardIndex = index);
                            },
                            child: _buildPolaroidCard(card, isSelected),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: PokoSpacing.md),

                  // 当前卡片手账详情寄语
                  if (memories.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: PokoSpacing.md,
                        vertical: PokoSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: t.surfaceAlt,
                        borderRadius: BorderRadius.circular(PokoRadius.md),
                        border: Border.all(color: t.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📝', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: PokoSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  memories[safeIndex].note,
                                  style: TextStyle(
                                    fontSize: PokoFont.small,
                                    color: t.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '— ${memories[safeIndex].dateText} · 陪伴第 ${_dayOf(memories[safeIndex])} 天',
                                  style: TextStyle(
                                    fontSize: PokoFont.tiny,
                                    color: t.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_lastSnapMessage != null) ...[
                    const SizedBox(height: PokoSpacing.sm),
                    Text(
                      _lastSnapMessage!,
                      style: const TextStyle(
                        fontSize: PokoFont.caption,
                        color: PokoPalette.rose,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: PokoSpacing.md),

                  // 底部：咔嚓！即时快门拍立得纪念按钮
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _takeSnapshot,
                      icon: const Text('📷', style: TextStyle(fontSize: 18)),
                      label: const Text(
                        '咔嚓！拍下一张今日纪念照',
                        style: TextStyle(
                          fontSize: PokoFont.bodyLg,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: t.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: PokoSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(PokoRadius.md),
                        ),
                        elevation: 3,
                        shadowColor: t.accent.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String val, String icon) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: PokoSpacing.xs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: PokoFont.tiny,
                color: PokoPalette.amberDeep,
              ),
            ),
            Text(
              val,
              style: const TextStyle(
                fontSize: PokoFont.caption,
                fontWeight: FontWeight.bold,
                color: PokoPalette.amberDeep,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 绘制复古纯白纸感拍立得相片
  Widget _buildPolaroidCard(MemoryEntry card, bool isSelected) {
    final t = context.poko(widget.isNight);
    final style = _styleOf(card);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 154,
      padding: const EdgeInsets.fromLTRB(
        PokoSpacing.sm,
        PokoSpacing.sm,
        PokoSpacing.sm,
        PokoSpacing.md,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(PokoRadius.md),
        border: Border.all(
          color: isSelected ? t.accent : t.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected
            ? PokoShadow.card(t.accent)
            : PokoShadow.soft(t.shadow),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 相片显影窗口
          Container(
            width: double.infinity,
            height: 110,
            decoration: BoxDecoration(
              color: style.photoBg,
              borderRadius: BorderRadius.circular(PokoRadius.xs),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(card.emoji, style: const TextStyle(fontSize: 48)),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PokoSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: style.badgeBg,
                      borderRadius: BorderRadius.circular(PokoRadius.xs),
                    ),
                    child: Text(
                      card.badge,
                      style: TextStyle(
                        fontSize: PokoFont.tiny,
                        fontWeight: FontWeight.bold,
                        color: style.badgeColor,
                      ),
                    ),
                  ),
                ),
                if (_isFlashing && isSelected)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(PokoRadius.xs),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: PokoSpacing.sm),
          // 拍立得手写签名栏
          Text(
            card.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: PokoFont.small,
              fontWeight: FontWeight.bold,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: PokoSpacing.xxs),
          Text(
            '${card.dateText} · 第 ${_dayOf(card)} 天',
            style: TextStyle(
              fontSize: PokoFont.tiny,
              color: t.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
