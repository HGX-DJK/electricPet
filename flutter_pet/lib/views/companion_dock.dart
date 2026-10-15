import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pet_model.dart';

/// 移动端灵动伴侣岛快捷操作栏 (现代悬浮毛玻璃灵动胶囊设计)
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.95),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
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
                  bgGradient: const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                  borderColor: const Color(0xFFFED7AA),
                  onTap: onFeedTap,
                ),
                const SizedBox(width: 8),
                _DockButton(
                  icon: '👗',
                  label: '衣橱',
                  bgGradient: const [Color(0xFFFAF5FF), Color(0xFFF3E8FF)],
                  borderColor: const Color(0xFFE9D5FF),
                  onTap: onWardrobeTap,
                ),
                const SizedBox(width: 8),
                _DockButton(
                  icon: '✨',
                  label: '绝活',
                  bgGradient: const [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
                  borderColor: const Color(0xFFFECDD3),
                  onTap: onActionTap,
                ),
                const SizedBox(width: 8),
                _DockButton(
                  icon: '📱',
                  label: '悬浮',
                  bgGradient: const [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                  borderColor: const Color(0xFFBBF7D0),
                  onTap: onToggleFloating,
                ),
                const SizedBox(width: 8),
                _DockButton(
                  icon: '🫧',
                  label: '洗澡',
                  bgGradient: const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                  borderColor: const Color(0xFFA7F3D0),
                  onTap: onBathTap,
                ),
                const SizedBox(width: 8),
                _DockButton(
                  icon: model.isSleeping ? '☀️' : '🌙',
                  label: model.isSleeping ? '唤醒' : '哄睡',
                  bgGradient: model.isSleeping
                      ? const [Color(0xFFFEFCE8), Color(0xFFFEF08A)]
                      : const [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                  borderColor: model.isSleeping ? const Color(0xFFFACC15) : const Color(0xFFC7D2FE),
                  onTap: onSleepTap,
                ),
                const SizedBox(width: 8),
                _DockButton(
                  icon: '📝',
                  label: '便签',
                  bgGradient: const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                  borderColor: const Color(0xFFFDE68A),
                  onTap: onMemoTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  final String icon;
  final String label;
  final List<Color> bgGradient;
  final Color borderColor;
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.bgGradient,
    required this.borderColor,
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
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: Container(
          width: 48,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.bgGradient,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: widget.borderColor.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
