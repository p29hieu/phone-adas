import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/domain/calibration.dart';

void main() {
  group('Calibration.compute', () {
    test('consistent points produce the mean correction', () {
      // App reads 10% short at both distances -> scale ~1.10.
      final r = Calibration.compute(const [
        CalibrationPoint(trueDistanceM: 10, rawDistanceM: 9.1),
        CalibrationPoint(trueDistanceM: 30, rawDistanceM: 27.3),
      ]);
      expect(r.isValid, isTrue);
      expect(r.scale, closeTo(1.099, 0.01));
      expect(r.spreadRatio, lessThan(0.01));
    });

    test('disagreeing points are rejected', () {
      // +25% at 10 m but -5% at 30 m: something moved between measurements.
      final r = Calibration.compute(const [
        CalibrationPoint(trueDistanceM: 10, rawDistanceM: 8.0),
        CalibrationPoint(trueDistanceM: 30, rawDistanceM: 31.5),
      ]);
      expect(r.isValid, isFalse);
      expect(r.spreadRatio, greaterThan(Calibration.maxSpreadRatio));
    });

    test('implausible overall scale is rejected', () {
      final r = Calibration.compute(const [
        CalibrationPoint(trueDistanceM: 10, rawDistanceM: 5),
        CalibrationPoint(trueDistanceM: 30, rawDistanceM: 15),
      ]);
      expect(r.scale, closeTo(2.0, 0.01));
      expect(r.isValid, isFalse);
    });
  });

  group('CalibrationSampler', () {
    test('median survives outlier frames', () {
      final s = CalibrationSampler();
      for (var i = 0; i < 20; i++) {
        s.add(10.0 + (i % 2 == 0 ? 0.1 : -0.1));
      }
      s.add(45.0); // a passing bus detected for one frame
      final out = s.finish();
      expect(out.status, SamplerStatus.stable);
      expect(out.medianM, closeTo(10.0, 0.15));
    });

    test('rejects when target readings drift', () {
      final s = CalibrationSampler();
      for (var i = 0; i < 30; i++) {
        s.add(10.0 + i * 0.2); // target rolling away
      }
      expect(s.finish().status, SamplerStatus.unstable);
    });

    test('rejects when detections are too few', () {
      final s = CalibrationSampler();
      for (var i = 0; i < 5; i++) {
        s.add(10);
      }
      expect(s.finish().status, SamplerStatus.tooFewSamples);
    });
  });
}
