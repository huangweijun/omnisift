import SwiftUI

struct ContentView: View {
    @Environment(ClipboardCaptureService.self) private var clipboardCaptureService
    @State private var selectedTab: Tab = Tab.initialSelection
    @AppStorage(UserDefaultsKeys.outputLanguagePreference, store: UserDefaults(suiteName: appGroupID))
    private var outputLanguageRawValue = OutputLanguagePreference.automatic.rawValue

    private var strings: AppStrings {
        AppStrings(rawPreferenceValue: outputLanguageRawValue)
    }

    enum Tab {
        case map, cards, settings

        static var initialSelection: Tab {
            #if DEBUG
            guard ProcessInfo.processInfo.environment["OMNISIFT_SCREENSHOT_MODE"] == "1" else {
                return .map
            }
            switch ProcessInfo.processInfo.environment["OMNISIFT_SCREENSHOT_TAB"] {
            case "cards":
                return .cards
            case "settings":
                return .settings
            default:
                return .map
            }
            #else
            return .map
            #endif
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            KnowledgeMapView()
                .tabItem {
                    Label(strings.knowledgeMapTab, systemImage: "point.3.connected.trianglepath.dotted")
                }
                .tag(Tab.map)

            CardListView()
                .tabItem {
                    Label(strings.libraryTab, systemImage: "rectangle.stack.fill")
                }
                .tag(Tab.cards)

            SettingsView()
                .tabItem {
                    Label(strings.settingsTab, systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(Color.accentColor)
        .safeAreaInset(edge: .bottom) {
            if let candidate = clipboardCaptureService.candidate {
                ClipboardCapturePrompt(candidate: candidate, strings: strings) {
                    Task { await clipboardCaptureService.collectCurrentCandidate() }
                } ignore: {
                    clipboardCaptureService.ignoreCurrentCandidate()
                } suppress: {
                    clipboardCaptureService.ignoreCurrentCandidate(permanently: true)
                }
            }
        }
    }
}

private struct ClipboardCapturePrompt: View {
    let candidate: ClipboardCaptureService.Candidate
    let strings: AppStrings
    let collect: () -> Void
    let ignore: () -> Void
    let suppress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: candidate.kind == .image ? "photo.on.rectangle" : "link.badge.plus")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.title)
                        .font(.subheadline.weight(.semibold))
                    Text(candidate.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let preview = candidate.preview {
                        Text(preview)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Button(action: ignore) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(strings.ignore)
            }

            HStack(spacing: 10) {
                Button(action: collect) {
                    Label(strings.collect, systemImage: "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if candidate.canSuppressPermanently {
                    Button(strings.dontAskAgainForThisLink, action: suppress)
                        .font(.caption.weight(.medium))
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }
}

#Preview {
    ContentView()
        .environment(KnowledgeCompassService())
        .environment(ClipboardCaptureService())
        .modelContainer(for: [InsightCard.self, Topic.self, TopicHierarchyNode.self, CardRelation.self, KnowledgeEntity.self, KnowledgeRelation.self], inMemory: true)
}
