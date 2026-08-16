import Foundation
import EventKit

/// Wrapper around EventKit for requesting calendar access and creating
/// revision events. Used by the "Schedule Revision" swipe action on decks.
enum CalendarAccessStatus {
    case notDetermined
    case granted
    case denied
    case restricted
}

final class CalendarService {
    static let shared = CalendarService()
    private let store = EKEventStore()

    /// Requests full calendar access. Returns the resulting status.
    /// On iOS 17+ uses `requestFullAccessToEvents()`.
    func requestAccess() async -> CalendarAccessStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess, .writeOnly:
            return .granted
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            break
        @unknown default:
            break
        }

        do {
            let granted = try await store.requestFullAccessToEvents()
            return granted ? .granted : .denied
        } catch {
            print("Calendar access error: \(error)")
            return .denied
        }
    }

    /// Creates a 30-minute calendar event for reviewing the given deck.
    /// Returns `true` on success.
    @discardableResult
    func createRevisionEvent(for deck: Deck, at date: Date) -> Bool {
        guard let calendar = store.defaultCalendarForNewEvents else {
            print("No default calendar available")
            return false
        }

        let event = EKEvent(eventStore: store)
        event.title = "FlashForward: \(deck.name)"
        event.startDate = date
        event.endDate = date.addingTimeInterval(1800) // 30 minutes
        event.notes = "Review \(deck.cards.count) cards in \(deck.name)"
        event.calendar = calendar

        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            print("Failed to create calendar event: \(error)")
            return false
        }
    }
}