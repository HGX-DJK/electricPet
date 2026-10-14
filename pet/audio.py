import io
import math
import struct
import wave
import winsound
import threading

class SoundManager:
    """
    轻量级原生音频合成与播放器
    使用纯 Python wave 库在内存中动态合成可爱的 8-bit / 治愈系音效，
    无需任何第三方音频依赖，零延迟、无缺失文件的风险。
    """
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super(SoundManager, cls).__new__(cls)
                cls._instance._init_sounds()
            return cls._instance

    def _init_sounds(self):
        self.muted = False
        self.volume = 0.8
        self._sound_cache = {}
        # 预先生成常用音效缓存
        try:
            self._sound_cache["meow"] = self._generate_meow()
            self._sound_cache["purr"] = self._generate_purr()
            self._sound_cache["chew"] = self._generate_chew()
            self._sound_cache["pop"] = self._generate_pop()
            self._sound_cache["sparkle"] = self._generate_sparkle()
            self._sound_cache["level_up"] = self._generate_levelup()
            self._sound_cache["alarm"] = self._generate_alarm()
            self._sound_cache["click"] = self._generate_click()
            self._sound_cache["snore"] = self._generate_snore()
            self._sound_cache["yawn"] = self._generate_yawn()
            self._sound_cache["dizzy"] = self._generate_dizzy()
            self._sound_cache["dance"] = self._generate_dance()
            self._sound_cache["curious"] = self._generate_curious()
        except Exception as e:
            print(f"[SoundManager] Init sounds warning: {e}")

    def _create_wav_bytes(self, samples, sample_rate=22050):
        buffer = io.BytesIO()
        with wave.open(buffer, 'wb') as wav_file:
            wav_file.setnchannels(1)  # 单声道
            wav_file.setsampwidth(2)  # 16-bit
            wav_file.setframerate(sample_rate)
            raw_data = bytearray()
            for s in samples:
                # 钳制振幅到 16-bit 整数范围
                val = int(max(min(s * 32767.0 * self.volume, 32767.0), -32768.0))
                raw_data.extend(struct.pack('<h', val))
            wav_file.writeframes(raw_data)
        return buffer.getvalue()

    def _generate_meow(self, sample_rate=22050):
        # 可爱上扬猫叫/鸟鸣音效 (~0.28秒)
        duration = 0.28
        total_samples = int(sample_rate * duration)
        samples = []
        for i in range(total_samples):
            t = i / sample_rate
            # 频率从 520Hz 滑升到 880Hz 然后微降到 820Hz
            if t < 0.18:
                freq = 520.0 + (t / 0.18) * 360.0
            else:
                freq = 880.0 - ((t - 0.18) / 0.10) * 80.0
            # 带有轻微颤音
            freq += math.sin(2 * math.pi * 18.0 * t) * 20.0
            # 包络平滑进出
            envelope = math.sin(math.pi * (i / total_samples))
            # 泛音让声音更柔和饱满
            sample = (
                0.7 * math.sin(2 * math.pi * freq * t) +
                0.25 * math.sin(2 * math.pi * freq * 2.0 * t) +
                0.05 * math.sin(2 * math.pi * freq * 3.0 * t)
            ) * envelope
            samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_purr(self, sample_rate=22050):
        # 呼噜呼噜治愈音效 (~0.35秒)
        duration = 0.35
        total_samples = int(sample_rate * duration)
        samples = []
        for i in range(total_samples):
            t = i / sample_rate
            tremolo = (math.sin(2 * math.pi * 26.0 * t) + 1.0) * 0.5
            freq = 110.0 + math.sin(2 * math.pi * 12.0 * t) * 15.0
            envelope = math.sin(math.pi * (i / total_samples)) ** 0.5
            sample = math.sin(2 * math.pi * freq * t) * tremolo * envelope * 0.6
            samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_chew(self, sample_rate=22050):
        # 吧唧咀嚼音效 (两次清脆咬嚼 ~0.2秒)
        duration = 0.22
        total_samples = int(sample_rate * duration)
        samples = []
        for i in range(total_samples):
            t = i / sample_rate
            phase = (t % 0.11) / 0.11
            freq = 420.0 - phase * 180.0
            envelope = (1.0 - phase) ** 2
            sample = (math.sin(2 * math.pi * freq * t) + 0.2 * math.sin(2 * math.pi * freq * 3 * t)) * envelope * 0.7
            samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_pop(self, sample_rate=22050):
        # 肥皂泡泡破裂声/弹跳声 (~0.08秒)
        duration = 0.08
        total_samples = int(sample_rate * duration)
        samples = []
        for i in range(total_samples):
            t = i / sample_rate
            freq = 300.0 + (1.0 - t / duration) * 600.0
            envelope = math.exp(-t * 40.0)
            sample = math.sin(2 * math.pi * freq * t) * envelope * 0.8
            samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_sparkle(self, sample_rate=22050):
        # 闪闪发光音效 (和弦爬音 ~0.3秒)
        notes = [523.25, 659.25, 783.99, 1046.50]  # C5, E5, G5, C6
        duration_per_note = 0.07
        samples = []
        for note_idx, freq in enumerate(notes):
            n_samples = int(sample_rate * duration_per_note)
            for i in range(n_samples):
                t = i / sample_rate
                envelope = (1.0 - (i / n_samples)) ** 1.5
                sample = (math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(2 * math.pi * freq * 2 * t)) * envelope * 0.5
                samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_levelup(self, sample_rate=22050):
        # 升级祝贺音效 (欢快大三和弦进阶 ~0.45秒)
        notes = [440.0, 554.37, 659.25, 880.0]  # A4, C#5, E5, A5
        duration_per_note = 0.11
        samples = []
        for freq in notes:
            n_samples = int(sample_rate * duration_per_note)
            for i in range(n_samples):
                t = i / sample_rate
                envelope = math.sin(math.pi * (i / n_samples))
                sample = (math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(2 * math.pi * freq * 2 * t)) * envelope * 0.6
                samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_alarm(self, sample_rate=22050):
        # 提示闹钟音效 (双声叮咚 ~0.4秒)
        notes = [783.99, 1046.50]  # G5, C6
        duration_per_note = 0.20
        samples = []
        for freq in notes:
            n_samples = int(sample_rate * duration_per_note)
            for i in range(n_samples):
                t = i / sample_rate
                envelope = math.exp(-t * 8.0)
                sample = (math.sin(2 * math.pi * freq * t) + 0.2 * math.sin(2 * math.pi * freq * 3 * t)) * envelope * 0.7
                samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_click(self, sample_rate=22050):
        # 轻微清脆按钮点击声 (~0.03秒)
        duration = 0.03
        total_samples = int(sample_rate * duration)
        samples = []
        for i in range(total_samples):
            t = i / sample_rate
            freq = 900.0 - (t / duration) * 400.0
            envelope = (1.0 - t / duration) ** 2
            sample = math.sin(2 * math.pi * freq * t) * envelope * 0.5
            samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_snore(self, sample_rate=22050):
        # 呼呼睡觉声 (~0.4秒)
        duration = 0.4
        total_samples = int(sample_rate * duration)
        samples = []
        for i in range(total_samples):
            t = i / sample_rate
            freq = 130.0 + math.sin(2 * math.pi * 3.0 * t) * 20.0
            envelope = math.sin(math.pi * (i / total_samples)) * 0.4
            sample = math.sin(2 * math.pi * freq * t) * envelope
            samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_yawn(self, sample_rate=22050):
        # 伸懒腰打哈欠音效 (柔和下滑 ~0.42秒)
        duration = 0.42
        total_samples = int(sample_rate * duration)
        samples = []
        for i in range(total_samples):
            t = i / sample_rate
            freq = 460.0 - (t / duration) * 180.0 + math.sin(2 * math.pi * 8.0 * t) * 15.0
            envelope = math.sin(math.pi * (i / total_samples)) * 0.55
            sample = (math.sin(2 * math.pi * freq * t) + 0.2 * math.sin(2 * math.pi * freq * 2.0 * t)) * envelope
            samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_dizzy(self, sample_rate=22050):
        # 眩晕弹簧音效 (上下摆动频率 ~0.38秒)
        duration = 0.38
        total_samples = int(sample_rate * duration)
        samples = []
        for i in range(total_samples):
            t = i / sample_rate
            freq = 380.0 + math.sin(2 * math.pi * 14.0 * t) * 160.0
            envelope = (1.0 - t / duration) * 0.6
            sample = math.sin(2 * math.pi * freq * t) * envelope
            samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_dance(self, sample_rate=22050):
        # 欢快律动蹦跳音效 (~0.36秒)
        notes = [523.25, 659.25, 587.33, 783.99]
        dur_note = 0.09
        samples = []
        for freq in notes:
            n_samples = int(sample_rate * dur_note)
            for i in range(n_samples):
                t = i / sample_rate
                envelope = (1.0 - (i / n_samples)) ** 1.2
                sample = (math.sin(2 * math.pi * freq * t) + 0.25 * math.sin(2 * math.pi * freq * 2 * t)) * envelope * 0.6
                samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def _generate_curious(self, sample_rate=22050):
        # 歪头好奇音效 (上扬俏皮双声短鸣 ~0.24秒)
        duration = 0.24
        total_samples = int(sample_rate * duration)
        samples = []
        for i in range(total_samples):
            t = i / sample_rate
            freq = 520.0 + (t / duration) * 440.0
            envelope = math.sin(math.pi * (i / total_samples)) * 0.55
            sample = math.sin(2 * math.pi * freq * t) * envelope
            samples.append(sample)
        return self._create_wav_bytes(samples, sample_rate)

    def play(self, sound_name):
        """异步播放指定音效"""
        if self.muted:
            return
        wav_bytes = self._sound_cache.get(sound_name)
        if not wav_bytes:
            return
        def _worker():
            try:
                winsound.PlaySound(wav_bytes, winsound.SND_MEMORY | winsound.SND_ASYNC)
            except Exception:
                pass
        threading.Thread(target=_worker, daemon=True).start()

    def toggle_mute(self):
        self.muted = not self.muted
        return self.muted

sound_manager = SoundManager()
