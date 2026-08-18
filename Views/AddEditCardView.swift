import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import os

/// v1.3-fixes — Task 4 (Tags): the card editor now has a **Tag** field.
/// Tags are optional and multiple (chips with autocomplete from tags
/// already used in the same deck). They are persisted on the `Card.tags`
/// computed accessor (backed by the `tagsJSON` String property added to
/// the model — additive, no migration plan required).
///
/// v1.3-fixes — Task 8 (Audit): the async `loadImage` Task is now tracked
/// and cancelled on view disappear so a slow photo load can never write to
/// a binding of a dismissed view (the "setState-after-dispose" risk). All
/// `print(...)` calls replaced with `AppLog.cards`.
struct AddEditCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var deck: Deck
    var card: Card? = nil

    @State private var front: String = ""
    @State private var back: String = ""
    @State private var frontImageItem: PhotosPickerItem? = nil
    @State private var backImageItem: PhotosPickerItem? = nil
    @State private var frontImageData: Data? = nil
    @State private var backImageData: Data? = nil
    @FocusState private var frontFocused: Bool
    @FocusState private var backFocused: Bool

    // Fullscreen image preview while editing
    @State private var fullscreenImageData: Data? = nil

    // v1.3 — Task 4. Tags.
    @State private var tags: [String] = []
    @State private var tagInput: String = ""
    @FocusState private var tagInputFocused: Bool

    // v1.3 — Task 8. Tracked image-load tasks, cancelled on disappear.
    @State private var frontLoadTask: Task<Void, Never>? = nil
    @State private var backLoadTask: Task<Void, Never>? = nil

    private var isEditing: Bool { card != nil }

    private var canSave: Bool {
        let hasFrontText = !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasBackText = !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasFrontText || frontImageData != nil)
            && (hasBackText || backImageData != nil)
    }

    /// Tags already used somewhere in this deck — drives autocomplete.
    private var existingDeckTags: [String] {
        let all = deck.cards.flatMap { $0.tags }
        return Array(Set(all)).sorted()
    }

    /// Tag suggestions matching the current input prefix, excluding tags
    /// already attached to this card.
    private var suggestedTags: [String] {
        let q = tagInput.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return existingDeckTags
            .filter { $0.lowercased().contains(q) && !tags.contains($0) }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    cardEditorSection(
                        title: L("card.front"),
                        titleIcon: "arrow.right.circle.fill",
                        text: $front,
                        isFocused: $frontFocused,
                        imageItem: $frontImageItem,
                        imageData: $frontImageData,
                        placeholder: L("card.frontPlaceholder"),
                        minHeight: 100
                    )

                    cardEditorSection(
                        title: L("card.back"),
                        titleIcon: "lightbulb.fill",
                        text: $back,
                        isFocused: $backFocused,
                        imageItem: $backImageItem,
                        imageData: $backImageData,
                        placeholder: L("card.backPlaceholder"),
                        minHeight: 100
                    )

                    // v1.3 — Task 4. Tag section.
                    tagSection

                    if isEditing, let card = card, card.reps > 0 {
                        HStack {
                            statItem(label: L("card.reviews"), value: "\(card.reps)")
                            Divider().frame(height: 30)
                            statItem(label: L("card.lapses"), value: "\(card.lapses)")
                            Divider().frame(height: 30)
                            statItem(label: L("card.interval"),
                                     value: formatInterval(card.scheduledDays))
                        }
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
            .navigationTitle(isEditing ? L("card.edit") : L("card.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.cancel")) {
                        cancelEditing()
                    }
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
            .onChange(of: frontImageItem) { _, newItem in
                frontLoadTask?.cancel()
                frontLoadTask = loadImage(item: newItem, into: $frontImageData)
            }
            .onChange(of: backImageItem) { _, newItem in
                backLoadTask?.cancel()
                backLoadTask = loadImage(item: newItem, into: $backImageData)
            }
            .onAppear { loadCard() }
            .onDisappear {
                // v1.3 — Task 8. Cancel any in-flight photo loads so they
                // can never write to a binding of a dismissed view.
                frontLoadTask?.cancel()
                backLoadTask?.cancel()
            }
            .fullScreenCover(item: Binding(
                get: { fullscreenImageData.map { ImageDataBox(data: $0) } },
                set: { fullscreenImageData = $0?.data }
            )) { box in
                FullscreenImageViewer(imageData: box.data)
            }
        }
    }

    // MARK: - Tag Section (Task 4)

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                Image(systemName: "tag.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.accent)
                Text(L("card.tags"))
                    .font(AppTheme.heading(16))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(String(format: L("card.tags.count"), tags.count))
                    .font(AppTheme.caption(11))
                    .foregroundColor(AppTheme.textTertiary)
            }

            // Existing chips
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
                .padding(AppTheme.spacingS)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                            style: .continuous))
            }

            // Input row
            HStack(spacing: AppTheme.spacingS) {
                TextField(L("card.tags.placeholder"), text: $tagInput)
                    .font(AppTheme.body(15))
                    .focused($tagInputFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { commitTagInput() }
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.vertical, AppTheme.spacingS)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                            .stroke(tagInputFocused
                                    ? AppTheme.accent.opacity(0.6) : Color.clear,
                                    lineWidth: 2)
                    )

                Button {
                    commitTagInput()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(tagInput.isEmpty ? AppTheme.textTertiary : AppTheme.accent)
                }
                .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // Autocomplete suggestions
            if !suggestedTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("card.tags.suggestions"))
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.textTertiary)
                    FlowLayout(spacing: 6) {
                        ForEach(suggestedTags, id: \.self) { suggestion in
                            Button {
                                addTag(suggestion)
                            } label: {
                                Text("#\(suggestion)")
                                    .font(AppTheme.caption(12))
                                    .foregroundColor(AppTheme.info)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.info.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(AppTheme.caption(13))
                .foregroundColor(.white)
            Button {
                removeTag(tag)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.spacingS)
        .padding(.vertical, 6)
        .background(Capsule().fill(AppTheme.accent.opacity(0.85)))
    }

    // MARK: - Editor Section

    private func cardEditorSection(
        title: String,
        titleIcon: String,
        text: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        imageItem: Binding<PhotosPickerItem?>,
        imageData: Binding<Data?>,
        placeholder: String,
        minHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                Image(systemName: titleIcon)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.accent)
                Text(title)
                    .font(AppTheme.heading(16))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                PhotosPicker(selection: imageItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 17))
                        .foregroundColor(AppTheme.accent)
                }
            }

            // Image preview — tappable to open fullscreen
            if let data = imageData.wrappedValue,
               let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Button {
                        fullscreenImageData = data
                    } label: {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                        style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                 style: .continuous)
                                    .stroke(AppTheme.accent.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    // Expand icon hint
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Circle())
                        .padding(8)

                    // Remove button
                    Button {
                        imageData.wrappedValue = nil
                        imageItem.wrappedValue = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding(8)
                }
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
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                        style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.radiusM, style: .continuous)
                    .stroke(isFocused.wrappedValue
                            ? AppTheme.accent.opacity(0.6) : Color.clear,
                            lineWidth: 2)
            )
        }
    }

    // MARK: - Helpers

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

    private func loadCard() {
        if let card = card {
            front = card.front
            back = card.back
            frontImageData = card.frontImageData
            backImageData = card.backImageData
            tags = card.tags
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                frontFocused = true
            }
        }
    }

    // v1.3 — Task 8. Returns the Task so the caller can cancel it on
    // disappear. All writes to `binding` are guarded by `Task.isCancelled`
    // so a photo that finishes loading after the view is dismissed is
    // dropped silently instead of touching a stale binding.
    @discardableResult
    private func loadImage(item: PhotosPickerItem?,
                           into binding: Binding<Data?>) -> Task<Void, Never>? {
        guard let item = item else { return nil }
        let task = Task { @MainActor in
            if let raw = try? await item.loadTransferable(type: Data.self) {
                if Task.isCancelled { return }
                let compressed = compressImageData(raw)
                if Task.isCancelled { return }
                binding.wrappedValue = compressed
            }
        }
        return task
    }

    /// Downscales large images and JPEG-compresses them before storing on the
    /// SwiftData model's `@Attribute(.externalStorage)` field.
    private func compressImageData(_ data: Data,
                                   maxDimension: CGFloat = 1200,
                                   quality: CGFloat = 0.72) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let longestSide = max(size.width, size.height)
        let scale: CGFloat = longestSide > maxDimension
            ? maxDimension / longestSide
            : 1.0
        let newSize = CGSize(width: size.width * scale,
                             height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return rendered.jpegData(compressionQuality: quality)
    }

    // MARK: - Tag actions (Task 4)

    private func commitTagInput() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        addTag(trimmed)
    }

    private func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Case-insensitive de-dup: don't add "Verb" if "verb" is already there.
        if !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            tags.append(trimmed)
        }
        tagInput = ""
    }

    private func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
    }

    // MARK: - Save / Cancel

    private func cancelEditing() {
        // v1.3 — Task 8. Cancel any in-flight photo loads before leaving.
        frontLoadTask?.cancel()
        backLoadTask?.cancel()
        dismiss()
    }

    private func save() {
        let trimmedFront = front.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBack = back.trimmingCharacters(in: .whitespacesAndNewlines)

        if let card = card {
            card.front = trimmedFront
            card.back = trimmedBack
            card.frontImageData = frontImageData
            card.backImageData = backImageData
            card.tags = tags
        } else {
            let newCard = Card(front: trimmedFront, back: trimmedBack, deck: deck)
            newCard.frontImageData = frontImageData
            newCard.backImageData = backImageData
            newCard.tags = tags
            modelContext.insert(newCard)
        }

        do {
            try modelContext.save()
        } catch {
            // v1.3 — Task 8: structured log.
            AppLog.cards.error("Failed to save card: \(error.localizedDescription, privacy: .public)")
        }
        dismiss()
    }
}

// MARK: - ImageDataBox (for fullScreenCover(item:))

private struct ImageDataBox: Identifiable {
    let id = UUID()
    let data: Data
}
