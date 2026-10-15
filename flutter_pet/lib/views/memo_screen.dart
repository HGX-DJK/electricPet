import 'package:flutter/material.dart';
import '../models/memo_model.dart';

/// 桌面便签 (马卡龙四色主题便签本)
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.border, width: 2.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 便签顶部标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.header,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: theme.sub),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 便签文本输入编辑区
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                maxLines: 8,
                style: TextStyle(fontSize: 14, color: theme.text, height: 1.5),
                decoration: const InputDecoration(
                  hintText: '写下当下的心事、待办灵感或想对波可说的话...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  border: InputBorder.none,
                ),
                onChanged: (text) {
                  widget.memoModel.setContent(text);
                },
              ),
            ),

            // 底部操作与四色马卡龙调色盘
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
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
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: t.header,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1E293B) : t.border,
                            width: isSelected ? 2.5 : 1.5,
                          ),
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  Text(
                    '字数: ${_controller.text.length}',
                    style: TextStyle(fontSize: 11, color: theme.sub.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
