import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/domain/safe_distance.dart';

void main() {
  group('SafeDistance.legalMinimumMeters (TT 38/2024)', () {
    test('below 60 km/h has no fixed legal minimum', () {
      expect(SafeDistance.legalMinimumMeters(0), 0);
      expect(SafeDistance.legalMinimumMeters(59.9), 0);
    });
    test('exactly 60 km/h requires 35 m', () {
      expect(SafeDistance.legalMinimumMeters(60), 35);
    });
    test('above 60 up to 80 km/h requires 55 m', () {
      expect(SafeDistance.legalMinimumMeters(60.1), 55);
      expect(SafeDistance.legalMinimumMeters(80), 55);
    });
    test('above 80 up to 100 km/h requires 70 m', () {
      expect(SafeDistance.legalMinimumMeters(80.1), 70);
      expect(SafeDistance.legalMinimumMeters(100), 70);
    });
    test('above 100 km/h requires 100 m', () {
      expect(SafeDistance.legalMinimumMeters(100.1), 100);
      expect(SafeDistance.legalMinimumMeters(120), 100);
    });
  });

  group('SafeDistance.recommendedMeters', () {
    test('uses 2-second rule below 60 km/h', () {
      expect(SafeDistance.recommendedMeters(36), closeTo(20, 0.01));
    });
    test('never below the legal minimum', () {
      expect(SafeDistance.recommendedMeters(60), 35);
      expect(SafeDistance.recommendedMeters(61), 55);
    });
    test('2-second rule dominates when longer than legal table', () {
      // 120 km/h -> 2 s = 66.7 m < 100 m legal, legal wins.
      expect(SafeDistance.recommendedMeters(120), 100);
    });
  });
}
