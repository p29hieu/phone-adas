import 'package:flutter/widgets.dart';

/// Compact pill badge for statuses (MOCK DATA, offline, stale, beta...).
/// Flutter SDK only.
///
/// ```dart
/// StatusBadge('MOCK DATA', background: Color(0xFFE65100))
/// ```
class StatusBadge extends StatelessWidget {
  const StatusBadge(
    this.text, {
    super.key,
    required this.background,
    this.foreground = const Color(0xFFFFFFFF),
    this.fontSize = 11,
  });

  final String text;
  final Color background;
  final Color foreground;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
