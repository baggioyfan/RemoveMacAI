import Foundation

/// A preference the profile forces while a feature is off.
struct ForcedPreference: Equatable {
  let domain: String
  let key: String
  let off: Bool
}

/// One thing a person can switch off, the switches it takes, and the model
/// sets it needs. Keys and sets for macOS 27 were first mapped by pared
/// (github.com/4evy/pared, MIT).
struct Feature {
  let id: String
  let title: String
  let restrictions: [String]
  let preferences: [ForcedPreference]
  let modelSets: [String]
}

/// A downloadable model set in Apple's asset service.
struct ModelSet {
  let name: String
  let assetType: String
  let title: String
}

enum Catalog {
  static let foundationModels = "com.apple.modelcatalog"
  static let visualModels = "com.apple.MobileAsset.UAF.FM.Visual"
  static let codeModels = "com.apple.MobileAsset.UAF.FM.CodeLM"
  static let cleanUpModels = "com.apple.MobileAsset.UAF.Photos.MagicCleanup"
  static let spatialModels = "com.apple.MobileAsset.UAF.Photos.SpatialPhotosRelive"

  static let modelSets: [ModelSet] = [
    ModelSet(
      name: foundationModels, assetType: "com.apple.MobileAsset.UAF.FM.GenerativeModels",
      title: "Apple 智能基础模型"),
    ModelSet(name: visualModels, assetType: visualModels, title: "图像与 Genmoji 模型"),
    ModelSet(name: spatialModels, assetType: spatialModels, title: "空间照片模型"),
    ModelSet(name: cleanUpModels, assetType: cleanUpModels, title: "照片清理模型"),
    ModelSet(name: codeModels, assetType: codeModels, title: "Xcode 代码补全模型"),
  ]

  static let features: [Feature] = [
    Feature(
      id: "siri", title: "Siri 与 Siri AI", restrictions: ["allowAssistant"],
      preferences: [
        ForcedPreference(domain: "com.apple.assistant.support", key: "Assistant Enabled", off: false),
        ForcedPreference(domain: "com.apple.Siri", key: "StatusMenuVisible", off: false),
        ForcedPreference(domain: "com.apple.Siri", key: "VoiceTriggerUserEnabled", off: false),
      ], modelSets: [foundationModels]),
    Feature(
      id: "chatgpt", title: "ChatGPT 及其他 AI 扩展",
      restrictions: [
        "allowExternalIntelligenceIntegrations", "allowExternalIntelligenceIntegrationsSignIn",
      ], preferences: [], modelSets: []),
    Feature(
      id: "writing-tools", title: "写作工具", restrictions: ["allowWritingTools"],
      preferences: [], modelSets: [foundationModels]),
    Feature(
      id: "genmoji", title: "Genmoji", restrictions: ["allowGenmoji"], preferences: [],
      modelSets: [foundationModels, visualModels]),
    Feature(
      id: "image-playground", title: "图像游乐场", restrictions: ["allowImagePlayground"],
      preferences: [], modelSets: [foundationModels, visualModels]),
    Feature(
      id: "mail", title: "邮件摘要与智能回复",
      restrictions: ["allowMailSummary", "allowMailSmartReplies"],
      preferences: [
        ForcedPreference(
          domain: "group.com.apple.mail", key: "DisableAutomaticMessageSummarization", off: true),
        ForcedPreference(domain: "group.com.apple.mail", key: "PersonalizedSmartReplies", off: false),
      ], modelSets: [foundationModels]),
    Feature(
      id: "notification-summaries", title: "通知摘要", restrictions: [],
      preferences: [
        ForcedPreference(domain: "group.com.apple.usernoted", key: "summarize_previews", off: false)
      ], modelSets: [foundationModels]),
    Feature(
      id: "messages-summaries", title: "信息摘要", restrictions: [],
      preferences: [
        ForcedPreference(domain: "com.apple.MobileSMS", key: "messageSummarizationEnabled", off: false)
      ], modelSets: [foundationModels]),
    Feature(
      id: "safari-summaries", title: "Safari 摘要", restrictions: ["allowSafariSummary"],
      preferences: [], modelSets: [foundationModels]),
    Feature(
      id: "notes-summaries", title: "备忘录转录摘要",
      restrictions: ["allowNotesTranscriptionSummary"], preferences: [],
      modelSets: [foundationModels]),
    Feature(
      id: "inline-predictions", title: "内联文本预测", restrictions: [],
      preferences: [
        ForcedPreference(
          domain: ".GlobalPreferences", key: "NSAutomaticInlinePredictionEnabled", off: false)
      ], modelSets: []),
    Feature(
      id: "spatial-photos", title: "空间照片", restrictions: [],
      preferences: [
        ForcedPreference(domain: "com.apple.spatialphotosrelive", key: "LocallyDisabled", off: true)
      ], modelSets: [spatialModels]),
    Feature(
      id: "photos-clean-up", title: "照片清理", restrictions: [], preferences: [],
      modelSets: [cleanUpModels]),
    Feature(
      id: "xcode-completion", title: "Xcode 预测式代码补全", restrictions: [],
      preferences: [], modelSets: [codeModels]),
  ]

  static func feature(_ id: String) -> Feature? { features.first { $0.id == id } }

  static func modelSet(_ name: String) -> ModelSet? { modelSets.first { $0.name == name } }

  /// The sets to remove: every set whose features are all being turned off.
  /// A set that a kept feature still needs stays.
  static func setsToRemove(keeping kept: Set<String>) -> [String] {
    modelSets.map(\.name).filter { set in
      let users = features.filter { $0.modelSets.contains(set) }
      return !users.isEmpty && users.allSatisfy { !kept.contains($0.id) }
    }
  }
}
