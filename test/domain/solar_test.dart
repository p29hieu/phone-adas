import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/domain/solar.dart';

void main() {
  // Hanoi: 21.03 N, 105.85 E (UTC+7).
  const lat = 21.03, lon = 105.85;

  test('noon in Hanoi is daytime, midnight is not', () {
    // 2026-03-20 12:00 local = 05:00 UTC.
    expect(Solar.isDaytime(DateTime.utc(2026, 3, 20, 5), lat, lon), isTrue);
    // 2026-03-20 00:30 local = 17:30 UTC previous day.
    expect(Solar.isDaytime(DateTime.utc(2026, 3, 19, 17, 30), lat, lon), isFalse);
  });

  test('equinox sunrise/sunset near 6:00/18:00 local time', () {
    final t = Solar.sunTimesUtc(DateTime.utc(2026, 3, 20), lat, lon);
    expect(t, isNotNull);
    final sunriseLocal = t!.sunrise.add(const Duration(hours: 7));
    final sunsetLocal = t.sunset.add(const Duration(hours: 7));
    expect(sunriseLocal.hour, inInclusiveRange(5, 7));
    expect(sunsetLocal.hour, inInclusiveRange(17, 19));
    expect(t.sunrise.isBefore(t.sunset), isTrue);
  });

  test('polar night returns null', () {
    expect(Solar.sunTimesUtc(DateTime.utc(2026, 12, 21), 80, 0), isNull);
  });
}
