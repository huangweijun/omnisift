import SwiftUI
import SwiftData

@main
struct OmniSiftApp: App {
    let modelContainer: ModelContainer

    init() {
        modelContainer = createSharedModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
