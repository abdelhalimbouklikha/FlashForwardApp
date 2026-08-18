import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var decks: [Deck]
    @Query var cards: [Card]
    @Query(sort: [SortDescriptor(\ReviewLog.reviewTime, order: .reverse)])
    var reviewLogs: [ReviewLog]

    private var totalCards: Int { cards.count }
    private var dueToday: Int { cards.filter { $0.isDue }.count }
    private var newCards: Int { cards.filter { $0.state == .new }.count }
    private var totalReviews: Int { reviewLogs.count }

    private var retentionRate: Double {
        guard !reviewLogs.isEmpty else { return 0 }
        let successful = reviewLogs.filter { $0.rating == .good || $0.rating == .easy }.count
        return Double(successful) / Double(reviewLogs.count)
    }

    private var upcomingTomorrow: Int {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let endOfTomorrow = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: tomorrow) ?? Date()
        return cards.filter { $0.due <= endOfTomorrow && $0.due > Date() }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    overviewStats
                    reviewPerformance
                    recentActivity
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)
                .padding(.bottom, AppTheme.spacingXL)
            }
            .primaryGradientBackground()
            .navigationTitle(L("stats.title"))
            .navigationBarTitleDisplayMode(.large)
        }
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
                VStack(spacing: 0) {
                    ForEach(reviewLogs.prefix(5)) { log in
                        if let card = log.card {
                            reviewLogRow(card: card, log: log)
                            if log.id != reviewLogs.prefix(5).last?.id {
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
