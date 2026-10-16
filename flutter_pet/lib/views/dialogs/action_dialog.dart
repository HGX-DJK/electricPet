import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 萌宠 14 种才艺绝活展示半屏面板
class ActionDialog extends StatelessWidget {
  final ValueChanged<String> onActionSelected;

  const ActionDialog({super.key, required this.onActionSelected});

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
    {'id': 'HAPPY_SPIN', 'name': '欢喜转圈', 'icon': '💫', 'desc': '满心欢喜，兴奋地原地打转'},
    {'id': 'DOZE_OFF', 'name': '犯困打盹', 'icon': '💤', 'desc': '小脑瓜一点一点，直打瞌睡'},
    {'id': 'DIZZY', 'name': '眩晕星星', 'icon': '⭐', 'desc': '眼花缭乱，头顶小星星转圈圈'},
  ];

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
                  Text('✨', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text(
                    '波可的才艺才华秀',
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
            '点击任意绝活，上方小猫将即刻展示独家特技~ 🐾',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),

          // 14 种才艺双列卡片
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 330),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.15,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Text(act['icon']!, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                act['name']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                act['desc']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF6366F1), size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
