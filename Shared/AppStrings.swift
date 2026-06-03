import Foundation

struct AppStrings {
    let language: OutputLanguage

    init(rawPreferenceValue: String) {
        language = OutputLanguagePreference(rawValue: rawPreferenceValue)?
            .resolvedLanguage ?? OutputLanguagePreference.automatic.resolvedLanguage
    }

    var locale: Locale {
        switch language {
        case .english: Locale(identifier: "en_US")
        case .simplifiedChinese: Locale(identifier: "zh_Hans_CN")
        }
    }

    var appName: String { text("OmniSift", "知漏") }
    var knowledgeMapTab: String { text("Map", "地图") }
    var libraryTab: String { text("Library", "知识库") }
    var settingsTab: String { text("Settings", "设置") }

    var todayUsage: String { text("Today's Usage", "今日用量") }
    var aiProcessing: String { text("AI Processing", "智能处理") }
    var upgradeToPro: String { text("Upgrade to Pro", "升级到专业版") }
    var languageSection: String { text("Language", "语言") }
    var summaryLanguage: String { text("Summary Language", "总结语言") }
    var mode: String { text("Mode", "模式") }
    var cloudAI: String { text("Cloud AI", "云端智能") }
    var status: String { text("Status", "状态") }
    var ready: String { text("Ready", "已就绪") }
    var notConfigured: String { text("Not configured", "未配置") }
    var latency: String { text("Latency", "延迟") }
    var perCardLatency: String { text("~2-5s per card", "每张约 2-5 秒") }
    var privacy: String { text("Privacy", "隐私") }
    var articleExtractionOnDevice: String { text("Article extraction runs on device first", "文章提取优先在设备端运行") }
    var textSentToCloud: String { text("Text sent to cloud for processing", "文本会发送到云端处理") }
    var sourceLinksAttached: String { text("Source links stay attached for review", "来源链接会保留便于回看") }
    var noAccountRequired: String { text("No account required", "无需账号") }
    var cardsStoredLocally: String { text("Cards stored locally on device", "卡片本地存储在设备上") }
    var account: String { text("Account", "账号") }
    var proActive: String { text("Pro Active", "专业版已生效") }
    var restorePurchases: String { text("Restore Purchases", "恢复购买") }
    var about: String { text("About", "关于") }
    var version: String { text("Version", "版本") }
    var privacyPolicy: String { text("Privacy Policy", "隐私政策") }
    var unlimitedModeActive: String { text("Unlimited Mode Active", "无限模式已开启") }
    var proPrice: String { text("$1.99/month, $9.99/year, or $14.99 lifetime", "每月 12 元、每年 68 元或永久 99 元") }
    var proProductName: String { text("OmniSift Pro", "知漏专业版") }
    var proHeadline: String { text("Turn every save into structured knowledge.", "把每次收藏变成结构化知识。") }
    var proDescription: String {
        text(
            "Unlock 50 AI processing uses per day, cleaner cards, and faster knowledge organization.",
            "解锁每日 50 次智能处理、更精美的卡片，以及更快的知识整理。"
        )
    }
    var choosePlan: String { text("Choose your plan", "选择套餐") }
    var loadingPlans: String { text("Loading plans...", "正在加载套餐...") }
    var plansUnavailable: String { text("Plans unavailable", "暂时无法显示套餐") }
    var plansUnavailableDescription: String {
        text(
            "Plans are taking a moment to load. Check your connection and try again.",
            "套餐加载需要一点时间，请检查网络后重试。"
        )
    }
    var loadPlansFailed: String { text("Plans are taking longer than expected.", "套餐加载时间较长。") }
    var storeUnavailable: String { text("Plans are temporarily unavailable.", "套餐暂时无法显示。") }
    var continueButton: String { text("Continue", "继续") }
    func continueWithPrice(_ price: String) -> String {
        switch language {
        case .english: "Continue - \(price)"
        case .simplifiedChinese: "继续 - \(price)"
        }
    }
    var purchaseInProgress: String { text("Purchasing...", "正在购买...") }
    var purchaseFailed: String { text("Purchase failed. Please try again.", "购买失败，请重试。") }
    var purchaseCompletedWithoutPro: String { text("Purchase completed, but Pro is not active yet.", "购买已完成，但专业版尚未生效。") }
    var restoringPurchases: String { text("Restoring...", "正在恢复...") }
    var restoreFailed: String { text("No active purchase was found.", "没有找到有效购买。") }
    var selectedPlan: String { text("Selected", "已选择") }
    var bestValue: String { text("Best value", "更划算") }
    var introOffer: String { text("Intro offer", "首期优惠") }
    var purchasePrivacyNote: String { text("Secure checkout by Apple. Renews until canceled.", "由应用商店安全结算，可随时取消续订。") }
    var termsOfUse: String { text("Terms of Use (EULA)", "使用条款 (EULA)") }
    var weeklyPlan: String { text("Weekly", "周付") }
    var monthlyPlan: String { text("Monthly", "月付") }
    var twoMonthPlan: String { text("2 Months", "两个月") }
    var threeMonthPlan: String { text("3 Months", "三个月") }
    var sixMonthPlan: String { text("6 Months", "半年") }
    var annualPlan: String { text("Annual", "年付") }
    var lifetimePlan: String { text("Lifetime", "永久版") }
    var subscriptionPlan: String { text("Subscription", "订阅套餐") }

    var autoLanguageHelp: String {
        text(
            "Auto uses Chinese in mainland China and English elsewhere. New summaries and app text follow this setting.",
            "自动模式会在中国大陆使用中文，其他地区使用英文。新的总结和应用文案会跟随此设置。"
        )
    }
    var chineseLanguageHelp: String {
        text(
            "App text, new summaries, topics, tags, and extracted entities will be written in Chinese.",
            "应用文案、新总结、主题、标签和实体抽取都会使用中文。"
        )
    }
    var englishLanguageHelp: String {
        text(
            "App text, new summaries, topics, tags, and extracted entities will be written in English.",
            "应用文案、新总结、主题、标签和实体抽取都会使用英文。"
        )
    }
    func languagePreferenceName(_ preference: OutputLanguagePreference) -> String {
        switch preference {
        case .automatic: text("Auto", "自动")
        case .simplifiedChinese: text("Chinese", "中文")
        case .english: text("English", "英文")
        }
    }

    var startCollecting: String { text("Start Collecting", "开始收集") }
    var emptyStateDescription: String {
        text(
            "Share text, links, articles, or screenshots to capture\nAI insights and build your knowledge library.",
            "分享文本、链接、文章或截图，提取智能洞察\n并构建你的个人知识库。"
        )
    }
    var instructionOpen: String { text("Open text, a link, an article, or a screenshot", "打开文本、链接、文章或截图") }
    var instructionShare: String { text("Tap the Share button", "点击系统分享按钮") }
    var instructionChooseApp: String { text("Choose OmniSift", "选择知漏") }
    var instructionAI: String { text("AI extracts, classifies & links it", "智能提取、归类并建立关联") }
    var clipboardXiaohongshuTitle: String { text("Xiaohongshu link copied", "发现小红书链接") }
    var clipboardXiaohongshuMessage: String { text("Collect this copied link into OmniSift?", "要收集到知漏吗？") }
    var clipboardImageTitle: String { text("Image copied", "发现复制的图片") }
    var clipboardImageMessage: String { text("Run OCR and collect it into OmniSift?", "要识别并收集到知漏吗？") }
    var collect: String { text("Collect", "收集") }
    var ignore: String { text("Ignore", "忽略") }
    var dontAskAgainForThisLink: String { text("Do not ask for this link", "不再提示此链接") }
    var clipboardSaveFailed: String { text("Could not collect from clipboard.", "无法从剪贴板收集。") }
    var clipboardURLCapture: String { text("Clipboard URL", "剪贴板链接") }
    var clipboardImageCapture: String { text("Clipboard Image", "剪贴板图片") }

    var knowledgeMapTitle: String { text("Knowledge Map", "知识地图") }
    var knowledgeMapDescription: String { text("Collecting lights the map; the compass reads it and points to the next route.", "收集会点亮星图，罗盘会读懂它并指向下一条探索路线。") }
    var knowledgeGalaxyTitle: String { text("Knowledge Galaxy", "知识星图") }
    var knowledgeGalaxyDescription: String { text("Every saved card lights a star. Themes become constellations, and relations draw routes between them.", "每张卡片都会点亮一颗星。主题形成星座，关联会在星座之间画出航线。") }
    var galaxySystems: String { text("Systems", "星系") }
    var galaxyConstellations: String { text("Constellations", "星座") }
    var galaxyStars: String { text("Stars", "星点") }
    var galaxyEntities: String { text("Entities", "实体") }
    var galaxyConnections: String { text("Links", "连接") }
    var galaxyLightingRule: String { text("More collected and processed cards light more stars inside each constellation.", "收集和整理越多，每个星座里被点亮的星点越多。") }
    func galaxyLitConstellations(count: Int) -> String {
        switch language {
        case .english: "\(count) lit"
        case .simplifiedChinese: "已点亮 \(count) 个"
        }
    }
    var galaxyFormingTitle: String { text("Your galaxy is forming", "你的星图正在形成") }
    var galaxyFormingDescription: String { text("Processed cards will become constellations as OmniSift learns your topics.", "知漏处理并理解卡片后，主题会逐渐长成星系。") }
    var galaxyRoot: String { text("Galaxy", "星图") }
    var backToGalaxy: String { text("Back in Galaxy", "返回上一层星图") }
    var organizeTopics: String { text("Organize Topics", "整理主题") }
    var topicOrganizationEntryDescription: String {
        text(
            "Review overview, signals, and AI star-map organization.",
            "查看总览、知识信号，并用 AI 整理星图结构。"
        )
    }
    var organizeStarMap: String { text("AI Organize Star Map", "智能整理星图") }
    var organizingStarMap: String { text("Organizing star map...", "正在整理星图...") }
    var aiStarMapProFeature: String { text("Pro feature. Upgrade to organize your star map.", "专业版功能，升级后可智能整理星图。") }
    var currentStarMapStructure: String { text("Current Star Map Structure", "当前星图结构") }
    var noStarMapStructure: String { text("Run AI organization to group topics into broad categories.", "运行智能整理，把主题归并成清晰的大类。") }
    var knowledgeOverview: String { text("Overview", "总览") }
    var savedInsightsLabel: String { text("Saved", "已保存") }
    var processedInsightsLabel: String { text("Processed", "已整理") }
    var topicClusters: String { text("Topic Clusters", "主题簇") }
    var topEntities: String { text("Top Entities", "高频实体") }
    var connectedIdeas: String { text("Connected Ideas", "关联想法") }
    var knowledgeSignals: String { text("Signals", "知识信号") }
    var knowledgeSignalsDescription: String {
        text(
            "Compressed signals from topics, entities, and links.",
            "把主题、实体和关联压缩成可扫读信号。"
        )
    }
    var openTopics: String { text("Open Topics", "查看主题") }
    var strongestSignal: String { text("Strongest", "最强信号") }
    var linkedIdeasSignal: String { text("Links", "关联") }
    var activeEntitiesSignal: String { text("Entities", "实体") }
    var needsAttention: String { text("Needs Attention", "待处理") }
    var noMapYet: String { text("Start collecting to grow your knowledge map.", "开始收集内容，知识地图会自动生长。") }
    var viewCards: String { text("View Cards", "查看卡片") }
    var knowledgeCompassTitle: String { text("Knowledge Compass", "知识罗盘") }
    var knowledgeCompassPageDescription: String {
        text(
            "A cockpit for reading your lit constellations, blind spots, and next routes.",
            "用来读取已点亮星座、知识暗区和下一条探索路线的驾驶舱。"
        )
    }
    var knowledgeCompassDescription: String {
        text(
            "Reads your star map, summarizes bright constellations, and points to what to explore next.",
            "读取你的星图，总结已点亮的星座，并指出下一步该探索什么。"
        )
    }
    var generateCompass: String { text("Generate Compass", "生成罗盘") }
    var refreshCompass: String { text("Refresh Compass", "刷新罗盘") }
    var generatingCompass: String { text("Generating compass...", "正在生成罗盘...") }
    var compassNotEnoughCards: String { text("Collect and process at least 4 cards to generate a compass.", "至少收集并整理 4 张卡片后，即可生成知识罗盘。") }
    var compassFocus: String { text("Lit", "已亮") }
    var compassJudgment: String { text("Pattern", "模式") }
    var compassGap: String { text("Dark", "暗区") }
    var compassExplore: String { text("Route", "路线") }
    var compassTapDirection: String { text("Tap a direction", "轻点方向") }
    var compassOrbitHint: String { text("Turn the compass to read lit areas, patterns, dark zones, and routes.", "转动罗盘，读取已亮区域、模式、暗区和路线。") }
    var compassActionDeck: String { text("Route Cards", "路线卡组") }
    var compassReadingLane: String { text("Map Reading", "星图解读") }
    var compassCurrentSignal: String { text("Compass Bearing", "罗盘方位") }
    var emergingJudgments: String { text("Cross-Constellation Patterns", "跨星座模式") }
    var knowledgeGaps: String { text("Dim Areas", "知识暗区") }
    var explorationDirections: String { text("Next Routes", "下一条路线") }
    var recommendedSearches: String { text("Search Prompts", "搜索提示") }
    func compassUpdated(_ date: Date) -> String {
        switch language {
        case .english: "Updated \(relativeAge(since: date))"
        case .simplifiedChinese: "\(relativeAge(since: date))更新"
        }
    }

    var noMatchingCards: String { text("No Matching Cards", "没有匹配卡片") }
    var noMatchingCardsDescription: String { text("Try another topic or search term.", "换一个主题或搜索词试试。") }
    var searchPrompt: String { text("Search insights, topics, sources", "搜索洞察、主题、来源") }
    var scopePicker: String { text("Scope", "范围") }
    var inboxScope: String { text("Inbox", "收件箱") }
    var libraryScope: String { text("Library", "知识库") }
    var allTopics: String { text("All Topics", "全部主题") }
    var processing: String { text("Processing...", "处理中...") }
    var retryAll: String { text("Retry All", "全部重试") }
    var retry: String { text("Retry", "重试") }
    var imageOCRCapture: String { text("Image OCR capture", "图片文字识别采集") }
    var pendingStatus: String { text("Pending", "待处理") }
    var processingStatus: String { text("Processing", "处理中") }
    var doneStatus: String { text("Done", "完成") }
    var failedStatus: String { text("Failed", "失败") }
    var textCapture: String { text("Text", "文本") }
    var urlCapture: String { text("URL", "链接") }
    var webCapture: String { text("Web", "网页") }
    var fileCapture: String { text("File", "文件") }
    var ocrCapture: String { text("OCR", "OCR") }
    var capture: String { text("Capture", "采集") }
    var extractingStatus: String { text("Extracting", "提取中") }
    var fullTextStatus: String { text("Full", "全文") }
    var partialTextStatus: String { text("Partial", "部分") }
    var urlOnlyStatus: String { text("URL Only", "仅链接") }
    var extractFailedStatus: String { text("Extract Failed", "提取失败") }

    var noTopicsYet: String { text("No Topics Yet", "还没有主题") }
    var noTopicsDescription: String { text("Topics will appear after OmniSift processes a few saved cards.", "知漏处理几张卡片后，会自动生成主题。") }
    var topicOrganizationTitle: String { text("Topic Organization", "主题整理") }
    var topicOrganizationDescription: String { text("Merge, rename, and correct AI-generated topics so your knowledge map stays useful.", "合并、重命名并修正智能生成的主题，让知识地图保持清晰可用。") }
    var renameTopic: String { text("Rename Topic", "重命名主题") }
    var mergeTopic: String { text("Merge Topic", "合并主题") }
    var mergeInto: String { text("Merge Into", "合并到") }
    var removeFromTopic: String { text("Remove from Topic", "从主题中移除") }
    var topicRenamePlaceholder: String { text("Topic name", "主题名称") }
    var topicOrganizationFailed: String { text("Topic update failed", "主题更新失败") }
    var topicMergeConfirmation: String { text("Choose a topic to merge into.", "选择要合并到的目标主题。") }
    func updated(_ date: Date) -> String {
        let formattedDate = date.formatted(.dateTime.month().day().hour().minute().locale(locale))
        return switch language {
        case .english: "Updated \(formattedDate)"
        case .simplifiedChinese: "更新于 \(formattedDate)"
        }
    }
    func savedInsights(count: Int) -> String {
        return switch language {
        case .english: "\(count) saved insights"
        case .simplifiedChinese: "\(count) 条已保存洞察"
        }
    }
    func subtopicCount(_ count: Int) -> String {
        return switch language {
        case .english: "\(count) subtopics"
        case .simplifiedChinese: "\(count) 个子主题"
        }
    }
    func relativeAge(since date: Date, now: Date = Date()) -> String {
        let elapsedSeconds = max(0, Int(now.timeIntervalSince(date)))
        let minute = 60
        let hour = minute * 60
        let day = hour * 24
        let month = day * 30
        let year = day * 365

        if elapsedSeconds < minute {
            return text("Just now", "刚刚")
        }
        if elapsedSeconds < hour {
            let minutes = max(1, elapsedSeconds / minute)
            return switch language {
            case .english: "\(minutes) min ago"
            case .simplifiedChinese: "\(minutes) 分钟前"
            }
        }
        if elapsedSeconds < day {
            let hours = max(1, elapsedSeconds / hour)
            return switch language {
            case .english: "\(hours) hr ago"
            case .simplifiedChinese: "\(hours) 小时前"
            }
        }
        if elapsedSeconds < day * 7 {
            let days = elapsedSeconds / day
            let hours = (elapsedSeconds % day) / hour
            return switch language {
            case .english:
                hours > 0 ? "\(days) \(days == 1 ? "day" : "days"), \(hours) hr" : "\(days) \(days == 1 ? "day" : "days") ago"
            case .simplifiedChinese:
                hours > 0 ? "\(days) 天 \(hours) 小时前" : "\(days) 天前"
            }
        }
        if elapsedSeconds < month {
            let weeks = max(1, elapsedSeconds / (day * 7))
            return switch language {
            case .english: "\(weeks) \(weeks == 1 ? "week" : "weeks") ago"
            case .simplifiedChinese: "\(weeks) 周前"
            }
        }
        if elapsedSeconds < year {
            let months = max(1, elapsedSeconds / month)
            return switch language {
            case .english: "\(months) \(months == 1 ? "month" : "months") ago"
            case .simplifiedChinese: "\(months) 个月前"
            }
        }

        let years = max(1, elapsedSeconds / year)
        return switch language {
        case .english: "\(years) \(years == 1 ? "year" : "years") ago"
        case .simplifiedChinese: "\(years) 年前"
        }
    }

    var exportAsImage: String { text("Export as Image", "导出为图片") }
    var copyText: String { text("Copy Text", "复制文本") }
    var delete: String { text("Delete", "删除") }
    var deleteCardQuestion: String { text("Delete this card?", "删除这张卡片？") }
    var source: String { text("Source", "来源") }
    var summaryTab: String { text("Summary", "摘要") }
    var originalTab: String { text("Original", "原文") }
    var sourceTab: String { text("Source", "来源") }
    var sourceDetails: String { text("Source Details", "来源详情") }
    var originalContent: String { text("Original Content", "原始内容") }
    var openSource: String { text("Open Source", "打开来源") }
    func openSourceInApp(_ appName: String) -> String {
        switch language {
        case .english: appName == source ? openSource : "Open in \(appName)"
        case .simplifiedChinese: appName == source ? openSource : "用\(appName)打开"
        }
    }
    var noSourceLink: String { text("No source link saved.", "没有保存来源链接。") }
    var invalidSourceLink: String { text("This source link cannot be opened safely.", "这个来源链接无法安全打开。") }
    var deleteFailed: String { text("Delete failed", "删除失败") }
    var ok: String { text("OK", "确定") }
    var detailContentPicker: String { text("Content", "内容") }
    var originalImageRetained: String { text("Original image retained for OCR capture", "原图已保留用于文字识别采集") }
    var knowledge: String { text("Knowledge", "知识") }
    var topics: String { text("Topics", "主题") }
    var tags: String { text("Tags", "标签") }
    var entities: String { text("Entities", "实体") }
    var relations: String { text("Relations", "关系") }
    var relatedInsights: String { text("Related Insights", "相关洞察") }
    var untitled: String { text("Untitled", "未命名") }
    var summary: String { text("Summary", "总结") }
    var originalText: String { text("Original Text", "原文") }
    var insight: String { text("Insight", "洞察") }
    var copiedToClipboard: String { text("Copied to clipboard", "已复制到剪贴板") }
    var savedToPhotos: String { text("Saved to Photos", "已保存到相册") }
    var copyTopicsPrefix: String { text("Topics:", "主题：") }
    var relatedReasonSimilar: String { text("Similar saved insight", "相似的已保存洞察") }
    var relatedReasonSharedPrefix: String { text("Shared", "共同标签") }
    func chars(_ count: Int) -> String {
        return switch language {
        case .english: "\(count) chars"
        case .simplifiedChinese: "\(count) 字符"
        }
    }
    func entityKind(_ kind: String) -> String {
        switch kind.normalizedKnowledgeKey {
        case "person": return text("Person", "人物")
        case "company": return text("Company", "公司")
        case "product": return text("Product", "产品")
        case "concept": return text("Concept", "概念")
        case "place": return text("Place", "地点")
        case "event": return text("Event", "事件")
        case "other": return text("Other", "其他")
        default: return kind
        }
    }
    func localizedRelationReason(_ reason: String) -> String {
        if reason == "Similar saved insight" {
            return relatedReasonSimilar
        }
        if reason.hasPrefix("Shared: ") {
            return "\(relatedReasonSharedPrefix): \(reason.dropFirst("Shared: ".count))"
        }
        return reason
    }
    func localizedExtractionError(_ error: String) -> String {
        switch error {
        case "Invalid source URL":
            return text("Invalid source URL", "来源链接无效")
        case "Only http and https links can be extracted":
            return text("Only http and https links can be extracted", "只能提取网页链接")
        case "The page did not return readable content":
            return text("The page did not return readable content", "页面没有返回可读内容")
        case "The link is not a readable web page":
            return text("The link is not a readable web page", "该链接不是可读取的网页")
        case "The in-app browser timed out while loading the page":
            return text("The in-app browser timed out while loading the page", "应用内浏览器加载页面超时")
        case "The in-app browser loaded the page but found no readable text":
            return text("The in-app browser loaded the page but found no readable text", "应用内浏览器已加载页面，但没有找到可读正文")
        case "Private or local network links cannot be extracted":
            return text("Private or local network links cannot be extracted", "无法提取私有或本地网络链接")
        case "Could not create shared data store.":
            return text("Could not create shared data store.", "无法创建共享数据存储。")
        case "The attachment file name is invalid.":
            return text("The attachment file name is invalid.", "附件文件名无效。")
        case "Rate limited. Try again later.":
            return text("Rate limited. Try again later.", "请求过于频繁，请稍后再试。")
        case "Cloud service unauthorized.":
            return text("Cloud service unauthorized.", "云端服务未授权。")
        case "Cloud service app secret is not configured.":
            return text("Cloud service app secret is not configured.", "云端服务密钥未配置。")
        case "Cloud service rejected authorization.":
            return text("Cloud service rejected authorization.", "云端服务拒绝授权。")
        default:
            if error.hasPrefix("App Group container is not available:") {
                return text(error, "应用组容器不可用。")
            }
            if error.hasPrefix("Could not create shared data store.") {
                return text(error, "无法创建共享数据存储。")
            }
            if error.hasPrefix("Network: ") {
                return text(error, "网络错误：\(error.dropFirst("Network: ".count))")
            }
            if error.hasPrefix("API(") {
                return text(error, "API 错误：\(error)")
            }
            if error.hasPrefix("Parse failed: ") {
                return text(error, "解析失败：\(error.dropFirst("Parse failed: ".count))")
            }
            return error
        }
    }

    var proDailyAIProcessing: String { text("50 AI processing uses per day", "每日 50 次智能处理") }
    var premiumCardTemplates: String { text("Premium card templates", "高级卡片模板") }
    var exportWithoutWatermark: String { text("Export without watermark", "无水印导出") }
    var priorityProcessing: String { text("Priority processing", "优先处理") }
    var subscribe: String { text("Subscribe", "订阅") }

    var dataStoreUnavailableTitle: String { text("Unable to open OmniSift data", "无法打开知漏数据") }
    var dataStoreUnavailableDescription: String {
        text(
            "Please restart the app. If this keeps happening, reinstalling may be required after backing up your data.",
            "请重启应用。如果问题持续出现，备份数据后可能需要重新安装。"
        )
    }

    var shareSaveToApp: String { text("Save to OmniSift", "保存到知漏") }
    var shareWillCleanLater: String { text("Collect now. AI will light the star map later.", "先采集下来，稍后点亮你的星图") }
    var cancel: String { text("Cancel", "取消") }
    var extractingContent: String { text("Extracting content...", "正在提取内容...") }
    var imageSavedForOCR: String { text("Image saved. OmniSift will run OCR after import.", "图片已保存，导入后知漏会识别其中的文字。") }
    var shareIncomingSignal: String { text("Incoming signal", "采集信号") }
    var shareReadyToLight: String { text("Ready to become a star", "准备点亮一颗新星") }
    var shareNoReadablePreview: String { text("No readable preview yet. The source will still be saved.", "暂时没有可读预览，仍会保留来源。") }
    var save: String { text("Save", "保存") }
    var saving: String { text("Saving...", "保存中...") }
    var shareSaveError: String { text("Could not save. Please try again.", "无法保存，请重试。") }
    var imageCapturedForOCR: String { text("Image captured for OCR", "已采集图片，等待文字识别") }
    var shareExtensionUnavailableTitle: String { text("Unable to open OmniSift", "无法打开知漏") }
    var close: String { text("Close", "关闭") }
    var onDeviceModelUnavailable: String { text("On-device model requires iPhone 15 Pro or newer (8GB+ RAM)", "端侧模型需要 iPhone 15 Pro 或更新机型（8GB 以上内存）。") }
    func freeUsesRemaining(_ count: Int) -> String {
        return switch language {
        case .english: "\(count) free uses remaining today"
        case .simplifiedChinese: "今日还剩 \(count) 次免费使用"
        }
    }

    private func text(_ english: String, _ simplifiedChinese: String) -> String {
        return switch language {
        case .english: english
        case .simplifiedChinese: simplifiedChinese
        }
    }
}
