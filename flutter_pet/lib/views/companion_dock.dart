import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pet_model.dart';

/// 灵动伴侣岛快捷操作栏 (马卡龙灵动岛胶囊设计)
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DockButton(
              icon: '🍱',
              label: '投喂',
              color: const Color(0xFFFFF7ED),
              border: const Color(0xFFFED7AA),
              onTap: onFeedTap,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: '👗',
              label: '衣橱',
              color: const Color(0xFFFAF5FF),
              border: const Color(0xFFE9D5FF),
              onTap: onWardrobeTap,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: '✨',
              label: '绝活',
              color: const Color(0xFFFFF1F2),
              border: const Color(0xFFFECDD3),
              onTap: onActionTap,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: '📝',
              label: '便签',
              color: const Color(0xFFFEFCE8),
              border: const Color(0xFFFEF08A),
              onTap: onMemoTap,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: '🫧',
              label: '洗澡',
              color: const Color(0xFFECFDF5),
              border: const Color(0xFFA7F3D0),
              onTap: onBathTap,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: model.isSleeping ? '☀️' : '🌙',
              label: model.isSleeping ? '唤醒' : '哄睡',
              color: model.isSleeping ? const Color(0xFFFEF08A) : const Color(0xFFEEF2FF),
              border: model.isSleeping ? const Color(0xFFFACC15) : const Color(0xFFC7D2FE),
              onTap: onSleepTap,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: '📱',
              label: '悬浮',
              color: const Color(0xFFF0FDF4),
              border: const Color(0xFFBBF7D0),
              onTap: onToggleFloating,
            ),
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  final String icon;
  final String label;
  final Color color;
  final Color border;
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.border,
    required this.onTap,
  });

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 44,
          height: 52,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.border, width: 1.2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
