import SwiftUI

struct SettingsView: View {
    @AppStorage("isPremium", store: UserDefaults(suiteName: appGroupID))
    private var isPremium = false
    @Environment(AIProcessingService.self) private var aiService

    var body: some View {
        NavigationStack {
            List {
                // Usage section
                Section("Today's Usage") {
                    HStack {
                        Label("AI Processing", systemImage: "sparkles")
                        Spacer()
                        if isPremium {
                            Text("Unlimited")
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Text("\(DailyUsageTracker.todayCount) / \(DailyUsageTracker.freeLimit)")
                                .foregroundStyle(
                                    DailyUsageTracker.isLimitReached ? .red : .secondary
                                )
                        }
                    }

                    if !isPremium {
                        Button("Upgrade to Pro") {
                            // TODO: Present RevenueCat paywall
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                }

                // AI Model section
                Section("AI Model") {
                    HStack {
                        Label("Gemma 4 E2B", systemImage: "cpu")
                        Spacer()
                        Text("On-Device · ANE")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Status", systemImage: modelStatusIcon)
                        Spacer()
                        modelStatusView
                    }

                    if !aiService.isModelLoaded {
                        Button {
                            Task { await aiService.loadModel() }
                        } label: {
                            Label("Download Model (~1.5 GB)", systemImage: "arrow.down.circle")
                        }
                        .disabled(aiService.isModelDownloading)
                    }

                    if let error = aiService.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Privacy section
                Section("Privacy") {
                    Label("All data stays on your device", systemImage: "lock.shield.fill")
                        .foregroundStyle(.green)

                    Label("No internet required for AI", systemImage: "wifi.slash")
                        .foregroundStyle(.secondary)

                    Label("Zero backend, zero tracking", systemImage: "eye.slash")
                        .foregroundStyle(.secondary)
                }

                // About section
                Section("About") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://omnisift.app/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Model Status Helpers

    private var modelStatusIcon: String {
        if aiService.isModelLoaded { return "checkmark.circle.fill" }
        if aiService.isModelDownloading { return "arrow.down.circle" }
        if aiService.isModelCached { return "internaldrive" }
        return "arrow.down.to.line"
    }

    @ViewBuilder
    private var modelStatusView: some View {
        if aiService.isModelLoaded {
            Text("Ready")
                .font(.caption)
                .foregroundStyle(.green)
        } else if aiService.isModelDownloading {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Downloading...")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } else if aiService.isModelCached {
            Text("Cached (tap to load)")
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Text("Not Downloaded")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AIProcessingService())
}
