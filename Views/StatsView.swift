import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var decks: [Deck]
    @Query var cards: [Card]
    @Query(sort: [SortDescriptor(\ReviewLog.reviewTime, order: .reverse)])
    var reviewLogs: [ReviewLog]

    private var totalCards: Int { cards.count }
    private var dueToday: Int { cards.filter { $0.isDue }.count }
    private var newCards: Int { cards.filter {