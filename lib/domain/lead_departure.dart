import 'dart:math' as math;

/// Detects "the vehicle ahead drove off while we are stopped" (red light).
///
/// Arms after ego speed stays under [stopSpeedKmh] for [stopDelay] with a
/// lead vehicle within [armDistanceM]. Fires exactly once when the
/// median-smoothed lead distance stays [departureDeltaM] above the settled
/// baseline for [confirmDelay] — engine-vibration bbox jitter produces
/// spikes, not a sustained rise, so it can no longer trigger. Resets as
/// soon as the ego vehicle moves again.
class LeadDepartureDetector {
  LeadDepartureDetector({
    this.stopSpeedKmh = 2,
    this.stopDelay = const Duration(seconds: 2),
    this.armDistanceM = 30,
    this.departureDeltaM = 3,
    this.confirmDelay = const Duration(milliseconds: 1200),
    this.medianWindow = 5,
  });

  final double stopSpeedKmh;
  final Duration stopDelay;
  final double armDistanceM;
  final double departureDeltaM;
  final Duration confirmDelay;
  final int medianWindow;

  DateTime? _stoppedSince;
  DateTime? _risenSince;
  bool _armed = false;
  bool _fired = false;
  double? _baseline;
  final List<double> _recent = [];

  bool get isArmed => _armed;

  /// Returns true exactly once per stop when the lead departs.
  bool update({
    required double egoSpeedKmh,
    required double? leadDistanceM,
    required DateTime ts,
  }) {
    if (egoSpeedKmh > stopSpeedKmh) {
      _stoppedSince = null;
      _risenSince = null;
      _armed = false;
      _fired = false;
      _baseline = null;
      _recent.clear();
      return false;
    }
    _stoppedSince ??= ts;

    final smoothed = _smooth(leadDistanceM);

    if (!_armed) {
      if (ts.difference(_stoppedSince!) >= stopDelay &&
          smoothed != null &&
          smoothed <= armDistanceM) {
        _armed = true;
        _fired = false;
        _baseline = smoothed;
      }
      return false;
    }

    if (smoothed != null && _baseline != null) {
      _baseline = math.min(_baseline!, smoothed);
      if (smoothed - _baseline! >= departureDeltaM) {
        _risenSince ??= ts;
        if (!_fired && ts.difference(_risenSince!) >= confirmDelay) {
          _fired = true;
          return true;
        }
      } else {
        _risenSince = null;
      }
    }
    return false;
  }

  /// Rolling median over the last [medianWindow] readings — single-frame
  /// bbox jitter (engine vibration) cannot move it.
  double? _smooth(double? d) {
    if (d == null) return _recent.isEmpty ? null : _medianOf(_recent);
    _recent.add(d);
    if (_recent.length > medianWindow) _recent.removeAt(0);
    return _medianOf(_recent);
  }

  static double _medianOf(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
