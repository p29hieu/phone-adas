
import 'package:flutter/widgets.dart';

/// Big tabular-figure numeral for dashboards and HUDs.
///
/// Digits render at a fixed width, so rapidly changing values (speed,
/// distance) do not jitter horizontally. Flutter SDK only.
///
/// ```dart
/// HudNumeral('55', size: 120, color: Colors.green)
/// ```
class HudNumeral extends StatelessWidget {
  const HudNumeral(
    this.text, {
    super.key,
    this.size = 96,
    this.weight = FontWeight.w700,
    this.color,
  });

  final String text;
  final double size;
  final FontWeight weight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: size,
        height: 1,
        fontWeight: weight,
        color: color ?? DefaultTextStyle.of(context).style.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
