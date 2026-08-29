import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/domain/distance_format.dart';
import 'package:phone_adas/domain/lane_monitor.dart';

void main() {
  final t0 = DateTime.utc(2026, 1, 1);
  DateTime at(double s) => t0.add(Duration(milliseconds: (s * 1000).round()));

  group('formatDistanceM', () {
    test('above 5 m rounds to whole meters', () {
      expect(formatDistanceM(49.24), '49');
      expect(formatDistanceM(5.06), '5');
    });
    test('at or below 5 m keeps one decimal', () {
      expect(formatDistanceM(4.96), '5.0');
      expect(formatDistanceM(2.34), '2.3');
    });
  });

  group('LaneMonitor', () {
    test('fires once after sustained departure at speed', () {
      final m = LaneMonitor();
      var fired = false;
      for (var i = 0; i <= 12; i++) {
        fired = m.update(
            offset: 0.7, conf: 0.8, egoSpeedKmh: 60, ts: at(i * 0.1));
        if (fired) break;
      }
      expect(fired, isTrue);
      expect(m.status, LaneStatus.departRight);
      // No repeat while still departed.
      expect(
        m.update(offset: 0.75, conf: 0.8, egoSpeedKmh: 60, ts: at(1.5)),
        isFalse,
      );
    });

    test('a brief wobble does not fire', () {
      final m = LaneMonitor();
      expect(m.update(offset: 0.7, conf: 0.8, egoSpeedKmh: 60, ts: at(0)),
          isFalse);
      expect(m.update(offset: 0.2, conf: 0.8, egoSpeedKmh: 60, ts: at(0.3)),
          isFalse);
      expect(m.status, LaneStatus.centered);
    });

    test('suppressed at low speed and low confidence', () {
      final m = LaneMonitor();
      for (var i = 0; i <= 12; i++) {
        expect(
          m.update(offset: 0.9, conf: 0.8, egoSpeedKmh: 10, ts: at(i * 0.1)),
          isFalse,
        );
      }
      expect(m.status, LaneStatus.unknown);
      final m2 = LaneMonitor();
      for (var i = 0; i <= 12; i++) {
        expect(
          m2.update(offset: 0.9, conf: 0.2, egoSpeedKmh: 60, ts: at(i * 0.1)),
          isFalse,
        );
      }
      expect(m2.status, LaneStatus.unknown);
    });

    test('releases with hysteresis and can fire again', () {
      final m = LaneMonitor();
      var fired = false;
      for (var i = 0; i <= 12 && !fired; i++) {
        fired = m.update(
            offset: -0.7, conf: 0.8, egoSpeedKmh: 60, ts: at(i * 0.1));
      }
      expect(m.status, LaneStatus.departLeft);
      // 0.5 is below 0.55 but above 0.44 release point -> still departed.
      m.update(offset: -0.5, conf: 0.8, egoSpeedKmh: 60, ts: at(2));
      expect(m.status, LaneStatus.departLeft);
      m.update(offset: -0.3, conf: 0.8, egoSpeedKmh: 60, ts: at(2.1));
      expect(m.status, LaneStatus.centered);
    });
  });
}
