import 'dart:math' as math;

/// Sunrise/sunset via the NOAA solar-position approximation (±3 min).
///
/// Fully offline — used to switch the HUD theme by real daylight at the
/// vehicle's GPS position instead of fixed clock hours.
class Solar {
  const Solar._();

  static double _rad(double deg) => deg * math.pi / 180;
  static double _deg(double rad) => rad * 180 / math.pi;

  /// Sunrise and sunset as UTC instants for the UTC calendar date of
  /// [dateUtc] at the given position. Returns null in polar day/night.
  static ({DateTime sunrise, DateTime sunset})? sunTimesUtc(
    DateTime dateUtc,
    double latDeg,
    double lonDeg,
  ) {
    final startOfDay = DateTime.utc(dateUtc.year, dateUtc.month, dateUtc.day);
    final dayOfYear = startOfDay.difference(DateTime.utc(dateUtc.year)).inDays + 1;

    final gamma = 2 * math.pi / 365 * (dayOfYear - 1 + (12 - 12) / 24);
    final eqTime = 229.18 *
        (0.000075 +
            0.001868 * math.cos(gamma) -
            0.032077 * math.sin(gamma) -
            0.014615 * math.cos(2 * gamma) -
            0.040849 * math.sin(2 * gamma));
    final decl = 0.006918 -
        0.399912 * math.cos(gamma) +
        0.070257 * math.sin(gamma) -
        0.006758 * math.cos(2 * gamma) +
        0.000907 * math.sin(2 * gamma) -
        0.002697 * math.cos(3 * gamma) +
        0.00148 * math.sin(3 * gamma);

    final lat = _rad(latDeg);
    // 90.833° accounts for atmospheric refraction and the solar diameter.
    final cosHa = (math.cos(_rad(90.833)) / (math.cos(lat) * math.cos(decl))) -
        math.tan(lat) * math.tan(decl);
    if (cosHa < -1 || cosHa > 1) return null;
    final haDeg = _deg(math.acos(cosHa));

    final sunriseMin = 720 - 4 * (lonDeg + haDeg) - eqTime;
    final sunsetMin = 720 - 4 * (lonDeg - haDeg) - eqTime;
    return (
      sunrise: startOfDay.add(Duration(milliseconds: (sunriseMin * 60000).round())),
      sunset: startOfDay.add(Duration(milliseconds: (sunsetMin * 60000).round())),
    );
  }

  /// Whether the sun is up at [utcNow] for the given position.
  /// Falls back to true (light theme) in polar edge cases.
  static bool isDaytime(DateTime utcNow, double latDeg, double lonDeg) {
    // Check against the sun times of the surrounding UTC dates, because a
    // local day in eastern longitudes maps to sunrise on the previous UTC date.
    for (var offset = -1; offset <= 1; offset++) {
      final t = Solar.sunTimesUtc(
        utcNow.add(Duration(days: offset)),
        latDeg,
        lonDeg,
      );
      if (t == null) return true;
      if (!utcNow.isBefore(t.sunrise) && utcNow.isBefore(t.sunset)) return true;
    }
    return false;
  }
}
