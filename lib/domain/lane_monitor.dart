/// Lane-keeping status from the native lane observation (test-mode).
enum LaneStatus { unknown, centered, departLeft, departRight }

/// Turns the raw lateral offset stream into a debounced lane-departure
/// status + one-shot events.
///
/// `offset` is the camera's position within the lane, normalized to the
/// half lane width: 0 = centered, +1 = on the right lane line. Departure
/// requires the offset to stay beyond [offsetThreshold] for [enterDelay]
/// at a speed above [minSpeedKmh]; it releases below 80% of the threshold
/// (hysteresis) and fires exactly one event per excursion.
class LaneMonitor {
  LaneMonitor({
    this.offsetThreshold = 0.55,
    this.minConf = 0.45,
    this.enterDelay = const Duration(milliseconds: 800),
    this.minSpeedKmh = 30,
  });

  final double offsetThreshold;
  final double minConf;
  final Duration enterDelay;
  final double minSpeedKmh;

  DateTime? _breachSince;
  LaneStatus _status = LaneStatus.unknown;
  bool _eventFired = false;

  LaneStatus get status => _status;

  /// Returns true exactly once when a departure begins.
  bool update({
    required double? offset,
    required double conf,
    required double egoSpeedKmh,
    required DateTime ts,
  }) {
    if (offset == null || conf < minConf || egoSpeedKmh < minSpeedKmh) {
      _status = LaneStatus.unknown;
      _breachSince = null;
      _eventFired = false;
      return false;
    }
    final magnitude = offset.abs();
    final departing = magnitude > offsetThreshold;
    final departed =
        _status == LaneStatus.departLeft || _status == LaneStatus.departRight;

    if (departed) {
      if (magnitude < offsetThreshold * 0.8) {
        _status = LaneStatus.centered;
        _breachSince = null;
        _eventFired = false;
      }
      return false;
    }

    if (!departing) {
      _status = LaneStatus.centered;
      _breachSince = null;
      return false;
    }

    _breachSince ??= ts;
    if (ts.difference(_breachSince!) >= enterDelay) {
      _status = offset > 0 ? LaneStatus.departRight : LaneStatus.departLeft;
      if (!_eventFired) {
        _eventFired = true;
        return true;
      }
    }
    return false;
  }
}
