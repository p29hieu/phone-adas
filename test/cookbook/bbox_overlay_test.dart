import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/cookbook/bbox_overlay.dart';

void main() {
  group('mapFrameRectToScreen (cover-fit)', () {
    test('identity when frame == screen', () {
      final r = mapFrameRectToScreen(
        const Rect.fromLTWH(100, 200, 50, 40),
        const Size(1920, 1080),
        const Size(1920, 1080),
      );
      expect(r, const Rect.fromLTWH(100, 200, 50, 40));
    });

    test('same aspect scales uniformly', () {
      final r = mapFrameRectToScreen(
        const Rect.fromLTWH(960, 540, 100, 100),
        const Size(1920, 1080),
        const Size(960, 540),
      );
      expect(r, const Rect.fromLTWH(480, 270, 50, 50));
    });

    test('taller screen crops sides, centers horizontally', () {
      final r = mapFrameRectToScreen(
        const Rect.fromLTWH(100, 50, 20, 10),
        const Size(200, 100),
        const Size(100, 100),
      );
      expect(r.left, closeTo(50, 0.001));
      expect(r.top, closeTo(50, 0.001));
      expect(r.width, closeTo(20, 0.001));
    });

    test('frame center always maps to screen center', () {
      for (final screen in const [
        Size(300, 900),
        Size(900, 300),
        Size(500, 500),
      ]) {
        final r = mapFrameRectToScreen(
          const Rect.fromLTWH(959, 539, 2, 2),
          const Size(1920, 1080),
          screen,
        );
        expect(r.center.dx, closeTo(screen.width / 2, 0.01));
        expect(r.center.dy, closeTo(screen.height / 2, 0.01));
      }
    });
  });
}
