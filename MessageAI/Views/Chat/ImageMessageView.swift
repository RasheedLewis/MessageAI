import SwiftUI

struct ImageMessageView: View {
    let url: URL
    let isCurrentUser: Bool
    let status: LocalMessageStatus

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholder
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    failureView
                @unknown default:
                    placeholder
                }
            }
            .frame(maxWidth: 240, maxHeight: 240)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor.opacity(0.3), lineWidth: 1)
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.theme.primaryVariant.opacity(0.25))
            )

            statusIcon
                .padding(8)
        }
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.theme.primaryVariant.opacity(0.4))
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.theme.accent)
        }
    }

    private var failureView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.theme.primaryVariant.opacity(0.4))
            ThemedIcon(systemName: "exclamationmark.triangle", state: .custom(Color.theme.error, glow: false), size: 20)
        }
    }

    private var borderColor: Color {
        isCurrentUser ? Color.theme.userBubbleEnd : Color.theme.aiBubbleEnd
    }

    private var statusIcon: some View {
        Group {
            switch status {
            case .sending:
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.6)
                    .tint(Color.theme.textOnPrimary)
            case .failed:
                ThemedIcon(systemName: "exclamationmark.circle", state: .custom(Color.theme.error, glow: false), size: 16)
            default:
                ThemedIcon(systemName: "checkmark", state: .custom(Color.theme.textOnPrimary.opacity(0.8), glow: false), size: 12)
            }
        }
    }
}
