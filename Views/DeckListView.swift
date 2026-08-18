import SwiftUI
import SwiftData
import UniformTypeIdentifiers
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Deck.createdAt, order: .reverse)]) var decks: [Deck]
    @Query(sort: [SortDescriptor(\DeckFolder.name)]) var folders: [DeckFolder]

    @State private var showingAddDeck = false
    @State private var deckToRename: Deck? = nil
    @State private var deckToDelete: Deck? = nil
    @State private var showingDeleteConfirm = false
    @State private var selectedDeck: Deck? = nil

    // CSV import / export
    @State private var showingCSVImporter = false
    @State private var csvImportResult: CSVImportService.ImportResult? = nil
    @State private var csvExportURL: URL? = nil
    @State private var deckToSchedule: Deck? = nil

    // Folders
    @State private var showingFolderList = false

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    EmptyStateView(
                        icon: "rectangle.stack.badge.plus",
                        title: L("decks.empty.title"),
                        message: L("decks.empty.message"),
                        actionTitle: L("decks.create"),
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
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showingCSVImporter = true
                        } label: {
                            Label(L("decks.importCSV"), systemImage: "tray.and.arrow.down.fill")
                        }
                        Button {
                            exportAllDecks()
                        } label: {
                            Label(L("decks.exportAll"), systemImage: "tray.and.arrow.up.fill")
                        }
                        .disabled(decks.isEmpty)
                        Divider()
                        Button {
                            showingFolderList = true
                        } label: {
                            Label(L("decks.manageFolders"), systemImage: "folder.badge.gear")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
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
            .sheet(isPresented: $showingFolderList) {
                FolderListView()
            }
            .sheet(isPresented: $showingCSVImporter) {
                DocumentPicker(allowedTypes: [UTType.commaSeparatedText, UTType.text, UTType.data]) { url in
                    importCSV(url: url)
                }
            }
            .sheet(item: $csvExportURL) { url in
                ShareSheet(items: [url])
            }
            .sheet(item: $deckToSchedule) { deck in
                ScheduleRevisionView(deck: deck)
            }
            .sheet(item: $deckToRename) { deck in
                AddEditDeckView(deck: deck)
            }
            .navigationDestination(item: $selectedDeck) { deck in
                DeckDetailView(deck: deck)
            }
            .alert(L("import.result.title"), isPresented: Binding(
                get: { csvImportResult != nil },
                set: { if !$0 { csvImportResult = nil } }
            )) {
                Button(L("common.ok"), role: .cancel) { csvImportResult = nil }
            } message: {
                if let r = csvImportResult {
                    if r.errors.isEmpty {
                        Text(String(format: L("import.result.message"),
                                    r.foldersCreated, r.decksCreated, r.cardsCreated))
                    } else {
                        Text(r.errors.joined(separator: "\n"))
                    }
                }
            }
            .alert(L("decks.delete.title"), isPresented: $showingDeleteConfirm) {
                Button(L("common.cancel"), role: .cancel) {
                    deckToDelete = nil
                }
                Button(L("common.delete"), role: .destructive) {
                    if let deck = deckToDelete {
                        modelContext.delete(deck)
                        deckToDelete = nil
                    }
                }
            } message: {
                if let deck = deckToDelete {
                    Text(String(format: L("decks.delete.message"),
                                deck.name, deck.cards.count))
                }
            }
        }
    }

    private var deckList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.spacingM) {
                // Group decks by folder (un-grouped decks at the top).
                let ungrouped = decks.filter { $0.folder == nil }
                let grouped = Dictionary(grouping: decks.filter { $0.folder != nil },
                                         by: { $0.folder! })

                if !ungrouped.isEmpty {
                    ForEach(ungrouped) { deck in
                        DeckRow(deck: deck) { selectedDeck = deck }
                            .contextMenu { deckContextMenu(for: deck) }
                    }
                }

                ForEach(folders.sorted(by: { $0.name < $1.name }), id: \.id) { folder in
                    let folderDecks = grouped[folder] ?? []
                    if !folderDecks.isEmpty {
                        Section {
                            ForEach(folderDecks.sorted(by: { $0.createdAt > $1.createdAt })) { deck in
                                DeckRow(deck: deck) { selectedDeck = deck }
                                    .contextMenu { deckContextMenu(for: deck) }
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.accent)
                                Text(folder.name)
                                    .font(AppTheme.heading(13))
                                    .foregroundColor(AppTheme.textSecondary)
                                Spacer()
                                Text("\(folderDecks.count)")
                                    .font(AppTheme.caption(11))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, AppTheme.spacingM)
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, AppTheme.spacingS)
            .padding(.bottom, AppTheme.spacingXL)
        }
    }

    @ViewBuilder
    private func deckContextMenu(for deck: Deck) -> some View {
        Button {
            deckToRename = deck
        } label: {
            Label(L("common.rename"), systemImage: "pencil")
        }
        Button {
            exportSingleDeck(deck)
        } label: {
            Label(L("decks.export"), systemImage: "tray.and.arrow.up")
        }
        Button {
            deckToSchedule = deck
        } label: {
            Label(L("decks.schedule"), systemImage: "calendar")
        }
        Divider()
        Button(role: .destructive) {
            deckToDelete = deck
            showingDeleteConfirm = true
        } label: {
            Label(L("common.delete"), systemImage: "trash")
        }
    }

    // MARK: - Actions

    private func importCSV(url: URL) {
        let result = CSVImportService.shared.importCSV(from: url, context: modelContext)
        csvImportResult = result
    }

    private func exportSingleDeck(_ deck: Deck) {
        let csv = CSVExportService.shared.export(decks: [deck])
        let safeName = deck.name.replacingOccurrences(of: "/", with: "-")
        do {
            csvExportURL = try CSVExportService.shared.writeTemporaryFile(
                csv: csv, filename: "\(safeName).csv")
        } catch {
            print("Export failed: \(error)")
        }
    }

    private func exportAllDecks() {
        let csv = CSVExportService.shared.export(decks: decks)
        do {
            csvExportURL = try CSVExportService.shared.writeTemporaryFile(
                csv: csv, filename: "FlashForwardExport.csv")
        } catch {
            print("Export failed: \(error)")
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
                                colors: [deck.color.opacity(0.25),
                                         deck.color.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: "rectangle.stack.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(deck.color)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(deck.name)
                        .font(AppTheme.heading(17))
                        .foregroundColor(AppTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: AppTheme.spacingM) {
                        Label(String(format: L("decks.cards.count"), deck.cards.count),
                              systemImage: "card.fill")
                            .font(AppTheme.caption(12))
                            .foregroundColor(AppTheme.textSecondary)

                        if deck.dueCount > 0 {
                            Label(String(format: L("decks.due.count"), deck.dueCount),
                                  systemImage: "clock.fill")
                                .font(AppTheme.caption(12))
                                .foregroundColor(deck.color)
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
    @State private var showingSchedule = false
    @State private var csvExportURL: URL? = nil

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
                    summaryCard(title: L("detail.due"), value: "\(dueCards.count)", color: deck.color)
                    summaryCard(title: L("detail.total"), value: "\(deck.cards.count)", color: AppTheme.textPrimary)
                    summaryCard(title: L("detail.new"), value: "\(deck.newCount)", color: AppTheme.info)
                }

                // Review button
                Button {
                    showingReview = true
                } label: {
                    HStack(spacing: AppTheme.spacingS) {
                        Image(systemName: "play.fill")
                        Text(dueCards.isEmpty ? L("detail.reviewAll") : L("detail.startReview"))
                    }
                    .font(AppTheme.heading(16))
                    .frame(maxWidth: .infinity)
                    .violetAccentButton()
                }
                .buttonStyle(.plain)
                .disabled(deck.cards.isEmpty)

                // Secondary actions row: Schedule, Export
                HStack(spacing: AppTheme.spacingM) {
                    Button {
                        showingSchedule = true
                    } label: {
                        Label(L("decks.schedule"), systemImage: "calendar")
                            .font(AppTheme.caption(14))
                            .foregroundColor(deck.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.spacingS)
                            .background(deck.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                       style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        exportSingleDeck()
                    } label: {
                        Label(L("decks.export"), systemImage: "tray.and.arrow.up")
                            .font(AppTheme.caption(14))
                            .foregroundColor(deck.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.spacingS)
                            .background(deck.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                       style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(deck.cards.isEmpty)
                }

                // Cards
                VStack(spacing: AppTheme.spacingS) {
                    HStack {
                        Text(L("detail.cards"))
                            .font(AppTheme.heading(18))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Button {
                            showingAddCard = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(deck.color)
                        }
                    }
                    .padding(.horizontal, 4)

                    if deck.cards.isEmpty {
                        VStack(spacing: AppTheme.spacingM) {
                            Image(systemName: "card.badge.plus")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(AppTheme.textTertiary)

                            Text(L("detail.noCards"))
                                .font(AppTheme.body(15))
                                .foregroundColor(AppTheme.textSecondary)

                            Button {
                                showingAddCard = true
                            } label: {
                                Text(L("detail.addCard"))
                                    .font(AppTheme.caption(14))
                                    .foregroundColor(deck.color)
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
                                    Label(L("common.delete"), systemImage: "trash")
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
        .sheet(isPresented: $showingSchedule) {
            ScheduleRevisionView(deck: deck)
        }
        .sheet(item: $csvExportURL) { url in
            ShareSheet(items: [url])
        }
        .fullScreenCover(isPresented: $showingReview) {
            ReviewView(deck: deck)
        }
    }

    private func exportSingleDeck() {
        let safeName = deck.name.replacingOccurrences(of: "/", with: "-")
        let csv = CSVExportService.shared.export(decks: [deck])
        do {
            csvExportURL = try CSVExportService.shared.writeTemporaryFile(
                csv: csv, filename: "\(safeName).csv")
        } catch {
            print("Export failed: \(error)")
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
                        Text(L("state.due"))
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
            case .new:         return (L("state.new"), AppTheme.textTertiary)
            case .learning:    return (L("state.learning"), AppTheme.warning)
            case .review:      return (L("state.review"), AppTheme.success)
            case .relearning:  return (L("state.relearning"), AppTheme.danger)
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


