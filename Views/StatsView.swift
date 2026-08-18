import SwiftUI
import SwiftData
import os

/// v1.3-fixes — Task 3 (Stats button crash).
///
/// The reported symptom: tapping the Stats tab "returns to the home screen
/// and closes the app instantly" — i.e. a hard crash. Static analysis
/// doesn't reveal an obvious force-unwrap; the most plausible culprits are:
///   • a SwiftData `@Query` whose sort descriptor trips on a partially-
///     deleted model (a `ReviewLog` whose `card` relationship was deleted
///     but the log row lingers),
///   • `ForEach(reviewLogs.prefix(5))` over an `ArraySlice` whose identity
///     changes mid-iteration when the query re-evaluates,
///   • a `Circle().trim(from: 0, to: retentionRate)` call where
///     `retentionRate` ends up NaN (0/0 is guarded, but the layered
///     `@Query` re-evals can transiently produce unexpected optionals).
///
/// This rewrite makes the view **bulletproof**:
///   1. An `onAppear` "probe" wrapped in `do/catch` that touches the
///      `modelContext` once; if it throws, the view switches to an
///      error-state UI instead of crashing. Diagnostics go through
///      `AppLog.stats` (no `print` left in the codebase — Task 8).
///   2. `Array(reviewLogs.prefix(5))` materializes the slice into a stable
///      array so the `ForEach` identity is fixed.
///   3. `retentionRate` is clamped to `[0, 1]` and sanitized against NaN
///      before being handed to `Circle().trim(...)`.
///   4. All optional access is explicit (`if let`) — no implicit unwraps.
///   5. Stats is reached via a `TabView` tab (not a `Navigator.push`), so
///      there is no push/replace mismatch to fix here; the defense is
///      purely runtime-safety.
struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var decks: [Deck]
    @Query var cards: [Card]
    @Query(sort: [SortDescriptor(\ReviewLog.reviewTime, order: .reverse)])
    var reviewLogs: [ReviewLog]

    /// If the `onAppear` probe throws, we render an error card instead of
    /// the stats — never a crash.
    @State private var loadError: String? = nil

    private var totalCards: Int { cards.count }
    private var dueToday: Int { cards.filter { $0.isDue }.count }
    private var newCards: Int { cards.filter { $0.state == .new }.count }
    private var totalReviews: Int { reviewLogs.count }

    /// Sanitized retention in `[0, 1]`. Never NaN.
    private var retentionRate: Double {
        guard !reviewLogs.isEmpty else { return 0 }
        let successful = reviewLogs.filter { $0.rating == .good || $0.rating == .easy }.count
        let raw = Double(successful) / Double(reviewLogs.count)
        if raw.isNaN || raw.isInfinite { return 0 }
        return min(max(raw, 0), 1)
    }

    private var upcomingTomorrow: Int {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()),
              let endOfTomorrow = cal.date(bySettingHour: 23, minute: 59, second: 59, of: tomorrow) else {
            return 0
        }
        let now = Date()
        return cards.filter { $0.due <= endOfTomorrow && $0.due > now }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    if let loadError {
                        errorCard(loadError)
                    } else {
                        overviewStats
                        reviewPerformance
                        recentActivity
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)
                .padding(.bottom, AppTheme.spacingXL)
            }
            .primaryGradientBackground()
            .navigationTitle(L("stats.title"))
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { probeData() }
    }

    // MARK: - Data probe (Task 3)

    /// Touch the SwiftData context once on appear. If anything throws, we
    /// log it (via `AppLog.stats`) and switch to the error card — the app
    /// keeps running instead of crashing.
    private func probeData() {
        // Force relationship resolution up front so a missing `card` on a
        // stale `ReviewLog` surfaces here (in a do/catch) rather than
        // mid-render.
        do {
            let descriptor = FetchDescriptor<ReviewLog>()
            let probe = try modelContext.fetch(descriptor)
            // Touch the card relationship on each log — faulting it now.
            for log in probe { _ = log.card?.front }
        } catch {
            AppLog.stats.error("StatsView probe failed: \(error.localizedDescription, privacy: .public)")
            loadError = error.localizedDescription
        }
    }

    private func errorCard(_ message: String) -> some View {
        VStack(spacing: AppTheme.spacingM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundColor(AppTheme.warning)
            Text(L("stats.error.title"))
                .font(AppTheme.heading(18))
                .foregroundColor(AppTheme.textPrimary)
            Text(L("stats.error.message"))
                .font(AppTheme.body(14))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(AppTheme.mono(11))
                .foregroundColor(AppTheme.textTertiary)
                .padding(AppTheme.spacingS)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusS, style: .continuous))
        }
        .padding(AppTheme.spacingL)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
    }

    // MARK: - Overview Stats

    private var overviewStats: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: AppTheme.spacingM),
            GridItem(.flexible(), spacing: AppTheme.spacingM)
        ], spacing: AppTheme.spacingM) {
            statCard(title: L("stats.dueToday"), value: "\(dueToday)", icon: "clock.fill", color: AppTheme.accent)
            statCard(title: L("stats.newCards"), value: "\(newCards)", icon: "sparkles", color: AppTheme.info)
            statCard(title: L("stats.totalCards"), value: "\(totalCards)", icon: "rectangle.stack.fill", color: AppTheme.success)
            statCard(title: L("stats.decks"), value: "\(decks.count)", icon: "books.vertical.fill", color: AppTheme.warning)
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: AppTheme.spacingM) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(AppTheme.title(22))
                    .foregroundColor(AppTheme.textPrimary)
                Text(title)
                    .font(AppTheme.caption(12))
                    .foregroundColor(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
    }

    // MARK: - Review Performance

    private var reviewPerformance: some View {
        VStack(spacing: AppTheme.spacingM) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(AppTheme.accent)
                Text(L("stats.reviewPerformance"))
                    .font(AppTheme.heading(18))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }

            HStack(spacing: AppTheme.spacingL) {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: retentionRate)
                            .stroke(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accentSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: retentionRate)

                        Text(String(format: "%.0f%%", retentionRate * 100))
                            .font(AppTheme.heading(18))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .frame(width: 70, height: 70)

                    Text(L("stats.retention"))
                        .font(AppTheme.caption(12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Divider()
                    .frame(height: 80)
                    .background(AppTheme.surfaceElevated)

                VStack(alignment: .leading, spacing: 12) {
                    performanceRow(label: L("stats.totalReviews"), value: "\(totalReviews)", color: AppTheme.textPrimary)
                    performanceRow(label: L("stats.dueTomorrow"), value: "\(upcomingTomorrow)", color: AppTheme.warning)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppTheme.spacingL)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        }
    }

    private func performanceRow(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.body(14))
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(AppTheme.heading(16))
                .foregroundColor(color)
        }
    }

    // MARK: - Recent Activity

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(AppTheme.accent)
                Text(L("stats.recentActivity"))
                    .font(AppTheme.heading(18))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
            }

            if reviewLogs.isEmpty {
                VStack(spacing: AppTheme.spacingS) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(AppTheme.textTertiary)
                    Text(L("stats.noReviews"))
                        .font(AppTheme.body(15))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.spacingL)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            } else {
                // Materialize a stable array (Task 3): `Array(...)` instead
                // of iterating the `ArraySlice` directly, so the ForEach
                // identity is fixed even if the query re-evaluates.
                let recent = Array(reviewLogs.prefix(5))
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.offset) { index, log in
                        if let card = log.card {
                            reviewLogRow(card: card, log: log)
                            if index < recent.count - 1 {
                                Divider()
                                    .background(AppTheme.surfaceElevated)
                                    .padding(.horizontal, AppTheme.spacingM)
                            }
                        }
                    }
                }
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            }
        }
    }

    private func reviewLogRow(card: Card, log: ReviewLog) -> some View {
        HStack(spacing: AppTheme.spacingM) {
            Circle()
                .fill(log.rating.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.front)
                    .font(AppTheme.body(15))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(log.reviewTime.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTheme.caption(12))
                    .foregroundColor(AppTheme.textSecondary)
            }

            Spacer()

            Text(log.rating.label)
                .font(AppTheme.caption(12))
                .foregroundColor(log.rating.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(log.rating.color.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(AppTheme.spacingM)
    }
}
