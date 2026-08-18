import Foundation
import SwiftData

/// Parses an imported CSV file into `DeckFolder`, `Deck`, and `Card` records.
///
/// v1.3-fixes — Task 2: the parser now accepts a **configurable separator**
/// (Tab, `|`, `;`, `:`, `,` or space) instead of hard-coding `,`. A
/// `detectSeparator(_:)` helper heuristically picks the separator that
/// yields the most well-formed columns, used as the default selection in
/// the new `CSVSeparatorPickerSheet`.
///
/// v1.3-fixes — Task 4: the importer also reads an **optional 5th `tags`
/// column**. If present, tags are split on `;` within the cell (so a CSV
/// field `verb;irregular` produces two tags). 4-column files keep working
/// unchanged (tags default to empty).
///
/// CSV FORMAT (documented):
/// ──────────────────────────────────────────────────────────────────────────
/// Columns (in this order). The 5th `tags` column is optional:
///
///     folder,deck,front,back[,tags]
///
/// Rules:
///  • The first row MAY be a header. If it contains the words "folder",
///    "deck", "front", and "back" (case-insensitive) it is skipped.
///  • `folder` — optional. If non-empty, the deck is placed in a folder with
///    that name (created if it doesn't exist). A deck belongs to at most one
///    folder.
///  • `deck` — required. The deck name. Decks are matched by name within the
///    same folder, so repeated rows append cards to the same deck.
///  • `front` — the question text. Required for a card to be created.
///  • `back`  — the answer text.   Required for a card to be created.
///  • `tags`  — optional. Semicolon-separated list, e.g. `verb;irregular`.
///  • A row with `folder` + `deck` but empty `front`/`back` creates the deck
///    (and folder) without adding a card — useful for pre-creating structure.
///  • Fields containing the separator, double quotes, or line breaks MUST be
///    wrapped in double quotes. Embedded double quotes are escaped as `""`
///    (standard RFC 4180 quoting).
///
/// Example:
///   folder,deck,front,back,tags
///   Spanish,Vocab 1,hola,hello,greeting;common
///   Spanish,Vocab 1,"adios, gracias","goodbye, thanks",greeting
///   Spanish,Vocab 2,uno,one,number
///   ,Standalone,gato,cat,animal
/// ──────────────────────────────────────────────────────────────────────────
struct CSVImportService {
    static let shared = CSVImportService()

    /// Supported field separators (Task 2). Order matters: it is the order
    /// shown in the picker UI. `\t` is stored as a literal tab character.
    enum Separator: String, CaseIterable, Identifiable, Equatable {
        case tab = "\t"
        case pipe = "|"
        case semicolon = ";"
        case colon = ":"
        case comma = ","
        case space = " "

        var id: String { displayName }

        var displayName: String {
            switch self {
            case .tab:        return "Tab"
            case .pipe:       return "|"
            case .semicolon:  return ";"
            case .colon:      return ":"
            case .comma:      return ","
            case .space:      return "␣"
            }
        }

        /// Human label shown next to each option.
        var label: String {
            switch self {
            case .tab:        return "\\t (Tab)"
            case .pipe:       return "| (Pipe)"
            case .semicolon:  return "; (Semicolon)"
            case .colon:      return ": (Colon)"
            case .comma:      return ", (Comma)"
            case .space:      return "␣ (Space)"
            }
        }

        /// The raw `Character` used by the low-level parser.
        var character: Character {
            // `rawValue` is a single-character String for every case.
            return Character(rawValue)
        }
    }

    struct ImportResult {
        var foldersCreated: Int = 0
        var decksCreated: Int = 0
        var cardsCreated: Int = 0
        var errors: [String] = []
    }

    /// One parsed row exposed to the UI for the live preview (Task 2).
    /// `tags` is non-nil only when the source file has a 5th column.
    struct PreviewRow: Identifiable {
        let id = UUID()
        let folder: String
        let deck: String
        let front: String
        let back: String
        let tags: [String]
    }

    // MARK: - Import (with separator + optional tags column)

    @discardableResult
    func importCSV(from url: URL,
                   context: ModelContext,
                   separator: Separator = .comma) -> ImportResult {
        var result = ImportResult()

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8)
                  ?? String(data: data, encoding: .isoLatin1) else {
            result.errors.append("Could not read file.")
            return result
        }

        return importCSV(content: content, context: context, separator: separator)
    }

    /// Content-level importer (used both by the file-based path and by the
    /// preview sheet's "Importer" button, which already holds the decoded
    /// string).
    @discardableResult
    func importCSV(content: String,
                   context: ModelContext,
                   separator: Separator = .comma) -> ImportResult {
        var result = ImportResult()

        let rows = parseCSV(content, separator: separator.character)
        guard !rows.isEmpty else {
            result.errors.append("File is empty.")
            return result
        }

        // Detect & skip header. The header check is separator-agnostic: we
        // lower-case every field of the first row and look for the four
        // required names anywhere in it.
        var startIndex = 0
        let first = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        if first.contains(where: { $0 == "folder" }) &&
           first.contains(where: { $0 == "deck" }) &&
           first.contains(where: { $0 == "front" }) &&
           first.contains(where: { $0 == "back" }) {
            startIndex = 1
        }

        var folderCache: [String: DeckFolder] = [:]
        var deckCache: [String: Deck] = [:]

        if let existingFolders = try? context.fetch(FetchDescriptor<DeckFolder>()) {
            for f in existingFolders { folderCache[f.name.lowercased()] = f }
        }
        if let existingDecks = try? context.fetch(FetchDescriptor<Deck>()) {
            for d in existingDecks {
                let fk = d.folder?.name.lowercased() ?? ""
                deckCache["\(fk)\u{0000}\(d.name.lowercased())"] = d
            }
        }

        for i in startIndex..<rows.count {
            let row = rows[i]
            guard row.count >= 2 else { continue }

            let folderName = row[0].trimmingCharacters(in: .whitespaces)
            let deckName = row[1].trimmingCharacters(in: .whitespaces)
            let front = row.count > 2 ? row[2] : ""
            let back = row.count > 3 ? row[3] : ""
            // Task 4 — optional 5th tags column. Split on `;`.
            let tagsRaw = row.count > 4 ? row[4] : ""
            let tags: [String] = tagsRaw
                .split(separator: ";", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            guard !deckName.isEmpty else { continue }

            // Resolve or create folder
            var folder: DeckFolder? = nil
            if !folderName.isEmpty {
                let key = folderName.lowercased()
                if let existing = folderCache[key] {
                    folder = existing
                } else {
                    let f = DeckFolder(name: folderName)
                    context.insert(f)
                    folderCache[key] = f
                    folder = f
                    result.foldersCreated += 1
                }
            }

            // Resolve or create deck
            let folderKey = folder?.name.lowercased() ?? ""
            let deckKey = "\(folderKey)\u{0000}\(deckName.lowercased())"
            let deck: Deck
            if let existing = deckCache[deckKey] {
                deck = existing
            } else {
                let d = Deck(name: deckName, colorHex: "7C3AED", folder: folder)
                context.insert(d)
                deckCache[deckKey] = d
                deck = d
                result.decksCreated += 1
            }

            // Create card if both sides are non-empty
            let trimmedFront = front.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedBack = back.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedFront.isEmpty && !trimmedBack.isEmpty {
                let card = Card(front: trimmedFront, back: trimmedBack, deck: deck)
                if !tags.isEmpty { card.tags = tags }
                context.insert(card)
                result.cardsCreated += 1
            }
        }

        do {
            try context.save()
        } catch {
            result.errors.append("Save failed: \(error.localizedDescription)")
        }

        return result
    }

    // MARK: - Preview (Task 2)

    /// Parses the given content with the given separator and returns up to
    /// `maxRows` preview rows for the live UI. The header row (if any) is
    /// skipped, mirroring the importer's behavior.
    func preview(content: String, separator: Separator, maxRows: Int = 50) -> [PreviewRow] {
        let rows = parseCSV(content, separator: separator.character)
        guard !rows.isEmpty else { return [] }

        var startIndex = 0
        let first = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        if first.contains(where: { $0 == "folder" }) &&
           first.contains(where: { $0 == "deck" }) &&
           first.contains(where: { $0 == "front" }) &&
           first.contains(where: { $0 == "back" }) {
            startIndex = 1
        }

        var out: [PreviewRow] = []
        for i in startIndex..<min(startIndex + maxRows, rows.count) {
            let row = rows[i]
            guard row.count >= 2 else {
                out.append(PreviewRow(folder: "", deck: "", front: "", back: "", tags: []))
                continue
            }
            let folder = row[0].trimmingCharacters(in: .whitespaces)
            let deck = row[1].trimmingCharacters(in: .whitespaces)
            let front = row.count > 2 ? row[2] : ""
            let back = row.count > 3 ? row[3] : ""
            let tagsRaw = row.count > 4 ? row[4] : ""
            let tags = tagsRaw
                .split(separator: ";", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            out.append(PreviewRow(folder: folder, deck: deck, front: front, back: back, tags: tags))
        }
        return out
    }

    // MARK: - Separator auto-detection (Task 2)

    /// Heuristic: tries each candidate separator on the first non-empty
    /// line and returns the one that produces the most columns, with a
    /// preference for separators that yield >= 2 columns (i.e. an actual
    /// multi-column row). Ties are broken by the order in `Separator.allCases`
    /// (comma first, which is the most common default).
    func detectSeparator(_ content: String) -> Separator {
        // Use the first line that actually contains data.
        let firstLine = content
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map { String($0) }
            ?? ""

        guard !firstLine.isEmpty else { return .comma }

        var best: Separator = .comma
        var bestScore = 0
        for sep in Separator.allCases {
            // Skip space detection when the line has no other separator —
            // splitting on space is too noisy for short strings.
            if sep == .space { continue }
            let cols = splitLine(firstLine, separator: sep.character)
            let score = cols.count
            // Require at least 2 columns for a real candidate; otherwise
            // keep comma as the safe default.
            if score >= 2 && score > bestScore {
                bestScore = score
                best = sep
            }
        }
        return best
    }

    // MARK: - Parsing internals

    /// Minimal RFC-4180 CSV parser parameterized by a separator character.
    /// Handles quoted fields, escaped quotes (`""`), and embedded newlines
    /// inside quoted fields. The separator can be `,`, `;`, `|`, `:`, `\t`
    /// or ` ` (space).
    private func parseCSV(_ content: String, separator: Character) -> [[String]] {
        var rows: [[String]] = []
        var currentField = ""
        var currentRow: [String] = []
        var inQuotes = false
        var i = content.startIndex

        while i < content.endIndex {
            let ch = content[i]
            if inQuotes {
                if ch == "\"" {
                    let next = content.index(after: i)
                    if next < content.endIndex && content[next] == "\"" {
                        currentField.append("\"")
                        i = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(ch)
                }
            } else {
                switch ch {
                case "\"":
                    inQuotes = true
                case separator:
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                case "\r":
                    break
                default:
                    currentField.append(ch)
                }
            }
            i = content.index(after: i)
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }

    /// Splits a single line on the separator (no quote handling) — used by
    /// the auto-detect heuristic. Good enough for picking the default.
    private func splitLine(_ line: String, separator: Character) -> [String] {
        line.split(separator: separator, omittingEmptySubsequences: false)
            .map { String($0) }
    }
}
