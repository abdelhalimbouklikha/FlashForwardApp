import SwiftUI
import SwiftData
import os

struct AddEditDeckView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\DeckFolder.name)]) var folders: [DeckFolder]

    var deck: Deck? = nil

    @State private var name: String = ""
    @State private var color: Color = AppTheme.accent
    @State private var selectedFolderID: String = ""
    @State private var showingNewFolder = false
    @State private var newFolderName = ""
    @FocusState private var nameFocused: Bool

    private let presetColors = [
        "7C3AED", "06B6D4", "F97316", "22C55E",
        "EF4444", "EC4899", "FACC15", "64748B"
    ]

    private var isEditing: Bool { deck != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    // Name
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Label(L("deck.name"), systemImage: "textformat")
                            .font(AppTheme.caption(13))
                            .foregroundColor(AppTheme.textSecondary)
                        TextField(L("deck.name"), text: $name)
                            .font(AppTheme.body(18))
                            .focused($nameFocused)
                            .padding(AppTheme.spacingM)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                        style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                 style: .continuous)
                                    .stroke(nameFocused
                                            ? AppTheme.accent.opacity(0.6)
                                            : Color.clear,
                                            lineWidth: 2)
                            )
                    }

                    // Color
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Label(L("deck.color"), systemImage: "paintpalette.fill")
                            .font(AppTheme.caption(13))
                            .foregroundColor(AppTheme.textSecondary)

                        HStack(spacing: AppTheme.spacingM) {
                            Circle()
                                .fill(color)
                                .frame(width: 32, height: 32)
                                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
                            ColorPicker("", selection: $color, supportsOpacity: false)
                                .labelsHidden()
                            Spacer()
                        }
                        .padding(AppTheme.spacingM)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                    style: .continuous))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(presetColors, id: \.self) { hex in
                                    Button {
                                        color = Color(hex: hex) ?? AppTheme.accent
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: hex) ?? AppTheme.accent)
                                            .frame(width: 30, height: 30)
                                            .overlay(
                                                Circle().stroke(
                                                    color.toHexString() == hex
                                                        ? .white : .clear,
                                                    lineWidth: 2)
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }

                    // Folder
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        HStack {
                            Label(L("deck.folder"), systemImage: "folder.fill")
                                .font(AppTheme.caption(13))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Button {
                                newFolderName = ""
                                showingNewFolder = true
                            } label: {
                                Label(L("deck.newFolder"), systemImage: "plus.circle")
                                    .font(AppTheme.caption(13))
                                    .foregroundColor(AppTheme.accent)
                            }
                        }

                        Picker(L("deck.folder"), selection: $selectedFolderID) {
                            Text(L("deck.folder.none")).tag("")
                            ForEach(folders) { folder in
                                Text(folder.name).tag(folder.id.uuidString)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppTheme.accent)
                        .padding(AppTheme.spacingM)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                    style: .continuous))
                    }
                }
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.top, AppTheme.spacingM)
            }
            .primaryGradientBackground()
            .navigationTitle(isEditing ? L("deck.rename") : L("deck.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.cancel")) { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        save()
                    } label: {
                        Text(L("common.save"))
                            .font(AppTheme.heading(16))
                            .foregroundColor(canSave ? AppTheme.accent : AppTheme.textTertiary)
                    }
                    .disabled(!canSave)
                }
            }
            .alert(L("deck.newFolder"), isPresented: $showingNewFolder) {
                TextField(L("deck.folder"), text: $newFolderName)
                Button(L("common.cancel"), role: .cancel) { newFolderName = "" }
                Button(L("common.create")) { createFolder() }
            }
            .onAppear { loadDeck() }
        }
    }

    private func loadDeck() {
        if let deck = deck {
            name = deck.name
            color = Color(hex: deck.colorHex) ?? AppTheme.accent
            selectedFolderID = deck.folder?.id.uuidString ?? ""
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                nameFocused = true
            }
        }
    }

    private func createFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let folder = DeckFolder(name: trimmed)
        modelContext.insert(folder)
        do { try modelContext.save() } catch { AppLog.decks.error("Failed to create folder: \(error.localizedDescription, privacy: .public)") }
        selectedFolderID = folder.id.uuidString
        newFolderName = ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let hex = color.toHexString()
        let folder = folders.first { $0.id.uuidString == selectedFolderID }

        if let deck = deck {
            deck.name = trimmedName
            deck.colorHex = hex
            deck.folder = folder
        } else {
            let newDeck = Deck(name: trimmedName, colorHex: hex, folder: folder)
            modelContext.insert(newDeck)
        }

        do { try modelContext.save() } catch { AppLog.decks.error("Failed to save deck: \(error.localizedDescription, privacy: .public)") }
        dismiss()
    }
}
