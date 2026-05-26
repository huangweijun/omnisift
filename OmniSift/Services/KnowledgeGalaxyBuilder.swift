import Foundation

struct KnowledgeGalaxy {
    let systems: [KnowledgeStarSystem]
    let featuredConnections: [KnowledgeGalaxyConnection]
    let stats: KnowledgeGalaxyStats
    let breadcrumbs: [KnowledgeGalaxyBreadcrumb]
    let isHierarchyBacked: Bool
    let focusedNodeID: String?

    var isEmpty: Bool {
        systems.isEmpty
    }

    var canGoBack: Bool {
        breadcrumbs.count > 1
    }
}

struct KnowledgeGalaxyStats {
    let systemCount: Int
    let entityCount: Int
    let connectionCount: Int
    let cardCount: Int
}

struct KnowledgeGalaxyBreadcrumb: Identifiable {
    let id: String?
    let name: String
}

struct KnowledgeStarSystem: Identifiable {
    let id: String
    let name: String
    let cards: [InsightCard]
    let satellites: [KnowledgeSatellite]
    let size: GalaxyStarSize
    let colorSeed: Int
    let childCount: Int
    let hierarchyNodeID: String?

    var canDrillDown: Bool {
        childCount > 0 && hierarchyNodeID != nil
    }
}

struct KnowledgeSatellite: Identifiable {
    let id: String
    let name: String
    let kind: String
    let cards: [InsightCard]
}

struct KnowledgeGalaxyConnection: Identifiable {
    let id: String
    let sourceName: String
    let targetName: String
    let label: String
    let cardIDString: String
    let strength: Double
}

enum GalaxyStarSize {
    case small
    case medium
    case large
    case giant

    static func from(cardCount: Int) -> GalaxyStarSize {
        switch cardCount {
        case 0...2: .small
        case 3...5: .medium
        case 6...10: .large
        default: .giant
        }
    }
}

struct KnowledgeGalaxyBuilder {
    private let maxFlatSystems = 8
    private let maxHierarchySystems = 8
    private let maxSatellitesPerSystem = 3
    private let maxConnections = 6

    func build(
        cards: [InsightCard],
        topics: [Topic],
        hierarchyNodes: [TopicHierarchyNode] = [],
        focusedNodeID: String? = nil,
        entities: [KnowledgeEntity],
        relations: [KnowledgeRelation]
    ) -> KnowledgeGalaxy {
        let cardByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id.uuidString, $0) })
        if !hierarchyNodes.isEmpty {
            return buildHierarchyGalaxy(
                hierarchyNodes: hierarchyNodes,
                focusedNodeID: focusedNodeID,
                cards: cards,
                cardByID: cardByID,
                entities: entities,
                relations: relations
            )
        }

        let systems = buildFlatSystems(cards: cards, topics: topics, cardByID: cardByID)
        let visibleSystems = Array(systems.prefix(maxFlatSystems))
        let stats = KnowledgeGalaxyStats(
            systemCount: systems.count,
            entityCount: entities.filter { !$0.cardIDStrings.isEmpty }.count,
            connectionCount: relations.count,
            cardCount: cards.count
        )

        return KnowledgeGalaxy(
            systems: visibleSystems,
            featuredConnections: [],
            stats: stats,
            breadcrumbs: [KnowledgeGalaxyBreadcrumb(id: nil, name: "Galaxy")],
            isHierarchyBacked: false,
            focusedNodeID: nil
        )
    }

    private func buildHierarchyGalaxy(
        hierarchyNodes: [TopicHierarchyNode],
        focusedNodeID: String?,
        cards: [InsightCard],
        cardByID: [String: InsightCard],
        entities: [KnowledgeEntity],
        relations: [KnowledgeRelation]
    ) -> KnowledgeGalaxy {
        let nodesByID = Dictionary(uniqueKeysWithValues: hierarchyNodes.map { ($0.id.uuidString, $0) })
        let rootNodes = hierarchyNodes
            .filter { $0.level == 1 && $0.parentIDString == nil }
            .sorted(by: hierarchySort)
        let focusedNode = focusedNodeID.flatMap { nodesByID[$0] }
        let childNodes: [TopicHierarchyNode]
        if let focusedNode {
            childNodes = focusedNode.childIDStrings.compactMap { nodesByID[$0] }.sorted(by: hierarchySort)
        } else {
            childNodes = rootNodes
        }

        let initialVisibleNodes = Array(childNodes.prefix(maxHierarchySystems))
        let shouldReserveCategorySlot = focusedNode.map { node in
            !residualCardIDs(for: node, visibleNodes: initialVisibleNodes).isEmpty
        } ?? false
        let childLimit = shouldReserveCategorySlot ? maxHierarchySystems - 1 : maxHierarchySystems
        let visibleNodes = Array(childNodes.prefix(childLimit))
        let showSatellites = focusedNode != nil
        var systems = visibleNodes.map { node in
            makeSystem(from: node, nodesByID: nodesByID, cardByID: cardByID)
        }
        if let focusedNode,
           let categorySystem = makeCategoryCardsSystem(
               from: focusedNode,
               visibleNodes: visibleNodes,
               cardByID: cardByID
           ) {
            systems.append(categorySystem)
        }
        if showSatellites {
            systems = attachSatellites(to: systems, entities: entities, cardByID: cardByID)
        }

        let breadcrumbs = breadcrumbs(for: focusedNode, nodesByID: nodesByID)
        let stats = KnowledgeGalaxyStats(
            systemCount: rootNodes.count,
            entityCount: entities.filter { !$0.cardIDStrings.isEmpty }.count,
            connectionCount: relations.count,
            cardCount: cards.count
        )

        return KnowledgeGalaxy(
            systems: systems,
            featuredConnections: showSatellites ? buildConnections(from: relations) : [],
            stats: stats,
            breadcrumbs: breadcrumbs,
            isHierarchyBacked: true,
            focusedNodeID: focusedNode?.id.uuidString
        )
    }

    private func makeSystem(
        from node: TopicHierarchyNode,
        nodesByID: [String: TopicHierarchyNode],
        cardByID: [String: InsightCard]
    ) -> KnowledgeStarSystem {
        let cards = node.cardIDStrings.compactMap { cardByID[$0] }
        return KnowledgeStarSystem(
            id: node.id.uuidString,
            name: node.name,
            cards: cards,
            satellites: [],
            size: GalaxyStarSize.from(cardCount: cards.count),
            colorSeed: stableSeed(for: node.normalizedName),
            childCount: node.childIDStrings.filter { nodesByID[$0] != nil }.count,
            hierarchyNodeID: node.id.uuidString
        )
    }

    private func makeCategoryCardsSystem(
        from node: TopicHierarchyNode,
        visibleNodes: [TopicHierarchyNode],
        cardByID: [String: InsightCard]
    ) -> KnowledgeStarSystem? {
        let cardIDs = residualCardIDs(for: node, visibleNodes: visibleNodes)
        let cards = cardIDs.compactMap { cardByID[$0] }
        guard !cards.isEmpty else { return nil }

        return KnowledgeStarSystem(
            id: "\(node.id.uuidString)-category-cards",
            name: node.name,
            cards: cards,
            satellites: [],
            size: GalaxyStarSize.from(cardCount: cards.count),
            colorSeed: stableSeed(for: node.normalizedName) &+ 17,
            childCount: 0,
            hierarchyNodeID: nil
        )
    }

    private func residualCardIDs(for node: TopicHierarchyNode, visibleNodes: [TopicHierarchyNode]) -> [String] {
        var childCardIDs = Set<String>()
        for child in visibleNodes {
            childCardIDs.formUnion(child.cardIDStrings)
        }
        return node.cardIDStrings.filter { !childCardIDs.contains($0) }
    }

    private func breadcrumbs(
        for focusedNode: TopicHierarchyNode?,
        nodesByID: [String: TopicHierarchyNode]
    ) -> [KnowledgeGalaxyBreadcrumb] {
        var breadcrumbs = [KnowledgeGalaxyBreadcrumb(id: nil, name: "Galaxy")]
        guard let focusedNode else { return breadcrumbs }

        var lineage: [TopicHierarchyNode] = []
        var current: TopicHierarchyNode? = focusedNode
        while let node = current {
            lineage.append(node)
            current = node.parentIDString.flatMap { nodesByID[$0] }
        }
        breadcrumbs += lineage.reversed().map { node in
            KnowledgeGalaxyBreadcrumb(id: node.id.uuidString, name: node.name)
        }
        return breadcrumbs
    }

    private func buildFlatSystems(
        cards: [InsightCard],
        topics: [Topic],
        cardByID: [String: InsightCard]
    ) -> [KnowledgeStarSystem] {
        var summaries: [String: TopicGalaxySummary] = [:]

        for topic in topics {
            let topicCards = topic.cardIDStrings.compactMap { cardByID[$0] }
            guard !topicCards.isEmpty else { continue }
            summaries[topic.normalizedName] = TopicGalaxySummary(name: topic.name, cards: topicCards)
        }

        for card in cards {
            let labels = (card.topicNames.isEmpty ? card.tags : card.topicNames)
                .compactMap { ContentStructure.cleanKnowledgeLabel($0) }

            for label in labels {
                let key = label.normalizedKnowledgeKey
                guard !key.isEmpty else { continue }
                if summaries[key] == nil {
                    summaries[key] = TopicGalaxySummary(name: label, cards: [])
                }
                summaries[key]?.append(card)
            }
        }

        return summaries.values
            .sorted {
                if $0.cards.count == $1.cards.count {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.cards.count > $1.cards.count
            }
            .map { summary in
                KnowledgeStarSystem(
                    id: summary.id,
                    name: summary.name,
                    cards: summary.cards,
                    satellites: [],
                    size: GalaxyStarSize.from(cardCount: summary.cards.count),
                    colorSeed: stableSeed(for: summary.id),
                    childCount: 0,
                    hierarchyNodeID: nil
                )
            }
    }

    private func attachSatellites(
        to systems: [KnowledgeStarSystem],
        entities: [KnowledgeEntity],
        cardByID: [String: InsightCard]
    ) -> [KnowledgeStarSystem] {
        let entitiesBySystemID = Dictionary(grouping: entities.compactMap { entity -> (String, KnowledgeSatellite)? in
            let entityCardIDs = Set(entity.cardIDStrings)
            guard !entityCardIDs.isEmpty,
                  let bestSystem = systems.max(by: { first, second in
                      overlapCount(first.cards, entityCardIDs: entityCardIDs) < overlapCount(second.cards, entityCardIDs: entityCardIDs)
                  }),
                  overlapCount(bestSystem.cards, entityCardIDs: entityCardIDs) > 0 else {
                return nil
            }

            let satellite = KnowledgeSatellite(
                id: entity.normalizedName,
                name: entity.name,
                kind: entity.kind,
                cards: entity.cardIDStrings.compactMap { cardByID[$0] }
            )
            return (bestSystem.id, satellite)
        }, by: { $0.0 })

        return systems.map { system in
            let satellites = (entitiesBySystemID[system.id] ?? [])
                .map(\.1)
                .sorted {
                    if $0.cards.count == $1.cards.count {
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    return $0.cards.count > $1.cards.count
                }
                .prefix(maxSatellitesPerSystem)

            return KnowledgeStarSystem(
                id: system.id,
                name: system.name,
                cards: system.cards,
                satellites: Array(satellites),
                size: system.size,
                colorSeed: system.colorSeed,
                childCount: system.childCount,
                hierarchyNodeID: system.hierarchyNodeID
            )
        }
    }

    private func buildConnections(from relations: [KnowledgeRelation]) -> [KnowledgeGalaxyConnection] {
        Array(relations.prefix(maxConnections)).map { relation in
            KnowledgeGalaxyConnection(
                id: relation.id.uuidString,
                sourceName: relation.sourceEntityName,
                targetName: relation.targetEntityName,
                label: relation.predicate,
                cardIDString: relation.cardIDString,
                strength: relation.confidence
            )
        }
    }

    private func hierarchySort(_ first: TopicHierarchyNode, _ second: TopicHierarchyNode) -> Bool {
        if first.sortOrder == second.sortOrder {
            return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
        }
        return first.sortOrder < second.sortOrder
    }

    private func overlapCount(_ cards: [InsightCard], entityCardIDs: Set<String>) -> Int {
        cards.reduce(0) { count, card in
            entityCardIDs.contains(card.id.uuidString) ? count + 1 : count
        }
    }

    private func stableSeed(for key: String) -> Int {
        key.unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult &+ Int(scalar.value)
        }
    }
}

private struct TopicGalaxySummary: Identifiable {
    let id: String
    let name: String
    private(set) var cards: [InsightCard]

    init(name: String, cards: [InsightCard]) {
        self.id = name.normalizedKnowledgeKey
        self.name = name
        self.cards = cards
    }

    mutating func append(_ card: InsightCard) {
        guard !cards.contains(where: { $0.id == card.id }) else { return }
        cards.append(card)
    }
}
