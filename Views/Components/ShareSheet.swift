import SwiftUI
import UIKit

/// SwiftUI wrapper around `UIActivityViewController` for invoking the native
/// iOS share sheet. Used to share exported CSV files (and any other items).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController,
                                context: Context) {}
}
