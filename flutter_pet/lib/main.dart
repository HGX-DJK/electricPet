import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/pet_model.dart';
import 'models/memo_model.dart';
import 'views/pet_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 状态栏沉浸透明
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  final petModel = PetModel();
  final memoModel = MemoModel();
  await Future.wait([petModel.isReady, memoModel.isReady]);

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
