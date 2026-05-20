import Foundation
import SwiftData

/// Processing status for an insight card
enum ProcessingStatus: String, Codable, CaseIterable {
    case pending
    case processing
    case processed
    case failed
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
    var tags: [String]
    /// Stored as raw string for SwiftData #Predicate compatibility
    var statusRawValue: String
    var createdAt: Date
    var processedAt: Date?
    var errorMessage: String?

    /// Computed accessor for the typed enum
    @Transient
    var status: ProcessingStatus {
        get { ProcessingStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        rawText: String,
        sourceApp: String? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.rawText = rawText
        self.sourceApp = sourceApp
        self.tags = tags
        self.statusRawValue = ProcessingStatus.pending.rawValue
        self.createdAt = Date()
    }
}
