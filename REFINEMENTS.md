# FlashForwardApp — Refinement Summary

This document lists every change made to the project, mapped to the eight
features requested in the refinement brief.

## Tech stack constraints (respected)
- iOS 17+, SwiftUI + SwiftData only.
- First-party Apple frameworks only: `SwiftUI`, `SwiftData`, `EventKit`,
  `PhotosUI`, `UniformTypeIdentifiers`, `UIKit`, `UserNotifications`.
- No paid Apple developer account required.
- Project still built via Codemagic (XcodeGen + `project.yml`).
- New permission keys added to `project.yml` (calendar, photos, notifications).

---

## Feature 1 — Global language switch (EN / FR)

**What changed**
- Split the `Localizable.strings` file: the original had both English and
  French strings in `Views/en.lproj/Localizable.strings` (a bug). Now:
    - `Views/en.lproj/Localizable.strings` — English only
    - `Views/fr.lproj/Localizable.strings` — French only (new file)
- Localized **every** previously-hardcoded English string in:
    - `DeckListView`, `DeckDetailView`, `CardRow` ("No Decks Yet",
      "Rename", "Delete", "Due", "Total", "New", "Cards", etc.)
    - `StatsView` ("Statistics", "Due Today", "Review Performance",
      "Retention", "Recent Activity", ...)
    - All new screens (`FolderListView`, `ScheduleRevisionView`,
      `FullscreenImageViewer`, `ShareSheet`, `SettingsView` intervals).
- The existing `Localization` + `L("key")` mechanism was already correct;
  the problem was incomplete coverage. That is now fixed.
- Added `.environment(\.locale, Locale(identifier: settings.language))`
  on the root view so system formatters (dates, numbers) follow the chosen
  language too.
- Added a note in Settings clarifying that **no restart is required** —
  switching language re-renders the entire app instantly via the
  `@Published var language` on `AppSettings`.

---

## Feature 2 — Real complete theme & font lists

**Themes** — expanded from 6 to 10:
- Existing: `midnight`, `ocean`, `sunset`, `forest`, `graphite`, `light`
- New: `rose` (dark pink), `aurora` (dark teal), `sand` (light warm beige),
  `slate` (light cool gray)

Each has a full `ThemeColors` definition (accent, surfaces, text colors,
rating colors, isLight flag).

**Fonts** — expanded from 4 to 12:
- `Font.Design` variants: `rounded`, `serif`, `mono`, `standard`
- Named iOS system fonts: `avenir` (Avenir Next), `futura`, `gillSans`,
  `optima`, `palatino`, `helveticaNeue`, `georgia`, `menlo`

**Live preview** — `SettingsView` now shows:
1. A large preview text ("Aa Bb Cc 123") rendered in the *currently selected*
   font at the top of the font section, updating instantly on selection.
2. Each row in the font list also renders the sample text in its own font, so
   the user can compare side-by-side before committing.

---

## Feature 3 — Custom review intervals (replaces multipliers)

**Removed**: `multAgain`, `multHard`, `multGood`, `multEasy` (the four
`Double` multipliers).

**Added**: `CustomInterval` struct
```swift
struct CustomInterval: Codable, Equatable {
    var enabled: Bool
    var value: Int
    var unit: IntervalUnit   // .minutes | .hours | .days
}
```
- Stored as JSON in `UserDefaults` (one key per rating).
- Defaults mirror FSRS defaults: `Again` = 10 min (enabled, matching FSRS's
  10-minute relearn), `Hard/Good/Easy` = disabled (FSRS default scheduling).

**FSRS adaptation** — `FSRS.review()`:
- Computes stability, difficulty, reps, lapses, state exactly as before
  (so stats remain meaningful).
- After computing the default `due` date, if the user's `CustomInterval`
  for the given rating is `enabled`, the `due` date is **overridden** to
  `now + interval.seconds`. `scheduledDays` is updated for display.
- When disabled, FSRS uses its pure default scheduling (no override).

**Settings UI** — for each of the 4 ratings:
- A summary label showing the current value (e.g. "10 min", "3 days", or
  "FSRS default" when disabled).
- A toggle to enable the custom interval.
- A stepper for the value (1…365).
- A segmented picker for the unit (min / hours / days).
- A "Reset to Defaults" button restores FSRS defaults.

---

## Feature 4 — Clickable photos (fullscreen viewer)

**New file**: `Views/Components/FullscreenImageViewer.swift`

- Presented via `.fullScreenCover(item:)` whenever the user taps a card image.
- Supports:
  - Pinch-to-zoom (`MagnifyGesture`, 1×–6× range)
  - Drag-to-pan when zoomed in
  - Double-tap to toggle 1× ↔ 2.5×
  - Single tap to dismiss (only when at 1×, to avoid accidental dismissal
    while inspecting details)
  - Swipe-down to dismiss when at 1×
  - Close (✕) button always visible
- Wired into both the review screen (`ReviewView.cardFace`) and the card
  editor (`AddEditCardView.cardEditorSection`).
- An expand icon (↗) overlay on the image previews signals tappability.

---

## Feature 5 — Folder management

**New file**: `Views/FolderListView.swift`

- Lists all folders, with per-folder stats (deck count, total cards, due count).
- Tap a folder to rename it (alert with text field).
- Long-press / context menu: Rename, Delete.
- Delete behavior: **automatic ungrouping**. The `DeckFolder.decks`
  relationship uses SwiftData's `deleteRule: .nullify`, so deleting a folder
  sets each contained deck's `folder` property to `nil` — the decks and all
  their cards are preserved. A confirmation alert explains this clearly:
  *"Deleting X will ungroup its N decks. The decks and their cards will be kept."*
- This was chosen over cascading delete because a folder is purely
  organizational; destroying study data when removing a folder would be
  hostile. A confirmation prompt was deemed unnecessary since no data is lost.

**Access**: from `DeckListView`'s toolbar `⋯` menu → "Manage Folders".

---

## Feature 6 — CSV import (verified & completed)

**File**: `Services/CSVImportService.swift` (existing, completed)

- Added `url.startAccessingSecurityScopedResource()` handling so files
  picked from the iOS Files app via `UIDocumentPickerViewController` can
  actually be read.
- Parser already handled RFC-4180 quoting, escaped quotes, and embedded
  newlines — verified and unchanged.
- **Now wired into the UI** (was previously dead code):
  - `DeckListView` toolbar `⋯` menu → "Import CSV"
  - Presents `DocumentPicker` for `[UTType.commaSeparatedText, UTType.text, UTType.data]`
  - On pick, runs `CSVImportService.importCSV(from:context:)` and shows
    an alert with the result ("Created X folders, Y decks, and Z cards.")
  - Imports are additive (matches existing folders/decks by name).

---

## Feature 7 — CSV export (new)

**New file**: `Services/CSVExportService.swift`

- Serializes decks and/or folders to the same `folder,deck,front,back` CSV
  format used by the importer (RFC-4180 quoting).
- Three entry points:
  - `export(decks:)` — export a flat list of decks
  - `export(folders:)` — export entire folders
  - `exportAll(context:)` — export everything
- `writeTemporaryFile(csv:filename:)` writes to `tmp` and returns a `URL`.
- Empty decks still emit a single row (preserving structure on re-import).

**New file**: `Views/Components/ShareSheet.swift`
- Thin `UIViewControllerRepresentable` wrapper around
  `UIActivityViewController` for the native iOS share sheet.

**Wired into the UI**:
- `DeckListView` toolbar `⋯` menu → "Export All as CSV" (shares the whole
  database as `FlashForwardExport.csv`).
- Each deck's context menu → "Export" (single deck).
- `DeckDetailView` → "Export" button next to "Schedule" (single deck).
- All paths route through the native share sheet (Save to Files, AirDrop,
  Mail, Messages, etc.).

---

## Feature 8 — Calendar with date, time & notification

**Files changed**:
- `Services/CalendarService.swift` — extended
- `Views/ScheduleRevisionView.swift` — **new**

**CalendarService additions**:
- `createRevisionEvent(for:at:durationMinutes:withAlarm:)` — now accepts a
  precise `Date` (date + time), a configurable duration, and an `withAlarm`
  flag. When `withAlarm` is true, attaches an `EKAlarm(absoluteDate: date)`
  to the event so iOS fires a local notification at that exact moment.
  No APNs / push server required — works with a free Apple account.
- `scheduleLocalReminder(for:at:)` — schedules an additional
  `UNNotificationRequest` via `UNUserNotificationCenter` as a belt-and-
  braces reminder. Also free-account compatible.
- `requestNotificationAuthorization()` — prompts the user for
  `.alert + .sound` permission once.

**ScheduleRevisionView** (new):
- Full sheet UI with:
  - An icon header showing the deck name
  - An info card (card count, due count, scheduled moment)
  - A `DatePicker` with `.date + .hourAndMinute` displayed components
    (concrete date AND time, both editable)
  - A segmented duration picker (15 / 30 / 45 / 60 / 90 min)
  - Toggles for "Calendar alarm" and "Local notification"
  - A primary "Schedule" button that requests calendar access, then
    creates the event (with alarm if enabled) and schedules the local
    notification (if enabled)
  - Success / failure messaging, auto-dismiss on success
  - Opens iOS Settings if calendar access was denied
- Reachable from: deck context menu → "Schedule", and from
  `DeckDetailView`'s "Schedule" button.

**Info.plist keys** (added to `project.yml`):
- `NSCalendarsUsageDescription`
- `NSCalendarsFullAccessUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`
- `NSUserNotificationsUsageDescription`

---

## New files added

| Path | Purpose |
|---|---|
| `Views/FolderListView.swift` | Folder management screen |
| `Views/ScheduleRevisionView.swift` | Date + time + alarm scheduling sheet |
| `Views/Components/FullscreenImageViewer.swift` | Zoomable fullscreen image viewer |
| `Views/Components/ShareSheet.swift` | `UIActivityViewController` wrapper |
| `Services/CSVExportService.swift` | CSV serialization + temp-file writer |
| `Views/fr.lproj/Localizable.strings` | French localization (split from EN) |
| `Views/fr.lproj/Assets.xcassets/Contents.json` | Empty asset catalog for FR bundle |
| `Views/fr.lproj/Assets.xcassets/AppIcon.appiconset/Contents.json` | AppIcon stub for FR bundle |
| `Views/en.lproj/Assets.xcassets/Contents.json` | Top-level asset catalog Contents |
| `REFINEMENTS.md` | This document |

## Modified files

| Path | Summary of changes |
|---|---|
| `project.yml` | Added Info.plist usage-description keys |
| `FlashForwardApp.swift` | Added `StatsView` tab; `.environment(\.locale)` for global language |
| `Models/Models.swift` | Added `DeckFolder.totalCards` / `dueCount` helpers |
| `Algorithms/FSRS.swift` | Replaced multipliers with `CustomInterval` override logic |
| `Theme/AppTheme.swift` | 10 themes; 12 fonts; `AppSettings` with custom intervals; JSON-encoded persistence |
| `Services/CalendarService.swift` | Date+time, duration, `EKAlarm`, local notifications |
| `Services/CSVImportService.swift` | Security-scoped resource access |
| `Views/DeckListView.swift` | Folder grouping, CSV import, CSV export, schedule sheet, full localization |
| `Views/CardsView.swift` | Full localization |
| `Views/ReviewView.swift` | Fullscreen image viewer integration; localization |
| `Views/StatsView.swift` | Full localization (was previously unreachable; now a tab) |
| `Views/SettingsView.swift` | Custom interval editor; expanded theme list; font list with live preview |
| `Views/AddEditDeckView.swift` | Localization |
| `Views/AddEditCardView.swift` | Fullscreen image viewer on image previews |
| `Views/en.lproj/Localizable.strings` | English-only, with ~80 new keys |

---

## Build

The project is still built via Codemagic exactly as before:

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project FlashForwardApp.xcodeproj \
    -scheme FlashForwardApp \
    -configuration Release \
    -sdk iphoneos \
    CODE_SIGNING_ALLOWED=NO \
    -derivedDataPath build \
    clean build
```

No new third-party dependencies were introduced.
