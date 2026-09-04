/// Shared data models for the ADAS pipeline.
///
/// Native cores (iOS/Android) emit [AdasFrame] maps over the event channel
/// `app.mikosea.test/detections`; Dart owns all distance math and alerts.
class Detection {
  const Detection({
    required this.cls,
    required this.conf,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  /// One of: car, truck, bus, motorcycle.
  final String cls;
  final double conf;

  /// Bounding box in full-resolution frame pixels (origin top-left).
  final double x, y, w, h;

  factory Detection.fromMap(Map<dynamic, dynamic> m) => Detection(
        cls: m['cls'] as String,
        conf: (m['conf'] as num).toDouble(),
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        w: (m['w'] as num).toDouble(),
        h: (m['h'] as num).toDouble(),
      );
}

/// One lane boundary as a segment in frame pixels, bottom (x0,y0) to
/// top (x1,y1).
class LaneLine {
  const LaneLine(this.x0, this.y0, this.x1, this.y1);

  final double x0, y0, x1, y1;

  /// X of this boundary at row [y] (linear, extrapolates beyond endpoints).
  double xAt(double y) {
    if ((y1 - y0).abs() < 1e-6) return x0;
    return x0 + (x1 - x0) * (y - y0) / (y1 - y0);
  }

  factory LaneLine.fromList(List<dynamic> v) => LaneLine(
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        (v[2] as num).toDouble(),
        (v[3] as num).toDouble(),
      );
}

/// Ego-lane estimate from the native core (test-mode feature).
class LaneObservation {
  const LaneObservation({
    required this.left,
    required this.right,
    required this.offset,
    required this.conf,
  });

  final LaneLine left;
  final LaneLine right;

  /// Camera position within the lane, normalized to half the lane width:
  /// 0 = centered, +1 = on the right line, -1 = on the left line.
  final double offset;
  final double conf;

  factory LaneObservation.fromMap(Map<dynamic, dynamic> m) => LaneObservation(
        left: LaneLine.fromList(m['left'] as List<dynamic>),
        right: LaneLine.fromList(m['right'] as List<dynamic>),
        offset: (m['offset'] as num).toDouble(),
        conf: (m['conf'] as num).toDouble(),
      );
}

/// Mount auto-calibration learned by the native core: the true lane-center
/// axis (cx, px) and horizon (vy, px) of THIS mount, from n two-sided locks.
class LaneCalib {
  const LaneCalib({required this.cx, required this.vy, required this.n});

  final double cx;
  final double vy;
  final int n;

  factory LaneCalib.fromMap(Map<dynamic, dynamic> m) => LaneCalib(
        cx: (m['cx'] as num).toDouble(),
        vy: (m['vy'] as num).toDouble(),
        n: (m['n'] as num).toInt(),
      );
}

class AdasFrame {
  const AdasFrame({
    required this.ts,
    required this.mock,
    required this.frameW,
    required this.frameH,
    this.fx,
    this.lane,
    this.laneDbg,
    this.laneCalib,
    required this.detections,
  });

  final DateTime ts;

  /// True while the native core has no ML model and emits synthetic data.
  final bool mock;
  final int frameW, frameH;

  /// Camera focal length in pixels for this frame (from iOS camera
  /// intrinsics). Null when the platform does not deliver intrinsics.
  final double? fx;

  /// Ego-lane estimate, when the native core produced one this frame.
  final LaneObservation? lane;

  /// Lane-detector diagnostics ({l, r, gate}) for the dev-mode overlay.
  final Map<dynamic, dynamic>? laneDbg;

  /// Learned mount axis/horizon, once the native core has calibrated.
  final LaneCalib? laneCalib;
  final List<Detection> detections;

  factory AdasFrame.fromMap(Map<dynamic, dynamic> m) => AdasFrame(
        ts: DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt()),
        mock: m['mock'] as bool? ?? false,
        frameW: (m['frameW'] as num).toInt(),
        frameH: (m['frameH'] as num).toInt(),
        fx: (m['fx'] as num?)?.toDouble(),
        lane: m['lane'] is Map<dynamic, dynamic>
            ? LaneObservation.fromMap(m['lane'] as Map<dynamic, dynamic>)
            : null,
        laneDbg: m['laneDbg'] is Map<dynamic, dynamic>
            ? m['laneDbg'] as Map<dynamic, dynamic>
            : null,
        laneCalib: m['laneCalib'] is Map<dynamic, dynamic>
            ? LaneCalib.fromMap(m['laneCalib'] as Map<dynamic, dynamic>)
            : null,
        detections: (m['detections'] as List<dynamic>? ?? const [])
            .map((e) => Detection.fromMap(e as Map<dynamic, dynamic>))
            .toList(growable: false),
      );
}
