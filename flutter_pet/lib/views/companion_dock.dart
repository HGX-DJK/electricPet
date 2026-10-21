import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/pet_model.dart';
import '../theme/poko_theme.dart';

/// 灵动伴侣岛快捷操作栏。
///
/// 之前每个按钮都带一种马卡龙底色 (橙/粉/紫/红/黄/绿/蓝共 7 种), 互相抢注意力;
/// 现在统一为同一套中性底色 + 1px 描边, 颜色交给 emoji 本身表达 —— 保留活泼感,
/// 但视觉层级干净了。
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
    final t = context.poko(isNight);

    final buttons = <Widget>[
      _DockButton(isNight: isNight, icon: '🍱', label: '投喂', onTap: onFeedTap),
      if (onTeaseTap != null)
        _DockButton(isNight: isNight, icon: '🧶', label: '逗趣', onTap: onTeaseTap!),
      _DockButton(isNight: isNight, icon: '👗', label: '衣橱', onTap: onWardrobeTap),
      _DockButton(isNight: isNight, icon: '✨', label: '绝活', onTap: onActionTap),
      _DockButton(isNight: isNight, icon: '📝', label: '便签', onTap: onMemoTap),
      _DockButton(isNight: isNight, icon: '🫧', label: '洗澡', onTap: onBathTap),
      _DockButton(
        isNight: isNight,
        icon: model.isSleeping ? '☀️' : '🌙',
        label: model.isSleeping ? '唤醒' : '哄睡',
        onTap: onSleepTap,
      ),
      _DockButton(isNight: isNight, icon: '📱', label: '悬浮', onTap: onToggleFloating),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: isNight ? 0.90 : 0.95),
        borderRadius: BorderRadius.circular(PokoRadius.lg),
        border: Border.all(color: t.border, width: 1),
        boxShadow: PokoShadow.card(t.shadow),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              buttons[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  final bool isNight;
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _DockButton({
    required this.isNight,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.poko(widget.isNight);
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 44,
          height: 52,
          decoration: BoxDecoration(
            // 统一中性底色; 按下时才浮出品牌色, 形成清晰的交互反馈
            color: _pressed ? t.accentSoft : t.surfaceAlt.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(PokoRadius.md),
            border: Border.all(
              color: _pressed ? t.accent.withValues(alpha: 0.45) : t.border,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: PokoFont.caption,
                  fontWeight: FontWeight.w600,
                  color: t.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
