import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pet/models/pet_model.dart';
import 'package:flutter_pet/services/backup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 「波可的时光纪念相册」的行为守护测试。
///
/// 背景：这个功能以前是**五张写死的假卡片**，日期也是编的；
/// 「咔嚓！拍下一张今日纪念照」按钮只播了个音效，什么也没存 ——
/// 整个相册没有任何实际意义。现在改成真实的成长记录 + 真拍照 + 真落盘。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // 别把测试数据写到用户真实的公共备份目录里
    final tmp = Directory('${Directory.systemTemp.path}/poko_backup_test');
    if (!tmp.existsSync()) tmp.createSync(recursive: true);
    BackupService.customBackupDir = tmp.path;
  });

  test('初次相遇会自动记下第一张纪念', () async {
    final model = PetModel();
    await model.isReady;

    expect(model.memories, isNotEmpty, reason: '第一次相遇必须留下一条纪念');
    expect(model.memories.first.id, 'meet');
    expect(model.memories.first.timestamp, greaterThan(0));
  });

  test('第一次投喂会记下里程碑，且不会重复记', () async {
    final model = PetModel();
    await model.isReady;

    model.feed('dried_fish');
    expect(model.memories.where((m) => m.id == 'first_feed').length, 1,
        reason: '第一次投喂必须留下一条「第一口小鱼干」');

    model.feed('canned_tuna');
    expect(model.memories.where((m) => m.id == 'first_feed').length, 1,
        reason: '同一个里程碑只能记一次');
  });

  test('第一次洗澡会记下里程碑', () async {
    final model = PetModel();
    await model.isReady;

    model.wash();
    expect(model.memories.where((m) => m.id == 'first_wash').length, 1);
  });

  test('升级会留下真实的等级里程碑', () async {
    final model = PetModel();
    await model.isReady;

    model.addExp(500);
    expect(model.memories.where((m) => m.id.startsWith('level_')).isNotEmpty,
        isTrue, reason: '升级必须留下纪念');
  });

  test('里程碑按 id 去重：重复触发只留一条', () async {
    final model = PetModel();
    await model.isReady;

    model.recordMemory(
        id: 'x', title: 't', note: 'n', emoji: '🐾', badge: 'b');
    model.recordMemory(
        id: 'x', title: 't2', note: 'n2', emoji: '🐾', badge: 'b');
    expect(model.memories.where((m) => m.id == 'x').length, 1);
  });

  test('拍下的今日纪念照会真的进相册，并且落盘后还能读回来', () async {
    final model = PetModel();
    await model.isReady;

    final before = model.memories.length;
    final entry = model.takeSnapshot();

    expect(model.memories.length, before + 1, reason: '拍照必须真的多一张卡');
    expect(model.memories.first.id, entry.id, reason: '新照片排在最前');
    expect(entry.isSnapshot, isTrue);
    expect(entry.title, contains('月'));
    expect(entry.note.trim(), isNotEmpty, reason: '照片要带一句话手记');

    // 落盘 → 重新读档，照片还在
    await model.saveToDisk();
    final reloaded = PetModel();
    await reloaded.isReady;
    expect(reloaded.memories.any((m) => m.id == entry.id), isTrue,
        reason: '纪念必须持久化，重启不能丢');
  });

  test('纪念按时间倒序，最新的在最前面', () async {
    final model = PetModel();
    await model.isReady;

    model.takeSnapshot();
    model.recordMemory(
        id: 'older', title: 't', note: 'n', emoji: '🐾', badge: 'b',
        timestamp: model.memories.first.timestamp - 100000);

    for (var i = 0; i + 1 < model.memories.length; i++) {
      expect(model.memories[i].timestamp,
          greaterThanOrEqualTo(model.memories[i + 1].timestamp),
          reason: '相册必须按时间倒序');
    }
  });

  test('相册容量有上限，不会无限膨胀', () async {
    final model = PetModel();
    await model.isReady;

    for (var i = 0; i < PetModel.maxMemories + 20; i++) {
      model.takeSnapshot();
    }
    expect(model.memories.length, lessThanOrEqualTo(PetModel.maxMemories));
  });
}
