import SwiftUI
import EventKit

/// Sheet for scheduling a calendar revision event for a specific deck, with
/// both a date AND a time picker. Optionally schedules an alarm (EKAlarm at
/// the event start) and a local notification so the user is reminded at the
/// chosen moment — all via EventKit + UNUserNotificationCenter, both of which
/// work with a free Apple developer account.
struct ScheduleRevisionView: View {
    let deck: Deck
    @Environment(\.dismiss) private var dismiss

    @State private var scheduledDate: Date = Date().addingTimeInterval(3600) // +1h by default
    @State private var durationMinutes: Int = 30
    @State private var withAlarm: Bool = true
    @State private var withLocalNotification: Bool = true
    @State private var isWorking: Bool = false
    @State private var resultMessage: String? = nil
    @State private var resultIsError: Bool = false
    @State private var calendarDenied: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    iconHeader

                    infoCard

                    // Date + time
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Label(L("schedule.date"), systemImage: "calendar")
                            .font(AppTheme.heading(16))
                            .foregroundColor(AppTheme.textPrimary)

                        DatePicker(L("schedule.date"), selection: $scheduledDate,
                                   in: Date()..., displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(AppTheme.accent)
                            .padding(AppTheme.spacingM)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                        style: .continuous))
                    }

                    // Duration
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Label(L("schedule.duration"), systemImage: "clock")
                            .font(AppTheme.heading(16))
                            .foregroundColor(AppTheme.textPrimary)

                        Picker(L("schedule.duration"), selection: $durationMinutes) {
                            Text("15 \(L("interval.unit.minutes"))").tag(15)
                            Text("30 \(L("interval.unit.minutes"))").tag(30)
                            Text("45 \(L("interval.unit.minutes"))").tag(45)
                            Text("60 \(L("interval.unit.minutes"))").tag(60)
                            Text("90 \(L("interval.unit.minutes"))").tag(90)
                        }
                        .pickerStyle(.segmented)
                        .tint(AppTheme.accent)
                    }

                    // Alarms / notifications
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Label(L("schedule.reminders"), systemImage: "bell.badge")
                            .font(AppTheme.heading(16))
                            .foregroundColor(AppTheme.textPrimary)

                        Toggle(isOn: $withAlarm) {
                            Text(L("schedule.calendarAlarm"))
                                .font(AppTheme.body(15))
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .tint(AppTheme.accent)

                        Toggle(isOn: $withLocalNotification) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("schedule.localNotification"))
                                    .font(AppTheme.body(15))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(L("schedule.localNotification.desc"))
                                    .font(AppTheme.caption(11))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                        }
                        .tint(AppTheme.accent)
                    }
                    .padding(AppTheme.spacingM)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL,
                                                style: .continuous))

                    // Result / error message
                    if let msg = resultMessage {
                        Text(msg)
                            .font(AppTheme.caption(13))
                            .foregroundColor(resultIsError ? AppTheme.danger : AppTheme.success)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppTheme.spacingM)
                            .background((resultIsError ? AppTheme.danger : AppTheme.success).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                         style: .continuous))
                    }

                    Spacer(minLength: 0)

                    Button {
                        Task { await schedule() }
                    } label: {
                        HStack(spacing: AppTheme.spacingS) {
                            if isWorking {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(L("schedule.create"))
                                .font(AppTheme.heading(16))
                        }
                        .frame(maxWidth: .infinity)
                        .violetAccentButton()
                    }
                    .buttonStyle(.plain)
                    .disabled(isWorking)
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingM)
                .padding(.bottom, AppTheme.spacingXL)
            }
            .primaryGradientBackground()
            .navigationTitle(L("schedule.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.cancel")) { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .alert(L("schedule.calendarDenied"), isPresented: $calendarDenied) {
                Button(L("common.ok"), role: .cancel) {}
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Button(L("schedule.openSettings")) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text(L("schedule.calendarDeniedMsg"))
            }
        }
    }

    // MARK: - Subviews

    private var iconHeader: some View {
        VStack(spacing: AppTheme.spacingS) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent.opacity(0.2), AppTheme.accent.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 88, height: 88)
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundColor(AppTheme.accent)
            }
            Text(String(format: L("schedule.deck"), deck.name))
                .font(AppTheme.heading(15))
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var infoCard: some View {
        HStack(spacing: AppTheme.spacingM) {
            statCell(value: "\(deck.cards.count)", label: L("schedule.info.cards"))
            Divider().frame(height: 36)
            statCell(value: "\(deck.dueCount)", label: L("schedule.info.due"))
            Divider().frame(height: 36)
            statCell(value: formattedDate, label: L("schedule.info.when"))
        }
        .padding(AppTheme.spacingM)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTheme.heading(15))
                .foregroundColor(AppTheme.textPrimary)
                .lineLimit(1)
            Text(label)
                .font(AppTheme.caption(10))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedDate: String {
        scheduledDate.formatted(date: .abbreviated, time: .shortened)
    }

    // MARK: - Scheduling

    @MainActor
    private func schedule() async {
        isWorking = true
        defer { isWorking = false }

        let status = await CalendarService.shared.requestAccess()
        if status != .granted {
            calendarDenied = true
            return
        }

        // Optionally ask for notification authorization up front.
        if withLocalNotification {
            _ = await CalendarService.shared.requestNotificationAuthorization()
        }

        let success = CalendarService.shared.createRevisionEvent(
            for: deck,
            at: scheduledDate,
            durationMinutes: durationMinutes,
            withAlarm: withAlarm
        )

        if withLocalNotification {
            _ = CalendarService.shared.scheduleLocalReminder(for: deck, at: scheduledDate)
        }

        if success {
            resultIsError = false
            resultMessage = String(format: L("schedule.success"), formattedDate)
            // Auto-dismiss after a short delay so the user sees the confirmation.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        } else {
            resultIsError = true
            resultMessage = L("schedule.failure")
        }
    }
}
