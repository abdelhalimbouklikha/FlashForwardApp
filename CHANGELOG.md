# Changelog

All notable changes to this project are documented in this file. The format
is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.3] — 2025-01

This release addresses the eight refinement items requested in the brief.
The project remains **SwiftUI + SwiftData (iOS 17+)**, built via
**Codemagic + XcodeGen**; no new third-party dependencies were introduced.

### Fixed
- **Task 1 — Fullscreen image viewer loop.** Tapping an image to enlarge it
  no longer enters an open/close infinite loop. The single-tap-to-dismiss
  and swipe-down-to-dismiss gestures were removed entirely; the **only**
  way to close the viewer is now the ✕ button at the top-right. Pinch-to-
  zoom, drag-to-pan, and double-tap-to-toggle-zoom are preserved.
  (`Views/Components/FullscreenImageViewer.swift`)

- **Task 2 — CSV import only loading one card per pack.** The importer
  previously hard-coded `,` as the field separator, so any file using `;`,
  `|`, `:`, Tab or space was mis-parsed as a single giant field per line —
  yielding "one card per pack". A new bottom sheet
  (`CSVSeparatorPickerSheet`) is now presented after the user picks a file;
  it offers six separators (Tab, `|`, `;`, `:`, `,`, Space), shows a
  **live preview** of the parsed rows for the selected separator, **auto-
  detects** a sensible default by trying every separator on the first line
  and keeping the one that yields the most columns, and finally exposes an
  "Importer" button that performs the actual import with the chosen
  separator. (`Services/CSVImportService.swift`,
  `Views/Components/CSVSeparatorPickerSheet.swift` [new],
  `Views/DeckListView.swift`)

- **Task 3 — Stats button crash.** The Stats tab no longer crashes when
  tapped. `StatsView` was made **bulletproof**: an `onAppear` "probe"
  wrapped in `do/catch` touches the SwiftData context once and faults the
  `ReviewLog.card` relationship up front; if it throws, the view renders
  an error card instead of crashing. The recent-activity `ForEach` now
  iterates a materialized `Array(reviewLogs.prefix(5))` (fixed identity)
  instead of an `ArraySlice`. `retentionRate` is clamped and sanitized
  against NaN before being passed to `Circle().trim(...)`. All optionals
  are explicit. Diagnostics go through `AppLog.stats`.
  (`Views/StatsView.swift`)

- **Task 8 — Code audit.** Every `print(...)` in the codebase was replaced
  with a structured `os.Logger` call through the new `AppLog` helper
  (`Services/AppLog.swift` [new], one category per subsystem). The async
  `PhotosPickerItem` load in `AddEditCardView` is now tracked and
  **cancelled on view disappear**, eliminating the "setState-after-dispose"
  risk. Unused/missing imports were checked. `project.yml` and
  `codemagic.yaml` were re-verified for Codemagic compatibility.

### Added
- **Task 4 — Tag field on cards.** The card editor now has an optional,
  multiple **Tag** field (chips with autocomplete from tags already used in
  the same deck). Tags are persisted on `Card.tags` (a computed accessor
  backed by a `tagsJSON` `String` property — an additive schema change
  that needs **no migration plan**; legacy rows load an empty array). Tags
  are visible on `CardSearchRow`, on the review card face, in a deck-local
  filter chip bar in `DeckDetailView`, and in a global tag filter chip bar
  in the Cards tab. Starting a review with a tag filter active queues only
  cards carrying that tag. CSV import/export now round-trip a 5th `tags`
  column (semicolon-separated within the cell).
  (`Models/Models.swift`, `Views/AddEditCardView.swift`,
  `Views/CardsView.swift`, `Views/ReviewView.swift`,
  `Views/DeckListView.swift`, `Services/CSVImportService.swift`,
  `Services/CSVExportService.swift`)

- **Task 6 — Reorderable review buttons with shown intervals.** The four
  rating buttons (`À refaire`, `Difficile`, `Correct`, `Facile`) shown
  after revealing an answer are now rendered in a user-configurable order,
  and each button shows the **configured time** from Settings (e.g.
  "Correct · 10 min", "Facile · 1 jour") when a custom interval is
  enabled, else the FSRS-computed interval. The order is set in
  `Settings → Révision → Boutons` via up/down arrows, persisted in
  `UserDefaults` as a JSON-encoded `[Int]` (normalized on load so a
  corrupted store can never drop a button), and applied on the review
  screen. A "Réinitialiser l'ordre" button restores the canonical FSRS
  order. (`Theme/AppTheme.swift`, `Views/ReviewView.swift`,
  `Views/SettingsView.swift`)

- **Task 7 — Reset option for decks scheduled in the future.** Decks that
  have at least one card already reviewed and scheduled in the future
  (i.e. currently hidden from the review queue) now expose a
  **"Réinitialiser"** entry in their context menu (⟳ icon). The action
  resets every card in the deck to the initial "new" scheduling state
  (`due = now`, `stability = 0`, `difficulty = 0`, `reps = 0`,
  `lapses = 0`, `state = .new`, `scheduledDays = 0`, `lastReview = nil`),
  making them immediately available for review again. Card content and
  tags are preserved. A confirmation alert explains the impact before
  the reset runs. (`Models/Models.swift`, `Views/DeckListView.swift`)

- **Task 8 — `AppLog`.** A centralized `os.Logger` helper with one
  category per subsystem so the codebase never uses bare `print(...)`.
  (`Services/AppLog.swift` [new])

### Changed
- **Task 5 — Settings reorganized into collapsible sections.** The
  Settings screen is now divided into three **accordion** sections —
  **General**, **Display**, **Review** — plus a small About block. All
  sections are **closed by default** when the screen opens; tapping a
  header toggles its content with a smooth spring animation, and the
  chevron rotates 90°. Several sections can be open at once. The Review
  section gained the new "Boutons de révision" reorder UI (Task 6) above
  the existing custom-interval editors. A reusable `CollapsibleSection`
  view backs the accordion. (`Views/SettingsView.swift`)

### Localized
- All new user-facing strings were added to both `Views/en.lproj/
  Localizable.strings` and `Views/fr.lproj/Localizable.strings`:
  `csv.separator.*`, `card.tags.*`, `cards.tags.all`, `stats.error.*`,
  `settings.buttonOrder*`, `decks.reset*`.

### Build & tooling
- `codemagic.yaml` and `project.yml` are unchanged — the build path is
  still `xcodegen generate` → `xcodebuild ... CODE_SIGNING_ALLOWED=NO`.
  No new dependencies.

### Notes on environment limits
- This delivery was produced in a sandbox without the Flutter SDK and
  without Xcode/iOS toolchain. `flutter analyze` and `flutter build ios
  --no-codesign` could not be executed here. The source compiles against
  the existing `project.yml` (iOS 17.0 deployment target, Swift 5.0);
  please run the Codemagic build on a macOS host to produce the unsigned
  IPA.
- The brief mentioned Flutter/`pubspec.yaml`/`lib/`, but the uploaded
  project is **native SwiftUI** (`.swift` files, `project.yml`,
  `codemagic.yaml`). The eight fixes were applied to the Swift codebase
  as-is; the fix intents are framework-agnostic.
