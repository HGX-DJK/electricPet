import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 萌宠 14 种才艺绝活展示面板 (现代移动端 BottomSheet 设计)
class ActionDialog extends StatelessWidget {
  final ValueChanged<String> onActionSelected;

  const ActionDialog({super.key, required this.onActionSelected});

  static const List<Map<String, String>> actions = [
    {'id': 'CARDBOARD_BOX', 'name': '纸箱藏猫猫', 'icon': '📦', 'desc': '钻入快递箱探头暗中观察', 'tag': '调皮'},
    {'id': 'CATCH_MOUSE', 'name': '喵影神捕', 'icon': '🐭', 'desc': '敏捷一扑抓住机械小老鼠', 'tag': '敏捷'},
    {'id': 'PLAY_YARN', 'name': '玩毛线球', 'icon': '🧶', 'desc': '抱着粉红毛线团滚来滚去', 'tag': '玩耍'},
    {'id': 'ROLL_OVER', 'name': '翻肚皮撒娇', 'icon': '😻', 'desc': '四脚朝天软软打滚求摸摸', 'tag': '撒娇'},
    {'id': 'PEEK_EDGE', 'name': '贴边偷看', 'icon': '👀', 'desc': '吸附在屏幕边缘探出半个脑袋', 'tag': '观察'},
    {'id': 'WASH_FACE', 'name': '洗脸理毛', 'icon': '🐾', 'desc': '抬起小爪认真打理软毛', 'tag': '日常'},
    {'id': 'STRETCH_YAWN', 'name': '伸懒腰哈欠', 'icon': '🥱', 'desc': '躬身伸懒腰，打个超大哈欠', 'tag': '惬意'},
    {'id': 'TILT_HEAD', 'name': '歪头卖萌', 'icon': '❓', 'desc': '好奇歪头眨巴水灵大眼睛', 'tag': '好奇'},
    {'id': 'LOOK_AROUND', 'name': '四处巡视', 'icon': '🔍', 'desc': '左瞅瞅右看看，保卫主人手机', 'tag': '警惕'},
    {'id': 'SIT_WAG_TAIL', 'name': '端坐摇尾巴', 'icon': '🐈', 'desc': '乖乖蹲坐，蓬松尾巴轻轻晃动', 'tag': '乖巧'},
    {'id': 'HEAD_BOB_MUSIC', 'name': '听歌点头', 'icon': '🎵', 'desc': '戴着耳机跟着动感音乐晃头', 'tag': '潮流'},
    {'id': 'CHASE_BUTTERFLY', 'name': '扑捉蝴蝶', 'icon': '🦋', 'desc': '追逐彩光小蝴蝶灵巧起跳', 'tag': '跃动'},
    {'id': 'HAPPY_SPIN', 'name': '欢喜转圈', 'icon': '💫', 'desc': '满心欢喜，兴奋地原地打转', 'tag': '元气'},
    {'id': 'DOZE_OFF', 'name': '犯困打盹', 'icon': '💤', 'desc': '小脑瓜一点一点，直打瞌睡', 'tag': '困倦'},
    {'id': 'DIZZY', 'name': '眩晕星星', 'icon': '⭐', 'desc': '眼花缭乱，头顶小星星转圈圈', 'tag': '搞笑'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖拽手柄
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

          // 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('✨', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 8),
                  Text(
                    '波可的才艺才华秀',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF94A3B8)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '点击任意绝活，波可将立即在屏幕上即兴表演！',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),

          // 才艺列表
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: actions.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final act = actions[index];
                return _ActionTile(
                  icon: act['icon']!,
                  name: act['name']!,
                  desc: act['desc']!,
                  tag: act['tag']!,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    onActionSelected(act['id']!);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  final String icon;
  final String name;
  final String desc;
  final String tag;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.name,
    required this.desc,
    required this.tag,
    required this.onTap,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(widget.icon, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.tag,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F46E5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.desc,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 2),
                    Text(
                      '表演',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
  }
}
