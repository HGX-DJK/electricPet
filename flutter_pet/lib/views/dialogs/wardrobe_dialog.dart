import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pet_model.dart';

/// 萌宠魔法衣橱换装半屏面板 (即时变身，上方实时预览)
class WardrobeDialog extends StatefulWidget {
  final PetModel model;

  const WardrobeDialog({super.key, required this.model});

  @override
  State<WardrobeDialog> createState() => _WardrobeDialogState();
}

class _WardrobeDialogState extends State<WardrobeDialog> {
  @override
  Widget build(BuildContext context) {
    final model = widget.model;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖拽指示把手
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
          const SizedBox(height: 14),

          // 标题与关闭按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('👗', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text(
                    '波可的魔法衣橱',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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
          const SizedBox(height: 4),
          const Text(
            '点击任意毛色或配饰，上方小猫即刻实时变身 ✨',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          const Text(
            '🐾 经典猫咪毛色',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),

          // 毛色滑动卡片
          SizedBox(
            height: 105,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: PetModel.availableSkins.values.map((skin) {
                final isSelected = (model.skinId == skin.id);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      model.setSkin(skin.id);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 95,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF3E8FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFA855F7) : const Color(0xFFE2E8F0),
                        width: isSelected ? 2.2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFA855F7).withOpacity(0.20),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Color(skin.primaryColor),
                                shape: BoxShape.circle,
                                border: Border.all(color: Color(skin.secondaryColor), width: 3.0),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_rounded, color: Color(0xFFA855F7), size: 22),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          skin.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? const Color(0xFF7E22CE) : const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          const Text(
            '🎀 随心配饰挂件',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _buildDecoItem(
                icon: '🔔',
                name: '金色小铃铛',
                isSelected: model.decorations['neck'] == 'bell',
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    model.setDecoration('neck', model.decorations['neck'] == 'bell' ? 'none' : 'bell');
                  });
                },
              ),
              const SizedBox(width: 12),
              _buildDecoItem(
                icon: '🎀',
                name: '俏皮蝴蝶结',
                isSelected: model.decorations['neck'] == 'ribbon',
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    model.setDecoration('neck', model.decorations['neck'] == 'ribbon' ? 'none' : 'ribbon');
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDecoItem({
    required String icon,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
              width: isSelected ? 2.0 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF92400E) : const Color(0xFF475569),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check_circle_rounded, color: Color(0xFFF59E0B), size: 15),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
