import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pet_model.dart';
import '../../services/sound_service.dart';

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

  const MemoryAlbumDialog({
    super.key,
    required this.model,
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
      const MemoryCardData(
        title: '初遇初雪那天',
        date: 'Day 1 · 相遇记',
        emoji: '🐱',
        note: '波可第一次被领进温暖的房间，大大的水灵眼睛怯生生又好奇地打量着四周~',
        badge: '初入家门',
        badgeBg: Color(0xFFEFF6FF),
        badgeColor: Color(0xFF2563EB),
        photoBg: Color(0xFFE0F2FE),
      ),
      const MemoryCardData(
        title: '小鱼干自由的干饭猫',
        date: '美食打卡',
        emoji: '🐟',
        note: '第一次尝到香酥小鱼干，小胡须兴奋抖动，嚼得嘎吱嘎吱响，满嘴鱼香！',
        badge: '特级干饭猫',
        badgeBg: Color(0xFFFEF3C7),
        badgeColor: Color(0xFFD97706),
        photoBg: Color(0xFFFEF9C3),
      ),
      const MemoryCardData(
        title: '粉红毛线球追逐战',
        date: '活力瞬间',
        emoji: '🧶',
        note: '毛线球骨碌碌滚到床底，波可像个毛茸茸小雪球一样扑过去，满地打滚！',
        badge: '淘气捕手',
        badgeBg: Color(0xFFFCE7F3),
        badgeColor: Color(0xFFDB2777),
        photoBg: Color(0xFFFDF2F8),
      ),
      const MemoryCardData(
        title: '原木剑麻咔嚓磨爪',
        date: '成长解压',
        emoji: '🪵',
        note: '利爪尖尖磨得亮晶晶，剑麻柱沙沙撕扯作响，神气活现的小威风霸气侧漏！',
        badge: '利爪大师',
        badgeBg: Color(0xFFFEF3C7),
        badgeColor: Color(0xFFB45309),
        photoBg: Color(0xFFFFFBEB),
      ),
      const MemoryCardData(
        title: '云朵暖暖窝幸福踩奶',
        date: '治愈甜梦',
        emoji: '🥐',
        note: '粉嫩肉垫在蓬松云朵垫子里轮流深浅按压，呼噜声比拖拉机还响，烤熟了小面包~',
        badge: '治愈满分',
        badgeBg: Color(0xFFF3E8FF),
        badgeColor: Color(0xFF9333EA),
        photoBg: Color(0xFFFAF5FF),
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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // 顶部拖拽把手指示条
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 标题与关闭按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF2F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('📸', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '波可的时光纪念相册',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '记录与波可相遇以来的每个治愈瞬间 · 拍立得手账',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 陪伴羁绊数据横幅
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFED7AA)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('已陪伴', '${widget.model.level * 2 + 1} 天', '📅'),
                Container(width: 1, height: 24, color: const Color(0xFFFDBA74)),
                _buildStatItem('当前品种', widget.model.currentSkin.name, '🐾'),
                Container(width: 1, height: 24, color: const Color(0xFFFDBA74)),
                _buildStatItem('亲密羁绊', 'Lv.${widget.model.level} (${widget.model.intimacy}%)', '💖'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 拍立得照片卡片滑动区
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _memories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
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
          const SizedBox(height: 14),

          // 当前卡片手账详情寄语
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📝', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _memories[_selectedCardIndex].note,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF334155),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_lastSnapMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _lastSnapMessage!,
              style: const TextStyle(fontSize: 11, color: Color(0xFFDB2777), fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 14),

          // 底部：咔嚓！即时快门拍立得纪念按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _takeSnapshot,
              icon: const Text('📷', style: TextStyle(fontSize: 18)),
              label: const Text(
                '咔嚓！拍下一张今日纪念照',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
                shadowColor: const Color(0xFF6366F1).withOpacity(0.35),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildStatItem(String label, String val, String icon) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF9A3412))),
            Text(
              val,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF7C2D12)),
            ),
          ],
        ),
      ],
    );
  }

  /// 绘制复古纯白纸感拍立得相片
  Widget _buildPolaroidCard(MemoryCardData card, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 154,
      padding: const EdgeInsets.fromLTRB(9, 9, 9, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFE2E8F0),
          width: isSelected ? 2.2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? const Color(0xFF6366F1).withOpacity(0.25) : Colors.black.withOpacity(0.08),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
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
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(card.emoji, style: const TextStyle(fontSize: 48)),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: card.badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      card.badge,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: card.badgeColor,
                      ),
                    ),
                  ),
                ),
                if (_isFlashing && isSelected)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 拍立得手写签名栏
          Text(
            card.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            card.date,
            style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
