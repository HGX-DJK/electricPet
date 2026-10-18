import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 真实太阳天文算法与四季时角计算服务 (NOAA Solar Astronomical Engine)
/// 基于公历日期计算真实太阳赤纬角、时角与准确日升日落时刻，并提供 24 小时连续 Color.lerp 平滑光影渐变
class SolarService {
  // 基准参考纬度：31.5°N (代表性温带/亚热带平原纬度，无需申请 GPS 隐私权限即可获得极高真实度)
  static const double defaultLatitude = 31.5;

  /// 计算公历一年中的第几天 (Day of Year 1..366)
  static int dayOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    return date.difference(startOfYear).inDays + 1;
  }

  /// 计算指定日期的真实太阳日出、日落与正午时刻 (以小数小时表示，例如 6.5 = 06:30)
  static SolarTimes calculateSolarTimes(DateTime date, {double latitude = defaultLatitude}) {
    final doy = dayOfYear(date);

    // 太阳赤纬角 (Solar Declination delta): 范围约 -23.44° (冬至) ~ +23.44° (夏至)
    final gamma = 2 * math.pi * (doy + 10) / 365.25;
    final declinationDeg = -23.44 * math.cos(gamma);
    final declinationRad = declinationDeg * math.pi / 180.0;
    final latRad = latitude * math.pi / 180.0;

    // 考虑大气折射与太阳视半径 (-0.833° 的地平视偏差)
    const zenithRad = 90.833 * math.pi / 180.0;
    final cosH0 = (math.cos(zenithRad) - math.sin(latRad) * math.sin(declinationRad)) /
        (math.cos(latRad) * math.cos(declinationRad));

    final clampedCosH0 = cosH0.clamp(-1.0, 1.0);
    final hourAngleDeg = math.acos(clampedCosH0) * 180.0 / math.pi;
    final halfDayHours = hourAngleDeg / 15.0; // 太阳时角每小时走 15 度

    // 太阳真平正午基准
    const solarNoon = 12.15;
    final sunrise = (solarNoon - halfDayHours).clamp(4.5, 8.0);
    final sunset = (solarNoon + halfDayHours).clamp(16.5, 20.2);

    return SolarTimes(
      sunriseHours: sunrise,
      sunsetHours: sunset,
      solarNoonHours: solarNoon,
      dayLengthHours: halfDayHours * 2,
    );
  }

  /// 将小数小时转换为标准 "HH:mm"
  static String formatHours(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round().clamp(0, 59);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// 24 小时连续基于分钟的 Color.lerp 平滑光影流转
  /// manualMode: -1: 自动真实自然天文, 0: 破晓晨曦, 1: 澄澈晴空, 2: 落日晚霞, 3: 静谧星夜
  static SkyTheme getSkyTheme({
    int manualMode = -1,
    DateTime? customTime,
  }) {
    final now = customTime ?? DateTime.now();
    final solar = calculateSolarTimes(now);
    final sunrise = solar.sunriseHours;
    final sunset = solar.sunsetHours;

    // 手动覆盖光影模式
    if (manualMode == 0) {
      return SkyTheme(
        name: '破晓晨曦',
        icon: '🌅',
        colors: const [Color(0xFFFDE8E8), Color(0xFFFEF3C7), Color(0xFFF0FDF4)],
        isNight: false,
        greeting: '破晓微光初现，万物初醒，波可伸个大懒腰陪你迎接第一缕晨曦！🌅✨',
        phaseName: '破晓晨曦',
        solarTimes: solar,
        isManual: true,
      );
    } else if (manualMode == 1) {
      return SkyTheme(
        name: '澄澈晴空',
        icon: '☀️',
        colors: const [Color(0xFFE0F2FE), Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
        isNight: false,
        greeting: '阳光洒满木地板，微风轻拂，最适合和小猫在地垫上打滚晒太阳啦~ ☀️🍃',
        phaseName: '澄澈晴空',
        solarTimes: solar,
        isManual: true,
      );
    } else if (manualMode == 2) {
      return SkyTheme(
        name: '落日晚霞',
        icon: '🌇',
        colors: const [Color(0xFFFFF1F2), Color(0xFFFEF3C7), Color(0xFFF3E8FF)],
        isNight: false,
        greeting: '落日熔金，晚霞漫天，主人今天辛苦啦，波可等你回家好久啦！🌇💕',
        phaseName: '落日晚霞',
        solarTimes: solar,
        isManual: true,
      );
    } else if (manualMode == 3) {
      return SkyTheme(
        name: '静谧星夜',
        icon: '🌙',
        colors: const [Color(0xFF0F0E26), Color(0xFF18153E), Color(0xFF221A48)],
        isNight: true,
        greeting: '夜深露重，小星星都眨眼啦，小夜灯暖暖的，晚安好梦哦主人~ 💤🌙',
        phaseName: '静谧星夜',
        solarTimes: solar,
        isManual: true,
      );
    }

    // 真实天文流转 (随当前分钟连续平滑插值)
    final nowHours = now.hour + now.minute / 60.0 + now.second / 3600.0;

    // 根据动态日升日落时刻划分光影阶段
    final tNightDeep = (sunrise - 1.2).clamp(3.5, 6.0); // 深度黑夜 (约 04:30)
    final tDawnStart = (sunrise - 0.6).clamp(4.0, 7.0); // 晨光微熹，天际破晓 (约 05:30)
    final tSunrise = sunrise; // 日出金光喷薄
    final tMorning = sunrise + 0.8; // 晨光饱满
    const tNoon = 12.0; // 正午澄澈
    final tAfternoon = sunset - 1.5; // 午后渐暖
    final tGoldenHour = sunset - 0.7; // 落日熔金
    final tSunset = sunset; // 夕阳沉落晚霞紫
    final tDusk = sunset + 0.5; // 暮色四合
    final tNightFall = sunset + 1.1; // 夜幕完全降临

    // 精选天文级连续渐变色标
    const cDeepNight = [Color(0xFF0A081D), Color(0xFF130E30), Color(0xFF1E1644)];
    const cDawn = [Color(0xFF241C48), Color(0xFF5B3C68), Color(0xFFC48B9F)];
    const cSunrise = [Color(0xFFFFEDD5), Color(0xFFFEF3C7), Color(0xFFE0F2FE)];
    const cMorning = [Color(0xFFFFFBEB), Color(0xFFF0FDF4), Color(0xFFF8FAFC)];
    const cNoon = [Color(0xFFE0F2FE), Color(0xFFF0FDF4), Color(0xFFF8FAFC)];
    const cAfternoon = [Color(0xFFEFF6FF), Color(0xFFFEF3C7), Color(0xFFFDF2F8)];
    const cGoldenHour = [Color(0xFFFFF1F2), Color(0xFFFED7AA), Color(0xFFFEF08A)];
    const cSunset = [Color(0xFFFCE7F3), Color(0xFFF472B6), Color(0xFF818CF8)];
    const cDusk = [Color(0xFF24153B), Color(0xFF372054), Color(0xFF1E1742)];
    const cNight = [Color(0xFF0F0E26), Color(0xFF18153E), Color(0xFF221A48)];

    List<Color> gradientColors;
    bool isNight;
    String phaseName;
    String icon;
    String greeting;

    if (nowHours < tNightDeep) {
      gradientColors = _lerpGradients(cNight, cDeepNight, nowHours / tNightDeep);
      isNight = true;
      phaseName = '静谧星夜';
      icon = '🌙';
      greeting = '夜深啦，小星星都眨眼了，主人早点休息哦，波可守着您~ 💤🌙';
    } else if (nowHours < tDawnStart) {
      final ratio = (nowHours - tNightDeep) / (tDawnStart - tNightDeep);
      gradientColors = _lerpGradients(cDeepNight, cDawn, ratio);
      isNight = true;
      phaseName = '破晓前夕';
      icon = '🌌';
      greeting = '东方渐露微白，世界还在睡梦中，波可悄悄舔舔主人的指尖~ ✨🐾';
    } else if (nowHours < tSunrise) {
      final ratio = (nowHours - tDawnStart) / (tSunrise - tDawnStart);
      gradientColors = _lerpGradients(cDawn, cSunrise, ratio);
      isNight = false;
      phaseName = '破晓晨曦';
      icon = '🌅';
      greeting = '晨光熹微，天际染上金粉色，早安主人！新的一天开始啦~ 🌅🐾';
    } else if (nowHours < tMorning) {
      final ratio = (nowHours - tSunrise) / (tMorning - tSunrise);
      gradientColors = _lerpGradients(cSunrise, cMorning, ratio);
      isNight = false;
      phaseName = '晨曦初照';
      icon = '☀️';
      greeting = '早安主人！朝阳洒满房间，今天也要元气满满哦！☀️🐱';
    } else if (nowHours < tNoon) {
      final ratio = (nowHours - tMorning) / (tNoon - tMorning);
      gradientColors = _lerpGradients(cMorning, cNoon, ratio);
      isNight = false;
      phaseName = '澄澈晴空';
      icon = '⛅';
      greeting = '微风轻拂，蓝天透亮，波可伸个大懒腰，陪主人专注前行~ ☕✨';
    } else if (nowHours < tAfternoon) {
      final ratio = (nowHours - tNoon) / (tAfternoon - tNoon);
      gradientColors = _lerpGradients(cNoon, cAfternoon, ratio);
      isNight = false;
      phaseName = '午后微风';
      icon = '☕';
      greeting = '午后的阳光暖洋洋的，适合在软垫上抱着毛线球打个小盹~ 🧶🐾';
    } else if (nowHours < tGoldenHour) {
      final ratio = (nowHours - tAfternoon) / (tGoldenHour - tAfternoon);
      gradientColors = _lerpGradients(cAfternoon, cGoldenHour, ratio);
      isNight = false;
      phaseName = '落日熔金';
      icon = '🌇';
      greeting = '太阳开始落山啦，光芒染上琥珀金，一天中最温柔的时刻到了~ 🌇✨';
    } else if (nowHours < tSunset) {
      final ratio = (nowHours - tGoldenHour) / (tSunset - tGoldenHour);
      gradientColors = _lerpGradients(cGoldenHour, cSunset, ratio);
      isNight = false;
      phaseName = '落日晚霞';
      icon = '🌇';
      greeting = '夕阳染上浪漫的粉紫色啦，主人今天辛苦啦，欢迎回家！🌇💕';
    } else if (nowHours < tDusk) {
      final ratio = (nowHours - tSunset) / (tDusk - tSunset);
      gradientColors = _lerpGradients(cSunset, cDusk, ratio);
      isNight = true;
      phaseName = '暮色四合';
      icon = '🌆';
      greeting = '暮霭沉沉，天色渐暗，第一颗星星悄悄亮起来啦~ 🌟🐾';
    } else if (nowHours < tNightFall) {
      final ratio = (nowHours - tDusk) / (tNightFall - tDusk);
      gradientColors = _lerpGradients(cDusk, cNight, ratio);
      isNight = true;
      phaseName = '初夜星垂';
      icon = '🌙';
      greeting = '夜幕完全降临啦，点亮小夜灯，波可陪着您享受安谧夜晚~ 💡🌙';
    } else {
      gradientColors = cNight;
      isNight = true;
      phaseName = '静谧星夜';
      icon = '🌙';
      greeting = '夜深啦，小星星都眨眼了，主人早点休息哦，波可守着您~ 💤🌙';
    }

    return SkyTheme(
      name: phaseName,
      icon: icon,
      colors: gradientColors,
      isNight: isNight,
      greeting: greeting,
      phaseName: phaseName,
      solarTimes: solar,
      isManual: false,
    );
  }

  static List<Color> _lerpGradients(List<Color> a, List<Color> b, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    return [
      Color.lerp(a[0], b[0], clampedT) ?? a[0],
      Color.lerp(a[1], b[1], clampedT) ?? a[1],
      Color.lerp(a[2], b[2], clampedT) ?? a[2],
    ];
  }
}

/// 某日日升日落天文时刻模型
class SolarTimes {
  final double sunriseHours;
  final double sunsetHours;
  final double solarNoonHours;
  final double dayLengthHours;

  const SolarTimes({
    required this.sunriseHours,
    required this.sunsetHours,
    required this.solarNoonHours,
    required this.dayLengthHours,
  });

  String get sunriseStr => SolarService.formatHours(sunriseHours);
  String get sunsetStr => SolarService.formatHours(sunsetHours);
}

/// 某时刻天空光影主题数据
class SkyTheme {
  final String name;
  final String icon;
  final List<Color> colors;
  final bool isNight;
  final String greeting;
  final String phaseName;
  final SolarTimes solarTimes;
  final bool isManual;

  const SkyTheme({
    required this.name,
    required this.icon,
    required this.colors,
    required this.isNight,
    required this.greeting,
    required this.phaseName,
    required this.solarTimes,
    required this.isManual,
  });
}
