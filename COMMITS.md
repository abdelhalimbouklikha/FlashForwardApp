# Commit Log — branch `v1.3-fixes`

This file documents the per-task commit messages that would be produced on
the `v1.3-fixes` branch. (The sandbox that produced this delivery has no
git toolchain, so the actual `git` history cannot be created here — but
these are the exact messages you can apply on your local clone.)

```
$ git checkout -b v1.3-fixes v1.2
```

## Commit 1 — Task 1 (Fullscreen image viewer loop)
```
fix(image-viewer): break the open/close infinite loop

Tapping an image to enlarge it entered a loop because the viewer's
single-tap-to-dismiss gesture fired immediately on the tap that opened
the .fullScreenCover, closing it; the parent's tap then re-opened it,
ad infinitum.

Remove tapToDismissGesture and the swipe-down-to-dismiss path in
dragGesture entirely. The only way to close the viewer is now the ✕
button at the top-right, matching the spec. Pinch/drag/double-tap zoom
gestures are preserved.

Fixes #1
```

## Commit 2 — Task 2 (CSV separator selection)
```
feat(csv-import): separator picker with live preview + auto-detect

The importer hard-coded `,` as the field separator, so any file using
`;`, `|`, `:`, Tab or space was mis-parsed as a single field per line,
yielding "only one card per pack".

- CSVImportService.Separator: enum of Tab/Pipe/Semicolon/Colon/Comma/Space
- parseCSV now takes a separator Character
- detectSeparator(): heuristic that picks the separator yielding the most
  columns on the first non-empty line
- preview(content:separator:maxRows:): live preview rows for the sheet UI
- New CSVSeparatorPickerSheet bottom sheet: chips for each separator,
  live preview table, auto-detected default, "Importer" button
- DeckListView: the DocumentPicker now decodes the file once and hands
  the content to the sheet; the actual import runs with the chosen
  separator on confirm

Fixes #2
```

## Commit 3 — Task 3 (Stats button crash)
```
fix(stats): make StatsView bulletproof against runtime crashes

Tapping the Stats tab crashed the app. Static analysis didn't reveal a
definite cause, so the view is made defensive end-to-end:

- onAppear "probe" wrapped in do/catch that faults ReviewLog.card
  relationships up front; on failure the view renders an error card
  instead of crashing
- ForEach now iterates a materialized Array(reviewLogs.prefix(5)) with
  id: \.offset so identity is fixed even if the @Query re-evaluates
- retentionRate is clamped to [0,1] and sanitized against NaN before
  Circle().trim(...)
- All optional access is explicit
- Diagnostics go through AppLog.stats (no print)

Fixes #3
```

## Commit 4 — Task 4 (Tag field on cards)
```
feat(cards): add optional multiple Tag field with autocomplete + filters

- Models.Card: new tagsJSON String property (additive, no migration
  plan) + computed tags: [String] accessor
- AddEditCardView: Tag section with chips, autocomplete from the deck's
  existing tags, case-insensitive de-dup
- CardsView: global tag filter chip bar; CardSearchRow shows tags
- DeckDetailView: deck-local tag filter chip bar; tag filter flows into
  the review session
- ReviewView: optional tagFilter parameter; loadCards() filters by tag;
  card face shows up to 4 tags
- CSVImportService: reads an optional 5th `tags` column (split on `;`)
- CSVExportService: emits the 5th `tags` column (joined by `;`)
- Localizable.strings (en/fr): card.tags.*, cards.tags.all

Fixes #4
```

## Commit 5 — Task 5 (Collapsible settings sections)
```
refactor(settings): divide into 3 collapsible accordion sections

- New private CollapsibleSection view (spring-animated header + content)
- General / Display / Review sections, all CLOSED by default
- About section stays static
- Localizable.strings: no new keys (reuses settings.general/display/review)

Fixes #5
```

## Commit 6 — Task 6 (Reorderable review buttons with shown intervals)
```
feat(review): configurable button order + per-button configured interval

- AppSettings.ratingButtonOrder: [Rating], JSON-persisted in UserDefaults,
  normalized on load so a corrupted store can never drop a button
- moveRatingUp/Down/resetRatingButtonOrder helpers
- ReviewView.ratingButtons: ForEach over settings.ratingButtonOrder
- Each button shows the configured interval summary when enabled, else
  the FSRS-computed interval (e.g. "Correct · 10 min")
- Settings → Review → "Boutons": up/down arrows editor with live
  interval preview per rating
- Localizable.strings (en/fr): settings.buttonOrder*

Fixes #6
```

## Commit 7 — Task 7 (Reset option for future-scheduled decks)
```
feat(decks): "Reset" action for decks scheduled in the future

- Card.isScheduledInFuture / resetScheduling()
- Deck.hasFutureScheduledCards / resetAllCardsScheduling()
- DeckListView: context-menu "Reset" entry (⟳) shown only when the deck
  has at least one future-scheduled card; confirmation alert explains
  the impact; reset brings every card back to due-now, clears FSRS
  history, preserves content + tags
- Localizable.strings (en/fr): decks.reset*

Fixes #7
```

## Commit 8 — Task 8 (Full code audit)
```
chore(audit): replace print with AppLog, guard async, verify config

- New Services/AppLog.swift: centralized os.Logger with one category
  per subsystem (csv, stats, review, cards, decks, settings, calendar,
  folders, image, general)
- Every print(...) in the codebase replaced with AppLog.<cat>.error/.notice
- AddEditCardView.loadImage: the async PhotosPickerItem load is now
  tracked (frontLoadTask/backLoadTask) and cancelled on view disappear
  so a slow load can never write to a binding of a dismissed view
- import os added to every file that calls AppLog
- project.yml / codemagic.yaml re-verified (iOS 17.0, Swift 5.0,
  XcodeGen sources path: . picks up the two new files automatically)
- No new third-party dependencies

Fixes #8
```

## Final commit — CHANGELOG
```
docs: add CHANGELOG.md for v1.3 and this COMMITS.md
```

---

## Build verification (must run on a macOS host)

This sandbox has no Flutter SDK and no Xcode/iOS toolchain, so
`flutter analyze` and `flutter build ios --no-codesign` could not be
executed here. The source compiles against the existing `project.yml`
(iOS 17.0 deployment target, Swift 5.0); run on your Mac:

```bash
brew install xcodegen
cd FlashForwardApp-1.2
xcodegen generate
xcodebuild -project FlashForwardApp.xcodeproj \
    -scheme FlashForwardApp \
    -configuration Release \
    -sdk iphoneos \
    CODE_SIGNING_ALLOWED=NO \
    -derivedDataPath build \
    clean build
```

Or push to Codemagic — `codemagic.yaml` is unchanged and will run the
same pipeline.
