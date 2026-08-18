import SwiftUI
import UIKit

// MARK: - Color(hex:) helpers

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r: Double, g: Double, b: Double, a: Double
        if s.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255.0
            g = Double((value >> 16) & 0xFF) / 255.0
            b = Double((value >> 8) & 0xFF) / 255.0
            a = Double(value & 0xFF) / 255.0
        } else {
            r = Double((value >> 16) & 0xFF) / 255.0
            g = Double((value >> 8) & 0xFF) / 255.0
            b = Double(value & 0xFF) / 255.0
            a = 1.0
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// RGB hex string (no alpha), e.g. "7C3AED". Used to persist colors picked
    /// in the UI back onto `Deck.colorHex`.
    func toHexString() -> String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X",
                      Int((r * 255.0).rounded()),
                      Int((g * 255.0).rounded()),
                      Int((b * 255.0).rounded()))
    }
}

// MARK: - In-app localization (independent of system locale)
//
// Approach: SwiftUI's `Text("...")` follows the bundle's preferred locale which
// tracks the iOS system language — a simple toggle cannot change it. So we keep
// an explicit `appLanguage` value in UserDefaults and resolve every visible
// string through `L("key")`, which loads the matching `en.lproj` / `fr.lproj`
// `Localizable.strings` via a manually constructed `Bundle(path:)`. Reactivity
// is handled by `AppSettings.language` (an ObservableObject published at the
// app root); changing it reloads the bundle and re-renders all observing views.
//
// Note: This is fully dynamic — switching language in Settings updates the
// entire app instantly without a restart. SwiftUI's `.environment(\.locale, …)`
// is also set on the root view so date formatters etc. follow the chosen
// language where applicable.

enum Localization {
    static var currentLanguage: String =
        UserDefaults.standard.string(forKey: "appLanguage") ?? "en"

    private static var bundle: Bundle? = bundle(for: currentLanguage)

    static func bundle(for lang: String) -> Bundle? {
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }

    static func setLanguage(_ lang: String) {
        currentLanguage = lang
        UserDefaults.standard.set(lang, forKey: "appLanguage")
        bundle = bundle(for: lang)
    }

    static func string(_ key: String) -> String {
        let b = bundle ?? .main
        // `value:` is the fallback returned when the key is missing.
        return b.localizedString(forKey: key, value: key, table: "Localizable")
    }
}

func L(_ key: String) -> String { Localization.string(key) }

// MARK: - Theme presets

enum ThemePreset: String, CaseIterable, Identifiable {
    case midnight, ocean, sunset, forest, graphite, light,
         rose, aurora, sand, slate
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .midnight: return L("theme.midnight")
        case .ocean:    return L("theme.ocean")
        case .sunset:   return L("theme.sunset")
        case .forest:   return L("theme.forest")
        case .graphite: return L("theme.graphite")
        case .light:    return L("theme.light")
        case .rose:     return L("theme.rose")
        case .aurora:   return L("theme.aurora")
        case .sand:     return L("theme.sand")
        case .slate:    return L("theme.slate")
        }
    }

    var colors: ThemeColors {
        switch self {
        case .midnight: return .midnight
        case .ocean:    return .ocean
        case .sunset:   return .sunset
        case .forest:   return .forest
        case .graphite: return .graphite
        case .light:    return .light
        case .rose:     return .rose
        case .aurora:   return .aurora
        case .sand:     return .sand
        case .slate:    return .slate
        }
    }
}

// MARK: - ReviewFont — full list of available system fonts

enum ReviewFont: String, CaseIterable, Identifiable {
    case rounded, serif, mono, standard,
         avenir, futura, gillSans, optima, palatino,
         helveticaNeue, georgia, menlo
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rounded:      return L("font.rounded")
        case .serif:        return L("font.serif")
        case .mono:         return L("font.mono")
        case .standard:     return L("font.standard")
        case .avenir:       return "Avenir Next"
        case .futura:       return "Futura"
        case .gillSans:     return "Gill Sans"
        case .optima:       return "Optima"
        case .palatino:     return "Palatino"
        case .helveticaNeue:return "Helvetica Neue"
        case .georgia:      return "Georgia"
        case .menlo:        return "Menlo"
        }
    }

    /// Sample text used in the live preview shown next to each font option.
    static let previewText: String = "Aa Bb Cc 123"
}

struct ThemeColors {
    let accent: Color
    let accentSecondary: Color
    let accentDeep: Color
    let background: Color
    let backgroundSecondary: Color
    let surface: Color
    let surfaceElevated: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let success: Color
    let warning: Color
    let danger: Color
    let info: Color
    let againColor: Color
    let hardColor: Color
    let goodColor: Color
    let easyColor: Color
    let isLight: Bool

    // ---- Original dark themes
    static let midnight = ThemeColors(
        accent: Color(hex: "7C3AED")!, accentSecondary: Color(hex: "8A5CEC")!, accentDeep: Color(hex: "4D2188")!,
        background: Color(hex: "0D0817")!, backgroundSecondary: Color(hex: "140D24")!,
        surface: Color(hex: "1C122B")!, surfaceElevated: Color(hex: "261938")!,
        textPrimary: .white, textSecondary: Color(white: 0.68), textTertiary: Color(white: 0.45),
        success: Color(hex: "4DCC80")!, warning: Color(hex: "F2BA4D")!, danger: Color(hex: "EB5959")!, info: Color(hex: "59A6F2")!,
        againColor: Color(hex: "EB5966")!, hardColor: Color(hex: "F2A64D")!, goodColor: Color(hex: "59CC80")!, easyColor: Color(hex: "59A6F2")!,
        isLight: false)

    static let ocean = ThemeColors(
        accent: Color(hex: "06B6D4")!, accentSecondary: Color(hex: "22D3EE")!, accentDeep: Color(hex: "0E7490")!,
        background: Color(hex: "04181F")!, backgroundSecondary: Color(hex: "08232C")!,
        surface: Color(hex: "0E2C36")!, surfaceElevated: Color(hex: "143844")!,
        textPrimary: .white, textSecondary: Color(white: 0.68), textTertiary: Color(white: 0.45),
        success: Color(hex: "34D399")!, warning: Color(hex: "FBBF24")!, danger: Color(hex: "F87171")!, info: Color(hex: "60A5FA")!,
        againColor: Color(hex: "F87171")!, hardColor: Color(hex: "FBBF24")!, goodColor: Color(hex: "34D399")!, easyColor: Color(hex: "60A5FA")!,
        isLight: false)

    static let sunset = ThemeColors(
        accent: Color(hex: "F97316")!, accentSecondary: Color(hex: "FB923C")!, accentDeep: Color(hex: "9A3412")!,
        background: Color(hex: "1A0E07")!, backgroundSecondary: Color(hex: "241409")!,
        surface: Color(hex: "2E1B0E")!, surfaceElevated: Color(hex: "3D2413")!,
        textPrimary: .white, textSecondary: Color(white: 0.70), textTertiary: Color(white: 0.48),
        success: Color(hex: "4ADE80")!, warning: Color(hex: "FACC15")!, danger: Color(hex: "EF4444")!, info: Color(hex: "38BDF8")!,
        againColor: Color(hex: "EF4444")!, hardColor: Color(hex: "FACC15")!, goodColor: Color(hex: "4ADE80")!, easyColor: Color(hex: "38BDF8")!,
        isLight: false)

    static let forest = ThemeColors(
        accent: Color(hex: "22C55E")!, accentSecondary: Color(hex: "4ADE80")!, accentDeep: Color(hex: "15803D")!,
        background: Color(hex: "06140C")!, backgroundSecondary: Color(hex: "0A1F12")!,
        surface: Color(hex: "102A1A")!, surfaceElevated: Color(hex: "163823")!,
        textPrimary: .white, textSecondary: Color(white: 0.68), textTertiary: Color(white: 0.45),
        success: Color(hex: "4ADE80")!, warning: Color(hex: "FACC15")!, danger: Color(hex: "F87171")!, info: Color(hex: "60A5FA")!,
        againColor: Color(hex: "F87171")!, hardColor: Color(hex: "FACC15")!, goodColor: Color(hex: "4ADE80")!, easyColor: Color(hex: "60A5FA")!,
        isLight: false)

    static let graphite = ThemeColors(
        accent: Color(hex: "9CA3AF")!, accentSecondary: Color(hex: "D1D5DB")!, accentDeep: Color(hex: "4B5563")!,
        background: Color(hex: "0A0A0A")!, backgroundSecondary: Color(hex: "141414")!,
        surface: Color(hex: "1C1C1E")!, surfaceElevated: Color(hex: "2C2C2E")!,
        textPrimary: .white, textSecondary: Color(white: 0.68), textTertiary: Color(white: 0.45),
        success: Color(hex: "34D399")!, warning: Color(hex: "FBBF24")!, danger: Color(hex: "F87171")!, info: Color(hex: "60A5FA")!,
        againColor: Color(hex: "F87171")!, hardColor: Color(hex: "FBBF24")!, goodColor: Color(hex: "34D399")!, easyColor: Color(hex: "60A5FA")!,
        isLight: false)

    static let light = ThemeColors(
        accent: Color(hex: "7C3AED")!, accentSecondary: Color(hex: "8B5CF6")!, accentDeep: Color(hex: "5B21B6")!,
        background: Color(hex: "F4F4F6")!, backgroundSecondary: Color(hex: "ECECF1")!,
        surface: Color(hex: "FFFFFF")!, surfaceElevated: Color(hex: "F6F6FA")!,
        textPrimary: Color(hex: "1C122B")!, textSecondary: Color(hex: "5A5468")!, textTertiary: Color(hex: "9A93AB")!,
        success: Color(hex: "16A34A")!, warning: Color(hex: "D97706")!, danger: Color(hex: "DC2626")!, info: Color(hex: "2563EB")!,
        againColor: Color(hex: "DC2626")!, hardColor: Color(hex: "D97706")!, goodColor: Color(hex: "16A34A")!, easyColor: Color(hex: "2563EB")!,
        isLight: true)

    // ---- New themes

    static let rose = ThemeColors(
        accent: Color(hex: "EC4899")!, accentSecondary: Color(hex: "F472B6")!, accentDeep: Color(hex: "9D174D")!,
        background: Color(hex: "1A0A14")!, backgroundSecondary: Color(hex: "240F1B")!,
        surface: Color(hex: "2E1626")!, surfaceElevated: Color(hex: "3D1E33")!,
        textPrimary: .white, textSecondary: Color(white: 0.70), textTertiary: Color(white: 0.48),
        success: Color(hex: "4ADE80")!, warning: Color(hex: "FACC15")!, danger: Color(hex: "F87171")!, info: Color(hex: "60A5FA")!,
        againColor: Color(hex: "F87171")!, hardColor: Color(hex: "FACC15")!, goodColor: Color(hex: "4ADE80")!, easyColor: Color(hex: "60A5FA")!,
        isLight: false)

    static let aurora = ThemeColors(
        accent: Color(hex: "14B8A6")!, accentSecondary: Color(hex: "2DD4BF")!, accentDeep: Color(hex: "0F766E")!,
        background: Color(hex: "04140F")!, backgroundSecondary: Color(hex: "08201A")!,
        surface: Color(hex: "0E2C24")!, surfaceElevated: Color(hex: "143830")!,
        textPrimary: .white, textSecondary: Color(white: 0.70), textTertiary: Color(white: 0.48),
        success: Color(hex: "4ADE80")!, warning: Color(hex: "FACC15")!, danger: Color(hex: "F87171")!, info: Color(hex: "60A5FA")!,
        againColor: Color(hex: "F87171")!, hardColor: Color(hex: "FACC15")!, goodColor: Color(hex: "4ADE80")!, easyColor: Color(hex: "60A5FA")!,
        isLight: false)

    static let sand = ThemeColors(
        accent: Color(hex: "D97706")!, accentSecondary: Color(hex: "F59E0B")!, accentDeep: Color(hex: "92400E")!,
        background: Color(hex: "FAF5EE")!, backgroundSecondary: Color(hex: "F1E9DC")!,
        surface: Color(hex: "FFFFFF")!, surfaceElevated: Color(hex: "FBF6EE")!,
        textPrimary: Color(hex: "3B2F1E")!, textSecondary: Color(hex: "6B5A3F")!, textTertiary: Color(hex: "9C8A6B")!,
        success: Color(hex: "16A34A")!, warning: Color(hex: "D97706")!, danger: Color(hex: "DC2626")!, info: Color(hex: "0E7490")!,
        againColor: Color(hex: "DC2626")!, hardColor: Color(hex: "D97706")!, goodColor: Color(hex: "16A34A")!, easyColor: Color(hex: "0E7490")!,
        isLight: true)

    static let slate = ThemeColors(
        accent: Color(hex: "475569")!, accentSecondary: Color(hex: "64748B")!, accentDeep: Color(hex: "334155")!,
        background: Color(hex: "F1F5F9")!, backgroundSecondary: Color(hex: "E2E8F0")!,
        surface: Color(hex: "FFFFFF")!, surfaceElevated: Color(hex: "F8FAFC")!,
        textPrimary: Color(hex: "0F172A")!, textSecondary: Color(hex: "475569")!, textTertiary: Color(hex: "94A3B8")!,
        success: Color(hex: "16A34A")!, warning: Color(hex: "D97706")!, danger: Color(hex: "DC2626")!, info: Color(hex: "0EA5E9")!,
        againColor: Color(hex: "DC2626")!, hardColor: Color(hex: "D97706")!, goodColor: Color(hex: "16A34A")!, easyColor: Color(hex: "0EA5E9")!,
        isLight: true)
}

// MARK: - AppTheme (reflects the currently selected preset)

enum AppTheme {
    static var currentPreset: ThemePreset = {
        ThemePreset(rawValue: UserDefaults.standard.string(forKey: "themePreset") ?? "") ?? .midnight
    }()

    static var currentReviewFontKey: String = {
        UserDefaults.standard.string(forKey: "reviewFont") ?? ReviewFont.rounded.rawValue
    }()

    private static var c: ThemeColors { currentPreset.colors }

    // Colors (computed so they track the live preset)
    static var accent: Color { c.accent }
    static var accentSecondary: Color { c.accentSecondary }
    static var accentDeep: Color { c.accentDeep }
    static var background: Color { c.background }
    static var backgroundSecondary: Color { c.backgroundSecondary }
    static var surface: Color { c.surface }
    static var surfaceElevated: Color { c.surfaceElevated }
    static var textPrimary: Color { c.textPrimary }
    static var textSecondary: Color { c.textSecondary }
    static var textTertiary: Color { c.textTertiary }
    static var success: Color { c.success }
    static var warning: Color { c.warning }
    static var danger: Color { c.danger }
    static var info: Color { c.info }
    static var againColor: Color { c.againColor }
    static var hardColor: Color { c.hardColor }
    static var goodColor: Color { c.goodColor }
    static var easyColor: Color { c.easyColor }
    static var isLightTheme: Bool { c.isLight }
    static var preferredColorScheme: ColorScheme { c.isLight ? .light : .dark }

    // Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // Corner Radii
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 20
    static let radiusXL: CGFloat = 28

    // Fonts (chrome)
    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    static func heading(_ size: CGFloat = 20) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .rounded)
    }
    static func caption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }
    static func mono(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    /// User-selectable font applied to review card faces (Settings → Display).
    /// Supports the four Font.Design variants plus eight named iOS system
    /// fonts, for a comprehensive list.
    static func reviewFont(_ size: CGFloat = 24) -> Font {
        switch ReviewFont(rawValue: currentReviewFontKey) ?? .rounded {
        case .rounded:       return .system(size: size, weight: .semibold, design: .rounded)
        case .serif:         return .system(size: size, weight: .semibold, design: .serif)
        case .mono:          return .system(size: size, weight: .medium, design: .monospaced)
        case .standard:      return .system(size: size, weight: .semibold, design: .default)
        case .avenir:        return .custom("AvenirNext-Medium", size: size)
        case .futura:        return .custom("Futura-Medium", size: size)
        case .gillSans:      return .custom("GillSans-SemiBold", size: size)
        case .optima:        return .custom("Optima-Bold", size: size)
        case .palatino:      return .custom("Palatino-Bold", size: size)
        case .helveticaNeue: return .custom("HelveticaNeue-Medium", size: size)
        case .georgia:       return .custom("Georgia-Bold", size: size)
        case .menlo:         return .custom("Menlo-Bold", size: size)
        }
    }
}

// MARK: - AppSettings (single source of truth for all user preferences)

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var themePreset: ThemePreset {
        didSet {
            UserDefaults.standard.set(themePreset.rawValue, forKey: "themePreset")
            AppTheme.currentPreset = themePreset
        }
    }

    @Published var reviewFont: ReviewFont {
        didSet {
            UserDefaults.standard.set(reviewFont.rawValue, forKey: "reviewFont")
            AppTheme.currentReviewFontKey = reviewFont.rawValue
        }
    }

    @Published var language: String {
        didSet { Localization.setLanguage(language) }
    }

    @Published var countdownEnabled: Bool {
        didSet { UserDefaults.standard.set(countdownEnabled, forKey: "reviewCountdownEnabled") }
    }

    @Published var countdownSeconds: Int {
        didSet { UserDefaults.standard.set(countdownSeconds, forKey: "reviewCountdownSeconds") }
    }

    // ---- Custom review intervals (replaces the old multipliers) ----
    //
    // Stored as JSON-encoded CustomInterval values in UserDefaults. When
    // `enabled`, FSRS pins the next-review date to `now + interval`, ignoring
    // the algorithmically computed interval. When disabled, FSRS uses its
    // default scheduling. Initial values mirror FSRS defaults (Again=10min,
    // Hard/Good/Easy disabled) so the app behaves like stock FSRS until the
    // user opts in.

    @Published var intervalAgain: CustomInterval {
        didSet { saveInterval(intervalAgain, forKey: "intervalAgain") }
    }
    @Published var intervalHard: CustomInterval {
        didSet { saveInterval(intervalHard, forKey: "intervalHard") }
    }
    @Published var intervalGood: CustomInterval {
        didSet { saveInterval(intervalGood, forKey: "intervalGood") }
    }
    @Published var intervalEasy: CustomInterval {
        didSet { saveInterval(intervalEasy, forKey: "intervalEasy") }
    }

    init() {
        let tp = ThemePreset(rawValue: UserDefaults.standard.string(forKey: "themePreset") ?? "") ?? .midnight
        self.themePreset = tp
        AppTheme.currentPreset = tp

        let rf = ReviewFont(rawValue: UserDefaults.standard.string(forKey: "reviewFont") ?? "") ?? .rounded
        self.reviewFont = rf
        AppTheme.currentReviewFontKey = rf.rawValue

        self.language = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"

        if UserDefaults.standard.object(forKey: "reviewCountdownEnabled") != nil {
            self.countdownEnabled = UserDefaults.standard.bool(forKey: "reviewCountdownEnabled")
        } else {
            self.countdownEnabled = false
        }

        self.countdownSeconds = (UserDefaults.standard.object(forKey: "reviewCountdownSeconds") as? Int) ?? 15

        self.intervalAgain = AppSettings.loadInterval(forKey: "intervalAgain", default: .defaultAgain)
        self.intervalHard  = AppSettings.loadInterval(forKey: "intervalHard",  default: .defaultHard)
        self.intervalGood  = AppSettings.loadInterval(forKey: "intervalGood",  default: .defaultGood)
        self.intervalEasy  = AppSettings.loadInterval(forKey: "intervalEasy",  default: .defaultEasy)
    }

    func interval(for rating: Rating) -> CustomInterval {
        switch rating {
        case .again: return intervalAgain
        case .hard:  return intervalHard
        case .good:  return intervalGood
        case .easy:  return intervalEasy
        }
    }

    func resetIntervals() {
        intervalAgain = .defaultAgain
        intervalHard  = .defaultHard
        intervalGood  = .defaultGood
        intervalEasy  = .defaultEasy
    }

    // MARK: - Persistence helpers

    private func saveInterval(_ interval: CustomInterval, forKey key: String) {
        if let data = try? JSONEncoder().encode(interval),
           let s = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(s, forKey: key)
        }
    }

    private static func loadInterval(forKey key: String, default fallback: CustomInterval) -> CustomInterval {
        guard let s = UserDefaults.standard.string(forKey: key),
              let data = s.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(CustomInterval.self, from: data) else {
            return fallback
        }
        return decoded
    }
}

// MARK: - View Modifiers

extension View {
    func primaryGradientBackground() -> some View {
        background(
            LinearGradient(
                colors: [AppTheme.background, AppTheme.backgroundSecondary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    /// Filled accent button used across the app. Name kept for backward
    /// compatibility with existing call sites.
    func violetAccentButton() -> some View {
        self
            .foregroundColor(.white)
            .padding(.horizontal, AppTheme.spacingL)
            .padding(.vertical, AppTheme.spacingM)
            .background(
                LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accentSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: AppTheme.accent.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Interval Formatting

func formatInterval(_ days: Int) -> String {
    if days == 0 { return "<1d" }
    if days < 30 { return "\(days)d" }
    if days < 365 { return String(format: "%.1fmo", Double(days) / 30.0) }
    return String(format: "%.1fy", Double(days) / 365.0)
}
