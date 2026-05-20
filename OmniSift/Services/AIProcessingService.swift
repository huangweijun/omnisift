import Foundation
import SwiftData

/// Service responsible for processing pending InsightCards using the local Gemma 4 model.
/// Runs in the main app only (not in Share Extension due to memory constraints).
@MainActor
@Observable
class AIProcessingService {
    var isModelLoaded = false
    var isProcessing = false
    var processingProgress: Double = 0
    var currentCardID: UUID?

    private var modelContext: ModelContext?

    /// System prompt for the AI cleaning task
    private let systemPrompt = """
    You are a knowledge distillation assistant. Given raw text from an AI conversation or web content:
    1. Extract the single most important insight as a one-line "highlight" (max 50 words).
    2. Write a concise "title" (max 10 words) that captures the topic.
    3. Clean and restructure the content into a brief "summary" (max 200 words) in Markdown format.
    4. Remove all pleasantries, filler, ads, navigation text, and AI disclaimers.
    5. Suggest 1-3 relevant tags.

    Respond in this exact JSON format:
    {"title": "...", "highlight": "...", "summary": "...", "tags": ["...", "..."]}
    """

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Load the Gemma 4 model (called once when app launches)
    func loadModel() async {
        // TODO: Integrate CoreML-LLM
        // let llm = try await CoreMLLLM.load(from: modelDirectory)
        isModelLoaded = true
    }

    /// Process all pending cards
    func processAllPending() async {
        guard isModelLoaded, !isProcessing else { return }
        guard let modelContext else { return }

        isProcessing = true
        defer { isProcessing = false }

        let pendingRaw = ProcessingStatus.pending.rawValue
        let descriptor = FetchDescriptor<InsightCard>(
            predicate: #Predicate { $0.statusRawValue == pendingRaw },
            sortBy: [SortDescriptor(\.createdAt)]
        )

        guard let pendingCards = try? modelContext.fetch(descriptor) else { return }

        for (index, card) in pendingCards.enumerated() {
            currentCardID = card.id
            processingProgress = Double(index) / Double(pendingCards.count)

            card.status = .processing
            try? modelContext.save()

            await processCard(card)

            processingProgress = Double(index + 1) / Double(pendingCards.count)
        }

        currentCardID = nil
        processingProgress = 0
    }

    /// Process a single card using the local AI model
    private func processCard(_ card: InsightCard) async {
        // For MVP: Use a mock/placeholder processing
        // TODO: Replace with actual CoreML-LLM inference
        do {
            // Simulate AI processing for now
            try await Task.sleep(for: .seconds(1))

            // Mock result — will be replaced with actual Gemma 4 inference
            let result = mockProcess(rawText: card.rawText)

            card.title = result.title
            card.highlight = result.highlight
            card.summary = result.summary
            card.tags = result.tags
            card.status = .processed
            card.processedAt = Date()

            DailyUsageTracker.incrementUsage()
            try? modelContext?.save()
        } catch {
            card.status = .failed
            card.errorMessage = error.localizedDescription
            try? modelContext?.save()
        }
    }

    /// Mock processing for development — extracts basic info from raw text
    private func mockProcess(rawText: String) -> (title: String, highlight: String, summary: String, tags: [String]) {
        let sentences = rawText.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let title = String(sentences.first?.prefix(60) ?? "Untitled Insight")
        let highlight = sentences.count > 1
            ? String(sentences[1].prefix(120))
            : String(rawText.prefix(120))
        let summary = String(rawText.prefix(500))
        let tags = extractTags(from: rawText)

        return (title, highlight, summary, tags)
    }

    /// Simple tag extraction based on content keywords
    private func extractTags(from text: String) -> [String] {
        let keywords: [(String, [String])] = [
            ("AI", ["ai", "machine learning", "model", "neural", "llm", "gpt", "claude", "gemini"]),
            ("Code", ["code", "function", "swift", "python", "api", "programming", "debug"]),
            ("Design", ["design", "ui", "ux", "layout", "color", "font", "interface"]),
            ("Business", ["revenue", "growth", "market", "startup", "product", "strategy"]),
        ]

        let lowered = text.lowercased()
        return keywords
            .filter { pair in pair.1.contains(where: { lowered.contains($0) }) }
            .map(\.0)
    }
}
