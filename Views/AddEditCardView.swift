import SwiftUI
import SwiftData

struct AddEditCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var deck: Deck
    var card: Card? = nil

    @State private var front: String = ""
    @State private var back: String = ""
    @FocusState private var frontFocused: Bool
    @FocusState private var backFocused: Bool

    private var isEditing: Bool { card != nil }
    private var canSave: Bool {
        !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    cardEditorSection(
                        title: "Front",
                        titleIcon: "arrow.right.circle.fill",
                        text: $front,
                        isFocused: $frontFocused,
                        placeholder: "What do you want to remember?",
                        minHeight: 120
                    )

                    cardEditorSection(
                        title: "Back",
                        titleIcon: "lightbulb.fill",
                        text: $back,
                        isFocused: $backFocused,
                        placeholder: "The answer or explanation...",
                        minHeight: 120
                    )

                    if isEditing, let card = card, card.reps > 0 {
                        HStack {
                            statItem(label: "Reviews", value: "\(card.reps)")
                            Divider().frame(height: 30)
                            statItem(label: "Lapses", value: "\(card.lapses)")
                            Divider().frame(height: 30)
                            statItem(label: "Interval", value: formatInterval(card.scheduledDays))
                        }
                        .padding(AppTheme.spacingM)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingM)
            }
            .primaryGradientBackground()
            .navigationTitle(isEditing ? "Edit Card" : "New Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        save()
                    } label: {
                        Text("Save")
                            .font(AppTheme.heading(16))
                            .foregroundColor(canSave ? AppTheme.accent : AppTheme.textTertiary)
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if let card = card {
                    front = card.front
                    back = card.back
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        frontFocused = true
                    }
                }
            }
        }
    }

    private func cardEditorSection(
        title: String,
        titleIcon: String,
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        placeholder: String,
        minHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack(spacing: AppTheme.spacingS) {
                Image(systemName: titleIcon)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.accent)
                Text(title)
                    .font(AppTheme.heading(16))
                    .foregroundColor(AppTheme.textPrimary)
            }

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(AppTheme.body(16))
                        .foregroundColor(AppTheme.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }

                TextEditor(text: text)
                    .focused(isFocused)
                    .font(AppTheme.body(16))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: minHeight)
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                    .stroke(isFocused.wrappedValue ? AppTheme.accent.opacity(0.6) : Color.clear, lineWidth: 2)
            )
        }
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AppTheme.heading(18))
                .foregroundColor(AppTheme.textPrimary)
            Text(label)
                .font(AppTheme.caption(11))
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        let trimmedFront = front.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBack = back.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFront.isEmpty && !trimmedBack.isEmpty else { return }

        if let card = card {
            card.front = trimmedFront
            card.back = trimmedBack
        } else {
            let newCard = Card(front: trimmedFront, back: trimmedBack, deck: deck)
            modelContext.insert(newCard)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save card: \(error)")
        }

        dismiss()
    }
}