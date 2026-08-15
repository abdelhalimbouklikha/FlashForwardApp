import SwiftUI
import SwiftData

@main
struct FlashForwardApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [Deck.self, Card.self, ReviewLog.self])
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            DeckListView()
                .tabItem {
                    Label("Decks", systemImage: "rectangle.stack.fill")
                }

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
        }
        .tint(AppTheme.accent)
    }
}