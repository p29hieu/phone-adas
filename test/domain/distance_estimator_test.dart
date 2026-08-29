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

void main() {
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

  test('pickLead ignores low-confidence detections', () {
    final e = DistanceEstimator();
    final lead = e.pickLead(frame([det('car', 960, 80, conf: 0.2)]));
    expect(lead, isNull);
  });
}
