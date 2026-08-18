import SwiftUI
import SwiftData
import UIKit

struct CardsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var settings: AppSettings

    @Query var cards: [Card]
    @Query(sort: [SortDescriptor(\Deck.name)]) var decks: [Deck]
    @Query(sort: [SortDescriptor(\DeckFolder.name)]) var folders: [DeckFolder]

    enum Filter: String, CaseIterable, Identifiable {
        case all, studied, notStudied, newlyAdded
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all:        return L("cards.filter.all")
            case .studied:    return L("cards.filter.studied")
            case .notStudied: return L("cards.filter.notStudied")
            case .newlyAdded: return L("cards.filter.new")
            }
        }
    }

    enum Scope: Equatable {
        case all
        case folder(UUID)
        case deck(UUID)
    }

    @State private var searchText: String = ""
    @State private var filter: Filter = .all
    @State private var scope: Scope = .all
    @State private var cardToEdit: Card? = nil

    // v1.3 — Task 4. Tag filter. `nil` means "no tag filter".
    @State private var tagFilter: String? = nil

    /// Every tag present across all cards, sorted — drives the tag-filter
    /// chip bar. Computed from the live `@Query var cards`, so it updates
    /// automatically when cards are edited.
    private var allTags: [String] {
        let all = cards.flatMap { $0.tags }
        return Array(Set(all)).sorted()
    }

    private var filteredCards: [Card] {
        cards.filter { card in
            // Status filter
            switch filter {
            case .all: break
            case .studied:
                guard card.reps > 0 else { return false }
            case .notStudied:
                guard card.reps == 0 else { return false }
            case .newlyAdded:
                guard card.state == .new else { return false }
            }

            // Scope filter (deck or folder)
            switch scope {
            case .all: break
            case .folder(let id):
                guard card.deck?.folder?.id == id else { return false }
            case .deck(let id):
                guard card.deck?.id == id else { return false }
            }

            // v1.3 — Task 4. Tag filter.
            if let tag = tagFilter {
                guard card.tags.contains(tag) else { return false }
            }

            // Text search
            if !searchText.isEmpty {
                let q = searchText.lowercased()
                let frontMatch = card.front.lowercased().contains(q)
                let backMatch = card.back.lowercased().contains(q)
                let deckMatch = card.deck?.name.lowercased().contains(q) ?? false
                let folderMatch = card.deck?.folder?.name.lowercased().contains(q) ?? false
                let tagMatch = card.tags.contains { $0.lowercased().contains(q) }
                guard frontMatch || backMatch || deckMatch || folderMatch || tagMatch else { return false }
            }

            return true
        }
    }

    private var scopeLabel: String {
        switch scope {
        case .all: return L("cards.allDecks")
        case .folder(let id): return folders.first { $0.id == id }?.name ?? ""
        case .deck(let id): return decks.first { $0.id == id }?.name ?? ""
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: AppTheme.spacingS) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.textTertiary)
                    TextField(L("cards.search"), text: $searchText)
                        .font(AppTheme.body(16))
                        .foregroundColor(AppTheme.textPrimary)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.vertical, AppTheme.spacingS)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                            style: .continuous))
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)

                // Filter buttons
                Picker("", selection: $filter) {
                    ForEach(Filter.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)

                // Scope picker
                Menu {
                    Button { scope = .all } label: {
                        Label(L("cards.allDecks"), systemImage: "tray.full.fill")
                    }
                    if !folders.isEmpty {
                        Section(L("cards.allFolders")) {
                            ForEach(folders) { folder in
                                Button { scope = .folder(folder.id) } label: {
                                    Label(folder.name, systemImage: "folder")
                                }
                            }
                        }
                    }
                    Section(L("cards.allDecks")) {
                        ForEach(decks) { deck in
                            Button { scope = .deck(deck.id) } label: {
                                HStack {
                                    Text(deck.name)
                                    if scope == .deck(deck.id) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: AppTheme.spacingS) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 15))
                        Text(scopeLabel)
                            .font(AppTheme.caption(14))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.vertical, AppTheme.spacingS)
                    .background(AppTheme.surface)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)

                // v1.3 — Task 4. Tag filter chip bar. Only shown when there
                // are tags somewhere in the database. Tapping a chip
                // toggles the filter; the "All" chip clears it.
                if !allTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppTheme.spacingS) {
                            tagChipButton(title: L("cards.tags.all"),
                                          isSelected: tagFilter == nil) {
                                tagFilter = nil
                            }
                            ForEach(allTags, id: \.self) { tag in
                                tagChipButton(title: "#\(tag)",
                                              isSelected: tagFilter == tag) {
                                    tagFilter = (tagFilter == tag) ? nil : tag
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.spacingM)
                        .padding(.vertical, AppTheme.spacingS)
                    }
                }

                // Card list
                if filteredCards.isEmpty {
                    Spacer()
                    VStack(spacing: AppTheme.spacingM) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(AppTheme.textTertiary)
                        Text(L("cards.empty"))
                            .font(AppTheme.body(15))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredCards) { card in
                            Button { cardToEdit = card } label: {
                                CardSearchRow(card: card)
                            }
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16,
                                                      bottom: 5, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.top, AppTheme.spacingS)
                }
            }
            .primaryGradientBackground()
            .navigationTitle(L("tab.cards"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $cardToEdit) { card in
                if let deck = card.deck {
                    AddEditCardView(deck: deck, card: card)
                }
            }
        }
    }
}

// MARK: - Card Search Row

struct CardSearchRow: View {
    let card: Card

    var body: some View {
        HStack(spacing: AppTheme.spacingM) {
            if let data = card.frontImageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(card.front)
                    .font(AppTheme.body(15))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)
                Text(card.back)
                    .font(AppTheme.caption(12))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                if let deck = card.deck {
                    HStack(spacing: 4) {
                        Circle().fill(deck.color).frame(width: 7, height: 7)
                        Text(deck.folder?.name != nil
                             ? "\(deck.folder!.name) / \(deck.name)"
                             : deck.name)
                            .font(AppTheme.caption(11))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
                // v1.3 — Task 4. Show tags on the card row.
                if !card.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(card.tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(AppTheme.caption(9))
                                .foregroundColor(AppTheme.info)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(AppTheme.info.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        if card.tags.count > 3 {
                            Text("+\(card.tags.count - 3)")
                                .font(AppTheme.caption(9))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                }
            }

            Spacer()

            stateBadge
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
    }

    @ViewBuilder
    private var stateBadge: some View {
        let (text, color): (String, Color) = {
            switch card.state {
            case .new:         return (L("state.new"), AppTheme.textTertiary)
            case .learning:    return (L("state.learning"), AppTheme.warning)
            case .review:      return (L("state.review"), AppTheme.success)
            case .relearning:  return (L("state.relearning"), AppTheme.danger)
            }
        }()
        Text(text)
            .font(AppTheme.caption(9))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Tag chip button (used in the Cards tab filter bar — Task 4)

extension CardsView {
    /// A small reusable chip used in the global tag-filter bar. Defined as a
    /// private method on `CardsView` to avoid extending the `View` protocol.
    @ViewBuilder
    fileprivate func tagChipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.caption(12))
                .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                .padding(.horizontal, AppTheme.spacingS)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? AnyShapeStyle(LinearGradient(
                                  colors: [AppTheme.accent, AppTheme.accentSecondary],
                                  startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(AppTheme.surface))
                )
        }
        .buttonStyle(.plain)
    }
}
