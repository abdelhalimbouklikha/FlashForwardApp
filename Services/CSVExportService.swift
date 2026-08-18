import Foundation
import SwiftData

/// Inverse of `CSVImportService` — serializes decks and/or folders into the
/// same `folder,deck,front,back` CSV format.
///
/// v1.3-fixes — Task 4: a 5th `tags` column is now emitted. Tags within a
/// cell are joined by `;` (the importer splits on `;`). Decks/cards without
/// tags emit an empty 5th cell, so the file round-trips losslessly.
///
/// Usage:
///   • `export(decks:)` — export a flat list of decks
///   • `export(folders:)` — export entire folders (all their decks)
///   • `exportAll(context:)` — export everything in the store
///
/// The result is a UTF-8 CSV string that can be written to a temporary file
/// and shared via `UIActivityViewController` (see `ShareSheet.swift`).
struct CSVExportService {
    static let shared = CSVExportService()

    /// Exports the given decks. Cards in each deck are emitted in creation
    /// order. The `folder` column is filled when the deck belongs to a folder.
    /// A 5th `tags` column (semicolon-separated) is emitted when the card has
    /// tags; otherwise the cell is empty.
    func export(decks: [Deck]) -> String {
        var rows: [[String]] = []
        rows.append(["folder", "deck", "front", "back", "tags"])

        for deck in decks.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let folderName = deck.folder?.name ?? ""
            let sortedCards = deck.cards.sorted { $0.createdAt < $1.createdAt }

            if sortedCards.isEmpty {
                // Emit a single row to preserve the deck structure even when
                // it has no cards (mirrors CSVImportService's behavior).
                rows.append([folderName, deck.name, "", "", ""])
            } else {
                for card in sortedCards {
                    let tagsCell = card.tags.joined(separator: ";")
                    rows.append([folderName, deck.name, card.front, card.back, tagsCell])
                }
            }
        }

        return encode(rows)
    }

    /// Exports every deck that belongs to the given folders (preserving the
    /// folder column).
    func export(folders: [DeckFolder]) -> String {
        let decks = folders.flatMap { $0.decks }
        return export(decks: decks)
    }

    /// Exports the entire database (all folders, all standalone decks).
    func exportAll(context: ModelContext) -> String {
        let allDecks = (try? context.fetch(FetchDescriptor<Deck>())) ?? []
        return export(decks: allDecks)
    }

    /// RFC-4180 encoder: wraps any field containing comma, quote, or newline
    /// in double quotes, and escapes embedded quotes by doubling them.
    private func encode(_ rows: [[String]]) -> String {
        var output = ""
        for row in rows {
            let escaped = row.map { field -> String in
                let needsQuoting = field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r")
                if needsQuoting {
                    let escapedQuotes = field.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escapedQuotes)\""
                }
                return field
            }
            output.append(escaped.joined(separator: ","))
            output.append("\n")
        }
        return output
    }

    /// Writes the given CSV string to a temporary file and returns its URL.
    /// The caller is responsible for sharing (and optionally deleting) it.
    func writeTemporaryFile(csv: String, filename: String = "FlashForwardExport.csv") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.data(using: .utf8)?.write(to: url)
        return url
    }
}
