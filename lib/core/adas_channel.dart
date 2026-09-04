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

  /// Starts the native core. Returns the Flutter texture id of the live
  /// camera preview, or null when no preview is available (simulator,
  /// permission denied, Android stub).
  static Future<int?> start() async {
    final res = await _control.invokeMethod<dynamic>('start');
    if (res is Map) return (res['textureId'] as num?)?.toInt();
    return null;
  }
  static Future<void> stop() => _control.invokeMethod('stop');

  /// Plays a short native system beep (alert-sound option "beep").
  static Future<void> beep() => _control.invokeMethod('beep');

  /// Starts recording the camera feed natively (H.264 to a temp file).
  /// Returns false when no real camera is available (simulator, Android
  /// stub, permission denied).
  static Future<bool> startRecording() async =>
      await _control.invokeMethod<bool>('startRecording') ?? false;

  /// Stops recording and returns the temp .mp4 path, or null when nothing
  /// was recorded.
  static Future<String?> stopRecording() =>
      _control.invokeMethod<String>('stopRecording');

  /// App version label, e.g. "v1.1.0 (2)" — shown in the dev-mode chip so
  /// every field screenshot identifies its build.
  static Future<String?> versionLabel() async {
    final res = await _control.invokeMethod<dynamic>('getVersion');
    if (res is! Map) return null;
    return 'v${res['version']} (${res['build']})';
  }
}
