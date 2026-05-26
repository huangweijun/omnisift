import Foundation
import SwiftData

/// App Group identifier shared between main app and Share Extension
let appGroupID = "group.com.omnisift.shared"

struct SharedContainerCreationError: LocalizedError {
    let errors: [Error]

    var errorDescription: String? {
        let details = errors
            .map { $0.localizedDescription }
            .joined(separator: "\n")
        return details.isEmpty ? "Could not create shared data store." : "Could not create shared data store.\n\(details)"
    }
}

private enum SharedContainerSetupError: LocalizedError {
    case appGroupUnavailable(String)
    case invalidAttachmentFileName

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable(let identifier):
            return "App Group container is not available: \(identifier)"
        case .invalidAttachmentFileName:
            return "The attachment file name is invalid."
        }
    }
}

/// Creates a shared ModelContainer that both the main app and Share Extension can access
/// via the App Group container directory.
/// NOTE: No @MainActor — Share Extension calls this from UIKit's main thread context
/// which is NOT the same as Swift concurrency's MainActor. Marking it @MainActor
/// causes a crash in the extension, preventing iOS from registering it in the share sheet.
func createSharedModelContainer(allowsInMemoryFallback: Bool = false) throws -> ModelContainer {
    let schema = sharedKnowledgeSchema
    guard let sharedStoreURL else {
        return try fallbackContainer(
            schema: schema,
            errors: [SharedContainerSetupError.appGroupUnavailable(appGroupID)],
            allowsInMemoryFallback: allowsInMemoryFallback
        )
    }

    let modelConfiguration = ModelConfiguration(
        schema: schema,
        url: sharedStoreURL,
        allowsSave: true
    )

    do {
        return try ModelContainer(
            for: schema,
            migrationPlan: OmniSiftMigrationPlan.self,
            configurations: [modelConfiguration]
        )
    } catch let sharedStoreError {
        return try fallbackContainer(
            schema: schema,
            errors: [sharedStoreError],
            allowsInMemoryFallback: allowsInMemoryFallback
        )
    }
}

func createInMemoryModelContainer() throws -> ModelContainer {
    try createInMemoryModelContainer(schema: sharedKnowledgeSchema)
}

let sharedKnowledgeSchema = Schema([
    InsightCard.self,
    Topic.self,
    TopicHierarchyNode.self,
    CardRelation.self,
    KnowledgeEntity.self,
    KnowledgeRelation.self
])

enum OmniSiftSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [InsightCard.self]
    }

    @Model
    final class InsightCard {
        var id: UUID
        var rawText: String
        var title: String?
        var summary: String?
        var highlight: String?
        var sourceApp: String?
        var tags: [String]
        var statusRawValue: String
        var createdAt: Date
        var processedAt: Date?
        var errorMessage: String?

        init(rawText: String, sourceApp: String? = nil, tags: [String] = []) {
            self.id = UUID()
            self.rawText = rawText
            self.sourceApp = sourceApp
            self.tags = tags
            self.statusRawValue = ProcessingStatus.pending.rawValue
            self.createdAt = Date()
        }
    }
}

enum OmniSiftSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            InsightCard.self,
            Topic.self,
            CardRelation.self,
            KnowledgeEntity.self,
            KnowledgeRelation.self
        ]
    }
}

enum OmniSiftSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            InsightCard.self,
            Topic.self,
            TopicHierarchyNode.self,
            CardRelation.self,
            KnowledgeEntity.self,
            KnowledgeRelation.self
        ]
    }
}

enum OmniSiftMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [OmniSiftSchemaV1.self, OmniSiftSchemaV2.self, OmniSiftSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: OmniSiftSchemaV1.self, toVersion: OmniSiftSchemaV2.self),
            .lightweight(fromVersion: OmniSiftSchemaV2.self, toVersion: OmniSiftSchemaV3.self)
        ]
    }
}

private func createInMemoryModelContainer(schema: Schema) throws -> ModelContainer {
    let configuration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true,
        allowsSave: true
    )
    return try ModelContainer(
        for: schema,
        configurations: [configuration]
    )
}

private func fallbackContainer(
    schema: Schema,
    errors: [Error],
    allowsInMemoryFallback: Bool
) throws -> ModelContainer {
    guard allowsInMemoryFallback else {
        throw SharedContainerCreationError(errors: errors)
    }

    do {
        return try createInMemoryModelContainer(schema: schema)
    } catch let inMemoryError {
        throw SharedContainerCreationError(errors: errors + [inMemoryError])
    }
}

/// URL for the shared SwiftData store in the App Group container.
private var sharedStoreURL: URL? {
    FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
        .appendingPathComponent("OmniSift.store")
}

func sharedAttachmentURL(fileName: String) -> URL? {
    guard isValidSharedAttachmentFileName(fileName),
          let directoryURL = sharedAttachmentsDirectoryURL() else {
        return nil
    }

    let directory = directoryURL.standardizedFileURL
    let fileURL = directory.appendingPathComponent(fileName, isDirectory: false).standardizedFileURL
    guard fileURL.deletingLastPathComponent() == directory else { return nil }
    return fileURL
}

func sharedAttachmentData(fileName: String?) throws -> Data? {
    guard let fileName else { return nil }
    guard let fileURL = sharedAttachmentURL(fileName: fileName) else {
        throw SharedContainerSetupError.invalidAttachmentFileName
    }
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    return try Data(contentsOf: fileURL)
}

func restoreSharedAttachment(data: Data, fileName: String?) throws {
    guard let fileName else { return }
    guard let fileURL = sharedAttachmentURL(fileName: fileName) else {
        throw SharedContainerSetupError.invalidAttachmentFileName
    }
    try data.write(to: fileURL, options: .atomic)
}

func deleteSharedAttachment(fileName: String?) throws {
    guard let fileName else { return }
    guard let fileURL = sharedAttachmentURL(fileName: fileName) else {
        throw SharedContainerSetupError.invalidAttachmentFileName
    }
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
    try FileManager.default.removeItem(at: fileURL)
}

func storeSharedAttachment(data: Data, fileExtension: String) throws -> String {
    guard let directoryURL = sharedAttachmentsDirectoryURL() else {
        throw SharedContainerSetupError.appGroupUnavailable(appGroupID)
    }

    try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
    )

    let normalizedExtension = fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    let fileName = "\(UUID().uuidString).\(normalizedExtension.isEmpty ? "dat" : normalizedExtension)"
    guard let fileURL = sharedAttachmentURL(fileName: fileName) else {
        throw SharedContainerSetupError.invalidAttachmentFileName
    }
    try data.write(to: fileURL, options: .atomic)
    return fileName
}

private func isValidSharedAttachmentFileName(_ fileName: String) -> Bool {
    guard !fileName.isEmpty,
          fileName == (fileName as NSString).lastPathComponent,
          !fileName.contains(".."),
          !fileName.contains("/"),
          !fileName.contains("\\") else {
        return false
    }

    let pattern = #"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\.[A-Za-z0-9]{1,8}$"#
    return fileName.range(of: pattern, options: .regularExpression) != nil
}

private func sharedAttachmentsDirectoryURL() -> URL? {
    FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
        .appendingPathComponent("Attachments", isDirectory: true)
}
