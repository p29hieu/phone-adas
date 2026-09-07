/// Learns the TRUE per-class vehicle width from LiDAR ground truth.
///
/// Each red-light stop behind a vehicle inside LiDAR range yields a sample
/// `width = depth * bboxPx / (fPx * scale)` — expressed in the estimator's
/// own frame so it composes with the manual calibration scale without
/// double-counting. EMA per class, bounds-gated, applied only after
/// [minSamples] so a single odd vehicle cannot skew long-range estimates.
class WidthLearner {
  WidthLearner({this.minSamples = 10, this.alpha = 0.05});

  final int minSamples;
  final double alpha;
  final Map<String, double> _mean = {};
  final Map<String, int> _counts = {};

  /// Physically plausible width bounds per class, meters.
  static const Map<String, (double, double)> bounds = {
    'car': (1.4, 2.3),
    'truck': (1.9, 2.9),
    'bus': (1.9, 2.9),
    'motorcycle': (0.4, 1.2),
  };

  /// Returns true when the sample was accepted.
  bool add(String cls, double widthM) {
    final b = bounds[cls];
    if (b == null || widthM < b.$1 || widthM > b.$2) return false;
    _mean[cls] = (_mean[cls] ?? widthM) * (1 - alpha) + widthM * alpha;
    _counts[cls] = (_counts[cls] ?? 0) + 1;
    return true;
  }

  double? widthFor(String cls) =>
      (_counts[cls] ?? 0) >= minSamples ? _mean[cls] : null;

  /// Classes with enough samples to trust.
  Map<String, double> get applicable => {
        for (final e in _mean.entries)
          if ((_counts[e.key] ?? 0) >= minSamples) e.key: e.value,
      };

  int get totalSamples =>
      _counts.values.fold(0, (sum, n) => sum + n);

  /// Compact persistence format: "cls:mean:count" joined by ";".
  String serialize() => [
        for (final e in _mean.entries)
          '${e.key}:${e.value.toStringAsFixed(4)}:${_counts[e.key] ?? 0}',
      ].join(';');

  static WidthLearner deserialize(String data,
      {int minSamples = 10, double alpha = 0.05}) {
    final learner = WidthLearner(minSamples: minSamples, alpha: alpha);
    for (final part in data.split(';')) {
      final f = part.split(':');
      if (f.length != 3) continue;
      final mean = double.tryParse(f[1]);
      final count = int.tryParse(f[2]);
      if (mean == null || count == null) continue;
      learner._mean[f[0]] = mean;
      learner._counts[f[0]] = count;
    }
    return learner;
  }
}
