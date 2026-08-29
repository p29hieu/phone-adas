import 'dart:math' as math;

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
    this.minFcwSpeedKmh = 10,
  });

  final Duration gapEnterDelay;
  final double ttcWarnSeconds;
  final double ttcCriticalSeconds;
  final double releaseFactor;

  /// Below this ego speed camera-based TTC alerts are suppressed: parking
  /// and stop-and-go creeping otherwise fire constantly. Radar-measured
  /// closing speed is exempt.
  final double minFcwSpeedKmh;

  double? _lastDistance;
  DateTime? _lastTs;
  double _closingMps = 0; // EMA of closing speed, + means approaching
  int _ttcStreak = 0;
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
      // Lead lost: a stale closing speed must never survive into the next
      // target, so the EMA resets too.
      _lastDistance = null;
      _lastTs = null;
      _closingMps = 0;
      _ttcStreak = 0;
      _gapBreachSince = null;
      _gapActive = false;
      return AdasAlert.none;
    }

    if (measuredClosingMps != null) {
      _closingMps = measuredClosingMps;
    } else if (_lastDistance != null && _lastTs != null) {
      final dt = ts.difference(_lastTs!).inMicroseconds / 1e6;
      if (dt > 0 && dt < 2) {
        final jump = (distanceM - _lastDistance!).abs();
        if (jump > math.max(3.0, _lastDistance! * 0.25)) {
          // Implausible single-step change: the lead pick switched to a
          // different vehicle (e.g. a cut-in). Restart the closing estimate
          // instead of reading the jump as motion.
          _closingMps = 0;
          _ttcStreak = 0;
        } else {
          final v = (_lastDistance! - distanceM) / dt;
          _closingMps = _closingMps * _emaKeep + v * (1 - _emaKeep);
        }
      }
    }
    _lastDistance = distanceM;
    _lastTs = ts;

    final fcwAllowed =
        measuredClosingMps != null || egoSpeedKmh >= minFcwSpeedKmh;
    if (fcwAllowed && _closingMps > _minClosingMps) {
      final ttc = distanceM / _closingMps;
      if (ttc < ttcWarnSeconds) {
        _ttcStreak++;
        // Radar readings are trusted immediately; camera-derived TTC needs
        // two consecutive qualifying frames to kill single-frame spikes.
        if (measuredClosingMps != null || _ttcStreak >= 2) {
          return ttc < ttcCriticalSeconds
              ? AdasAlert.collisionCritical
              : AdasAlert.collision;
        }
      } else {
        _ttcStreak = 0;
      }
    } else {
      _ttcStreak = 0;
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
