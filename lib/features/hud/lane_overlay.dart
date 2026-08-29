import 'package:flutter/material.dart';

import '../../cookbook/bbox_overlay.dart';
import '../../domain/lane_monitor.dart';
import '../../domain/models.dart';

/// Test-mode overlay: fills the estimated ego lane, turning orange while a
/// lane departure is active. Shares the cover-fit mapping with BBoxOverlay.
class LaneOverlay extends StatelessWidget {
  const LaneOverlay({
    super.key,
    required this.lane,
    required this.frameSize,
    required this.status,
  });

  final LaneObservation lane;
  final Size frameSize;
  final LaneStatus status;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LanePainter(lane: lane, frameSize: frameSize, status: status),
    );
  }
}

class _LanePainter extends CustomPainter {
  _LanePainter({
    required this.lane,
    required this.frameSize,
    required this.status,
  });

  final LaneObservation lane;
  final Size frameSize;
  final LaneStatus status;

  @override
  void paint(Canvas canvas, Size size) {
    Offset map(double x, double y) =>
        mapFramePointToScreen(Offset(x, y), frameSize, size);
    final l0 = map(lane.left.x0, lane.left.y0);
    final l1 = map(lane.left.x1, lane.left.y1);
    final r0 = map(lane.right.x0, lane.right.y0);
    final r1 = map(lane.right.x1, lane.right.y1);

    final departed =
        status == LaneStatus.departLeft || status == LaneStatus.departRight;
    final color = departed ? const Color(0xFFFF9800) : const Color(0xFF4CAF50);

    final fill = Path()
      ..moveTo(l0.dx, l0.dy)
      ..lineTo(l1.dx, l1.dy)
      ..lineTo(r1.dx, r1.dy)
      ..lineTo(r0.dx, r0.dy)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.16));

    final stroke = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(l0, l1, stroke);
    canvas.drawLine(r0, r1, stroke);
  }

  @override
  bool shouldRepaint(covariant _LanePainter old) =>
      old.lane != lane || old.status != status || old.frameSize != frameSize;
}
