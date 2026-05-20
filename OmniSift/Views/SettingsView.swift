import SwiftUI

struct SettingsView: View {
    @AppStorage("isPremium", store: UserDefaults(suiteName: appGroupID))
    private var isPremium = false

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
                        Text("On-Device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Model Status", systemImage: "arrow.down.circle")
                        Spacer()
                        // TODO: Check model download status
                        Text("Ready")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                // Privacy section
                Section("Privacy") {
                    Label("All data stays on your device", systemImage: "lock.shield.fill")
                        .foregroundStyle(.green)

                    Label("No internet required for AI", systemImage: "wifi.slash")
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
}

#Preview {
    SettingsView()
}
