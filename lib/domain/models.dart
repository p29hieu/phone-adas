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

class AdasFrame {
  const AdasFrame({
    required this.ts,
    required this.mock,
    required this.frameW,
    required this.frameH,
    this.fx,
    required this.detections,
  });

  final DateTime ts;

  /// True while the native core has no ML model and emits synthetic data.
  final bool mock;
  final int frameW, frameH;

  /// Camera focal length in pixels for this frame (from iOS camera
  /// intrinsics). Null when the platform does not deliver intrinsics.
  final double? fx;
  final List<Detection> detections;

  factory AdasFrame.fromMap(Map<dynamic, dynamic> m) => AdasFrame(
        ts: DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt()),
        mock: m['mock'] as bool? ?? false,
        frameW: (m['frameW'] as num).toInt(),
        frameH: (m['frameH'] as num).toInt(),
        fx: (m['fx'] as num?)?.toDouble(),
        detections: (m['detections'] as List<dynamic>? ?? const [])
            .map((e) => Detection.fromMap(e as Map<dynamic, dynamic>))
            .toList(growable: false),
      );
}
