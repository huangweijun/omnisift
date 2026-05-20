import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ShareExtensionView: View {
    let extensionContext: NSExtensionContext?

    @Environment(\.modelContext) private var modelContext
    @State private var extractedText: String = ""
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var sourceApp: String = "Unknown"

    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Bottom sheet
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    // Handle bar
                    Capsule()
                        .fill(.secondary.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)

                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Save to OmniSift")
                                .font(.headline)
                            Text("AI will clean & structure this later")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Cancel") { dismiss() }
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 20)

                    // Content preview
                    if isLoading {
                        ProgressView("Extracting content...")
                            .frame(height: 100)
                    } else {
                        ScrollView {
                            Text(extractedText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 120)
                        .padding(.horizontal, 20)
                        .padding(12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 20)
                    }

                    // Usage info
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.tint)
                        Text("\(DailyUsageTracker.remainingFreeUses) free uses remaining today")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)

                    // Save button
                    Button {
                        saveAndDismiss()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Text(isSaving ? "Saving..." : "Save")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(extractedText.isEmpty || isSaving)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .task {
            await extractContent()
        }
    }

    // MARK: - Content Extraction

    private func extractContent() async {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            isLoading = false
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Try plain text first
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(
                        forTypeIdentifier: UTType.plainText.identifier
                    ) as? String {
                        extractedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        isLoading = false
                        return
                    }
                }

                // Try URL
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await provider.loadItem(
                        forTypeIdentifier: UTType.url.identifier
                    ) as? URL {
                        extractedText = url.absoluteString
                        isLoading = false
                        return
                    }
                }
            }
        }

        isLoading = false
    }

    // MARK: - Actions

    private func saveAndDismiss() {
        guard !extractedText.isEmpty else { return }
        isSaving = true

        let card = InsightCard(
            rawText: extractedText,
            sourceApp: sourceApp
        )
        modelContext.insert(card)

        do {
            try modelContext.save()
        } catch {
            print("Failed to save InsightCard: \(error)")
        }

        isSaving = false
        dismiss()
    }

    private func dismiss() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
