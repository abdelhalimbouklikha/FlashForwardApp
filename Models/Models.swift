import Foundation
import SwiftData
import SwiftUI

// MARK: - Enums

enum CardState: Int, Codable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

enum Rating: Int, Codable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    var label: String {
        switch self {
        case .again: return L("rating.again")
        case .hard:  return L("rating.hard")
        case .good:  return L("rating.good")
        case .easy:  return L("rating.easy")
        }
    }

    var color: Color {
        switch self {
        case .again: return AppTheme.againColor
        case .hard:  return AppTheme.hardColor
        case .good:  return AppTheme.goodColor
        case .easy:  return AppTheme.easyColor
        }
    }
}

// MARK: - DeckFolder

@Model
final class DeckFolder {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Deck.folder)
    var decks: [Deck] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }

    /// Total number of cards across all decks in this folder.
    var totalCards: Int {
        decks.reduce(0) { $0 + $1.cards.count }
    }

    /// Number of cards currently due across all decks in this folder.
    var dueCount: Int {
        decks.reduce(0) { $0 + $1.dueCount }
    }
}

// MARK: - Deck

@Model
final class Deck {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String = "7C3AED"
    var createdAt: Date
    var folder: DeckFolder?

    @Relationship(deleteRule: .cascade, inverse: \Card.deck)
    var cards: [Card] = []

    init(name: String, colorHex: String = "7C3AED", folder: DeckFolder? = nil) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.folder = folder
    }

    var dueCount: Int {
        cards.filter { $0.isDue }.count
    }

    var newCount: Int {
        cards.filter { $0.state == .new }.count
    }

    /// Resolves the deck's color, falling back to the current theme accent.
    var color: Color {
        Color(hex: colorHex) ?? AppTheme.accent
    }
}

// MARK: - Card

@Model
final class Card {
    @Attribute(.unique) var id: UUID
    var front: String
    var back: String
    var deck: Deck?
    var createdAt: Date

    /// Optional image attached to the question side. Stored externally so the
    /// SQLite row stays small.
    @Attribute(.externalStorage) var frontImageData: Data? = nil

    /// Optional image attached to the answer side.
    @Attribute(.externalStorage) var backImageData: Data? = nil

    // FSRS scheduling fields
    var stability: Double
    var difficulty: Double
    var reps: Int
    var lapses: Int
    var stateValue: Int
    var scheduledDays: Int
    var due: Date
    var lastReview: Date?

    var state: CardState {
        get { CardState(rawValue: stateValue) ?? .new }
        set { stateValue = newValue.rawValue }
    }

    var isDue: Bool {
        due <= Date()
    }

    init(front: String, back: String, deck: Deck? = nil) {
        self.id = UUID()
        self.front = front
        self.back = back
        self.deck = deck
        self.createdAt = Date()
        self.frontImageData = nil
        self.backImageData = nil
        self.stability = 0
        self.difficulty = 0
        self.reps = 0
        self.lapses = 0
        self.stateValue = CardState.new.rawValue
        self.scheduledDays = 0
        self.due = Date()
        self.lastReview = nil
    }
}

// MARK: - ReviewLog

@Model
final class ReviewLog {
    @Attribute(.unique) var id: UUID
    var card: Card?
    var ratingValue: Int
    var reviewTime: Date
    var stateBeforeValue: Int
    var stabilityBefore: Double
    var difficultyBefore: Double
    var elapsedDays: Int
    var scheduledDaysBefore: Int

    var rating: Rating {
        Rating(rawValue: ratingValue) ?? .good
    }

    var stateBefore: CardState {
        CardState(rawValue: stateBeforeValue) ?? .new
    }

    init(card: Card, rating: Rating, stateBefore: CardState,
         stabilityBefore: Double, difficultyBefore: Double,
         elapsedDays: Int, scheduledDaysBefore: Int) {
        self.id = UUID()
        self.card = card
        self.ratingValue = rating.rawValue
        self.reviewTime = Date()
        self.stateBeforeValue = stateBefore.rawValue
        self.stabilityBefore = stabilityBefore
        self.difficultyBefore = difficultyBefore
        self.elapsedDays = elapsedDays
        self.scheduledDaysBefore = scheduledDaysBefore
    }
}
