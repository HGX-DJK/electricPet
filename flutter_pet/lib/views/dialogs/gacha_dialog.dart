import 'package:flutter/material.dart';
import '../../models/pet_model.dart';
import '../../services/haptic_service.dart';

class GachaItem {
  final String rarity;
  final String slot;
  final String id;
  final String name;
  final String icon;
  final bool isNew;

  const GachaItem({
    required this.rarity,
    required this.slot,
    required this.id,
    required this.name,
    required this.icon,
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
      isNew: map['isNew'] as bool? ?? false,
    );
  }
}

/// 🌌 全息赛博盲盒扭蛋机面板 (Cyber Gacha Pod)
/// 30 能量币单抽、270 能量币十连必出 SSR/UR、炫酷开箱卡片与一键穿戴
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

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
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
          content: Text('⚡ 赛博能量币不足 (需 $cost 币)，多陪波可玩耍或升级可赢取代币！'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 2),
        ),
      );
      HapticService.light();
      return;
    }

    setState(() {
      _isPulling = true;
    });
    HapticService.medium();
    _animCtrl.forward(from: 0.0);

    Future.delayed(const Duration(milliseconds: 400), () {
      final rawResults = widget.model.drawGacha(count);
      final results = rawResults.map((m) => GachaItem.fromMap(m)).toList();
      final hasHighRarity = results.any((item) => item.rarity == 'UR' || item.rarity == 'SSR');

      if (hasHighRarity) {
        HapticService.jackpotHaptic();
      } else {
        HapticService.heavy();
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
        return const Color(0xFFEC4899); // 霓虹粉紫
      case 'SSR':
        return const Color(0xFFF59E0B); // 赛博曜金
      case 'SR':
        return const Color(0xFF8B5CF6); // 星空幻紫
      case 'R':
      default:
        return const Color(0xFF0EA5E9); // 科技天青
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;

    return Container(
      height: MediaQuery.of(context).size.height * 0.76,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // 暗曜夜空底色
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 30,
            offset: Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部指示条
          Center(
            child: Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 标题栏：盲盒机名字、代币余额、关闭按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('🪐', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '赛博能量盲盒舱',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'CYBER GACHA POD v2.0',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0EA5E9).withOpacity(0.9),
                          letterSpacing: 1.2,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          '${model.coins}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFDE68A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 核心内容展示区
          Expanded(
            child: _recentResults != null
                ? _buildResultsView()
                : _buildPodShowcase(),
          ),

          const SizedBox(height: 12),

          // 底部抽卡按钮区
          _buildActionButtons(),
        ],
      ),
    );
  }

  /// 盲盒机外观与保底公告视图
  Widget _buildPodShowcase() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 全息发光扭蛋机舱图景
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFF0EA5E9).withOpacity(0.35),
                const Color(0xFF6366F1).withOpacity(0.1),
                Colors.transparent,
              ],
            ),
          ),
          child: Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFFC084FC)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Text('🔮', style: TextStyle(fontSize: 46)),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 保底特权横幅
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFF59E0B).withOpacity(0.15),
                const Color(0xFFEC4899).withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✨', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Text(
                '十连抽享 9 折且必出 SSR/UR 极品神装！',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFDE68A),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 奖池爆款预览轮播条
        Text(
          '涵盖：战术目镜、RGB键盘、全息逗猫棒、极客冷萃、复古掌机、天使羽翼',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: const Color(0xFF94A3B8).withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  /// 抽取结果卡片流
  Widget _buildResultsView() {
    final results = _recentResults!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '🎉 启封获得 (${results.length} 件神装)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE2E8F0),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _recentResults = null;
                });
              },
              child: const Text('返回机舱', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            itemCount: results.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.45,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              final item = results[index];
              final rarityColor = _getRarityColor(item.rarity);
              final isEquipped = item.slot == 'habitat'
                  ? widget.model.habitat == item.id
                  : widget.model.decorations[item.slot] == item.id;

              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: rarityColor.withOpacity(0.6), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: rarityColor.withOpacity(0.18),
                      blurRadius: 10,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item.icon, style: const TextStyle(fontSize: 22)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: rarityColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: rarityColor, width: 0.8),
                          ),
                          child: Text(
                            item.rarity,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: rarityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.slotName,
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(0xFF94A3B8).withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 24,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isEquipped ? const Color(0xFF334155) : rarityColor,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: isEquipped
                            ? null
                            : () {
                                if (item.slot == 'habitat') {
                                  widget.model.setHabitat(item.id);
                                } else {
                                  widget.model.setDecoration(item.slot, item.id);
                                }
                                HapticService.selection();
                                setState(() {});
                                widget.onUpdated();
                              },
                        child: Text(
                          isEquipped ? '已穿戴' : '一键穿戴',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isEquipped ? const Color(0xFF94A3B8) : Colors.white,
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

  /// 底部抽卡按钮
  Widget _buildActionButtons() {
    return Row(
      children: [
        // 单抽
        Expanded(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
              ),
            ),
            onPressed: _isPulling ? null : () => _handleDraw(1),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '⚡ 单次启封',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                ),
                SizedBox(height: 2),
                Text(
                  '30 能量币',
                  style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        // 十连抽 (保底)
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 4,
              shadowColor: const Color(0xFF0EA5E9).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isPulling ? null : () => _handleDraw(10),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🚀 全息十连', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6),
                    Text('必出SSR/UR', style: TextStyle(fontSize: 10, color: Color(0xFFFDE68A))),
                  ],
                ),
                SizedBox(height: 2),
                Text(
                  '270 能量币 (限时9折)',
                  style: TextStyle(fontSize: 11, color: Color(0xFFE0F2FE)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
