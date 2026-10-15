import 'package:flutter/material.dart';

/// 萌宠 14 种才艺绝活展示弹窗
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
                    Text('✨', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 8),
                    Text(
                      '波可的才艺才华秀',
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
            SizedBox(
              height: 360,
              child: ListView.separated(
                itemCount: actions.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final act = actions[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    tileColor: const Color(0xFFF8FAFC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    leading: Text(act['icon']!, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      act['name']!,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    subtitle: Text(
                      act['desc']!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF6366F1), size: 28),
                    onTap: () {
                      onActionSelected(act['id']!);
                      Navigator.pop(context);
                    },
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
