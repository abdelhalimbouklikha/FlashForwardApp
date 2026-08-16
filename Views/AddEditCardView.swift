import SwiftUI
import SwiftData
import PhotosUI
import UIKit

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

    private var isEditing: Bool { card != nil }

    private var canSave: Bool {
        let hasFrontText = !front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasBackText = !back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasFrontText || frontImageData != nil)
            && (hasBackText || backImageData != nil)
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
            .onChange(of: frontImageItem) { _, newItem in
                loadImage(item: newItem, into: $frontImageData)
            }
            .onChange(of: backImageItem) { _, newItem in
                loadImage(item: newItem, into: $backImageData)
            }
            .onAppear { loadCard() }
        }
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

            // Image preview
            if let data = imageData.wrappedValue,
               let uiImage = UIImage(data: data) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusM,
                                                    style: .continuous))
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
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                frontFocused = true
            }
        }
    }

    private func loadImage(item: PhotosPickerItem?,
                           into binding: Binding<Data?>) {
        guard let item = item else { return }
        Task {
            if let raw = try? await item.loadTransferable(type: Data.self) {
                let compressed = compressImageData(raw)
                await MainActor.run { binding.wrappedValue = compressed }
            }
        }
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

    private func save() {
        let trimmedFront = front.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBack = back.trimmingCharacters(in: .whitespacesAndNewlines)

        if let card = card {
            card.front = trimmedFront
            card.back = trimmedBack
            card.frontImageData = frontImageData
            card.backImageData = backImageData
        } else {
            let newCard = Card(front: trimmedFront, back: trimmedBack, deck: deck)
            newCard.frontImageData = frontImageData
            newCard.backImageData = backImageData
            modelContext.insert(newCard)
        }

        do { try modelContext.save() } catch { print("Failed to save card: \(error)") }
        dismiss()
    }
}