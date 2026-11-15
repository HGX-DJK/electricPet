import 'package:flutter/material.dart';

import '../../widgets/bouncy_touch_feedback.dart';
import '../../models/overlay_settings.dart';
import '../../services/overlay_service.dart';
import '../../theme/poko_theme.dart';

/// 桌面悬浮宠设置面板
///
/// 设计要点：
/// - 每一项改动都立刻推给原生侧，桌面上那只猫会实时跟着变（改大小立刻变大、改透明度立刻变淡）
/// - 不做"保存"按钮：所见即所得，少一次心智负担
class FloatingPetSettingsSheet extends StatefulWidget {
  final bool isNight;

  const FloatingPetSettingsSheet({super.key, required this.isNight});

  /// 便捷弹出
  static Future<void> show(BuildContext context, {required bool isNight}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => FloatingPetSettingsSheet(isNight: isNight),
    );
  }

  @override
  State<FloatingPetSettingsSheet> createState() => _FloatingPetSettingsSheetState();
}

class _FloatingPetSettingsSheetState extends State<FloatingPetSettingsSheet> {
  OverlaySettings _settings = const OverlaySettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await OverlayService.getSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  /// 立即下发：桌面上的悬浮宠实时生效
  ///
  /// ⚠️ 下发失败必须把界面**回滚**回去：面板顶部写着「改动即时生效」，
  /// 如果实际没生效却把新值留在界面上，用户会一直以为已经改好了，
  /// 直到在桌面上看到老样子才发现。
  Future<void> _apply(OverlaySettings next) async {
    final previous = _settings;
    setState(() => _settings = next);
    final ok = await OverlayService.updateSettings(next);
    if (ok || !mounted) return;
    setState(() => _settings = previous);
    final reason = OverlayService.lastError ?? '未知原因';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('设置没能同步到桌面悬浮宠（$reason）'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.poko(widget.isNight);
    return PokoSheetShell(
      isNight: widget.isNight,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('⚙️', style: TextStyle(fontSize: PokoFont.displayMd)),
                      const SizedBox(width: 8),
                      Text(
                        '悬浮宠设置',
                        style: TextStyle(
                          fontSize: PokoFont.title,
                          fontWeight: FontWeight.bold,
                          color: t.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '改动即时生效',
                        style: TextStyle(fontSize: PokoFont.caption, color: t.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _PreviewCard(settings: _settings, isNight: widget.isNight),
                  const SizedBox(height: 18),

                  _SectionTitle(text: '体型大小', isNight: widget.isNight),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final dp in OverlaySettings.sizePresets) ...[
                        Expanded(
                          child: _ChoiceChip(
                            label: dp == 60
                                ? '小巧\n60dp'
                                : dp == 82
                                    ? '标准\n82dp'
                                    : '大气\n110dp',
                            selected: _settings.sizeDp == dp,
                            isNight: widget.isNight,
                            onTap: () => _apply(_settings.copyWith(sizeDp: dp)),
                          ),
                        ),
                        if (dp != OverlaySettings.sizePresets.last)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '也可以直接在桌面用两指捏合波可来缩放',
                    style: TextStyle(fontSize: PokoFont.caption, color: t.textSecondary),
                  ),
                  const SizedBox(height: 18),

                  _SectionTitle(text: '透明度', isNight: widget.isNight),
                  Slider(
                    value: _settings.opacity,
                    min: 0.35,
                    max: 1.0,
                    divisions: 13,
                    activeColor: t.accent,
                    label: '${(_settings.opacity * 100).round()}%',
                    onChanged: (v) => _apply(_settings.copyWith(opacity: v)),
                  ),
                  const SizedBox(height: 6),

                  _SectionTitle(text: '行为开关', isNight: widget.isNight),
                  const SizedBox(height: 4),
                  _SwitchRow(
                    icon: '👀',
                    title: '闲置探头避让',
                    subtitle: '久不互动时缩到屏幕边缘探头张望',
                    value: _settings.peeking,
                    isNight: widget.isNight,
                    onChanged: (v) => _apply(_settings.copyWith(peeking: v)),
                  ),
                  _SwitchRow(
                    icon: '🚶',
                    title: '自主边缘散步',
                    subtitle: '贴着屏幕边缘自己溜达几步',
                    value: _settings.strolling,
                    isNight: widget.isNight,
                    onChanged: (v) => _apply(_settings.copyWith(strolling: v)),
                  ),
                  _SwitchRow(
                    icon: '💬',
                    title: '主动搭话',
                    subtitle: '长时间没人理时会自己冒泡说句话',
                    value: _settings.autoChat,
                    isNight: widget.isNight,
                    onChanged: (v) => _apply(_settings.copyWith(autoChat: v)),
                  ),
                  _SwitchRow(
                    icon: '🧲',
                    title: '边缘磁吸',
                    subtitle: '关掉后松手就停在原地，不会被吸回屏幕边',
                    value: _settings.edgeSnap,
                    isNight: widget.isNight,
                    onChanged: (v) => _apply(_settings.copyWith(edgeSnap: v)),
                  ),

                  const SizedBox(height: 16),
                  _TipsCard(isNight: widget.isNight),
                ],
              ),
            ),
    );
  }
}

/// 预览卡片：用尺寸比例直观展示当前设置
class _PreviewCard extends StatelessWidget {
  final OverlaySettings settings;
  final bool isNight;

  const _PreviewCard({required this.settings, required this.isNight});

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    final scale = settings.sizeDp / 82.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: t.isNight ? PokoPalette.night_surface_alt : PokoPalette.glow_soft,
        borderRadius: BorderRadius.circular(PokoRadius.lg),
        border: Border.all(
          color: t.isNight ? PokoPalette.night_border : PokoPalette.orange_200,
        ),
      ),
      child: Column(
        children: [
          Opacity(
            opacity: settings.opacity,
            child: Transform.scale(
              scale: scale,
              child: const Text('🐱', style: TextStyle(fontSize: 44)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '桌面上的波可就是这个样子',
            style: TextStyle(fontSize: PokoFont.small, color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool isNight;

  const _SectionTitle({required this.text, required this.isNight});

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    return Text(
      text,
      style: TextStyle(
        fontSize: PokoFont.body,
        fontWeight: FontWeight.bold,
        color: t.textPrimary,
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isNight;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.isNight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    return BouncyTouchFeedback(
      scaleDown: 0.96,
        onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? (t.isNight ? PokoPalette.night_border : PokoPalette.orange_100)
              : (t.isNight ? PokoPalette.night_surface_alt : Colors.white),
          borderRadius: BorderRadius.circular(PokoRadius.md),
          border: Border.all(
            color: selected
                ? (t.isNight ? PokoPalette.indigo_500 : PokoPalette.orange_400)
                : (t.isNight ? PokoPalette.night_border : PokoPalette.slate_200),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: PokoFont.small,
            height: 1.4,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? t.accentDeep : t.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool isNight;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isNight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: PokoFont.title)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: PokoFont.body,
                    fontWeight: FontWeight.w600,
                    color: t.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: PokoFont.caption, color: t.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: t.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 玩法提示卡：告诉用户新的交互方式
class _TipsCard extends StatelessWidget {
  final bool isNight;

  const _TipsCard({required this.isNight});

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.isNight ? PokoPalette.night_surface_alt : PokoPalette.emerald_50,
        borderRadius: BorderRadius.circular(PokoRadius.md),
        border: Border.all(
          color: t.isNight ? PokoPalette.night_border : PokoPalette.mint_200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🐾 桌面上的新玩法',
            style: TextStyle(
              fontSize: PokoFont.body,
              fontWeight: FontWeight.bold,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '· 摸头 / 摸身 / 摸尾巴 / 戳爪爪，会有四种不同反应\n'
            '· 波可会一直盯着你的指尖看\n'
            '· 点菜单里的小鱼干，拖到它嘴边才算喂到\n'
            '· 双击波可它会原地转圈，回小窝请点菜单里的 🏠\n'
            '· 气泡也能点，点一下就回小窝',
            style: TextStyle(
              fontSize: PokoFont.caption,
              height: 1.6,
              color: t.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
