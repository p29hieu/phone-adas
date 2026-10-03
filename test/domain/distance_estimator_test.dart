import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/domain/distance_estimator.dart';
import 'package:phone_adas/domain/models.dart';

Detection det(String cls, double cx, double w, {double conf = 0.9}) =>
    Detection(cls: cls, conf: conf, x: cx - w / 2, y: 500, w: w, h: w * 0.8);

AdasFrame frame(List<Detection> ds) => AdasFrame(
      ts: DateTime.utc(2026),
      mock: true,
      frameW: 1920,
      frameH: 1080,
      detections: ds,
    );

LaneObservation laneObs() => const LaneObservation(
      // Lane from (760,1080)-(880,626) to (1160,1080)-(1040,626).
      left: LaneLine(760, 1080, 880, 626),
      right: LaneLine(1160, 1080, 1040, 626),
      offset: 0,
      conf: 0.9,
    );

AdasFrame frameWithLane(List<Detection> ds) => AdasFrame(
      ts: DateTime.utc(2026),
      mock: true,
      frameW: 1920,
      frameH: 1080,
      lane: laneObs(),
      detections: ds,
    );

void main() {
  test('LaneLine.xAt interpolates and extrapolates', () {
    const line = LaneLine(760, 1080, 880, 626);
    expect(line.xAt(1080), closeTo(760, 0.01));
    expect(line.xAt(626), closeTo(880, 0.01));
    expect(line.xAt(853), closeTo(820, 1)); // midpoint
  });

  test('with a detected lane, only in-lane vehicles are relevant', () {
    final e = DistanceEstimator();
    // In-lane car near center bottom; moto far left outside the lane.
    final inLane = det('car', 960, 60);
    final outside = det('motorcycle', 400, 120);
    final relevant = e.relevantDetections(frameWithLane([inLane, outside]));
    expect(relevant, [inLane]);
    expect(e.pickLead(frameWithLane([inLane, outside])), inLane);
  });

  test('low-confidence lane falls back to the center band', () {
    final e = DistanceEstimator();
    final f = AdasFrame(
      ts: DateTime.utc(2026),
      mock: true,
      frameW: 1920,
      frameH: 1080,
      lane: const LaneObservation(
        left: LaneLine(760, 1080, 880, 626),
        right: LaneLine(1160, 1080, 1040, 626),
        offset: 0,
        conf: 0.2,
      ),
      detections: [det('car', 960, 60), det('car', 200, 90)],
    );
    final relevant = e.relevantDetections(f);
    expect(relevant.length, 1);
    expect(relevant.single.w, 60);
  });

  test('pinhole math: 49 px car at f=1500 is about 55 m', () {
    final e = DistanceEstimator(fPx: 1500);
    final d = e.estimate(det('car', 960, 49));
    expect(d, isNotNull);
    expect(d!, closeTo(55.1, 0.2));
  });

  test('unknown class or zero width returns null', () {
    final e = DistanceEstimator();
    expect(e.estimate(det('dog', 960, 50)), isNull);
    expect(e.estimate(det('car', 960, 0)), isNull);
  });

  test('pickLead ignores vehicles outside the center lane band', () {
    final e = DistanceEstimator();
    // Wide (near) car far left, smaller car dead center.
    final lead = e.pickLead(frame([
      det('car', 200, 120),
      det('car', 960, 60),
    ]));
    expect(lead, isNotNull);
    expect(lead!.w, 60);
  });

  test('pickLead prefers the nearest (widest) in-lane vehicle', () {
    final e = DistanceEstimator();
    final lead = e.pickLead(frame([
      det('car', 900, 50),
      det('truck', 1000, 90),
    ]));
    expect(lead!.cls, 'truck');
  });

  test('learned mount axis recenters the no-lane fallback band', () {
    final e = DistanceEstimator();
    // Car at x=1300: outside the default center band (960 +/- 288)...
    final offCenter = det('car', 1300, 60);
    expect(e.relevantDetections(frame([offCenter])), isEmpty);
    // ...but inside the band once the mount is known to aim at ~1250.
    e.centerXOverride = 1250;
    expect(e.relevantDetections(frame([offCenter])), [offCenter]);
    // And the true frame center is now OUTSIDE the recentered band.
    final centered = det('car', 700, 60);
    expect(e.relevantDetections(frame([centered])), isEmpty);
  });

  group('roll compensation (derotatedWidth)', () {
    test('identity when level or beyond the model range', () {
      expect(DistanceEstimator.derotatedWidth(100, 80, 0), 100);
      expect(DistanceEstimator.derotatedWidth(100, 80, 1.5), 100);
      expect(DistanceEstimator.derotatedWidth(100, 80, 20), 100);
    });

    test('recovers the true width of a 5-degree rolled box', () {
      // True car box 94x80 rolled 5deg -> axis-aligned ~100.6x84.9.
      final w = DistanceEstimator.derotatedWidth(100.6, 84.9, 5);
      expect(w, closeTo(94.2, 1.5));
      // Sign of the roll does not matter.
      expect(DistanceEstimator.derotatedWidth(100.6, 84.9, -5),
          closeTo(w, 0.001));
    });

    test('tilted mount no longer reads closer than reality', () {
      final e = DistanceEstimator(fPx: 1500);
      const det = Detection(
          cls: 'car', conf: 0.9, x: 0, y: 0, w: 100.6, h: 84.9);
      final level = e.estimate(det)!; // inflated bbox -> too close
      e.rollDeg = 5;
      final corrected = e.estimate(det)!;
      expect(corrected, greaterThan(level));
      expect(corrected, closeTo(1.8 * 1500 / 94.2, 1.0));
    });
  });

  group('laneSlot', () {
    test('classifies left / ego / right against detected lane lines', () {
      final e = DistanceEstimator();
      final f = frameWithLane([]);
      expect(e.laneSlot(det('motorcycle', 400, 120), f), -1);
      expect(e.laneSlot(det('car', 960, 60), f), 0);
      expect(e.laneSlot(det('car', 1500, 80), f), 1);
    });

    test('falls back to the calibrated band without a lane', () {
      final e = DistanceEstimator()..centerXOverride = 1200;
      final f = frame([]);
      expect(e.laneSlot(det('car', 1200, 60), f), 0);
      expect(e.laneSlot(det('car', 700, 60), f), -1);
      expect(e.laneSlot(det('car', 1700, 60), f), 1);
    });
  });

  test('pickLead ignores low-confidence detections', () {
    final e = DistanceEstimator();
    final lead = e.pickLead(frame([det('car', 960, 80, conf: 0.2)]));
    expect(lead, isNull);
  });
}