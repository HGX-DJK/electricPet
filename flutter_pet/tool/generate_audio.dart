// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

Uint8List createWav(List<double> samples, int sampleRate) {
  final numSamples = samples.length;
  final dataLength = numSamples * 2;
  final buffer = Uint8List(44 + dataLength);
  final byteData = ByteData.sublistView(buffer);

  // "RIFF"
  buffer.setRange(0, 4, [0x52, 0x49, 0x46, 0x46]);
  byteData.setUint32(4, 36 + dataLength, Endian.little);
  // "WAVE"
  buffer.setRange(8, 12, [0x57, 0x41, 0x56, 0x45]);
  // "fmt "
  buffer.setRange(12, 16, [0x66, 0x6D, 0x74, 0x20]);
  byteData.setUint32(16, 16, Endian.little); // 16 = PCM chunk size
  byteData.setUint16(20, 1, Endian.little);  // 1 = PCM format
  byteData.setUint16(22, 1, Endian.little);  // 1 channel (mono)
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
  byteData.setUint16(32, 2, Endian.little);  // Block align
  byteData.setUint16(34, 16, Endian.little); // 16 bits per sample
  // "data"
  buffer.setRange(36, 40, [0x64, 0x61, 0x74, 0x61]);
  byteData.setUint32(40, dataLength, Endian.little);

  // PCM 16-bit signed integer samples
  int offset = 44;
  for (int i = 0; i < numSamples; i++) {
    final s = samples[i].clamp(-1.0, 1.0);
    final val = (s * 32767.0).round();
    byteData.setInt16(offset, val, Endian.little);
    offset += 2;
  }

  return buffer;
}

void main() {
  const sampleRate = 22050;
  final outDir = Directory('assets/audio');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  // 1. meow.wav: 软萌小猫“喵呜~”叫声 (基频 680Hz 滑向 850Hz 再滑降到 450Hz，泛音丰满)
  {
    const duration = 0.62;
    final totalSamples = (duration * sampleRate).toInt();
    final samples = List<double>.filled(totalSamples, 0.0);
    double phase = 0.0;

    for (int i = 0; i < totalSamples; i++) {
      final t = i / totalSamples;
      // 频率滑音曲线：前 35% 爬升，后 65% 柔和滑降
      double freq;
      if (t < 0.32) {
        freq = 640.0 + (t / 0.32) * 220.0; // 640 -> 860 Hz
      } else {
        final dt = (t - 0.32) / 0.68;
        freq = 860.0 - dt * 420.0; // 860 -> 440 Hz
      }

      // 包络 (Attack - Decay)
      double amp;
      if (t < 0.12) {
        amp = t / 0.12;
      } else if (t < 0.60) {
        amp = 1.0 - (t - 0.12) * 0.3;
      } else {
        amp = 0.85 * (1.0 - (t - 0.60) / 0.40);
      }

      // 猫叫声学谐波：基音 + 二次谐波 (更富鼻腔萌音) + 三次谐波
      final deltaPhase = (2.0 * math.pi * freq) / sampleRate;
      phase += deltaPhase;
      final val = 0.62 * math.sin(phase) +
                  0.30 * math.sin(2.0 * phase) +
                  0.08 * math.sin(3.0 * phase);

      // 微颤颤音 Vibrato
      final vibrato = 1.0 + 0.04 * math.sin(2.0 * math.pi * 7.5 * (i / sampleRate));

      samples[i] = val * amp * vibrato * 0.85;
    }

    final bytes = createWav(samples, sampleRate);
    File('assets/audio/meow.wav').writeAsBytesSync(bytes);
    print('Generated assets/audio/meow.wav (${bytes.length} bytes)');
  }

  // 2. purr.wav: 治愈呼噜噜白噪音 ASMR (低频 28Hz~45Hz 颤动喉音 + 呼吸引导)
  {
    const duration = 2.4;
    final totalSamples = (duration * sampleRate).toInt();
    final samples = List<double>.filled(totalSamples, 0.0);
    final rand = math.Random(42);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      // 猫呼噜基频：28Hz 主波 + 56Hz 谐波
      final throatPulse = math.sin(2.0 * math.pi * 28.0 * t);
      final throatHarmonic = math.sin(2.0 * math.pi * 56.0 * t);
      
      // 呼吸起伏周期 (每 1.2 秒一个呼噜呼吸包络)
      final breathCycle = 0.5 + 0.5 * math.sin(2.0 * math.pi * (1.0 / 1.2) * t);
      
      // 轻微气流白噪音
      final noise = (rand.nextDouble() * 2.0 - 1.0) * 0.15;

      final composite = (throatPulse * 0.55 + throatHarmonic * 0.30 + noise) * (0.4 + 0.6 * breathCycle);
      samples[i] = composite * 0.75;
    }

    final bytes = createWav(samples, sampleRate);
    File('assets/audio/purr.wav').writeAsBytesSync(bytes);
    print('Generated assets/audio/purr.wav (${bytes.length} bytes)');
  }

  // 3. click.wav: 家具小夜灯清脆“啪嗒”开关机械音
  {
    const duration = 0.075;
    final totalSamples = (duration * sampleRate).toInt();
    final samples = List<double>.filled(totalSamples, 0.0);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      // 双重机械弹簧快门冲击 (前击 + 回弹微响)
      final decay1 = math.exp(-t * 120.0);
      final pulse1 = math.sin(2.0 * math.pi * 2100.0 * t) * decay1;
      
      double pulse2 = 0.0;
      if (t > 0.015) {
        final t2 = t - 0.015;
        final decay2 = math.exp(-t2 * 90.0);
        pulse2 = math.sin(2.0 * math.pi * 1400.0 * t2) * decay2 * 0.7;
      }

      samples[i] = (pulse1 + pulse2) * 0.90;
    }

    final bytes = createWav(samples, sampleRate);
    File('assets/audio/click.wav').writeAsBytesSync(bytes);
    print('Generated assets/audio/click.wav (${bytes.length} bytes)');
  }

  // 4. scratch.wav: 剑麻猫抓板磨爪沙沙声 (木质绳索连续摩擦)
  {
    const duration = 0.28;
    final totalSamples = (duration * sampleRate).toInt();
    final samples = List<double>.filled(totalSamples, 0.0);
    final rand = math.Random(101);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / duration;
      // 3 次连续快速抓擦 burst
      final burst = (math.sin(t * 3.0 * math.pi * 2.0).abs());
      final noise = (rand.nextDouble() * 2.0 - 1.0);
      final decay = (1.0 - t * 0.6);
      samples[i] = noise * burst * decay * 0.70;
    }

    final bytes = createWav(samples, sampleRate);
    File('assets/audio/scratch.wav').writeAsBytesSync(bytes);
    print('Generated assets/audio/scratch.wav (${bytes.length} bytes)');
  }

  // 5. pop.wav: 小鲜鱼弹射与毛线球轻击“啵”音
  {
    const duration = 0.11;
    final totalSamples = (duration * sampleRate).toInt();
    final samples = List<double>.filled(totalSamples, 0.0);
    double phase = 0.0;

    for (int i = 0; i < totalSamples; i++) {
      final t = i / totalSamples;
      final freq = 1100.0 - t * 750.0; // 1100 -> 350 Hz 快速抛物线下滑
      phase += (2.0 * math.pi * freq) / sampleRate;
      final decay = math.exp(-t * 22.0);
      samples[i] = math.sin(phase) * decay * 0.95;
    }

    final bytes = createWav(samples, sampleRate);
    File('assets/audio/pop.wav').writeAsBytesSync(bytes);
    print('Generated assets/audio/pop.wav (${bytes.length} bytes)');
  }

  // 6. shutter.wav: 拍立得照片快门咔嚓音
  {
    const duration = 0.16;
    final totalSamples = (duration * sampleRate).toInt();
    final samples = List<double>.filled(totalSamples, 0.0);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final click1 = (t < 0.03) ? math.sin(2.0 * math.pi * 3200.0 * t) * math.exp(-t * 220.0) : 0.0;
      final click2 = (t >= 0.04 && t < 0.10) ? math.sin(2.0 * math.pi * 2400.0 * (t - 0.04)) * math.exp(-(t - 0.04) * 160.0) * 0.8 : 0.0;
      samples[i] = (click1 + click2) * 0.85;
    }

    final bytes = createWav(samples, sampleRate);
    File('assets/audio/shutter.wav').writeAsBytesSync(bytes);
    print('Generated assets/audio/shutter.wav (${bytes.length} bytes)');
  }
}
