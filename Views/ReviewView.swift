import SwiftUI
import SwiftData
import UIKit
import os

struct ReviewView: View {
    let deck: Deck
    /// v1.3 — Task 4. Optional tag filter: when non-nil, only cards carrying
    /// this tag are queued for review. Set by `DeckDetailView` when the
    /// user starts a review with a tag filter active.
    var tagFilter: String? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: AppSettings

    @State private var queue: [Card] = []
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var sessionComplete: Bool = false
    @State private var reviewedCount: Int = 0
    @State private var againCount: Int = 0
    @State private var hardCount: Int = 0
    @State private var goodCount: Int = 0
    @State private var easyCount: Int = 0

    // Countdown
    @State private var countdownRemaining: Int = 0
    @State private var countdownExpired: Bool = false
    private let countdownPublisher = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Fullscreen image viewer
    @State private var fullscreenImageData: Data? = nil

    private var fsrs: FSRS {
        FSRS(
            intervalAgain: settings.intervalAgain,
            intervalHard:  settings.intervalHard,
            intervalGood:  settings.intervalGood,
            intervalEasy:  settings.intervalEasy
        )
    }

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
                    title: L("review.allCaughtUp"),
                    message: L("review.allCaughtUpMsg"),
                    actionTitle: L("common.done"),
                    action: { dismiss() }
                )
            }
        }
        .primaryGradientBackground()
        .preferredColorScheme(AppTheme.preferredColorScheme)
        .onAppear { loadCards() }
        .onReceive(countdownPublisher) { _ in
            guard settings.countdownEnabled,
                  !sessionComplete,
                  currentCard != nil,
                  countdownRemaining > 0 else { return }
            countdownRemaining -= 1
            if countdownRemaining == 0 {
                countdownExpired = true
                haptic(.light)
            }
        }
        .onChange(of: currentIndex) { _, _ in
            resetCountdown()
        }
        .fullScreenCover(item: Binding(
            get: { fullscreenImageData.map { ImageDataWrapper(data: $0) } },
            set: { fullscreenImageData = $0?.data }
        )) { wrapper in
            FullscreenImageViewer(imageData: wrapper.data)
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

            if settings.countdownEnabled {
                countdownRing
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

    // MARK: - Countdown Ring

    private var countdownRing: some View {
        let total = max(1, settings.countdownSeconds)
        let progress = Double(countdownRemaining) / Double(total)

        return ZStack {
            Circle()
                .stroke(AppTheme.surfaceElevated, lineWidth: 3)

            Circle()
                .trim(from: 0, to: max(0, progress))
                .stroke(
                    countdownExpired ? AppTheme.danger : AppTheme.accent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.4), value: countdownRemaining)

            Text("\(countdownRemaining)")
                .font(AppTheme.mono(10))
                .foregroundColor(countdownExpired ? AppTheme.danger : AppTheme.textSecondary)
        }
        .frame(width: 34, height: 34)
        .scaleEffect(countdownExpired ? 1.15 : 1.0)
        .animation(
            countdownExpired
                ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                : .default,
            value: countdownExpired
        )
    }

    // MARK: - Card View

    private func cardView(card: Card) -> some View {
        ZStack {
            cardFace(text: card.front,
                     imageData: card.frontImageData,
                     label: L("review.question"),
                     icon: "questionmark.circle.fill",
                     tags: card.tags)
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .opacity(isFlipped ? 0 : 1)

            cardFace(text: card.back,
                     imageData: card.backImageData,
                     label: L("review.answer"),
                     icon: "lightbulb.fill",
                     tags: card.tags)
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

    private func cardFace(text: String, imageData: Data?,
                          label: String, icon: String,
                          tags: [String] = []) -> some View {
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

            if let data = imageData, let uiImage = UIImage(data: data) {
                Button {
                    fullscreenImageData = data
                    haptic(.light)
                } label: {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                    style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                                .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
                        )
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(Color.black.opacity(0.45))
                                .clipShape(Circle())
                                .padding(8)
                        }
                }
                .buttonStyle(.plain)
            }

            if !text.isEmpty {
                Text(text)
                    .font(AppTheme.reviewFont(24))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.spacingL)
            }

            // v1.3 — Task 4. Show the card's tags (up to 4) at the bottom
            // of the card face, so the user can see the tags during review.
            if !tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tags.prefix(4), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(AppTheme.caption(10))
                            .foregroundColor(AppTheme.info)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.info.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if tags.count > 4 {
                        Text("+\(tags.count - 4)")
                            .font(AppTheme.caption(10))
                            .foregroundColor(AppTheme.textTertiary)
                    }
                }
            }
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
                Text(L("review.tapToReveal"))
                    .font(AppTheme.caption(14))
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.bottom, AppTheme.spacingS)
            } else {
                Text(L("review.howWell"))
                    .font(AppTheme.caption(14))
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.bottom, AppTheme.spacingS)
            }

            // v1.3 — Task 6. Render the four rating buttons in the
            // user-configured order (Settings → Review → Boutons).
            HStack(spacing: AppTheme.spacingS) {
                ForEach(settings.ratingButtonOrder, id: \.self) { rating in
                    ratingButton(rating: rating, preview: previews[rating])
                }
            }
        }
    }

    /// v1.3 — Task 6. Each button shows the rating label and, beneath it,
    /// the **configured** time from Settings (e.g. "10 min", "1 jour") when
    /// a custom interval is enabled; otherwise it falls back to the FSRS-
    /// computed interval (e.g. "3d"). This matches the spec example
    /// "Correct · 10 min".
    private func ratingButton(rating: Rating, preview: ScheduledCard?) -> some View {
        // Prefer the user-configured interval summary; fall back to the
        // FSRS-computed interval for this card.
        let custom = settings.interval(for: rating)
        let intervalText: String
        if custom.enabled {
            intervalText = custom.summary
        } else if let preview = preview {
            intervalText = formatInterval(preview.scheduledDays)
        } else {
            intervalText = ""
        }

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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
                Text(L("review.sessionComplete"))
                    .font(AppTheme.title(28))
                    .foregroundColor(AppTheme.textPrimary)

                Text(String(format: L("review.cardsReviewed"), reviewedCount))
                    .font(AppTheme.body(16))
                    .foregroundColor(AppTheme.textSecondary)
            }

            VStack(spacing: AppTheme.spacingM) {
                ratingBreakdownRow(label: L("rating.again"), count: againCount, color: AppTheme.againColor)
                ratingBreakdownRow(label: L("rating.hard"), count: hardCount, color: AppTheme.hardColor)
                ratingBreakdownRow(label: L("rating.good"), count: goodCount, color: AppTheme.goodColor)
                ratingBreakdownRow(label: L("rating.easy"), count: easyCount, color: AppTheme.easyColor)
            }
            .padding(AppTheme.spacingL)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
            .padding(.horizontal, AppTheme.spacingL)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text(L("common.done"))
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
        // v1.3 — Task 4. Apply the optional tag filter before the due
        // filter, so a tag-filtered review session only considers cards
        // carrying that tag.
        let pool: [Card]
        if let tag = tagFilter {
            pool = deck.cards.filter { $0.tags.contains(tag) }
        } else {
            pool = deck.cards
        }
        let dueCards = pool.filter { $0.isDue }
        queue = dueCards.shuffled()
        resetCountdown()
    }

    private func resetCountdown() {
        countdownRemaining = settings.countdownEnabled ? settings.countdownSeconds : 0
        countdownExpired = false
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
            // v1.3 — Task 8: structured log instead of bare print.
            AppLog.review.error("Failed to save review: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Haptics

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - ImageDataWrapper (for fullScreenCover(item:))

private struct ImageDataWrapper: Identifiable {
    let id = UUID()
    let data: Data
}
