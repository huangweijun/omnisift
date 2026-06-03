import Foundation
import SwiftData

/// Service responsible for processing pending InsightCards.
/// Uses cloud API by default (fast, no memory pressure).
/// Local model is optional premium offline feature.
@MainActor
@Observable
class AIProcessingService {
    var isModelLoaded = false
    var isLoadingModel = false
    var isProcessing = false
    var processingProgress: Double = 0
    var currentCardID: UUID?
    var errorMessage: String?
    var showLimitReachedPaywall = false

    /// Processing mode
    enum ProcessingMode: String, CaseIterable {
        case cloud = "Cloud AI"
        case local = "On-Device"
    }

    var processingMode: ProcessingMode = .cloud

    private let cloudService = CloudAIService()
    private let webExtractionService = WebContentExtractionService()
    private let browserExtractionService = BrowserContentExtractionService()
    private let imageTextExtractionService = ImageTextExtractionService()
    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        // Cloud mode is always "ready"
        if processingMode == .cloud {
            isModelLoaded = true
        }
    }

    // MARK: - Model Lifecycle (only relevant for local mode)

    func loadModel() async {
        if processingMode == .cloud {
            isModelLoaded = true
            return
        }
        // Local model loading disabled — causes OOM on devices with < 8GB RAM.
        // iPhone 13 Pro (6GB) cannot load the 2.5GB monolithic model + 2.7GB embeddings.
        errorMessage = AppStrings(rawPreferenceValue: OutputLanguagePreference.stored.rawValue).onDeviceModelUnavailable
        isModelLoaded = false
    }

    // MARK: - Batch Processing

    func processAllPending() async {
        guard isModelLoaded, !isProcessing else { return }
        guard let modelContext else { return }

        isProcessing = true
        defer { isProcessing = false }

        let pendingRaw = ProcessingStatus.pending.rawValue
        let descriptor = FetchDescriptor<InsightCard>(
            predicate: #Predicate { $0.statusRawValue == pendingRaw },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let pendingCards = try? modelContext.fetch(descriptor),
              !pendingCards.isEmpty else { return }

        let isPremium = UserDefaults(suiteName: appGroupID)?.bool(forKey: "isPremium") ?? false

        for (index, card) in pendingCards.enumerated() {
            if DailyUsageTracker.isLimitReached(isPremium: isPremium) {
                showLimitReachedPaywall = true
                break
            }

            currentCardID = card.id
            processingProgress = Double(index) / Double(pendingCards.count)

            card.status = .processing
            try? modelContext.save()

            await processCard(card)

            processingProgress = Double(index + 1) / Double(pendingCards.count)
        }

        currentCardID = nil
        processingProgress = 0
    }

    // MARK: - Single Card Processing

    private func processCard(_ card: InsightCard) async {
        do {
            await extractImageTextIfNeeded(for: card)
            inferSourceURLIfNeeded(for: card)
            if card.contentType == .image, card.extractionStatus == .failed {
                if card.rawTextIsOnlyImagePlaceholder {
                    applyLocalUnreadableImageSummary(to: card)
                    upsertTopics(for: card)
                    linkRelatedCards(for: card)
                } else {
                    card.extractionStatus = .partialText
                }
                try? modelContext?.save()
                if card.status == .processed {
                    return
                }
            }

            await extractSourceContentIfNeeded(for: card)

            if applyLocalInaccessibleLinkSummaryIfNeeded(to: card) {
                upsertTopics(for: card)
                linkRelatedCards(for: card)
                try? modelContext?.save()
                return
            }

            let processingInput = ContentStructure.formattedForAIProcessing(
                title: card.sourceTitle ?? card.title,
                body: card.rawText
            )
            let result = try await cloudService.process(rawText: processingInput)
            let summary = ContentStructure.cleanSummaryText(result.summary)
            ?? ContentStructure.fallbackSummaryMarkdown(
                title: result.title,
                highlight: result.highlight,
                body: card.rawText,
                sourceURLString: card.sourceURLString,
                language: OutputLanguagePreference.stored.resolvedLanguage
            )

            card.title = result.title
            card.highlight = result.highlight
            card.summary = summary
            card.tags = result.tags
            card.topicNames = result.topics.isEmpty ? result.tags : result.topics
            card.keywordNames = result.keywords
            card.entityNames = result.entities.map(\.name)
            card.relationSummaries = result.relations.map { "\($0.source) \($0.predicate) \($0.target)" }
            card.formattedOriginalMarkdown = result.formattedOriginalMarkdown
            card.confidence = result.confidence
            card.status = .processed
            card.processedAt = Date()
            card.errorMessage = nil

            if card.sourceApp == nil || card.sourceApp == "Unknown" {
                card.sourceApp = inferSourceApp(from: card.sourceURL)
            }

            upsertTopics(for: card)
            upsertEntities(result.entities, for: card)
            upsertKnowledgeRelations(result.relations, confidence: result.confidence, for: card)
            linkRelatedCards(for: card)

            DailyUsageTracker.incrementUsage()
            try? modelContext?.save()
        } catch {
            card.status = .failed
            card.errorMessage = error.localizedDescription
            try? modelContext?.save()
        }
    }

    /// Retry a single failed card
    func retryCard(_ card: InsightCard) async {
        guard card.status == .failed else { return }
        let isPremium = UserDefaults(suiteName: appGroupID)?.bool(forKey: "isPremium") ?? false
        if DailyUsageTracker.isLimitReached(isPremium: isPremium) {
            showLimitReachedPaywall = true
            return
        }

        card.status = .processing
        card.errorMessage = nil
        try? modelContext?.save()

        await processCard(card)
    }

    /// Retry all failed cards
    func retryAllFailed() async {
        guard isModelLoaded, !isProcessing else { return }
        guard let modelContext else { return }

        isProcessing = true
        defer { isProcessing = false }

        let failedRaw = ProcessingStatus.failed.rawValue
        let descriptor = FetchDescriptor<InsightCard>(
            predicate: #Predicate { $0.statusRawValue == failedRaw },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let failedCards = try? modelContext.fetch(descriptor),
              !failedCards.isEmpty else { return }

        for card in failedCards {
            let isPremium = UserDefaults(suiteName: appGroupID)?.bool(forKey: "isPremium") ?? false
            if DailyUsageTracker.isLimitReached(isPremium: isPremium) { break }

            card.status = .processing
            card.errorMessage = nil
            try? modelContext.save()

            await processCard(card)
        }
    }

    // MARK: - Content Extraction

    private func extractImageTextIfNeeded(for card: InsightCard) async {
        guard card.contentType == .image,
              let attachmentFileName = card.attachmentFileName else {
            return
        }

        card.extractionStatus = .pending
        card.extractionError = nil
        try? modelContext?.save()

        let result = await imageTextExtractionService.extractText(fromAttachmentNamed: attachmentFileName)
        if result.status == .failed {
            card.extractionStatus = .failed
            card.extractionError = result.errorMessage
            return
        }

        card.rawText = result.text
        card.extractionStatus = result.status
        card.extractionError = nil
    }

    private func extractSourceContentIfNeeded(for card: InsightCard) async {
        guard let sourceURL = card.sourceURL else { return }
        guard shouldExtractSourceContent(for: card) else {
            return
        }

        let existingRawText = card.rawText
        card.extractionStatus = .pending
        card.extractionError = nil
        try? modelContext?.save()

        let fetchResult = await webExtractionService.extract(from: sourceURL)
        let result = await resolveBestURLExtraction(
            initialResult: fetchResult,
            sourceURL: sourceURL,
            existingRawTextCount: card.rawText.count
        )

        if result.status == .failed {
            if existingRawText.hasMeaningfulCapturedText {
                card.rawText = existingRawText
                card.extractionStatus = .partialText
            } else {
                card.extractionStatus = .failed
            }
            card.extractionError = result.errorMessage
            return
        }

        applyURLExtractionResult(result, to: card)
    }

    private func shouldExtractSourceContent(for card: InsightCard) -> Bool {
        switch card.extractionStatus {
        case .urlOnly, .partialText, .failed:
            return true
        case .fullText:
            return card.hasDiscoveredSourceURL && card.rawTextLooksLikeShareWrapper
        case .notNeeded, .pending:
            return false
        }
    }

    private func applyURLExtractionResult(
        _ result: WebContentExtractionService.ExtractionResult,
        to card: InsightCard
    ) {
        if let title = result.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty,
           card.sourceTitle?.isEmpty ?? true {
            card.sourceTitle = title
        }

        let normalizedBody = ContentStructure.normalizeExtractedBody(
            body: result.text,
            title: card.sourceTitle
        )

        if normalizedBody.count > card.rawText.count {
            card.rawText = normalizedBody
        }

        card.extractionStatus = result.status
        card.extractionError = nil
    }

    private func resolveBestURLExtraction(
        initialResult: WebContentExtractionService.ExtractionResult,
        sourceURL: URL,
        existingRawTextCount: Int
    ) async -> WebContentExtractionService.ExtractionResult {
        guard shouldTryBrowserExtraction(
            result: initialResult,
            existingRawTextCount: existingRawTextCount
        ) else {
            return initialResult
        }

        let browserResult = await browserExtractionService.extract(from: sourceURL)
        return bestExtractionResult(initialResult, browserResult)
    }

    private func shouldTryBrowserExtraction(
        result: WebContentExtractionService.ExtractionResult,
        existingRawTextCount: Int
    ) -> Bool {
        if result.status == .failed {
            return true
        }

        let extractedCount = max(result.text.count, existingRawTextCount)
        return result.status == .partialText && extractedCount < 500
    }

    private func bestExtractionResult(
        _ first: WebContentExtractionService.ExtractionResult,
        _ second: WebContentExtractionService.ExtractionResult
    ) -> WebContentExtractionService.ExtractionResult {
        if second.status == .failed {
            return first
        }
        if first.status == .failed {
            return second
        }
        if second.text.count > first.text.count {
            return second
        }
        if second.text.count == first.text.count,
           second.title != nil,
           first.title == nil {
            return second
        }
        return first
    }

    private func applyLocalInaccessibleLinkSummaryIfNeeded(to card: InsightCard) -> Bool {
        guard card.extractionStatus == .failed,
              card.sourceURL != nil,
              !card.rawText.hasMeaningfulCapturedText else {
            return false
        }

        let language = OutputLanguagePreference.stored.resolvedLanguage
        card.title = card.sourceTitle ?? language.inaccessibleLinkTitle
        card.highlight = language.inaccessibleLinkHighlight
        card.summary = language.inaccessibleLinkSummary
        card.tags = localizedFallbackLabels(for: language, english: ["Link", "Unreadable"])
        card.topicNames = localizedFallbackLabels(for: language, english: ["Saved Links"])
        card.keywordNames = localizedFallbackLabels(for: language, english: ["Blocked Page", "Shared Link"])
        card.entityNames = []
        card.relationSummaries = []
        card.formattedOriginalMarkdown = nil
        card.confidence = 0.2
        card.status = .processed
        card.processedAt = Date()
        card.errorMessage = nil
        return true
    }

    private func inferSourceURLIfNeeded(for card: InsightCard) {
        guard card.sourceURL == nil,
              let url = SourceURLValidator.firstValidatedWebURL(in: card.rawText) else {
            return
        }

        card.sourceURLString = url.absoluteString
        card.contentType = card.contentType == .image ? .image : .url
        if card.sourceApp == nil || card.sourceApp == "Unknown" {
            card.sourceApp = inferSourceApp(from: url)
        }
        if card.extractionStatus == .notNeeded || card.extractionStatus == .fullText {
            card.extractionStatus = .partialText
        }
    }

    private func applyLocalUnreadableImageSummary(to card: InsightCard) {
        let language = OutputLanguagePreference.stored.resolvedLanguage
        card.title = card.sourceTitle ?? language.unreadableImageTitle
        card.highlight = language.unreadableImageHighlight
        card.summary = language.unreadableImageSummary
        card.tags = localizedFallbackLabels(for: language, english: ["Image", "OCR"])
        card.topicNames = localizedFallbackLabels(for: language, english: ["Image Captures"])
        card.keywordNames = localizedFallbackLabels(for: language, english: ["Unreadable Image", "OCR"])
        card.entityNames = []
        card.relationSummaries = []
        card.formattedOriginalMarkdown = nil
        card.confidence = 0.15
        card.status = .processed
        card.processedAt = Date()
        card.errorMessage = nil
    }

    private func localizedFallbackLabels(for language: OutputLanguage, english: [String]) -> [String] {
        guard language == .simplifiedChinese else {
            return english
        }

        return english.map { label in
            switch label {
            case "Link": "链接"
            case "Unreadable": "不可读取"
            case "Saved Links": "已保存链接"
            case "Blocked Page": "受限页面"
            case "Shared Link": "分享链接"
            case "Image": "图片"
            case "OCR": "文字识别"
            case "Image Captures": "图片采集"
            case "Unreadable Image": "不可读图片"
            default: label
            }
        }
    }

    // MARK: - Source App Inference

    private func inferSourceApp(from url: URL?) -> String? {
        guard let host = url?.host?.lowercased() else { return nil }
        let mapping: [(String, String)] = [
            ("deepseek.com", "DeepSeek"),
            ("chat.openai.com", "ChatGPT"),
            ("chatgpt.com", "ChatGPT"),
            ("claude.ai", "Claude"),
            ("perplexity.ai", "Perplexity"),
            ("weixin.qq.com", "微信公众号"),
            ("twitter.com", "Twitter"),
            ("x.com", "X"),
            ("zhihu.com", "知乎"),
            ("notion.so", "Notion"),
            ("github.com", "GitHub"),
            ("youtube.com", "YouTube"),
            ("bilibili.com", "Bilibili"),
            ("xiaohongshu.com", "小红书"),
        ]
        for (domain, name) in mapping {
            if host.contains(domain) { return name }
        }
        return host.split(separator: ".").dropLast().last.map(String.init)?.capitalized
    }

    // MARK: - Knowledge Organization

    private func upsertTopics(for card: InsightCard) {
        guard let modelContext else { return }
        let cardID = card.id.uuidString

        for name in card.topicNames.cleanedKnowledgeLabels(limit: 5) {
            let key = name.normalizedKnowledgeKey
            var descriptor = FetchDescriptor<Topic>(
                predicate: #Predicate { $0.normalizedName == key }
            )
            descriptor.fetchLimit = 1

            if let topic = try? modelContext.fetch(descriptor).first {
                if !topic.cardIDStrings.contains(cardID) {
                    topic.cardIDStrings.append(cardID)
                }
                topic.lastUpdatedAt = Date()
            } else {
                modelContext.insert(Topic(name: name, cardIDStrings: [cardID]))
            }
        }
    }

    private func upsertEntities(_ entities: [CloudAIService.ExtractedEntity], for card: InsightCard) {
        guard let modelContext else { return }
        let cardID = card.id.uuidString

        for entity in entities {
            let key = entity.name.normalizedKnowledgeKey
            var descriptor = FetchDescriptor<KnowledgeEntity>(
                predicate: #Predicate { $0.normalizedName == key }
            )
            descriptor.fetchLimit = 1

            if let existingEntity = try? modelContext.fetch(descriptor).first {
                if !existingEntity.cardIDStrings.contains(cardID) {
                    existingEntity.cardIDStrings.append(cardID)
                }
                existingEntity.kind = entity.kind
                existingEntity.lastSeenAt = Date()
            } else {
                modelContext.insert(KnowledgeEntity(name: entity.name, kind: entity.kind, cardIDStrings: [cardID]))
            }
        }
    }

    private func upsertKnowledgeRelations(
        _ relations: [CloudAIService.ExtractedRelation],
        confidence: Double,
        for card: InsightCard
    ) {
        guard let modelContext else { return }
        let cardID = card.id.uuidString
        let descriptor = FetchDescriptor<KnowledgeRelation>(
            predicate: #Predicate { $0.cardIDString == cardID }
        )
        let existingRelations = (try? modelContext.fetch(descriptor)) ?? []

        for relation in relations {
            let alreadyExists = existingRelations.contains {
                $0.cardIDString == cardID &&
                $0.sourceEntityName.normalizedKnowledgeKey == relation.source.normalizedKnowledgeKey &&
                $0.targetEntityName.normalizedKnowledgeKey == relation.target.normalizedKnowledgeKey &&
                $0.predicate.normalizedKnowledgeKey == relation.predicate.normalizedKnowledgeKey
            }

            if !alreadyExists {
                modelContext.insert(KnowledgeRelation(
                    sourceEntityName: relation.source,
                    targetEntityName: relation.target,
                    predicate: relation.predicate,
                    cardIDString: cardID,
                    confidence: confidence
                ))
            }
        }
    }

    private func linkRelatedCards(for card: InsightCard) {
        guard let modelContext else { return }
        let cardID = card.id.uuidString
        var descriptor = FetchDescriptor<InsightCard>(
            predicate: #Predicate { $0.statusRawValue == "processed" },
            sortBy: [SortDescriptor(\.processedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        let processedCards = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.id != card.id }

        let candidates = processedCards
            .map { otherCard in
                (card: otherCard, score: relatednessScore(between: card, and: otherCard))
            }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(3)

        card.relatedCardIDStrings = candidates.map { $0.card.id.uuidString }

        let existingDescriptor = FetchDescriptor<CardRelation>(
            predicate: #Predicate { $0.sourceCardIDString == cardID }
        )
        let existingRelations = (try? modelContext.fetch(existingDescriptor)) ?? []

        for candidate in candidates {
            let targetID = candidate.card.id.uuidString
            guard !existingRelations.contains(where: { $0.targetCardIDString == targetID }) else {
                continue
            }
            let sharedLabels = sharedKnowledgeLabels(between: card, and: candidate.card)
            let strings = AppStrings(rawPreferenceValue: OutputLanguagePreference.stored.rawValue)
            modelContext.insert(CardRelation(
                sourceCardIDString: cardID,
                targetCardIDString: targetID,
                relationType: .related,
                reason: sharedLabels.isEmpty ? strings.relatedReasonSimilar : "\(strings.relatedReasonSharedPrefix): \(sharedLabels.joined(separator: ", "))",
                confidence: min(0.95, 0.45 + Double(candidate.score) * 0.1)
            ))
        }
    }

    private func relatednessScore(between first: InsightCard, and second: InsightCard) -> Int {
        let firstLabels = Set((first.topicNames + first.tags + first.keywordNames + first.entityNames).map(\.normalizedKnowledgeKey))
        let secondLabels = Set((second.topicNames + second.tags + second.keywordNames + second.entityNames).map(\.normalizedKnowledgeKey))
        return firstLabels.intersection(secondLabels).count
    }

    private func sharedKnowledgeLabels(between first: InsightCard, and second: InsightCard) -> [String] {
        let secondKeys = Set((second.topicNames + second.tags + second.keywordNames + second.entityNames).map(\.normalizedKnowledgeKey))
        return (first.topicNames + first.tags + first.keywordNames + first.entityNames)
            .filter { secondKeys.contains($0.normalizedKnowledgeKey) }
            .cleanedKnowledgeLabels(limit: 3)
    }
}

private extension InsightCard {
    var hasDiscoveredSourceURL: Bool {
        guard let sourceURLString else { return false }
        return rawText.localizedCaseInsensitiveContains(sourceURLString) ||
            SourceURLValidator.firstValidatedWebURL(in: rawText)?.absoluteString == sourceURLString
    }

    var rawTextLooksLikeShareWrapper: Bool {
        let cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }

        let lowered = cleaned.lowercased()
        let wrapperMarkers = [
            "打开 app",
            "app内打开",
            "app 内打开",
            "复制链接",
            "复制这条信息",
            "打开小红书",
            "xhslink.com",
            "xiaohongshu.com",
            "read more",
            "open app",
            "open in app",
            "copy link"
        ]
        if wrapperMarkers.contains(where: { lowered.contains($0) }) {
            return true
        }

        guard SourceURLValidator.firstValidatedWebURL(in: cleaned) != nil else {
            return false
        }
        return cleaned.count < 1200
    }

    var rawTextIsOnlyImagePlaceholder: Bool {
        let cleanedRawText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedRawText.isEmpty else { return true }

        let placeholderValues = [
            AppStrings(rawPreferenceValue: OutputLanguagePreference.english.rawValue).imageCapturedForOCR,
            AppStrings(rawPreferenceValue: OutputLanguagePreference.simplifiedChinese.rawValue).imageCapturedForOCR
        ]

        return placeholderValues.contains(cleanedRawText)
    }
}

private extension String {
    var hasMeaningfulCapturedText: Bool {
        let cleaned = trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 80 else { return false }

        var withoutURLs = cleaned.replacingOccurrences(
            of: #"(?i)\b(?:https?://|www\.)[^\s<>"']+"#,
            with: "",
            options: .regularExpression
        )

        let noiseMarkers = [
            "打开 APP",
            "APP内打开",
            "APP 内打开",
            "复制链接",
            "复制这条信息",
            "打开小红书",
            "Open App",
            "Open in app",
            "Copy link"
        ]
        for marker in noiseMarkers {
            withoutURLs = withoutURLs.replacingOccurrences(
                of: marker,
                with: "",
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }

        let compact = withoutURLs.replacingOccurrences(
            of: #"[^\p{L}\p{N}]"#,
            with: "",
            options: .regularExpression
        )
        return compact.count >= 30
    }
}

private extension Array where Element == String {
    func cleanedKnowledgeLabels(limit: Int) -> [String] {
        var seen = Set<String>()
        return compactMap { label -> String? in
            let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return nil }
            let key = cleaned.normalizedKnowledgeKey
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return cleaned
        }
        .prefix(limit)
        .map { $0 }
    }
}
