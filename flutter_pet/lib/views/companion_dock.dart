import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pet_model.dart';

/// 灵动伴侣岛快捷操作栏 (马卡龙灵动岛胶囊设计，支持昼夜自适应)
class CompanionDock extends StatelessWidget {
  final PetModel model;
  final VoidCallback onFeedTap;
  final VoidCallback onWardrobeTap;
  final VoidCallback onActionTap;
  final VoidCallback onMemoTap;
  final VoidCallback onBathTap;
  final VoidCallback onSleepTap;
  final VoidCallback onToggleFloating;
  final VoidCallback? onTeaseTap;
  final bool isNight;

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
    this.onTeaseTap,
    this.isNight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isNight
            ? const Color(0xFF161334).withValues(alpha: 0.90)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isNight ? const Color(0xFF4338CA).withValues(alpha: 0.4) : Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isNight
                ? const Color(0xFF0D0A24).withValues(alpha: 0.6)
                : const Color(0xFF6366F1).withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: isNight
                ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
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
              color: isNight ? const Color(0xFF241F48) : const Color(0xFFFFF7ED),
              border: isNight ? const Color(0xFF6366F1).withValues(alpha: 0.5) : const Color(0xFFFED7AA),
              textColor: isNight ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              onTap: onFeedTap,
            ),
            const SizedBox(width: 8),
            if (onTeaseTap != null) ...[
              _DockButton(
                icon: '🧶',
                label: '逗趣',
                color: isNight ? const Color(0xFF2A1C3C) : const Color(0xFFFDF2F8),
                border: isNight ? const Color(0xFFEC4899).withValues(alpha: 0.5) : const Color(0xFFFBCFE8),
                textColor: isNight ? const Color(0xFFFCE7F3) : const Color(0xFF334155),
                onTap: onTeaseTap!,
              ),
              const SizedBox(width: 8),
            ],
            _DockButton(
              icon: '👗',
              label: '衣橱',
              color: isNight ? const Color(0xFF221A44) : const Color(0xFFFAF5FF),
              border: isNight ? const Color(0xFF8B5CF6).withValues(alpha: 0.5) : const Color(0xFFE9D5FF),
              textColor: isNight ? const Color(0xFFEDE9FE) : const Color(0xFF334155),
              onTap: onWardrobeTap,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: '✨',
              label: '绝活',
              color: isNight ? const Color(0xFF2E1C32) : const Color(0xFFFFF1F2),
              border: isNight ? const Color(0xFFF43F5E).withValues(alpha: 0.5) : const Color(0xFFFECDD3),
              textColor: isNight ? const Color(0xFFFFE4E6) : const Color(0xFF334155),
              onTap: onActionTap,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: '📝',
              label: '便签',
              color: isNight ? const Color(0xFF2A232B) : const Color(0xFFFEFCE8),
              border: isNight ? const Color(0xFFEAB308).withValues(alpha: 0.5) : const Color(0xFFFEF08A),
              textColor: isNight ? const Color(0xFFFEF9C3) : const Color(0xFF334155),
              onTap: onMemoTap,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: '🫧',
              label: '洗澡',
              color: isNight ? const Color(0xFF172938) : const Color(0xFFECFDF5),
              border: isNight ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFFA7F3D0),
              textColor: isNight ? const Color(0xFFD1FAE5) : const Color(0xFF334155),
              onTap: onBathTap,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: model.isSleeping ? '☀️' : '🌙',
              label: model.isSleeping ? '唤醒' : '哄睡',
              color: isNight
                  ? const Color(0xFF231E54)
                  : (model.isSleeping ? const Color(0xFFFEF08A) : const Color(0xFFEEF2FF)),
              border: isNight
                  ? const Color(0xFF818CF8).withValues(alpha: 0.6)
                  : (model.isSleeping ? const Color(0xFFFACC15) : const Color(0xFFC7D2FE)),
              textColor: isNight ? const Color(0xFFE0E7FF) : const Color(0xFF334155),
              onTap: onSleepTap,
            ),
            const SizedBox(width: 8),
            _DockButton(
              icon: '📱',
              label: '悬浮',
              color: isNight ? const Color(0xFF1E2442) : const Color(0xFFF0FDF4),
              border: isNight ? const Color(0xFF6366F1).withValues(alpha: 0.5) : const Color(0xFFBBF7D0),
              textColor: isNight ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
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
  final Color? textColor;
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.border,
    this.textColor,
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
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor ?? const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
