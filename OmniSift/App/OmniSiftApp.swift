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
                .onAppear {
                    aiService.configure(modelContext: modelContainer.mainContext)
                    Task { await aiService.loadModel() }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task { await aiService.processAllPending() }
                    }
                }
        }
        .modelContainer(modelContainer)
    }
}
