import Foundation

/// The debloater commands: tweaks, presets, background items, storage and export.
enum TweakCommands {
  static func label(_ state: TweakState) -> String {
    switch state {
    case .applied: return Term.green("已完成")
    case .notApplied: return Term.dim("未应用")
    case .partial: return Term.yellow("部分应用")
    case .managed: return Term.yellow("由其他描述文件管理")
    case .unsupported: return Term.dim("需要更新的 macOS")
    }
  }

  // MARK: tweaks

  static func list(json: Bool) {
    let s = Snapshot()
    if json {
      let rows = Tweaks.all.map { t -> [String: Any] in
        ["id": t.id, "group": t.group.rawValue, "title": t.title, "state": "\(s.state(t))",
         "profile": t.inProfile, "presets": t.presets.map(\.rawValue).sorted()]
      }
      let data = try! JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
      print(String(decoding: data, as: UTF8.self))
      return
    }
    Commands.header()
    for group in TweakGroup.allCases {
      print(Term.bold(group.title))
      for t in Tweaks.all where t.group == group {
        print("  " + Term.pad(t.id, 22) + Term.pad(t.title, 46) + label(s.state(t)))
      }
      print()
    }
    print(Term.dim("应用部分设置项：removemacai apply <names>   或使用预设：removemacai apply --preset recommended"))
  }

  // MARK: apply and undo

  /// Applies the named tweaks (and, for a preset, turns Apple Intelligence off),
  /// leaving everything else as it is.
  static func apply(ids: [String], preset: Preset?, dryRun: Bool, yes: Bool) -> Bool {
    let s = Snapshot()
    var requested = Set<String>()
    for id in ids {
      guard let tweak = Tweaks.tweak(id) else {
        Term.fail("没有名为 \"\(id)\" 的设置项。名称列表命令：removemacai tweaks")
      }
      requested.insert(tweak.id)
    }
    if let preset { requested.formUnion(Tweaks.preset(preset).map(\.id)) }
    guard !requested.isEmpty else { Term.fail("请指定要应用的设置项，或用 --preset 指定预设") }
    let currentAI: Set<String>? = s.profile.ai && s.profile.on ? s.profile.kept : nil
    let ai: Set<String>? = preset != nil ? (currentAI ?? []) : currentAI
    let plan = Plan.make(wanted: s.appliedTweaks.union(requested), ai: ai, snapshot: s)
    return run(plan, dryRun: dryRun, yes: yes, verb: "应用")
  }

  static func undo(ids: [String], dryRun: Bool, yes: Bool) -> Bool {
    let s = Snapshot()
    var wanted = s.appliedTweaks
    for id in ids {
      guard Tweaks.tweak(id) != nil else { Term.fail("没有名为 \"\(id)\" 的设置项") }
      wanted.remove(id)
    }
    let ai: Set<String>? = s.profile.on && s.profile.ai ? s.profile.kept : nil
    let plan = Plan.make(wanted: wanted, ai: ai, undo: Set(ids), snapshot: s)
    return run(plan, dryRun: dryRun, yes: yes, verb: "撤销")
  }

  static func describe(_ plan: Plan) {
    if !plan.apply.isEmpty {
      print(Term.bold("应用"))
      for t in plan.apply {
        print("  " + Term.green("+") + " " + t.title)
        for c in t.changes { print("      " + Term.dim(c.command)) }
        if let caveat = t.caveat { print("      " + Term.yellow(caveat)) }
      }
    }
    if !plan.revert.isEmpty {
      print(Term.bold("撤销"))
      for t in plan.revert { print("  " + Term.yellow("-") + " " + t.title) }
    }
    if let profile = plan.profile {
      print(Term.bold("描述文件"))
      print("  " + (profile.isEmpty ? "移除 RemoveMacAI 描述文件" : "安装更新后的描述文件（macOS 会要求你在系统设置中批准）"))
    }
    if !plan.models.isEmpty {
      print(Term.bold("模型"))
      for name in plan.models { print("  删除 " + (Catalog.modelSet(name)?.title ?? name)) }
    }
    print()
  }

  static func run(_ plan: Plan, dryRun: Bool, yes: Bool, verb: String) -> Bool {
    Commands.header()
    guard !plan.isEmpty else {
      print(Term.green("无需更改。") + " 所有列出的项目均已是目标状态。")
      return true
    }
    describe(plan)
    if dryRun {
      print(Term.bold("试运行，未做任何更改。"))
      return true
    }
    if !yes {
      guard isatty(STDIN_FILENO) == 1 else { Term.fail("请在终端中运行，或添加 --yes") }
      guard Term.ask("\(verb)这些更改？") else {
        print("未做任何更改。")
        return true
      }
      print()
    }
    let problems = Engine.runLocal(plan)
    for p in problems { print("  " + Term.yellow("!") + " " + p) }
    if !(plan.apply + plan.revert).filter({ !$0.inProfile }).isEmpty {
      print(Term.green("✓") + " 设置已更改")
    }
    var ok = problems.isEmpty
    if let profile = plan.profile {
      ok = (profile.isEmpty ? Commands.removeProfile() : Commands.installProfile(profile)) && ok
    }
    if ok && !plan.models.isEmpty {
      ok = Commands.deleteModels(plan.models, step: "Models")
    }
    print()
    print((ok ? Term.green("完成。") : Term.yellow("未完成。")) + Term.dim("  全部撤销命令：\(Commands.undo)"))
    return ok
  }

  // MARK: background items

  static func background(_ args: [String], yes: Bool) -> Bool {
    let items = BackgroundItems.scan()
    let labels = BackgroundItems.disabledLabels()
    guard let action = args.first, action == "off" || action == "on" else {
      Commands.header()
      if items.isEmpty {
        print("没有来自其他应用的后台项目。")
        return true
      }
      print(Term.bold("来自其他应用的后台项目"))
      for item in items {
        let off = BackgroundItems.isDisabled(item, labels)
        let state = off ? Term.dim(Term.pad("关闭", 5)) : Term.green(Term.pad("开启", 5))
        let kind = item.isUpdater ? Term.dim("更新器") : Term.yellow("辅助程序")
        print("  " + Term.pad(item.label, 48) + Term.pad(item.owner, 22) + state + kind
          + (item.system ? Term.dim("  （所有用户）") : ""))
      }
      print()
      print(Term.dim("关闭辅助程序可能导致其应用无法工作，例如 VPN 或 Docker。"))
      print(Term.dim("关闭某个项目：removemacai background off <label>"))
      return true
    }
    let names = Set(args.dropFirst())
    let chosen = items.filter { names.contains($0.label) }
    for name in names where !chosen.contains(where: { $0.label == name }) {
      Term.fail("没有名为 \"\(name)\" 的后台项目")
    }
    guard !chosen.isEmpty else { Term.fail("请指定项目名称，列表命令：removemacai background") }
    if action == "off" {
      for item in chosen { if let warning = item.warning { print(Term.yellow("!") + " \(item.label): " + warning) } }
    }
    if !yes {
      guard isatty(STDIN_FILENO) == 1 else { Term.fail("请在终端中运行，或添加 --yes") }
      let verb = action == "off" ? "关闭" : "开启"
      guard Term.ask("\(verb) \(chosen.map(\.label).joined(separator: ", "))?") else {
        print("未做任何更改。")
        return true
      }
    }
    let problems = BackgroundItems.set(chosen, disabled: action == "off")
    for p in problems { print(Term.yellow("!") + " " + p) }
    if problems.isEmpty { print(Term.green("✓") + " " + (action == "off" ? "已关闭" : "已开启") + "：" + chosen.map(\.label).joined(separator: ", ")) }
    return problems.isEmpty
  }

  // MARK: storage

  static func clean(ids: [String], dryRun: Bool, yes: Bool) -> Bool {
    Commands.header()
    print(Term.dim("正在计算..."))
    let items = Storage.scan()
    if Term.color { print("\u{1B}[1A\u{1B}[K", terminator: "") }
    if items.isEmpty {
      print("没有可清理的内容。")
      return true
    }
    print(Term.bold("可释放的空间"))
    for item in items {
      let amount = item.kind == .snapshots ? "\(item.count) 个快照" : Term.size(item.bytes)
      print("  " + Term.pad(item.id, 16) + Term.pad(item.title, 34) + amount)
      if let caveat = item.caveat { print("    " + Term.dim(caveat)) }
    }
    print()
    guard !ids.isEmpty else {
      print(Term.dim("移到废纸篓：removemacai clean <names>"))
      return true
    }
    let chosen = items.filter { ids.contains($0.id) }
    for id in ids where !chosen.contains(where: { $0.id == id }) {
      Term.fail("\"\(id)\" 不在上面的列表中")
    }
    let total = chosen.reduce(Int64(0)) { $0 + $1.bytes }
    let permanent = chosen.filter(\.permanent)
    if !permanent.isEmpty {
      print(Term.yellow("!") + " " + permanent.map(\.title).joined(separator: " 和 ") + " 将被立即删除，不会移入废纸篓。")
    }
    if dryRun {
      print(Term.bold("试运行，未移动任何内容。") + " 预计可释放约 \(Term.size(total))。")
      return true
    }
    if !yes {
      guard isatty(STDIN_FILENO) == 1 else { Term.fail("请在终端中运行，或添加 --yes") }
      let verb = permanent.isEmpty ? "移到废纸篓" : "删除"
      guard Term.ask("\(verb)：\(chosen.map(\.title).joined(separator: "、"))？") else {
        print("未移动任何内容。")
        return true
      }
    }
    let result = Storage.clean(chosen)
    for p in result.problems { print(Term.yellow("!") + " " + p) }
    let trashed = chosen.filter { !$0.permanent }.reduce(Int64(0)) { $0 + $1.bytes } - result.protectedBytes
    if trashed > 0 { print(Term.green("✓") + " 已移到废纸篓。清倒废纸篓即可释放约 \(Term.size(trashed))。") }
    if !permanent.isEmpty && result.problems.isEmpty { print(Term.green("✓") + " 已删除 " + permanent.map(\.title).joined(separator: " 和 ") + "。") }
    if result.protected > 0 { print(Term.dim("  \(result.protected) 个受 macOS 保护的项目保持原位。")) }
    return result.problems.isEmpty
  }

  // MARK: export

  /// Writes the profile for a preset or named tweaks, for deploying with an MDM.
  static func export(path: String, ids: [String], preset: Preset?, keepAI: Set<String>, noAI: Bool) {
    var tweaks = Set<String>()
    for id in ids {
      guard let t = Tweaks.tweak(id) else { Term.fail("没有名为 \"\(id)\" 的设置项") }
      guard t.inProfile else { Term.fail("\(id) 是按用户生效的设置，无法写入描述文件") }
      tweaks.insert(id)
    }
    if let preset { tweaks.formUnion(Tweaks.preset(preset).filter(\.inProfile).map(\.id)) }
    let contents = Profile.Contents(ai: noAI ? nil : keepAI, tweaks: tweaks)
    do {
      try Profile.data(contents).write(to: URL(fileURLWithPath: path))
    } catch { Term.fail("无法写入 \(path)：\(error)") }
    print(Term.green("✓") + " 已写入 \(path)")
    print(Term.dim("  Apple 智能：\(noAI ? "未改动" : keepAI.isEmpty ? "关闭" : "关闭（保留 \(keepAI.sorted().joined(separator: ", "))）")"))
    print(Term.dim("  设置项：\(tweaks.isEmpty ? "无" : tweaks.sorted().joined(separator: ", "))"))
    print(Term.dim("  按用户生效的设置项（访达、程序坞、输入）不包含在描述文件中；这些需要在每台 Mac 上运行 removemacai。"))
  }
}
