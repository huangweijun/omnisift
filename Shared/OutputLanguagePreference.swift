import Foundation

enum OutputLanguagePreference: String, CaseIterable, Identifiable {
    case automatic
    case simplifiedChinese
    case english

    var id: Self { self }

    var displayName: String {
        switch self {
        case .automatic: "Auto"
        case .simplifiedChinese: "中文"
        case .english: "English"
        }
    }

    var resolvedLanguage: OutputLanguage {
        switch self {
        case .simplifiedChinese:
            return .simplifiedChinese
        case .english:
            return .english
        case .automatic:
            return Locale.current.isMainlandChinaRegion ? .simplifiedChinese : .english
        }
    }

    static var stored: OutputLanguagePreference {
        let rawValue = UserDefaults(suiteName: appGroupID)?
            .string(forKey: UserDefaultsKeys.outputLanguagePreference)
        return rawValue.flatMap(OutputLanguagePreference.init(rawValue:)) ?? .automatic
    }
}

enum OutputLanguage {
    case simplifiedChinese
    case english

    var aiInstruction: String {
        switch self {
        case .simplifiedChinese:
            return "Write all user-facing JSON string values in Simplified Chinese. Preserve product names, URLs, code identifiers, and proper nouns in their original language when appropriate."
        case .english:
            return "Write all user-facing JSON string values in English. Preserve product names, URLs, code identifiers, and proper nouns in their original language when appropriate."
        }
    }

    var inaccessibleLinkTitle: String {
        switch self {
        case .simplifiedChinese: "无法读取分享链接内容"
        case .english: "Unable to Read Shared Link"
        }
    }

    var inaccessibleLinkHighlight: String {
        switch self {
        case .simplifiedChinese: "这个链接需要登录、浏览器会话或动态渲染。已自动尝试应用内浏览器解析；若仍失败，请复制全文或分享截图。"
        case .english: "This link requires login, a browser session, or dynamic rendering. In-app browser extraction was attempted automatically; if it still fails, copy the full text or share screenshots."
        }
    }

    var inaccessibleLinkSummary: String {
        switch self {
        case .simplifiedChinese: "知漏已保存原始链接，并自动尝试了网页抓取与应用内浏览器渲染，但页面仍未返回可读正文。"
        case .english: "OmniSift saved the original link and automatically tried HTTP fetch plus in-app browser rendering, but the page still did not return readable text."
        }
    }
}

enum UserDefaultsKeys {
    static let outputLanguagePreference = "output_language_preference"
    static let lastKnowledgeCleanupAt = "last_knowledge_cleanup_at"
    static let cachedKnowledgeCompassReport = "cached_knowledge_compass_report"
    static let lastKnowledgeCompassAt = "last_knowledge_compass_at"
    static let lastKnowledgeCompassProcessedCount = "last_knowledge_compass_processed_count"
    static let lastKnowledgeCompassLanguage = "last_knowledge_compass_language"
}

private extension Locale {
    var isMainlandChinaRegion: Bool {
        region?.identifier.uppercased() == "CN"
    }
}
