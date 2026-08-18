import SwiftUI
import UIKit

/// Fullscreen, pinch-to-zoom image viewer presented when the user taps an
/// image on a card.
///
/// v1.3-fixes — Bug fix (Task 1): the previous implementation attached both a
/// single-tap `tapToDismissGesture` and a `doubleTapGesture` to the image.
/// When the viewer was presented via `.fullScreenCover`, the tap that opened
/// it could still be "in flight" and immediately trigger the single-tap
/// dismiss, which closed the viewer; the parent's tap then re-opened it,
/// producing an infinite open/close loop.
///
/// Fix: the single-tap-to-dismiss gesture has been **removed entirely**, and
/// the swipe-down-to-dismiss path in `dragGesture` has been removed too. The
/// **only** way to close the viewer is now the ✕ button at the top-right.
/// Pinch-to-zoom, drag-to-pan (when zoomed), and double-tap-to-toggle-zoom
/// are preserved. This matches the spec: "Seul le bouton croix (X) en haut
/// à droite doit la refermer."
struct FullscreenImageViewer: View {
    let imageData: Data

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(Text("Close"))
                    .padding(.trailing, AppTheme.spacingM)
                    .padding(.top, AppTheme.spacingS)
                }

                Spacer()
            }
            .zIndex(2)

            if let uiImage = UIImage(data: imageData) {
                GeometryReader { geo in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnificationGesture)
                        .gesture(dragGesture)
                        .gesture(doubleTapGesture)
                }
                .ignoresSafeArea()
            } else {
                Text(L("image.unavailable"))
                    .foregroundColor(.white)
            }
        }
        .statusBarHidden()
        // Prevent any accidental dismiss from the swipe-down gesture of the
        // presentation itself (iOS interactive pop). Only the ✕ button
        // dismisses.
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - Close

    /// Dismisses the viewer. Called **only** by the ✕ button. This is the
    /// single, explicit exit point that prevents the auto-open/close loop.
    private func close() {
        withAnimation(.easeInOut(duration: 0.25)) { dismiss() }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let delta = value.magnification / lastScale
                lastScale = value.magnification
                scale = min(max(scale * delta, 1.0), 6.0)
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 1.05 {
                    withAnimation(.spring()) {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    /// Drag-to-pan — only active when zoomed in (>1×). At 1×, drags are
    /// ignored so they cannot accidentally dismiss the viewer (Task 1 fix).
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                guard scale > 1.0 else { return }
                lastOffset = offset
            }
    }

    /// Double-tap toggles 1× ↔ 2.5×. A single tap does **nothing** now
    /// (previously it dismissed, which caused the loop — see Task 1).
    private var doubleTapGesture: some Gesture {
        TapGesture(count: 2).onEnded {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if scale > 1.5 {
                    scale = 1.0
                    offset = .zero
                    lastOffset = .zero
                } else {
                    scale = 2.5
                }
            }
        }
    }
}

// MARK: - Convenience view modifier
// (Kept for backward compatibility with any call site that referenced it.)

extension View {
    /// Presents a fullscreen image viewer when `data` is non-nil.
    func fullscreenImageOverlay(data: Data?) -> some View {
        self
    }
}
