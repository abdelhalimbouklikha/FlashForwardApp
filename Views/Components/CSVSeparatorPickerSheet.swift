import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// v1.3-fixes — Task 2. Bottom sheet presented after the user picks a CSV
/// file. It lets the user choose the field separator (Tab, `|`, `;`, `:`,
/// `,`, Space), shows a **live preview** of the parsed rows for the chosen
/// separator, auto-detects a sensible default, and finally exposes an
/// "Importer" button that performs the actual import with the selected
/// separator.
///
/// This fixes the original bug where the importer hard-coded `,` as the
/// separator, so any file using `;` or `|` or Tab would be mis-parsed as
/// a single giant field per line — yielding "only one card per pack".
struct CSVSeparatorPickerSheet: View {
    /// The raw file content (already decoded from the picked URL by the
    /// caller). Held here so the preview re-parses instantly without
    /// re-reading the file on every separator change.
    let content: String

    /// Called with the user's chosen separator when they tap "Importer".
    let onImport: (CSVImportService.Separator) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selected: CSVImportService.Separator = .comma
    @State private var autoDetected: CSVImportService.Separator = .comma

    private var previewRows: [CSVImportService.PreviewRow] {
        CSVImportService.shared.preview(content: content, separator: selected)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.spacingL) {
                        infoHeader
                        separatorPicker
                        previewSection
                    }
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.top, AppTheme.spacingM)
                    .padding(.bottom, AppTheme.spacingXL)
                }

                Divider().background(AppTheme.surfaceElevated)

                importButton
                    .padding(.horizontal, AppTheme.spacingM)
                    .padding(.vertical, AppTheme.spacingM)
            }
            .primaryGradientBackground()
            .navigationTitle(L("csv.separator.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("common.cancel")) { dismiss() }
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            .onAppear { initializeDefaults() }
        }
    }

    // MARK: - Header

    private var infoHeader: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack(spacing: AppTheme.spacingS) {
                Image(systemName: "tablecells.badge.ellipsis")
                    .font(.system(size: 18))
                    .foregroundColor(AppTheme.accent)
                Text(L("csv.separator.description"))
                    .font(AppTheme.body(14))
                    .foregroundColor(AppTheme.textSecondary)
            }
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 13))
                    .foregroundColor(AppTheme.accent.opacity(0.8))
                Text(String(format: L("csv.separator.detected"),
                             autoDetected.label))
                    .font(AppTheme.caption(12))
                    .foregroundColor(AppTheme.textTertiary)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Separator picker

    private var separatorPicker: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            Text(L("csv.separator.choose"))
                .font(AppTheme.heading(15))
                .foregroundColor(AppTheme.textPrimary)
                .padding(.horizontal, 4)

            // Wrap in a horizontal flow so all six options are visible
            // without scrolling on every device width.
            FlowLayout(spacing: 8) {
                ForEach(CSVImportService.Separator.allCases) { sep in
                    separatorChip(sep)
                }
            }
            .padding(AppTheme.spacingM)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL,
                                        style: .continuous))
        }
    }

    private func separatorChip(_ sep: CSVImportService.Separator) -> some View {
        let isSelected = sep == selected
        return Button {
            selected = sep
            haptic()
        } label: {
            Text(sep.label)
                .font(AppTheme.caption(13))
                .foregroundColor(isSelected ? .white : AppTheme.textSecondary)
                .padding(.horizontal, AppTheme.spacingM)
                .padding(.vertical, AppTheme.spacingS)
                .background(
                    Capsule()
                        .fill(isSelected
                              ? AnyShapeStyle(LinearGradient(
                                  colors: [AppTheme.accent, AppTheme.accentSecondary],
                                  startPoint: .leading, endPoint: .trailing))
                              : AnyShapeStyle(AppTheme.surfaceElevated))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Live preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingS) {
            HStack {
                Text(L("csv.separator.preview"))
                    .font(AppTheme.heading(15))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text(String(format: L("csv.separator.rows"),
                            previewRows.count))
                    .font(AppTheme.caption(12))
                    .foregroundColor(AppTheme.textTertiary)
            }
            .padding(.horizontal, 4)

            if previewRows.isEmpty {
                VStack(spacing: AppTheme.spacingS) {
                    Image(systemName: "doc.questionmark")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(AppTheme.textTertiary)
                    Text(L("csv.separator.noRows"))
                        .font(AppTheme.body(14))
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(AppTheme.spacingL)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL,
                                            style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(previewRows.prefix(10).enumerated()), id: \.element.id) { _, row in
                        previewRow(row)
                        Divider().background(AppTheme.surfaceElevated)
                    }
                }
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL,
                                            style: .continuous))
            }
        }
    }

    private func previewRow(_ row: CSVImportService.PreviewRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: AppTheme.spacingS) {
                if !row.folder.isEmpty {
                    tagPill(row.folder, color: AppTheme.accent.opacity(0.6))
                }
                if !row.deck.isEmpty {
                    tagPill(row.deck, color: AppTheme.accent)
                }
                if row.front.isEmpty && row.back.isEmpty {
                    Text(L("csv.separator.emptyRow"))
                        .font(AppTheme.caption(11))
                        .foregroundColor(AppTheme.textTertiary)
                }
            }
            if !row.front.isEmpty {
                Text(row.front)
                    .font(AppTheme.body(14))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(2)
            }
            if !row.back.isEmpty {
                Text(row.back)
                    .font(AppTheme.caption(12))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(2)
            }
            if !row.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(row.tags, id: \.self) { t in
                        Text("#\(t)")
                            .font(AppTheme.caption(10))
                            .foregroundColor(AppTheme.info)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.info.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(AppTheme.spacingM)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tagPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(AppTheme.caption(11))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color))
    }

    // MARK: - Import button

    private var importButton: some View {
        Button {
            onImport(selected)
            dismiss()
        } label: {
            HStack(spacing: AppTheme.spacingS) {
                Image(systemName: "tray.and.arrow.down.fill")
                Text(L("csv.separator.import"))
            }
            .font(AppTheme.heading(16))
            .frame(maxWidth: .infinity)
            .violetAccentButton()
        }
        .buttonStyle(.plain)
        .disabled(previewRows.isEmpty)
    }

    // MARK: - Helpers

    private func initializeDefaults() {
        let detected = CSVImportService.shared.detectSeparator(content)
        autoDetected = detected
        selected = detected
    }

    private func haptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - FlowLayout (simple wrapping HStack)

/// A lightweight wrapping layout for the separator chips so all six options
/// are visible without horizontal scrolling on narrow phones. Uses the
/// `Layout` protocol (iOS 16+).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x - bounds.minX + size.width > maxWidth {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y),
                          proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
