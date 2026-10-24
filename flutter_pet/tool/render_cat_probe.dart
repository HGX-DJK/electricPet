// 一次性可视化探针：把波可按真实坐标渲染成 PNG，用来肉眼核对"朝向 / 屁股对着家具"的问题。
// 用法：flutter test tool/render_cat_probe.dart
// 产物：<系统临时目录>/poko_probe/orientation.png
//
// ⚠️ 跑完看到 PROBE_OUT=... 就说明图已经生成，可以直接 Ctrl+C 结束 ——
//    这个探针渲染完不会自动退出（渲染引擎还占着），别等它。
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

Widget _cat(PetModel model, double petX, double petY, bool facingLeft) {
  return Positioned(
    left: petX - 100,
    top: petY - 100,
    child: CustomPaint(
      size: const Size(200, 200),
      painter: PetPainter(
        model: model,
        animTime: 0.35,
        state: 'IDLE',
        facingLeft: facingLeft,
      ),
    ),
  );
}

Widget _scene({
  required PetModel model,
  required bool grass,
  required bool facingLeft,
  required String label,
}) {
  // 家具：猫草在左 (left:24)，猫抓柱在右 (right:24)
  final Widget furniture = grass
      ? const Positioned(
          left: 24,
          top: kFloorTop + 16,
          child: CatGrassPlanter(isNight: false, plantTilt: 0, onTap: _noop),
        )
      : const Positioned(
          right: 24,
          top: kFloorTop + 16,
          child: CatScratchingPost(isNight: false, postWiggle: 0, onTap: _noop),
        );
  // 猫的落点：猫草 +38（猫在草右边），猫抓柱 -38（猫在柱左边）
  final double petX = grass ? 48.0 + 38.0 : (kCellW - 48.0) - 38.0;
  const double petY = kFloorTop + 42.0;

  return SizedBox(
    width: kCellW,
    height: kCellH,
    child: Stack(
      children: <Widget>[
        Container(color: const Color(0xFFEDE0CE)),
        // 木地板
        Positioned(
          left: 0,
          top: kFloorTop,
          child: Container(width: kCellW, height: kCellH - kFloorTop, color: const Color(0xFFD9C3A3)),
        ),
        furniture,
        _cat(model, petX, petY, facingLeft),
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
      _scene(model: black, grass: true, facingLeft: true, label: 'BLACK grass | facingLeft=true (现状)'),
      _scene(model: black, grass: true, facingLeft: false, label: 'BLACK grass | facingLeft=false'),
      _scene(model: black, grass: false, facingLeft: false, label: 'BLACK post | facingLeft=false (现状)'),
      _scene(model: black, grass: false, facingLeft: true, label: 'BLACK post | facingLeft=true'),
      _scene(model: ragdoll, grass: true, facingLeft: true, label: 'RAGDOLL grass | facingLeft=true (现状)'),
      _scene(model: ragdoll, grass: true, facingLeft: false, label: 'RAGDOLL grass | facingLeft=false'),
      _scene(model: ragdoll, grass: false, facingLeft: false, label: 'RAGDOLL post | facingLeft=false (现状)'),
      _scene(model: ragdoll, grass: false, facingLeft: true, label: 'RAGDOLL post | facingLeft=true'),
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
