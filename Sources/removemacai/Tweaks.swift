import Foundation

/// A sidebar section of the catalog.
enum TweakGroup: String, CaseIterable, Identifiable {
  case privacy, annoyances, apps, finder, windows, typing

  var id: String { rawValue }

  var title: String {
    switch self {
    case .privacy: return "隐私"
    case .annoyances: return "烦人设置"
    case .apps: return "Apple 应用"
    case .finder: return "访达"
    case .windows: return "程序坞与窗口"
    case .typing: return "输入"
    }
  }

  var symbol: String {
    switch self {
    case .privacy: return "hand.raised"
    case .annoyances: return "bell.slash"
    case .apps: return "square.grid.2x2"
    case .finder: return "folder"
    case .windows: return "dock.rectangle"
    case .typing: return "keyboard"
    }
  }

  var summary: String {
    switch self {
    case .privacy: return "阻止你的 Mac 向 Apple 发送分析数据、搜索记录和录音。"
    case .annoyances: return "关闭那些没人需要的弹窗、小组件和意外打扰。"
    case .apps: return "让不用的 Apple 应用安静下来。macOS 不允许任何人删除它们。"
    case .finder: return "显示访达隐藏的内容，并阻止它留下杂项文件。"
    case .windows: return "更快的程序坞，去掉多余的图标和动画。"
    case .typing: return "阻止 macOS 篡改你输入的内容。"
    }
  }
}

/// A named starting selection.
enum Preset: String, CaseIterable, Identifiable {
  case recommended, privacy

  var id: String { rawValue }

  var title: String {
    switch self {
    case .recommended: return "推荐"
    case .privacy: return "最大隐私"
    }
  }

  var summary: String {
    switch self {
    case .recommended: return "关闭 Apple 智能，没有分析数据和广告，弹窗更少。你依赖的功能都不会失效。"
    case .privacy: return "包含推荐项的全部内容，并额外关闭 Game Center 和 Safari 搜索建议。"
    }
  }
}

/// One setting a tweak changes.
enum Change: Equatable {
  /// A restriction key the profile sets to false.
  case restriction(String)
  /// A preference the profile forces, so it can't be changed back by hand.
  case forced(String, String, PlistValue)
  /// A preference written for the current user.
  case pref(String, String, PlistValue, currentHost: Bool = false)
  /// A launchd agent in the user's session, disabled and unloaded.
  case service(String)
  /// Music's application job, whose label changes when macOS replaces its files.
  case musicLaunches
  /// Dock icons removed by bundle identifier.
  case dockRemove([String])
  /// ~/Library shown in Finder.
  case showLibrary

  var inProfile: Bool {
    switch self {
    case .restriction, .forced: return true
    default: return false
    }
  }

  /// The journal key; two tweaks never change the same thing.
  var key: String {
    switch self {
    case .restriction(let k): return "restriction:\(k)"
    case .forced(let d, let k, _): return "forced:\(d):\(k)"
    case .pref(let d, let k, _, let host): return "pref:\(d):\(k)" + (host ? ":currentHost" : "")
    case .service(let l): return "service:\(l)"
    case .musicLaunches: return "application:com.apple.Music"
    case .dockRemove(let ids): return "dock:" + ids.joined(separator: ",")
    case .showLibrary: return "library"
    }
  }

  /// The equivalent command, shown before anything changes.
  var command: String {
    switch self {
    case .restriction(let k): return "profile: com.apple.applicationaccess \(k) = false"
    case .forced(let d, let k, let v): return "profile: \(d) \(k) = \(v) (locked)"
    case .pref(let d, let k, let v, let host):
      let type: String
      switch v {
      case .bool: type = "-bool"
      case .int: type = "-int"
      case .double: type = "-float"
      case .string: type = "-string"
      }
      let value: String
      if case .string(let s) = v { value = "\"\(s)\"" } else { value = v.description }
      return "defaults\(host ? " -currentHost" : "") write \(d) \"\(k)\" \(type) \(value)"
    case .service(let l): return "launchctl disable gui/$UID/\(l) && launchctl bootout gui/$UID/\(l)"
    case .musicLaunches:
      guard let label = try? MusicLaunch.label() else { return "could not identify Music's application launch entry" }
      return Change.service(label).command
    case .dockRemove(let ids): return "remove from the Dock: " + ids.joined(separator: ", ")
    case .showLibrary: return "chflags nohidden ~/Library"
    }
  }
}

struct Tweak: Identifiable {
  let id: String
  let group: TweakGroup
  let title: String
  let detail: String
  var caveat: String? = nil
  let changes: [Change]
  /// Processes that read the setting only at launch.
  var restart: [String] = []
  var presets: Set<Preset> = []
  /// The first macOS version (major, minor) that has the setting.
  var since: (Int, Int) = (14, 0)

  var inProfile: Bool { changes.contains { $0.inProfile } }

  var supported: Bool {
    let os = ProcessInfo.processInfo.operatingSystemVersion
    return (os.majorVersion, os.minorVersion) >= since
  }
}

enum Tweaks {
  static let all: [Tweak] = [
    // MARK: Privacy
    Tweak(
      id: "analytics", group: .privacy, title: "关闭 Mac 分析",
      detail: "阻止你的 Mac 向 Apple 和应用开发者发送诊断与使用数据。",
      changes: [.restriction("allowDiagnosticSubmission")], presets: [.recommended, .privacy]),
    Tweak(
      id: "personalized-ads", group: .privacy, title: "关闭个性化广告",
      detail: "阻止 Apple 根据你在其应用中的行为，在 App Store、News 和股市中投放定向广告。",
      changes: [.restriction("allowApplePersonalizedAdvertising")], presets: [.recommended, .privacy]),
    Tweak(
      id: "improve-siri", group: .privacy, title: "关闭改进 Siri 与听写",
      detail: "阻止 Apple 存储和审看你的 Siri 与听写请求录音。",
      changes: [.forced("com.apple.assistant.support", "Siri Data Sharing Opt-In Status", .int(2))],
      presets: [.recommended, .privacy]),
    Tweak(
      id: "improve-search", group: .privacy, title: "关闭改进搜索",
      detail: "阻止 Apple 保存你的聚焦搜索、Safari 和查询（Look Up）搜索记录来改进搜索。",
      changes: [.forced("com.apple.assistant.support", "Search Queries Data Sharing Status", .int(2))],
      presets: [.recommended, .privacy]),
    Tweak(
      id: "spotlight-web", group: .privacy, title: "关闭聚焦搜索互联网结果",
      detail: "让聚焦搜索只在你的 Mac 上进行，而不是发送给 Apple 以获取网页建议。",
      changes: [.restriction("allowSpotlightInternetResults")], presets: [.recommended, .privacy]),
    Tweak(
      id: "lookup-suggestions", group: .privacy, title: "关闭查询建议",
      detail: "阻止查询（Look Up）功能将你选中的词语发送给 Apple 以获取网页结果。",
      changes: [.forced("com.apple.lookup.shared", "LookupSuggestionsDisabled", .bool(true))],
      presets: [.recommended, .privacy]),
    Tweak(
      id: "safari-suggestions", group: .privacy, title: "关闭 Safari 搜索建议",
      detail: "阻止 Safari 将你在地址栏输入的内容发送给搜索引擎和 Apple。",
      caveat: "输入时地址栏不再建议搜索。",
      changes: [
        .forced("com.apple.Safari", "UniversalSearchEnabled", .bool(false)),
        .forced("com.apple.Safari", "SuppressSearchSuggestions", .bool(true)),
      ], presets: [.privacy]),
    Tweak(
      id: "game-center", group: .privacy, title: "关闭 Game Center",
      detail: "关闭 Game Center，包括其登录提示、好友请求和通知。",
      caveat: "需要 Game Center 保存进度或在线游玩的游戏将失去这些功能。",
      changes: [.restriction("allowGameCenter")], presets: [.privacy]),

    // MARK: Annoyances
    Tweak(
      id: "click-to-desktop", group: .annoyances, title: "防止点击墙纸时隐藏窗口",
      detail: "避免误点墙纸时所有窗口都滑走。",
      changes: [.pref("com.apple.WindowManager", "EnableStandardClickToShowDesktop", .bool(false))],
      presets: [.recommended]),
    Tweak(
      id: "desktop-widgets", group: .annoyances, title: "隐藏桌面小组件",
      detail: "隐藏桌面上的小组件，包括台前调度中的小组件。",
      changes: [
        .pref("com.apple.WindowManager", "StandardHideWidgets", .bool(true)),
        .pref("com.apple.WindowManager", "StageManagerHideWidgets", .bool(true)),
      ]),
    Tweak(
      id: "media-keys", group: .annoyances, title: "关闭播放、暂停和切歌键",
      detail: "关闭媒体键背后的服务，使播放键无法打开音乐应用。",
      caveat: "这些按键在所有应用中都将失效，包括 VLC 和 Spotify。若要保留按键功能、仅阻止音乐应用打开，请改用“阻止 Music 启动”。",
      changes: [.service("com.apple.rcd")]),
    Tweak(
      id: "music-launches", group: .annoyances, title: "阻止 Music 启动，包括通过 AirPods 启动",
      detail: "停用 Music 的应用启动项，按 AirPods 不再打开它。不会安装任何后台辅助工具或描述文件。",
      caveat: "会关闭 Music 并阻止手动启动。macOS 更新替换 Music 的文件后需要重新应用。",
      changes: [.musicLaunches]),
    Tweak(
      id: "iphone-mirroring", group: .annoyances, title: "关闭 iPhone 镜像",
      detail: "关闭 iPhone 镜像，让该应用及其提示不再出现。",
      changes: [.restriction("allowiPhoneMirroring")], since: (15, 0)),

    // MARK: Apple apps
    Tweak(
      id: "music-classic", group: .apps, title: "在音乐应用中关闭 Apple Music",
      detail: "让音乐应用回归为只播放你自己资料库的播放器，去掉商店和订阅提示。",
      caveat: "Apple Music 订阅者将无法使用流媒体播放。",
      changes: [.restriction("allowMusicService")]),
    Tweak(
      id: "book-store", group: .apps, title: "关闭图书商店",
      detail: "从图书应用中移除商店，保留你自己的图书。",
      changes: [.restriction("allowBookstore")], since: (15, 0)),
    Tweak(
      id: "dock-apple-apps", group: .apps, title: "从程序坞移除不用的 Apple 应用",
      detail: "从程序坞移除 News、TV、音乐、播客、图书、无边记、地图和股市。应用仍保持安装。",
      changes: [.dockRemove([
        "com.apple.news", "com.apple.TV", "com.apple.Music", "com.apple.podcasts", "com.apple.iBooksX",
        "com.apple.freeform", "com.apple.Maps", "com.apple.stocks",
      ])], restart: ["Dock"]),

    // MARK: Finder
    Tweak(
      id: "file-extensions", group: .finder, title: "显示文件扩展名",
      detail: "显示每个文件的完整名称，更容易发现伪装成文档的文件。",
      changes: [.pref(Prefs.global, "AppleShowAllExtensions", .bool(true))], restart: ["Finder"],
      presets: [.recommended, .privacy]),
    Tweak(
      id: "hidden-files", group: .finder, title: "显示隐藏文件",
      detail: "显示 macOS 隐藏的文件，例如 .gitignore 和 .zshrc。按下 Command-Shift-句点 也可切换。",
      changes: [.pref("com.apple.finder", "AppleShowAllFiles", .bool(true))], restart: ["Finder"]),
    Tweak(
      id: "path-bar", group: .finder, title: "显示路径栏",
      detail: "在每个访达窗口底部显示当前文件夹的位置。",
      changes: [.pref("com.apple.finder", "ShowPathbar", .bool(true))], restart: ["Finder"],
      presets: [.recommended]),
    Tweak(
      id: "status-bar", group: .finder, title: "显示状态栏",
      detail: "在访达窗口底部显示项目数量和可用空间。",
      changes: [.pref("com.apple.finder", "ShowStatusBar", .bool(true))], restart: ["Finder"]),
    Tweak(
      id: "folders-first", group: .finder, title: "让文件夹排在文件上方",
      detail: "按名称排序时，文件夹始终排在文件上方。",
      changes: [.pref("com.apple.finder", "_FXSortFoldersFirst", .bool(true))], restart: ["Finder"],
      presets: [.recommended]),
    Tweak(
      id: "search-this-folder", group: .finder, title: "搜索当前文件夹",
      detail: "让访达搜索当前所在的文件夹，而不是整台 Mac。",
      changes: [.pref("com.apple.finder", "FXDefaultSearchScope", .string("SCcf"))], restart: ["Finder"]),
    Tweak(
      id: "extension-warning", group: .finder, title: "跳过扩展名更改警告",
      detail: "停止访达在每次更改文件扩展名时要求确认。",
      changes: [.pref("com.apple.finder", "FXEnableExtensionChangeWarning", .bool(false))], restart: ["Finder"]),
    Tweak(
      id: "path-in-title", group: .finder, title: "在标题栏显示完整路径",
      detail: "在访达窗口顶部显示完整的文件夹路径。",
      changes: [.pref("com.apple.finder", "_FXShowPosixPathInTitle", .bool(true))], restart: ["Finder"]),
    Tweak(
      id: "network-ds-store", group: .finder, title: "阻止在网络磁盘上生成 .DS_Store 文件",
      detail: "阻止访达在其他电脑的共享文件夹中留下 .DS_Store 文件。",
      changes: [.pref("com.apple.desktopservices", "DSDontWriteNetworkStores", .bool(true))],
      presets: [.recommended]),
    Tweak(
      id: "trash-30-days", group: .finder, title: "30 天后清倒废纸篓",
      detail: "删除在废纸篓中超过 30 天的项目，避免它占满磁盘。",
      changes: [.pref("com.apple.finder", "FXRemoveOldTrashItems", .bool(true))], restart: ["Finder"]),
    Tweak(
      id: "save-locally", group: .finder, title: "将新文稿存储在这台 Mac 上",
      detail: "让存储对话框默认从这台 Mac 开始，而不是 iCloud Drive。",
      changes: [.pref(Prefs.global, "NSDocumentSaveNewDocumentsToCloud", .bool(false))]),
    Tweak(
      id: "expanded-save", group: .finder, title: "展开存储对话框",
      detail: "以完整的文件夹浏览视图打开存储对话框，而不是精简版本。",
      changes: [.pref(Prefs.global, "NSNavPanelExpandedStateForSaveMode", .bool(true))]),
    Tweak(
      id: "show-library", group: .finder, title: "显示“资源库”文件夹",
      detail: "显示主文件夹中隐藏的资源库文件夹。",
      changes: [.showLibrary]),

    // MARK: Dock and windows
    Tweak(
      id: "dock-recents", group: .windows, title: "隐藏程序坞中的最近使用应用",
      detail: "阻止程序坞添加你最近打开的应用。",
      changes: [.pref("com.apple.dock", "show-recents", .bool(false))], restart: ["Dock"],
      presets: [.recommended]),
    Tweak(
      id: "dock-delay", group: .windows, title: "移除程序坞自动隐藏延迟",
      detail: "让隐藏的程序坞立即显示，而不是延迟半秒。",
      changes: [.pref("com.apple.dock", "autohide-delay", .double(0))], restart: ["Dock"]),
    Tweak(
      id: "dock-bounce", group: .windows, title: "停止程序坞图标弹跳",
      detail: "阻止程序坞图标在应用启动时弹跳。",
      changes: [.pref("com.apple.dock", "launchanim", .bool(false))], restart: ["Dock"]),
    Tweak(
      id: "minimize-to-app", group: .windows, title: "将窗口最小化到应用图标",
      detail: "将最小化的窗口收纳进其应用图标，而不是占满程序坞。",
      changes: [.pref("com.apple.dock", "minimize-to-application", .bool(true))], restart: ["Dock"]),
    Tweak(
      id: "window-animations", group: .windows, title: "关闭窗口打开动画",
      detail: "立即打开新窗口，而不是以缩放动画出现。",
      changes: [.pref(Prefs.global, "NSAutomaticWindowAnimationsEnabled", .bool(false))]),
    Tweak(
      id: "tile-margins", group: .windows, title: "移除平铺窗口之间的间隙",
      detail: "移除平铺到屏幕两侧的窗口周围的边距。",
      changes: [.pref("com.apple.WindowManager", "EnableTiledWindowMargins", .bool(false))], since: (15, 0)),
    Tweak(
      id: "screenshot-shadow", group: .windows, title: "移除窗口截图中的阴影",
      detail: "截取窗口截图时不再带有周围的大片投影。",
      changes: [.pref("com.apple.screencapture", "disable-shadow", .bool(true))], restart: ["SystemUIServer"]),

    // MARK: Typing
    Tweak(
      id: "autocorrect", group: .typing, title: "关闭自动更正",
      detail: "阻止 macOS 在你输入时更正词语。",
      changes: [.pref(Prefs.global, "NSAutomaticSpellingCorrectionEnabled", .bool(false))]),
    Tweak(
      id: "smart-punctuation", group: .typing, title: "关闭智能引号和破折号",
      detail: "保留你输入的直引号和双连字符，代码和终端环境需要这样。",
      changes: [
        .pref(Prefs.global, "NSAutomaticQuoteSubstitutionEnabled", .bool(false)),
        .pref(Prefs.global, "NSAutomaticDashSubstitutionEnabled", .bool(false)),
      ]),
    Tweak(
      id: "double-space-period", group: .typing, title: "关闭双击空格输入句号",
      detail: "阻止两个空格变成句号。",
      changes: [.pref(Prefs.global, "NSAutomaticPeriodSubstitutionEnabled", .bool(false))]),
    Tweak(
      id: "auto-capitalize", group: .typing, title: "关闭自动大写",
      detail: "阻止 macOS 将每句的第一个单词大写。",
      changes: [.pref(Prefs.global, "NSAutomaticCapitalizationEnabled", .bool(false))]),
    Tweak(
      id: "key-repeat", group: .typing, title: "长按按键时重复输入而不是显示声调",
      detail: "按住按键时持续重复输入，而不是打开声调菜单。",
      caveat: "请改用 Option 快捷键或字符显示程序输入声调字符。",
      changes: [.pref(Prefs.global, "ApplePressAndHoldEnabled", .bool(false))]),
  ]

  static func tweak(_ id: String) -> Tweak? { all.first { $0.id == id } }

  /// Maximum privacy builds on Recommended.
  static func preset(_ preset: Preset) -> [Tweak] {
    let names: Set<Preset> = preset == .privacy ? [.recommended, .privacy] : [preset]
    return all.filter { !$0.presets.isDisjoint(with: names) && $0.supported }
  }
}
