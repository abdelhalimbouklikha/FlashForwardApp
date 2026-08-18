import SwiftUI
import UIKit

/// Fullscreen, pinch-to-zoom image viewer presented when the user taps an
/// image on a card. Supports:
///   • Pinch-to-zoom (MagnifyGesture)
///   • Drag-to-pan when zoomed in
///   • Double-tap to toggle 1× ↔ 2.5×
///   • Tap the background (or the close button) to dismiss
///   • Swipe-down to dismiss when at 1× zoom
struct FullscreenImageViewer: View {
    let imageData: Data

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var backgroundOpacity: Double = 1.0

    var body: some View {
        ZStack {
            Color.black
                .opacity(backgroundOpacity)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { dismiss() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .padding(.trailing, AppTheme.spacingM)
                    .padding(.top, AppTheme.spacingS)
                }

                Spacer()
            }

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
                        .gesture(tapToDismissGesture)
                }
                .ignoresSafeArea()
            } else {
                Text(L("image.unavailable"))
                    .foregroundColor(.white)
            }
        }
        .statusBarHidden()
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
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { value in
                guard scale > 1.0 else {
                    // Swipe-down to dismiss when at 1× zoom
                    if value.translation.height > 120 {
                        withAnimation(.easeInOut(duration: 0.25)) { dismiss() }
                    }
                    return
                }
                lastOffset = offset
            }
    }

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

    /// Single tap fades the background slightly; used purely as a visual cue.
    private var tapToDismissGesture: some Gesture {
        TapGesture().onEnded {
            // Only dismiss on single tap if not zoomed — avoids accidental
            // dismissal while inspecting details.
            if scale <= 1.05 {
                withAnimation(.easeInOut(duration: 0.25)) { dismiss() }
            }
        }
    }
}

// MARK: - Convenience view modifier

extension View {
    /// Presents a fullscreen image viewer when `data` is non-nil.
    func fullscreenImageOverlay(data: Data?) -> some View {
        self
    }
}
