import Foundation
import SwiftData

@MainActor
@Observable
final class TopicHierarchyOrganizationService {
    var isOrganizing = false
    var lastRunError: String?
    var lastOrganizedAt: Date?

    private let cloudService = CloudAIService()
    private var modelContext: ModelContext?
    private let maxSampleTitlesPerTopic = 3

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func organizeNow(topics: [Topic], cards: [InsightCard]) async {
        guard !isOrganizing else { return }
        guard let modelContext else { return }

        isOrganizing = true
        lastRunError = nil
        defer { isOrganizing = false }

        do {
            let context = makeOrganizationContext(topics: topics, cards: cards)
            guard !context.topicInputs.isEmpty else {
                try replaceHierarchy(with: [], using: modelContext)
                lastOrganizedAt = Date()
                return
            }

            let aiResult = try await cloudService.organizeTopics(context.topicInputs)
            let nodes = makeHierarchyNodes(
                from: aiResult.nodes,
                unassignedTopics: aiResult.unassignedTopics,
                context: context,
                source: .ai
            )
            try replaceHierarchy(with: nodes, using: modelContext)
            lastOrganizedAt = Date()
        } catch {
            do {
                let context = makeOrganizationContext(topics: topics, cards: cards)
                let fallbackNodes = makeDeterministicHierarchy(context: context)
                try replaceHierarchy(with: fallbackNodes, using: modelContext)
                lastOrganizedAt = Date()
                lastRunError = error.localizedDescription
            } catch {
                lastRunError = error.localizedDescription
            }
        }
    }

    private func makeOrganizationContext(topics: [Topic], cards: [InsightCard]) -> TopicOrganizationContext {
        let cardByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id.uuidString, $0) })
        var metadataByKey: [String: TopicMetadata] = [:]

        for topic in topics {
            let topicCards = cardsForTopic(topic, cards: cards, cardByID: cardByID)
            guard !topicCards.isEmpty else { continue }
            metadataByKey[topic.normalizedName] = TopicMetadata(
                name: topic.name,
                normalizedName: topic.normalizedName,
                summary: topic.summary,
                cards: topicCards
            )
        }

        for card in cards {
            let labels = (card.topicNames.isEmpty ? card.tags : card.topicNames)
                .compactMap { ContentStructure.cleanKnowledgeLabel($0) }
            for label in labels {
                let key = label.normalizedKnowledgeKey
                guard !key.isEmpty else { continue }
                if metadataByKey[key] == nil {
                    metadataByKey[key] = TopicMetadata(name: label, normalizedName: key, summary: nil, cards: [])
                }
                metadataByKey[key]?.append(card)
            }
        }

        let metadata = metadataByKey.values.sorted {
            if $0.cards.count == $1.cards.count {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.cards.count > $1.cards.count
        }

        let inputs = metadata.map { topic in
            CloudAIService.TopicOrganizationTopic(
                name: topic.name,
                normalizedName: topic.normalizedName,
                summary: topic.summary,
                cardCount: topic.cards.count,
                sampleTitles: topic.cards.prefix(maxSampleTitlesPerTopic).map { card in
                    card.title ?? card.sourceTitle ?? String(card.rawText.prefix(60))
                }
            )
        }

        return TopicOrganizationContext(
            topics: metadata,
            topicInputs: inputs,
            metadataByKey: metadataByKey
        )
    }

    private func cardsForTopic(
        _ topic: Topic,
        cards: [InsightCard],
        cardByID: [String: InsightCard]
    ) -> [InsightCard] {
        var result = topic.cardIDStrings.compactMap { cardByID[$0] }
        let existingIDs = Set(result.map(\.id))
        let topicKey = topic.normalizedName
        result += cards.filter { card in
            guard !existingIDs.contains(card.id) else { return false }
            return card.topicNames.contains { $0.normalizedKnowledgeKey == topicKey } ||
            (card.topicNames.isEmpty && card.tags.contains { $0.normalizedKnowledgeKey == topicKey })
        }
        return uniqueCards(result)
    }

    private func makeHierarchyNodes(
        from aiNodes: [CloudAIService.OrganizedTopicNode],
        unassignedTopics: [String],
        context: TopicOrganizationContext,
        source: TopicHierarchySource
    ) -> [TopicHierarchyNode] {
        var usedTopicKeys = Set<String>()
        var nodes: [TopicHierarchyDraft] = []

        for (index, node) in aiNodes.prefix(8).enumerated() {
            if let draft = makeDraft(
                from: node,
                level: 1,
                parentIDString: nil,
                sortOrder: index,
                context: context,
                usedTopicKeys: &usedTopicKeys,
                source: source
            ) {
                nodes.append(draft)
            }
        }

        let explicitUnassigned = unassignedTopics.map(\.normalizedKnowledgeKey)
        let missingKeys = context.topics.map(\.normalizedName).filter { !usedTopicKeys.contains($0) }
        let fallbackKeys = uniqueKeys(explicitUnassigned + missingKeys).filter {
            context.metadataByKey[$0] != nil && !usedTopicKeys.contains($0)
        }
        if !fallbackKeys.isEmpty {
            nodes.append(makeFallbackDraft(
                topicKeys: fallbackKeys,
                sortOrder: nodes.count,
                context: context,
                source: source
            ))
        }

        return materializeDrafts(nodes)
    }

    private func makeDraft(
        from node: CloudAIService.OrganizedTopicNode,
        level: Int,
        parentIDString: String?,
        sortOrder: Int,
        context: TopicOrganizationContext,
        usedTopicKeys: inout Set<String>,
        source: TopicHierarchySource
    ) -> TopicHierarchyDraft? {
        guard level <= 3,
              let name = ContentStructure.cleanKnowledgeLabel(node.name) else {
            return nil
        }

        let nodeID = UUID().uuidString
        let ownTopicKeys = uniqueKeys((node.topics ?? []).map(\.normalizedKnowledgeKey))
            .filter { context.metadataByKey[$0] != nil && !usedTopicKeys.contains($0) }
        usedTopicKeys.formUnion(ownTopicKeys)

        let childDrafts = (node.children ?? [])
            .prefix(8)
            .enumerated()
            .compactMap { childIndex, child -> TopicHierarchyDraft? in
                makeDraft(
                    from: child,
                    level: level + 1,
                    parentIDString: nodeID,
                    sortOrder: childIndex,
                    context: context,
                    usedTopicKeys: &usedTopicKeys,
                    source: source
                )
            }

        let descendantTopicKeys = childDrafts.flatMap(\.allTopicKeys)
        guard !ownTopicKeys.isEmpty || !descendantTopicKeys.isEmpty else { return nil }
        let cardIDs = cardIDs(for: ownTopicKeys + descendantTopicKeys, context: context)

        return TopicHierarchyDraft(
            idString: nodeID,
            name: name,
            summary: ContentStructure.cleanDisplayText(node.summary),
            level: level,
            parentIDString: parentIDString,
            topicNormalizedNames: ownTopicKeys,
            cardIDStrings: cardIDs,
            sortOrder: sortOrder,
            source: source,
            confidence: min(max(node.confidence ?? 0.7, 0), 1),
            children: childDrafts
        )
    }

    private func makeFallbackDraft(
        topicKeys: [String],
        sortOrder: Int,
        context: TopicOrganizationContext,
        source: TopicHierarchySource
    ) -> TopicHierarchyDraft {
        let language = OutputLanguagePreference.stored.resolvedLanguage
        let name = language == .simplifiedChinese ? "其他" : "Other"
        return TopicHierarchyDraft(
            idString: UUID().uuidString,
            name: name,
            summary: nil,
            level: 1,
            parentIDString: nil,
            topicNormalizedNames: topicKeys,
            cardIDStrings: cardIDs(for: topicKeys, context: context),
            sortOrder: sortOrder,
            source: source,
            confidence: 0.45,
            children: []
        )
    }

    private func makeDeterministicHierarchy(context: TopicOrganizationContext) -> [TopicHierarchyNode] {
        let language = OutputLanguagePreference.stored.resolvedLanguage
        let groups = deterministicGroups(for: language)
        var buckets = Dictionary(uniqueKeysWithValues: groups.map { ($0.name, [String]()) })

        for topic in context.topics {
            let key = topic.normalizedName
            let groupName = groups.first { group in
                group.keywords.contains { key.contains($0) || topic.name.normalizedKnowledgeKey.contains($0) }
            }?.name ?? (language == .simplifiedChinese ? "其他" : "Other")
            buckets[groupName, default: []].append(key)
        }

        let drafts = groups.enumerated().compactMap { index, group -> TopicHierarchyDraft? in
            let topicKeys = buckets[group.name, default: []]
            guard !topicKeys.isEmpty else { return nil }
            let sortedKeys = topicKeys.sorted { first, second in
                let firstCount = context.metadataByKey[first]?.cards.count ?? 0
                let secondCount = context.metadataByKey[second]?.cards.count ?? 0
                if firstCount == secondCount { return first < second }
                return firstCount > secondCount
            }
            let visibleKeys = Array(sortedKeys.prefix(8))
            let childDrafts = visibleKeys.enumerated().map { childIndex, topicKey in
                let metadata = context.metadataByKey[topicKey]
                return TopicHierarchyDraft(
                    idString: UUID().uuidString,
                    name: metadata?.name ?? topicKey,
                    summary: metadata?.summary,
                    level: 2,
                    parentIDString: nil,
                    topicNormalizedNames: [topicKey],
                    cardIDStrings: cardIDs(for: [topicKey], context: context),
                    sortOrder: childIndex,
                    source: .deterministic,
                    confidence: 0.6,
                    children: []
                )
            }
            return TopicHierarchyDraft(
                idString: UUID().uuidString,
                name: group.name,
                summary: nil,
                level: 1,
                parentIDString: nil,
                topicNormalizedNames: sortedKeys,
                cardIDStrings: cardIDs(for: sortedKeys, context: context),
                sortOrder: index,
                source: .deterministic,
                confidence: 0.55,
                children: childDrafts
            )
        }

        return materializeDrafts(drafts)
    }

    private func deterministicGroups(for language: OutputLanguage) -> [DeterministicTopicGroup] {
        switch language {
        case .simplifiedChinese:
            return [
                DeterministicTopicGroup(name: "技术", keywords: ["swift", "ios", "ai", "代码", "开发", "模型", "工具", "数据库", "云", "技术", "编程", "claude", "gemini"]),
                DeterministicTopicGroup(name: "工作与商业", keywords: ["项目", "产品", "创业", "商业", "会议", "职业", "公司", "管理"]),
                DeterministicTopicGroup(name: "学习", keywords: ["书", "课程", "学习", "研究", "笔记", "知识"]),
                DeterministicTopicGroup(name: "生活", keywords: ["生活", "健康", "习惯", "家庭", "旅行", "日常"]),
                DeterministicTopicGroup(name: "娱乐", keywords: ["游戏", "电影", "音乐", "动漫", "节目", "娱乐"]),
                DeterministicTopicGroup(name: "财经", keywords: ["股票", "投资", "财经", "金融", "钱", "crypto", "预算"]),
                DeterministicTopicGroup(name: "其他", keywords: [])
            ]
        case .english:
            return [
                DeterministicTopicGroup(name: "Technology", keywords: ["swift", "ios", "ai", "code", "api", "database", "cloud", "model", "developer", "software", "claude", "gemini"]),
                DeterministicTopicGroup(name: "Work & Business", keywords: ["project", "product", "startup", "business", "meeting", "career", "company", "management"]),
                DeterministicTopicGroup(name: "Learning", keywords: ["book", "course", "study", "research", "note", "learning"]),
                DeterministicTopicGroup(name: "Life", keywords: ["health", "habit", "family", "home", "travel", "daily"]),
                DeterministicTopicGroup(name: "Entertainment", keywords: ["game", "movie", "music", "anime", "show", "entertainment"]),
                DeterministicTopicGroup(name: "Finance", keywords: ["stock", "investment", "finance", "money", "crypto", "budget"]),
                DeterministicTopicGroup(name: "Other", keywords: [])
            ]
        }
    }

    private func materializeDrafts(_ drafts: [TopicHierarchyDraft]) -> [TopicHierarchyNode] {
        drafts.flatMap { draft in
            let node = TopicHierarchyNode(
                id: UUID(uuidString: draft.idString) ?? UUID(),
                name: draft.name,
                summary: draft.summary,
                level: draft.level,
                parentIDString: draft.parentIDString,
                childIDStrings: draft.children.map(\.idString),
                topicNormalizedNames: draft.topicNormalizedNames,
                cardIDStrings: draft.cardIDStrings,
                sortOrder: draft.sortOrder,
                source: draft.source,
                confidence: draft.confidence
            )
            let children = draft.children.map { child in
                var updated = child
                updated.parentIDString = draft.idString
                return updated
            }
            return [node] + materializeDrafts(children)
        }
    }

    private func cardIDs(for topicKeys: [String], context: TopicOrganizationContext) -> [String] {
        var seen = Set<String>()
        return topicKeys.flatMap { key in
            context.metadataByKey[key]?.cards ?? []
        }
        .compactMap { card in
            let idString = card.id.uuidString
            guard !seen.contains(idString) else { return nil }
            seen.insert(idString)
            return idString
        }
        .sorted()
    }

    private func replaceHierarchy(with nodes: [TopicHierarchyNode], using modelContext: ModelContext) throws {
        let existing = try modelContext.fetch(FetchDescriptor<TopicHierarchyNode>())
        for node in existing {
            modelContext.delete(node)
        }
        for node in nodes {
            modelContext.insert(node)
        }
        try modelContext.save()
    }

    private func uniqueCards(_ cards: [InsightCard]) -> [InsightCard] {
        var seen = Set<UUID>()
        return cards.filter { card in
            guard !seen.contains(card.id) else { return false }
            seen.insert(card.id)
            return true
        }
    }

    private func uniqueKeys(_ keys: [String]) -> [String] {
        var seen = Set<String>()
        return keys.compactMap { key in
            let cleaned = key.normalizedKnowledgeKey
            guard !cleaned.isEmpty, !seen.contains(cleaned) else { return nil }
            seen.insert(cleaned)
            return cleaned
        }
    }
}

private struct TopicOrganizationContext {
    let topics: [TopicMetadata]
    let topicInputs: [CloudAIService.TopicOrganizationTopic]
    let metadataByKey: [String: TopicMetadata]
}

private struct TopicMetadata {
    let name: String
    let normalizedName: String
    let summary: String?
    private(set) var cards: [InsightCard]

    mutating func append(_ card: InsightCard) {
        guard !cards.contains(where: { $0.id == card.id }) else { return }
        cards.append(card)
    }
}

private struct TopicHierarchyDraft {
    let idString: String
    let name: String
    let summary: String?
    let level: Int
    var parentIDString: String?
    let topicNormalizedNames: [String]
    let cardIDStrings: [String]
    let sortOrder: Int
    let source: TopicHierarchySource
    let confidence: Double
    let children: [TopicHierarchyDraft]

    var allTopicKeys: [String] {
        topicNormalizedNames + children.flatMap(\.allTopicKeys)
    }
}

private struct DeterministicTopicGroup {
    let name: String
    let keywords: [String]
}
