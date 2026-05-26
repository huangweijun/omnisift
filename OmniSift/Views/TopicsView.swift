import SwiftUI
import SwiftData

struct TopicsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(TopicHierarchyOrganizationService.self) private var hierarchyOrganizationService
    @Query(sort: \Topic.lastUpdatedAt, order: .reverse) private var topics: [Topic]
    @Query(sort: \TopicHierarchyNode.sortOrder) private var hierarchyNodes: [TopicHierarchyNode]
    @Query(sort: \InsightCard.createdAt, order: .reverse) private var cards: [InsightCard]
    @Query(sort: \KnowledgeEntity.lastSeenAt, order: .reverse) private var entities: [KnowledgeEntity]
    @Query(sort: \KnowledgeRelation.createdAt, order: .reverse) private var relations: [KnowledgeRelation]
    @State private var renameTopic: Topic?
    @State private var mergeSourceTopic: Topic?
    @State private var organizationErrorMessage: String?
    @State private var showPaywall = false
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private let organizationService = TopicOrganizationService()

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    private var organizationErrorIsPresented: Binding<Bool> {
        Binding(
            get: { organizationErrorMessage != nil },
            set: { if !$0 { organizationErrorMessage = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if topics.isEmpty {
                    ContentUnavailableView(
                        strings.noTopicsYet,
                        systemImage: "square.stack.3d.up",
                        description: Text(strings.noTopicsDescription)
                    )
                } else {
                    List {
                        organizationHeader
                        overviewSection
                        knowledgeSignalsSection
                        hierarchyPreviewSection

                        ForEach(topics) { topic in
                            NavigationLink {
                                TopicDetailView(topic: topic) { card in
                                    remove(card, from: topic)
                                }
                            } label: {
                                TopicRow(topic: topic, cardCount: cardsForTopic(topic).count, strings: strings)
                            }
                            .contextMenu {
                                Button(strings.renameTopic, systemImage: "pencil") {
                                    renameTopic = topic
                                }
                                Button(strings.mergeTopic, systemImage: "arrow.triangle.merge") {
                                    mergeSourceTopic = topic
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(strings.topicOrganizationTitle)
            .navigationDestination(for: InsightCard.self) { card in
                CardDetailView(card: card)
            }
            .sheet(item: $renameTopic) { topic in
                TopicRenameSheet(topic: topic, strings: strings) { newName in
                    rename(topic, to: newName)
                }
            }
            .sheet(item: $mergeSourceTopic) { sourceTopic in
                TopicMergeSheet(sourceTopic: sourceTopic, topics: topics, strings: strings) { targetTopic in
                    merge(sourceTopic, into: targetTopic)
                }
            }
            .alert(strings.topicOrganizationFailed, isPresented: organizationErrorIsPresented) {
                Button(strings.ok, role: .cancel) {
                    organizationErrorMessage = nil
                }
            } message: {
                Text(organizationErrorMessage ?? "")
            }
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
            }
        }
    }

    private var overviewSection: some View {
        Section(strings.knowledgeOverview) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatTile(title: strings.savedInsightsLabel, value: "\(cards.count)", color: .blue)
                StatTile(title: strings.processedInsightsLabel, value: "\(processedCards.count)", color: .green)
                StatTile(title: strings.topics, value: "\(topicSummaries.count)", color: .orange)
                StatTile(title: strings.entities, value: "\(entities.count)", color: .purple)
            }
            .padding(.vertical, 4)
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }
    }

    @ViewBuilder
    private var knowledgeSignalsSection: some View {
        if !topicSummaries.isEmpty || !topEntitySummaries.isEmpty || !relations.isEmpty {
            Section(strings.knowledgeSignals) {
                KnowledgeSignalBoard(
                    topicSummaries: Array(topicSummaries.prefix(6)),
                    entities: Array(topEntitySummaries.prefix(6)),
                    relations: Array(relations.prefix(4)),
                    strings: strings,
                    showsOpenTopicsTile: false
                )
                .padding(.vertical, 4)
            }
        }
    }

    private var hierarchyPreviewSection: some View {
        Section(strings.currentStarMapStructure) {
            let rootNodes = hierarchyNodes
                .filter { $0.level == 1 && $0.parentIDString == nil }
                .sorted { first, second in
                    if first.sortOrder == second.sortOrder {
                        return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
                    }
                    return first.sortOrder < second.sortOrder
                }

            if rootNodes.isEmpty {
                Text(strings.noStarMapStructure)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rootNodes) { node in
                    TopicHierarchyPreviewRow(node: node, strings: strings)
                }
            }
        }
    }

    private var hasStarMapOrganizationAccess: Bool {
        subscriptionService.isPremium || DailyUsageTracker.unlimitedMode
    }

    private var processedCards: [InsightCard] {
        cards.filter { $0.status == .processed }
    }

    private var topicSummaries: [TopicSummary] {
        let cardByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id.uuidString, $0) })
        var summaries: [String: TopicSummary] = [:]

        for topic in topics {
            let topicCards = topic.cardIDStrings.compactMap { cardByID[$0] }
            guard !topicCards.isEmpty else { continue }
            summaries[topic.normalizedName] = TopicSummary(name: topic.name, cards: topicCards)
        }

        for card in cards {
            let labels = (card.topicNames.isEmpty ? card.tags : card.topicNames)
                .compactMap { ContentStructure.cleanKnowledgeLabel($0) }
            for label in labels {
                let key = label.normalizedKnowledgeKey
                guard !key.isEmpty else { continue }
                if summaries[key] == nil {
                    summaries[key] = TopicSummary(name: label, cards: [])
                }
                summaries[key]?.append(card)
            }
        }

        return summaries.values.sorted {
            if $0.cards.count == $1.cards.count {
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.cards.count > $1.cards.count
        }
    }

    private var topEntitySummaries: [EntitySummary] {
        let cardByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id.uuidString, $0) })
        return entities
            .map { entity in
                EntitySummary(
                    name: entity.name,
                    kind: entity.kind,
                    cards: entity.cardIDStrings.compactMap { cardByID[$0] }
                )
            }
            .filter { !$0.cards.isEmpty }
            .sorted {
                if $0.cards.count == $1.cards.count {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.cards.count > $1.cards.count
            }
    }

    private var organizationHeader: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text(strings.topicOrganizationDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    organizeStarMap()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: hierarchyOrganizationService.isOrganizing ? "arrow.triangle.2.circlepath" : "wand.and.stars")
                            .frame(width: 22)

                        Spacer(minLength: 0)

                        Text(hierarchyOrganizationService.isOrganizing ? strings.organizingStarMap : strings.organizeStarMap)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .multilineTextAlignment(.center)

                        Spacer(minLength: 0)

                        Color.clear
                            .frame(width: 22, height: 1)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(hierarchyOrganizationService.isOrganizing || topics.isEmpty)

                if !hasStarMapOrganizationAccess {
                    Text(strings.aiStarMapProFeature)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let hierarchyError = hierarchyOrganizationService.lastRunError {
                    Text(hierarchyError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func organizeStarMap() {
        guard hasStarMapOrganizationAccess else {
            showPaywall = true
            return
        }
        Task { await hierarchyOrganizationService.organizeNow(topics: topics, cards: cards) }
    }

    private func cardsForTopic(_ topic: Topic) -> [InsightCard] {
        let topicKey = topic.normalizedName
        let cardIDs = Set(topic.cardIDStrings)
        return cards.filter { card in
            cardIDs.contains(card.id.uuidString) ||
            card.topicNames.contains { $0.normalizedKnowledgeKey == topicKey } ||
            (card.topicNames.isEmpty && card.tags.contains { $0.normalizedKnowledgeKey == topicKey })
        }
    }

    private func rename(_ topic: Topic, to newName: String) {
        do {
            try organizationService.renameTopic(topic, to: newName, cards: cards, using: modelContext)
        } catch {
            organizationErrorMessage = error.localizedDescription
        }
    }

    private func merge(_ sourceTopic: Topic, into targetTopic: Topic) {
        do {
            try organizationService.mergeTopic(sourceTopic, into: targetTopic, cards: cards, using: modelContext)
        } catch {
            organizationErrorMessage = error.localizedDescription
        }
    }

    private func remove(_ card: InsightCard, from topic: Topic) {
        do {
            try organizationService.remove(card, from: topic, using: modelContext)
        } catch {
            organizationErrorMessage = error.localizedDescription
        }
    }
}

private struct TopicHierarchyPreviewRow: View {
    let node: TopicHierarchyNode
    let strings: AppStrings

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(strings.savedInsights(count: node.cardIDStrings.count)) · \(strings.subtopicCount(node.childIDStrings.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

private struct TopicRow: View {
    let topic: Topic
    let cardCount: Int
    let strings: AppStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(topic.name)
                    .font(.headline)
                Spacer()
                Text("\(cardCount)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }

            if let summary = topic.summary, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Text(strings.updated(topic.lastUpdatedAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct TopicDetailView: View {
    let topic: Topic
    let onRemoveCard: (InsightCard) -> Void
    @Query(sort: \InsightCard.createdAt, order: .reverse) private var allCards: [InsightCard]
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    private var cards: [InsightCard] {
        let topicKey = topic.normalizedName
        let cardIDs = Set(topic.cardIDStrings)
        return allCards.filter { card in
            cardIDs.contains(card.id.uuidString) ||
            card.topicNames.contains { $0.normalizedKnowledgeKey == topicKey } ||
            (card.topicNames.isEmpty && card.tags.contains { $0.normalizedKnowledgeKey == topicKey })
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(topic.name)
                        .font(.title2.weight(.bold))
                    Text(strings.savedInsights(count: cards.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(cards) { card in
                    NavigationLink {
                        CardDetailView(card: card)
                    } label: {
                        CardRow(card: card)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(strings.removeFromTopic, systemImage: "minus.circle", role: .destructive) {
                            onRemoveCard(card)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TopicRenameSheet: View {
    let topic: Topic
    let strings: AppStrings
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(topic: Topic, strings: AppStrings, onSave: @escaping (String) -> Void) {
        self.topic = topic
        self.strings = strings
        self.onSave = onSave
        _name = State(initialValue: topic.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(strings.topicRenamePlaceholder, text: $name)
            }
            .navigationTitle(strings.renameTopic)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings.ok) {
                        onSave(name)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TopicMergeSheet: View {
    let sourceTopic: Topic
    let topics: [Topic]
    let strings: AppStrings
    let onMerge: (Topic) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(strings.topicMergeConfirmation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(topics.filter { $0.id != sourceTopic.id }) { topic in
                    Button {
                        onMerge(topic)
                        dismiss()
                    } label: {
                        HStack {
                            Text(topic.name)
                            Spacer()
                            Text("\(topic.cardIDStrings.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(strings.mergeInto)
        }
    }
}

#Preview {
    TopicsView()
        .modelContainer(for: [InsightCard.self, Topic.self, TopicHierarchyNode.self, CardRelation.self, KnowledgeEntity.self, KnowledgeRelation.self], inMemory: true)
}
