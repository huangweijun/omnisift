import Foundation

/// Handles AI text processing via the OmniSift iOS backend proxy.
/// This replaces local model inference to avoid OOM on devices with limited RAM.
actor CloudAIService {
    /// API configuration
    private let chatEndpoint = URL(string: "https://www.xuanduai.com/api/ios/chat")!
    private var appSecret: String? {
        if let secret = Bundle.main.configuredString(forInfoDictionaryKey: "OMNISIFT_IOS_APP_SECRET") {
            return secret
        }
        return Bundle.main.secretPlistString(forKey: "OMNISIFT_IOS_APP_SECRET")
    }

    /// Maximum input characters
    private static let maxInputChars = 3000

    struct ProcessingResult: Sendable {
        let title: String
        let highlight: String
        let summary: String
        let tags: [String]
        let topics: [String]
        let keywords: [String]
        let entities: [ExtractedEntity]
        let relations: [ExtractedRelation]
        let formattedOriginalMarkdown: String?
        let confidence: Double
    }

    struct ExtractedEntity: Sendable, Decodable {
        let name: String
        let kind: String
    }

    struct ExtractedRelation: Sendable, Decodable {
        let source: String
        let predicate: String
        let target: String
    }

    struct TopicOrganizationTopic: Sendable, Encodable {
        let name: String
        let normalizedName: String
        let summary: String?
        let cardCount: Int
        let sampleTitles: [String]
    }

    struct TopicOrganizationResult: Sendable {
        let nodes: [OrganizedTopicNode]
        let unassignedTopics: [String]
    }

    struct KnowledgeCompassInput: Sendable, Encodable {
        let generatedAt: Date
        let windowDays: Int
        let cards: [KnowledgeCompassCard]
    }

    struct KnowledgeCompassCard: Sendable, Encodable {
        let title: String
        let highlight: String?
        let summary: String?
        let topics: [String]
        let tags: [String]
        let entities: [String]
        let sourceTitle: String?
        let capturedAt: Date
    }

    struct KnowledgeCompassResult: Sendable, Codable {
        let headline: String
        let focusSummary: String
        let emergingJudgments: [String]
        let knowledgeGaps: [String]
        let explorationDirections: [String]
        let recommendedSearches: [String]
        let confidence: Double
    }

    struct OrganizedTopicNode: Sendable, Decodable {
        let name: String
        let summary: String?
        let topics: [String]?
        let confidence: Double?
        let children: [OrganizedTopicNode]?
    }

    enum CloudAIError: LocalizedError {
        case networkError(String)
        case apiError(Int, String)
        case parseError(String)
        case rateLimited
        case missingAppSecret
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .networkError(let msg): return "Network: \(msg)"
            case .apiError(let code, let msg): return "API(\(code)): \(msg.prefix(120))"
            case .parseError(let detail): return "Parse failed: \(detail.prefix(80))"
            case .rateLimited: return "Rate limited. Try again later."
            case .missingAppSecret: return "Cloud service app secret is not configured."
            case .unauthorized: return "Cloud service rejected authorization."
            }
        }
    }

    /// Process raw text through the cloud API
    func process(rawText: String) async throws -> ProcessingResult {
        let inputText = String(rawText.prefix(Self.maxInputChars))
        let outputLanguage = OutputLanguagePreference.stored.resolvedLanguage
        let text = try await sendMessage(
            system: systemPrompt(for: outputLanguage),
            userContent: inputText,
            maxTokens: 2200
        )

        return parseAIResponse(text)
    }

    func organizeTopics(_ topics: [TopicOrganizationTopic]) async throws -> TopicOrganizationResult {
        let outputLanguage = OutputLanguagePreference.stored.resolvedLanguage
        let payload: [String: Any] = [
            "topics": topics.map { topic in
                [
                    "name": topic.name,
                    "normalizedName": topic.normalizedName,
                    "summary": topic.summary ?? "",
                    "cardCount": topic.cardCount,
                    "sampleTitles": topic.sampleTitles
                ]
            },
            "constraints": [
                "maxDepth": 3,
                "maxLevel1Categories": 8,
                "maxChildrenPerNode": 8
            ]
        ]
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        guard let payloadText = String(data: payloadData, encoding: .utf8) else {
            throw CloudAIError.parseError("Could not encode topic organization input")
        }

        let text = try await sendMessage(
            system: topicOrganizationPrompt(for: outputLanguage),
            userContent: payloadText,
            maxTokens: 2048
        )
        return try parseTopicOrganizationResponse(text)
    }

    func generateKnowledgeCompass(_ input: KnowledgeCompassInput) async throws -> KnowledgeCompassResult {
        let outputLanguage = OutputLanguagePreference.stored.resolvedLanguage
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let payloadData = try encoder.encode(input)
        guard let payloadText = String(data: payloadData, encoding: .utf8) else {
            throw CloudAIError.parseError("Could not encode knowledge compass input")
        }

        let text = try await sendMessage(
            system: knowledgeCompassPrompt(for: outputLanguage),
            userContent: payloadText,
            maxTokens: 1600
        )
        return try parseKnowledgeCompassResponse(text)
    }

    // MARK: - Response Parsing

    private func sendMessage(system: String, userContent: String, maxTokens: Int) async throws -> String {
        guard let appSecret else {
            throw CloudAIError.missingAppSecret
        }

        let requestBody: [String: Any] = [
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": userContent]
            ]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: chatEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(appSecret, forHTTPHeaderField: "x-ios-app-secret")
        request.httpBody = jsonData
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CloudAIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudAIError.networkError("Invalid response type")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw CloudAIError.unauthorized
        }

        if httpResponse.statusCode == 429 {
            throw CloudAIError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "No body"
            throw CloudAIError.apiError(httpResponse.statusCode, body)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            let bodyPreview = String(data: data.prefix(200), encoding: .utf8) ?? "binary"
            throw CloudAIError.parseError(bodyPreview)
        }

        return text
    }

    private func systemPrompt(for outputLanguage: OutputLanguage) -> String {
        """
        You are a knowledge distillation assistant. Given raw text from an AI conversation or web content:
        1. Extract the single most important insight as a one-line "highlight" (max 50 words).
        2. Write a concise "title" (max 10 words) that captures the topic.
        3. Write a structured "summary" (max 300 words) in Markdown with:
           - A 1-2 sentence overview paragraph
           - A bullet-point list of key takeaways (use - prefix)
           - Include specific numbers, names, and facts when available
           - Use **bold** for critical terms
        4. If the original input contains readable article, note, transcript, or OCR text, create "formattedOriginalMarkdown":
           - Preserve the original meaning and order.
           - Remove duplicated navigation, ads, share prompts, cookie text, and unrelated UI chrome.
           - Add Markdown headings, paragraphs, bullet lists, block quotes, and code fences only when helpful.
           - Do not invent missing content.
           - Keep it concise but readable, max 900 words.
        5. If the input is only a URL, an unreadable/blocked page, OCR placeholder, image placeholder, or mostly noise, set "formattedOriginalMarkdown" to null.
        6. "title" and "highlight" must be plain text only. Never return JSON objects inside those fields.
        7. Remove pleasantries, filler, ads, navigation text, and AI disclaimers from analysis fields.
        8. Suggest 1-3 relevant tags.
        9. Suggest 1-3 stable personal knowledge topics. Use specific names, not generic buckets.
        10. Extract up to 8 entities as {"name":"...","kind":"person|company|product|concept|place|event|other"}.
        11. Extract up to 5 relations as {"source":"entity","predicate":"short verb phrase","target":"entity"}.
        12. Return confidence from 0.0 to 1.0 based on input quality and certainty.
        13. \(outputLanguage.aiInstruction)

        Respond ONLY with this JSON (no markdown fences, no extra text):
        {"title":"...","highlight":"...","summary":"...","formattedOriginalMarkdown":null,"tags":["..."],"topics":["..."],"keywords":["..."],"entities":[{"name":"...","kind":"concept"}],"relations":[{"source":"...","predicate":"...","target":"..."}],"confidence":0.8}
        """
    }

    private func topicOrganizationPrompt(for outputLanguage: OutputLanguage) -> String {
        """
        You organize a personal knowledge library into a calm, navigable topic hierarchy.
        Input is JSON containing flat topics with card counts and short sample titles. Do not invent source topics.

        Rules:
        1. Create a tree with max depth 3.
        2. Level 1 must be broad categories, ideally 5-8 categories, never more than 8.
        3. Level 2 should be clear domains under a broad category.
        4. Level 3 should be specific topic clusters only when useful.
        5. Each input topic normalizedName must appear in exactly one node's topics array.
        6. Use fewer, clearer groups instead of many tiny groups.
        7. Put uncertain or miscellaneous topics into a clear "Other" category.
        8. \(outputLanguage.aiInstruction)

        Respond ONLY with this JSON (no markdown fences, no extra text):
        {"nodes":[{"name":"...","summary":"...","topics":["input normalizedName"],"confidence":0.9,"children":[]}],"unassignedTopics":[]}
        """
    }

    private func knowledgeCompassPrompt(for outputLanguage: OutputLanguage) -> String {
        """
        You are a personal knowledge strategist reading the user's personal knowledge star map. Each saved card is a star, topics are constellations, and relations are routes between constellations. Produce a short "knowledge compass" report that explains what is already lit and what should be explored next.

        Goals:
        1. Explain which constellations or themes are becoming brighter in one compact sentence.
        2. Infer 2-3 cross-topic judgments, hypotheses, or patterns the user may be forming. Be cautious and phrase as "seems" when uncertain.
        3. Identify 2-3 dim areas: missing evidence, missing counterarguments, underexplored themes, or weak connections between constellations.
        4. Recommend 3-4 next exploration routes that would help the user light up or connect the star map. Prefer questions, source types, and search queries over specific URLs.
        5. Avoid generic productivity advice. Tie every point to the provided cards, topics, tags, entities, and relations.
        6. \(outputLanguage.aiInstruction)

        Keep the headline under 24 words, focusSummary under 45 words, and each list item under 22 words. Respond ONLY with this JSON:
        {"headline":"...","focusSummary":"...","emergingJudgments":["..."],"knowledgeGaps":["..."],"explorationDirections":["..."],"recommendedSearches":["..."],"confidence":0.8}
        """
    }

    private func parseAIResponse(_ response: String) -> ProcessingResult {
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let parsed = decodeAIResponseJSON(from: cleaned) {
            return makeProcessingResult(from: parsed)
        }

        if let jsonString = ContentStructure.extractBalancedJSONObject(from: cleaned),
           let parsed = decodeAIResponseJSON(from: jsonString) {
            return makeProcessingResult(from: parsed)
        }

        return fallbackExtract(from: cleaned)
    }

    private func decodeAIResponseJSON(from text: String) -> AIResponseJSON? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AIResponseJSON.self, from: data)
    }

    private func parseTopicOrganizationResponse(_ response: String) throws -> TopicOrganizationResult {
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let parsed = decodeTopicOrganizationJSON(from: cleaned) {
            return TopicOrganizationResult(nodes: parsed.nodes, unassignedTopics: parsed.unassignedTopics ?? [])
        }

        if let jsonString = ContentStructure.extractBalancedJSONObject(from: cleaned),
           let parsed = decodeTopicOrganizationJSON(from: jsonString) {
            return TopicOrganizationResult(nodes: parsed.nodes, unassignedTopics: parsed.unassignedTopics ?? [])
        }

        throw CloudAIError.parseError(String(cleaned.prefix(120)))
    }

    private func parseKnowledgeCompassResponse(_ response: String) throws -> KnowledgeCompassResult {
        let cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let parsed = decodeKnowledgeCompassJSON(from: cleaned) {
            return makeKnowledgeCompassResult(from: parsed)
        }

        if let jsonString = ContentStructure.extractBalancedJSONObject(from: cleaned),
           let parsed = decodeKnowledgeCompassJSON(from: jsonString) {
            return makeKnowledgeCompassResult(from: parsed)
        }

        throw CloudAIError.parseError(String(cleaned.prefix(120)))
    }

    private func decodeTopicOrganizationJSON(from text: String) -> TopicOrganizationResponseJSON? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(TopicOrganizationResponseJSON.self, from: data)
    }

    private func decodeKnowledgeCompassJSON(from text: String) -> KnowledgeCompassResponseJSON? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(KnowledgeCompassResponseJSON.self, from: data)
    }

    private func makeProcessingResult(from parsed: AIResponseJSON) -> ProcessingResult {
        ProcessingResult(
            title: sanitizeField(parsed.title, fallback: "Untitled"),
            highlight: sanitizeField(parsed.highlight, fallback: parsed.title),
            summary: parsed.summary.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: parsed.tags.cleanedKnowledgeLabels(limit: 3),
            topics: (parsed.topics ?? []).cleanedKnowledgeLabels(limit: 3),
            keywords: (parsed.keywords ?? []).cleanedKnowledgeLabels(limit: 8),
            entities: (parsed.entities ?? []).cleanedEntities(limit: 8),
            relations: (parsed.relations ?? []).cleanedRelations(limit: 5),
            formattedOriginalMarkdown: cleanFormattedOriginal(parsed.formattedOriginalMarkdown),
            confidence: min(max(parsed.confidence ?? 0.7, 0), 1)
        )
    }

    private func cleanFormattedOriginal(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 80 else { return nil }
        let lowered = trimmed.lowercased()
        let blockedMarkers = [
            "null",
            "image captured for ocr",
            "已采集图片，等待文字识别",
            "could not extract",
            "unreadable",
            "blocked page"
        ]
        guard !blockedMarkers.contains(where: { lowered == $0 || lowered.contains($0) }) else {
            return nil
        }
        return String(trimmed.prefix(6000))
    }

    private func sanitizeField(_ value: String, fallback: String) -> String {
        if let recovered = ContentStructure.recoverAIFields(from: value) {
            return recovered
        }
        return ContentStructure.cleanDisplayText(value) ?? fallback
    }

    private func makeKnowledgeCompassResult(from parsed: KnowledgeCompassResponseJSON) -> KnowledgeCompassResult {
        KnowledgeCompassResult(
            headline: sanitizeField(parsed.headline, fallback: "Knowledge Compass"),
            focusSummary: ContentStructure.cleanDisplayText(parsed.focusSummary) ?? parsed.focusSummary,
            emergingJudgments: parsed.emergingJudgments.cleanedSentences(limit: 4),
            knowledgeGaps: parsed.knowledgeGaps.cleanedSentences(limit: 4),
            explorationDirections: parsed.explorationDirections.cleanedSentences(limit: 5),
            recommendedSearches: parsed.recommendedSearches.cleanedSentences(limit: 5),
            confidence: min(max(parsed.confidence ?? 0.7, 0), 1)
        )
    }

    private func fallbackExtract(from text: String) -> ProcessingResult {
        if let jsonString = ContentStructure.extractBalancedJSONObject(from: text),
           let parsed = decodeAIResponseJSON(from: jsonString) {
            return makeProcessingResult(from: parsed)
        }

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let firstLine = lines.first ?? "Untitled"
        if firstLine.hasPrefix("{"),
           let recoveredTitle = ContentStructure.recoverAIFields(from: firstLine) {
            let highlight = ContentStructure.recoverHighlight(from: firstLine) ?? recoveredTitle
            return ProcessingResult(
                title: recoveredTitle,
                highlight: highlight,
                summary: String(lines.dropFirst().joined(separator: "\n").prefix(800)),
                tags: ["AI"],
                topics: [recoveredTitle].cleanedKnowledgeLabels(limit: 1),
                keywords: [],
                entities: [],
                relations: [],
                formattedOriginalMarkdown: nil,
                confidence: 0.35
            )
        }

        let title = String(firstLine.prefix(60))
        let highlight = lines.count > 1 ? String(lines[1].prefix(120)) : title
        let summary = lines.dropFirst().joined(separator: "\n")

        return ProcessingResult(
            title: title,
            highlight: highlight,
            summary: String(summary.prefix(800)),
            tags: ["AI"],
            topics: [title].cleanedKnowledgeLabels(limit: 1),
            keywords: [],
            entities: [],
            relations: [],
            formattedOriginalMarkdown: nil,
            confidence: 0.35
        )
    }
}

private struct AIResponseJSON: Decodable {
    let title: String
    let highlight: String
    let summary: String
    let tags: [String]
    let topics: [String]?
    let keywords: [String]?
    let entities: [CloudAIService.ExtractedEntity]?
    let relations: [CloudAIService.ExtractedRelation]?
    let formattedOriginalMarkdown: String?
    let confidence: Double?
}

private struct TopicOrganizationResponseJSON: Decodable {
    let nodes: [CloudAIService.OrganizedTopicNode]
    let unassignedTopics: [String]?
}

private struct KnowledgeCompassResponseJSON: Decodable {
    let headline: String
    let focusSummary: String
    let emergingJudgments: [String]
    let knowledgeGaps: [String]
    let explorationDirections: [String]
    let recommendedSearches: [String]
    let confidence: Double?
}

private extension Array where Element == String {
    func cleanedKnowledgeLabels(limit: Int) -> [String] {
        var seen = Set<String>()
        return compactMap { label -> String? in
            let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return nil }
            let key = cleaned.normalizedKnowledgeKey
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return cleaned
        }
        .prefix(limit)
        .map { $0 }
    }

    func cleanedSentences(limit: Int) -> [String] {
        var seen = Set<String>()
        return compactMap { sentence -> String? in
            let cleaned = ContentStructure.cleanDisplayText(sentence)
                ?? sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return nil }
            let key = cleaned.normalizedKnowledgeKey
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return cleaned
        }
        .prefix(limit)
        .map { $0 }
    }
}

private extension Array where Element == CloudAIService.ExtractedEntity {
    func cleanedEntities(limit: Int) -> [CloudAIService.ExtractedEntity] {
        var seen = Set<String>()
        return compactMap { entity -> CloudAIService.ExtractedEntity? in
            let name = entity.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let key = name.normalizedKnowledgeKey
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            let kind = entity.kind.trimmingCharacters(in: .whitespacesAndNewlines)
            return CloudAIService.ExtractedEntity(name: name, kind: kind.isEmpty ? "concept" : kind)
        }
        .prefix(limit)
        .map { $0 }
    }
}

private extension Array where Element == CloudAIService.ExtractedRelation {
    func cleanedRelations(limit: Int) -> [CloudAIService.ExtractedRelation] {
        compactMap { relation -> CloudAIService.ExtractedRelation? in
            let source = relation.source.trimmingCharacters(in: .whitespacesAndNewlines)
            let predicate = relation.predicate.trimmingCharacters(in: .whitespacesAndNewlines)
            let target = relation.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !source.isEmpty, !predicate.isEmpty, !target.isEmpty else { return nil }
            return CloudAIService.ExtractedRelation(source: source, predicate: predicate, target: target)
        }
        .prefix(limit)
        .map { $0 }
    }
}
