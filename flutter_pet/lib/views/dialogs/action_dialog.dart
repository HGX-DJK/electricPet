import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/poko_theme.dart';

/// 萌宠 14 种才艺绝活展示半屏面板
class ActionDialog extends StatelessWidget {
  final ValueChanged<String> onActionSelected;
  final bool isNight;

  const ActionDialog({
    super.key,
    required this.onActionSelected,
    this.isNight = false,
  });

  static const List<Map<String, String>> actions = [
    {'id': 'CARDBOARD_BOX', 'name': '纸箱藏猫猫', 'icon': '📦', 'desc': '钻入快递箱探头暗中观察'},
    {'id': 'CATCH_MOUSE', 'name': '喵影神捕', 'icon': '🐭', 'desc': '敏捷一扑抓住机械小老鼠'},
    {'id': 'PLAY_YARN', 'name': '玩毛线球', 'icon': '🧶', 'desc': '抱着粉红毛线团滚来滚去'},
    {'id': 'PEEK_EDGE', 'name': '贴边偷看', 'icon': '👀', 'desc': '吸附在屏幕边缘探出半个脑袋'},
    {'id': 'WASH_FACE', 'name': '洗脸理毛', 'icon': '🐾', 'desc': '抬起小爪认真打理软毛'},
    {'id': 'STRETCH_YAWN', 'name': '伸懒腰哈欠', 'icon': '🥱', 'desc': '躬身伸懒腰，打个超大哈欠'},
    {'id': 'KNEADING_BISCUITS', 'name': '治愈踩奶', 'icon': '🥐', 'desc': '肉垫轮流下按，舒服呼噜做面包'},
    {'id': 'TILT_HEAD', 'name': '歪头卖萌', 'icon': '❓', 'desc': '好奇歪头眨巴水灵大眼睛'},
    {'id': 'LOOK_AROUND', 'name': '四处巡视', 'icon': '🔍', 'desc': '左瞅瞅右看看，保卫主人手机'},
    {'id': 'SIT_WAG_TAIL', 'name': '端坐摇尾巴', 'icon': '🐈', 'desc': '乖乖蹲坐，蓬松尾巴轻轻晃动'},
    {'id': 'HEAD_BOB_MUSIC', 'name': '听歌点头', 'icon': '🎵', 'desc': '戴着耳机跟着动感音乐晃头'},
    {'id': 'CHASE_BUTTERFLY', 'name': '扑捉蝴蝶', 'icon': '🦋', 'desc': '追逐彩光小蝴蝶灵巧起跳'},
    {'id': 'HAPPY_SPIN', 'name': '追尾转圈', 'icon': '💫', 'desc': '兴奋地原地追逐自己的尾巴狂转圈圈'},
    {'id': 'CAT_STRETCH', 'name': '猫式伸展', 'icon': '🧘', 'desc': '翘起屁股双前爪贴地，正宗猫瑜伽'},
    {'id': 'HIGH_FIVE', 'name': '击掌对拳', 'icon': '✋', 'desc': '探出毛茸茸前爪，与主人默契击掌'},
    {'id': 'ROLL_ON_BACK', 'name': '翻肚皮蹬腿', 'icon': '🐰', 'desc': '四脚朝天露软肚皮，欢快蹬蹬腿'},
    {'id': 'DOZE_OFF', 'name': '犯困打盹', 'icon': '💤', 'desc': '小脑瓜一点一点，直打瞌睡'},
    {'id': 'DIZZY', 'name': '眩晕星星', 'icon': '⭐', 'desc': '眼花缭乱，头顶小星星转圈圈'},
  ];

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
                    const Text('✨', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: PokoSpacing.sm),
                    Text(
                      '波可的才艺才华秀',
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
            const SizedBox(height: PokoSpacing.xs),
            Text(
              '点击任意绝活，上方小猫将即刻展示独家特技~ 🐾',
              style: TextStyle(
                fontSize: PokoFont.small,
                color: t.textSecondary,
              ),
            ),
            const SizedBox(height: PokoSpacing.md),

            // 14 种才艺双列卡片
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 330),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.15,
                  crossAxisSpacing: PokoSpacing.sm,
                  mainAxisSpacing: PokoSpacing.sm,
                ),
                itemCount: actions.length,
                itemBuilder: (context, index) {
                  final act = actions[index];
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onActionSelected(act['id']!);
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
                      ),
                      child: Row(
                        children: [
                          Text(
                            act['icon']!,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: PokoSpacing.sm),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  act['name']!,
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
                                  act['desc']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: PokoFont.tiny,
                                    color: t.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.play_circle_fill_rounded,
                            color: t.accent,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
