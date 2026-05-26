import SwiftUI
import SwiftData

@main
struct OmniSiftApp: App {
    let modelContainer: ModelContainer
    let startupErrorMessage: String?
    @State private var aiService = AIProcessingService()
    @State private var subscriptionService = SubscriptionService()
    @State private var cleanupService = KnowledgeCleanupService()
    @State private var compassService = KnowledgeCompassService()
    @State private var hierarchyOrganizationService = TopicHierarchyOrganizationService()
    @State private var clipboardCaptureService = ClipboardCaptureService()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            modelContainer = try createSharedModelContainer()
            startupErrorMessage = nil
        } catch {
            startupErrorMessage = error.localizedDescription
            do {
                modelContainer = try createInMemoryModelContainer()
            } catch {
                fatalError("Could not create error-state data store: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let startupErrorMessage {
                DataStoreUnavailableView(errorMessage: startupErrorMessage)
            } else {
                ContentView()
                    .environment(aiService)
                    .environment(subscriptionService)
                    .environment(cleanupService)
                    .environment(compassService)
                    .environment(hierarchyOrganizationService)
                    .environment(clipboardCaptureService)
                    .task {
                        #if DEBUG
                        seedScreenshotDemoDataIfNeeded(modelContext: modelContainer.mainContext)
                        #endif
                        subscriptionService.configure()
                        aiService.configure(modelContext: modelContainer.mainContext)
                        cleanupService.configure(modelContext: modelContainer.mainContext)
                        compassService.configure()
                        hierarchyOrganizationService.configure(modelContext: modelContainer.mainContext)
                        clipboardCaptureService.configure(modelContext: modelContainer.mainContext)
                        await aiService.loadModel()

                        async let _ = subscriptionService.checkStatus()
                        await clipboardCaptureService.inspectPasteboardIfNeeded()
                        await aiService.processAllPending()
                        await cleanupService.runIfNeeded(reason: .afterProcessing)
                    }
                    .onChange(of: scenePhase) { newPhase in
                        if newPhase == .active, aiService.isModelLoaded {
                            Task {
                                await clipboardCaptureService.inspectPasteboardIfNeeded()
                                await aiService.processAllPending()
                                await cleanupService.runIfNeeded(reason: .appBecameActive)
                            }
                        }
                    }
            }
        }
        .modelContainer(modelContainer)
    }
}

private struct DataStoreUnavailableView: View {
    let errorMessage: String
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.orange)
            Text(strings.dataStoreUnavailableTitle)
                .font(.title3.weight(.semibold))
            Text(strings.dataStoreUnavailableDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(strings.localizedExtractionError(errorMessage))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .padding(24)
    }
}
