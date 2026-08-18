import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    generalSection
                    displaySection
                    reviewSection
                    aboutSection
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingS)
                .padding(.bottom, AppTheme.spacingXL)
            }
            .primaryGradientBackground()
            .navigationTitle(L("settings.title"))
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            sectionHeader(title: L("settings.general"), icon: "gearshape.fill")

            VStack(spacing: 0) {
                // Language
                HStack(spacing: AppTheme.spacingM) {
                    Image(systemName: "globe")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 28)
                    Text(L("settings.language"))
                        .font(AppTheme.body(16))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Menu {
                        Button { settings.language = "en" } label: {
                            Label(L("settings.language.english"),
                                  systemImage: settings.language == "en" ? "checkmark" : "")
                        }
                        Button { settings.language = "fr" } label: {
                            Label(L("settings.language.french"),
                                  systemImage: settings.language == "fr" ? "checkmark" : "")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(currentLanguageName)
                                .font(AppTheme.body(15))
                                .foregroundColor(AppTheme.textSecondary)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                    }
                }
                .padding(AppTheme.spacingM)

                Divider().background(AppTheme.surfaceElevated).padding(.leading, 52)
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL,
                                        style: .continuous))

            Text(L("settings.language.note"))
                .font(AppTheme.caption(11))
                .foregroundColor(AppTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    private var currentLanguageName: String {
        switch settings.language {
        case "fr": return L("settings.language.french")
        default:   return L("settings.language.english")
        }
    }

    // MARK: - Display (themes + fonts)

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            sectionHeader(title: L("settings.display"), icon: "paintbrush.fill")

            VStack(spacing: AppTheme.spacingM) {
                // Theme picker — full grid of all 10 themes
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    Text(L("settings.theme"))
                        .font(AppTheme.body(16))
                        .foregroundColor(AppTheme.textPrimary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(ThemePreset.allCases) { preset in
                                Button {
                                    settings.themePreset = preset
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [preset.colors.accent,
                                                                 preset.colors.accentSecondary],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 44, height: 44)
                                            if settings.themePreset == preset {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                        Text(preset.displayName)
                                            .font(AppTheme.caption(10))
                                            .foregroundColor(settings.themePreset == preset
                                                             ? AppTheme.textPrimary
                                                             : AppTheme.textTertiary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }

                Divider().background(AppTheme.surfaceElevated)

                // Review font — full list with live preview
                VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                    HStack(spacing: AppTheme.spacingM) {
                        Image(systemName: "textformat")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.accent)
                            .frame(width: 28)
                        Text(L("settings.font"))
                            .font(AppTheme.body(16))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }

                    // Live preview of the currently selected font
                    HStack {
                        Spacer()
                        Text(ReviewFont.previewText)
                            .font(AppTheme.reviewFont(22))
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                    }
                    .padding(AppTheme.spacingM)
                    .background(AppTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                style: .continuous))

                    // Selectable list — tapping a row instantly updates the
                    // preview above so the user can compare fonts.
                    VStack(spacing: 0) {
                        ForEach(ReviewFont.allCases) { font in
                            Button {
                                settings.reviewFont = font
                            } label: {
                                HStack(spacing: AppTheme.spacingM) {
                                    Text(font.displayName)
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Text(ReviewFont.previewText)
                                        .font(fontPreviewFont(font, size: 16))
                                        .foregroundColor(AppTheme.textSecondary)
                                    if settings.reviewFont == font {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppTheme.accent)
                                    }
                                }
                                .padding(.vertical, AppTheme.spacingS)
                                .padding(.horizontal, AppTheme.spacingM)
                            }
                            .buttonStyle(.plain)

                            if font != ReviewFont.allCases.last {
                                Divider().background(AppTheme.surfaceElevated).padding(.leading, AppTheme.spacingM)
                            }
                        }
                    }
                    .background(AppTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                style: .continuous))
                }

                Divider().background(AppTheme.surfaceElevated)

                // Countdown toggle
                VStack(spacing: AppTheme.spacingS) {
                    Toggle(isOn: $settings.countdownEnabled) {
                        HStack(spacing: AppTheme.spacingM) {
                            Image(systemName: "timer")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("settings.countdown"))
                                    .font(AppTheme.body(16))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(L("settings.countdown.desc"))
                                    .font(AppTheme.caption(11))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }
                    }
                    .tint(AppTheme.accent)

                    if settings.countdownEnabled {
                        HStack {
                            Text(L("settings.countdown.seconds"))
                                .font(AppTheme.caption(13))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Stepper(value: $settings.countdownSeconds,
                                    in: 5...120, step: 5) {
                                Text("\(settings.countdownDetails)")
                                    .font(AppTheme.mono(14))
                                    .foregroundColor(AppTheme.accent)
                            }
                        }
                        .padding(.leading, 46)
                    }
                }
            }
            .padding(AppTheme.spacingM)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL,
                                        style: .continuous))
        }
    }

    /// Maps a `ReviewFont` case to the actual SwiftUI Font used both in the
    /// review card face and the preview row in Settings.
    private func fontPreviewFont(_ font: ReviewFont, size: CGFloat) -> Font {
        switch font {
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

    // MARK: - Review (custom intervals — replaces multipliers)

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            sectionHeader(title: L("settings.review"), icon: "repeat")

            VStack(spacing: AppTheme.spacingM) {
                Text(L("settings.intervals.desc"))
                    .font(AppTheme.caption(12))
                    .foregroundColor(AppTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                intervalEditor(label: L("rating.again"),
                               color: AppTheme.againColor,
                               interval: $settings.intervalAgain)
                intervalEditor(label: L("rating.hard"),
                               color: AppTheme.hardColor,
                               interval: $settings.intervalHard)
                intervalEditor(label: L("rating.good"),
                               color: AppTheme.goodColor,
                               interval: $settings.intervalGood)
                intervalEditor(label: L("rating.easy"),
                               color: AppTheme.easyColor,
                               interval: $settings.intervalEasy)

                Button {
                    settings.resetIntervals()
                } label: {
                    Text(L("settings.reset"))
                        .font(AppTheme.caption(14))
                        .foregroundColor(AppTheme.accent)
                }
            }
            .padding(AppTheme.spacingM)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL,
                                        style: .continuous))
        }
    }

    private func intervalEditor(label: String, color: Color,
                                interval: Binding<CustomInterval>) -> some View {
        VStack(spacing: AppTheme.spacingS) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(AppTheme.body(15))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(interval.wrappedValue.summary)
                    .font(AppTheme.mono(13))
                    .foregroundColor(interval.wrappedValue.enabled ? color : AppTheme.textTertiary)
            }

            // Enable toggle
            Toggle(isOn: Binding(
                get: { interval.wrappedValue.enabled },
                set: { interval.wrappedValue.enabled = $0 }
            )) {
                Text(L("interval.useCustom"))
                    .font(AppTheme.caption(13))
                    .foregroundColor(AppTheme.textSecondary)
            }
            .tint(color)

            if interval.wrappedValue.enabled {
                // Value stepper
                HStack {
                    Text(L("interval.value"))
                        .font(AppTheme.caption(13))
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Stepper(value: Binding(
                        get: { interval.wrappedValue.value },
                        set: { interval.wrappedValue.value = max(1, $0) }
                    ), in: 1...365, step: 1) {
                        Text("\(interval.wrappedValue.value)")
                            .font(AppTheme.mono(14))
                            .foregroundColor(color)
                    }
                }

                // Unit picker (segmented)
                Picker(L("interval.unit"), selection: Binding(
                    get: { interval.wrappedValue.unit },
                    set: { interval.wrappedValue.unit = $0 }
                )) {
                    ForEach(IntervalUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .tint(color)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            sectionHeader(title: L("settings.about"), icon: "info.circle.fill")

            HStack {
                Text(L("settings.about.version"))
                    .font(AppTheme.body(15))
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
                Text(appVersion)
                    .font(AppTheme.mono(14))
                    .foregroundColor(AppTheme.textPrimary)
            }
            .padding(AppTheme.spacingM)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL,
                                        style: .continuous))
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    // MARK: - Helpers

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: AppTheme.spacingS) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(AppTheme.accent)
            Text(title)
                .font(AppTheme.heading(16))
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// Small helper used in SettingsView — computed property so the @Published
// change triggers a re-render.
extension AppSettings {
    var countdownDetails: String {
        "\(countdownSeconds)s"
    }
}
