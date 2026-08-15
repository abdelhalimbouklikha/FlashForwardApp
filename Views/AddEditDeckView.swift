import SwiftUI

struct AddEditDeckView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var deck: Deck? = nil

    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool { deck != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacingL) {
                TextField("Deck Name", text: $name)
                    .font(AppTheme.body(18))
                    .focused($nameFocused)
                    .padding(AppTheme.spacingM)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                            .stroke(nameFocused ? AppTheme.accent.opacity(0.6) : Color.clear, lineWidth: 2)
                    )
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.top, AppTheme.spacingM)

                Spacer()
            }
            .primaryGradientBackground()
            .navigationTitle(isEditing ? "Rename Deck" : "New Deck")
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
                if let deck = deck {
                    name = deck.name
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        nameFocused = true
                    }
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let deck = deck {
            deck.name = trimmedName
        } else {
            let newDeck = Deck(name: trimmedName)
            modelContext.insert(newDeck)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save deck: \(error)")
        }

        dismiss()
    }
}