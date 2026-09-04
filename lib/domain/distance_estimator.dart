import 'models.dart';

/// Pinhole-model distance: d = realWidth * fPx / bboxWidthPx.
///
/// [fPx] is the focal length in pixels at the emitted frame resolution.
/// On iOS it should be replaced per-frame by the camera intrinsic fx
/// (AVCaptureConnection intrinsic matrix); the default matches a ~26 mm
/// equivalent lens at 1920 px width.
class DistanceEstimator {
  DistanceEstimator({this.fPx = 1500, this.scale = 1.0});

  double fPx;

  /// User-calibration correction factor (see domain/calibration.dart).
  /// 1.0 = uncalibrated.
  double scale;

  /// Learned mount axis (px) from native auto-calibration; when set, the
  /// no-lane fallback band centers here instead of the frame center, so a
  /// skewed mount still watches the ego lane.
  double? centerXOverride;

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
    return w * fPx / d.w * scale;
  }

  /// Minimum lane confidence before the detected lane replaces the
  /// center band as the relevance filter.
  static const double laneMinConf = 0.45;

  /// Extra tolerance around the lane, as a fraction of the lane width.
  static const double laneMarginRatio = 0.10;

  /// Vehicles that matter: inside the detected ego lane when one is
  /// available, otherwise within the central band of the frame. Everything
  /// else (parked cars, opposing traffic at the frame edges) is ignored by
  /// the overlay and the alert pipeline.
  List<Detection> relevantDetections(AdasFrame f) {
    final lane = f.lane;
    final useLane = lane != null && lane.conf >= laneMinConf;
    bool inside(Detection d) {
      final cx = d.x + d.w / 2;
      if (useLane) {
        final yBottom = d.y + d.h;
        final xl = lane.left.xAt(yBottom);
        final xr = lane.right.xAt(yBottom);
        if (xr <= xl) return false;
        final margin = (xr - xl) * laneMarginRatio;
        return cx >= xl - margin && cx <= xr + margin;
      }
      final bandCenter = centerXOverride ?? f.frameW / 2;
      return (cx - bandCenter).abs() <= f.frameW * laneBandHalfWidth;
    }

    return [
      for (final d in f.detections)
        if (realWidthM.containsKey(d.cls) &&
            d.conf >= minConfidence &&
            inside(d))
          d,
    ];
  }

  /// Lead vehicle: the nearest (widest bbox) relevant detection.
  Detection? pickLead(AdasFrame f) {
    Detection? best;
    for (final d in relevantDetections(f)) {
      if (best == null || d.w > best.w) best = d;
    }
    return best;
  }
}
