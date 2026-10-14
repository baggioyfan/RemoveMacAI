import AppKit
import Foundation

let version = "1.1.0"

enum Commands {
  /// How to undo, as the person ran us: the one-line installer passes its own
  /// command, a brew or source install uses the binary's name.
  static var undo: String {
    ProcessInfo.processInfo.environment["REMOVEMACAI_UNDO"] ?? "removemacai revert"
  }

  static func header() {
    let os = ProcessInfo.processInfo.operatingSystemVersion
    print(Term.bold("RemoveMacAI") + Term.dim(" \(version)  ·  macOS \(os.majorVersion).\(os.minorVersion)"))
    print()
  }

  // MARK: status

  static func status() {
    header()
    print(Term.bold("功能"))
    for feature in Catalog.features {
      let label: String
      switch Settings.state(feature) {
      case .lockedOff: label = Term.green("关闭") + Term.dim("（已锁定）")
      case .off: label = Term.green("关闭")
      case .on: label = Term.yellow("开启")
      case .unknown: label = Term.yellow("未知")
      }
      print("  " + Term.pad(feature.title, 40) + label)
    }
    print()
    if printModels() == 0 && Profile.installed().ai {
      print(Term.dim("  macOS 会自行删除已删除的模型文件，因此系统设置在一段时间内仍会统计它们。"))
    }
    print()
    if isOff() {
      print(Term.green("Apple 智能已关闭。") + Term.dim(" 撤销命令：\(undo)"))
    } else {
      print("关闭命令：" + Term.bold("removemacai"))
    }
  }

  @discardableResult
  static func printModels() -> Int64? {
    print(Term.bold("磁盘上的模型"))
    guard Models.available() else {
      print(Term.dim("  Apple 的资产服务没有响应，因此大小未知。"))
      return nil
    }
    var readings: [String: Int64] = [:]
    for set in Catalog.modelSets {
      let bytes = Models.bytes(set.name)
      readings[set.name] = bytes
      print("  " + Term.pad(set.title, 40) + modelSize(bytes))
    }
    let total = Models.total(Catalog.modelSets.map(\.name), read: { readings[$0] })
    print("  " + Term.pad("总计", 40) + (total.map { Term.bold(Term.size($0)) } ?? Term.yellow("未知")))
    return total
  }

  static func modelSize(_ bytes: Int64?) -> String {
    guard let bytes else { return Term.yellow("未知") }
    return bytes > 0 ? Term.yellow(Term.size(bytes)) : Term.dim("无")
  }

  static func featuresOn() -> Int { Catalog.features.filter { Settings.state($0) == .on }.count }

  static func isOff() -> Bool {
    let profile = Profile.installed()
    return profile.on && profile.ai && Catalog.features.allSatisfy { Settings.state($0).isOff }
  }

  // MARK: off

  static func off(keep: Set<String>, dryRun: Bool, yes: Bool) -> Bool {
    header()
    for id in keep where Catalog.feature(id) == nil {
      Term.fail("没有名为 \"\(id)\" 的功能。名称列表命令：removemacai features")
    }
    let sets = Catalog.setsToRemove(keeping: keep)
    let modelsAvailable = sets.isEmpty || Models.available()
    let modelsBefore: Int64? = sets.isEmpty ? 0 : (modelsAvailable ? Models.total(sets) : nil)
    let profile = Profile.installed()
    let target = Profile.Contents(ai: keep, tweaks: profile.tweaks)
    let profileReady = profile.contents == target
    let offSummary = keep.isEmpty ? "Apple 智能已关闭。" : "所选功能已关闭。"

    if profileReady && modelsBefore == 0 {
      print(Term.green(offSummary) + " 所选待移除的模型集中已没有剩余模型。")
      if !sets.isEmpty {
        print(Term.dim("macOS 会自行删除已删除的模型文件，因此系统设置在一段时间内仍会统计它们。"))
      }
      warnKeptButOff(keep)
      print(Term.dim("查看状态：removemacai status    撤销：\(undo)"))
      return true
    }

    let on = featuresOn()
    print(profileReady ? "描述文件已安装。正在检查所选模型。" : "正在检查 Apple 智能及其模型。")
    print("  " + Term.pad("已开启功能", 20) + "\(on) / \(Catalog.features.count)")
    print("  " + Term.pad("磁盘上的模型", 20) + (modelsBefore.map(Term.size) ?? "未知"))
    print()
    print("关闭后将执行以下操作：")
    print("  · 关闭 Siri、Writing Tools、Genmoji、Image Playground、摘要和 ChatGPT"
      + (keep.isEmpty ? "" : Term.dim("（保留 " + keep.sorted().joined(separator: ", ") + "）")))
    if let modelsBefore {
      print("  · 删除 " + Term.bold(Term.size(modelsBefore)) + " 的模型，并阻止 macOS 再次下载")
    } else if modelsAvailable {
      print("  · 请求移除模型并阻止下载（当前模型大小未知）")
    } else {
      print("  · 停止模型下载（Apple 的资产服务不可用，无法请求移除）")
    }
    if !profileReady {
      print("  · 请你在系统设置中批准一个描述文件（macOS 要求必须点击确认）")
    }
    print()
    print(Term.dim("恢复全部设置：\(undo)"))
    print()

    let data: Data
    do { data = try Profile.data(target) } catch { Term.fail("无法生成描述文件：\(error)") }

    if dryRun {
      let path = FileManager.default.temporaryDirectory.appendingPathComponent("RemoveMacAI.mobileconfig")
      try? data.write(to: path)
      print(Term.bold("试运行，未做任何更改。"))
      print("将安装的描述文件：  " + path.path)
      var deleting = sets
      var staying: [(String, String)] = []
      if modelsAvailable, let split = try? Models.matching(sets) {
        (deleting, staying) = (split.matched.filter { Models.present($0) }, split.skipped)
      }
      print("将删除的模型：    " + (deleting.isEmpty ? "无" : deleting.joined(separator: ", ")))
      for (name, reason) in staying {
        print("  " + Term.yellow("!") + " \(Catalog.modelSet(name)?.title ?? name) 将保留：" + Term.dim(reason))
      }
      return true
    }
    if !yes {
      guard isatty(STDIN_FILENO) == 1 else { Term.fail("请在终端中运行，或添加 --yes") }
      guard Term.ask("关闭 Apple 智能？") else {
        print("未做任何更改。")
        return true
      }
      print()
    }

    // 1. The profile switches the features off and blocks the model downloads.
    if profileReady {
      print(Term.green("✓") + " 描述文件已安装")
    } else {
      print(Term.bold("第 1 步（共 2 步）") + "  批准描述文件")
      do { try data.write(to: Profile.file) } catch { Term.fail("无法写入 \(Profile.file.path)：\(error)") }
      NSWorkspace.shared.open(Profile.file)
      Thread.sleep(forTimeInterval: 1)
      openProfileSettings()
      print("  系统设置已打开。双击 " + Term.bold("RemoveMacAI") + "，然后点击 "
        + Term.bold("安装") + "。")
      guard waitFor("在系统设置中等待你的操作", { Profile.matches(target) })
      else {
        print("  描述文件尚未安装。安装后重新运行本命令，将从这里继续。")
        return false
      }
      print("  " + Term.green("✓") + " 描述文件已安装")
    }

    // 2. The models go now that they cannot download again.
    let removalComplete = deleteModels(sets, step: "第 2 步（共 2 步）")
    print()
    if removalComplete {
      print(Term.green("完成。") + " " + offSummary)
    } else {
      print(Term.yellow("未完成。") + " " + offSummary + " 描述文件保持安装状态；模型移除尚未完成。")
    }
    warnKeptButOff(keep)
    print(Term.dim("查看状态：removemacai status    撤销：\(undo)"))
    return removalComplete
  }

  /// Removes the model sets through the asset service and reports what it
  /// could confirm. Returns whether removal is complete.
  static func deleteModels(_ sets: [String], step: String) -> Bool {
    // Approval can take several minutes; use a fresh snapshot before deleting.
    let removalAvailable = sets.isEmpty || Models.available()
    var removing = sets
    var staying: [(String, String)] = []
    if removalAvailable, !sets.isEmpty {
      do { (removing, staying) = try Models.matching(sets) } catch { Term.fail("\(error)") }
    }
    for (name, reason) in staying {
      print("  " + Term.yellow("!") + " \(Catalog.modelSet(name)?.title ?? name) 已保留：" + Term.dim(reason))
    }
    let removalBefore: Int64? = removing.isEmpty ? 0 : (removalAvailable ? Models.total(removing) : nil)
    var removalComplete = true
    if !removalAvailable {
      print("  " + Term.yellow("!") + " Apple 的资产服务不可用，无法请求移除模型。")
      removalComplete = false
    } else if removalBefore != 0 {
      print(Term.bold(step) + "  删除模型")
      do {
        let result = try removeModels(removing, before: removalBefore)
        for (name, reason) in result.failures {
          print("  " + Term.yellow("!") + " \(Catalog.modelSet(name)?.title ?? name) 的移除请求：" + Term.dim(reason))
        }
        removalComplete = result.complete
        if let deleted = result.deletedBytes {
          print("  " + (result.complete ? Term.green("✓") : Term.yellow("!")) + " 已删除 " + Term.size(deleted))
        } else {
          print("  " + Term.dim("删除量未知，因为资产服务未报告全部大小。"))
        }
        if result.after == nil {
          print("  " + Term.yellow("!") + " 剩余模型大小未知；无法确认移除结果。")
        } else if let remaining = result.after, remaining > 0 {
          print("  " + Term.yellow("!") + " 所选模型中仍有 " + Term.size(remaining) + " 未删除。")
        }
        if !result.verified {
          print("  " + Term.yellow("!") + " 等待确认所选模型已移除时超时。")
        }
        if result.complete {
          print("    " + Term.dim("macOS 会自行删除这些文件，因此系统设置在一段时间内仍会在 Apple 智能下统计它们。"))
        }
      } catch { Term.fail("\(error)") }
    }
    return removalComplete
  }

  static func warnKeptButOff(_ keep: Set<String>) {
    for feature in Catalog.features where keep.contains(feature.id) && Settings.state(feature) == .off {
      print(Term.yellow("!") + " \(feature.title) 已保留，但它处于关闭状态。请在系统设置中开启它。")
    }
  }

  /// Injectable operations let self-tests verify failures without contacting the asset service.
  static func removeModels(
    _ sets: [String], before: Int64?,
    remove: ([String]) throws -> [(String, String)] = { try Models.remove($0) },
    total: @escaping ([String]) -> Int64? = { Models.total($0) },
    wait: (() -> Bool) -> Bool = { waitFor("正在删除", $0, minutes: 0.5) }
  ) throws -> ModelRemovalResult {
    if sets.isEmpty || before == 0 {
      return ModelRemovalResult(before: before, after: 0, failures: [], verified: true)
    }
    let failures = try remove(sets)
    var after: Int64?
    let verified = wait {
      after = total(sets)
      return after == 0
    }
    return ModelRemovalResult(before: before, after: after, failures: failures, verified: verified)
  }

  // MARK: revert

  /// Undoes everything: the tweaks in the journal right away, then the
  /// profile, which macOS only lets the person remove.
  static func revert() {
    header()
    let journal = Engine.loadJournal()
    let profileOn = Profile.installed().on
    guard profileOn || !journal.entries.isEmpty else {
      print("RemoveMacAI 在这台 Mac 上没有做过任何更改，因此没有可撤销的内容。")
      return
    }
    if !journal.entries.isEmpty {
      let problems = Engine.revertAll()
      for p in problems { print("  " + Term.yellow("!") + " " + p) }
      print(Term.green("✓") + " 描述文件之外更改的设置已恢复原状")
    }
    if profileOn {
      guard removeProfile() else { exit(1) }
      print(Term.dim("重新开启某个功能时，macOS 会重新下载模型。"))
    }
  }

  /// Turns Apple Intelligence back on and keeps the other tweaks.
  static func on() {
    header()
    let profile = Profile.installed()
    guard profile.on && profile.ai else {
      print("RemoveMacAI 未关闭 Apple 智能，因此没有可撤销的内容。")
      return
    }
    if profile.tweaks.isEmpty {
      guard removeProfile() else { exit(1) }
    } else {
      let target = Profile.Contents(ai: nil, tweaks: profile.tweaks)
      guard installProfile(target) else { exit(1) }
    }
    print(Term.dim("重新开启某个功能时，macOS 会重新下载模型。"))
  }

  static func removeProfile() -> Bool {
    openProfileSettings()
    print("系统设置已打开。选择 " + Term.bold("RemoveMacAI") + "，然后点击 " + Term.bold("移除") + "。")
    print(Term.dim("也可以在终端执行：sudo profiles remove -identifier \(Profile.identifier)"))
    guard waitFor("在系统设置中等待你的操作", { !Profile.installed().on }) else {
      print("描述文件仍处于安装状态。你可以随时在系统设置中移除它。")
      return false
    }
    print(Term.green("✓") + " 描述文件已移除。你自己的设置重新生效。")
    return true
  }

  /// Shows the profile for approval and waits until it is in force.
  static func installProfile(_ target: Profile.Contents) -> Bool {
    do { try Profile.present(target) } catch {
      print(Term.red("错误：") + "无法写入 \(Profile.file.path)：\(error)")
      return false
    }
    Thread.sleep(forTimeInterval: 1)
    openProfileSettings()
    print("系统设置已打开。双击 " + Term.bold("RemoveMacAI") + "，然后点击 " + Term.bold("安装") + "。")
    guard waitFor("在系统设置中等待你的操作", { Profile.matches(target) }) else {
      print("描述文件尚未安装。安装后重新运行本命令。")
      return false
    }
    print(Term.green("✓") + " 描述文件已安装")
    return true
  }

  // MARK: features

  static func features() {
    for f in Catalog.features { print(Term.pad(f.id, 26) + f.title) }
  }

  // MARK: helpers

  static func openProfileSettings() {
    for url in [
      "x-apple.systempreferences:com.apple.Profiles-Settings.extension",
      "x-apple.systempreferences:com.apple.preferences.configurationprofiles",
    ] {
      if let u = URL(string: url), NSWorkspace.shared.open(u) { return }
    }
  }

  static func waitFor(_ what: String, _ condition: () -> Bool, minutes: Double = 10) -> Bool {
    let spinner = Array("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏")
    let deadline = Date().addingTimeInterval(minutes * 60)
    var i = 0
    defer { if Term.color { print("\r\u{1B}[K", terminator: "") } }
    while Date() < deadline {
      if condition() { return true }
      if Term.color {
        print("\r  " + Term.dim("\(spinner[i % spinner.count]) \(what)"), terminator: "")
        fflush(stdout)
      }
      i += 1
      Thread.sleep(forTimeInterval: 0.5)
    }
    return false
  }
}
