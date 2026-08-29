import 'package:flutter/services.dart';

import '../domain/models.dart';

/// Bridge to the native vision core.
///
/// Contract (identical on iOS and Android — and, later, for the external
/// UVC camera source):
///  - EventChannel `app.mikosea.test/detections` emits [AdasFrame] maps
///    at ~10 Hz.
///  - MethodChannel `app.mikosea.test/control` accepts `start` / `stop`.
class AdasChannel {
  const AdasChannel._();

  static const EventChannel _events =
      EventChannel('app.mikosea.test/detections');
  static const MethodChannel _control =
      MethodChannel('app.mikosea.test/control');

  static Stream<AdasFrame>? _frames;

  static Stream<AdasFrame> get frames => _frames ??= _events
      .receiveBroadcastStream()
      .map((e) => AdasFrame.fromMap(e as Map<dynamic, dynamic>))
      .asBroadcastStream();

  static Future<void> start() => _control.invokeMethod('start');
  static Future<void> stop() => _control.invokeMethod('stop');
}
