import AudioToolbox
import AVFoundation
import CoreML
import Flutter
import UIKit
import Vision

/// Native vision core — Phase 2: real pipeline.
///
/// AVCaptureSession (1080p BGRA, back wide camera)
///   -> Flutter texture (live preview)
///   -> per-frame camera intrinsics (fx, pixels)
///   -> Vision VNCoreMLRequest over a centered square ROI (no full-frame
///      resize: a car at 55 m keeps ~33 px in the model input)
///   -> YOLO11n Core ML pipeline (NMS baked in) on the Neural Engine
///
/// Falls back to the mock emitter on the simulator, when the model is not
/// bundled (run tools/export_model.sh), or when camera permission is denied.
///
/// Contract (frozen, mirrored on Android):
///  - EventChannel `app.mikosea.test/detections`:
///    {ts, mock, frameW, frameH, fx?, detections:[{cls, conf, x, y, w, h}]}
///  - MethodChannel `app.mikosea.test/control`:
///    `start` -> {textureId: Int?}, `stop`.
final class AdasCore: NSObject, FlutterPlugin, FlutterStreamHandler, FlutterTexture,
                      AVCaptureVideoDataOutputSampleBufferDelegate {

  // MARK: - Registration

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = AdasCore(textures: registrar.textures())
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

  private let textures: FlutterTextureRegistry
  private var textureId: Int64 = -1

  init(textures: FlutterTextureRegistry) {
    self.textures = textures
    super.init()
    textureId = textures.register(self)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(orientationChanged),
      name: UIDevice.orientationDidChangeNotification,
      object: nil
    )
  }

  // MARK: - Tuning constants

  /// Minimum interval between inferences (~10 Hz).
  private static let inferenceInterval: TimeInterval = 0.09
  /// ROI side as a fraction of the buffer's short side (960 px of 1080).
  private static let roiShortSideFraction = 8.0 / 9.0
  /// COCO classes forwarded to Flutter.
  private static let allowedClasses: Set<String> = ["car", "truck", "bus", "motorcycle"]
  /// Default focal length (px at 1080p) when intrinsics are unavailable.
  private static let mockFocalPx = 1500.0

  // MARK: - State

  private var sink: FlutterEventSink?
  private let session = AVCaptureSession()
  private let videoOutput = AVCaptureVideoDataOutput()
  private let captureQueue = DispatchQueue(label: "app.mikosea.test.capture")
  private var visionModel: VNCoreMLModel?
  private var modelLoadAttempted = false
  private var cameraConfigured = false
  private var cameraRunning = false
  private var lastInferenceAt = Date.distantPast
  private var latestFx: Double?

  private let bufferLock = NSLock()
  private var latestBuffer: CVPixelBuffer?

  private var mockTimer: Timer?
  private var mockPhase = 0.0

  // Recording (test-mode "Quay"): writes the already-flowing camera buffers
  // to an H.264 .mp4 via the hardware encoder. All state is touched on
  // captureQueue only.
  private var assetWriter: AVAssetWriter?
  private var writerInput: AVAssetWriterInput?
  private var pixelAdaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var recordingURL: URL?
  private var wantRecording = false

  // MARK: - FlutterTexture

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    bufferLock.lock()
    defer { bufferLock.unlock() }
    guard let buffer = latestBuffer else { return nil }
    return Unmanaged.passRetained(buffer)
  }

  // MARK: - FlutterPlugin

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      start()
      result(["textureId": cameraAvailable ? textureId : nil])
    case "stop":
      stop()
      result(nil)
    case "beep":
      AudioServicesPlaySystemSound(1052)
      result(nil)
    case "startRecording":
      guard cameraAvailable else {
        result(false)
        return
      }
      captureQueue.async { self.wantRecording = true }
      result(true)
    case "stopRecording":
      captureQueue.async {
        self.wantRecording = false
        guard let writer = self.assetWriter, let url = self.recordingURL else {
          DispatchQueue.main.async { result(nil) }
          return
        }
        self.writerInput?.markAsFinished()
        self.assetWriter = nil
        self.writerInput = nil
        self.pixelAdaptor = nil
        self.recordingURL = nil
        writer.finishWriting {
          DispatchQueue.main.async {
            result(writer.status == .completed ? url.path : nil)
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var cameraAvailable: Bool {
    #if targetEnvironment(simulator)
      return false
    #else
      return true
    #endif
  }

  // MARK: - FlutterStreamHandler

  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    start()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stop()
    sink = nil
    return nil
  }

  // MARK: - Lifecycle

  private func start() {
    loadModelIfNeeded()
    guard cameraAvailable else {
      startMockEmitter()
      return
    }
    // Mock detections keep flowing until the real model is bundled, so the
    // Flutter side stays alive either way; preview runs regardless.
    if visionModel == nil { startMockEmitter() }
    AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
      guard let self, granted else {
        self?.startMockEmitter()
        return
      }
      self.captureQueue.async {
        self.configureSessionIfNeeded()
        if !self.session.isRunning { self.session.startRunning() }
        self.cameraRunning = true
        // Orientation must be applied AFTER the connection exists. Doing it
        // earlier silently no-ops, and under rotation lock no orientation
        // event ever retries it — the stuck-sideways-preview bug.
        DispatchQueue.main.async { self.applyOrientation() }
      }
    }
  }

  private func stop() {
    stopMockEmitter()
    if cameraRunning {
      captureQueue.async { self.session.stopRunning() }
      cameraRunning = false
    }
  }

  private func loadModelIfNeeded() {
    guard !modelLoadAttempted else { return }
    modelLoadAttempted = true
    guard let url = Bundle.main.url(forResource: "yolo11n", withExtension: "mlmodelc") else {
      NSLog("AdasCore: yolo11n.mlmodelc not bundled — mock detections only")
      return
    }
    do {
      let config = MLModelConfiguration()
      config.computeUnits = .all // prefer the Neural Engine
      let model = try MLModel(contentsOf: url, configuration: config)
      visionModel = try VNCoreMLModel(for: model)
      NSLog("AdasCore: YOLO11n loaded")
    } catch {
      NSLog("AdasCore: model load failed: \(error)")
    }
  }

  // MARK: - Camera

  private func configureSessionIfNeeded() {
    guard !cameraConfigured else { return }
    cameraConfigured = true
    session.beginConfiguration()
    session.sessionPreset = .hd1920x1080
    if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
       let input = try? AVCaptureDeviceInput(device: device),
       session.canAddInput(input) {
      session.addInput(input)
    }
    videoOutput.videoSettings =
      [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
    if session.canAddOutput(videoOutput) {
      session.addOutput(videoOutput)
    }
    if let connection = videoOutput.connection(with: .video),
       connection.isCameraIntrinsicMatrixDeliverySupported {
      connection.isCameraIntrinsicMatrixDeliveryEnabled = true
    }
    session.commitConfiguration()
  }

  @objc private func orientationChanged() {
    applyOrientation()
  }

  /// Rotates delivered buffers upright for the current INTERFACE
  /// orientation, so preview, detections and the Flutter overlay share one
  /// frame space. The interface (not device) orientation is authoritative:
  /// under rotation lock or at cold start the device orientation is
  /// .unknown/.faceUp while the UI is firmly portrait.
  private func applyOrientation() {
    guard cameraConfigured, let connection = videoOutput.connection(with: .video) else { return }
    let angle = Self.rotationAngleForCurrentInterface()
    if #available(iOS 17.0, *) {
      if connection.isVideoRotationAngleSupported(angle) {
        connection.videoRotationAngle = angle
      }
    } else {
      switch angle {
      case 0: connection.videoOrientation = .landscapeRight
      case 180: connection.videoOrientation = .landscapeLeft
      case 270: connection.videoOrientation = .portraitUpsideDown
      default: connection.videoOrientation = .portrait
      }
    }
  }

  /// Must be called on the main thread.
  private static func rotationAngleForCurrentInterface() -> CGFloat {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let orientation = (scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)?
      .interfaceOrientation ?? .portrait
    switch orientation {
    case .landscapeRight: return 0
    case .landscapeLeft: return 180
    case .portraitUpsideDown: return 270
    default: return 90
    }
  }

  // MARK: - Capture delegate

  func captureOutput(_ output: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    bufferLock.lock()
    latestBuffer = pixelBuffer
    bufferLock.unlock()
    textures.textureFrameAvailable(textureId)

    if wantRecording {
      appendRecordingFrame(pixelBuffer, sampleBuffer: sampleBuffer)
    }

    if let attachment = CMGetAttachment(
      sampleBuffer,
      key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
      attachmentModeOut: nil
    ) as? Data {
      let matrix = attachment.withUnsafeBytes { $0.load(as: matrix_float3x3.self) }
      latestFx = Double(matrix.columns.0.x)
    }

    guard let model = visionModel else { return }
    let now = Date()
    guard now.timeIntervalSince(lastInferenceAt) >= Self.inferenceInterval else { return }
    lastInferenceAt = now
    runInference(model: model, on: pixelBuffer)
  }

  // MARK: - Inference

  private func runInference(model: VNCoreMLModel, on pixelBuffer: CVPixelBuffer) {
    let frameW = CVPixelBufferGetWidth(pixelBuffer)
    let frameH = CVPixelBufferGetHeight(pixelBuffer)
    let w = Double(frameW), h = Double(frameH)

    // Centered square ROI on the short side — full resolution, no squeeze.
    let side = min(w, h) * Self.roiShortSideFraction
    let roi = CGRect(
      x: (w - side) / 2 / w,
      y: (h - side) / 2 / h,
      width: side / w,
      height: side / h
    )

    let request = VNCoreMLRequest(model: model)
    request.regionOfInterest = roi
    request.imageCropAndScaleOption = .scaleFill

    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
    do {
      try handler.perform([request])
    } catch {
      return
    }

    var detections: [[String: Any]] = []
    var vehicleBoxes: [CGRect] = []
    for observation in request.results as? [VNRecognizedObjectObservation] ?? [] {
      guard let label = observation.labels.first,
            Self.allowedClasses.contains(label.identifier) else { continue }
      // Vision boxes are normalized within the ROI, origin bottom-left.
      let b = observation.boundingBox
      let boxW = b.width * roi.width * w
      let boxH = b.height * roi.height * h
      let boxX = (roi.minX + b.minX * roi.width) * w
      let boxYTop = (1.0 - (roi.minY + b.maxY * roi.height)) * h
      detections.append([
        "cls": label.identifier,
        "conf": Double(label.confidence),
        "x": boxX,
        "y": boxYTop,
        "w": boxW,
        "h": boxH,
      ])
      vehicleBoxes.append(CGRect(x: boxX, y: boxYTop, width: boxW, height: boxH))
    }

    var frame: [String: Any] = [
      "ts": Int(Date().timeIntervalSince1970 * 1000),
      "mock": false,
      "frameW": frameW,
      "frameH": frameH,
      "fx": latestFx as Any,
      "detections": detections,
    ]
    if let lane = detectLane(in: pixelBuffer, excluding: vehicleBoxes) {
      frame["lane"] = lane
    }
    emit(frame)
  }

  private func emit(_ frame: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.sink?(frame)
    }
  }


  // MARK: - Recording

  private func appendRecordingFrame(_ pixelBuffer: CVPixelBuffer,
                                    sampleBuffer: CMSampleBuffer) {
    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    if assetWriter == nil {
      startWriter(
        width: CVPixelBufferGetWidth(pixelBuffer),
        height: CVPixelBufferGetHeight(pixelBuffer),
        startPTS: pts
      )
    }
    guard let input = writerInput, let adaptor = pixelAdaptor,
          assetWriter?.status == .writing, input.isReadyForMoreMediaData
    else { return }
    adaptor.append(pixelBuffer, withPresentationTime: pts)
  }

  private func startWriter(width: Int, height: Int, startPTS: CMTime) {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "phone_adas_rec_\(Int(Date().timeIntervalSince1970)).mp4")
    guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
    let settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: width,
      AVVideoHeightKey: height,
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = true
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input, sourcePixelBufferAttributes: nil)
    guard writer.canAdd(input) else { return }
    writer.add(input)
    guard writer.startWriting() else { return }
    writer.startSession(atSourceTime: startPTS)
    assetWriter = writer
    writerInput = input
    pixelAdaptor = adaptor
    recordingURL = url
  }

  // MARK: - Lane detection (test-mode, classic CV)

  private var prevLeftFit: (a: Double, b: Double)?
  private var prevRightFit: (a: Double, b: Double)?
  private var laneMissCount = 0

  /// Finds the ego-lane boundaries as painted STRIPES: a candidate pixel
  /// must be brighter than BOTH sides (top-hat test), so curbs, medians and
  /// shadow edges — which only contrast on one side — cannot win. Per row
  /// the stripe NEAREST the image center is taken (the ego-lane boundary is
  /// by definition the innermost marking), regions covered by detected
  /// vehicles are skipped, the fit gets one outlier-trimming round, and the
  /// result is tracked across frames (guided search window + EMA smoothing).
  private func detectLane(in pixelBuffer: CVPixelBuffer,
                          excluding boxes: [CGRect]) -> [String: Any]? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return laneMiss() }
    let w = CVPixelBufferGetWidth(pixelBuffer)
    let h = CVPixelBufferGetHeight(pixelBuffer)
    let rowStride = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let ptr = base.assumingMemoryBound(to: UInt8.self)

    let scale = Double(w) / 1920.0
    // Stop above the hood/dashboard: real mounts show the dash from ~78%
    // down, and its reflections fit as fake splayed lane lines.
    let yTop = Int(Double(h) * 0.58)
    let yBot = Int(Double(h) * 0.80)
    let xMid = w / 2
    let xSpan = Int(Double(w) * 0.45)
    let stepY = max(1, (yBot - yTop) / 26)
    let stepX = max(2, Int(3 * scale))
    let brightThr = 18
    let trackWindow = Int(90 * scale)

    var leftPts: [(y: Double, x: Double)] = []
    var rightPts: [(y: Double, x: Double)] = []
    var scannedRows = 0
    var y = yTop
    while y < yBot {
      scannedRows += 1
      let row = ptr + y * rowStride
      func lum(_ x: Int) -> Int { Int(row[x * 4 + 1]) }
      // Expected stripe half-width grows toward the camera (perspective).
      let t = Double(y - yTop) / Double(max(1, yBot - yTop))
      let off = max(3, Int((6 + 16 * t) * scale))
      func blocked(_ x: Int) -> Bool {
        let p = CGPoint(x: Double(x), y: Double(y))
        return boxes.contains { $0.insetBy(dx: -10, dy: -10).contains(p) }
      }
      func isStripe(_ x: Int) -> Bool {
        guard x - off - stepX >= 0, x + off + stepX < w, !blocked(x) else { return false }
        let c = lum(x)
        return c - lum(x - off) > brightThr && c - lum(x + off) > brightThr
      }
      func scanSide(prev: (a: Double, b: Double)?, isLeft: Bool) -> Int {
        if let fit = prev {
          // Tracking: search only near the previous line's position.
          let cx = Int(fit.a * Double(y) + fit.b)
          let inner = isLeft ? min(cx + trackWindow, xMid - stepX)
                             : max(cx - trackWindow, xMid + stepX)
          let outer = isLeft ? max(cx - trackWindow, xMid - xSpan)
                             : min(cx + trackWindow, xMid + xSpan)
          var x = inner
          while isLeft ? x > outer : x < outer {
            if isStripe(x) { return x }
            x += isLeft ? -stepX : stepX
          }
          return -1
        }
        // Acquisition: nearest stripe to the center wins.
        var x = isLeft ? xMid - off - stepX : xMid + off + stepX
        while isLeft ? x > xMid - xSpan : x < xMid + xSpan {
          if isStripe(x) { return x }
          x += isLeft ? -stepX : stepX
        }
        return -1
      }
      let xl = scanSide(prev: prevLeftFit, isLeft: true)
      if xl >= 0 { leftPts.append((Double(y), Double(xl))) }
      let xr = scanSide(prev: prevRightFit, isLeft: false)
      if xr >= 0 { rightPts.append((Double(y), Double(xr))) }
      y += stepY
    }

    guard leftPts.count >= 7, rightPts.count >= 7,
          var l = Self.fitLineTrimmed(leftPts),
          var r = Self.fitLineTrimmed(rightPts)
    else { return laneMiss() }

    // Temporal smoothing: lane geometry changes slowly at 10 Hz.
    if let p = prevLeftFit { l = (a: p.a * 0.6 + l.a * 0.4, b: p.b * 0.6 + l.b * 0.4) }
    if let p = prevRightFit { r = (a: p.a * 0.6 + r.a * 0.4, b: p.b * 0.6 + r.b * 0.4) }

    let yB = Double(yBot), yT = Double(yTop)
    let xlB = l.a * yB + l.b, xrB = r.a * yB + r.b
    let laneWidth = xrB - xlB

    // Geometry gates a REAL ego lane must satisfy; anything else (dashboard
    // reflections, curbs, road edges) is dropped rather than drawn wrong:
    // 1. plausible width at the scan floor (a 3.5 m lane spans ~25-35% of
    //    the frame there — the dashboard fit spanned ~75%);
    // 2. the two lines converge: left leans right going up, right leans left;
    // 3. their intersection (vanishing point) sits near the horizon band;
    // 4. the lane center at the bottom is near the image center.
    guard laneWidth > Double(w) * 0.16, laneWidth < Double(w) * 0.45,
          xlB < Double(xMid), xrB > Double(xMid)
    else { return laneMiss() }
    guard l.a < -0.05, r.a > 0.05 else { return laneMiss() }
    let slopeDenom = l.a - r.a
    guard abs(slopeDenom) > 1e-6 else { return laneMiss() }
    let vanishY = (r.b - l.b) / slopeDenom
    guard vanishY > Double(h) * 0.25, vanishY < Double(h) * 0.65
    else { return laneMiss() }
    guard abs((xlB + xrB) / 2 - Double(xMid)) < Double(w) * 0.18
    else { return laneMiss() }

    prevLeftFit = l
    prevRightFit = r
    laneMissCount = 0

    let center = (xlB + xrB) / 2
    let offset = (Double(xMid) - center) / (laneWidth / 2)
    let conf = Double(min(leftPts.count, rightPts.count)) / Double(max(1, scannedRows))
    return [
      "left": [xlB, yB, l.a * yT + l.b, yT],
      "right": [xrB, yB, r.a * yT + r.b, yT],
      "offset": max(-2.0, min(2.0, offset)),
      "conf": min(1.0, conf),
    ]
  }

  /// Records a miss; tracking state survives short dropouts (dashed lines,
  /// crossings) and resets after ~1.2 s without a lane.
  private func laneMiss() -> [String: Any]? {
    laneMissCount += 1
    if laneMissCount > 12 {
      prevLeftFit = nil
      prevRightFit = nil
    }
    return nil
  }

  /// Least-squares fit of x = a*y + b with one MAD-based trimming round.
  private static func fitLineTrimmed(
    _ pts: [(y: Double, x: Double)]
  ) -> (a: Double, b: Double)? {
    guard let first = fitLine(pts) else { return nil }
    let residuals = pts.map { abs($0.x - (first.a * $0.y + first.b)) }
    let sorted = residuals.sorted()
    let mad = sorted[sorted.count / 2]
    let cut = Swift.max(4.0, mad * 2.5)
    let kept = zip(pts, residuals).filter { $0.1 <= cut }.map { $0.0 }
    guard kept.count >= 6, let refit = fitLine(kept) else { return first }
    return refit
  }

  /// Least-squares fit of x = a*y + b.
  private static func fitLine(_ pts: [(y: Double, x: Double)]) -> (a: Double, b: Double)? {
    let n = Double(pts.count)
    var sy = 0.0, sx = 0.0, syy = 0.0, syx = 0.0
    for p in pts { sy += p.y; sx += p.x; syy += p.y * p.y; syx += p.y * p.x }
    let denom = n * syy - sy * sy
    guard abs(denom) > 1e-6 else { return nil }
    let a = (n * syx - sy * sx) / denom
    let b = (sx - a * sy) / n
    return (a, b)
  }

  // MARK: - Mock emitter (simulator / model missing / permission denied)

  private func startMockEmitter() {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.mockTimer == nil else { return }
      self.mockTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
        self?.emitMockFrame()
      }
    }
  }

  private func stopMockEmitter() {
    DispatchQueue.main.async { [weak self] in
      self?.mockTimer?.invalidate()
      self?.mockTimer = nil
    }
  }

  private func emitMockFrame() {
    guard sink != nil else { return }
    mockPhase += 0.1
    // Three mock vehicles matching the product mockup:
    // motorcycle left ~6 m, car center drifting 30-70 m, car right ~25 m.
    let dMoto = 6.2 + 0.4 * sin(mockPhase / 1.7)
    let dCenter = 50.0 + 20.0 * sin(mockPhase / 3.0)
    let dRight = 25.4 + 1.5 * sin(mockPhase / 2.3)
    func box(_ cls: String, _ cx: Double, _ groundY: Double, _ realW: Double,
             _ d: Double, _ hRatio: Double, _ conf: Double) -> [String: Any] {
      let w = realW * Self.mockFocalPx / d
      let h = w * hRatio
      return ["cls": cls, "conf": conf, "x": cx - w / 2.0, "y": groundY - h, "w": w, "h": h]
    }
    emit([
      "ts": Int(Date().timeIntervalSince1970 * 1000),
      "mock": true,
      "frameW": 1920,
      "frameH": 1080,
      "fx": Self.mockFocalPx,
      "detections": [
        box("motorcycle", 620, 760, 0.8, dMoto, 1.6, 0.88),
        box("car", 960, 620, 1.8, dCenter, 0.8, 0.93),
        box("car", 1330, 660, 1.8, dRight, 0.8, 0.91),
      ],
      "lane": [
        "left": [760.0 - 80.0 * sin(mockPhase / 7.0), 1080.0, 880.0, 626.0],
        "right": [1160.0 - 80.0 * sin(mockPhase / 7.0), 1080.0, 1040.0, 626.0],
        "offset": 0.65 * sin(mockPhase / 7.0),
        "conf": 0.9,
      ] as [String: Any],
    ])
  }
}
