import 'package:flutter/widgets.dart';

/// Full-screen pulsing edge glow for urgent states (collision warning).
/// Pointer-transparent. Pulses while [active]; fades out and stops
/// animating when deactivated. Flutter SDK only.
///
/// ```dart
/// PulsingBorder(active: alert == Alert.collision, color: Color(0xFFE53935))
/// ```
class PulsingBorder extends StatefulWidget {
  const PulsingBorder({
    super.key,
    required this.active,
    this.color = const Color(0xFFE53935),
    this.period = const Duration(seconds: 2),
    this.maxThickness = 16,
  });

  final bool active;
  final Color color;

  /// One full bright-dim-bright cycle.
  final Duration period;
  final double maxThickness;

  @override
  State<PulsingBorder> createState() => _PulsingBorderState();
}

class _PulsingBorderState extends State<PulsingBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulsingBorder old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && old.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.active ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // 0.35..1.0 intensity swing per half-period.
            final t = 0.35 + 0.65 * _controller.value;
            return CustomPaint(
              size: Size.infinite,
              painter: _EdgeGlowPainter(
                color: widget.color,
                intensity: t,
                thickness: widget.maxThickness,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EdgeGlowPainter extends CustomPainter {
  _EdgeGlowPainter({
    required this.color,
    required this.intensity,
    required this.thickness,
  });

  final Color color;
  final double intensity;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness * intensity
      ..color = color.withValues(alpha: 0.85 * intensity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, thickness * 0.8);
    canvas.drawRect(rect.deflate(thickness * intensity / 2), paint);
  }

  @override
  bool shouldRepaint(covariant _EdgeGlowPainter old) =>
      old.intensity != intensity ||
      old.color != color ||
      old.thickness != thickness;
}
