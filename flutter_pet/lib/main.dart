import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/pet_model.dart';
import 'models/memo_model.dart';
import 'views/pet_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 自定义全屏异常边界捕获：确保无论发生任何未知错误，都绝不纯白屏，而是优雅呈现可爱猫咪提示
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: const Color(0xFFFFF7ED),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🐱', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text(
                  '波可桌面宠物 · 启动中',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      );
    };

    // 全局未捕获 Flutter 框架错误上报
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };

    // 状态栏沉浸透明
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    // 启动前在主线程预加载持久化数据，杜绝首次构建时的异步竞争与 notifyListeners 干扰
    final petModel = PetModel();
    final memoModel = MemoModel();
    try {
      await petModel.loadFromDisk();
      await memoModel.loadFromDisk();
    } catch (e) {
      debugPrint('Config pre-load non-fatal error: $e');
    }

    runApp(DesktopElectricPetApp(petModel: petModel, memoModel: memoModel));
  }, (Object error, StackTrace stack) {
    debugPrint('💥 [Zone Error] $error\n$stack');
  });
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          surface: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: PetScreen(
        petModel: _petModel,
        memoModel: _memoModel,
      ),
    );
  }
}
