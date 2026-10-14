import AppKit
import SwiftUI

struct ContentView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    NavigationSplitView {
      Sidebar()
        .navigationSplitViewColumnWidth(min: 210, ideal: 230)
    } detail: {
      DetailView(page: model.page ?? .overview)
        .safeAreaInset(edge: .bottom, spacing: 0) {
          if model.pendingCount > 0 { PendingBar() }
        }
    }
    .sheet(isPresented: $model.showingWelcome) { WelcomeSheet() }
    .sheet(isPresented: $model.reviewing) { ReviewSheet() }
    .sheet(isPresented: Binding(get: { model.run != nil }, set: { if !$0 { model.dismissRun() } })) {
      RunSheet()
    }
  }
}

struct DetailView: View {
  let page: Page

  var body: some View {
    switch page {
    case .overview: OverviewView()
    case .intelligence: IntelligenceView()
    case .group(let group): TweakGroupView(group: group)
    case .background: BackgroundView()
    case .storage: StorageView()
    case .changes: ChangesView()
    }
  }
}

// MARK: - Sidebar

struct Sidebar: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    List(selection: $model.page) {
      row(.overview)
      Section("关闭") {
        row(.intelligence, badge: model.aiPending ? Text("1") : nil)
        ForEach([TweakGroup.privacy, .annoyances, .apps], id: \.self) { group in
          row(.group(group), badge: count(group))
        }
        row(.background)
      }
      Section("自定义") {
        ForEach([TweakGroup.finder, .windows, .typing], id: \.self) { group in
          row(.group(group), badge: count(group))
        }
      }
      Section("清理") {
        row(.storage)
        row(.changes)
      }
    }
    .listStyle(.sidebar)
    .safeAreaInset(edge: .bottom, spacing: 0) {
      Button { model.openWelcome() } label: {
        Label("RemoveMacAI 工作原理", systemImage: "questionmark.circle")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
    }
  }

  func row(_ page: Page, badge: Text? = nil) -> some View {
    Label(page.title, systemImage: page.symbol)
      .badge(badge)
      .tag(page)
  }

  func count(_ group: TweakGroup) -> Text? {
    let c = model.switchedOn(in: group)
    return c.on > 0 ? Text("\(c.on) / \(c.total)") : nil
  }
}

// MARK: - Bottom bar and review

struct PendingBar: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(.tint)
      VStack(alignment: .leading, spacing: 1) {
        Text(model.pendingCount == 1 ? "1 项更改待确认" : "\(model.pendingCount) 项更改待确认")
          .font(.callout.weight(.medium))
        Text("尚未更改任何内容。您会先看到完整列表。")
          .font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Button("放弃") { model.discard() }
      Button("检查并应用…") { model.reviewing = true }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 10)
    .background(.bar)
    .overlay(alignment: .top) { Divider() }
  }
}

struct ReviewSheet: View {
  @Environment(AppModel.self) private var model
  @State private var plan: Plan?
  @State private var showCommands = false

  var changeCount: Int {
    guard let plan else { return 0 }
    return plan.apply.count + plan.revert.count + (model.aiPending ? 1 : 0)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 10) {
        Text(changeCount == 1 ? "确认 1 项更改" : "确认 \(changeCount) 项更改").font(.title2.weight(.bold))
        if let plan {
          HStack(spacing: 8) {
            if !plan.models.isEmpty, let bytes = model.modelBytes(plan.models), bytes > 0 {
              chip("可释放约 \(Term.size(bytes))", color: .green)
            }
            chip("随时可撤销", color: .accentColor)
            if plan.profile.map({ !$0.isEmpty }) ?? false {
              chip("需要输入一次密码", color: .secondary)
            }
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.top, 22)
      .padding(.bottom, 14)
      Divider()
      if let plan {
        List {
          if model.aiPending || !plan.models.isEmpty {
            Section("Apple 智能") {
              if model.aiPending, let kept = model.targetAI {
                Label(
                  kept.isEmpty ? "关闭所有功能" : "关闭除 \(kept.count) 项保留功能以外的所有内容",
                  systemImage: "apple.intelligence")
              } else if model.aiPending {
                Label("重新开启 Apple 智能。macOS 会在功能需要时重新下载其模型。", systemImage: "arrow.uturn.backward")
              }
              if !plan.models.isEmpty {
                let bytes = model.modelBytes(plan.models)
                Label {
                  HStack {
                    Text(bytes.map { $0 > 0 ? "删除模型，约 \(Term.size($0))" : "让 macOS 完成残留模型文件的移除" } ?? "删除模型")
                    Spacer()
                    Text("macOS 可重新下载").font(.caption).foregroundStyle(.secondary)
                  }
                } icon: {
                  Image(systemName: "trash")
                }
              }
            }
          }
          if !plan.apply.isEmpty {
            Section("开启或关闭") {
              ForEach(plan.apply) { t in ChangeRow(tweak: t, adding: true, showCommands: showCommands) }
            }
          }
          if !plan.revert.isEmpty {
            Section("还原") {
              ForEach(plan.revert) { t in ChangeRow(tweak: t, adding: false, showCommands: showCommands) }
            }
          }
          if let profile = plan.profile {
            Section("点击“应用”后会发生什么") {
              if profile.isEmpty {
                step(1, "您的设置会更改。这需要几秒钟。")
                step(2, "系统设置会打开，以便您移除 RemoveMacAI 描述文件。我们会告诉您位置。")
              } else {
                step(1, "不需要描述文件的设置会立即更改。")
                step(2, "系统设置会打开，您在其中安装 RemoveMacAI 描述文件。我们会告诉您位置。")
                if !plan.models.isEmpty { step(3, "模型会被删除，然后您会看到摘要。") }
              }
            }
          }
        }
        .listStyle(.inset)
      } else {
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      Divider()
      HStack {
        Toggle("显示具体设置", isOn: $showCommands)
          .toggleStyle(.checkbox)
          .help("显示每项更改背后的命令或描述文件键")
        Spacer()
        Button("取消", role: .cancel) { model.reviewing = false }
          .keyboardShortcut(.cancelAction)
        Button(changeCount == 1 ? "应用更改" : "应用 \(changeCount) 项更改") { model.apply() }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
          .disabled(plan?.isEmpty ?? true)
      }
      .controlSize(.large)
      .padding(16)
    }
    .frame(width: 640, height: 600)
    .task {
      let wanted = model.wanted
      let ai = model.targetAI
      let snapshot = model.snapshot
      plan = await Task.detached { Plan.make(wanted: wanted, ai: ai, snapshot: snapshot) }.value
    }
  }

  func chip(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.caption.weight(.semibold))
      .foregroundStyle(color == .secondary ? Color.secondary : color)
      .padding(.horizontal, 9).padding(.vertical, 4)
      .background(Capsule().fill(color.opacity(0.13)))
  }

  func step(_ n: Int, _ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      StepBadge(number: n)
      Text(text).fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct ChangeRow: View {
  let tweak: Tweak
  let adding: Bool
  var showCommands = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Image(systemName: adding ? "plus.circle.fill" : "arrow.uturn.backward.circle.fill")
          .foregroundStyle(adding ? Color.accentColor : .orange)
        Text(tweak.title)
        if tweak.inProfile {
          Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
            .help("由 RemoveMacAI 描述文件保持锁定")
        }
        Spacer()
      }
      if showCommands {
        VStack(alignment: .leading, spacing: 2) {
          ForEach(tweak.changes.indices, id: \.self) { i in
            Text(tweak.changes[i].command)
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
              .textSelection(.enabled)
          }
        }
        .padding(.leading, 26)
      }
    }
    .padding(.vertical, 2)
  }
}

// MARK: - Running

struct RunSheet: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Group {
      switch model.run {
      case .working(let text)?:
        VStack(spacing: 16) {
          ProgressView().controlSize(.large)
          Text(text).font(.headline)
          Text("这需要几秒钟。").foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(width: 420)
      case .approveProfile(let remove)?:
        ApproveProfileView(remove: remove)
      case .finished(let problems, let freed)?:
        FinishedView(problems: problems, freed: freed)
      case nil:
        EmptyView()
      }
    }
    .interactiveDismissDisabled()
  }
}

struct ApproveProfileView: View {
  @Environment(AppModel.self) private var model
  let remove: Bool
  @State private var showContents = false
  @State private var showTrouble = false

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 6) {
        Text(remove ? "在系统设置中移除描述文件" : "在系统设置中完成最后一步")
          .font(.title2.weight(.bold))
        Text(remove
          ? "macOS 需要您亲自移除 RemoveMacAI 描述文件。系统设置已打开。"
          : "macOS 需要您亲自安装 RemoveMacAI 描述文件。系统设置已打开。")
          .foregroundStyle(.secondary)
      }
      HStack(alignment: .top, spacing: 22) {
        SettingsGuide(remove: remove)
          .frame(width: 360)
        VStack(alignment: .leading, spacing: 14) {
          if remove {
            stepRow(1, "选择 RemoveMacAI", "位于“通用” › “设备管理”下。", active: true)
            stepRow(2, "点按减号按钮，然后点按“移除”", "如果 macOS 要求，请输入密码。", active: false)
          } else {
            stepRow(0, "不需要描述文件的设置已完成", nil, active: false, done: true)
            stepRow(2, "连按“已下载”下的 RemoveMacAI", "位于“通用” › “设备管理”。", active: true)
            stepRow(3, "点按“安装”，然后输入密码", "macOS 可能会提示描述文件未签名。对于并非来自公司的免费应用，这属于正常现象。", active: false)
          }
          HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(remove ? "等待您移除…" : "等待您安装…").foregroundStyle(.secondary)
          }
          .padding(.top, 2)
        }
      }
      if !remove {
        DisclosureGroup("此描述文件包含什么？", isExpanded: $showContents) {
          VStack(alignment: .leading, spacing: 8) {
            Text("它会关闭您选择的 Apple 智能功能，将模型下载指向本机上的一个封闭地址以阻止 macOS 再次获取，并锁定标记有锁图标的设置。仅此而已。")
              .fixedSize(horizontal: false, vertical: true)
            Button("显示描述文件") { NSWorkspace.shared.activateFileViewerSelecting([Profile.file]) }
              .buttonStyle(.link)
          }
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(.top, 6)
        }
      }
      DisclosureGroup("出了点问题", isExpanded: $showTrouble) {
        Text("如果系统设置显示描述文件无法\(remove ? "移除" : "安装")，请在此处点按“取消”。您的 Mac 会保持原样，您可以通过“帮助” › “报告问题”在 GitHub 上报告。")
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 6)
      }
      HStack {
        Button("取消") { model.cancel() }
        Spacer()
        Button("显示系统设置") { Commands.openProfileSettings() }
          .buttonStyle(.borderedProminent)
      }
      .controlSize(.large)
    }
    .padding(26)
    .frame(width: 760)
    .fixedSize(horizontal: false, vertical: true)
  }

  func stepRow(_ n: Int, _ title: String, _ detail: String?, active: Bool, done: Bool = false) -> some View {
    HStack(alignment: .top, spacing: 10) {
      StepBadge(number: n, done: done, active: active)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.callout.weight(done ? .regular : .semibold))
          .foregroundStyle(done ? .secondary : .primary)
          .fixedSize(horizontal: false, vertical: true)
        if let detail {
          Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }
}

struct FinishedView: View {
  @Environment(AppModel.self) private var model
  let problems: [String]
  let freed: Int64?

  var body: some View {
    VStack(spacing: 16) {
      ZStack {
        Circle().fill((problems.isEmpty ? Color.green : Color.orange).opacity(0.15)).frame(width: 64, height: 64)
        Image(systemName: problems.isEmpty ? "checkmark" : "exclamationmark.triangle.fill")
          .font(.system(size: 28, weight: .bold))
          .foregroundStyle(problems.isEmpty ? Color.green : Color.orange)
      }
      .accessibilityHidden(true)
      Text(problems.isEmpty ? "全部完成" : "已完成，但有一些问题").font(.title2.weight(.bold))
      if let freed, freed > 0 {
        Text("已删除 \(Term.size(freed)) 的 Apple 智能模型。macOS 会按自己的计划清除文件，因此“储存”设置可能会在一段时间内显示旧的大小。")
          .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 420)
          .fixedSize(horizontal: false, vertical: true)
      }
      if !problems.isEmpty {
        ScrollView {
          VStack(alignment: .leading, spacing: 6) {
            ForEach(problems, id: \.self) { Text("• " + $0).textSelection(.enabled) }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 440, maxHeight: 160)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5)))
      }
      Text("改变主意了？侧边栏中的“撤销”可还原所有内容。")
        .font(.callout).foregroundStyle(.secondary)
      HStack(spacing: 10) {
        Button("查看更改内容") {
          model.dismissRun()
          model.page = .changes
        }
        Button("完成") { model.dismissRun() }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
      }
      .controlSize(.large)
      .padding(.top, 4)
    }
    .padding(32)
    .frame(width: 520)
  }
}
