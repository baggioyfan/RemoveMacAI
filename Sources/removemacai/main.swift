import Foundation

let usage = """
  RemoveMacAI \(version)
  精简 macOS：关闭 Apple 智能、删除其模型，并关闭分析、广告及其他内容。
  所有更改均可撤销。

  Apple 智能
    removemacai                 显示当前开启的内容，然后将其关闭（先询问）
    removemacai status          显示当前开启的内容以及模型占用的空间
    removemacai off [options]   跳过概览直接关闭
        --keep a,b              保持这些功能开启（名称见：removemacai features）
        --dry-run               仅显示将要更改的内容，不做任何更改
        --yes                   不再询问
    removemacai on              重新开启 Apple 智能，保留其他设置项
    removemacai features        列出功能名称

  精简
    removemacai tweaks [--json]           列出所有设置项及其是否已应用
    removemacai apply <names> [options]   应用设置项
        --preset recommended|privacy      应用一个预设，包含关闭 Apple 智能
        --dry-run, --yes
    removemacai undo <names>              撤销设置项
    removemacai background [off|on <labels>]
                                          其他应用的后台项目
    removemacai clean [<names>]           显示可释放的空间，并将部分内容移到废纸篓
    removemacai export <file.mobileconfig> [--preset p] [<names>] [--keep a,b] [--no-ai]
                                          生成供 MDM 使用的描述文件

    removemacai revert          撤销 RemoveMacAI 所做的全部更改
    removemacai app             打开 RemoveMacAI 应用

  """

var args = Array(CommandLine.arguments.dropFirst())
func flag(_ name: String) -> Bool {
  guard let i = args.firstIndex(of: name) else { return false }
  args.remove(at: i)
  return true
}
func option(_ name: String) -> String? {
  guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
  let value = args[i + 1]
  args.removeSubrange(i...(i + 1))
  return value
}
func presetOption() -> Preset? {
  guard let name = option("--preset") else { return nil }
  guard let preset = Preset(rawValue: name) else {
    Term.fail("没有名为 \"\(name)\" 的预设。请使用 recommended 或 privacy")
  }
  return preset
}

// Opened from Finder: the app. With arguments, or from a bare binary: the CLI.
if args.isEmpty && Bundle.main.bundleURL.pathExtension == "app" || args.first == "app" {
  guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 else {
    Term.fail("RemoveMacAI 需要 macOS 26 或更高版本")
  }
  Shell.inApp = true
  RemoveMacAIApp.main()
  exit(0)
}

guard args.first == "selftest" || ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 else {
  Term.fail("RemoveMacAI 需要 macOS 26 或更高版本")
}

switch args.first {
case "status":
  Commands.status()
case "off", nil:
  if !args.isEmpty { args.removeFirst() }
  let keep = Set((option("--keep") ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
  let dryRun = flag("--dry-run")
  let yes = flag("--yes") || flag("-y")
  if let extra = args.first { Term.fail("未知选项 \(extra)") }
  exit(Commands.off(keep: keep, dryRun: dryRun, yes: yes) ? 0 : 1)
case "revert":
  Commands.revert()
case "on":
  Commands.on()
case "features":
  Commands.features()
case "tweaks":
  args.removeFirst()
  TweakCommands.list(json: flag("--json"))
case "apply", "undo":
  let command = args.removeFirst()
  let preset = presetOption()
  let dryRun = flag("--dry-run")
  let yes = flag("--yes") || flag("-y")
  if let bad = args.first(where: { $0.hasPrefix("-") }) { Term.fail("未知选项 \(bad)") }
  let ok = command == "apply"
    ? TweakCommands.apply(ids: args, preset: preset, dryRun: dryRun, yes: yes)
    : TweakCommands.undo(ids: args, dryRun: dryRun, yes: yes)
  exit(ok ? 0 : 1)
case "background":
  args.removeFirst()
  let yes = flag("--yes") || flag("-y")
  exit(TweakCommands.background(args, yes: yes) ? 0 : 1)
case "clean":
  args.removeFirst()
  let dryRun = flag("--dry-run")
  let yes = flag("--yes") || flag("-y")
  exit(TweakCommands.clean(ids: args, dryRun: dryRun, yes: yes) ? 0 : 1)
case "export":
  args.removeFirst()
  let preset = presetOption()
  let keep = Set((option("--keep") ?? "").split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty })
  let noAI = flag("--no-ai")
  guard let path = args.first else { Term.fail("请指定要写入的文件，例如：removemacai export RemoveMacAI.mobileconfig") }
  TweakCommands.export(path: path, ids: Array(args.dropFirst()), preset: preset, keepAI: keep, noAI: noAI)
case "selftest":
  exit(selfTest() ? 0 : 1)
case "--version", "-v", "version":
  print(version)
case "help", "--help", "-h":
  print(usage, terminator: "")
default:
  print(usage, terminator: "")
  exit(1)
}
