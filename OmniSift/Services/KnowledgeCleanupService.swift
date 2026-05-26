import Foundation
import SwiftData

@MainActor
@Observable
final class KnowledgeCleanupService {
    enum CleanupReason {
        case launch
        case afterProcessing
        case appBecameActive
        case manual
    }

    var isCleaning = false
    var lastRunError: String?
    var lastCleanedAt: Date?

    private let automaticCleanupInterval: TimeInterval = 6 * 60 * 60
    private let maxTopicsPerCard = 5
    private let maxTagsPerCard = 8
    private let maxKeywordsPerCard = 10
    private let maxEntitiesPerCard = 10
    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        lastCleanedAt = UserDefaults(suiteName: appGroupID)?.object(forKey: UserDefaultsKeys.lastKnowledgeCleanupAt) as? Date
    }

    func runIfNeeded(reason: CleanupReason) async {
        guard shouldRunAutomatically(reason: reason) else { return }
        await runNow(reason: reason)
    }

    func runNow(reason: CleanupReason) async {
        guard !isCleaning, let modelContext else { return }

        isCleaning = true
        lastRunError = nil
        defer { isCleaning = false }

        do {
            try cleanup(using: modelContext)
            let now = Date()
            lastCleanedAt = now
            UserDefaults(suiteName: appGroupID)?.set(now, forKey: UserDefaultsKeys.lastKnowledgeCleanupAt)
        } catch {
            lastRunError = error.localizedDescription
        }
    }

    private func shouldRunAutomatically(reason: CleanupReason) -> Bool {
        guard !isCleaning else { return false }
        if reason == .manual { return true }

        let lastRun = lastCleanedAt
            ?? UserDefaults(suiteName: appGroupID)?.object(forKey: UserDefaultsKeys.lastKnowledgeCleanupAt) as? Date
        guard let lastRun else { return true }
        return Date().timeIntervalSince(lastRun) >= automaticCleanupInterval
    }

    private func cleanup(using modelContext: ModelContext) throws {
        let cards = try modelContext.fetch(FetchDescriptor<InsightCard>())
        let topics = try modelContext.fetch(FetchDescriptor<Topic>())
        let entities = try modelContext.fetch(FetchDescriptor<KnowledgeEntity>())
        let knowledgeRelations = try modelContext.fetch(FetchDescriptor<KnowledgeRelation>())
        let cardRelations = try modelContext.fetch(FetchDescriptor<CardRelation>())
        let validCardIDs = Set(cards.map { $0.id.uuidString })
        let originalTopicSnapshot = topicSnapshot(from: topics, validCardIDs: validCardIDs)

        for card in cards {
            card.topicNames = cleanedLabels(card.topicNames, limit: maxTopicsPerCard)
            card.tags = cleanedLabels(card.tags, limit: maxTagsPerCard)
            card.keywordNames = cleanedLabels(card.keywordNames, limit: maxKeywordsPerCard)
            card.entityNames = cleanedLabels(card.entityNames, limit: maxEntitiesPerCard)
            card.relatedCardIDStrings = cleanedIDs(card.relatedCardIDStrings, validCardIDs: validCardIDs, excluding: card.id.uuidString)
        }

        let topicIndex = buildTopicIndex(from: cards)
        let entityIndex = buildEntityIndex(from: cards)
        try mergeTopics(topics, topicIndex: topicIndex, validCardIDs: validCardIDs, using: modelContext)
        pruneEntities(entities, entityIndex: entityIndex, using: modelContext)
        pruneKnowledgeRelations(knowledgeRelations, validCardIDs: validCardIDs, using: modelContext)
        pruneCardRelations(cardRelations, validCardIDs: validCardIDs, using: modelContext)
        let updatedTopics = try modelContext.fetch(FetchDescriptor<Topic>())
        if topicSnapshot(from: updatedTopics, validCardIDs: validCardIDs) != originalTopicSnapshot {
            try clearHierarchy(using: modelContext)
        }

        try modelContext.save()
    }

    private func cleanedLabels(_ labels: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        return labels.compactMap { label in
            let cleaned = label
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            guard !cleaned.isEmpty else { return nil }
            let key = cleaned.normalizedKnowledgeKey
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return cleaned
        }
        .prefix(limit)
        .map { $0 }
    }

    private func cleanedIDs(_ ids: [String], validCardIDs: Set<String>, excluding currentCardID: String) -> [String] {
        var seen = Set<String>()
        return ids.compactMap { id in
            guard validCardIDs.contains(id), id != currentCardID, !seen.contains(id) else { return nil }
            seen.insert(id)
            return id
        }
    }

    private func buildTopicIndex(from cards: [InsightCard]) -> [String: TopicIndexEntry] {
        var index: [String: TopicIndexEntry] = [:]

        for card in cards where card.status == .processed {
            let labels = cleanedLabels(card.topicNames.isEmpty ? card.tags : card.topicNames, limit: maxTopicsPerCard)
            for label in labels {
                let key = label.normalizedKnowledgeKey
                guard !key.isEmpty else { continue }
                if index[key] == nil {
                    index[key] = TopicIndexEntry(name: label, cardIDStrings: [])
                }
                index[key]?.insertCardID(card.id.uuidString)
                index[key]?.recordDisplayName(label)
            }
        }

        return index.mapValues { entry in
            entry.withCanonicalDisplayName()
        }
    }

    private func buildEntityIndex(from cards: [InsightCard]) -> [String: Set<String>] {
        var index: [String: Set<String>] = [:]
        for card in cards where card.status == .processed {
            for entityName in cleanedLabels(card.entityNames, limit: maxEntitiesPerCard) {
                let key = entityName.normalizedKnowledgeKey
                guard !key.isEmpty else { continue }
                index[key, default: []].insert(card.id.uuidString)
            }
        }
        return index
    }

    private func mergeTopics(
        _ topics: [Topic],
        topicIndex: [String: TopicIndexEntry],
        validCardIDs: Set<String>,
        using modelContext: ModelContext
    ) throws {
        var topicsByKey: [String: [Topic]] = [:]
        for topic in topics {
            topicsByKey[topic.normalizedName, default: []].append(topic)
        }

        for (key, entry) in topicIndex {
            let existing = topicsByKey[key] ?? []
            if existing.isEmpty {
                modelContext.insert(Topic(name: entry.name, cardIDStrings: Array(entry.cardIDStrings).sorted()))
                continue
            }

            let keeper = existing[0]
            keeper.name = entry.name
            keeper.normalizedName = key
            keeper.cardIDStrings = Array(entry.cardIDStrings.intersection(validCardIDs)).sorted()
            keeper.lastUpdatedAt = Date()

            for duplicate in existing.dropFirst() {
                if keeper.summary?.isEmpty ?? true, let summary = duplicate.summary, !summary.isEmpty {
                    keeper.summary = summary
                }
                modelContext.delete(duplicate)
            }
        }

        let indexedKeys = Set(topicIndex.keys)
        for (key, existingTopics) in topicsByKey where !indexedKeys.contains(key) {
            for topic in existingTopics {
                modelContext.delete(topic)
            }
        }
    }

    private func pruneEntities(
        _ entities: [KnowledgeEntity],
        entityIndex: [String: Set<String>],
        using modelContext: ModelContext
    ) {
        for entity in entities {
            let indexedIDs = entityIndex[entity.normalizedName] ?? []
            if indexedIDs.isEmpty {
                modelContext.delete(entity)
            } else {
                entity.cardIDStrings = Array(indexedIDs).sorted()
            }
        }
    }

    private func pruneKnowledgeRelations(
        _ relations: [KnowledgeRelation],
        validCardIDs: Set<String>,
        using modelContext: ModelContext
    ) {
        for relation in relations where !validCardIDs.contains(relation.cardIDString) {
            modelContext.delete(relation)
        }
    }

    private func pruneCardRelations(
        _ relations: [CardRelation],
        validCardIDs: Set<String>,
        using modelContext: ModelContext
    ) {
        for relation in relations where !validCardIDs.contains(relation.sourceCardIDString) || !validCardIDs.contains(relation.targetCardIDString) {
            modelContext.delete(relation)
        }
    }

    private func topicSnapshot(from topics: [Topic], validCardIDs: Set<String>) -> [String: [String]] {
        var snapshot: [String: Set<String>] = [:]
        for topic in topics {
            let cardIDs = topic.cardIDStrings.filter { validCardIDs.contains($0) }
            snapshot[topic.normalizedName, default: []].formUnion(cardIDs)
        }
        return snapshot.mapValues { $0.sorted() }
    }

    private func clearHierarchy(using modelContext: ModelContext) throws {
        let nodes = try modelContext.fetch(FetchDescriptor<TopicHierarchyNode>())
        for node in nodes {
            modelContext.delete(node)
        }
    }
}

private struct TopicIndexEntry {
    var name: String
    var cardIDStrings: Set<String>
    private var displayNameCounts: [String: Int]

    init(name: String, cardIDStrings: Set<String>) {
        self.name = name
        self.cardIDStrings = cardIDStrings
        self.displayNameCounts = [:]
    }

    mutating func insertCardID(_ cardID: String) {
        cardIDStrings.insert(cardID)
    }

    mutating func recordDisplayName(_ displayName: String) {
        displayNameCounts[displayName, default: 0] += 1
    }

    func withCanonicalDisplayName() -> TopicIndexEntry {
        var copy = self
        copy.name = displayNameCounts
            .sorted { first, second in
                if first.value == second.value {
                    if first.key.count == second.key.count {
                        return first.key.localizedCaseInsensitiveCompare(second.key) == .orderedAscending
                    }
                    return first.key.count < second.key.count
                }
                return first.value > second.value
            }
            .first?.key ?? name
        return copy
    }
}
