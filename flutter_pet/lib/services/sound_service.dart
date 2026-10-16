import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// 萌宠全局沉浸式 ASMR 音效与物理声效服务
class SoundService {
  static bool _soundEnabled = true;
  static bool get soundEnabled => _soundEnabled;
  static set soundEnabled(bool value) {
    _soundEnabled = value;
    if (!_soundEnabled) {
      stopPurr();
    }
  }
  static AudioPlayer? _sfxPlayer;
  static AudioPlayer? _purrPlayer;
  static bool _isPurring = false;

  static AudioPlayer get sfxPlayer {
    _sfxPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    return _sfxPlayer!;
  }

  static AudioPlayer get purrPlayer {
    _purrPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
    return _purrPlayer!;
  }

  /// 软萌猫咪叫声 (Mew~ 喵呜~)
  static Future<void> playMeow() async {
    if (!soundEnabled) return;
    try {
      await sfxPlayer.stop();
      await sfxPlayer.play(AssetSource('audio/meow.wav'), volume: 0.85);
    } catch (_) {
      // 容错降级
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// 真实治愈打呼噜咕噜声 ASMR (Purr) 循环开启
  static Future<void> startPurr() async {
    if (!soundEnabled || _isPurring) return;
    _isPurring = true;
    try {
      await purrPlayer.setVolume(0.70);
      await purrPlayer.setReleaseMode(ReleaseMode.loop);
      await purrPlayer.play(AssetSource('audio/purr.wav'));
    } catch (_) {}
  }

  /// 停止打呼噜声
  static Future<void> stopPurr() async {
    if (!_isPurring) return;
    _isPurring = false;
    try {
      await purrPlayer.stop();
    } catch (_) {}
  }

  /// 家具开关清脆“啪嗒”声 (Lamp Click)
  static Future<void> playClick() async {
    // 系统物理清脆声优先提供原生级低延迟
    SystemSound.play(SystemSoundType.click);
    if (!soundEnabled) return;
    try {
      await sfxPlayer.stop();
      await sfxPlayer.play(AssetSource('audio/click.wav'), volume: 0.95);
    } catch (_) {}
  }

  /// 剑麻猫抓板磨爪沙沙声 (Scratch)
  static Future<void> playScratch() async {
    if (!soundEnabled) return;
    try {
      await sfxPlayer.stop();
      await sfxPlayer.play(AssetSource('audio/scratch.wav'), volume: 0.80);
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// 小鱼弹跳/毛线球弹射“啵”音 (Pop)
  static Future<void> playPop() async {
    if (!soundEnabled) return;
    try {
      await sfxPlayer.stop();
      await sfxPlayer.play(AssetSource('audio/pop.wav'), volume: 0.75);
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// 拍立得照片快门咔嚓音 (Shutter)
  static Future<void> playShutter() async {
    if (!soundEnabled) return;
    try {
      await sfxPlayer.stop();
      await sfxPlayer.play(AssetSource('audio/shutter.wav'), volume: 0.85);
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// 释放音频资源
  static void dispose() {
    _sfxPlayer?.dispose();
    _purrPlayer?.dispose();
    _sfxPlayer = null;
    _purrPlayer = null;
    _isPurring = false;
  }
}
