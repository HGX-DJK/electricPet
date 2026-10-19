import 'package:flutter/material.dart';
import '../../models/pet_model.dart';
import '../../services/haptic_service.dart';
import '../../services/sound_service.dart';

class GachaItem {
  final String rarity;
  final String slot;
  final String id;
  final String name;
  final String icon;
  final String desc;
  final bool isNew;

  const GachaItem({
    required this.rarity,
    required this.slot,
    required this.id,
    required this.name,
    required this.icon,
    this.desc = '',
    this.isNew = false,
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
    );
  }
}

/// ✨ 奇迹星愿扭蛋机面板 (Dream Capsule Pod)
/// 30 币单抽与 270 币十连抽 (100% 保底 SSR/UR 绝品发光配件)
/// 采用温暖治愈日落奶油美学，支持开箱品质辉光卡片与一键穿戴/布置小窝
class GachaDialog extends StatefulWidget {
  final PetModel model;
  final VoidCallback onUpdated;

  const GachaDialog({
    super.key,
    required this.model,
    required this.onUpdated,
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
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleDraw(int count) {
    final cost = count == 1 ? 30 : 270;
    if (widget.model.coins < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ 能量币不足 (需 $cost 币)，多陪波可玩耍或投喂可获得能量币！'),
          backgroundColor: const Color(0xFFF43F5E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    Future.delayed(const Duration(milliseconds: 450), () {
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
        return const Color(0xFFF43F5E); // 绝品梦幻粉金
      case 'SSR':
        return const Color(0xFFF59E0B); // 璀璨曜金
      case 'SR':
        return const Color(0xFFA855F7); // 幻梦星紫
      case 'R':
      default:
        return const Color(0xFF0EA5E9); // 清晨天青
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
    final isNight = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: isNight ? const Color(0xFF1E1738) : const Color(0xFFFFFDF8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: isNight ? const Color(0xFF4C3D77) : const Color(0xFFFED7AA),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 28,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部指示条
          Center(
            child: Container(
              width: 42,
              height: 4.5,
              decoration: BoxDecoration(
                color: isNight ? const Color(0xFF4C3D77) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 标题栏：心愿扭蛋机、代币余额、关闭按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFEDD5), Color(0xFFFDE68A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text('✨', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '奇迹星愿扭蛋机',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isNight ? Colors.white : const Color(0xFF1E293B),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'DREAM CAPSULE POD · 灵动心愿',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFF7A55),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // 能量币余额胶囊
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isNight ? const Color(0xFF2E2452) : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.5),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          '${model.coins}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isNight ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      SoundService.playClick();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isNight ? const Color(0xFF2E2452) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isNight ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (_lastEquippedMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Text('🐾', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _lastEquippedMessage!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 核心内容展示区 (机舱外观 / 抽取结果卡片流)
          Expanded(
            child: _recentResults != null
                ? _buildResultsView(isNight)
                : _buildPodShowcase(isNight),
          ),

          const SizedBox(height: 12),

          // 底部抽卡祈愿按钮区
          _buildActionButtons(isNight),
        ],
      ),
    );
  }

  /// 萌趣梦幻扭蛋机展示视图
  Widget _buildPodShowcase(bool isNight) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 梦幻水晶球扭蛋仓
        RotationTransition(
          turns: Tween(begin: 0.0, end: _isPulling ? 1.0 : 0.0).animate(
            CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOutCubic),
          ),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFEDD5),
                  const Color(0xFFFED7AA).withOpacity(0.6),
                  const Color(0xFFFDE68A).withOpacity(0.2),
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
                    colors: [Color(0xFFFF9E7D), Color(0xFFFF7A55), Color(0xFFF59E0B)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF7A55).withOpacity(0.4),
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.88),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'POKO POD',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFEA580C),
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

        const SizedBox(height: 16),

        // 保底特权横幅 (十连必出 SSR / UR)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.45), width: 1.1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✨', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                '十连抽享 9 折且 100% 保底 SSR / UR 绝品神装！',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9A3412),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 奖池爆款配件预览
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '🌟 绝品装扮涵盖：战术目镜、RGB机械键盘、全息光纤逗猫棒、夏日阳光海滩、暗夜霓虹极客房、圣洁天使羽翼',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: isNight ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  /// 抽取结果卡片流
  Widget _buildResultsView(bool isNight) {
    final results = _recentResults!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '愿望启封达成 (${results.length} 件心愿之礼)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isNight ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                SoundService.playClick();
                setState(() => _recentResults = null);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFF2E2452) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF7A55).withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded, size: 13, color: Color(0xFFFF7A55)),
                    SizedBox(width: 3),
                    Text(
                      '返回机舱',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7A55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            itemCount: results.length,
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.28,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final item = results[index];
              final rarityColor = _getRarityColor(item.rarity);
              final isHabitat = item.slot == 'habitat';
              final isEquipped = isHabitat
                  ? widget.model.habitat == item.id
                  : widget.model.decorations[item.slot] == item.id;

              return Container(
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFF281F47) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: rarityColor.withOpacity(0.65),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: rarityColor.withOpacity(0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 图标与品质徽章
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: rarityColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(item.icon, style: const TextStyle(fontSize: 20)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: rarityColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: rarityColor.withOpacity(0.8), width: 0.9),
                          ),
                          child: Text(
                            _getRarityLabel(item.rarity),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: rarityColor,
                            ),
                          ),
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
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isNight ? Colors.white : const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.desc.isNotEmpty ? item.desc : item.slotName,
                          style: TextStyle(
                            fontSize: 9.5,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                            color: isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                          backgroundColor: isEquipped
                              ? (isNight ? const Color(0xFF3B2E5C) : const Color(0xFFE2E8F0))
                              : rarityColor,
                          padding: EdgeInsets.zero,
                          elevation: isEquipped ? 0 : 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isEquipped
                                ? (isNight ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
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
    return Row(
      children: [
        // 单抽
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isNight ? const Color(0xFF281F47) : Colors.white,
              foregroundColor: const Color(0xFFFF7A55),
              padding: const EdgeInsets.symmetric(vertical: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFFF7A55), width: 1.2),
              ),
            ),
            onPressed: _isPulling ? null : () => _handleDraw(1),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🌟 开启心愿',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  '30 能量币',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 十连抽 (保底)
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7A55), Color(0xFFF59E0B)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF7A55).withOpacity(0.35),
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
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isPulling ? null : () => _handleDraw(10),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🚀 幸运十连', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      SizedBox(width: 6),
                      Text('保底SSR/UR', style: TextStyle(fontSize: 10, color: Color(0xFFFEF3C7))),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    '270 能量币 (限时9折)',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFFFFFBEB)),
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
