import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/domain/lead_departure.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  DateTime at(double s) => t0.add(Duration(milliseconds: (s * 1000).round()));

  test('fires once when the departure is sustained', () {
    final d = LeadDepartureDetector();
    // Stopped behind a lead at 8 m for 3 s.
    var fired = false;
    for (var i = 0; i <= 30; i++) {
      fired = d.update(egoSpeedKmh: 0, leadDistanceM: 8, ts: at(i * 0.1));
      expect(fired, isFalse);
    }
    expect(d.isArmed, isTrue);
    // Lead pulls away and keeps going; the median rise must hold for the
    // 1.2 s confirmation window before the event fires exactly once.
    var t = 3.1;
    fired = false;
    for (var dist = 9.0; dist < 30 && !fired; dist += 0.8, t += 0.1) {
      fired = d.update(egoSpeedKmh: 0, leadDistanceM: dist, ts: at(t));
    }
    expect(fired, isTrue);
    expect(d.update(egoSpeedKmh: 0, leadDistanceM: 35, ts: at(t + 0.1)),
        isFalse); // only once
  });

  test('engine-vibration jitter while stopped does not fire', () {
    final d = LeadDepartureDetector();
    for (var i = 0; i <= 30; i++) {
      d.update(egoSpeedKmh: 0, leadDistanceM: 8, ts: at(i * 0.1));
    }
    expect(d.isArmed, isTrue);
    // Noisy readings spiking up to +4.5 m for single frames.
    for (var i = 0; i <= 40; i++) {
      final noisy = 8.0 + (i % 4 == 0 ? 4.5 : (i % 3 == 0 ? -0.6 : 0.3));
      expect(
        d.update(egoSpeedKmh: 0, leadDistanceM: noisy, ts: at(3.1 + i * 0.1)),
        isFalse,
      );
    }
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
