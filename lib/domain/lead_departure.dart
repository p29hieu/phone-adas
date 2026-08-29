import 'dart:math' as math;

/// Detects "the vehicle ahead drove off while we are stopped" (red light).
///
/// Arms after ego speed stays under [stopSpeedKmh] for [stopDelay] with a
/// lead vehicle within [armDistanceM]. Fires exactly once when the lead
/// distance rises [departureDeltaM] above the settled baseline. Resets as
/// soon as the ego vehicle moves again.
class LeadDepartureDetector {
  LeadDepartureDetector({
    this.stopSpeedKmh = 2,
    this.stopDelay = const Duration(seconds: 2),
    this.armDistanceM = 30,
    this.departureDeltaM = 3,
  });

  final double stopSpeedKmh;
  final Duration stopDelay;
  final double armDistanceM;
  final double departureDeltaM;

  DateTime? _stoppedSince;
  bool _armed = false;
  bool _fired = false;
  double? _baseline;

  bool get isArmed => _armed;

  /// Returns true exactly once per stop when the lead departs.
  bool update({
    required double egoSpeedKmh,
    required double? leadDistanceM,
    required DateTime ts,
  }) {
    if (egoSpeedKmh > stopSpeedKmh) {
      _stoppedSince = null;
      _armed = false;
      _fired = false;
      _baseline = null;
      return false;
    }
    _stoppedSince ??= ts;

    if (!_armed) {
      if (ts.difference(_stoppedSince!) >= stopDelay &&
          leadDistanceM != null &&
          leadDistanceM <= armDistanceM) {
        _armed = true;
        _fired = false;
        _baseline = leadDistanceM;
      }
      return false;
    }

    if (leadDistanceM != null && _baseline != null) {
      _baseline = math.min(_baseline!, leadDistanceM);
      if (!_fired && leadDistanceM - _baseline! >= departureDeltaM) {
        _fired = true;
        return true;
      }
    }
    return false;
  }
}
