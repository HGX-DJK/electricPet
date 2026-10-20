import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pet_model.dart';
import '../models/memo_model.dart';

/// 跨平台公用目录静默备份服务 (防卸载丢失数据沉淀)
/// 针对 Android (Download / Documents) 与 Windows (用户文档目录) 提供免登录沉淀保障
class BackupService {
  /// 测试或自定义环境路径重写挂钩
  static String? customBackupDir;

  /// 获取候选公用存储目录列表
  static List<String> get candidateBackupDirs {
    if (customBackupDir != null) {
      return [customBackupDir!];
    }

    final dirs = <String>[];
    try {
      if (!kIsWeb) {
        if (Platform.isAndroid) {
          dirs.add('/storage/emulated/0/Download/ElectricPet');
          dirs.add('/sdcard/Download/ElectricPet');
          dirs.add('/storage/emulated/0/Documents/ElectricPet');
        } else if (Platform.isWindows) {
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null && userProfile.isNotEmpty) {
            dirs.add('$userProfile\\Documents\\ElectricPet');
          }
          final appData = Platform.environment['APPDATA'];
          if (appData != null && appData.isNotEmpty) {
            dirs.add('$appData\\ElectricPet');
          }
        } else if (Platform.isMacOS || Platform.isLinux) {
          final home = Platform.environment['HOME'];
          if (home != null && home.isNotEmpty) {
            dirs.add('$home/Documents/ElectricPet');
          }
        }
      }
    } catch (e) {
      debugPrint('获取备份目录异常: $e');
    }
    return dirs;
  }

  /// 静默双写备份到外部公共持久化目录
  static Future<void> writeSilentBackup(Map<String, dynamic> petData, {Map<String, dynamic>? memoData}) async {
    try {
      final dirs = candidateBackupDirs;
      if (dirs.isEmpty) return;

      final payload = {
        'version': 2,
        'format': 'POKO_PUBLIC_BACKUP',
        'savedAt': DateTime.now().toIso8601String(),
        'pet': petData,
        if (memoData != null) 'memo': memoData,
      };
      final jsonContent = const JsonEncoder.withIndent('  ').convert(payload);

      for (final dirPath in dirs) {
        try {
          final dir = Directory(dirPath);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          final file = File('${dir.path}/poko_backup.json');
          await file.writeAsString(jsonContent, flush: true);
          // 成功写入任一有效候选目录即完成
          return;
        } catch (_) {
          // 继续尝试备用候选目录
        }
      }
    } catch (e) {
      debugPrint('静默外部备份写入失败 (安全忽略): $e');
    }
  }

  /// 检测公用目录是否存在有价值的“历史波可档案”
  static Future<Map<String, dynamic>?> checkHistoricalBackup() async {
    try {
      final dirs = candidateBackupDirs;
      for (final dirPath in dirs) {
        try {
          final file = File('$dirPath/poko_backup.json');
          if (await file.exists()) {
            final raw = await file.readAsString();
            if (raw.trim().isEmpty) continue;
            final data = jsonDecode(raw) as Map<String, dynamic>;
            final pet = data['pet'] as Map<String, dynamic>?;
            if (pet != null) {
              final level = (pet['level'] as num?)?.toInt() ?? 1;
              final unlockedItems = (pet['unlockedItems'] as List?)?.cast<String>() ?? [];
              final coins = (pet['coins'] as num?)?.toInt() ?? 200;
              final totalFed = (pet['totalFedCount'] as num?)?.toInt() ?? 0;
              final intimacy = (pet['intimacy'] as num?)?.toInt() ?? 100;
              final skinId = pet['skinId'] as String? ?? 'cat_calico';

              // 判断该档案是否具备继承价值 (已升级、抽过盲盒、喂食过、换过皮肤等)
              final bool hasValue = level >= 2 ||
                  unlockedItems.length > 5 ||
                  coins != 200 ||
                  totalFed > 0 ||
                  intimacy > 100 ||
                  skinId != 'cat_calico';

              if (hasValue) {
                return data;
              }
            }
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      debugPrint('检测历史备份异常: $e');
    }
    return null;
  }

  /// 一键继承并恢复历史档案
  static Future<bool> restoreFromHistoricalBackup(
    Map<String, dynamic> backupPayload,
    PetModel pet, {
    MemoModel? memo,
  }) async {
    try {
      final petData = backupPayload['pet'] as Map<String, dynamic>?;
      if (petData == null) return false;

      // 1. 恢复宠物数据
      pet.restoreFromData(petData);
      await pet.saveToDisk();

      // 2. 恢复便签数据 (若有)
      final memoData = backupPayload['memo'] as Map<String, dynamic>?;
      if (memoData != null && memo != null) {
        memo.content = memoData['content'] ?? memo.content;
        memo.currentThemeKey = memoData['currentThemeKey'] ?? memo.currentThemeKey;
        memo.isPinned = memoData['isPinned'] ?? memo.isPinned;
        memo.updatedAt = memoData['updatedAt'] ?? memo.updatedAt;
        await memo.saveToDisk();
      }

      return true;
    } catch (e) {
      debugPrint('恢复历史档案失败: $e');
      return false;
    }
  }

  /// 导出防丢文本存档码 (Base64 加密压缩口令，适用于跨手机迁移)
  static String exportSaveCode(Map<String, dynamic> petData) {
    try {
      final jsonStr = jsonEncode({
        'version': 2,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'data': petData,
      });
      final b64 = base64Encode(utf8.encode(jsonStr));
      return 'POKO#v2#$b64';
    } catch (e) {
      return '';
    }
  }

  /// 导入文本存档码
  static Map<String, dynamic>? importSaveCode(String code) {
    try {
      var cleaned = code.trim();
      if (cleaned.startsWith('POKO#v2#')) {
        cleaned = cleaned.substring('POKO#v2#'.length);
      } else if (cleaned.startsWith('POKO#')) {
        cleaned = cleaned.substring('POKO#'.length);
      }
      final jsonStr = utf8.decode(base64Decode(cleaned));
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded['data'] as Map<String, dynamic>? ?? decoded;
    } catch (e) {
      return null;
    }
  }
}
