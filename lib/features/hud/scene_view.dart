import 'package:flutter/material.dart';

import '../../domain/distance_format.dart';
import 'hud_state.dart';

/// Tesla-style scene rendering: a perspective road with the ego vehicle at
/// the bottom and nearby detected vehicles placed by distance + lane slot
/// (left / ego / right). Painted fully opaque, so it simply covers the
/// camera layers when ViewMode.scene is active — the detection pipeline
/// keeps running underneath unchanged.
class SceneView extends StatelessWidget {
  const SceneView({super.key, required this.state, required this.leadColor});

  final HudState state;
  final Color leadColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ScenePainter(state: state, leadColor: leadColor),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({required this.state, required this.leadColor});

  final HudState state;
  final Color leadColor;

  static const double _horizonFrac = 0.32;

  /// Perspective constant: distance (m) at which a vehicle sits halfway
  /// between the bottom edge and the horizon.
  static const double _perspectiveK = 14;

  static const _sky = Color(0xFF0A0D12);
  static const _ground = Color(0xFF12161D);
  static const _asphalt = Color(0xFF1B2029);
  static const _lineColor = Color(0x8FFFFFFF);
  static const _otherCar = Color(0xFF8A93A3);
  static const _egoCar = Color(0xFF3D8BFF);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final yH = h * _horizonFrac;
    final yB = h;
    final cx = w / 2;

    double yOf(double d) => yH + (yB - yH) * (_perspectiveK / (d + _perspectiveK));
    double laneW(double y) {
      final t = ((y - yH) / (yB - yH)).clamp(0.0, 1.0);
      return w * 0.045 + (w * 0.42 - w * 0.045) * t;
    }

    // Background: sky above the horizon, ground below.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, yH),
      Paint()..color = _sky,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, yH, w, h - yH),
      Paint()..color = _ground,
    );

    // Road surface spanning three lanes.
    final road = Path()
      ..moveTo(cx - 1.5 * laneW(yB), yB)
      ..lineTo(cx + 1.5 * laneW(yB), yB)
      ..lineTo(cx + 1.5 * laneW(yH + 1), yH + 1)
      ..lineTo(cx - 1.5 * laneW(yH + 1), yH + 1)
      ..close();
    canvas.drawPath(road, Paint()..color = _asphalt);

    // Lane boundaries: outer solid, inner dashed.
    void boundary(double slots, {required bool dashed}) {
      final paint = Paint()
        ..color = _lineColor
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      if (!dashed) {
        canvas.drawLine(
          Offset(cx + slots * laneW(yB), yB),
          Offset(cx + slots * laneW(yH + 1), yH + 1),
          paint,
        );
        return;
      }
      var y = yB;
      while (y > yH + 4) {
        final segment = (y - yH) * 0.10;
        final y2 = (y - segment).clamp(yH + 1, yB);
        canvas.drawLine(
          Offset(cx + slots * laneW(y), y),
          Offset(cx + slots * laneW(y2), y2),
          paint,
        );
        y = y2 - segment * 0.8;
      }
    }

    boundary(-1.5, dashed: false);
    boundary(1.5, dashed: false);
    boundary(-0.5, dashed: true);
    boundary(0.5, dashed: true);

    // Other vehicles, far ones first so near ones overlap them.
    final vehicles = [...state.sceneVehicles]
      ..sort((a, b) => b.distanceM.compareTo(a.distanceM));
    for (final v in vehicles) {
      final y = yOf(v.distanceM);
      final lw = laneW(y);
      final x = cx + v.laneSlot * lw;
      final isMoto = v.cls == 'motorcycle';
      final isBig = v.cls == 'truck' || v.cls == 'bus';
      final carW = lw * (isMoto ? 0.26 : (isBig ? 0.66 : 0.52));
      final carH = carW * (isMoto ? 1.9 : (isBig ? 1.7 : 1.5));
      final rect = Rect.fromCenter(
        center: Offset(x, y - carH / 2),
        width: carW,
        height: carH,
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(x, y), width: carW * 1.15, height: carW * 0.3),
        Paint()..color = const Color(0x55000000),
      );
      final body = Paint()..color = v.isLead ? leadColor : _otherCar;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(carW * 0.24)),
        body,
      );
      // Rear window hint.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, rect.top + carH * 0.3),
            width: carW * 0.72,
            height: carH * 0.22,
          ),
          Radius.circular(carW * 0.1),
        ),
        Paint()..color = const Color(0x66000000),
      );
      if (v.isLead) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${formatDistanceM(v.distanceM)} m',
            style: TextStyle(
              color: Colors.white,
              fontSize: (carW * 0.5).clamp(14.0, 32.0),
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, rect.top - tp.height - 6));
      }
    }

    // Ego vehicle, bottom center, shifted by the live lane offset so lane
    // drift is visible exactly as the detector sees it.
    final laneOffset =
        (state.lane != null && state.lane!.conf >= 0.45) ? state.lane!.offset : 0.0;
    final egoW = laneW(yB) * 0.56;
    final egoX = cx + laneOffset.clamp(-1.5, 1.5) * laneW(yB) / 2;
    final egoRect = Rect.fromCenter(
      center: Offset(egoX, h - egoW * 0.7),
      width: egoW,
      height: egoW * 1.9,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(egoX, h), width: egoW * 1.3, height: egoW * 0.35),
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(egoRect, Radius.circular(egoW * 0.26)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_egoCar, _egoCar.withValues(alpha: 0.7)],
        ).createShader(egoRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(egoX, egoRect.top + egoRect.height * 0.28),
          width: egoW * 0.74,
          height: egoRect.height * 0.2,
        ),
        Radius.circular(egoW * 0.1),
      ),
      Paint()..color = const Color(0x4D000000),
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.state.sceneVehicles != state.sceneVehicles ||
      old.state.lane?.offset != state.lane?.offset ||
      old.leadColor != leadColor;
}
