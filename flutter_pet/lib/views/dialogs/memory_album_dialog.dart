import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pet_model.dart';
import '../../services/sound_service.dart';
import '../../theme/poko_theme.dart';

/// 陪伴时光纪念拍立得相册卡片
class MemoryCardData {
  final String title;
  final String date;
  final String emoji;
  final String note;
  final String badge;
  final Color badgeBg;
  final Color badgeColor;
  final Color photoBg;

  const MemoryCardData({
    required this.title,
    required this.date,
    required this.emoji,
    required this.note,
    required this.badge,
    required this.badgeBg,
    required this.badgeColor,
    required this.photoBg,
  });
}

/// 萌宠时光拍立得相册与成长纪念手账
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

class _MemoryAlbumDialogState extends State<MemoryAlbumDialog> {
  int _selectedCardIndex = 0;
  bool _isFlashing = false;
  String? _lastSnapMessage;

  // 经典时光回忆纪念卡池
  late final List<MemoryCardData> _memories;

  @override
  void initState() {
    super.initState();
    _memories = [
      MemoryCardData(
        title: '初遇初雪那天',
        date: 'Day 1 · 相遇记',
        emoji: '🐱',
        note: '波可第一次被领进温暖的房间，大大的水灵眼睛怯生生又好奇地打量着四周~',
        badge: '初入家门',
        badgeBg: PokoPalette.skySoft,
        badgeColor: PokoPalette.skyDeep,
        photoBg: PokoPalette.sky.withValues(alpha: 0.14),
      ),
      MemoryCardData(
        title: '小鱼干自由的干饭猫',
        date: '美食打卡',
        emoji: '🐟',
        note: '第一次尝到香酥小鱼干，小胡须兴奋抖动，嚼得嘎吱嘎吱响，满嘴鱼香！',
        badge: '特级干饭猫',
        badgeBg: PokoPalette.amberSoft,
        badgeColor: PokoPalette.amber,
        photoBg: PokoPalette.amber.withValues(alpha: 0.14),
      ),
      MemoryCardData(
        title: '粉红毛线球追逐战',
        date: '活力瞬间',
        emoji: '🧶',
        note: '毛线球骨碌碌滚到床底，波可像个毛茸茸小雪球一样扑过去，满地打滚！',
        badge: '淘气捕手',
        badgeBg: PokoPalette.rose.withValues(alpha: 0.14),
        badgeColor: PokoPalette.roseDeep,
        photoBg: PokoPalette.rose.withValues(alpha: 0.10),
      ),
      const MemoryCardData(
        title: '原木剑麻咔嚓磨爪',
        date: '成长解压',
        emoji: '🪵',
        note: '利爪尖尖磨得亮晶晶，剑麻柱沙沙撕扯作响，神气活现的小威风霸气侧漏！',
        badge: '利爪大师',
        badgeBg: PokoPalette.amberSoft,
        badgeColor: PokoPalette.amberDeep,
        photoBg: PokoPalette.amberSoft,
      ),
      const MemoryCardData(
        title: '云朵暖暖窝幸福踩奶',
        date: '治愈甜梦',
        emoji: '🥐',
        note: '粉嫩肉垫在蓬松云朵垫子里轮流深浅按压，呼噜声比拖拉机还响，烤熟了小面包~',
        badge: '治愈满分',
        badgeBg: PokoPalette.violetSoft,
        badgeColor: PokoPalette.violetDeep,
        photoBg: PokoPalette.violetSoft,
      ),
    ];
  }

  /// 点击“即时快门咔嚓”拍照留念
  void _takeSnapshot() {
    SoundService.playShutter();
    if (widget.model.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _isFlashing = true;
      _lastSnapMessage = '咔嚓！已将当前波可的甜萌瞬间收入纪念相册中~ 📸💕';
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
          child: Column(
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
                            '记录与波可相遇以来的每个治愈瞬间 · 拍立得手账',
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
                    _buildStatItem('已陪伴', '${widget.model.totalDays} 天', '📅'),
                    Container(
                      width: 1,
                      height: 24,
                      color: PokoPalette.amber.withValues(alpha: 0.55),
                    ),
                    _buildStatItem('当前品种', widget.model.currentSkin.name, '🐾'),
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

              // 拍立得照片卡片滑动区
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _memories.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: PokoSpacing.md),
                  itemBuilder: (context, index) {
                    final card = _memories[index];
                    final isSelected = _selectedCardIndex == index;
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
                      child: Text(
                        _memories[_selectedCardIndex].note,
                        style: TextStyle(
                          fontSize: PokoFont.small,
                          color: t.textSecondary,
                          height: 1.45,
                        ),
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
  Widget _buildPolaroidCard(MemoryCardData card, bool isSelected) {
    final t = context.poko(widget.isNight);
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
              color: card.photoBg,
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
                      color: card.badgeBg,
                      borderRadius: BorderRadius.circular(PokoRadius.xs),
                    ),
                    child: Text(
                      card.badge,
                      style: TextStyle(
                        fontSize: PokoFont.tiny,
                        fontWeight: FontWeight.bold,
                        color: card.badgeColor,
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
            card.date,
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
