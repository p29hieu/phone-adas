import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/domain/lead_departure.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  DateTime at(double s) => t0.add(Duration(milliseconds: (s * 1000).round()));

  test('fires once when lead departs after a settled stop', () {
    final d = LeadDepartureDetector();
    // Stopped behind a lead at 8 m for 3 s.
    var fired = false;
    for (var i = 0; i <= 30; i++) {
      fired = d.update(egoSpeedKmh: 0, leadDistanceM: 8, ts: at(i * 0.1));
      expect(fired, isFalse);
    }
    expect(d.isArmed, isTrue);
    // Lead pulls away: 9, 10, 11.5 m -> delta over 3 m triggers.
    expect(d.update(egoSpeedKmh: 0, leadDistanceM: 9, ts: at(3.1)), isFalse);
    expect(d.update(egoSpeedKmh: 0, leadDistanceM: 10, ts: at(3.2)), isFalse);
    expect(d.update(egoSpeedKmh: 0, leadDistanceM: 11.5, ts: at(3.3)), isTrue);
    // Only once.
    expect(d.update(egoSpeedKmh: 0, leadDistanceM: 15, ts: at(3.4)), isFalse);
  });

  test('does not arm while moving or without a close lead', () {
    final d = LeadDepartureDetector();
    for (var i = 0; i <= 30; i++) {
      d.update(egoSpeedKmh: 30, leadDistanceM: 8, ts: at(i * 0.1));
    }
    expect(d.isArmed, isFalse);
    final d2 = LeadDepartureDetector();
    for (var i = 0; i <= 30; i++) {
      d2.update(egoSpeedKmh: 0, leadDistanceM: 60, ts: at(i * 0.1));
    }
    expect(d2.isArmed, isFalse);
  });

  test('resets when ego moves again', () {
    final d = LeadDepartureDetector();
    for (var i = 0; i <= 30; i++) {
      d.update(egoSpeedKmh: 0, leadDistanceM: 8, ts: at(i * 0.1));
    }
    expect(d.isArmed, isTrue);
    d.update(egoSpeedKmh: 10, leadDistanceM: 9, ts: at(3.1));
    expect(d.isArmed, isFalse);
  });
}
