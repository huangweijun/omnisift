import Foundation
import SwiftData

/// Processing status for an insight card
enum ProcessingStatus: String, Codable, CaseIterable {
    case pending
    case processing
    case processed
    case failed
}

/// How much source content was captured before AI processing.
enum ExtractionStatus: String, Codable, CaseIterable {
    case notNeeded
    case pending
    case fullText
    case partialText
    case urlOnly
    case failed
}

/// Source content shape captured from the share sheet.
enum CapturedContentType: String, Codable, CaseIterable {
    case text
    case webPage
    case url
    case image
    case unknown
}

/// The capture channel that produced the card.
enum CaptureMethod: String, Codable, CaseIterable {
    case sharedText
    case sharedURL
    case clipboardURL
    case clipboardImage
    case safariDOM
    case fileImport
    case imageOCR
    case unknown
}

/// Core data model representing a collected knowledge snippet
@Model
final class InsightCard {
    var id: UUID
    var rawText: String
    var title: String?
    var summary: String?
    var highlight: String?
    var sourceApp: String?
    var sourceURLString: String?
    var sourceTitle: String?
    var attachmentFileName: String?
    var formattedOriginalMarkdown: String?
    var tags: [String]
    var topicNames: [String] = []
    var keywordNames: [String] = []
    var entityNames: [String] = []
    var relationSummaries: [String] = []
    var relatedCardIDStrings: [String] = []
    var confidence: Double = 0
    /// Stored as raw string for SwiftData #Predicate compatibility
    var statusRawValue: String
    /// Stored as raw string for SwiftData #Predicate compatibility
    var extractionStatusRawValue: String = ExtractionStatus.notNeeded.rawValue
    /// Stored as raw string for SwiftData #Predicate compatibility
    var contentTypeRawValue: String = CapturedContentType.text.rawValue
    /// Stored as raw string for SwiftData #Predicate compatibility
    var captureMethodRawValue: String = CaptureMethod.sharedText.rawValue
    var extractionError: String?
    var createdAt: Date
    var processedAt: Date?
    var errorMessage: String?

    /// Computed accessor for the typed enum
    @Transient
    var status: ProcessingStatus {
        get { ProcessingStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }

    /// Computed accessor for the typed enum
    @Transient
    var extractionStatus: ExtractionStatus {
        get { ExtractionStatus(rawValue: extractionStatusRawValue) ?? .notNeeded }
        set { extractionStatusRawValue = newValue.rawValue }
    }

    /// Computed accessor for the typed enum
    @Transient
    var contentType: CapturedContentType {
        get { CapturedContentType(rawValue: contentTypeRawValue) ?? .unknown }
        set { contentTypeRawValue = newValue.rawValue }
    }

    /// Computed accessor for the typed enum
    @Transient
    var captureMethod: CaptureMethod {
        get { CaptureMethod(rawValue: captureMethodRawValue) ?? .unknown }
        set { captureMethodRawValue = newValue.rawValue }
    }

    @Transient
    var sourceURL: URL? {
        SourceURLValidator.validatedWebURL(from: sourceURLString)
    }

    init(
        rawText: String,
        sourceApp: String? = nil,
        sourceURLString: String? = nil,
        sourceTitle: String? = nil,
        attachmentFileName: String? = nil,
        tags: [String] = [],
        extractionStatus: ExtractionStatus = .notNeeded,
        contentType: CapturedContentType = .text,
        captureMethod: CaptureMethod = .sharedText
    ) {
        self.id = UUID()
        self.rawText = rawText
        self.sourceApp = sourceApp
        self.sourceURLString = sourceURLString
        self.sourceTitle = sourceTitle
        self.attachmentFileName = attachmentFileName
        self.tags = tags
        self.statusRawValue = ProcessingStatus.pending.rawValue
        self.extractionStatusRawValue = extractionStatus.rawValue
        self.contentTypeRawValue = contentType.rawValue
        self.captureMethodRawValue = captureMethod.rawValue
        self.createdAt = Date()
    }
}

/// A user-facing topic generated from one or more cards.
@Model
final class Topic {
    var id: UUID
    var name: String
    var normalizedName: String
    var summary: String?
    var cardIDStrings: [String]
    var createdAt: Date
    var lastUpdatedAt: Date

    init(name: String, summary: String? = nil, cardIDStrings: [String] = []) {
        self.id = UUID()
        self.name = name
        self.normalizedName = name.normalizedKnowledgeKey
        self.summary = summary
        self.cardIDStrings = cardIDStrings
        self.createdAt = Date()
        self.lastUpdatedAt = Date()
    }
}

enum TopicHierarchySource: String, Codable, CaseIterable {
    case ai
    case deterministic
    case manual
}

/// A display projection that groups flat topics into a navigable hierarchy.
@Model
final class TopicHierarchyNode {
    var id: UUID
    var name: String
    var normalizedName: String
    var summary: String?
    var level: Int
    var parentIDString: String?
    var childIDStrings: [String]
    var topicNormalizedNames: [String]
    var cardIDStrings: [String]
    var sortOrder: Int
    var sourceRawValue: String
    var confidence: Double
    var createdAt: Date
    var lastUpdatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        summary: String? = nil,
        level: Int,
        parentIDString: String? = nil,
        childIDStrings: [String] = [],
        topicNormalizedNames: [String] = [],
        cardIDStrings: [String] = [],
        sortOrder: Int = 0,
        source: TopicHierarchySource = .deterministic,
        confidence: Double = 1,
        createdAt: Date = Date(),
        lastUpdatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.normalizedName = name.normalizedKnowledgeKey
        self.summary = summary
        self.level = level
        self.parentIDString = parentIDString
        self.childIDStrings = childIDStrings
        self.topicNormalizedNames = topicNormalizedNames
        self.cardIDStrings = cardIDStrings
        self.sortOrder = sortOrder
        self.sourceRawValue = source.rawValue
        self.confidence = confidence
        self.createdAt = createdAt
        self.lastUpdatedAt = lastUpdatedAt
    }

    @Transient
    var source: TopicHierarchySource {
        get { TopicHierarchySource(rawValue: sourceRawValue) ?? .deterministic }
        set { sourceRawValue = newValue.rawValue }
    }
}

/// A lightweight semantic edge between two cards.
@Model
final class CardRelation {
    var id: UUID
    var sourceCardIDString: String
    var targetCardIDString: String
    var relationTypeRawValue: String
    var reason: String
    var confidence: Double
    var createdAt: Date

    init(
        sourceCardIDString: String,
        targetCardIDString: String,
        relationType: CardRelationType,
        reason: String,
        confidence: Double
    ) {
        self.id = UUID()
        self.sourceCardIDString = sourceCardIDString
        self.targetCardIDString = targetCardIDString
        self.relationTypeRawValue = relationType.rawValue
        self.reason = reason
        self.confidence = confidence
        self.createdAt = Date()
    }

    @Transient
    var relationType: CardRelationType {
        get { CardRelationType(rawValue: relationTypeRawValue) ?? .related }
        set { relationTypeRawValue = newValue.rawValue }
    }
}

enum CardRelationType: String, Codable, CaseIterable {
    case related
    case similar
    case sameTopic
    case references
    case contradicts
}

/// A graph node extracted from card content.
@Model
final class KnowledgeEntity {
    var id: UUID
    var name: String
    var normalizedName: String
    var kind: String
    var cardIDStrings: [String]
    var createdAt: Date
    var lastSeenAt: Date

    init(name: String, kind: String = "concept", cardIDStrings: [String] = []) {
        self.id = UUID()
        self.name = name
        self.normalizedName = name.normalizedKnowledgeKey
        self.kind = kind
        self.cardIDStrings = cardIDStrings
        self.createdAt = Date()
        self.lastSeenAt = Date()
    }
}

/// A graph edge extracted from one card's AI analysis.
@Model
final class KnowledgeRelation {
    var id: UUID
    var sourceEntityName: String
    var targetEntityName: String
    var predicate: String
    var cardIDString: String
    var confidence: Double
    var createdAt: Date

    init(
        sourceEntityName: String,
        targetEntityName: String,
        predicate: String,
        cardIDString: String,
        confidence: Double
    ) {
        self.id = UUID()
        self.sourceEntityName = sourceEntityName
        self.targetEntityName = targetEntityName
        self.predicate = predicate
        self.cardIDString = cardIDString
        self.confidence = confidence
        self.createdAt = Date()
    }
}

extension String {
    var normalizedKnowledgeKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
