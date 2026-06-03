import SwiftUI
import SwiftData

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIProcessingService.self) private var aiService
    @Query(sort: \InsightCard.createdAt, order: .reverse) private var cards: [InsightCard]
    @State private var selectedScope: CardScope = CardScope.initialSelection
    @State private var selectedTopic: String?
    @State private var searchText = ""
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    private enum CardScope: String, CaseIterable, Identifiable {
        case inbox
        case library

        var id: Self { self }

        static var initialSelection: CardScope {
            #if DEBUG
            if ProcessInfo.processInfo.environment["OMNISIFT_SCREENSHOT_MODE"] == "1" {
                return .library
            }
            #endif
            return .inbox
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            listControls

                            if visibleCards.isEmpty {
                                ContentUnavailableView(
                                    strings.noMatchingCards,
                                    systemImage: "tray",
                                    description: Text(strings.noMatchingCardsDescription)
                                )
                                .padding(.top, 40)
                            } else {
                                ForEach(visibleCards) { card in
                                    NavigationLink(value: card) {
                                        CardRow(card: card)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle(strings.appName)
            .searchable(text: $searchText, prompt: strings.searchPrompt)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        TopicsView()
                    } label: {
                        Label(strings.organizeTopics, systemImage: "square.stack.3d.up.fill")
                    }
                }
                if aiService.isProcessing {
                    ToolbarItem(placement: .status) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text(strings.processing)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if cards.contains(where: { $0.status == .failed }) && !aiService.isProcessing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await aiService.retryAllFailed() }
                        } label: {
                            Label(strings.retryAll, systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .navigationDestination(for: InsightCard.self) { card in
                CardDetailView(card: card)
            }
            .sheet(isPresented: Bindable(aiService).showLimitReachedPaywall) {
                ProPaywallView()
            }
        }
    }

    private var listControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(strings.scopePicker, selection: $selectedScope) {
                ForEach(CardScope.allCases) { scope in
                    Text(title(for: scope)).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if !topicNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        TopicFilterChip(title: strings.allTopics, isSelected: selectedTopic == nil) {
                            selectedTopic = nil
                        }
                        ForEach(topicNames, id: \.self) { topic in
                            TopicFilterChip(title: topic, isSelected: selectedTopic == topic) {
                                selectedTopic = topic
                            }
                        }
                    }
                }
            }
        }
    }

    private func title(for scope: CardScope) -> String {
        switch scope {
        case .inbox: strings.inboxScope
        case .library: strings.libraryScope
        }
    }

    private var visibleCards: [InsightCard] {
        cards
            .filter(matchesScope)
            .filter(matchesTopic)
            .filter(matchesSearch)
    }

    private var topicNames: [String] {
        var seen = Set<String>()
        return cards
            .flatMap(\.topicNames)
            .compactMap { topic -> String? in
                let key = topic.normalizedKnowledgeKey
                guard !key.isEmpty, !seen.contains(key) else { return nil }
                seen.insert(key)
                return topic
            }
            .sorted()
    }

    private func matchesScope(_ card: InsightCard) -> Bool {
        switch selectedScope {
        case .inbox:
            card.status != .processed || card.extractionStatus == .failed || card.extractionStatus == .urlOnly
        case .library:
            true
        }
    }

    private func matchesTopic(_ card: InsightCard) -> Bool {
        guard let selectedTopic else { return true }
        return card.topicNames.contains { $0.normalizedKnowledgeKey == selectedTopic.normalizedKnowledgeKey }
    }

    private func matchesSearch(_ card: InsightCard) -> Bool {
        let query = searchText.normalizedKnowledgeKey
        guard !query.isEmpty else { return true }

        let haystack = [
            card.title,
            card.highlight,
            card.summary,
            card.sourceTitle,
            card.sourceURLString,
            card.rawText,
            card.tags.joined(separator: " "),
            card.topicNames.joined(separator: " "),
            card.keywordNames.joined(separator: " "),
            card.entityNames.joined(separator: " ")
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .normalizedKnowledgeKey

        return haystack.contains(query)
    }
}

private struct TopicFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1), in: Capsule())
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Row

struct CardRow: View {
    let card: InsightCard
    @Environment(AIProcessingService.self) private var aiService
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status indicator + source
            HStack {
                StatusBadge(status: card.status)
                ExtractionBadge(status: card.extractionStatus)
                CaptureMethodBadge(method: card.captureMethod)
                Spacer()
                if let source = card.sourceApp, source != "Unknown" {
                    Text(source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(strings.relativeAge(since: card.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Title or raw text preview
            if let title = ContentStructure.cleanDisplayText(card.title)
                ?? ContentStructure.cleanDisplayText(card.sourceTitle) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
            }

            // Highlight quote
            if let highlight = ContentStructure.cleanDisplayText(card.highlight)
                ?? ContentStructure.recoverHighlight(from: card.highlight ?? "") {
                Text(highlight)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: 3)
                    }
            } else if card.status == .pending || card.status == .processing {
                Text(card.rawText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Error + retry for failed cards
            if card.status == .failed {
                VStack(alignment: .leading, spacing: 8) {
                    if let error = card.errorMessage {
                        Text(strings.localizedExtractionError(error))
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(2)
                    }
                    Text(card.rawText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Button {
                        Task { await aiService.retryCard(card) }
                    } label: {
                        Label(strings.retry, systemImage: "arrow.clockwise")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                }
            }

            if let extractionError = card.extractionError, card.extractionStatus == .failed {
                Label(strings.localizedExtractionError(extractionError), systemImage: "link.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            } else if card.contentType == .image {
                Label(strings.imageOCRCapture, systemImage: "text.viewfinder")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            } else if let sourceURLString = card.sourceURLString {
                Label(sourceURLString, systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            // Topics and tags
            let labels = (card.topicNames.isEmpty ? card.tags : card.topicNames)
                .compactMap { ContentStructure.cleanKnowledgeLabel($0) }
            if !labels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(labels.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            if card.status == .processing {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            }
        }
    }
}

// MARK: - Extraction Badge

struct ExtractionBadge: View {
    let status: ExtractionStatus
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    var body: some View {
        if status != .notNeeded {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
        }
    }

    private var label: String {
        switch status {
        case .notNeeded: strings.textCapture
        case .pending: strings.extractingStatus
        case .fullText: strings.fullTextStatus
        case .partialText: strings.partialTextStatus
        case .urlOnly: strings.urlOnlyStatus
        case .failed: strings.extractFailedStatus
        }
    }

    private var icon: String {
        switch status {
        case .notNeeded: "doc.text"
        case .pending: "arrow.clockwise"
        case .fullText: "doc.richtext"
        case .partialText: "doc.text.magnifyingglass"
        case .urlOnly: "link"
        case .failed: "exclamationmark.triangle"
        }
    }

    private var color: Color {
        switch status {
        case .notNeeded, .fullText: .green
        case .pending: Color.accentColor
        case .partialText, .urlOnly: .orange
        case .failed: .red
        }
    }
}

struct CaptureMethodBadge: View {
    let method: CaptureMethod
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    var body: some View {
        if method != .unknown {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    private var label: String {
        switch method {
        case .sharedText: strings.textCapture
        case .sharedURL: strings.urlCapture
        case .clipboardURL: strings.clipboardURLCapture
        case .clipboardImage: strings.clipboardImageCapture
        case .safariDOM: strings.webCapture
        case .fileImport: strings.fileCapture
        case .imageOCR: strings.ocrCapture
        case .unknown: strings.capture
        }
    }

    private var icon: String {
        switch method {
        case .sharedText: "text.quote"
        case .sharedURL: "link"
        case .clipboardURL: "doc.on.clipboard"
        case .clipboardImage: "photo.on.rectangle"
        case .safariDOM: "safari"
        case .fileImport: "doc"
        case .imageOCR: "text.viewfinder"
        case .unknown: "square.and.arrow.down"
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ProcessingStatus
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    var body: some View {
        HStack(spacing: 4) {
            switch status {
            case .pending:
                Image(systemName: "clock")
                Text(strings.pendingStatus)
            case .processing:
                ProgressView()
                    .scaleEffect(0.6)
                Text(strings.processingStatus)
            case .processed:
                Image(systemName: "checkmark.circle.fill")
                Text(strings.doneStatus)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                Text(strings.failedStatus)
            }
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(statusColor)
    }

    private var statusColor: Color {
        switch status {
        case .pending: .orange
        case .processing: Color.accentColor
        case .processed: .green
        case .failed: .red
        }
    }
}

#Preview {
    CardListView()
        .modelContainer(for: [InsightCard.self, Topic.self, TopicHierarchyNode.self, CardRelation.self, KnowledgeEntity.self, KnowledgeRelation.self], inMemory: true)
}
