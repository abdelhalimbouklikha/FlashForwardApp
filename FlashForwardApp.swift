import SwiftUI
import SwiftData

@main
struct FlashForwardApp: App {
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(settings)
                .preferredColorScheme(AppTheme.preferredColorScheme)
                .tint(AppTheme.accent)
        }
        .modelContainer(for: [DeckFolder.self, Deck.self, Card.self, ReviewLog.self])
    }
}

struct RootTabView: View {
    // Declared so the root re-renders on theme/font/language changes, which in
    // turn re-evaluates AppTheme.* and L(...) across the tab content.
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            DeckListView()
                .tabItem {
                    Label(L("tab.decks"), systemImage: "rectangle.stack.fill")
                }

            CardsView()
                .tabItem {
                    Label(L("tab.cards"), systemImage: "square.grid.2x2.fill")
                }

            SettingsView()
                .tabItem {
                    Label(L("tab.settings"), systemImage: "gearshape.fill")
                }
        }
    }
}