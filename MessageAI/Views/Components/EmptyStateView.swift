import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "bubble.left"

    var body: some View {
        VStack(spacing: 16) {
            ThemedIcon(systemName: systemImage, state: .active, size: 42, withContainer: false, showsBorder: false)

            Text(title)
                .font(.theme.headline)
                .foregroundStyle(Color.theme.textOnPrimary)

            Text(message)
                .font(.theme.body)
                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyStateView(
        title: "No conversations yet",
        message: "Start a new chat to see messages here."
    )
}

