import 'models.dart';

/// Pinhole-model distance: d = realWidth * fPx / bboxWidthPx.
///
/// [fPx] is the focal length in pixels at the emitted frame resolution.
/// On iOS it should be replaced per-frame by the camera intrinsic fx
/// (AVCaptureConnection intrinsic matrix); the default matches a ~26 mm
/// equivalent lens at 1920 px width.
class DistanceEstimator {
  DistanceEstimator({this.fPx = 1500});

  double fPx;

  /// Assumed real vehicle widths per class, meters.
  static const Map<String, double> realWidthM = {
    'car': 1.8,
    'truck': 2.5,
    'bus': 2.5,
    'motorcycle': 0.8,
  };

  static const double minConfidence = 0.4;

  /// Fraction of frame width (each side of center) considered "our lane"
  /// for the v1 lead-vehicle heuristic.
  static const double laneBandHalfWidth = 0.15;

  double? estimate(Detection d) {
    final w = realWidthM[d.cls];
    if (w == null || d.w <= 0) return null;
    return w * fPx / d.w;
  }

  /// v1 lead-vehicle pick: nearest (widest bbox) vehicle whose horizontal
  /// center lies within the central lane band. Lane detection replaces this
  /// in a later phase.
  Detection? pickLead(AdasFrame f) {
    Detection? best;
    for (final d in f.detections) {
      if (!realWidthM.containsKey(d.cls) || d.conf < minConfidence) continue;
      final cx = d.x + d.w / 2;
      if ((cx - f.frameW / 2).abs() > f.frameW * laneBandHalfWidth) continue;
      if (best == null || d.w > best.w) best = d;
    }
    return best;
  }
}
