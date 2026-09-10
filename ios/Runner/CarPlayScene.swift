import CarPlay
import Foundation
import UIKit

/// Bridge between the Flutter side (AdasCore control channel pushes
/// pre-localized strings at ~1 Hz) and the CarPlay scene. The scene only
/// exists when Apple's CarPlay "driving task" entitlement is present in the
/// provisioning profile; without it this file is dormant dead weight.
final class CarplayBridge {
  static let shared = CarplayBridge()

  private let lock = NSLock()
  private var values: [String: String] = [:]
  private var updatedAt = Date.distantPast
  var onChange: (() -> Void)?

  func update(_ newValues: [String: String]) {
    lock.lock()
    values = newValues
    updatedAt = Date()
    lock.unlock()
    DispatchQueue.main.async { [weak self] in self?.onChange?() }
  }

  func snapshot() -> (values: [String: String], updatedAt: Date) {
    lock.lock()
    defer { lock.unlock() }
    return (values, updatedAt)
  }
}

/// CarPlay "driving task" scene: a template-based readout of the lead
/// distance, speed, weather and current area. The camera/AR view stays on
/// the phone (CarPlay forbids live video for this category); the phone app
/// must be in the foreground for the pipeline to run, so this display goes
/// stale-dashed within 5 s of the app leaving the foreground.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  private var interfaceController: CPInterfaceController?
  private var staleTimer: Timer?

  func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                didConnect interfaceController: CPInterfaceController) {
    self.interfaceController = interfaceController
    CarplayBridge.shared.onChange = { [weak self] in self?.refresh() }
    interfaceController.setRootTemplate(buildTemplate(), animated: false,
                                        completion: nil)
    staleTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) {
      [weak self] _ in self?.refresh()
    }
  }

  func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                didDisconnectInterfaceController interfaceController: CPInterfaceController) {
    staleTimer?.invalidate()
    staleTimer = nil
    CarplayBridge.shared.onChange = nil
    self.interfaceController = nil
  }

  private func items() -> [CPInformationItem] {
    let (v, at) = CarplayBridge.shared.snapshot()
    let stale = Date().timeIntervalSince(at) > 5
    func val(_ key: String) -> String {
      stale ? "—" : (v[key]?.isEmpty == false ? v[key]! : "—")
    }
    var rows = [
      CPInformationItem(title: v["distLabel"] ?? "Distance", detail: val("dist")),
      CPInformationItem(title: v["speedLabel"] ?? "Speed", detail: val("speed")),
    ]
    if let gap = v["gap"], !gap.isEmpty {
      rows.append(CPInformationItem(
        title: v["gapLabel"] ?? "Minimum gap", detail: stale ? "—" : gap))
    }
    rows.append(CPInformationItem(
      title: v["weatherLabel"] ?? "Weather", detail: val("weather")))
    rows.append(CPInformationItem(
      title: v["areaLabel"] ?? "Area", detail: val("area")))
    return rows
  }

  private func buildTemplate() -> CPInformationTemplate {
    CPInformationTemplate(
      title: "Phone ADAS", layout: .twoColumn, items: items(), actions: [])
  }

  private func refresh() {
    guard let controller = interfaceController else { return }
    if let template = controller.rootTemplate as? CPInformationTemplate {
      template.items = items()
    } else {
      controller.setRootTemplate(buildTemplate(), animated: false, completion: nil)
    }
  }
}
