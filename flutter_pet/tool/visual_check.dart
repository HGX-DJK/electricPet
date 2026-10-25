/// 波可 App 的「可视化体检」入口。
///
/// 手机端的问题（文字被省略号切掉、控件压住猫身、抽屉头部挤成一团）
/// 光读代码看不出来，渲染成图片一眼就能定位。这个仓库里共有三支探针：
///
/// | 探针 | 作用 | 产物 |
/// | --- | --- | --- |
/// | `render_ui_probe.dart` | 把真实 App 按 390×844 渲染成 PNG，逐屏审查首页 / 抽屉 / 弹层 | `<临时目录>/poko_ui/*.png` |
/// | `render_cat_probe.dart` | 单独渲染猫与家具场景，核对朝向、尾巴、遮挡 | `<临时目录>/poko_probe/orientation.png` |
/// | `hit_probe.dart` | 打印某个屏幕坐标上覆盖着哪些控件 + 命中测试链 | 控制台 |
///
/// 本文件是猫/家具探针的快捷入口：
///
/// ```bash
/// flutter test tool/visual_check.dart
/// ```
///
/// 产物在 `<系统临时目录>/poko_probe/orientation.png`，用来肉眼核对
/// 「波可的朝向 / 尾巴有没有压在家具上」这类只能看图才能确认的问题。
library;

import 'render_cat_probe.dart' as probe;

void main() => probe.main();
