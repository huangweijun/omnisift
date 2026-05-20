import SwiftUI

struct CardDetailView: View {
    let card: InsightCard

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                // Highlight quote
                if let highlight = card.highlight {
                    highlightSection(highlight)
                }

                // Summary content
                if let summary = card.summary {
                    summarySection(summary)
                }

                // Raw text (collapsible)
                rawTextSection

                // Metadata
                metadataSection
            }
            .padding(20)
        }
        .navigationTitle(card.title ?? "Insight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Export as Image", systemImage: "photo") {
                        // TODO: ImageRenderer export
                    }
                    Button("Copy Text", systemImage: "doc.on.doc") {
                        copyContent()
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        // TODO: Delete action
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusBadge(status: card.status)
                Spacer()
                if let source = card.sourceApp {
                    Label(source, systemImage: "app.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let title = card.title {
                Text(title)
                    .font(.title2.weight(.bold))
            }
        }
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
            Label("Summary", systemImage: "text.alignleft")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(text)
                .font(.body)
                .lineSpacing(4)
        }
    }

    private var rawTextSection: some View {
        DisclosureGroup {
            Text(card.rawText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } label: {
            Label("Original Text", systemImage: "doc.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Label(card.createdAt.formatted(.dateTime.month().day().hour().minute()),
                      systemImage: "calendar")
                Spacer()
                Text("\(card.rawText.count) chars")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Actions

    private func copyContent() {
        let text = [card.title, card.highlight, card.summary]
            .compactMap { $0 }
            .joined(separator: "\n\n")
        UIPasteboard.general.string = text
    }
}

#Preview {
    NavigationStack {
        CardDetailView(card: InsightCard(
            rawText: "This is a sample raw text from a conversation with Claude about Swift concurrency patterns.",
            sourceApp: "Claude"
        ))
    }
}
