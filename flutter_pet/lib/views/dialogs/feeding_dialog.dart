import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/pet_model.dart';
import '../../theme/poko_theme.dart';

/// 萌宠专属美味餐厅投喂半屏面板 (支持连续投喂、实时饱腹反馈与猫咪实时吃食互动)
class FeedingDialog extends StatelessWidget {
  final PetModel model;
  final ValueChanged<String> onFeedSelected;
  final bool isNight;

  const FeedingDialog({
    super.key,
    required this.model,
    required this.onFeedSelected,
    this.isNight = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.poko(isNight);
    return PokoSheetShell(
      isNight: isNight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PokoSpacing.xl,
          0,
          PokoSpacing.xl,
          PokoSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题与关闭按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('🍱', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: PokoSpacing.sm),
                    Text(
                      '波可的美食小厨房',
                      style: TextStyle(
                        fontSize: PokoFont.title,
                        fontWeight: FontWeight.bold,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(PokoSpacing.xs),
                    decoration: BoxDecoration(
                      color: t.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 18, color: t.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: PokoSpacing.md),

            // 实时饱腹度与体重进度条 (带动态监听更新)
            AnimatedBuilder(
              animation: model,
              builder: (context, _) {
                final hungerPct = (model.hunger / 100.0).clamp(0.0, 1.0);
                final isFull = model.isFull;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PokoSpacing.md,
                    vertical: PokoSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: PokoPalette.amberSoft,
                    borderRadius: BorderRadius.circular(PokoRadius.md),
                    border: Border.all(
                      color: PokoPalette.amber.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                '饱腹度',
                                style: TextStyle(
                                  fontSize: PokoFont.small,
                                  fontWeight: FontWeight.bold,
                                  color: PokoPalette.amberDeep,
                                ),
                              ),
                              const SizedBox(width: PokoSpacing.xs),
                              Text(
                                '${model.hunger.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: PokoFont.body,
                                  fontWeight: FontWeight.bold,
                                  color: isFull
                                      ? PokoPalette.emerald
                                      : PokoPalette.amber,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '体重: ${model.weight.toStringAsFixed(2)} kg  ${isFull ? "🌟 肚子饱饱" : "😋 嗷嗷待哺"}',
                            style: const TextStyle(
                              fontSize: PokoFont.caption,
                              color: PokoPalette.amberDeep,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: PokoSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(PokoRadius.xs),
                        child: Container(
                          height: 8,
                          color: PokoPalette.amber.withValues(alpha: 0.18),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: hungerPct,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isFull
                                      ? [
                                          PokoPalette.emerald,
                                          PokoPalette.emeraldDeep,
                                        ]
                                      : [
                                          PokoPalette.amber,
                                          PokoPalette.amberDeep,
                                        ],
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
            const SizedBox(height: PokoSpacing.md),

            // 美食佳肴列表 (可连续投喂，上方猫咪实时品尝并塑造独特性格)
            AnimatedBuilder(
              animation: model,
              builder: (context, _) {
                final isFull = model.isFull;
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 310),
                  child: GridView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.05,
                  crossAxisSpacing: PokoSpacing.sm,
                  mainAxisSpacing: PokoSpacing.sm,
                ),
                itemCount: PetModel.foodMenu.length,
                itemBuilder: (context, index) {
                  final food = PetModel.foodMenu[index];
                  final pData = food['personality'];
                  String pType = '';
                  int pVal = 1;
                  if (pData is List && pData.isNotEmpty) {
                    pType = pData[0].toString().toLowerCase();
                    if (pData.length > 1 && pData[1] is num) {
                      pVal = (pData[1] as num).toInt();
                    }
                  }
                  String pBadge = '';
                  Color pColor = PokoPalette.amber;
                  if (pType == 'tech') {
                    pBadge = ' · 极客+$pVal';
                    pColor = PokoPalette.sky;
                  } else if (pType == 'sport') {
                    pBadge = ' · 运动+$pVal';
                    pColor = PokoPalette.rose;
                  } else if (pType == 'lazy') {
                    pBadge = ' · 佛系+$pVal';
                    pColor = PokoPalette.emerald;
                  }

                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: isFull ? 0.65 : 1.0,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onFeedSelected(food['id'] as String);
                      },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PokoSpacing.sm,
                        vertical: PokoSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: t.surfaceAlt,
                        borderRadius: BorderRadius.circular(PokoRadius.md),
                        border: Border.all(color: t.border),
                        boxShadow: PokoShadow.soft(t.shadow),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: PokoPalette.amberSoft,
                              borderRadius: BorderRadius.circular(
                                PokoRadius.sm,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              food['icon'] as String,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          const SizedBox(width: PokoSpacing.sm),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  food['name'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: PokoFont.small,
                                    fontWeight: FontWeight.bold,
                                    color: t.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: PokoSpacing.xxs),
                                Text(
                                  '+${(food['hunger'] as double).toInt()}饱腹 +${(food['exp'] as double).toInt()}经验$pBadge',
                                  style: TextStyle(
                                    fontSize: PokoFont.tiny,
                                    color: pColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      const SizedBox(height: PokoSpacing.sm),

      // 底部温馨提示
      AnimatedBuilder(
        animation: model,
        builder: (context, _) {
          final isFull = model.isFull;
          return Center(
            child: Text(
              isFull
                  ? '🌟 波可已经吃得饱饱的啦~ 摸摸圆滚滚的小肚皮吧！'
                  : '💡 提示：点击美味可连续投喂，猫咪会在上方大快朵颐哦~',
              style: TextStyle(
                fontSize: PokoFont.caption,
                fontWeight: isFull ? FontWeight.bold : FontWeight.normal,
                color: isFull ? PokoPalette.emerald : t.textMuted,
              ),
            ),
          );
        },
      ),
          ],
        ),
      ),
    );
  }
}
