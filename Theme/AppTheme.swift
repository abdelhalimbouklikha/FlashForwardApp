import SwiftUI

enum AppTheme {
    // MARK: - Colors
    static let accent = Color(red: 0.486, green: 0.227, blue: 0.929)
    static let accentSecondary = Color(red: 0.541, green: 0.361, blue: 0.949)
    static let accentDeep = Color(red: 0.30, green: 0.13, blue: 0.55)
    static let background = Color(red: 0.05, green: 0.03, blue: 0.09)
    static let backgroundSecondary = Color(red: 0.08, green: 0.05, blue: 0.14)
    static let surface = Color(red: 0.11, green: 0.07, blue: 0.17)
    static let surfaceElevated = Color(red: 0.15, green: 0.10, blue: 0.22)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.68)
    static let textTertiary = Color(white: 0.45)
    static let success = Color(red: 0.30, green: 0.80, blue: 0.50)
    static let warning = Color(red: 0.95, green: 0.73, blue: 0.30)
    static let danger = Color(red: 0.92, green: 0.35, blue: 0.35)
    static let info = Color(red: 0.35, green: 0.65, blue: 0.95)

    // Rating colors
    static let againColor = Color(red: 0.92, green: 0.35, blue: 0.40)
    static let hardColor = Color(red: 0.95, green: 0.65, blue: 0.30)
    static let goodColor = Color(red: 0.35, green: 0.80, blue: 0.50)
    static let easyColor = Color(red: 0.35, green: 0.65, blue: 0.95)

    // MARK: - Spacing
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 16
    static let spacingL: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Corner Radii
    static let radiusS: CGFloat = 8
    static let radiusM: CGFloat = 12
    static let radiusL: CGFloat = 20
    static let radiusXL: CGFloat = 28

    // MARK: - Fonts
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