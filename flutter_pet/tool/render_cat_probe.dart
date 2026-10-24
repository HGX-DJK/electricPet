// 一次性可视化探针：把波可按真实坐标渲染成 PNG，用来肉眼核对
//「朝向 / 尾巴有没有压在家具上」「猫有没有真的面对家具」这类只能看图才能确认的问题。
//
// 用法：flutter test tool/render_cat_probe.dart
// 产物：<系统临时目录>/poko_probe/orientation.png
//
// 场景参数与 pet_screen.dart 里的常量保持一致：
//   猫草   ：站位 = 草心 + 50，盆栽下沉 34px（top = 地板线 + 50），探身 +1
//   猫抓柱 ：站位 = 柱心 - 78，不下沉，探身 +1
// 家具一律画在猫之后（前景层），与 App 内新分层一致。
//
// ⚠️ 跑完看到 PROBE_OUT=... 就 Ctrl+C 结束（探针不会自动退出）。
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pet/models/pet_model.dart';
import 'package:flutter_pet/renderers/pet_painter.dart';
import 'package:flutter_pet/views/furniture/cat_room_items.dart';
import 'package:shared_preferences/shared_preferences.dart';

const double kCellW = 240;
const double kCellH = 280;
const double kFloorTop = 60;

// 与 pet_screen.dart 的 _kPlantTopOffset / _kPlantStandOffset / _kPostStandOffset 对齐
const double kPlantTopOffset = 50.0; // 盆栽 top 相对地板线
const double kPlantStandOffset = 50.0; // 猫站位距草心
const double kPostStandOffset = 78.0; // 猫站位距柱心

Widget _cat(
  PetModel model,
  double petX,
  double petY, {
  required bool facingLeft,
  required String state,
  required double focusLean,
}) {
  return Positioned(
    left: petX - 100,
    top: petY - 100,
    child: CustomPaint(
      size: const Size(200, 200),
      painter: PetPainter(
        model: model,
        animTime: 0.35,
        state: state,
        facingLeft: facingLeft,
        focusLean: focusLean,
      ),
    ),
  );
}

Widget _scene({
  required PetModel model,
  required bool grass,
  required String state,
  required String label,
}) {
  final Widget furniture = grass
      ? const Positioned(
          left: 24,
          top: kFloorTop + kPlantTopOffset,
          child: CatGrassPlanter(isNight: false, plantTilt: 0, onTap: _noop),
        )
      : const Positioned(
          right: 24,
          top: kFloorTop + 16,
          child: CatScratchingPost(isNight: false, postWiggle: 0, onTap: _noop),
        );
  final double petX = grass
      ? 48.0 + kPlantStandOffset
      : (kCellW - 48.0) - kPostStandOffset;
  const double petY = kFloorTop + 42.0;

  return SizedBox(
    width: kCellW,
    height: kCellH,
    child: Stack(
      children: <Widget>[
        Container(color: const Color(0xFFEDE0CE)),
        Positioned(
          left: 0,
          top: kFloorTop,
          child: Container(width: kCellW, height: kCellH - kFloorTop, color: const Color(0xFFD9C3A3)),
        ),
        _cat(
          model,
          petX,
          petY,
          facingLeft: grass, // 啃草朝左、磨爪朝右
          state: state,
          focusLean: 1.0,
        ),
        // ⚠️ 家具在猫之后 = 前景层（猫头不再把猫草整个盖住）
        furniture,
        Positioned(
          left: 4,
          top: 4,
          child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF1F2937))),
        ),
      ],
    ),
  );
}

void _noop() {}

void main() {
  testWidgets('render orientation probe', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final black = PetModel()..skinId = 'cat_black';
    final ragdoll = PetModel()..skinId = 'cat_ragdoll';

    final List<Widget> cells = <Widget>[
      _scene(model: black, grass: true, state: 'EATING', label: 'BLACK grass'),
      _scene(model: ragdoll, grass: true, state: 'EATING', label: 'RAGDOLL grass'),
      _scene(model: black, grass: false, state: 'STRETCH_YAWN', label: 'BLACK post'),
      _scene(model: ragdoll, grass: false, state: 'STRETCH_YAWN', label: 'RAGDOLL post'),
    ];

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Wrap(
            children: cells,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);

    final dir = Directory('${Directory.systemTemp.path}/poko_probe');
    dir.createSync(recursive: true);
    final out = File('${dir.path}/orientation.png');
    out.writeAsBytesSync(data!.buffer.asUint8List());
    // 必须释放图片，否则引擎一直占着，flutter test 进程不会退出
    image.dispose();
    // ignore: avoid_print
    print('PROBE_OUT=${out.path}');
  });
}
