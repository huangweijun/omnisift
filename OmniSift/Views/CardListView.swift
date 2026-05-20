import SwiftUI
import SwiftData

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AIProcessingService.self) private var aiService
    @Query(sort: \InsightCard.createdAt, order: .reverse) private var cards: [InsightCard]

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    EmptyStateView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(cards) { card in
                                NavigationLink(value: card) {
                                    CardRow(card: card)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("OmniSift")
            .toolbar {
                if aiService.isProcessing {
                    ToolbarItem(placement: .status) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Processing...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationDestination(for: InsightCard.self) { card in
                CardDetailView(card: card)
            }
        }
    }
}

// MARK: - Card Row

struct CardRow: View {
    let card: InsightCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status indicator + source
            HStack {
                StatusBadge(status: card.status)
                Spacer()
                if let source = card.sourceApp {
                    Text(source)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(card.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Title or raw text preview
            if let title = card.title {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
            }

            // Highlight quote
            if let highlight = card.highlight {
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
                // Show raw text preview for unprocessed cards
                Text(card.rawText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Tags
            if !card.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(card.tags.prefix(3), id: \.self) { tag in
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

// MARK: - Status Badge

struct StatusBadge: View {
    let status: ProcessingStatus

    var body: some View {
        HStack(spacing: 4) {
            switch status {
            case .pending:
                Image(systemName: "clock")
                Text("Pending")
            case .processing:
                ProgressView()
                    .scaleEffect(0.6)
                Text("Processing")
            case .processed:
                Image(systemName: "checkmark.circle.fill")
                Text("Done")
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Failed")
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
        .modelContainer(for: InsightCard.self, inMemory: true)
}
