import Flutter
import Foundation

/// Native vision core — Phase 0: mock emitter at 10 Hz.
///
/// The real pipeline (AVCaptureSession -> Vision VNCoreMLRequest with
/// regionOfInterest -> YOLO .mlpackage on the Neural Engine) lands here
/// next; the Flutter-facing contract below stays identical, as does the
/// future UVC/external frame source on Android.
///
/// Contract:
///  - EventChannel `app.mikosea.test/detections`: frames at ~10 Hz.
///  - MethodChannel `app.mikosea.test/control`: `start` / `stop`.
final class AdasCore: NSObject, FlutterPlugin, FlutterStreamHandler {
  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AdasCore()
    let events = FlutterEventChannel(
      name: "app.mikosea.test/detections",
      binaryMessenger: registrar.messenger()
    )
    events.setStreamHandler(instance)
    let control = FlutterMethodChannel(
      name: "app.mikosea.test/control",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: control)
  }

  private var sink: FlutterEventSink?
  private var timer: Timer?
  private var phase = 0.0

  // MARK: - FlutterPlugin

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      startMockEmitter()
      result(nil)
    case "stop":
      stopMockEmitter()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    startMockEmitter()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopMockEmitter()
    sink = nil
    return nil
  }

  // MARK: - Mock emitter

  private func startMockEmitter() {
    guard timer == nil else { return }
    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.emitMockFrame()
    }
  }

  private func stopMockEmitter() {
    timer?.invalidate()
    timer = nil
  }

  private func emitMockFrame() {
    guard let sink else { return }
    phase += 0.1
    // A "car" drifting between roughly 30 m and 70 m (w = 1.8 * 1500 / d).
    let w = 65.0 + 25.0 * sin(phase / 3.0)
    let frame: [String: Any] = [
      "ts": Int(Date().timeIntervalSince1970 * 1000),
      "mock": true,
      "frameW": 1920,
      "frameH": 1080,
      "detections": [
        [
          "cls": "car",
          "conf": 0.92,
          "x": 960.0 - w / 2.0,
          "y": 520.0,
          "w": w,
          "h": w * 0.8,
        ] as [String: Any],
      ],
    ]
    sink(frame)
  }
}
