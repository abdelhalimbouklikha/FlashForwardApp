import SwiftUI
import SwiftData
import os

/// Lists all folders, lets the user rename them, and delete them.
///
/// Deleting a folder does NOT delete its decks — decks are automatically
/// "ungrouped" (their `folder` property is set to `nil`). This is safer than
/// cascading deletes and preserves the user's card content. We chose
/// automatic ungrouping over a confirmation dialog because:
///   1. The folder is purely an organizational hint — losing it should never
///      destroy study data.
///   2. The SwiftData `DeckFolder` model already declares
///      `deleteRule: .nullify` on its `decks` relationship, so the data layer
///      enforces this behavior for free.
struct FolderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\DeckFolder.name)]) var folders: [DeckFolder]

    @State private var folderToRename: DeckFolder? = nil
    @State private var renameText: String = ""
    @State private var showingRenameAlert = false
    @State private var folderToDelete: DeckFolder? = nil
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if folders.isEmpty {
                    EmptyStateView(
                        icon: "folder.badge.plus",
                        title: L("folders.empty.title"),
                        message: L("folders.empty.message")
                    )
                } else {
                    folderList
                }
            }
            .primaryGradientBackground()
            .navigationTitle(L("folders.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("common.done")) { dismiss() }
                        .foregroundColor(AppTheme.accent)
                }
            }
            .alert(L("folders.rename.title"), isPresented: $showingRenameAlert) {
                TextField(L("folders.name"), text: $renameText)
                Button(L("common.cancel"), role: .cancel) { renameText = "" }
                Button(L("common.save")) { confirmRename() }
            }
            .alert(L("folders.delete.title"), isPresented: $showingDeleteConfirm) {
                Button(L("common.cancel"), role: .cancel) { folderToDelete = nil }
                Button(L("common.delete"), role: .destructive) {
                    if let folder = folderToDelete {
                        deleteFolder(folder)
                    }
                }
            } message: {
                if let folder = folderToDelete {
                    Text(String(format: L("folders.delete.message"),
                                folder.name, folder.decks.count))
                }
            }
        }
    }

    private var folderList: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingM) {
                ForEach(folders) { folder in
                    Button {
                        folderToRename = folder
                        renameText = folder.name
                        showingRenameAlert = true
                    } label: {
                        HStack(spacing: AppTheme.spacingM) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppTheme.accent.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(AppTheme.accent)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text(folder.name)
                                    .font(AppTheme.heading(17))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)

                                HStack(spacing: AppTheme.spacingM) {
                                    Label(String(format: L("folders.decks.count"), folder.decks.count),
                                          systemImage: "rectangle.stack")
                                        .font(AppTheme.caption(12))
                                        .foregroundColor(AppTheme.textSecondary)

                                    Label(String(format: L("folders.cards.count"), folder.totalCards),
                                          systemImage: "card.fill")
                                        .font(AppTheme.caption(12))
                                        .foregroundColor(AppTheme.textSecondary)

                                    if folder.dueCount > 0 {
                                        Label(String(format: L("folders.due.count"), folder.dueCount),
                                              systemImage: "clock.fill")
                                            .font(AppTheme.caption(12))
                                            .foregroundColor(AppTheme.accent)
                                    }
                                }
                            }

                            Spacer()

                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .padding(AppTheme.spacingM)
                        .background(AppTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            folderToRename = folder
                            renameText = folder.name
                            showingRenameAlert = true
                        } label: {
                            Label(L("common.rename"), systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            folderToDelete = folder
                            showingDeleteConfirm = true
                        } label: {
                            Label(L("common.delete"), systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.spacingM)
            .padding(.top, AppTheme.spacingS)
            .padding(.bottom, AppTheme.spacingXL)
        }
    }

    private func confirmRename() {
        guard let folder = folderToRename else { return }
        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        folder.name = trimmed
        do { try modelContext.save() } catch { AppLog.folders.error("Rename failed: \(error.localizedDescription, privacy: .public)") }
        folderToRename = nil
        renameText = ""
    }

    private func deleteFolder(_ folder: DeckFolder) {
        // SwiftData's DeckFolder.decks relationship uses deleteRule: .nullify,
        // so deleting the folder automatically un-groups its decks (their
        // `folder` property is set to nil). No card data is lost.
        modelContext.delete(folder)
        do { try modelContext.save() } catch { AppLog.folders.error("Delete folder failed: \(error.localizedDescription, privacy: .public)") }
        folderToDelete = nil
    }
}
