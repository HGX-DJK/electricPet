import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// 真实小猫叫声音调分类
enum MeowTone {
  random, // 随机智能匹配
  sweet,  // 经典软萌甜美长喵 (meow.wav)
  soft,   // 惬意温润耳语喵 (meow_soft.wav)
  short,  // 俏皮欢快短促轻喵 (meow_short.wav)
}

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
  static AudioPlayer? _ambientPlayer;
  static bool _isPurring = false;
  static String _ambientMode = 'none'; // 'none', 'rain', 'purr'
  static String get ambientMode => _ambientMode;
  static final math.Random _random = math.Random();

  static AudioPlayer get sfxPlayer {
    _sfxPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    return _sfxPlayer!;
  }

  static AudioPlayer get purrPlayer {
    _purrPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
    return _purrPlayer!;
  }

  static AudioPlayer get ambientPlayer {
    _ambientPlayer ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
    return _ambientPlayer!;
  }

  /// 循环切换专注助眠 ASMR 白噪音音景 ('none' -> 'rain' -> 'purr' -> 'none')
  static Future<String> cycleAmbientSound() async {
    if (!soundEnabled) return 'none';
    if (_ambientMode == 'none') {
      _ambientMode = 'rain';
      try {
        await ambientPlayer.setVolume(0.52);
        await ambientPlayer.setReleaseMode(ReleaseMode.loop);
        await ambientPlayer.play(AssetSource('audio/rain.wav'));
      } catch (_) {}
      return 'rain';
    } else if (_ambientMode == 'rain') {
      _ambientMode = 'purr';
      try {
        await ambientPlayer.setVolume(0.70);
        await ambientPlayer.setReleaseMode(ReleaseMode.loop);
        await ambientPlayer.play(AssetSource('audio/purr.wav'));
      } catch (_) {}
      return 'purr';
    } else {
      _ambientMode = 'none';
      try {
        await ambientPlayer.stop();
      } catch (_) {}
      return 'none';
    }
  }

  /// 直接设置环境白噪音模式 ('none', 'rain', 'purr')
  static Future<void> setAmbientMode(String mode) async {
    if (!soundEnabled || mode == 'none') {
      await stopAmbient();
      return;
    }
    _ambientMode = mode;
    try {
      if (mode == 'rain') {
        await ambientPlayer.setVolume(0.52);
        await ambientPlayer.setReleaseMode(ReleaseMode.loop);
        await ambientPlayer.play(AssetSource('audio/rain.wav'));
      } else if (mode == 'purr') {
        await ambientPlayer.setVolume(0.70);
        await ambientPlayer.setReleaseMode(ReleaseMode.loop);
        await ambientPlayer.play(AssetSource('audio/purr.wav'));
      }
    } catch (_) {}
  }

  /// 停止环境白噪音
  static Future<void> stopAmbient() async {
    _ambientMode = 'none';
    try {
      await ambientPlayer.stop();
    } catch (_) {}
  }

  /// 软萌猫咪叫声 (Mew~ 喵呜~，原生真实高清录音，支持三种真实小猫音调随机池)
  static Future<void> playMeow({MeowTone tone = MeowTone.random}) async {
    if (!soundEnabled) return;
    try {
      await sfxPlayer.stop();
      String asset;
      double volume = 0.88;
      switch (tone) {
        case MeowTone.sweet:
          asset = 'audio/meow.wav';
          volume = 0.88;
          break;
        case MeowTone.soft:
          asset = 'audio/meow_soft.wav';
          volume = 0.86;
          break;
        case MeowTone.short:
          asset = 'audio/meow_short.wav';
          volume = 0.90;
          break;
        case MeowTone.random:
          final pool = ['audio/meow.wav', 'audio/meow_soft.wav', 'audio/meow_short.wav'];
          asset = pool[_random.nextInt(pool.length)];
          break;
      }
      await sfxPlayer.play(AssetSource(asset), volume: volume);
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
      await purrPlayer.setVolume(0.80);
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

  /// 剑麻猫抓板磨爪真实撕扯沙沙声 (Scratch - 原生利爪抓挠木质/剑麻清脆质感)
  static Future<void> playScratch() async {
    if (!soundEnabled) return;
    try {
      await sfxPlayer.stop();
      await sfxPlayer.play(AssetSource('audio/scratch.wav'), volume: 0.95);
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

  /// 敲敲猫罐头清脆金属音 (Can Chime)
  static Future<void> playCanChime() async {
    if (!soundEnabled) return;
    SystemSound.play(SystemSoundType.click);
    try {
      await sfxPlayer.stop();
      await sfxPlayer.play(AssetSource('audio/pop.wav'), volume: 0.95);
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// 猫咪小口舔水吧唧音效 (Water Lapping)
  static Future<void> playWaterLap() async {
    if (!soundEnabled) return;
    try {
      await sfxPlayer.stop();
      await sfxPlayer.play(AssetSource('audio/pop.wav'), volume: 0.65);
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  /// 释放音频资源
  static void dispose() {
    _sfxPlayer?.dispose();
    _purrPlayer?.dispose();
    _ambientPlayer?.dispose();
    _sfxPlayer = null;
    _purrPlayer = null;
    _ambientPlayer = null;
    _isPurring = false;
    _ambientMode = 'none';
  }
}
