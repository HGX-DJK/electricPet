/// 波可外观探针的快捷入口。
///
/// 真正的实现见同目录下的 `render_cat_probe.dart` —— 这里只是把命令写短一点：
///
/// ```bash
/// flutter test tool/zz_debug_probe.dart
/// ```
///
/// 产物在 `<系统临时目录>/poko_probe/orientation.png`，用来肉眼核对
/// 「波可的朝向 / 尾巴有没有压在家具上」这类只能看图才能确认的问题。
library;

import 'render_cat_probe.dart' as probe;

void main() => probe.main();
