import 'package:flutter/material.dart';
import '../models/pet_model.dart';

/// 灵动伴侣岛快捷操作栏 (仿 iOS 灵动岛马卡龙胶囊设计)
class CompanionDock extends StatelessWidget {
  final PetModel model;
  final VoidCallback onFeedTap;
  final VoidCallback onWardrobeTap;
  final VoidCallback onActionTap;
  final VoidCallback onMemoTap;
  final VoidCallback onBathTap;
  final VoidCallback onSleepTap;
  final VoidCallback onToggleFloating;

  const CompanionDock({
    super.key,
    required this.model,
    required this.onFeedTap,
    required this.onWardrobeTap,
    required this.onActionTap,
    required this.onMemoTap,
    required this.onBathTap,
    required this.onSleepTap,
    required this.onToggleFloating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItem(
            icon: '🍱',
            label: '投喂',
            color: const Color(0xFFFFF7ED),
            border: const Color(0xFFFED7AA),
            onTap: onFeedTap,
          ),
          const SizedBox(width: 8),
          _buildItem(
            icon: '👗',
            label: '衣橱',
            color: const Color(0xFFFAF5FF),
            border: const Color(0xFFE9D5FF),
            onTap: onWardrobeTap,
          ),
          const SizedBox(width: 8),
          _buildItem(
            icon: '✨',
            label: '绝活',
            color: const Color(0xFFFFF1F2),
            border: const Color(0xFFFECDD3),
            onTap: onActionTap,
          ),
          const SizedBox(width: 8),
          _buildItem(
            icon: '📝',
            label: '便签',
            color: const Color(0xFFFEFCE8),
            border: const Color(0xFFFEF08A),
            onTap: onMemoTap,
          ),
          const SizedBox(width: 8),
          _buildItem(
            icon: '🫧',
            label: '洗澡',
            color: const Color(0xFFECFDF5),
            border: const Color(0xFFA7F3D0),
            onTap: onBathTap,
          ),
          const SizedBox(width: 8),
          _buildItem(
            icon: model.isSleeping ? '☀️' : '🌙',
            label: model.isSleeping ? '唤醒' : '哄睡',
            color: const Color(0xFFEEF2FF),
            border: const Color(0xFFC7D2FE),
            onTap: onSleepTap,
          ),
          const SizedBox(width: 8),
          _buildItem(
            icon: '📱',
            label: '悬浮',
            color: const Color(0xFFF0FDF4),
            border: const Color(0xFFBBF7D0),
            onTap: onToggleFloating,
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String icon,
    required String label,
    required Color color,
    required Color border,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
