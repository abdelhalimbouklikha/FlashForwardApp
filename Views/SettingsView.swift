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
        }
    }

    private var currentLanguageName: String {
        switch settings.language {
        case "fr": return L("settings.language.french")
        default:   return L("settings.language.english")
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            sectionHeader(title: L("settings.display"), icon: "paintbrush.fill")

            VStack(spacing: AppTheme.spacingM) {
                // Theme picker
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

                // Review font
                HStack(spacing: AppTheme.spacingM) {
                    Image(systemName: "textformat")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 28)
                    Text(L("settings.font"))
                        .font(AppTheme.body(16))
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    Picker(L("settings.font"), selection: $settings.reviewFont) {
                        ForEach(ReviewFont.allCases) { font in
                            Text(font.displayName).tag(font)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(AppTheme.accent)
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

    // MARK: - Review (FSRS multipliers)

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingM) {
            sectionHeader(title: L("settings.review"), icon: "repeat")

            VStack(spacing: AppTheme.spacingM) {
                Text(L("settings.multipliers.desc"))
                    .font(AppTheme.caption(12))
                    .foregroundColor(AppTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                multiplierRow(label: L("rating.again"),
                              value: $settings.multAgain,
                              color: AppTheme.againColor)
                multiplierRow(label: L("rating.hard"),
                              value: $settings.multHard,
                              color: AppTheme.hardColor)
                multiplierRow(label: L("rating.good"),
                              value: $settings.multGood,
                              color: AppTheme.goodColor)
                multiplierRow(label: L("rating.easy"),
                              value: $settings.multEasy,
                              color: AppTheme.easyColor)

                Button {
                    settings.multAgain = 1.0
                    settings.multHard = 1.0
                    settings.multGood = 1.0
                    settings.multEasy = 1.0
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

    private func multiplierRow(label: String, value: Binding<Double>,
                               color: Color) -> some View {
        VStack(spacing: AppTheme.spacingS) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(AppTheme.body(15))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(String(format: "%.2f×", value.wrappedValue))
                    .font(AppTheme.mono(14))
                    .foregroundColor(color)
            }
            Slider(value: value, in: 0.25...3.0, step: 0.05)
                .tint(color)
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