import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pet_model.dart';

/// 萌宠专属美味餐厅投喂半屏面板 (支持连续投喂、实时饱腹反馈与猫咪实时吃食互动)
class FeedingDialog extends StatelessWidget {
  final PetModel model;
  final ValueChanged<String> onFeedSelected;

  const FeedingDialog({
    super.key,
    required this.model,
    required this.onFeedSelected,
  });

  @override
  Widget build(BuildContext context) {
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
          // 顶部拖拽把手指示条
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
                  Text('🍱', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text(
                    '波可的美食小厨房',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 实时饱腹度与体重进度条 (带动态监听更新)
          AnimatedBuilder(
            animation: model,
            builder: (context, _) {
              final hungerPct = (model.hunger / 100.0).clamp(0.0, 1.0);
              final isFull = model.hunger >= 95.0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('饱腹度', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                            const SizedBox(width: 6),
                            Text(
                              '${model.hunger.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isFull ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '体重: ${model.weight.toStringAsFixed(2)} kg  ${isFull ? "🌟 肚子饱饱" : "😋 嗷嗷待哺"}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 8,
                        color: const Color(0xFFFEF3C7),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: hungerPct,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isFull
                                    ? [const Color(0xFF34D399), const Color(0xFF10B981)]
                                    : [const Color(0xFFFBBF24), const Color(0xFFF59E0B)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // 美食佳肴列表 (可连续投喂，上方猫咪实时品尝并塑造独特性格)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 310),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.05,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: PetModel.foodMenu.length,
              itemBuilder: (context, index) {
                final food = PetModel.foodMenu[index];
                final pType = food['personality'] as String?;
                String pBadge = '';
                Color pColor = const Color(0xFFD97706);
                if (pType == 'HACKER') {
                  pBadge = ' · 极客+1';
                  pColor = const Color(0xFF0EA5E9);
                } else if (pType == 'ATHLETE') {
                  pBadge = ' · 运动+1';
                  pColor = const Color(0xFFEF4444);
                } else if (pType == 'LAZY') {
                  pBadge = ' · 佛系+1';
                  pColor = const Color(0xFF10B981);
                }

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onFeedSelected(food['id'] as String);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(food['icon'] as String, style: const TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food['name'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '+${(food['hunger'] as double).toInt()}饱腹 +${(food['exp'] as double).toInt()}经验$pBadge',
                                style: TextStyle(fontSize: 9.2, color: pColor, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // 底部温馨提示
          const Center(
            child: Text(
              '💡 提示：点击美味可连续投喂，猫咪会在上方大快朵颐哦~',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}
