import 'package:flutter/material.dart';
import '../theme/poko_theme.dart';
import '../models/memo_model.dart';
import '../widgets/poko_tap_target.dart';

/// 桌面便签 (马卡龙四色主题便签半屏面板)
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(PokoRadius.xl)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        // 滚动容器 + 高度上限：
        // 键盘弹起时会叠加 viewInsets.bottom，原来这个固定 Column
        // 在小窗口 / 横屏下会把底部调色盘顶出可视区，够不着。
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            // 便签顶部把手
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: theme.sub.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 便签顶部标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Text('📝', style: TextStyle(fontSize: PokoFont.headline)),
                  const SizedBox(width: 8),
                  Text(
                    '随手灵感便签',
                    style: TextStyle(
                      fontSize: PokoFont.titleSm,
                      fontWeight: FontWeight.bold,
                      color: theme.text,
                    ),
                  ),
                  const Spacer(),
                  // 插入时间戳按钮
                  PokoTapTarget(
                    semanticLabel: '插入当前时间戳',
                    onTap: () {
                      widget.memoModel.insertTimestamp();
                      _controller.text = widget.memoModel.content;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(PokoRadius.sm),
                        border: Border.all(color: theme.border.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: theme.sub),
                          const SizedBox(width: 4),
                          Text(
                            '时间戳',
                            style: TextStyle(fontSize: PokoFont.caption, color: theme.sub, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PokoTapTarget(
                    semanticLabel: '关闭便签',
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 18, color: theme.sub),
                    ),
                  ),
                ],
              ),
            ),

            // 便签文本输入编辑区
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(PokoRadius.lg),
                  border: Border.all(color: theme.border.withValues(alpha: 0.8)),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: 6,
                  style: TextStyle(fontSize: PokoFont.bodyMd, color: theme.text, height: 1.5),
                  decoration: const InputDecoration(
                    hintText: '写下当下的心事、待办灵感或想对波可说的话...',
                    hintStyle: TextStyle(color: PokoPalette.slate_400, fontSize: PokoFont.body),
                    border: InputBorder.none,
                  ),
                  onChanged: (text) {
                    widget.memoModel.setContent(text);
                    setState(() {});
                  },
                ),
              ),
            ),

            // 底部操作与四色马卡龙调色盘
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  // 四色主题切换按钮
                  ...MemoModel.themes.entries.map((entry) {
                    final t = entry.value;
                    final isSelected = (widget.memoModel.currentThemeKey == entry.key);
                    // 26dp 的色卡在手机上很难点准 ——
                    // 命中区扩到 40dp，视觉尺寸保持 26dp 不变。
                    return PokoTapTarget(
                      semanticLabel: '切换便签配色：${entry.value.name}',
                      minTapTarget: 40,
                      onTap: () {
                        widget.memoModel.setTheme(entry.key);
                        setState(() {});
                      },
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: t.header,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? PokoPalette.slate_800 : t.border,
                            width: isSelected ? 2.5 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
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
                    style: TextStyle(fontSize: PokoFont.caption, color: theme.sub.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
