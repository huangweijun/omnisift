import Foundation
import SwiftData

/// App Group identifier shared between main app and Share Extension
let appGroupID = "group.com.omnisift.shared"

/// Creates a shared ModelContainer that both the main app and Share Extension can access
/// via the App Group container directory.
@MainActor
func createSharedModelContainer() -> ModelContainer {
    let schema = Schema([InsightCard.self])

    let modelConfiguration = ModelConfiguration(
        schema: schema,
        url: sharedStoreURL,
        allowsSave: true
    )

    do {
        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    } catch {
        fatalError("Could not create shared ModelContainer: \(error)")
    }
}

/// URL for the shared SwiftData store in the App Group container
private var sharedStoreURL: URL {
    guard let containerURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupID
    ) else {
        fatalError("App Group container not found: \(appGroupID)")
    }
    return containerURL.appendingPathComponent("OmniSift.store")
}
