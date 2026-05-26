import SwiftUI
import SwiftData

struct KnowledgeMapView: View {
    @Environment(KnowledgeCompassService.self) private var compassService
    @Query(sort: \InsightCard.createdAt, order: .reverse) private var cards: [InsightCard]
    @Query(sort: \Topic.lastUpdatedAt, order: .reverse) private var topics: [Topic]
    @Query(sort: \TopicHierarchyNode.sortOrder) private var hierarchyNodes: [TopicHierarchyNode]
    @Query(sort: \KnowledgeEntity.lastSeenAt, order: .reverse) private var entities: [KnowledgeEntity]
    @Query(sort: \KnowledgeRelation.createdAt, order: .reverse) private var relations: [KnowledgeRelation]
    @State private var focusedHierarchyNodeID: String?
    @State private var selectedGalaxySystem: KnowledgeStarSystem?
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    private var galaxy: KnowledgeGalaxy {
        KnowledgeGalaxyBuilder().build(
            cards: cards,
            topics: topics,
            hierarchyNodes: hierarchyNodes,
            focusedNodeID: focusedHierarchyNodeID,
            entities: entities,
            relations: relations
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    header
                    topicOrganizationEntry

                    if cards.isEmpty {
                        EmptyStateView()
                            .padding(.top, 24)
                    } else {
                        KnowledgeGalaxyView(
                            galaxy: galaxy,
                            strings: strings,
                            onSelectSystem: handleGalaxySystemSelection,
                            onSelectBreadcrumb: { focusedHierarchyNodeID = $0 },
                            onBack: moveGalaxyFocusBack
                        )
                        compassSection
                        needsAttentionSection
                    }
                }
                .padding(20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: InsightCard.self) { card in
                CardDetailView(card: card)
            }
            .sheet(item: $selectedGalaxySystem) { system in
                NavigationStack {
                    KnowledgeCardCollectionView(
                        title: system.name,
                        subtitle: strings.savedInsights(count: system.cards.count),
                        cards: system.cards
                    )
                }
            }
            .task(id: processedCards.count) {
                await compassService.generateIfNeeded(cards: cards)
            }
        }
    }

    private func handleGalaxySystemSelection(_ system: KnowledgeStarSystem) {
        if let nodeID = system.hierarchyNodeID, system.canDrillDown {
            focusedHierarchyNodeID = nodeID
        } else {
            selectedGalaxySystem = system
        }
    }

    private func moveGalaxyFocusBack() {
        guard let focusedHierarchyNodeID,
              let currentNode = hierarchyNodes.first(where: { $0.id.uuidString == focusedHierarchyNodeID }) else {
            self.focusedHierarchyNodeID = nil
            return
        }
        self.focusedHierarchyNodeID = currentNode.parentIDString
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings.knowledgeMapTitle)
                .font(.largeTitle.weight(.bold))
            Text(strings.knowledgeMapDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var topicOrganizationEntry: some View {
        NavigationLink {
            TopicsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(strings.organizeTopics)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(strings.topicOrganizationEntryDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.orange.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var compassSection: some View {
        KnowledgeCompassCard(
            report: compassService.report,
            generatedAt: compassService.generatedAt,
            isGenerating: compassService.isGenerating,
            errorMessage: compassService.lastRunError,
            processedCount: processedCards.count,
            strings: strings,
            isImmersive: true
        ) {
            Task { await compassService.generateNow(cards: cards) }
        }
    }

    @ViewBuilder
    private var needsAttentionSection: some View {
        let attentionCards = Array(cardsNeedingAttention.prefix(6))
        if !attentionCards.isEmpty {
            SectionCard(title: strings.needsAttention, systemImage: "tray.full.fill") {
                VStack(spacing: 12) {
                    ForEach(attentionCards) { card in
                        NavigationLink(value: card) {
                            CardRow(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var processedCards: [InsightCard] {
        cards.filter { $0.status == .processed }
    }

    private var cardsNeedingAttention: [InsightCard] {
        cards.filter { card in
            card.status != .processed || card.extractionStatus == .failed || card.extractionStatus == .urlOnly
        }
    }

}

struct TopicSummary: Identifiable {
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

struct EntitySummary: Identifiable {
    let id: String
    let name: String
    let kind: String
    let cards: [InsightCard]

    init(name: String, kind: String, cards: [InsightCard]) {
        self.id = name.normalizedKnowledgeKey
        self.name = name
        self.kind = kind
        self.cards = cards
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.primary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct KnowledgeSignalBoard: View {
    let topicSummaries: [TopicSummary]
    let entities: [EntitySummary]
    let relations: [KnowledgeRelation]
    let strings: AppStrings
    var showsOpenTopicsTile = true

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(strings.knowledgeSignalsDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
                if let strongestTopic = topicSummaries.first {
                    NavigationLink {
                        KnowledgeCardCollectionView(
                            title: strongestTopic.name,
                            subtitle: strings.savedInsights(count: strongestTopic.cards.count),
                            cards: strongestTopic.cards
                        )
                    } label: {
                        SignalTile(
                            title: strings.strongestSignal,
                            value: strongestTopic.name,
                            caption: strings.savedInsights(count: strongestTopic.cards.count),
                            systemImage: "circle.hexagongrid.fill",
                            color: .orange
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let topEntity = entities.first {
                    NavigationLink {
                        KnowledgeCardCollectionView(
                            title: topEntity.name,
                            subtitle: strings.savedInsights(count: topEntity.cards.count),
                            cards: topEntity.cards
                        )
                    } label: {
                        SignalTile(
                            title: strings.activeEntitiesSignal,
                            value: topEntity.name,
                            caption: strings.entityKind(topEntity.kind),
                            systemImage: "sparkle.magnifyingglass",
                            color: .purple
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let relation = relations.first {
                    SignalTile(
                        title: strings.linkedIdeasSignal,
                        value: "\(relation.sourceEntityName) → \(relation.targetEntityName)",
                        caption: relation.predicate,
                        systemImage: "point.3.connected.trianglepath.dotted",
                        color: .blue
                    )
                }

                if showsOpenTopicsTile {
                    NavigationLink {
                        TopicsView()
                    } label: {
                        SignalTile(
                            title: strings.openTopics,
                            value: "\(topicSummaries.count)",
                            caption: strings.topicClusters,
                            systemImage: "square.stack.3d.up.fill",
                            color: .green
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    SignalTile(
                        title: strings.topicClusters,
                        value: "\(topicSummaries.count)",
                        caption: strings.currentStarMapStructure,
                        systemImage: "square.stack.3d.up.fill",
                        color: .green
                    )
                }
            }

            if !topicSummaries.dropFirst().isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(topicSummaries.dropFirst().prefix(5)) { summary in
                            NavigationLink {
                                KnowledgeCardCollectionView(
                                    title: summary.name,
                                    subtitle: strings.savedInsights(count: summary.cards.count),
                                    cards: summary.cards
                                )
                            } label: {
                                Text(summary.name)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Color.orange.opacity(0.12), in: Capsule())
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct SignalTile: View {
    let title: String
    let value: String
    let caption: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(color)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct KnowledgeCompassView: View {
    @Environment(KnowledgeCompassService.self) private var compassService
    @Query(sort: \InsightCard.createdAt, order: .reverse) private var cards: [InsightCard]
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    private var processedCards: [InsightCard] {
        cards.filter { $0.status == .processed }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(strings.knowledgeCompassTitle)
                            .font(.largeTitle.weight(.bold))
                        Text(strings.knowledgeCompassPageDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    KnowledgeCompassCard(
                        report: compassService.report,
                        generatedAt: compassService.generatedAt,
                        isGenerating: compassService.isGenerating,
                        errorMessage: compassService.lastRunError,
                        processedCount: processedCards.count,
                        strings: strings,
                        isImmersive: true
                    ) {
                        Task { await compassService.generateNow(cards: cards) }
                    }
                }
                .padding(20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: processedCards.count) {
                await compassService.generateIfNeeded(cards: cards)
            }
        }
    }
}

private struct KnowledgeCompassCard: View {
    let report: CloudAIService.KnowledgeCompassResult?
    let generatedAt: Date?
    let isGenerating: Bool
    let errorMessage: String?
    let processedCount: Int
    let strings: AppStrings
    var isImmersive = false
    let onGenerate: () -> Void
    @State private var selectedDirection = CompassDirection.focus

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                compassHeader

                if let generatedAt {
                    Text(strings.compassUpdated(generatedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if isGenerating {
                    Label(strings.generatingCompass, systemImage: "wand.and.stars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if processedCount < 4 {
                    Text(strings.compassNotEnoughCards)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let errorMessage {
                    Text(strings.localizedExtractionError(errorMessage))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if let report {
                    CompassOrbitControl(
                        selectedDirection: $selectedDirection,
                        strings: strings,
                        isCompact: !isImmersive
                    )

                    CompassDirectionDetail(
                        direction: selectedDirection,
                        report: report,
                        strings: strings,
                        isImmersive: isImmersive
                    )
                }
            }
        }
        .padding(isImmersive ? 18 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(compassBackground, in: RoundedRectangle(cornerRadius: isImmersive ? 28 : 22))
        .overlay {
            if isImmersive {
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(selectedDirection.color.opacity(0.22), lineWidth: 1)
            }
        }
        .shadow(color: isImmersive ? selectedDirection.color.opacity(0.12) : .clear, radius: 18, y: 10)
    }

    private var compassBackground: some ShapeStyle {
        if isImmersive {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        selectedDirection.color.opacity(0.16),
                        Color(.secondarySystemGroupedBackground).opacity(0.96),
                        Color(red: 0.90, green: 0.56, blue: 0.16).opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(.regularMaterial)
    }

    private var compassHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                if isImmersive, report != nil {
                    Label(strings.compassCurrentSignal, systemImage: selectedDirection.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectedDirection.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedDirection.color.opacity(0.12), in: Capsule())
                }

                Text(report?.headline ?? strings.knowledgeCompassDescription)
                    .font(report == nil ? .subheadline : (isImmersive ? .title3.weight(.bold) : .headline))
                    .foregroundStyle(report == nil ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onGenerate) {
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: report == nil ? "sparkles" : "arrow.clockwise")
                        .font(.headline.weight(.semibold))
                }
            }
            .buttonStyle(.plain)
            .frame(width: 52, height: 52)
            .background(
                (isImmersive ? selectedDirection.color : Color.accentColor).opacity(0.18),
                in: Circle()
            )
            .foregroundStyle(isImmersive ? selectedDirection.color : .accentColor)
            .disabled(isGenerating || processedCount < 4)
            .accessibilityLabel(report == nil ? strings.generateCompass : strings.refreshCompass)
        }
    }
}

private enum CompassDirection: CaseIterable {
    case focus
    case judgment
    case gap
    case explore

    var systemImage: String {
        switch self {
        case .focus: "scope"
        case .judgment: "lightbulb.max.fill"
        case .gap: "questionmark.diamond.fill"
        case .explore: "arrow.up.right.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .focus: .blue
        case .judgment: .cyan
        case .gap: .orange
        case .explore: .green
        }
    }

    func title(strings: AppStrings) -> String {
        switch self {
        case .focus: strings.compassFocus
        case .judgment: strings.compassJudgment
        case .gap: strings.compassGap
        case .explore: strings.compassExplore
        }
    }
}

private struct CompassDirectionGrid: View {
    @Binding var selectedDirection: CompassDirection
    let strings: AppStrings

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strings.compassTapDirection)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(CompassDirection.allCases, id: \.self) { direction in
                    CompassDirectionButton(
                        direction: direction,
                        isSelected: selectedDirection == direction,
                        strings: strings
                    ) {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedDirection = direction
                        }
                    }
                }
            }
        }
    }
}

private struct CompassOrbitControl: View {
    @Binding var selectedDirection: CompassDirection
    let strings: AppStrings
    var isCompact = false

    var body: some View {
        VStack(spacing: isCompact ? 10 : 14) {
            Text(strings.compassOrbitHint)
                .font(isCompact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: isCompact ? 24 : 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                selectedDirection.color.opacity(0.16),
                                Color.secondary.opacity(0.05),
                                selectedDirection.color.opacity(0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: diameter, height: diameter)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                selectedDirection.color.opacity(0.18),
                                Color.secondary.opacity(0.06),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: diameter * 0.46
                    )
                    )
                    .overlay(
                        Circle()
                            .stroke(selectedDirection.color.opacity(0.45), lineWidth: 1.2)
                    )

                Circle()
                    .strokeBorder(selectedDirection.color.opacity(0.18), style: StrokeStyle(lineWidth: 8, lineCap: .round, dash: [1, 17]))
                    .padding(diameter * 0.052)

                Circle()
                    .strokeBorder(Color.secondary.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [5, 8]))
                    .padding(diameter * 0.12)

                ForEach(CompassDirection.allCases, id: \.self) { direction in
                    CompassTick(direction: direction, selectedDirection: selectedDirection, radius: diameter * 0.43)
                }

                CompassNeedle(direction: selectedDirection)
                    .frame(width: needleSize, height: needleSize)
                    .rotationEffect(needleRotation)
                    .animation(.spring(response: 0.35, dampingFraction: 0.72), value: selectedDirection)

                directionButton(.focus, x: 0, y: -buttonOffset)
                directionButton(.judgment, x: buttonOffset, y: 0)
                directionButton(.gap, x: 0, y: buttonOffset)
                directionButton(.explore, x: -buttonOffset, y: 0)
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity)
        }
    }

    private var diameter: CGFloat {
        isCompact ? 236 : 286
    }

    private var needleSize: CGFloat {
        isCompact ? 78 : 96
    }

    private var buttonOffset: CGFloat {
        isCompact ? 76 : 92
    }

    private var needleRotation: Angle {
        switch selectedDirection {
        case .focus: .degrees(0)
        case .judgment: .degrees(90)
        case .gap: .degrees(180)
        case .explore: .degrees(270)
        }
    }

    private func directionButton(_ direction: CompassDirection, x: CGFloat, y: CGFloat) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedDirection = direction
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: direction.systemImage)
                    .font((isCompact ? Font.caption : Font.callout).weight(.bold))
                Text(direction.title(strings: strings))
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: isCompact ? 64 : 76, height: isCompact ? 52 : 58)
            .background(
                selectedDirection == direction
                    ? AnyShapeStyle(
                        LinearGradient(
                            colors: [direction.color, direction.color.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    : AnyShapeStyle(direction.color.opacity(0.14)),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(direction.color.opacity(selectedDirection == direction ? 0.35 : 0.10), lineWidth: 1)
            )
            .foregroundStyle(selectedDirection == direction ? .white : direction.color)
            .shadow(color: selectedDirection == direction ? direction.color.opacity(0.34) : .clear, radius: 14, y: 7)
        }
        .buttonStyle(.plain)
        .offset(x: x, y: y)
    }
}

private struct CompassTick: View {
    let direction: CompassDirection
    let selectedDirection: CompassDirection
    let radius: CGFloat

    private var offset: CGSize {
        switch direction {
        case .focus: CGSize(width: 0, height: -radius)
        case .judgment: CGSize(width: radius, height: 0)
        case .gap: CGSize(width: 0, height: radius)
        case .explore: CGSize(width: -radius, height: 0)
        }
    }

    var body: some View {
        Capsule()
            .fill(selectedDirection == direction ? direction.color : Color.secondary.opacity(0.22))
            .frame(width: direction == .judgment || direction == .explore ? 18 : 4, height: direction == .judgment || direction == .explore ? 4 : 18)
            .offset(offset)
    }
}

private struct CompassNeedle: View {
    let direction: CompassDirection

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            direction.color.opacity(0.28),
                            direction.color.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().strokeBorder(direction.color.opacity(0.26), lineWidth: 1))

            Capsule()
                .fill(direction.color.opacity(0.20))
                .frame(width: 7, height: 52)
                .offset(y: 24)

            CompassNeedleShape()
                .fill(
                    LinearGradient(
                        colors: [.white, direction.color.opacity(0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 54, height: 68)
                .offset(y: -17)
                .shadow(color: direction.color.opacity(0.45), radius: 12, y: 4)
                .overlay(
                    CompassNeedleShape()
                        .stroke(.white.opacity(0.65), lineWidth: 1.2)
                        .frame(width: 54, height: 68)
                        .offset(y: -17)
                )

            Circle()
                .fill(.background)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(direction.color.opacity(0.8), lineWidth: 2))
        }
    }
}

private struct CompassNeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.78))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct CompassDirectionButton: View {
    let direction: CompassDirection
    let isSelected: Bool
    let strings: AppStrings
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: direction.systemImage)
                    .font(.caption.weight(.bold))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(isSelected ? .white : direction.color)
                Text(direction.title(strings: strings))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? direction.color : direction.color.opacity(0.12),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .foregroundStyle(isSelected ? .white : direction.color)
        }
        .buttonStyle(.plain)
    }
}

private struct CompassDirectionDetail: View {
    let direction: CompassDirection
    let report: CloudAIService.KnowledgeCompassResult
    let strings: AppStrings
    var isImmersive = false

    private var title: String {
        switch direction {
        case .focus: strings.compassFocus
        case .judgment: strings.emergingJudgments
        case .gap: strings.knowledgeGaps
        case .explore: strings.explorationDirections
        }
    }

    private var items: [String] {
        switch direction {
        case .focus: [report.focusSummary]
        case .judgment: report.emergingJudgments
        case .gap: report.knowledgeGaps
        case .explore: report.explorationDirections
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isImmersive ? 14 : 10) {
            HStack(spacing: 10) {
                Image(systemName: direction.systemImage)
                    .font((isImmersive ? Font.title3 : Font.caption).weight(.bold))
                    .frame(width: isImmersive ? 34 : 22, height: isImmersive ? 34 : 22)
                    .background(direction.color.opacity(0.16), in: Circle())
                    .foregroundStyle(direction.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font((isImmersive ? Font.headline : Font.caption).weight(.semibold))
                        .foregroundStyle(direction.color)
                    if isImmersive {
                        Text(strings.compassReadingLane)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: isImmersive ? 10 : 8) {
                ForEach(Array(items.prefix(isImmersive ? 3 : 2).enumerated()), id: \.offset) { index, item in
                    CompassReadingRow(
                        index: index,
                        text: item,
                        color: direction.color,
                        isImmersive: isImmersive
                    )
                }
            }

            if isImmersive, direction == .explore, !report.recommendedSearches.isEmpty {
                Text(strings.compassActionDeck)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                CompassChipGroup(labels: Array(report.recommendedSearches.prefix(5)), color: direction.color)
            } else if direction == .explore, !report.recommendedSearches.isEmpty {
                CompassChipGroup(labels: Array(report.recommendedSearches.prefix(3)), color: direction.color)
                    .padding(.top, 2)
            }
        }
        .padding(isImmersive ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isImmersive
                ? AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            direction.color.opacity(0.16),
                            direction.color.opacity(0.08),
                            Color.secondary.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                : AnyShapeStyle(direction.color.opacity(0.08)),
            in: RoundedRectangle(cornerRadius: isImmersive ? 22 : 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isImmersive ? 22 : 16)
                .strokeBorder(direction.color.opacity(isImmersive ? 0.18 : 0), lineWidth: 1)
        )
        .id(direction)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

private struct CompassReadingRow: View {
    let index: Int
    let text: String
    let color: Color
    let isImmersive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(isImmersive ? .white : color)
                .frame(width: isImmersive ? 24 : 18, height: isImmersive ? 24 : 18)
                .background(isImmersive ? color : color.opacity(0.14), in: Circle())
                .shadow(color: isImmersive ? color.opacity(0.28) : .clear, radius: 8, y: 3)

            Text(text)
                .font(isImmersive ? .callout : .subheadline)
                .foregroundStyle(isImmersive ? .primary : .secondary)
                .lineLimit(isImmersive ? 5 : 4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(isImmersive ? 10 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isImmersive ? Color.primary.opacity(0.035) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct CompassChipGroup: View {
    let labels: [String]
    let color: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.caption2.weight(.medium))
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.12), in: Capsule())
                    .foregroundStyle(color)
            }
        }
    }
}

private struct CompassList: View {
    let title: String
    let items: [String]
    let color: Color

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 5, height: 5)
                            .padding(.top, 7)
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

private struct TopicClusterRow: View {
    let summary: TopicSummary
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(summary.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct EntityChip: View {
    let entity: EntitySummary
    let strings: AppStrings

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entity.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text("\(entity.cards.count) · \(strings.entityKind(entity.kind))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.12), in: Capsule())
        .foregroundStyle(.purple)
    }
}

struct KnowledgeCardCollectionView: View {
    let title: String
    let subtitle: String
    let cards: [InsightCard]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.weight(.bold))
                    Text(subtitle)
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
                }
            }
            .padding(20)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    KnowledgeMapView()
        .modelContainer(for: [InsightCard.self, Topic.self, TopicHierarchyNode.self, CardRelation.self, KnowledgeEntity.self, KnowledgeRelation.self], inMemory: true)
}
