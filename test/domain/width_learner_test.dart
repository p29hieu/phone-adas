import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/domain/distance_estimator.dart';
import 'package:phone_adas/domain/models.dart';
import 'package:phone_adas/domain/width_learner.dart';

void main() {
  group('WidthLearner', () {
    test('rejects implausible widths', () {
      final w = WidthLearner();
      expect(w.add('car', 0.9), isFalse); // narrower than any car
      expect(w.add('car', 3.5), isFalse); // wider than a truck
      expect(w.add('dog', 1.8), isFalse); // unknown class
      expect(w.add('car', 1.85), isTrue);
    });

    test('applies only after enough samples', () {
      final w = WidthLearner(minSamples: 5);
      for (var i = 0; i < 4; i++) {
        w.add('car', 1.9);
      }
      expect(w.widthFor('car'), isNull);
      w.add('car', 1.9);
      expect(w.widthFor('car'), closeTo(1.9, 0.05));
      expect(w.applicable.keys, ['car']);
    });

    test('EMA converges toward the sample stream', () {
      final w = WidthLearner(minSamples: 1, alpha: 0.1);
      w.add('car', 1.6);
      for (var i = 0; i < 60; i++) {
        w.add('car', 2.0);
      }
      expect(w.widthFor('car'), closeTo(2.0, 0.02));
    });

    test('serialize/deserialize roundtrip', () {
      final w = WidthLearner(minSamples: 2);
      w.add('car', 1.85);
      w.add('car', 1.87);
      w.add('motorcycle', 0.8);
      final restored = WidthLearner.deserialize(w.serialize(), minSamples: 2);
      expect(restored.widthFor('car'), closeTo(w.widthFor('car')!, 0.001));
      expect(restored.totalSamples, w.totalSamples);
      expect(restored.widthFor('motorcycle'), isNull); // 1 sample < min 2
    });
  });

  test('estimator uses learned width overrides', () {
    final e = DistanceEstimator(fPx: 1500);
    const det = Detection(cls: 'car', conf: 0.9, x: 0, y: 0, w: 50, h: 40);
    final before = e.estimate(det)!; // 1.8 * 1500 / 50 = 54
    e.widthOverrides = {'car': 2.0};
    final after = e.estimate(det)!; // 2.0 * 1500 / 50 = 60
    expect(before, closeTo(54, 0.01));
    expect(after, closeTo(60, 0.01));
  });

  test('Detection.fromMap parses depthM when present', () {
    final d = Detection.fromMap({
      'cls': 'car',
      'conf': 0.9,
      'x': 1.0,
      'y': 2.0,
      'w': 300,
      'h': 200,
      'depthM': 3.42,
    });
    expect(d.depthM, closeTo(3.42, 0.001));
    final noDepth = Detection.fromMap(
        {'cls': 'car', 'conf': 0.9, 'x': 1, 'y': 2, 'w': 300, 'h': 200});
    expect(noDepth.depthM, isNull);
  });
}
