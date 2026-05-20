import Foundation
import SwiftData
#if canImport(CoreMLLLM)
import CoreMLLLM
#endif

/// Service responsible for processing pending InsightCards using the local Gemma 4 model.
/// The model is bundled directly in the app — no download needed, works offline immediately.
@MainActor
@Observable
class AIProcessingService {
    var isModelLoaded = false
    var isLoadingModel = false
    var isProcessing = false
    var processingProgress: Double = 0
    var currentCardID: UUID?
    var errorMessage: String?

    #if canImport(CoreMLLLM)
    private var llm: CoreMLLLM?
    #endif

    private var modelContext: ModelContext?

    /// Maximum input characters to send to the model (prevents OOM on very long texts)
    private static let maxInputChars = 2000

    /// System prompt for the AI cleaning task
    private let systemPrompt = """
    You are a knowledge distillation assistant. Given raw text from an AI conversation or web content:
    1. Extract the single most important insight as a one-line "highlight" (max 50 words).
    2. Write a concise "title" (max 10 words) that captures the topic.
    3. Clean and restructure the content into a brief "summary" (max 200 words) in Markdown.
    4. Remove pleasantries, filler, ads, navigation text, and AI disclaimers.
    5. Suggest 1-3 relevant tags from: AI, Code, Design, Business, Science, Health, Writing, Productivity.

    Respond ONLY with this JSON (no markdown fences, no extra text):
    {"title":"...","highlight":"...","summary":"...","tags":["...",".."]}
    """

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Model Lifecycle

    /// Load the Gemma 4 model from the app bundle (no download needed).
    func loadModel() async {
        guard !isModelLoaded, !isLoadingModel else { return }
        errorMessage = nil
        isLoadingModel = true

        #if canImport(CoreMLLLM)
        do {
            // Load from the bundled model directory inside the app
            guard let modelURL = Bundle.main.url(forResource: "gemma4e2b", withExtension: nil, subdirectory: "Models") else {
                // Fallback: check if models are in the top-level bundle
                guard let altURL = Bundle.main.resourceURL?.appendingPathComponent("Models/gemma4e2b") else {
                    errorMessage = "Model files not found in app bundle"
                    isLoadingModel = false
                    return
                }
                llm = try await CoreMLLLM.load(from: altURL)
                isLoadingModel = false
                isModelLoaded = true
                return
            }
            llm = try await CoreMLLLM.load(from: modelURL)
            isLoadingModel = false
            isModelLoaded = true
        } catch {
            isLoadingModel = false
            errorMessage = "Model load failed: \(error.localizedDescription)"
        }
        #else
        // Simulator fallback: mock mode
        try? await Task.sleep(for: .milliseconds(500))
        isLoadingModel = false
        isModelLoaded = true
        #endif
    }

    // MARK: - Batch Processing

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

        guard let pendingCards = try? modelContext.fetch(descriptor),
              !pendingCards.isEmpty else { return }

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

    // MARK: - Single Card Processing

    private func processCard(_ card: InsightCard) async {
        do {
            let inputText = String(card.rawText.prefix(Self.maxInputChars))
            let fullResponse: String

            #if canImport(CoreMLLLM)
            if let llm {
                fullResponse = try await generateWithLLM(llm, inputText: inputText)
            } else {
                fullResponse = mockGenerate(inputText: inputText)
            }
            #else
            fullResponse = mockGenerate(inputText: inputText)
            #endif

            let result = parseAIResponse(fullResponse)

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

    // MARK: - LLM Inference

    #if canImport(CoreMLLLM)
    private func generateWithLLM(_ llm: CoreMLLLM, inputText: String) async throws -> String {
        let messages: [CoreMLLLM.Message] = [
            .init(role: .user, content: """
            \(systemPrompt)

            ---
            RAW TEXT:
            \(inputText)
            """)
        ]

        var fullResponse = ""
        let stream = try await llm.generate(messages, maxTokens: 512)
        for await token in stream {
            fullResponse += token
        }
        return fullResponse
    }
    #endif

    /// Mock generation for simulator/development
    private func mockGenerate(inputText: String) -> String {
        let sentences = inputText.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let title = String((sentences.first ?? "Untitled").prefix(60))
        let highlight = sentences.count > 1
            ? String(sentences[1].prefix(120))
            : String(inputText.prefix(120))
        let summary = String(inputText.prefix(500))
        let tags = detectTags(from: inputText)

        let tagsJSON = tags.map { "\"\($0)\"" }.joined(separator: ",")
        return """
        {"title":"\(escapeJSON(title))","highlight":"\(escapeJSON(highlight))","summary":"\(escapeJSON(summary))","tags":[\(tagsJSON)]}
        """
    }

    private func escapeJSON(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    // MARK: - Response Parsing

    private func parseAIResponse(_ response: String) -> AIResult {
        let jsonString = extractJSON(from: response)

        if let data = jsonString.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(AIResponseJSON.self, from: data) {
            return AIResult(
                title: parsed.title,
                highlight: parsed.highlight,
                summary: parsed.summary,
                tags: parsed.tags
            )
        }

        return fallbackExtract(from: response)
    }

    private func extractJSON(from text: String) -> String {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return text
        }
        return String(text[start...end])
    }

    private func fallbackExtract(from text: String) -> AIResult {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let title = String((lines.first ?? "Untitled").prefix(60))
        let highlight = lines.count > 1 ? String(lines[1].prefix(120)) : title
        let summary = lines.dropFirst().joined(separator: "\n")

        return AIResult(
            title: title,
            highlight: highlight,
            summary: String(summary.prefix(800)),
            tags: detectTags(from: text)
        )
    }

    private func detectTags(from text: String) -> [String] {
        let keywords: [(String, [String])] = [
            ("AI", ["ai", "machine learning", "model", "neural", "llm", "gpt", "claude", "gemini"]),
            ("Code", ["code", "function", "swift", "python", "api", "programming", "debug"]),
            ("Design", ["design", "ui", "ux", "layout", "color", "font", "interface"]),
            ("Business", ["revenue", "growth", "market", "startup", "product", "strategy"]),
            ("Science", ["research", "experiment", "data", "hypothesis", "physics", "biology"]),
            ("Productivity", ["workflow", "efficiency", "habit", "tool", "automate", "system"]),
        ]

        let lowered = text.lowercased()
        return keywords
            .filter { pair in pair.1.contains(where: { lowered.contains($0) }) }
            .map(\.0)
    }
}

// MARK: - Data Types

private struct AIResult {
    let title: String
    let highlight: String
    let summary: String
    let tags: [String]
}

private struct AIResponseJSON: Decodable {
    let title: String
    let highlight: String
    let summary: String
    let tags: [String]
}
