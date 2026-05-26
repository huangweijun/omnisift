import SwiftUI
import SwiftData
import UIKit

struct CardDetailView: View {
    let card: InsightCard
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InsightCard.createdAt, order: .reverse) private var allCards: [InsightCard]
    @Query(sort: \CardRelation.createdAt, order: .reverse) private var cardRelations: [CardRelation]
    @State private var showDeleteConfirm = false
    @State private var showCopiedToast = false
    @State private var showExportedToast = false
    @State private var deleteErrorMessage: String?
    @State private var selectedDetailTab: DetailTab = .summary
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    private var displayTitle: String? {
        ContentStructure.cleanDisplayText(card.title)
            ?? ContentStructure.cleanDisplayText(card.sourceTitle)
    }

    private var displayHighlight: String? {
        guard let highlight = card.highlight else { return nil }
        return ContentStructure.cleanDisplayText(highlight)
            ?? ContentStructure.recoverHighlight(from: highlight)
    }

    private var displaySummary: String? {
        guard let summary = card.summary else { return nil }
        return ContentStructure.cleanDisplayText(summary) ?? summary
    }

    private var readableOriginalMarkdown: String? {
        guard let markdown = card.formattedOriginalMarkdown?.trimmingCharacters(in: .whitespacesAndNewlines),
              markdown.count >= 80 else {
            return nil
        }
        return markdown
    }

    private var availableDetailTabs: [DetailTab] {
        if readableOriginalMarkdown == nil {
            return [.summary, .source]
        }
        return DetailTab.allCases
    }

    private var validWebSourceURL: URL? {
        guard let url = card.sourceURL else { return nil }
        return SourceURLValidator.validatedWebURL(url)
    }

    private var cleanedTopicNames: [String] {
        card.topicNames.compactMap { ContentStructure.cleanKnowledgeLabel($0) }
    }

    private var cleanedTags: [String] {
        card.tags.compactMap { ContentStructure.cleanKnowledgeLabel($0) }
    }

    private var deleteErrorIsPresented: Binding<Bool> {
        Binding(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )
    }

    private enum DetailTab: String, CaseIterable, Identifiable {
        case summary
        case original
        case source

        var id: Self { self }
    }

    init(card: InsightCard) {
        self.card = card
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                detailTabPicker
                selectedTabContent
            }
            .padding(20)
        }
        .navigationTitle(displayTitle ?? strings.insight)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if showCopiedToast {
                toastView(strings.copiedToClipboard, icon: "checkmark.circle.fill")
            }
            if showExportedToast {
                toastView(strings.savedToPhotos, icon: "checkmark.circle.fill")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(strings.exportAsImage, systemImage: "photo") {
                        exportAsImage()
                    }
                    Button(strings.copyText, systemImage: "doc.on.doc") {
                        copyContent()
                    }
                    Divider()
                    Button(strings.delete, systemImage: "trash", role: .destructive) {
                        showDeleteConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(strings.deleteCardQuestion, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(strings.delete, role: .destructive) {
                deleteCard()
            }
        }
        .alert(strings.deleteFailed, isPresented: deleteErrorIsPresented) {
            Button(strings.ok, role: .cancel) {
                deleteErrorMessage = nil
            }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    // MARK: - Sections

    private var detailTabPicker: some View {
        Picker(strings.detailContentPicker, selection: $selectedDetailTab) {
            ForEach(availableDetailTabs) { tab in
                Text(title(for: tab)).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: readableOriginalMarkdown == nil) { _, originalUnavailable in
            if originalUnavailable, selectedDetailTab == .original {
                selectedDetailTab = .source
            }
        }
    }

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedDetailTab {
        case .summary:
            summaryTabContent
        case .original:
            originalTabContent
        case .source:
            sourceTabContent
        }
    }

    @ViewBuilder
    private var summaryTabContent: some View {
        if let highlight = displayHighlight {
            highlightSection(highlight)
        }
        if let summary = displaySummary {
            summarySection(summary)
        }
        taxonomySection
        relatedInsightsSection
        metadataSection
    }

    @ViewBuilder
    private var originalTabContent: some View {
        if let readableOriginalMarkdown {
            readableOriginalContent(readableOriginalMarkdown)
        } else {
            sourceTabContent
        }
    }

    private func readableOriginalContent(_ markdown: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(strings.originalContent, systemImage: "doc.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            MarkdownContentView(markdown: markdown)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

            HStack {
                CaptureMethodBadge(method: card.captureMethod)
                ExtractionBadge(status: card.extractionStatus)
                Spacer()
                Text(strings.chars(markdown.count))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var sourceTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            sourceSection
            metadataSection
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusBadge(status: card.status)
                ExtractionBadge(status: card.extractionStatus)
                CaptureMethodBadge(method: card.captureMethod)
                Spacer()
                if let source = card.sourceApp, source != "Unknown" {
                    Label(source, systemImage: "app.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let title = displayTitle {
                Text(title)
                    .font(.title2.weight(.bold))
            }
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(strings.source, systemImage: "link")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let sourceTitle = card.sourceTitle, !sourceTitle.isEmpty {
                Text(sourceTitle)
                    .font(.body.weight(.medium))
            }

            if let sourceURLString = card.sourceURLString {
                Text(sourceURLString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let sourceURL = validWebSourceURL {
                Link(destination: sourceURL) {
                    Label(strings.openSourceInApp(sourceAppName), systemImage: sourceOpenIcon)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
            } else if card.sourceURLString == nil {
                Label(strings.noSourceLink, systemImage: "link.badge.plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(strings.invalidSourceLink, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let extractionError = card.extractionError, card.extractionStatus == .failed {
                Label(strings.localizedExtractionError(extractionError), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if card.contentType == .image {
                Label(strings.originalImageRetained, systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            attachmentImagePreview
        }
        .showIf(card.sourceTitle != nil || card.sourceURLString != nil || card.extractionError != nil || card.contentType == .image)
    }

    @ViewBuilder
    private var attachmentImagePreview: some View {
        if card.contentType == .image,
           let image = attachmentImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                }
        }
    }

    private var taxonomySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(strings.knowledge, systemImage: "square.stack.3d.up")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if !cleanedTopicNames.isEmpty {
                labelGroup(title: strings.topics, labels: cleanedTopicNames, color: .accentColor)
            }

            if !cleanedTags.isEmpty {
                labelGroup(title: strings.tags, labels: cleanedTags, color: .blue)
            }

            if !card.entityNames.isEmpty {
                labelGroup(title: strings.entities, labels: card.entityNames, color: .purple)
            }

            if !card.relationSummaries.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text(strings.relations)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(card.relationSummaries.prefix(5), id: \.self) { relation in
                        Text(relation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .showIf(!cleanedTopicNames.isEmpty || !cleanedTags.isEmpty || !card.entityNames.isEmpty || !card.relationSummaries.isEmpty)
    }

    private var relatedInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(strings.relatedInsights, systemImage: "point.3.connected.trianglepath.dotted")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(relatedCards) { relatedCard in
                NavigationLink(value: relatedCard) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ContentStructure.cleanDisplayText(relatedCard.title)
                            ?? ContentStructure.cleanDisplayText(relatedCard.sourceTitle)
                            ?? strings.untitled)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if let reason = relationReason(for: relatedCard) {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .showIf(!relatedCards.isEmpty)
    }

    private func highlightSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(text)
                .font(.body.italic())
                .foregroundStyle(.primary.opacity(0.9))
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.08))
                )
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 4)
                        .padding(.vertical, 8)
                }
        }
    }

    private func summarySection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(strings.summary, systemImage: "text.alignleft")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            MarkdownContentView(markdown: text)
        }
    }

    private func title(for tab: DetailTab) -> String {
        switch tab {
        case .summary: strings.summaryTab
        case .original: strings.originalTab
        case .source: strings.sourceTab
        }
    }

    private var sourceAppName: String {
        guard let sourceApp = card.sourceApp,
              !sourceApp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              sourceApp != "Unknown" else {
            return strings.source
        }
        return sourceApp
    }

    private var sourceOpenIcon: String {
        if sourceAppName == "小红书" {
            return "app.connected.to.app.below.fill"
        }
        return "safari"
    }

    private var attachmentImage: UIImage? {
        guard let data = try? sharedAttachmentData(fileName: card.attachmentFileName) else {
            return nil
        }
        return UIImage(data: data)
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Label(card.createdAt.formatted(.dateTime.month().day().hour().minute().locale(strings.locale)),
                      systemImage: "calendar")
                Spacer()
                if card.confidence > 0 {
                    Text("AI \(Int(card.confidence * 100))%")
                }
                Text(strings.chars(card.rawText.count))
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private func copyContent() {
        let text = [
            card.title,
            card.highlight,
            card.summary,
            card.topicNames.isEmpty ? nil : "\(strings.copyTopicsPrefix) \(card.topicNames.joined(separator: ", "))",
            card.sourceURLString
        ]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        UIPasteboard.general.string = text
        withAnimation { showCopiedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showCopiedToast = false }
        }
    }

    private func exportAsImage() {
        let renderer = ImageRenderer(content: exportCardView)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation { showExportedToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showExportedToast = false }
        }
    }

    private func deleteCard() {
        let cardID = card.id.uuidString
        let attachmentFileName = card.attachmentFileName
        var attachmentData: Data?

        do {
            attachmentData = try sharedAttachmentData(fileName: attachmentFileName)
            try deleteSharedAttachment(fileName: attachmentFileName)
            try removeKnowledgeReferences(to: cardID)
            modelContext.delete(card)
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            if let attachmentData {
                try? restoreSharedAttachment(data: attachmentData, fileName: attachmentFileName)
            }
            deleteErrorMessage = error.localizedDescription
        }
    }

    private func removeKnowledgeReferences(to cardID: String) throws {
        for topic in try fetchModels(Topic.self) {
            let remainingIDs = topic.cardIDStrings.filter { $0 != cardID }
            if remainingIDs.isEmpty {
                modelContext.delete(topic)
            } else if remainingIDs.count != topic.cardIDStrings.count {
                topic.cardIDStrings = remainingIDs
                topic.lastUpdatedAt = Date()
            }
        }

        for entity in try fetchModels(KnowledgeEntity.self) {
            let remainingIDs = entity.cardIDStrings.filter { $0 != cardID }
            if remainingIDs.isEmpty {
                modelContext.delete(entity)
            } else if remainingIDs.count != entity.cardIDStrings.count {
                entity.cardIDStrings = remainingIDs
            }
        }

        for relation in try fetchModels(KnowledgeRelation.self) where relation.cardIDString == cardID {
            modelContext.delete(relation)
        }

        for relation in try fetchModels(CardRelation.self) where relation.sourceCardIDString == cardID || relation.targetCardIDString == cardID {
            modelContext.delete(relation)
        }

        for relatedCard in allCards where relatedCard.id.uuidString != cardID && relatedCard.relatedCardIDStrings.contains(cardID) {
            relatedCard.relatedCardIDStrings = relatedCard.relatedCardIDStrings.filter { $0 != cardID }
        }
    }

    private func fetchModels<Model: PersistentModel>(_ modelType: Model.Type) throws -> [Model] {
        try modelContext.fetch(FetchDescriptor<Model>())
    }

    @ViewBuilder
    private var exportCardView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = card.title {
                Text(title)
                    .font(.title3.weight(.bold))
            }
            if let highlight = card.highlight {
                Text(highlight)
                    .font(.body.italic())
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(Color.blue).frame(width: 3)
                    }
            }
            if let summary = card.summary {
                Text(summary)
                    .font(.callout)
            }
            HStack {
                Text(strings.appName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(card.createdAt.formatted(.dateTime.month().day().locale(strings.locale)))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func toastView(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func labelGroup(title: String, labels: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            FlowLabelGroup(labels: labels, color: color)
        }
    }

    private var relatedCards: [InsightCard] {
        let relatedIDs = Set(card.relatedCardIDStrings)
        let relationIDs = Set(cardRelations
            .filter { $0.sourceCardIDString == card.id.uuidString }
            .map(\.targetCardIDString))
        let allRelatedIDs = relatedIDs.union(relationIDs)

        return allCards.filter { allRelatedIDs.contains($0.id.uuidString) }
    }

    private func relationReason(for relatedCard: InsightCard) -> String? {
        cardRelations.first {
            $0.sourceCardIDString == card.id.uuidString &&
            $0.targetCardIDString == relatedCard.id.uuidString
        }.map { strings.localizedRelationReason($0.reason) }
    }
}

private struct FlowLabelGroup: View {
    let labels: [String]
    let color: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(labels, id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.12), in: Capsule())
                    .foregroundStyle(color)
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func showIf(_ condition: Bool) -> some View {
        if condition {
            self
        }
    }
}

#Preview {
    NavigationStack {
        CardDetailView(card: InsightCard(
            rawText: "This is a sample raw text from a conversation with Claude about Swift concurrency patterns.",
            sourceApp: "Claude"
        ))
    }
    .modelContainer(for: [InsightCard.self, Topic.self, TopicHierarchyNode.self, CardRelation.self, KnowledgeEntity.self, KnowledgeRelation.self], inMemory: true)
}
