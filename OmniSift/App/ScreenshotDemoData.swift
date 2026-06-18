#if DEBUG
import Foundation
import SwiftData

@MainActor
func seedScreenshotDemoDataIfNeeded(modelContext: ModelContext) {
    guard ProcessInfo.processInfo.environment["OMNISIFT_SCREENSHOT_MODE"] == "1" else {
        return
    }

    let defaults = UserDefaults(suiteName: appGroupID)
    defaults?.set(OutputLanguagePreference.english.rawValue, forKey: UserDefaultsKeys.outputLanguagePreference)

    let existingCards = (try? modelContext.fetch(FetchDescriptor<InsightCard>())) ?? []
    guard existingCards.isEmpty else { return }

    let cards = [
        demoCard(
            title: "SwiftData migration checklist",
            highlight: "Keep lightweight migrations boring, test the shared container path, and ship with one obvious rollback story.",
            summary: "A compact checklist for making SwiftData changes safer when the main app and Share Extension share the same store.",
            sourceApp: "Safari",
            sourceURLString: "https://developer.apple.com/documentation/swiftdata",
            sourceTitle: "SwiftData migration notes",
            topics: ["iOS Architecture", "Persistence"],
            keywords: ["SwiftData", "migration", "App Group"],
            entities: ["SwiftData", "App Group", "Share Extension"],
            relations: ["SwiftData requires a stable migration plan", "Share Extension reads the shared container"],
            confidence: 0.91
        ),
        demoCard(
            title: "Research reading workflow",
            highlight: "Capture first, organize second. The key is removing friction at the moment an idea appears.",
            summary: "Notes from a reading workflow that turns saved paragraphs into searchable cards with topics and entities.",
            sourceApp: "Research Chat",
            sourceTitle: "Research workflow conversation",
            topics: ["Research", "Knowledge Capture"],
            keywords: ["capture", "summary", "tags"],
            entities: ["Knowledge Graph", "OmniSift"],
            relations: ["Structured summaries reduce review time", "Knowledge Graph connects recurring concepts"],
            confidence: 0.88
        ),
        demoCard(
            title: "Pricing and usage limits",
            highlight: "Free users need enough daily value to form a habit; Pro should be for heavier capture.",
            summary: "A launch pricing note comparing free daily AI processing with a lightweight Pro subscription.",
            sourceApp: "Notes",
            sourceTitle: "Launch plan",
            topics: ["Product Strategy", "Subscriptions"],
            keywords: ["pricing", "free tier", "Pro"],
            entities: ["RevenueCat", "App Store", "OmniSift Pro"],
            relations: ["RevenueCat maps products to Pro entitlement", "Free tier supports habit formation"],
            confidence: 0.84
        ),
        demoCard(
            title: "Screenshot OCR idea capture",
            highlight: "Screenshots are often the fallback when text selection or webpage extraction is not available.",
            summary: "A capture pattern for saving images first, extracting text, and attaching source context when possible.",
            sourceApp: "Photos",
            sourceTitle: "OCR capture note",
            topics: ["Capture Methods", "OCR"],
            keywords: ["screenshot", "OCR", "fallback"],
            entities: ["Vision", "Screenshot", "Share Sheet"],
            relations: ["OCR converts images into reviewable cards", "Share Sheet keeps capture cross-app"],
            confidence: 0.81
        )
    ]

    cards.forEach(modelContext.insert)
    insertDemoTopics(cards: cards, modelContext: modelContext)
    insertDemoEntities(cards: cards, modelContext: modelContext)
    try? modelContext.save()
}

private func demoCard(
    title: String,
    highlight: String,
    summary: String,
    sourceApp: String,
    sourceURLString: String? = nil,
    sourceTitle: String,
    topics: [String],
    keywords: [String],
    entities: [String],
    relations: [String],
    confidence: Double
) -> InsightCard {
    let card = InsightCard(
        rawText: "\(title)\n\n\(summary)",
        sourceApp: sourceApp,
        sourceURLString: sourceURLString,
        sourceTitle: sourceTitle,
        tags: topics,
        extractionStatus: sourceURLString == nil ? .notNeeded : .fullText,
        contentType: sourceURLString == nil ? .text : .webPage,
        captureMethod: sourceURLString == nil ? .sharedText : .safariDOM
    )
    card.title = title
    card.highlight = highlight
    card.summary = summary
    card.topicNames = topics
    card.keywordNames = keywords
    card.entityNames = entities
    card.relationSummaries = relations
    card.confidence = confidence
    card.status = .processed
    card.processedAt = Date()
    card.createdAt = Date().addingTimeInterval(Double.random(in: -240_000 ... -3_600))
    return card
}

private func insertDemoTopics(cards: [InsightCard], modelContext: ModelContext) {
    let grouped = Dictionary(grouping: cards.flatMap { card in
        card.topicNames.map { topic in (topic, card.id.uuidString) }
    }, by: { $0.0 })

    for (topic, pairs) in grouped {
        modelContext.insert(Topic(name: topic, cardIDStrings: pairs.map(\.1)))
    }
}

private func insertDemoEntities(cards: [InsightCard], modelContext: ModelContext) {
    var cardIDsByEntity: [String: Set<String>] = [:]
    for card in cards {
        for entity in card.entityNames {
            cardIDsByEntity[entity, default: []].insert(card.id.uuidString)
        }
        for relation in card.relationSummaries {
            let pieces = relation.split(separator: " ", maxSplits: 1).map(String.init)
            guard let source = pieces.first else { continue }
            modelContext.insert(KnowledgeRelation(
                sourceEntityName: source,
                targetEntityName: card.title ?? "Insight",
                predicate: relation,
                cardIDString: card.id.uuidString,
                confidence: card.confidence
            ))
        }
    }

    for (entity, cardIDs) in cardIDsByEntity {
        modelContext.insert(KnowledgeEntity(name: entity, cardIDStrings: Array(cardIDs)))
    }
}
#endif
