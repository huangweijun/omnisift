import Foundation
import SwiftData

@MainActor
struct TopicOrganizationService {
    enum TopicOrganizationError: LocalizedError {
        case emptyTopicName
        case duplicateTopicName
        case sameTopicMerge

        var errorDescription: String? {
            switch self {
            case .emptyTopicName:
                "Topic name cannot be empty"
            case .duplicateTopicName:
                "A topic with this name already exists"
            case .sameTopicMerge:
                "Choose a different topic to merge into"
            }
        }
    }

    func renameTopic(
        _ topic: Topic,
        to newName: String,
        cards: [InsightCard],
        using modelContext: ModelContext
    ) throws {
        let cleanedName = try validatedTopicName(newName)
        let oldKey = topic.normalizedName
        let newKey = cleanedName.normalizedKnowledgeKey
        guard oldKey == newKey || !topicExists(normalizedName: newKey, excluding: topic, using: modelContext) else {
            throw TopicOrganizationError.duplicateTopicName
        }
        let affectedCards = cardsForTopic(topic, from: cards)

        topic.name = cleanedName
        topic.normalizedName = newKey
        topic.cardIDStrings = Array(Set(affectedCards.map { $0.id.uuidString })).sorted()
        topic.lastUpdatedAt = Date()

        for card in affectedCards {
            card.topicNames = replacingTopicLabel(in: card.topicNames, oldKey: oldKey, newName: cleanedName)
        }

        try clearHierarchy(using: modelContext)
        try modelContext.save()
    }

    func mergeTopic(
        _ source: Topic,
        into target: Topic,
        cards: [InsightCard],
        using modelContext: ModelContext
    ) throws {
        guard source.id != target.id else { throw TopicOrganizationError.sameTopicMerge }

        let sourceKey = source.normalizedName
        let targetName = try validatedTopicName(target.name)
        let targetCards = cardsForTopic(target, from: cards)
        let sourceCards = cardsForTopic(source, from: cards)
        let mergedCards = uniqueCards(targetCards + sourceCards)

        target.cardIDStrings = Array(Set(mergedCards.map { $0.id.uuidString })).sorted()
        target.lastUpdatedAt = Date()

        for card in sourceCards {
            card.topicNames = replacingTopicLabel(in: card.topicNames, oldKey: sourceKey, newName: targetName)
        }

        modelContext.delete(source)
        try clearHierarchy(using: modelContext)
        try modelContext.save()
    }

    func remove(
        _ card: InsightCard,
        from topic: Topic,
        using modelContext: ModelContext
    ) throws {
        let topicKey = topic.normalizedName
        let hadExplicitTopic = !card.topicNames.isEmpty
        card.topicNames = card.topicNames.filter { $0.normalizedKnowledgeKey != topicKey }
        if !hadExplicitTopic {
            card.tags = card.tags.filter { $0.normalizedKnowledgeKey != topicKey }
        }
        topic.cardIDStrings = topic.cardIDStrings.filter { $0 != card.id.uuidString }
        topic.lastUpdatedAt = Date()
        try clearHierarchy(using: modelContext)
        try modelContext.save()
    }

    private func clearHierarchy(using modelContext: ModelContext) throws {
        let nodes = try modelContext.fetch(FetchDescriptor<TopicHierarchyNode>())
        for node in nodes {
            modelContext.delete(node)
        }
    }

    private func cardsForTopic(_ topic: Topic, from cards: [InsightCard]) -> [InsightCard] {
        let topicKey = topic.normalizedName
        let cardIDs = Set(topic.cardIDStrings)
        return cards.filter { card in
            cardIDs.contains(card.id.uuidString) ||
            card.topicNames.contains { $0.normalizedKnowledgeKey == topicKey } ||
            (card.topicNames.isEmpty && card.tags.contains { $0.normalizedKnowledgeKey == topicKey })
        }
    }

    private func topicExists(normalizedName: String, excluding topic: Topic, using modelContext: ModelContext) -> Bool {
        var descriptor = FetchDescriptor<Topic>(
            predicate: #Predicate { candidate in
                candidate.normalizedName == normalizedName
            }
        )
        descriptor.fetchLimit = 2
        let matchingTopics = (try? modelContext.fetch(descriptor)) ?? []
        return matchingTopics.contains { $0.id != topic.id }
    }

    private func replacingTopicLabel(in labels: [String], oldKey: String, newName: String) -> [String] {
        var didReplace = false
        let replaced = labels.map { label in
            if label.normalizedKnowledgeKey == oldKey {
                didReplace = true
                return newName
            }
            return label
        }
        return cleanedLabels(didReplace ? replaced : replaced + [newName])
    }

    private func cleanedLabels(_ labels: [String]) -> [String] {
        var seen = Set<String>()
        return labels.compactMap { label in
            let cleaned = ContentStructure.cleanKnowledgeLabel(label)
            guard let cleaned else { return nil }
            let key = cleaned.normalizedKnowledgeKey
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return cleaned
        }
    }

    private func uniqueCards(_ cards: [InsightCard]) -> [InsightCard] {
        var seen = Set<UUID>()
        return cards.filter { card in
            guard !seen.contains(card.id) else { return false }
            seen.insert(card.id)
            return true
        }
    }

    private func validatedTopicName(_ name: String) throws -> String {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !cleaned.isEmpty else { throw TopicOrganizationError.emptyTopicName }
        return cleaned
    }
}
