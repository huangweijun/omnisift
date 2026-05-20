import SwiftUI
import SwiftData

@main
struct OmniSiftApp: App {
    let modelContainer: ModelContainer
    @State private var aiService = AIProcessingService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        modelContainer = createSharedModelContainer()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(aiService)
                .task {
                    aiService.configure(modelContext: modelContainer.mainContext)
                    await aiService.loadModel()
                    await aiService.processAllPending()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active, aiService.isModelLoaded {
                        Task { await aiService.processAllPending() }
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
