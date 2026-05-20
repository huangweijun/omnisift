import SwiftUI

struct SettingsView: View {
    @Environment(AIProcessingService.self) private var aiService
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                // Usage section
                Section("Today's Usage") {
                    HStack {
                        Label("AI Processing", systemImage: "sparkles")
                        Spacer()
                        if subscriptionService.isPremium {
                            Label("Unlimited", systemImage: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        } else {
                            Text("\(DailyUsageTracker.todayCount) / \(DailyUsageTracker.freeLimit)")
                                .foregroundStyle(
                                    DailyUsageTracker.isLimitReached ? .red : .secondary
                                )
                        }
                    }

                    if !subscriptionService.isPremium {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Upgrade to Pro", systemImage: "crown")
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
                        Label("Status", systemImage: aiService.isModelLoaded ? "checkmark.circle.fill" : "hourglass")
                        Spacer()
                        if aiService.isModelLoaded {
                            Text("Ready")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if aiService.isLoadingModel {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        } else {
                            Text("Idle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Label("Speed", systemImage: "gauge.with.dots.needle.33percent")
                        Spacer()
                        Text("~31 tok/s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let error = aiService.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                // Privacy section
                Section("Privacy") {
                    Label("All data stays on your device", systemImage: "lock.shield.fill")
                        .foregroundStyle(.green)

                    Label("No internet required", systemImage: "wifi.slash")
                        .foregroundStyle(.secondary)

                    Label("Zero backend, zero tracking", systemImage: "eye.slash")
                        .foregroundStyle(.secondary)
                }

                // Account section
                Section("Account") {
                    if subscriptionService.isPremium {
                        Label("Pro Active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }

                    Button("Restore Purchases") {
                        Task { await subscriptionService.restorePurchases() }
                    }
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
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AIProcessingService())
        .environment(SubscriptionService())
}
