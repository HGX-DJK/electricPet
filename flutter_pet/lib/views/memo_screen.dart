import 'package:flutter/material.dart';
import '../models/memo_model.dart';

/// 桌面便签 (马卡龙四色主题便签面板)
class MemoScreen extends StatefulWidget {
  final MemoModel memoModel;

  const MemoScreen({super.key, required this.memoModel});

  @override
  State<MemoScreen> createState() => _MemoScreenState();
}

class _MemoScreenState extends State<MemoScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.memoModel.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.memoModel.currentTheme;

    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖拽手柄
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: theme.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 便签顶部标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.header,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.border, width: 1.5),
            ),
            child: Row(
              children: [
                const Text('📝', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  '随手灵感便签',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.text,
                  ),
                ),
                const Spacer(),
                // 插入时间戳按钮
                GestureDetector(
                  onTap: () {
                    widget.memoModel.insertTimestamp();
                    _controller.text = widget.memoModel.content;
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.border.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: theme.sub),
                        const SizedBox(width: 4),
                        Text('时间戳', style: TextStyle(fontSize: 11, color: theme.sub, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 20, color: theme.sub),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 便签文本输入编辑区
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.border.withValues(alpha: 0.6)),
            ),
            child: TextField(
              controller: _controller,
              maxLines: 6,
              style: TextStyle(fontSize: 14, color: theme.text, height: 1.5),
              decoration: const InputDecoration(
                hintText: '写下当下的心事、待办灵感或想对波可说的话...',
                hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (text) {
                widget.memoModel.setContent(text);
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 12),

          // 底部操作与四色马卡龙调色盘
          Row(
            children: [
              // 四色主题切换按钮
              ...MemoModel.themes.entries.map((entry) {
                final t = entry.value;
                final isSelected = (widget.memoModel.currentThemeKey == entry.key);
                return GestureDetector(
                  onTap: () {
                    widget.memoModel.setTheme(entry.key);
                    setState(() {});
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: t.header,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1E293B) : t.border,
                        width: isSelected ? 2.5 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
              const Spacer(),
              Text(
                '字数: ${_controller.text.length}',
                style: TextStyle(fontSize: 11, color: theme.sub.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
