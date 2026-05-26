import Foundation
import SwiftData

@MainActor
@Observable
final class KnowledgeCompassService {
    var report: CloudAIService.KnowledgeCompassResult?
    var generatedAt: Date?
    var isGenerating = false
    var lastRunError: String?

    private let cloudService = CloudAIService()
    private let automaticRefreshInterval: TimeInterval = 7 * 24 * 60 * 60
    private let minimumCardsForReport = 4
    private let newCardsRefreshThreshold = 10
    private let maxCardsPerReport = 24
    private let reportWindowDays = 30

    func configure() {
        loadCachedReport()
    }

    func generateIfNeeded(cards: [InsightCard]) async {
        clearCachedReportIfLanguageChanged()
        guard shouldGenerateAutomatically(cards: cards) else { return }
        await generateNow(cards: cards)
    }

    func generateNow(cards: [InsightCard]) async {
        clearCachedReportIfLanguageChanged()
        guard !isGenerating else { return }
        let processedCards = eligibleCards(from: cards)
        guard processedCards.count >= minimumCardsForReport else {
            lastRunError = nil
            return
        }

        isGenerating = true
        lastRunError = nil
        defer { isGenerating = false }

        do {
            let input = makeInput(from: processedCards)
            let result = try await cloudService.generateKnowledgeCompass(input)
            report = result
            generatedAt = Date()
            persist(result, processedCount: processedCards.count)
        } catch {
            lastRunError = error.localizedDescription
        }
    }

    private func shouldGenerateAutomatically(cards: [InsightCard]) -> Bool {
        guard !isGenerating else { return false }
        let processedCount = eligibleCards(from: cards).count
        guard processedCount >= minimumCardsForReport else { return false }
        guard report == nil || generatedAt == nil else {
            let defaults = UserDefaults(suiteName: appGroupID)
            let lastCount = defaults?.integer(forKey: UserDefaultsKeys.lastKnowledgeCompassProcessedCount) ?? 0
            let hasEnoughNewCards = processedCount - lastCount >= newCardsRefreshThreshold
            let isStale = generatedAt.map { Date().timeIntervalSince($0) >= automaticRefreshInterval } ?? true
            return hasEnoughNewCards || isStale
        }
        return true
    }

    private func eligibleCards(from cards: [InsightCard]) -> [InsightCard] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -reportWindowDays, to: Date()) ?? .distantPast
        return cards
            .filter { $0.status == .processed && $0.createdAt >= cutoff }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func makeInput(from cards: [InsightCard]) -> CloudAIService.KnowledgeCompassInput {
        CloudAIService.KnowledgeCompassInput(
            generatedAt: Date(),
            windowDays: reportWindowDays,
            cards: cards.prefix(maxCardsPerReport).map { card in
                CloudAIService.KnowledgeCompassCard(
                    title: ContentStructure.cleanDisplayText(card.title)
                        ?? ContentStructure.cleanDisplayText(card.sourceTitle)
                        ?? String(card.rawText.prefix(80)),
                    highlight: ContentStructure.cleanDisplayText(card.highlight),
                    summary: ContentStructure.cleanDisplayText(card.summary) ?? card.summary,
                    topics: card.topicNames.cleanedCompassLabels(limit: 5),
                    tags: card.tags.cleanedCompassLabels(limit: 5),
                    entities: card.entityNames.cleanedCompassLabels(limit: 8),
                    sourceTitle: ContentStructure.cleanDisplayText(card.sourceTitle),
                    capturedAt: card.createdAt
                )
            }
        )
    }

    private func persist(_ report: CloudAIService.KnowledgeCompassResult, processedCount: Int) {
        let defaults = UserDefaults(suiteName: appGroupID)
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(report) {
            defaults?.set(data, forKey: UserDefaultsKeys.cachedKnowledgeCompassReport)
        }
        defaults?.set(generatedAt, forKey: UserDefaultsKeys.lastKnowledgeCompassAt)
        defaults?.set(processedCount, forKey: UserDefaultsKeys.lastKnowledgeCompassProcessedCount)
        defaults?.set(OutputLanguagePreference.stored.resolvedLanguage.cacheKey, forKey: UserDefaultsKeys.lastKnowledgeCompassLanguage)
    }

    private func loadCachedReport() {
        let defaults = UserDefaults(suiteName: appGroupID)
        guard defaults?.string(forKey: UserDefaultsKeys.lastKnowledgeCompassLanguage) == OutputLanguagePreference.stored.resolvedLanguage.cacheKey else {
            return
        }
        generatedAt = defaults?.object(forKey: UserDefaultsKeys.lastKnowledgeCompassAt) as? Date
        guard let data = defaults?.data(forKey: UserDefaultsKeys.cachedKnowledgeCompassReport),
              let cached = try? JSONDecoder().decode(CloudAIService.KnowledgeCompassResult.self, from: data) else {
            return
        }
        report = cached
    }

    private func clearCachedReportIfLanguageChanged() {
        let defaults = UserDefaults(suiteName: appGroupID)
        let currentLanguage = OutputLanguagePreference.stored.resolvedLanguage.cacheKey
        let cachedLanguage = defaults?.string(forKey: UserDefaultsKeys.lastKnowledgeCompassLanguage)
        guard cachedLanguage != nil, cachedLanguage != currentLanguage else { return }
        report = nil
        generatedAt = nil
        defaults?.removeObject(forKey: UserDefaultsKeys.cachedKnowledgeCompassReport)
        defaults?.removeObject(forKey: UserDefaultsKeys.lastKnowledgeCompassAt)
        defaults?.removeObject(forKey: UserDefaultsKeys.lastKnowledgeCompassProcessedCount)
        defaults?.removeObject(forKey: UserDefaultsKeys.lastKnowledgeCompassLanguage)
    }
}

private extension OutputLanguage {
    var cacheKey: String {
        switch self {
        case .english: "english"
        case .simplifiedChinese: "simplifiedChinese"
        }
    }
}

private extension Array where Element == String {
    func cleanedCompassLabels(limit: Int) -> [String] {
        var seen = Set<String>()
        return compactMap { label -> String? in
            let cleaned = ContentStructure.cleanKnowledgeLabel(label)
                ?? label.trimmingCharacters(in: .whitespacesAndNewlines)
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
