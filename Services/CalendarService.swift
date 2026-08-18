import Foundation
import EventKit
import UserNotifications
import os

/// Wrapper around EventKit for requesting calendar access and creating
/// revision events. Used by the "Schedule Revision" flow on decks.
///
/// All features here work with a free Apple developer account:
///   • EventKit calendar access — free
///   • EKAlarm (event-level alarm that fires a notification at the event
///     start time) — free, no APNs push needed
///   • UNUserNotificationCenter local notifications — free
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
            AppLog.calendar.error("Calendar access error: \(error.localizedDescription, privacy: .public)")
            return .denied
        }
    }

    /// Creates a calendar event for reviewing the given deck, starting at
    /// `date` and lasting `durationMinutes` (default 30). When `withAlarm`
    /// is true (default), an `EKAlarm` is attached with an absolute trigger
    /// at the event start, so the user receives a local notification at
    /// that moment — no push server required.
    @discardableResult
    func createRevisionEvent(for deck: Deck,
                             at date: Date,
                             durationMinutes: Int = 30,
                             withAlarm: Bool = true) -> Bool {
        guard let calendar = store.defaultCalendarForNewEvents else {
            AppLog.calendar.notice("No default calendar available")
            return false
        }

        let event = EKEvent(eventStore: store)
        event.title = "FlashForward: \(deck.name)"
        event.startDate = date
        event.endDate = date.addingTimeInterval(TimeInterval(durationMinutes * 60))
        event.notes = String(format: L("schedule.event.notes"),
                             deck.cards.count, deck.name)
        event.calendar = calendar

        if withAlarm {
            // Absolute alarm: fires exactly at event start. Works offline,
            // no remote push required.
            let alarm = EKAlarm(absoluteDate: date)
            event.addAlarm(alarm)
        }

        do {
            try store.save(event, span: .thisEvent)
            return true
        } catch {
            AppLog.calendar.error("Failed to create calendar event: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Schedules an additional local notification via UNUserNotificationCenter
    /// at the same time, as a belt-and-braces reminder. Local notifications
    /// are fully supported on a free Apple account (they do not require APNs).
    /// Returns true if scheduling succeeded.
    @discardableResult
    func scheduleLocalReminder(for deck: Deck, at date: Date) -> Bool {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "FlashForward"
        content.body = String(format: L("schedule.notification.body"), deck.name)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                          from: date),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "flashforward-\(deck.id.uuidString)-\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        // We use the completion-based API so it works on iOS 17+.
        var success = false
        let semaphore = DispatchSemaphore(value: 0)
        center.add(request) { error in
            if let error = error {
                AppLog.calendar.error("Failed to schedule local notification: \(error.localizedDescription, privacy: .public)")
            } else {
                success = true
            }
            semaphore.signal()
        }
        semaphore.wait()
        return success
    }

    /// Requests notification authorization (alert + sound). Safe to call
    /// repeatedly — iOS only prompts the user once.
    func requestNotificationAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }
}
