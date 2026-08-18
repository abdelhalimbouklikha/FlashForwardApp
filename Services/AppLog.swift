import Foundation
import os

/// v1.3-fixes — Task 8 (Audit). Centralized logger so the codebase never
/// uses bare `print(...)` for diagnostics (those leak into the Console app
/// with no subsystem/category and are easy to forget). Replacing every
/// `print("...")` call site with `AppLog.<level>("...")` gives:
///   • Structured logs (subsystem = bundle id, category = the file/topic)
///   • Levels that respect the OS log filtering (debug logs don't ship in
///     Release unless explicitly collected).
///   • A single place to turn off diagnostics for production builds.
enum AppLog {
    /// Subsystem = the app's bundle identifier (falls back to a literal if
    /// the bundle id isn't available, e.g. in tests).
    private static let subsystem: String =
        Bundle.main.bundleIdentifier ?? "com.abdelhalim.FlashForwardApp"

    /// A shared `os.Logger` for general, non-categorized diagnostics.
    static let general = Logger(subsystem: subsystem, category: "general")
    /// Category loggers — pick the one that matches the call site.
    static let csv       = Logger(subsystem: subsystem, category: "csv")
    static let stats     = Logger(subsystem: subsystem, category: "stats")
    static let review    = Logger(subsystem: subsystem, category: "review")
    static let cards     = Logger(subsystem: subsystem, category: "cards")
    static let decks     = Logger(subsystem: subsystem, category: "decks")
    static let settings  = Logger(subsystem: subsystem, category: "settings")
    static let calendar  = Logger(subsystem: subsystem, category: "calendar")
    static let folders   = Logger(subsystem: subsystem, category: "folders")
    static let image     = Logger(subsystem: subsystem, category: "image")
}
