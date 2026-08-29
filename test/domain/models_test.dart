import 'package:flutter_test/flutter_test.dart';
import 'package:phone_adas/domain/models.dart';

void main() {
  test('AdasFrame.fromMap parses fx when present', () {
    final f = AdasFrame.fromMap({
      'ts': 1700000000000,
      'mock': false,
      'frameW': 1920,
      'frameH': 1080,
      'fx': 1478.5,
      'detections': [
        {'cls': 'car', 'conf': 0.9, 'x': 900.0, 'y': 500.0, 'w': 49, 'h': 40},
      ],
    });
    expect(f.fx, closeTo(1478.5, 0.001));
    expect(f.detections.single.cls, 'car');
    expect(f.detections.single.w, 49);
  });

  test('AdasFrame.fromMap tolerates missing fx and null mock', () {
    final f = AdasFrame.fromMap({
      'ts': 1700000000000,
      'frameW': 1080,
      'frameH': 1920,
      'detections': <dynamic>[],
    });
    expect(f.fx, isNull);
    expect(f.mock, isFalse);
    expect(f.frameW, 1080);
    expect(f.detections, isEmpty);
  });
}
