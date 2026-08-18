import Foundation

// MARK: - ScheduledCard (value type returned by FSRS.review)

struct ScheduledCard {
    var stability: Double = 0
    var difficulty: Double = 0
    var scheduledDays: Int = 0
    var reps: Int = 0
    var lapses: Int = 0
    var state: CardState = .new
    var due: Date = Date()
}

// MARK: - CustomInterval (user-defined concrete interval, replaces multipliers)
//
// When `enabled` is true, FSRS will OVERRIDE the algorithmically computed
// `due` date for that rating with the user's chosen value. The stability,
// difficulty, reps, lapses and state are still computed by FSRS so that
// statistics remain meaningful; only the next-review date is pinned.
// When `enabled` is false, FSRS uses its default scheduling.

enum IntervalUnit: String, Codable, CaseIterable, Identifiable {
    case minutes, hours, days
    var id: String { rawValue }

    var label: String {
        switch self {
        case .minutes: return L("interval.unit.minutes")
        case .hours:   return L("interval.unit.hours")
        case .days:    return L("interval.unit.days")
        }
    }

    /// One unit expressed in seconds.
    var seconds: TimeInterval {
        switch self {
        case .minutes: return 60
        case .hours:   return 3600
        case .days:    return 86_400
        }
    }
}

struct CustomInterval: Codable, Equatable {
    var enabled: Bool
    var value: Int
    var unit: IntervalUnit

    static let defaultAgain = CustomInterval(enabled: false, value: 10, unit: .minutes)
    static let defaultHard  = CustomInterval(enabled: false, value: 1,  unit: .days)
    static let defaultGood  = CustomInterval(enabled: false, value: 3,  unit: .days)
    static let defaultEasy  = CustomInterval(enabled: false, value: 7,  unit: .days)

    /// Returns the concrete time interval in seconds, or nil when disabled.
    var timeInterval: TimeInterval? {
        guard enabled else { return nil }
        return Double(value) * unit.seconds
    }

    /// Human-readable summary, e.g. "10 min", "1 day", "off".
    var summary: String {
        guard enabled else { return L("interval.off") }
        let unitLabel: String
        switch unit {
        case .minutes: unitLabel = value == 1 ? L("interval.unit.minute") : L("interval.unit.minutes")
        case .hours:   unitLabel = value == 1 ? L("interval.unit.hour")   : L("interval.unit.hours")
        case .days:    unitLabel = value == 1 ? L("interval.unit.day")    : L("interval.unit.days")
        }
        return "\(value) \(unitLabel)"
    }
}

// MARK: - FSRS

struct FSRS {
    var requestRetention: Double = 0.9
    var maximumInterval: Double = 36500

    /// User-defined concrete intervals (one per rating). When enabled, the
    /// card's `due` date is pinned to `now + interval` regardless of the
    /// FSRS-computed stability. Replaces the old multiplier system.
    var intervalAgain: CustomInterval = .defaultAgain
    var intervalHard:  CustomInterval = .defaultHard
    var intervalGood:  CustomInterval = .defaultGood
    var intervalEasy:  CustomInterval = .defaultEasy

    func customInterval(for rating: Rating) -> CustomInterval {
        switch rating {
        case .again: return intervalAgain
        case .hard:  return intervalHard
        case .good:  return intervalGood
        case .easy:  return intervalEasy
        }
    }

    /// Full FSRS-5 default weight array (19 weights).
    var w: [Double] = [
        0.40255,  // 0
        1.18385,  // 1
        3.173,    // 2  — init stability: Again
        15.69102, // 3  — init stability: Hard
        7.19476,  // 4  — init difficulty / mean-reversion target
        0.5345,   // 5  — init stability: Good
        1.4604,   // 6  — init stability: Easy / difficulty delta weight
        0.0046,   // 7  — mean reversion weight
        1.54575,  // 8  — recall stability exp factor
        0.1192,   // 9  — recall stability decay exponent
        1.0193,   // 10 — recall stability retrievability factor
        1.9395,   // 11 — forget stability multiplier
        0.11,     // 12 — forget stability difficulty power
        0.29605,  // 13 — forget stability (s+1) power
        2.2698,   // 14 — forget stability retrievability factor
        0.2315,   // 15 — hard penalty
        2.9899,   // 16 — easy bonus
        0.51655,  // 17
        0.6621    // 18
    ]

    // MARK: - Main Review Function

    func review(card: Card, rating: Rating, now: Date) -> ScheduledCard {
        let lastReview = card.lastReview ?? now
        let elapsedSeconds = max(0, now.timeIntervalSince(lastReview))
        let elapsedDays = elapsedSeconds / 86400.0
        let r = retrievability(elapsedDays: elapsedDays, stability: card.stability)

        var result = ScheduledCard()
        result.reps = card.reps + 1
        result.lapses = card.lapses
        result.state = card.state
        result.difficulty = card.difficulty
        result.stability = card.stability

        // The user's custom interval (if any) for this rating.
        let custom = customInterval(for: rating)

        // ------------------------------------------------------------------
        // NEW CARD
        // ------------------------------------------------------------------
        if card.state == .new {
            result.difficulty = w[4]
            result.reps = 1

            switch rating {
            case .again:
                result.stability = w[2]
                result.state = .learning
                result.scheduledDays = 0
                result.due = now.addingTimeInterval(10 * 60)

            case .hard:
                result.stability = w[3]
                result.state = .learning
                result.scheduledDays = 0
                result.due = now.addingTimeInterval(10 * 60)

            case .good:
                result.stability = w[5]
                result.state = .review
                result.scheduledDays = nextInterval(stability: result.stability)
                result.due = now.addingTimeInterval(Double(result.scheduledDays) * 86400.0)

            case .easy:
                result.stability = w[6]
                result.state = .review
                result.scheduledDays = max(4, nextInterval(stability: result.stability))
                result.due = now.addingTimeInterval(Double(result.scheduledDays) * 86400.0)
            }
        }
        // ------------------------------------------------------------------
        // LEARNING or RELEARNING
        // ------------------------------------------------------------------
        else if card.state == .learning || card.state == .relearning {
            switch rating {
            case .again:
                result.difficulty = nextDifficulty(d: card.difficulty, rating: .again)
                result.stability = nextForgetStability(d: card.difficulty, s: card.stability, r: r)
                result.state = card.state
                result.scheduledDays = 0
                result.due = now.addingTimeInterval(10 * 60)

            case .hard:
                result.difficulty = nextDifficulty(d: card.difficulty, rating: .hard)
                result.stability = nextRecallStability(d: card.difficulty, s: card.stability, r: r, rating: .hard)
                result.state = card.state
                result.scheduledDays = 0
                result.due = now.addingTimeInterval(10 * 60)

            case .good:
                result.difficulty = nextDifficulty(d: card.difficulty, rating: .good)
                result.stability = nextRecallStability(d: card.difficulty, s: card.stability, r: r, rating: .good)
                result.state = .review
                result.scheduledDays = nextInterval(stability: result.stability)
                result.due = now.addingTimeInterval(Double(result.scheduledDays) * 86400.0)

            case .easy:
                result.difficulty = nextDifficulty(d: card.difficulty, rating: .easy)
                result.stability = nextRecallStability(d: card.difficulty, s: card.stability, r: r, rating: .easy)
                result.state = .review
                result.scheduledDays = max(4, nextInterval(stability: result.stability))
                result.due = now.addingTimeInterval(Double(result.scheduledDays) * 86400.0)
            }
        }
        // ------------------------------------------------------------------
        // REVIEW
        // ------------------------------------------------------------------
        else {
            switch rating {
            case .again:
                result.difficulty = nextDifficulty(d: card.difficulty, rating: .again)
                result.stability = nextForgetStability(d: card.difficulty, s: card.stability, r: r)
                result.state = .relearning
                result.lapses = card.lapses + 1
                result.scheduledDays = 0
                result.due = now.addingTimeInterval(10 * 60)

            case .hard:
                result.difficulty = nextDifficulty(d: card.difficulty, rating: .hard)
                result.stability = nextRecallStability(d: card.difficulty, s: card.stability, r: r, rating: .hard)
                result.state = .review
                let stabilityInterval = nextInterval(stability: result.stability)
                let prevInterval = max(1, card.scheduledDays)
                result.scheduledDays = min(stabilityInterval, max(1, Int(Double(prevInterval) * 1.2)))
                result.due = now.addingTimeInterval(Double(result.scheduledDays) * 86400.0)

            case .good:
                result.difficulty = nextDifficulty(d: card.difficulty, rating: .good)
                result.stability = nextRecallStability(d: card.difficulty, s: card.stability, r: r, rating: .good)
                result.state = .review
                result.scheduledDays = nextInterval(stability: result.stability)
                result.due = now.addingTimeInterval(Double(result.scheduledDays) * 86400.0)

            case .easy:
                result.difficulty = nextDifficulty(d: card.difficulty, rating: .easy)
                result.stability = nextRecallStability(d: card.difficulty, s: card.stability, r: r, rating: .easy)
                result.state = .review
                let stabilityInterval = nextInterval(stability: result.stability)
                let prevInterval = max(1, card.scheduledDays)
                result.scheduledDays = max(stabilityInterval, Int(Double(prevInterval) * 1.3))
                result.due = now.addingTimeInterval(Double(result.scheduledDays) * 86400.0)
            }
        }

        // ------------------------------------------------------------------
        // Override with user-defined custom interval (replaces multipliers)
        // ------------------------------------------------------------------
        if let customSeconds = custom.timeInterval {
            result.due = now.addingTimeInterval(customSeconds)
            // For display purposes only; "scheduledDays" is a day-count hint.
            result.scheduledDays = max(0, Int(round(customSeconds / 86400.0)))
        }

        // Clamp to maximum interval
        result.scheduledDays = min(result.scheduledDays, Int(maximumInterval))

        return result
    }

    // MARK: - Preview Helper (computes all four ratings at once)

    func preview(card: Card, now: Date) -> [Rating: ScheduledCard] {
        var result: [Rating: ScheduledCard] = [:]
        for r in Rating.allCases {
            result[r] = review(card: card, rating: r, now: now)
        }
        return result
    }

    // MARK: - Scheduling Helpers

    /// Retrievability R = (1 + elapsed / (9 * stability))^-1
    func retrievability(elapsedDays: Double, stability: Double) -> Double {
        guard stability > 0 else { return 0 }
        let factor = elapsedDays / (9.0 * stability)
        return 1.0 / (1.0 + factor)
    }

    /// Interval for a given stability at the target retention level.
    func nextInterval(stability: Double) -> Int {
        let interval = 9.0 * stability * (1.0 / requestRetention - 1.0)
        return max(1, min(Int(round(interval)), Int(maximumInterval)))
    }

    /// Next difficulty with mean reversion toward w[4].
    func nextDifficulty(d: Double, rating: Rating) -> Double {
        let nextD = d - w[6] * Double(rating.rawValue - 3)
        let reverted = meanReversion(target: w[4], current: nextD)
        return min(10, max(1, reverted))
    }

    func meanReversion(target: Double, current: Double) -> Double {
        return w[7] * target + (1 - w[7]) * current
    }

    /// Stability after a successful recall (Hard / Good / Easy).
    func nextRecallStability(d: Double, s: Double, r: Double, rating: Rating) -> Double {
        let hardPenalty = rating == .hard ? w[15] : 1.0
        let easyBonus = rating == .easy ? w[16] : 1.0
        let inner = exp(w[8])
            * (11 - d)
            * pow(s, -w[9])
            * (exp((1 - r) * w[10]) - 1)
        let newS = s * (1 + inner * hardPenalty * easyBonus)
        return max(0.1, newS)
    }

    /// Stability after a forgotten recall (Again).
    func nextForgetStability(d: Double, s: Double, r: Double) -> Double {
        let newS = w[11]
            * pow(d, -w[12])
            * (pow(s + 1, w[13]) - 1)
            * exp((1 - r) * w[14])
        return max(0.1, newS)
    }
}
