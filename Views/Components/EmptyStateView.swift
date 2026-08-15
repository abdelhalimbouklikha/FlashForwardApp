import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppTheme.spacingL) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accentSecondary],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.bottom, AppTheme.spacingS)

            VStack(spacing: AppTheme.spacingS) {
                Text(title)
                    .font(AppTheme.title(22))
                    .foregroundColor(AppTheme.textPrimary)

                Text(message)
                    .font(AppTheme.body(15))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.spacingXL)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppTheme.heading(16))
                        .violetAccentButton()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.spacingXL)
    }
}