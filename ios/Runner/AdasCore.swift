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
    // Three mock vehicles matching the product mockup:
    // motorcycle left ~6 m, car center drifting 30-70 m, car right ~25 m.
    // w = realWidth * 1500 / distance.
    let dMoto = 6.2 + 0.4 * sin(phase / 1.7)
    let dCenter = 50.0 + 20.0 * sin(phase / 3.0)
    let dRight = 25.4 + 1.5 * sin(phase / 2.3)
    let wMoto = 0.8 * 1500.0 / dMoto
    let wCenter = 1.8 * 1500.0 / dCenter
    let wRight = 1.8 * 1500.0 / dRight
    func box(_ cls: String, _ cx: Double, _ groundY: Double, _ w: Double, _ hRatio: Double, _ conf: Double) -> [String: Any] {
      let h = w * hRatio
      return ["cls": cls, "conf": conf, "x": cx - w / 2.0, "y": groundY - h, "w": w, "h": h]
    }
    let frame: [String: Any] = [
      "ts": Int(Date().timeIntervalSince1970 * 1000),
      "mock": true,
      "frameW": 1920,
      "frameH": 1080,
      "detections": [
        box("motorcycle", 620, 760, wMoto, 1.6, 0.88),
        box("car", 960, 620, wCenter, 0.8, 0.93),
        box("car", 1330, 660, wRight, 0.8, 0.91),
      ],
    ]
    sink(frame)
  }
}
