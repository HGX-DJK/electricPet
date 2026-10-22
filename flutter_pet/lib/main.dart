import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/pet_model.dart';
import 'models/memo_model.dart';
import 'theme/poko_theme.dart';
import 'views/pet_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 状态栏沉浸透明 (内容延伸到状态栏下方, 由各页面用 SafeArea 让位)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  // 容错与防黑屏安全兜底：渲染异常时展示温润萌宠占位，杜绝 Release 模式出现黑屏
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFF1E1B4B),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐱', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              '波可正在努力苏醒中...',
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  };

  final petModel = PetModel();
  final memoModel = MemoModel();
  // 秒开优化：立即执行 runApp 呈现首帧，杜绝异步 I/O 阻塞导致原生黑屏闪烁；本地存档在后台异步回填

  runApp(DesktopElectricPetApp(petModel: petModel, memoModel: memoModel));
}

class DesktopElectricPetApp extends StatefulWidget {
  final PetModel? petModel;
  final MemoModel? memoModel;

  const DesktopElectricPetApp({
    super.key,
    this.petModel,
    this.memoModel,
  });

  @override
  State<DesktopElectricPetApp> createState() => _DesktopElectricPetAppState();
}

class _DesktopElectricPetAppState extends State<DesktopElectricPetApp> {
  late final PetModel _petModel;
  late final MemoModel _memoModel;

  @override
  void initState() {
    super.initState();
    _petModel = widget.petModel ?? PetModel();
    _memoModel = widget.memoModel ?? MemoModel();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '电子宠物',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.light, // 昼夜由 App 内部节律决定, 不跟随系统
      builder: (context, child) {
        // 全局统一文字缩放上限, 避免超大字体把浮层布局挤爆
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15),
          ),
          child: child!,
        );
      },
      home: PetScreen(
        petModel: _petModel,
        memoModel: _memoModel,
      ),
    );
  }

  /// 统一主题: 品牌主色 + 一致的圆角/间距/字阶
  ThemeData _buildTheme(Brightness brightness) {
    final isNight = brightness == Brightness.dark;
    final t = PokoTokens.of(isNight);
    final scheme = ColorScheme.fromSeed(
      seedColor: PokoPalette.indigo,
      brightness: brightness,
    ).copyWith(
      primary: t.accent,
      surface: t.surface,
      onSurface: t.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'sans-serif',
      scaffoldBackgroundColor: t.canvas,
      splashFactory: InkSparkle.splashFactory,
      // 统一弹层圆角
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PokoRadius.xl)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(PokoRadius.xl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isNight ? t.borderStrong : t.textPrimary,
        contentTextStyle: const TextStyle(fontSize: PokoFont.body, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PokoRadius.md)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      // 统一页面转场
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
