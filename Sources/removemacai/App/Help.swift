import SwiftUI

/// Small pieces that explain things: help popovers, numbered steps, the
/// safety promises and a drawing of the System Settings profile screen.

struct InfoButton: View {
  let title: String
  let text: String
  @State private var shown = false

  var body: some View {
    Button { shown.toggle() } label: {
      Image(systemName: "info.circle").foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .help(title)
    .accessibilityLabel("关于\(title)")
    .popover(isPresented: $shown, arrowEdge: .bottom) {
      VStack(alignment: .leading, spacing: 6) {
        Text(title).font(.headline)
        Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
      .padding(14)
      .frame(width: 300, alignment: .leading)
    }
  }
}

enum Explain {
  static let profile = (
    "描述文件",
    "macOS 只允许通过描述文件锁定这些设置，学校和企业管理 Mac 用的也是同样的东西。RemoveMacAI 会向您展示其内容，由您亲自在系统设置中安装。之后随时可在那里移除，或使用撤销。"
  )
  static let models = (
    "Apple 智能模型",
    "Apple 智能运行所需的文件，无论您是否使用这些功能，macOS 都会下载。删除它们即可释放空间。如果重新开启某项功能，macOS 会重新下载所需的文件。"
  )
  static let locked = (
    "由描述文件保持关闭",
    "此设置由 RemoveMacAI 描述文件保持关闭，macOS 更新或误点都无法将其重新开启。撤销会移除描述文件，让您重新掌控该开关。"
  )
}

struct StepBadge: View {
  let number: Int
  var done = false
  var active = true

  var body: some View {
    ZStack {
      Circle().fill(done ? Color.green : (active ? Color.accentColor : Color.secondary.opacity(0.25)))
      if done {
        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
      } else {
        Text("\(number)").font(.caption.weight(.bold).monospacedDigit())
          .foregroundStyle(active ? Color.white : Color.secondary)
      }
    }
    .frame(width: 22, height: 22)
    .accessibilityHidden(true)
  }
}

struct Promise: Identifiable {
  let id = UUID()
  let symbol: String
  let title: String
  let detail: String
  var tint: Color = .accentColor
}

enum Promises {
  static let all: [Promise] = [
    Promise(symbol: "eye", title: "您先看到每一项更改", detail: "在您查看列表并点按“应用”之前，不会发生任何更改。"),
    Promise(symbol: "arrow.uturn.backward", title: "一切都可以撤销", detail: "撤销会还原每项设置。已删除的模型会在功能需要时重新下载。"),
    Promise(symbol: "checkmark.shield", title: "您的 Mac 保持受保护", detail: "系统完整性保护（SIP）保持开启。/System 内不会改动任何内容。", tint: .green),
    Promise(symbol: "wifi.slash", title: "没有任何内容离开您的 Mac", detail: "无账户、无分析、无网络请求。代码在 GitHub 上公开。", tint: .green),
  ]
}

struct PromiseCard: View {
  let promise: Promise

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: promise.symbol)
        .font(.title2)
        .foregroundStyle(promise.tint)
        .frame(width: 28)
      VStack(alignment: .leading, spacing: 3) {
        Text(promise.title).font(.headline)
        Text(promise.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5)))
    .accessibilityElement(children: .combine)
  }
}

struct SafetyCard: View {
  @Environment(\.openURL) private var openURL
  var showWelcome: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("设计上即安全", systemImage: "checkmark.shield.fill")
        .font(.headline)
        .foregroundStyle(.green)
      Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
        GridRow {
          check("每次更改前您都会先确认")
          check("撤销可还原一切")
        }
        GridRow {
          check("系统完整性保护保持开启")
          check("无网络请求，无分析")
        }
      }
      HStack(spacing: 18) {
        Button("在 GitHub 上阅读代码") { openURL(URL(string: "https://github.com/omlahore/RemoveMacAI")!) }
        Button("RemoveMacAI 工作原理") { showWelcome() }
      }
      .buttonStyle(.link)
      .font(.callout)
    }
  }

  func check(_ text: String) -> some View {
    Label {
      Text(text).foregroundStyle(.primary)
    } icon: {
      Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.green)
    }
    .font(.callout)
  }
}

/// A drawing of System Settings at General > Device Management, with the
/// RemoveMacAI profile and its Install button marked. Drawn, not a
/// screenshot, so it stays sharp and follows light and dark mode.
struct SettingsGuide: View {
  var remove = false
  @State private var pulse = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 6) {
        Circle().fill(Color(red: 1, green: 0.37, blue: 0.34)).frame(width: 10, height: 10)
        Circle().fill(Color(red: 1, green: 0.74, blue: 0.18)).frame(width: 10, height: 10)
        Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25)).frame(width: 10, height: 10)
        Text("系统设置").font(.caption).foregroundStyle(.secondary).padding(.leading, 6)
        Spacer()
      }
      .padding(.horizontal, 10)
      .frame(height: 28)
      .background(.quaternary.opacity(0.6))
      HStack(alignment: .top, spacing: 0) {
        VStack(alignment: .leading, spacing: 7) {
          ForEach(["Wi-Fi", "蓝牙", "网络"], id: \.self) { Text($0) }
          Text("通用")
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor))
          ForEach(["外观", "隐私与安全性"], id: \.self) { Text($0) }
        }
        .font(.caption)
        .padding(10)
        .frame(width: 120, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.quaternary.opacity(0.35))
        VStack(alignment: .leading, spacing: 9) {
          Text("通用 › 设备管理").font(.caption).foregroundStyle(.secondary)
          Text(remove ? "描述文件" : "已下载").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
          HStack(spacing: 8) {
            Image(systemName: "checkmark.shield")
            VStack(alignment: .leading, spacing: 1) {
              Text("RemoveMacAI").font(.caption.weight(.semibold))
              Text(remove ? "选择后点按 −" : "连按以查看").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
          }
          .padding(8)
          .background(RoundedRectangle(cornerRadius: 7).fill(.background))
          .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.accentColor, lineWidth: pulse ? 3 : 1.5))
          VStack(alignment: .leading, spacing: 8) {
            Text(remove ? "移除“RemoveMacAI”？" : "“RemoveMacAI”想要安装").font(.caption2).foregroundStyle(.secondary)
            HStack(spacing: 6) {
              Spacer()
              Text("取消").font(.caption2)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).stroke(.tertiary))
              Text(remove ? "移除" : "安装…").font(.caption2.weight(.semibold)).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.accentColor.opacity(0.5), lineWidth: pulse ? 4 : 0).padding(-3))
            }
          }
          .padding(8)
          .background(RoundedRectangle(cornerRadius: 7).fill(.background))
          Spacer(minLength: 0)
        }
        .padding(10)
      }
      .frame(height: 200)
    }
    .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      remove
        ? "系统设置、通用、设备管理。选择 RemoveMacAI 描述文件，然后点按减号按钮将其移除。"
        : "系统设置、通用、设备管理。连按“已下载”下的 RemoveMacAI 描述文件，然后点按“安装”。")
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
    }
  }
}
