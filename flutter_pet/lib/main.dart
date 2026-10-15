import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/pet_model.dart';
import 'models/memo_model.dart';
import 'views/pet_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 状态栏沉浸透明
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const DesktopElectricPetApp());
}

class DesktopElectricPetApp extends StatefulWidget {
  const DesktopElectricPetApp({super.key});

  @override
  State<DesktopElectricPetApp> createState() => _DesktopElectricPetAppState();
}

class _DesktopElectricPetAppState extends State<DesktopElectricPetApp> {
  late final PetModel _petModel;
  late final MemoModel _memoModel;

  @override
  void initState() {
    super.initState();
    _petModel = PetModel();
    _memoModel = MemoModel();
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
        fontFamily: 'sans-serif',
      ),
      home: PetScreen(
        petModel: _petModel,
        memoModel: _memoModel,
      ),
    );
  }
}
