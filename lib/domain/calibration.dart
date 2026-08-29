import 'dart:math' as math;

/// Two-point guided calibration ("Hiệu chỉnh thông số").
///
/// The user mounts the phone, aims at a parked car at two known distances
/// (10 m and 30 m) and samples each. The resulting [CalibrationResult.scale]
/// multiplies every pinhole estimate and absorbs the systematic errors of
/// this phone + windshield + model combination: bbox tightness bias, glass
/// refraction, lens deviations and the target car's width offset.
class Calibration {
  const Calibration._();

  /// Reference distances of the guided flow, meters.
  static const List<double> referenceDistancesM = [10, 30];

  static const double minScale = 0.7;
  static const double maxScale = 1.3;

  /// Maximum allowed disagreement between the per-point scales. Above this
  /// the two measurements contradict each other and must be redone.
  static const double maxSpreadRatio = 0.15;

  /// Combines per-point measurements into one correction factor
  /// (geometric mean). [CalibrationResult.isValid] is false when the points
  /// disagree or the result is outside the plausible range.
  static CalibrationResult compute(List<CalibrationPoint> points) {
    assert(points.isNotEmpty);
    final scales =
        points.map((p) => p.trueDistanceM / p.rawDistanceM).toList();
    final scale = math.exp(
        scales.map(math.log).reduce((a, b) => a + b) / scales.length);
    final lo = scales.reduce(math.min);
    final hi = scales.reduce(math.max);
    final spread = hi / lo - 1;
    final isValid =
        spread <= maxSpreadRatio && scale >= minScale && scale <= maxScale;
    return CalibrationResult(
        scale: scale, spreadRatio: spread, isValid: isValid);
  }
}

class CalibrationPoint {
  const CalibrationPoint({
    required this.trueDistanceM,
    required this.rawDistanceM,
  });

  final double trueDistanceM;

  /// Median uncalibrated estimate at this point (from [CalibrationSampler]).
  final double rawDistanceM;
}

class CalibrationResult {
  const CalibrationResult({
    required this.scale,
    required this.spreadRatio,
    required this.isValid,
  });

  final double scale;
  final double spreadRatio;
  final bool isValid;
}

/// Collects raw distance samples at one reference point and judges their
/// stability via median + median-absolute-deviation, so a passing cyclist
/// or a jittery detection cannot poison the calibration.
class CalibrationSampler {
  CalibrationSampler({this.minSamples = 15, this.maxJitterRatio = 0.05});

  final int minSamples;
  final double maxJitterRatio;
  final List<double> _samples = [];

  int get count => _samples.length;

  void add(double rawDistanceM) {
    if (rawDistanceM > 0) _samples.add(rawDistanceM);
  }

  void reset() => _samples.clear();

  SamplerOutcome finish() {
    if (count < minSamples) return const SamplerOutcome.tooFewSamples();
    final median = _median(_samples);
    final deviations = _samples.map((s) => (s - median).abs()).toList();
    final mad = _median(deviations);
    final jitter = mad / median;
    if (jitter > maxJitterRatio) return SamplerOutcome.unstable(jitter);
    return SamplerOutcome.stable(median: median, jitterRatio: jitter);
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}

enum SamplerStatus { stable, tooFewSamples, unstable }

class SamplerOutcome {
  const SamplerOutcome.stable(
      {required double median, required double jitterRatio})
      : status = SamplerStatus.stable,
        medianM = median,
        jitter = jitterRatio;

  const SamplerOutcome.tooFewSamples()
      : status = SamplerStatus.tooFewSamples,
        medianM = 0,
        jitter = 0;

  const SamplerOutcome.unstable(double jitterRatio)
      : status = SamplerStatus.unstable,
        medianM = 0,
        jitter = jitterRatio;

  final SamplerStatus status;
  final double medianM;
  final double jitter;
}
