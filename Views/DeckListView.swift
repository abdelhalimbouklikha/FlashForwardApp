import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import os
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

    // v1.3 — Task 2. CSV separator selection sheet. After the user picks a
    // file, we decode its content once and hold it here; the
    // `CSVSeparatorPickerSheet` re-parses this string live as the user
    // tries different separators (no file re-reads).
    @State private var csvPendingContent: String? = nil
    @State private var showingCSVSeparatorSheet: Bool = false

    // v1.3 — Task 7. "Reset" deck action state.
    @State private var deckToReset: Deck? = nil
    @State private var showingResetConfirm: Bool = false

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
                    loadCSVContent(url: url)
                }
            }
            // v1.3 — Task 2. Separator selection sheet with live preview.
            .sheet(isPresented: $showingCSVSeparatorSheet) {
                if let content = csvPendingContent {
                    CSVSeparatorPickerSheet(content: content) { separator in
                        performCSVImport(separator: separator)
                    }
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
            // v1.3 — Task 7. Reset confirmation.
            .alert(L("decks.reset.title"), isPresented: $showingResetConfirm) {
                Button(L("common.cancel"), role: .cancel) {
                    deckToReset = nil
                }
                Button(L("decks.reset.action"), role: .destructive) {
                    if let deck = deckToReset {
                        resetDeck(deck)
                    }
                }
            } message: {
                if let deck = deckToReset {
                    Text(String(format: L("decks.reset.message"),
                                deck.name, deck.cards.count))
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
        // v1.3 — Task 7. "Reset" option only for decks that have at least
        // one card reviewed and scheduled in the future (i.e. currently
        // hidden from the review queue). Decks that are fully due / new
        // don't need a reset.
        if deck.hasFutureScheduledCards {
            Divider()
            Button {
                deckToReset = deck
                showingResetConfirm = true
            } label: {
                Label(L("decks.reset"), systemImage: "arrow.uturn.left.circle")
            }
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

    /// v1.3 — Task 2. Reads the picked file into a String and hands it to
    /// the separator-selection sheet. The actual import is deferred until
    /// the user confirms a separator.
    private func loadCSVContent(url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8)
                  ?? String(data: data, encoding: .isoLatin1) else {
            var r = CSVImportService.ImportResult()
            r.errors.append(L("csv.separator.readError"))
            csvImportResult = r
            return
        }
        csvPendingContent = content
        showingCSVSeparatorSheet = true
    }

    /// v1.3 — Task 2. Performs the import with the user-selected separator.
    private func performCSVImport(separator: CSVImportService.Separator) {
        guard let content = csvPendingContent else { return }
        let result = CSVImportService.shared.importCSV(
            content: content, context: modelContext, separator: separator)
        csvImportResult = result
        csvPendingContent = nil
    }

    /// v1.3 — Task 7. Resets every card in the deck to the initial "new"
    /// scheduling state (due now, FSRS history cleared). Content, tags and
    /// images are preserved.
    private func resetDeck(_ deck: Deck) {
        deck.resetAllCardsScheduling()
        do {
            try modelContext.save()
        } catch {
            // Defensive: never crash the app on a save failure — surface
            // the error to the import-result alert channel instead.
            var r = CSVImportService.ImportResult()
            r.errors.append(L("decks.reset.failed"))
            csvImportResult = r
        }
        deckToReset = nil
    }

    private func exportSingleDeck(_ deck: Deck) {
        let csv = CSVExportService.shared.export(decks: [deck])
        let safeName = deck.name.replacingOccurrences(of: "/", with: "-")
        do {
            csvExportURL = try CSVExportService.shared.writeTemporaryFile(
                csv: csv, filename: "\(safeName).csv")
        } catch {
            AppLog.decks.error("Export failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func exportAllDecks() {
        let csv = CSVExportService.shared.export(decks: decks)
        do {
            csvExportURL = try CSVExportService.shared.writeTemporaryFile(
                csv: csv, filename: "FlashForwardExport.csv")
        } catch {
            AppLog.decks.error("Export failed: \(error.localizedDescription, privacy: .public)")
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

    // v1.3 — Task 4. Tag filter for this deck's card list + review session.
    @State private var tagFilter: String? = nil

    /// Every tag present across this deck's cards, sorted — drives the
    /// deck-local tag-filter chip bar.
    private var deckTags: [String] {
        Array(Set(deck.cards.flatMap { $0.tags })).sorted()
    }

    private var sortedCards: [Card] {
        let base = deck.cards.sorted { $0.createdAt < $1.createdAt }
        guard let tag = tagFilter else { return base }
        return base.filter { $0.tags.contains(tag) }
    }

    private var dueCards: [Card] {
        let base = deck.cards.filter { $0.isDue }
        guard let tag = tagFilter else { return base }
        return base.filter { $0.tags.contains(tag) }
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

                    // v1.3 — Task 4. Deck-local tag filter chip bar. Only
                    // shown when the deck has at least one tag.
                    if !deckTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: AppTheme.spacingS) {
                                deckTagChip(title: L("cards.tags.all"),
                                            isSelected: tagFilter == nil) {
                                    tagFilter = nil
                                }
                                ForEach(deckTags, id: \.self) { tag in
                                    deckTagChip(title: "#\(tag)",
                                                isSelected: tagFilter == tag) {
                                        tagFilter = (tagFilter == tag) ? nil : tag
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }

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
        // v1.3 — Task 4. Pass the active tag filter into the review
        // session so only tagged cards are queued.
        .fullScreenCover(isPresented: $showingReview) {
            ReviewView(deck: deck, tagFilter: tagFilter)
        }
    }

    /// Small reusable chip used in the deck-local tag filter bar (Task 4).
    private func deckTagChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
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
                                  colors: [deck.color, deck.color.opacity(0.8)],
                                  startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(AppTheme.surface))
                )
        }
        .buttonStyle(.plain)
    }

    private func exportSingleDeck() {
        let safeName = deck.name.replacingOccurrences(of: "/", with: "-")
        let csv = CSVExportService.shared.export(decks: [deck])
        do {
            csvExportURL = try CSVExportService.shared.writeTemporaryFile(
                csv: csv, filename: "\(safeName).csv")
        } catch {
            AppLog.decks.error("Export failed: \(error.localizedDescription, privacy: .public)")
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


