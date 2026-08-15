import SwiftUI
import SwiftData
import UIKit

struct ReviewView: View {
    let deck: Deck
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var queue: [Card] = []
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var sessionComplete: Bool = false
    @State private var reviewedCount: Int = 0
    @State private var againCount: Int = 0
    @State private var hardCount: Int = 0
    @State private var goodCount: Int = 0
    @State private var easyCount: Int = 0

    private let fsrs = FSRS()

    private var currentCard: Card? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    private var totalCards: Int { queue.count }
    private var progress: Double {
        guard totalCards > 0 else { return 0 }
        return Double(reviewedCount) / Double(totalCards)
    }

    var body: some View {
        Group {
            if sessionComplete {
                sessionCompleteView
            } else if let card = currentCard {
                reviewSessionView(card: card)
            } else {
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "All Caught Up!",
                    message: "No cards are due in this deck right now. Come back later or add new cards.",
                    actionTitle: "Done",
                    action: { dismiss() }
                )
            }
        }
        .primaryGradientBackground()
        .preferredColorScheme(.dark)
        .onAppear {
            loadCards()
        }
    }

    // MARK: - Review Session

    private func reviewSessionView(card: Card) -> some View {
        let previews = fsrs.preview(card: card, now: Date())

        return VStack(spacing: 0) {
            topBar

            Spacer()

            cardView(card: card)
                .padding(.horizontal, AppTheme.spacingM)

            Spacer()

            ratingButtons(previews: previews)
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingL)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: AppTheme.spacingM) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.surface)
                    .clipShape(Circle())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppTheme.surface)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 6)

            Text("\(reviewedCount + (currentCard != nil ? 1 : 0))/\(totalCards)")
                .font(AppTheme.mono(13))
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.horizontal, AppTheme.spacingM)
        .padding(.top, AppTheme.spacingM)
        .padding(.bottom, AppTheme.spacingS)
    }

    // MARK: - Card View

    private func cardView(card: Card) -> some View {
        ZStack {
            cardFace(text: card.front, label: "Question", icon: "questionmark.circle.fill")
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(isFlipped ? 0 : 1)

            cardFace(text: card.back, label: "Answer", icon: "lightbulb.fill")
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(isFlipped ? 1 : 0)
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                isFlipped.toggle()
            }
            haptic(.light)
        }
    }

    private func cardFace(text: String, label: String, icon: String) -> some View {
        VStack(spacing: AppTheme.spacingL) {
            HStack(spacing: AppTheme.spacingS) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.accent)
                Text(label)
                    .font(AppTheme.caption(12))
                    .foregroundColor(AppTheme.textTertiary)
                    .textCase(.uppercase)
                    .tracking(1.5)
            }

            Text(text)
                .font(AppTheme.title(24))
                .foregroundColor(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.spacingL)
        }
        .frame(maxWidth: .infinity, minHeight: 380)
        .padding(AppTheme.spacingXL)
        .background(
            LinearGradient(
                colors: [AppTheme.surfaceElevated, AppTheme.surface],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusXL, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusXL, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: AppTheme.accent.opacity(0.08), radius: 20, y: 8)
    }

    // MARK: - Rating Buttons

    private func ratingButtons(previews: [Rating: ScheduledCard]) -> some View {
        VStack(spacing: AppTheme.spacingS) {
            if !isFlipped {
                Text("Tap card to reveal answer")
                    .font(AppTheme.caption(14))
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.bottom, AppTheme.spacingS)
            } else {
                Text("How well did you remember?")
                    .font(AppTheme.caption(14))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.bottom, AppTheme.spacingS)
            }

            HStack(spacing: AppTheme.spacingS) {
                ForEach(Rating.allCases, id: \.self) { rating in
                    ratingButton(rating: rating, preview: previews[rating])
                }
            }
        }
    }

    private func ratingButton(rating: Rating, preview: ScheduledCard?) -> some View {
        let intervalText = preview.map { formatInterval($0.scheduledDays) } ?? ""

        return Button {
            grade(rating: rating)
        } label: {
            VStack(spacing: 4) {
                Text(rating.label)
                    .font(AppTheme.heading(14))
                    .foregroundColor(.white)

                Text(intervalText)
                    .font(AppTheme.caption(11))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                    .fill(rating.color.opacity(isFlipped ? 0.85 : 0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                    .stroke(rating.color.opacity(isFlipped ? 0 : 0.3), lineWidth: 1)
            )
        }
        .disabled(!isFlipped)
        .buttonStyle(.plain)
    }

    // MARK: - Session Complete

    private var sessionCompleteView: some View {
        VStack(spacing: AppTheme.spacingXL) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.success.opacity(0.2), AppTheme.accent.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.success, AppTheme.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: AppTheme.spacingS) {
                Text("Session Complete!")
                    .font(AppTheme.title(28))
                    .foregroundColor(AppTheme.textPrimary)

                Text("You reviewed \(reviewedCount) card\(reviewedCount == 1 ? "" : "s")")
                    .font(AppTheme.body(16))
                    .foregroundColor(AppTheme.textSecondary)
            }

            VStack(spacing: AppTheme.spacingM) {
                ratingBreakdownRow(label: "Again", count: againCount, color: AppTheme.againColor)
                ratingBreakdownRow(label: "Hard", count: hardCount, color: AppTheme.hardColor)
                ratingBreakdownRow(label: "Good", count: goodCount, color: AppTheme.goodColor)
                ratingBreakdownRow(label: "Easy", count: easyCount, color: AppTheme.easyColor)
            }
            .padding(AppTheme.spacingL)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .padding(.horizontal, AppTheme.spacingL)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(AppTheme.heading(17))
                    .frame(maxWidth: .infinity)
                    .violetAccentButton()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.spacingL)
            .padding(.bottom, AppTheme.spacingXL)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ratingBreakdownRow(label: String, count: Int, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(AppTheme.body(15))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()

            Text("\(count)")
                .font(AppTheme.heading(16))
                .foregroundColor(AppTheme.textPrimary)
        }
    }

    // MARK: - Actions

    private func loadCards() {
        let dueCards = deck.cards.filter { $0.isDue }
        queue = dueCards.shuffled()
    }

    private func grade(rating: Rating) {
        guard let card = currentCard else { return }

        let now = Date()
        let elapsedDays: Int
        if let lastReview = card.lastReview {
            elapsedDays = max(0, Int(now.timeIntervalSince(lastReview) / 86400.0))
        } else {
            elapsedDays = 0
        }

        // Create review log
        let log = ReviewLog(
            card: card,
            rating: rating,
            stateBefore: card.state,
            stabilityBefore: card.stability,
            difficultyBefore: card.difficulty,
            elapsedDays: elapsedDays,
            scheduledDaysBefore: card.scheduledDays
        )
        modelContext.insert(log)

        // Compute FSRS result
        let scheduled = fsrs.review(card: card, rating: rating, now: now)

        // Update card
        card.stability = scheduled.stability
        card.difficulty = scheduled.difficulty
        card.reps = scheduled.reps
        card.lapses = scheduled.lapses
        card.state = scheduled.state
        card.scheduledDays = scheduled.scheduledDays
        card.due = scheduled.due
        card.lastReview = now

        // Update counts
        reviewedCount += 1
        switch rating {
        case .again: againCount += 1
        case .hard:  hardCount += 1
        case .good:  goodCount += 1
        case .easy:  easyCount += 1
        }

        haptic(.medium)

        // Flip back and advance
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            isFlipped = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if currentIndex + 1 < queue.count {
                currentIndex += 1
            } else {
                sessionComplete = true
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save: \(error)")
        }
    }

    // MARK: - Haptics

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}