import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/domain/collision_warning.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1, 0, 0, 0);
  DateTime at(double seconds) =>
      t0.add(Duration(milliseconds: (seconds * 1000).round()));

  group('CollisionMonitor gap warning (hysteresis)', () {
    test('fires only after sustained breach of 2 s', () {
      final m = CollisionMonitor();
      // 70 km/h -> legal gap 55 m. Hold distance at 40 m.
      var alert = AdasAlert.none;
      for (var i = 0; i <= 25; i++) {
        alert = m.update(distanceM: 40, egoSpeedKmh: 70, ts: at(i * 0.1));
      }
      // 2.5 s elapsed, breach was continuous -> active.
      expect(alert, AdasAlert.keepDistance);
    });

    test('does not fire on a brief cut-in shorter than 2 s', () {
      final m = CollisionMonitor();
      var alert = AdasAlert.none;
      for (var i = 0; i <= 10; i++) {
        alert = m.update(distanceM: 40, egoSpeedKmh: 70, ts: at(i * 0.1));
      }
      expect(alert, AdasAlert.none); // only 1.0 s so far
      alert = m.update(distanceM: 60, egoSpeedKmh: 70, ts: at(1.2));
      expect(alert, AdasAlert.none); // breach ended, timer reset
    });

    test('releases only above gap * 1.1', () {
      final m = CollisionMonitor();
      var alert = AdasAlert.none;
      for (var i = 0; i <= 25; i++) {
        alert = m.update(distanceM: 40, egoSpeedKmh: 70, ts: at(i * 0.1));
      }
      expect(alert, AdasAlert.keepDistance);
      // 56 m is above 55 but below 60.5 -> still active (hysteresis).
      alert = m.update(distanceM: 56, egoSpeedKmh: 70, ts: at(2.6));
      expect(alert, AdasAlert.keepDistance);
      alert = m.update(distanceM: 62, egoSpeedKmh: 70, ts: at(2.7));
      expect(alert, AdasAlert.none);
    });
  });

  group('CollisionMonitor TTC', () {
    test('measured closing speed (radar) triggers with no EMA warm-up', () {
      final m = CollisionMonitor();
      // Single radar reading: 20 m gap closing at 10 m/s -> TTC 2 s.
      final alert = m.update(
        distanceM: 20,
        egoSpeedKmh: 50,
        ts: at(0),
        measuredClosingMps: 10,
      );
      expect(alert, AdasAlert.collision);
      // 10 m at 10 m/s -> TTC 1 s -> critical.
      final critical = m.update(
        distanceM: 10,
        egoSpeedKmh: 50,
        ts: at(0.1),
        measuredClosingMps: 10,
      );
      expect(critical, AdasAlert.collisionCritical);
    });

    test('closing fast triggers collision immediately, no 2 s delay', () {
      final m = CollisionMonitor();
      // Approach at 10 m/s: 40 m -> 30 m over 1 s, TTC ~= 3 s then shrinking.
      var alert = AdasAlert.none;
      var d = 40.0;
      for (var i = 0; i <= 25 && d > 5; i++) {
        alert = m.update(distanceM: d, egoSpeedKmh: 50, ts: at(i * 0.1));
        d -= 1.0; // 10 m/s closing
        if (alert != AdasAlert.none) break;
      }
      expect(
        alert == AdasAlert.collision || alert == AdasAlert.collisionCritical,
        isTrue,
      );
    });

    test('suppressed while creeping at parking speed', () {
      final m = CollisionMonitor();
      var alert = AdasAlert.none;
      var d = 12.0;
      for (var i = 0; i <= 40; i++) {
        alert = m.update(distanceM: d, egoSpeedKmh: 5, ts: at(i * 0.1));
        d -= 0.08; // creeping closer at 0.8 m/s
        expect(alert, AdasAlert.none);
      }
    });

    test('lead switch (distance jump) does not fake a closing speed', () {
      final m = CollisionMonitor();
      var alert = AdasAlert.none;
      // Following a car at 50 m...
      for (var i = 0; i < 10; i++) {
        alert = m.update(distanceM: 50, egoSpeedKmh: 70, ts: at(i * 0.1));
      }
      // ...a motorbike cuts in at 9 m: one-frame jump, then steady.
      for (var i = 10; i < 20; i++) {
        alert = m.update(distanceM: 9, egoSpeedKmh: 70, ts: at(i * 0.1));
        expect(alert, isNot(AdasAlert.collision));
        expect(alert, isNot(AdasAlert.collisionCritical));
      }
    });

    test('losing the lead resets the closing estimate', () {
      final m = CollisionMonitor();
      var d = 40.0;
      for (var i = 0; i < 8; i++) {
        m.update(distanceM: d, egoSpeedKmh: 60, ts: at(i * 0.1));
        d -= 1.0; // closing at 10 m/s
      }
      expect(m.closingSpeedMps, greaterThan(1));
      m.update(distanceM: null, egoSpeedKmh: 60, ts: at(0.9));
      expect(m.closingSpeedMps, 0);
    });

    test('steady following produces no TTC alert', () {
      final m = CollisionMonitor();
      var alert = AdasAlert.none;
      for (var i = 0; i <= 30; i++) {
        alert = m.update(distanceM: 60, egoSpeedKmh: 70, ts: at(i * 0.1));
      }
      expect(alert, AdasAlert.none);
    });
  });
}
