import Foundation
import SwiftData

/// Parses an imported CSV file into `DeckFolder`, `Deck`, and `Card` records.
///
/// CSV FORMAT (documented):
/// ──────────────────────────────────────────────────────────────────────────
/// Columns (in this exact order):
///
///     folder,deck,front,back
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
///  • A row with `folder` + `deck` but empty `front`/`back` creates the deck
///    (and folder) without adding a card — useful for pre-creating structure.
///  • Fields containing commas, double quotes, or line breaks MUST be wrapped
///    in double quotes. Embedded double quotes are escaped as `""` (standard
///    RFC 4180 quoting).
///
/// Example:
///   folder,deck,front,back
///   Spanish,Vocab 1,hola,hello
///   Spanish,Vocab 1,"adios, gracias","goodbye, thanks"
///   Spanish,Vocab 2,uno,one
///   ,Standalone,gato,cat
/// ──────────────────────────────────────────────────────────────────────────
struct CSVImportService {
    static let shared = CSVImportService()

    struct ImportResult {
        var foldersCreated: Int = 0
        var decksCreated: Int = 0
        var cardsCreated: Int = 0
        var errors: [String] = []
    }

    @discardableResult
    func importCSV(from url: URL, context: ModelContext) -> ImportResult {
        var result = ImportResult()

        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8)
                  ?? String(data: data, encoding: .isoLatin1) else {
            result.errors.append("Could not read file.")
            return result
        }

        let rows = parseCSV(content)
        guard !rows.isEmpty else {
            result.errors.append("File is empty.")
            return result
        }

        // Detect & skip header
        var startIndex = 0
        let first = rows[0].map { $0.lowercased() }
        if first.contains("folder") && first.contains("deck")
           && first.contains("front") && first.contains("back") {
            startIndex = 1
        }

        // Caches keyed by lowercased name to de-duplicate
        var folderCache: [String: DeckFolder] = [:]
        var deckCache: [String: Deck] = [:]

        // Load existing folders/decks so imports are additive
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

    /// Minimal RFC-4180 CSV parser: handles quoted fields, escaped quotes (`""`),
    /// and embedded newlines inside quoted fields.
    private func parseCSV(_ content: String) -> [[String]] {
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
                case ",":
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
}