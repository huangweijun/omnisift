import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .cards

    enum Tab {
        case cards, settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            CardListView()
                .tabItem {
                    Label("Cards", systemImage: "rectangle.stack.fill")
                }
                .tag(Tab.cards)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(Tab.settings)
        }
        .tint(Color.accentColor)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: InsightCard.self, inMemory: true)
}
