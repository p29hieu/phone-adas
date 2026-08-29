import 'package:flutter/widgets.dart';

/// AR-style bounding-box overlay: corner brackets around detected objects
/// plus a label bubble above each box. Flutter SDK only.
///
/// The overlay maps rectangles given in a *source frame* coordinate space
/// (e.g. a 1920x1080 camera frame) onto the widget's screen space using
/// cover-fit semantics (same as `BoxFit.cover` for the underlying preview),
/// so boxes stay glued to objects regardless of screen aspect ratio.
///
/// ```dart
/// BBoxOverlay(
///   frameSize: const Size(1920, 1080),
///   items: [
///     BBoxItem(
///       rect: const Rect.fromLTWH(940, 500, 60, 48),
///       label: '14.8 m',
///       color: const Color(0xFFFFF3C4),
///     ),
///   ],
/// )
/// ```
class BBoxItem {
  const BBoxItem({
    required this.rect,
    required this.label,
    required this.color,
    this.textColor = const Color(0xFF1A1A1A),
    this.emphasized = false,
  });

  /// Object rectangle in source-frame coordinates.
  final Rect rect;
  final String label;

  /// Bubble background and bracket color.
  final Color color;
  final Color textColor;

  /// Draws a thicker bracket (e.g. for the lead vehicle).
  final bool emphasized;
}

/// Maps [rect] from a [frame]-sized space onto a [screen]-sized space with
/// cover-fit (fill screen, crop overflow, keep aspect). Pure function —
/// unit-testable without widgets.
Rect mapFrameRectToScreen(Rect rect, Size frame, Size screen) {
  final scale = (screen.width / frame.width) > (screen.height / frame.height)
      ? screen.width / frame.width
      : screen.height / frame.height;
  final dx = (screen.width - frame.width * scale) / 2;
  final dy = (screen.height - frame.height * scale) / 2;
  return Rect.fromLTWH(
    rect.left * scale + dx,
    rect.top * scale + dy,
    rect.width * scale,
    rect.height * scale,
  );
}

class BBoxOverlay extends StatelessWidget {
  const BBoxOverlay({
    super.key,
    required this.frameSize,
    required this.items,
  });

  final Size frameSize;
  final List<BBoxItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _BBoxPainter(frameSize: frameSize, items: items),
      ),
    );
  }
}

class _BBoxPainter extends CustomPainter {
  _BBoxPainter({required this.frameSize, required this.items});

  final Size frameSize;
  final List<BBoxItem> items;

  @override
  void paint(Canvas canvas, Size size) {
    for (final item in items) {
      final r = mapFrameRectToScreen(item.rect, frameSize, size);
      _paintBrackets(canvas, r, item);
      _paintBubble(canvas, r, item);
    }
  }

  void _paintBrackets(Canvas canvas, Rect r, BBoxItem item) {
    final paint = Paint()
      ..color = item.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = item.emphasized ? 3.5 : 2
      ..strokeCap = StrokeCap.round;
    final len = (r.shortestSide * 0.28).clamp(8.0, 26.0);
    final path = Path()
      // top-left
      ..moveTo(r.left, r.top + len)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + len, r.top)
      // top-right
      ..moveTo(r.right - len, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + len)
      // bottom-right
      ..moveTo(r.right, r.bottom - len)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - len, r.bottom)
      // bottom-left
      ..moveTo(r.left + len, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - len);
    canvas.drawPath(path, paint);
  }

  void _paintBubble(Canvas canvas, Rect r, BBoxItem item) {
    final tp = TextPainter(
      text: TextSpan(
        text: item.label,
        style: TextStyle(
          color: item.textColor,
          fontSize: item.emphasized ? 20 : 17,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const padH = 12.0, padV = 6.0, tail = 7.0, gap = 10.0;
    final w = tp.width + padH * 2;
    final h = tp.height + padV * 2;
    final cx = r.center.dx;
    final top = r.top - gap - tail - h;
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w / 2, top, w, h),
      const Radius.circular(8),
    );
    final fill = Paint()..color = item.color;
    canvas.drawRRect(bubble, fill);
    final tailPath = Path()
      ..moveTo(cx - tail, top + h)
      ..lineTo(cx, top + h + tail)
      ..lineTo(cx + tail, top + h)
      ..close();
    canvas.drawPath(tailPath, fill);
    tp.paint(canvas, Offset(cx - tp.width / 2, top + padV));
  }

  @override
  bool shouldRepaint(covariant _BBoxPainter old) =>
      old.items != items || old.frameSize != frameSize;
}
