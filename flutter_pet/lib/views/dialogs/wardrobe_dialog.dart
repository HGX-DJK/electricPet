import 'package:flutter/material.dart';
import '../../models/pet_model.dart';

/// 萌宠魔法衣橱换装弹窗 (皮肤与饰品切换)
class WardrobeDialog extends StatelessWidget {
  final PetModel model;

  const WardrobeDialog({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '经典猫咪花色',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: PetModel.availableSkins.values.map((skin) {
                  final isSelected = (model.skinId == skin.id);
                  return GestureDetector(
                    onTap: () {
                      model.setSkin(skin.id);
                    },
                    child: Container(
                      width: 90,
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFF3E8FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFA855F7) : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Color(skin.primaryColor),
                              shape: BoxShape.circle,
                              border: Border.all(color: Color(skin.secondaryColor), width: 3),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            skin.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
            const SizedBox(height: 16),
            const Text(
              '随心配饰挂件',
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
                    model.setDecoration('neck', model.decorations['neck'] == 'bell' ? 'none' : 'bell');
                  },
                ),
                const SizedBox(width: 10),
                _buildDecoItem(
                  icon: '🎀',
                  name: '俏皮蝴蝶结',
                  isSelected: model.decorations['neck'] == 'ribbon',
                  onTap: () {
                    model.setDecoration('neck', model.decorations['neck'] == 'ribbon' ? 'none' : 'ribbon');
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecoItem({
    required String icon,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF92400E) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
