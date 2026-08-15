import SwiftUI
import SwiftData

struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Deck.createdAt, order: .reverse)]) var decks: [Deck]

    @State private var showingAddDeck = false
    @State private var deckToRename: Deck? = nil
    @State private var deckToDelete: Deck? = nil
    @State private var showingDeleteConfirm = false
    @State private var selectedDeck: Deck? = nil

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    EmptyStateView(
                        icon: "rectangle.stack.badge.plus",
                        title: "No Decks Yet",
                        message: "Create your first deck to start learning with spaced repetition powered by FSRS.",
                        actionTitle: "Create Deck",
                        action: { showingAddDeck = true }
                    )
                } else {
                    deckList
                }
            }
            .primaryGradientBackground()
            .navigationTitle("FlashForward")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddDeck = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showingAddDeck) {
                AddEditDeckView()
            }
            .sheet(item: $deckToRename) { deck in
                AddEditDeckView(deck: deck)
            }
            .navigationDestination(item: $selectedDeck) { deck in
                DeckDetailView(deck: deck)
            }
            .alert("Delete Deck?", isPresented: $showingDeleteConfirm) {
                Button("Cancel", role: .cancel) {
                    deckToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let deck = deckToDelete {
                        modelContext.delete(deck)
                        deckToDelete = nil
                    }
                }
            } message: {
                if let deck = deckToDelete {
                    Text("This will permanently delete \"\(deck.name)\" and all \(deck.cards.count) cards in it.")
                }
            }
        }
    }

    private var deckList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.spacingM) {
                ForEach(decks) { deck in
                    DeckRow(deck: deck) {
                        selectedDeck = deck
                    }
                    .contextMenu {
                        Button {
                            deckToRename = deck
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deckToDelete = deck
                            showingDeleteConfirm = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, AppTheme.spacingS)
            .padding(.bottom, AppTheme.spacingXL)
        }
    }
}

// MARK: - Deck Row

struct DeckRow: View {
    let deck: Deck
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.spacingM) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent.opacity(0.25),
                                         AppTheme.accentDeep.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(AppTheme.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(deck.name)
                        .font(AppTheme.heading(17))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: AppTheme.spacingM) {
                        Label("\(deck.cards.count) cards", systemImage: "card.fill")
                            .font(AppTheme.caption(12))
                            .foregroundColor(AppTheme.textSecondary)

                        if deck.dueCount > 0 {
                            Label("\(deck.dueCount) due", systemImage: "clock.fill")
                                .font(AppTheme.caption(12))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(AppTheme.spacingM)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Deck Detail View

struct DeckDetailView: View {
    let deck: Deck
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddCard = false
    @State private var cardToEdit: Card? = nil
    @State private var showingReview = false

    private var sortedCards: [Card] {
        deck.cards.sorted { $0.createdAt < $1.createdAt }
    }

    private var dueCards: [Card] {
        deck.cards.filter { $0.isDue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingL) {
                // Summary
                HStack(spacing: AppTheme.spacingM) {
                    summaryCard(title: "Due", value: "\(dueCards.count)", color: AppTheme.accent)
                    summaryCard(title: "Total", value: "\(deck.cards.count)", color: AppTheme.textPrimary)
                    summaryCard(title: "New", value: "\(deck.newCount)", color: AppTheme.info)
                }

                // Review button
                Button {
                    showingReview = true
                } label: {
                    HStack(spacing: AppTheme.spacingS) {
                        Image(systemName: "play.fill")
                        Text(dueCards.isEmpty ? "Review All Cards" : "Start Review")
                    }
                    .font(AppTheme.heading(16))
                    .frame(maxWidth: .infinity)
                    .violetAccentButton()
                }
                .buttonStyle(.plain)
                .disabled(deck.cards.isEmpty)

                // Cards
                VStack(spacing: AppTheme.spacingS) {
                    HStack {
                        Text("Cards")
                            .font(AppTheme.heading(18))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Button {
                            showingAddCard = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    .padding(.horizontal, 4)

                    if deck.cards.isEmpty {
                        VStack(spacing: AppTheme.spacingM) {
                            Image(systemName: "card.badge.plus")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(AppTheme.textTertiary)

                            Text("No cards yet")
                                .font(AppTheme.body(15))
                                .foregroundColor(AppTheme.textSecondary)

                            Button {
                                showingAddCard = true
                            } label: {
                                Text("Add Card")
                                    .font(AppTheme.caption(14))
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.spacingXL)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                    } else {
                        ForEach(sortedCards) { card in
                            CardRow(card: card) {
                                cardToEdit = card
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    modelContext.delete(card)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, AppTheme.spacingS)
            .padding(.bottom, AppTheme.spacingXL)
        }
        .primaryGradientBackground()
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddCard) {
            AddEditCardView(deck: deck)
        }
        .sheet(item: $cardToEdit) { card in
            AddEditCardView(deck: deck, card: card)
        }
        .fullScreenCover(isPresented: $showingReview) {
            ReviewView(deck: deck)
        }
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: AppTheme.spacingS) {
            Text(value)
                .font(AppTheme.title(28))
                .foregroundColor(color)
            Text(title)
                .font(AppTheme.caption(12))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.spacingM)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
    }
}

// MARK: - Card Row

struct CardRow: View {
    let card: Card
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.spacingM) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(card.front)
                        .font(AppTheme.body(15))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(card.back)
                        .font(AppTheme.caption(13))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    stateBadge
                    if card.isDue {
                        Text("Due")
                            .font(AppTheme.caption(10))
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
            .padding(AppTheme.spacingM)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var stateBadge: some View {
        let (text, color): (String, Color) = {
            switch card.state {
            case .new:         return ("New", AppTheme.textTertiary)
            case .learning:    return ("Learning", AppTheme.warning)
            case .review:      return ("Review", AppTheme.success)
            case .relearning:  return ("Relearning", AppTheme.danger)
            }
        }()
        Text(text)
            .font(AppTheme.caption(10))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}