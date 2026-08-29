import 'safe_distance.dart';

enum AdasAlert { none, keepDistance, collision, collisionCritical }

/// Fuses the lead-vehicle distance stream and ego speed into alert levels.
///
/// - [AdasAlert.keepDistance]: below the legal gap sustained for
///   [gapEnterDelay] (hysteresis: released only above gap * [releaseFactor]).
///   Deliberate 2 s delay so a car cutting in does not chirp instantly.
/// - [AdasAlert.collision] / [AdasAlert.collisionCritical]: time-to-collision
///   below [ttcWarnSeconds] / [ttcCriticalSeconds]. Immediate, no delay.
class CollisionMonitor {
  CollisionMonitor({
    this.gapEnterDelay = const Duration(seconds: 2),
    this.ttcWarnSeconds = 2.5,
    this.ttcCriticalSeconds = 1.2,
    this.releaseFactor = 1.1,
  });

  final Duration gapEnterDelay;
  final double ttcWarnSeconds;
  final double ttcCriticalSeconds;
  final double releaseFactor;

  double? _lastDistance;
  DateTime? _lastTs;
  double _closingMps = 0; // EMA of closing speed, + means approaching
  DateTime? _gapBreachSince;
  bool _gapActive = false;

  /// Minimum closing speed before TTC is considered meaningful (m/s).
  static const double _minClosingMps = 0.5;
  static const double _emaKeep = 0.7;

  double get closingSpeedMps => _closingMps;

  /// [measuredClosingMps] — closing speed measured by an external range
  /// sensor (e.g. the car's factory ACC radar over CAN). When provided it
  /// replaces the camera-derived EMA: no warm-up, no differentiation noise.
  AdasAlert update({
    required double? distanceM,
    required double egoSpeedKmh,
    required DateTime ts,
    double? measuredClosingMps,
  }) {
    if (distanceM == null) {
      // Lead lost: keep gap state armed briefly is not needed for v1.
      _lastDistance = null;
      _lastTs = null;
      _gapBreachSince = null;
      _gapActive = false;
      return AdasAlert.none;
    }

    if (measuredClosingMps != null) {
      _closingMps = measuredClosingMps;
    } else if (_lastDistance != null && _lastTs != null) {
      final dt = ts.difference(_lastTs!).inMicroseconds / 1e6;
      if (dt > 0 && dt < 2) {
        final v = (_lastDistance! - distanceM) / dt;
        _closingMps = _closingMps * _emaKeep + v * (1 - _emaKeep);
      }
    }
    _lastDistance = distanceM;
    _lastTs = ts;

    if (_closingMps > _minClosingMps) {
      final ttc = distanceM / _closingMps;
      if (ttc < ttcCriticalSeconds) return AdasAlert.collisionCritical;
      if (ttc < ttcWarnSeconds) return AdasAlert.collision;
    }

    final gap = SafeDistance.legalMinimumMeters(egoSpeedKmh);
    if (gap <= 0) {
      _gapBreachSince = null;
      _gapActive = false;
      return AdasAlert.none;
    }
    if (_gapActive) {
      if (distanceM > gap * releaseFactor) {
        _gapActive = false;
        _gapBreachSince = null;
        return AdasAlert.none;
      }
      return AdasAlert.keepDistance;
    }
    if (distanceM < gap) {
      _gapBreachSince ??= ts;
      if (ts.difference(_gapBreachSince!) >= gapEnterDelay) {
        _gapActive = true;
        return AdasAlert.keepDistance;
      }
    } else {
      _gapBreachSince = null;
    }
    return AdasAlert.none;
  }
}
