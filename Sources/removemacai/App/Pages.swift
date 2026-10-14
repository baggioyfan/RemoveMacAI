import SwiftUI

// MARK: - Overview

struct OverviewView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        StatusHero()
        HStack(spacing: 12) {
          StatTile(title: "已更改的设置", value: "\(model.appliedCount) / \(model.availableCount)", link: model.appliedCount > 0 ? "查看详情" : "浏览设置") {
            model.page = .group(TweakGroup.allCases.first { model.switchedOn(in: $0).on > 0 } ?? .privacy)
          }
          StatTile(title: "后台运行的应用", value: model.background.isEmpty ? "无" : "\(model.background.count)", link: "查看列表") {
            model.page = .background
          }
          StatTile(
            title: "可释放的空间",
            value: model.scanned ? Term.size(model.storage.reduce(0) { $0 + $1.bytes }) : "未检查",
            link: model.scanned ? "旧安装包与缓存" : "立即检查"
          ) {
            model.page = .storage
            if !model.scanned && !model.scanning { model.scan() }
          }
        }
        VStack(alignment: .leading, spacing: 10) {
          Text("或从预设开始").font(.headline)
          VStack(spacing: 0) {
            ForEach(Array(Preset.allCases.enumerated()), id: \.element) { i, preset in
              if i > 0 { Divider().padding(.leading, 56) }
              HStack(alignment: .top, spacing: 14) {
                Image(systemName: preset == .recommended ? "checkmark.seal" : "hand.raised")
                  .font(.title2).foregroundStyle(.tint).frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                  Text(preset.title).font(.headline)
                  Text(preset.summary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                  Text("共 \(Tweaks.preset(preset).count) 项设置，并关闭 Apple 智能")
                    .font(.caption).foregroundStyle(.tertiary)
                }
                Spacer()
                Button("确认…") {
                  model.choose(preset)
                  model.reviewing = true
                }
              }
              .padding(14)
            }
          }
          .card()
          Footer("预设会叠加在已应用的设置之上，并且在您确认之前不会更改任何内容。")
        }
        SafetyCard { model.openWelcome() }
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .card()
        Text("RemoveMacAI 的 Apple 智能移除功能基于 4evy 的 [pared](https://github.com/4evy/pared)。")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .tint(.secondary)
      }
      .padding(24)
      .frame(maxWidth: 820)
      .frame(maxWidth: .infinity)
    }
    .navigationTitle("总览")
  }
}

/// Apple Intelligence's state, how much space it takes, and the main action.
struct StatusHero: View {
  @Environment(AppModel.self) private var model

  var off: Bool { model.currentAI != nil }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 16) {
        ZStack {
          RoundedRectangle(cornerRadius: 12).fill((off ? Color.green : Color.orange).opacity(0.15))
          Image(systemName: off ? "checkmark.shield.fill" : "apple.intelligence")
            .font(.system(size: 24))
            .foregroundStyle(off ? Color.green : Color.orange)
        }
        .frame(width: 52, height: 52)
        .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 3) {
          Text(off ? "Apple 智能已关闭" : "Apple 智能已开启")
            .font(.title2.weight(.bold))
          Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
      if !off && model.modelTotal > 0, let disk = DiskSize.total {
        ProgressView(value: Double(model.modelTotal), total: Double(max(disk, model.modelTotal)))
          .tint(.orange)
          .accessibilityLabel("模型占 \(Term.size(model.modelTotal))，总存储 \(Term.size(disk))")
      }
      HStack(spacing: 10) {
        if off {
          if model.modelTotal > 0 {
            Button("删除残留模型…") { model.deleteLeftoverModels() }
              .buttonStyle(.borderedProminent)
          }
          Button("更改保留项") { model.page = .intelligence }
        } else {
          Button("使用推荐设置关闭…") {
            model.choose(.recommended)
            model.reviewing = true
          }
          .buttonStyle(.borderedProminent)
          Button("选择要关闭的项目") { model.page = .intelligence }
          Text("您会先看到每一项更改。").font(.callout).foregroundStyle(.secondary)
        }
      }
      .controlSize(.large)
    }
    .padding(20)
    .card()
  }

  var subtitle: String {
    if model.loadingModels { return "正在检查模型占用的空间…" }
    if off {
      if model.modelTotal > 0 { return "仍有 \(Term.size(model.modelTotal)) 的模型留在磁盘上。macOS 不会再下载更多。" }
      if let kept = model.currentAI, !kept.isEmpty { return "保留了 \(kept.count) 项功能。其余均已关闭，相关模型也已删除。" }
      return "模型已删除，macOS 不会再下载。"
    }
    if model.modelTotal > 0 { return "无论是否使用，这些模型都在这台 Mac 上占用 \(Term.size(model.modelTotal))。" }
    return "各项功能均已开启。RemoveMacAI 可以关闭您不使用的功能。"
  }
}

struct StatTile: View {
  let title: String
  let value: String
  let link: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(.callout).foregroundStyle(.secondary).lineLimit(1)
        Text(value).font(.title2.weight(.bold)).monospacedDigit()
        Text(link).font(.callout).foregroundStyle(.tint)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .card()
  }
}

enum DiskSize {
  /// The capacity of the startup disk.
  static var total: Int64? {
    let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey])
    return values?.volumeTotalCapacity.map(Int64.init)
  }
}

extension View {
  /// A grouped-box background that matches System Settings.
  func card() -> some View {
    background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5))
  }
}

// MARK: - Apple Intelligence

struct IntelligenceView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    Form {
      Section {
        Toggle(isOn: $model.aiOff) {
          VStack(alignment: .leading, spacing: 3) {
            Text("关闭 Apple 智能").font(.headline)
            Text("关闭下列功能，删除其模型，并阻止 macOS 再次下载。随时可以重新开启，macOS 会重新下载所需的模型。")
              .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
          }
        }
        .toggleStyle(.switch)
      } footer: {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Footer("macOS 要求您为此安装描述文件，撤销可还原所有内容。此部分基于 4evy 的 pared，该项目最先绘制了 Apple 资产服务和模型集的分布。")
          InfoButton(title: Explain.profile.0, text: Explain.profile.1)
        }
      }

      Section {
        ForEach(Catalog.features, id: \.id) { feature in
          Toggle(isOn: Binding(
            get: { model.aiKept.contains(feature.id) },
            set: { if $0 { model.aiKept.insert(feature.id) } else { model.aiKept.remove(feature.id) } }
          )) {
            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 6) {
                Text(feature.title)
                Text(stateText(feature.id)).font(.caption).foregroundStyle(.secondary)
              }
              if let blurb = FeatureBlurbs.text[feature.id] {
                Text(blurb).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
              }
            }
          }
          .disabled(!model.aiOff)
        }
      } header: {
        HStack {
          Text("保留您使用的功能")
          Spacer()
          if model.aiOff { Text("开启以保留").font(.caption).foregroundStyle(.secondary).textCase(nil) }
        }
      } footer: {
        Footer("保留的功能会留下其所需模型，因此可释放的空间会减少。")
      }

      Section {
        if model.loadingModels {
          HStack { ProgressView().controlSize(.small); Text("正在查询 Apple 资产服务…").foregroundStyle(.secondary) }
        } else if !model.modelsAvailable {
          Text("Apple 资产服务没有响应，因此大小未知。").foregroundStyle(.secondary)
        } else {
          ForEach(Catalog.modelSets, id: \.name) { set in
            LabeledContent(set.title) {
              let bytes = model.modelBytes[set.name] ?? 0
              Text(bytes > 0 ? Term.size(bytes) : "无").foregroundStyle(bytes > 0 ? .primary : .secondary)
            }
          }
          LabeledContent("总计") { Text(Term.size(model.modelTotal)).fontWeight(.semibold) }
          if model.currentAI != nil && model.modelTotal > 0 {
            HStack {
              Text("Apple 智能已关闭，但这些模型仍留在磁盘上。").foregroundStyle(.secondary)
              Spacer()
              Button("删除模型") { model.deleteLeftoverModels() }
            }
          }
        }
      } header: {
        HStack(spacing: 6) {
          Text("磁盘上的模型")
          InfoButton(title: Explain.models.0, text: Explain.models.1)
        }
      } footer: {
        Footer("macOS 会按自己的计划删除文件，因此移除后“储存”设置仍可能在一段时间内将其计入。")
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Apple 智能")
  }

  func stateText(_ id: String) -> String {
    switch model.featureStates[id] {
    case .lockedOff?: return "· 已关闭，由描述文件保持关闭"
    case .off?: return "· 已关闭"
    case .on?: return "· 已开启"
    default: return model.loadingModels ? "· 正在检查…" : ""
    }
  }
}

// MARK: - Tweak groups

struct TweakGroupView: View {
  @Environment(AppModel.self) private var model
  let group: TweakGroup

  var tweaks: [Tweak] { Tweaks.all.filter { $0.group == group } }

  var body: some View {
    Form {
      Section {
        ForEach(tweaks) { TweakRow(tweak: $0) }
      } header: {
        Text(group.summary).font(.body).foregroundStyle(.secondary).textCase(nil)
      } footer: {
        if tweaks.contains(where: \.inProfile) {
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Footer("带锁图标的设置由 RemoveMacAI 描述文件保持锁定，该描述文件在系统设置中安装。")
            InfoButton(title: Explain.locked.0, text: Explain.locked.1)
          }
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle(group.title)
    .toolbar {
      ToolbarItem {
        Menu {
          Button("全选") { for t in tweaks where t.supported { model.toggle(t, true) } }
          Button("选择推荐项") {
            for t in tweaks {
              let recommended = t.presets.contains(.recommended)
              if model.state(t) == .partial && !recommended {
                model.leave(t)
              } else {
                model.toggle(t, recommended || model.state(t) == .applied)
              }
            }
          }
          Button("全部取消选择") { for t in tweaks { model.toggle(t, false) } }
        } label: {
          Label("选择", systemImage: "checklist")
        }
      }
    }
  }
}

struct TweakRow: View {
  @Environment(AppModel.self) private var model
  let tweak: Tweak

  var body: some View {
    let state = model.state(tweak)
    let wanted = model.isOn(tweak)
    Toggle(isOn: Binding(get: { wanted }, set: { model.toggle(tweak, $0) })) {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(tweak.title)
          if tweak.inProfile {
            Image(systemName: "lock.fill").font(.caption2).foregroundStyle(.tertiary)
              .help("由 RemoveMacAI 描述文件保持锁定")
          }
          if let note = pendingNote(state: state, wanted: wanted, undoes: model.undoes(tweak)) {
            Text(note).font(.caption.weight(.medium)).foregroundStyle(.tint)
          }
        }
        Text(tweak.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        if let caveat = tweak.caveat {
          Label(caveat, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
        }
        if state == .managed {
          Text("由此 Mac 上的其他描述文件管理。").font(.caption).foregroundStyle(.secondary)
        } else if state == .unsupported {
          Text("需要 macOS \(tweak.since.0).\(tweak.since.1) 或更高版本。").font(.caption).foregroundStyle(.secondary)
        } else if state == .partial {
          Text("已部分应用。除非您进行切换，否则将保持现状。").font(.caption).foregroundStyle(.secondary)
        }
      }
      .padding(.vertical, 2)
    }
    .toggleStyle(.switch)
    .disabled(state == .managed || state == .unsupported)
  }

  func pendingNote(state: TweakState, wanted: Bool, undoes: Bool) -> String? {
    if wanted && state != .applied { return "将在确认时应用" }
    if undoes { return "将在确认时撤销" }
    return nil
  }
}

// MARK: - Background items

struct BackgroundView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Form {
      Section {
        if model.background.isEmpty {
          Text("没有来自其他应用的后台项目。").foregroundStyle(.secondary)
        }
        ForEach(model.background) { item in
          Toggle(isOn: Binding(
            get: { !model.backgroundOff.contains(item.id) },
            set: { model.setBackground(item, off: !$0) }
          )) {
            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 6) {
                Text(item.owner)
                if item.system {
                  Text("所有用户").font(.caption2.weight(.medium)).padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(.quaternary))
                }
              }
              Text(item.label).font(.caption.monospaced()).foregroundStyle(.secondary)
              Text(item.program).font(.caption2.monospaced()).foregroundStyle(.tertiary)
                .lineLimit(1).truncationMode(.middle)
              if let warning = item.warning {
                Label(warning, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
              }
            }
          }
          .toggleStyle(.switch)
          .disabled(model.backgroundBusy)
        }
      } header: {
        Text("其他应用安装的更新器、辅助程序和代理。无论其应用是否打开，它们都会运行。关闭后立即生效。更新器可以放心关闭；辅助程序可能是其应用正常运行所必需的，例如 VPN 或 Docker。")
          .font(.body).foregroundStyle(.secondary).textCase(nil)
      } footer: {
        Footer("标记为“所有用户”的项目需要输入密码。Apple 自带的后台服务受系统完整性保护（SIP），因此 RemoveMacAI 不会改动它们。")
      }
    }
    .formStyle(.grouped)
    .navigationTitle("后台项目")
    .toolbar {
      ToolbarItem {
        Button { model.loadBackground() } label: { Label("重新载入", systemImage: "arrow.clockwise") }
      }
    }
  }
}

// MARK: - Storage

struct StorageView: View {
  @Environment(AppModel.self) private var model
  @State private var confirming = false

  /// Selected items that are deleted right away instead of going to the Trash.
  var permanentChosen: [String] {
    model.storage.filter { model.storageChosen.contains($0.id) && $0.permanent }.map(\.title)
  }

  var body: some View {
    Form {
      if !model.scanned {
        Section {
          HStack(spacing: 14) {
            Image(systemName: "internaldrive").font(.title).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
              Text("查找可释放的空间").font(.headline)
              Text("查找旧安装包、航拍视频、Xcode 残留、应用缓存和 Time Machine 快照。在您选择之前不会移动任何内容。")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if model.scanning { ProgressView().controlSize(.small) } else { Button("扫描") { model.scan() } }
          }
          .padding(.vertical, 4)
        }
      } else {
        Section {
          if model.storage.isEmpty {
            Text("没有需要清理的内容。").foregroundStyle(.secondary)
          }
          ForEach(model.storage) { item in
            HStack(alignment: .top, spacing: 10) {
              Toggle("", isOn: Binding(
                get: { model.storageChosen.contains(item.id) },
                set: { if $0 { model.storageChosen.insert(item.id) } else { model.storageChosen.remove(item.id) } }
              ))
              .toggleStyle(.checkbox)
              .labelsHidden()
              VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                Text(item.detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let caveat = item.caveat {
                  Label(caveat, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
                }
              }
              Spacer()
              Text(item.kind == .snapshots ? "\(item.count) 个快照" : Term.size(item.bytes))
                .monospacedDigit().foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
          }
        } header: {
          HStack {
            Text("文件会移到废纸篓，清空废纸篓前不会真正删除。模拟器和快照会被立即删除。").textCase(nil)
            Spacer()
            if model.scanning { ProgressView().controlSize(.small) } else { Button("再次扫描") { model.scan() }.buttonStyle(.link) }
          }
        }
        Section {
          HStack {
            if let message = model.cleanMessage {
              Text(message).foregroundStyle(.secondary)
            } else {
              Text(model.storageChosen.isEmpty ? "未选择任何内容" : "已选择：\(Term.size(model.chosenBytes))").monospacedDigit()
            }
            Spacer()
            if model.cleaning { ProgressView().controlSize(.small) }
            Button(permanentChosen.isEmpty ? "移到废纸篓…" : "移除…") { confirming = true }
              .buttonStyle(.borderedProminent)
              .disabled(model.storageChosen.isEmpty || model.cleaning)
          }
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("储存空间")
    .confirmationDialog(
      permanentChosen.isEmpty ? "将所选项目移到废纸篓？" : "移除所选项目？",
      isPresented: $confirming
    ) {
      Button(permanentChosen.isEmpty ? "移到废纸篓" : "移除") { model.clean() }
    } message: {
      Text("约 \(Term.size(model.chosenBytes))。仅管理员可移动的项目会要求输入密码。"
        + (permanentChosen.isEmpty ? "" : " \(permanentChosen.joined(separator: "、"))将被立即删除，而不是移到废纸篓。"))
    }
  }
}

// MARK: - Undo

struct ChangesView: View {
  @Environment(AppModel.self) private var model
  @State private var confirming = false

  var body: some View {
    Form {
      Section("描述文件") {
        if model.snapshot.profile.on {
          LabeledContent("RemoveMacAI 描述文件", value: "已安装")
          if model.currentAI != nil { Label("Apple 智能已关闭", systemImage: "apple.intelligence") }
          ForEach(model.snapshot.profile.tweaks.sorted(), id: \.self) { id in
            Label(Tweaks.tweak(id)?.title ?? id, systemImage: "lock.fill")
          }
        } else {
          Text("未安装。").foregroundStyle(.secondary)
        }
      }
      Section("其他更改") {
        let entries = model.journal.entries.sorted { $0.value.date > $1.value.date }
        if entries.isEmpty {
          Text("无。").foregroundStyle(.secondary)
        }
        ForEach(entries, id: \.key) { key, entry in
          LabeledContent {
            Text(entry.date, style: .date).foregroundStyle(.secondary)
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(title(entry.tweak))
              Text(key).font(.caption.monospaced()).foregroundStyle(.tertiary)
            }
          }
        }
      }
      Section {
        HStack {
          Text("将所有设置恢复为 RemoveMacAI 更改前的状态，并移除描述文件。")
            .foregroundStyle(.secondary)
          Spacer()
          Button("全部撤销…", role: .destructive) { confirming = true }
            .disabled(!model.snapshot.profile.on && model.journal.entries.isEmpty)
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("撤销")
    .confirmationDialog("撤销 RemoveMacAI 的所有更改？", isPresented: $confirming) {
      Button("全部撤销", role: .destructive) { model.undoEverything() }
    } message: {
      Text("macOS 要求您在系统设置中移除描述文件。已删除的模型会在功能需要时重新下载，废纸篓中的文件保持原样。")
    }
  }

  func title(_ id: String) -> String {
    if let t = Tweaks.tweak(id) { return t.title }
    if let item = model.background.first(where: { $0.id == id }) { return "后台项目：\(item.owner)" }
    return id
  }
}

struct Footer: View {
  let text: String
  init(_ text: String) { self.text = text }

  var body: some View {
    Text(text)
      .font(.callout)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
  }
}

/// What each Apple Intelligence feature does, in a line, so people know what
/// they keep or lose.
enum FeatureBlurbs {
  static let text: [String: String] = [
    "siri": "语音助手。保留后，基础 Siri 在没有大型模型的情况下仍可使用。",
    "chatgpt": "让 Siri 和写作工具将请求转交给 ChatGPT。",
    "writing-tools": "改写、校对并总结您选定的文本。",
    "genmoji": "根据描述生成新表情符号。",
    "image-playground": "根据提示词生成图片。",
    "mail": "在“邮件”中总结电子邮件并建议回复。",
    "notification-summaries": "将一组通知浓缩为一行。",
    "messages-summaries": "总结“信息”中的长对话。",
    "safari-summaries": "总结 Safari 中的网页。",
    "notes-summaries": "总结“备忘录”中的录音与转录文本。",
    "inline-predictions": "在输入时建议词语或句子的剩余部分。",
    "spatial-photos": "将平面照片转换为 3D 空间场景。",
    "photos-clean-up": "在“照片”中移除照片中的物体。",
    "xcode-completion": "在 Xcode 中输入时预测代码。",
  ]
}
