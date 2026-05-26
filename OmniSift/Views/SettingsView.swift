import SwiftUI

struct SettingsView: View {
    private static let unlimitedModeTapThreshold = 10

    @Environment(AIProcessingService.self) private var aiService
    @Environment(SubscriptionService.self) private var subscriptionService
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue
    @State private var showPaywall = false
    @State private var versionTapCount = 0
    @State private var unlimitedEnabled = DailyUsageTracker.unlimitedMode

    private var canToggleUnlimitedMode: Bool {
        DailyUsageTracker.allowsTestingBypass
    }

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    private var dailyLimitReached: Bool {
        DailyUsageTracker.isLimitReached(isPremium: subscriptionService.isPremium)
    }

    private var outputLanguageBinding: Binding<OutputLanguagePreference> {
        Binding {
            OutputLanguagePreference(rawValue: outputLanguageRawValue) ?? .automatic
        } set: { newValue in
            outputLanguageRawValue = newValue.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Usage section
                Section(strings.todayUsage) {
                    HStack {
                        Label(strings.aiProcessing, systemImage: "sparkles")
                        Spacer()
                        if subscriptionService.isPremium {
                            Text("\(DailyUsageTracker.todayCount) / \(DailyUsageTracker.proLimit)")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(DailyUsageTracker.todayCount) / \(DailyUsageTracker.freeLimit)")
                                .foregroundStyle(
                                    dailyLimitReached ? .red : .secondary
                                )
                        }
                    }

                    if !subscriptionService.isPremium {
                        Button {
                            showPaywall = true
                        } label: {
                            Label(strings.upgradeToPro, systemImage: "crown")
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                }

                Section(strings.languageSection) {
                    Picker(strings.summaryLanguage, selection: outputLanguageBinding) {
                        ForEach(OutputLanguagePreference.allCases) { preference in
                            Text(strings.languagePreferenceName(preference)).tag(preference)
                        }
                    }

                    Text(languageHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // AI Processing section
                Section(strings.aiProcessing) {
                    HStack {
                        Label(strings.mode, systemImage: "cloud.fill")
                        Spacer()
                        Text(strings.cloudAI)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label(strings.status, systemImage: aiService.isModelLoaded ? "checkmark.circle.fill" : "hourglass")
                        Spacer()
                        if aiService.isModelLoaded {
                            Text(strings.ready)
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Text(strings.notConfigured)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    HStack {
                        Label(strings.latency, systemImage: "bolt.fill")
                        Spacer()
                        Text(strings.perCardLatency)
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
                Section(strings.privacy) {
                    Label(strings.articleExtractionOnDevice, systemImage: "doc.text.magnifyingglass")
                        .foregroundStyle(.green)

                    Label(strings.textSentToCloud, systemImage: "cloud.fill")
                        .foregroundStyle(.secondary)

                    Label(strings.sourceLinksAttached, systemImage: "link")
                        .foregroundStyle(.secondary)

                    Label(strings.noAccountRequired, systemImage: "person.crop.circle.badge.xmark")
                        .foregroundStyle(.secondary)

                    Label(strings.cardsStoredLocally, systemImage: "lock.shield.fill")
                        .foregroundStyle(.green)
                }

                // Account section
                Section(strings.account) {
                    if subscriptionService.isPremium {
                        Label(strings.proActive, systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    }

                    Button(strings.restorePurchases) {
                        Task { await subscriptionService.restorePurchases() }
                    }
                }

                // About section
                Section(strings.about) {
                    HStack {
                        Label(strings.version, systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard canToggleUnlimitedMode else { return }
                        versionTapCount += 1
                        if versionTapCount >= Self.unlimitedModeTapThreshold {
                            versionTapCount = 0
                            unlimitedEnabled.toggle()
                            DailyUsageTracker.setUnlimitedMode(unlimitedEnabled)
                        }
                    }

                    if canToggleUnlimitedMode && unlimitedEnabled {
                        Label(strings.unlimitedModeActive, systemImage: "infinity")
                            .foregroundStyle(.orange)
                    }

                    Link(destination: URL(string: "https://huangweijun.github.io/omnisift/privacy-policy.html")!) {
                        Label(strings.privacyPolicy, systemImage: "hand.raised.fill")
                    }
                }
            }
            .navigationTitle(strings.settingsTab)
            .sheet(isPresented: $showPaywall) {
                ProPaywallView()
            }
        }
    }

    private var languageHelpText: String {
        switch outputLanguageBinding.wrappedValue {
        case .automatic:
            strings.autoLanguageHelp
        case .simplifiedChinese:
            strings.chineseLanguageHelp
        case .english:
            strings.englishLanguageHelp
        }
    }
}

#Preview {
    SettingsView()
        .environment(AIProcessingService())
        .environment(SubscriptionService())
}
