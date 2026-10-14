import AppKit
import SwiftUI

struct RemoveMacAIApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate
  @State private var model = AppModel()

  var body: some Scene {
    Window("RemoveMacAI", id: "main") {
      ContentView()
        .environment(model)
        .frame(minWidth: 860, minHeight: 600)
    }
    .defaultSize(width: 1000, height: 700)
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(replacing: .appInfo) {
        Button("关于 RemoveMacAI") { AppDelegate.showAbout() }
      }
      CommandGroup(after: .toolbar) {
        Button("重新载入") { model.reload(resetChoices: true) }.keyboardShortcut("r")
      }
      CommandGroup(replacing: .help) {
        Button("RemoveMacAI 工作原理") { model.openWelcome() }
        Divider()
        Link("GitHub 上的 RemoveMacAI", destination: URL(string: "https://github.com/omlahore/RemoveMacAI")!)
        Link("报告问题", destination: URL(string: "https://github.com/omlahore/RemoveMacAI/issues/new/choose")!)
      }
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    // A bare binary run from Terminal has no bundle, so it must ask to be a real app.
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    #if DEBUG
      if let dir = ProcessInfo.processInfo.environment["REMOVEMACAI_SNAPSHOTS"] { Snapshots.run(into: dir) }
    #endif
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

  static func showAbout() {
    let credits = NSMutableAttributedString(
      string: "精简 macOS，且每项更改都可撤销。\n\nApple 智能部分基于 4evy 的 pared，该项目最先绘制了 Apple 资产服务和模型集的分布。",
      attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
    NSApp.orderFrontStandardAboutPanel(options: [
      .applicationName: "RemoveMacAI",
      .applicationVersion: version,
      .version: "",
      .credits: credits,
    ])
  }
}
