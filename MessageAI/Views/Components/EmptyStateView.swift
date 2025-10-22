import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    var systemImage: String = "bubble.left"

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor.opacity(0.6))

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
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

