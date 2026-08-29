import 'dart:math' as math;

/// Legal minimum following distances — Thông tư 38/2024/TT-BGTVT, Điều 11.
///
/// Values apply to dry roads in normal weather. Below 60 km/h the law
/// requires an "appropriate" gap with no fixed number, so
/// [legalMinimumMeters] returns 0 there and [recommendedMeters] falls back
/// to a 2-second rule.
class SafeDistance {
  const SafeDistance._();

  static double legalMinimumMeters(double speedKmh) {
    if (speedKmh < 60) return 0;
    if (speedKmh == 60) return 35;
    if (speedKmh <= 80) return 55;
    if (speedKmh <= 100) return 70;
    return 100;
  }

  /// Practical target gap: the legal minimum, or a 2-second gap when the
  /// law gives no number (and never less than the 2-second gap above 60).
  static double recommendedMeters(double speedKmh) {
    final twoSecondGap = speedKmh / 3.6 * 2.0;
    return math.max(legalMinimumMeters(speedKmh), twoSecondGap);
  }
}
