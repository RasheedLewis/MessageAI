import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    var isSending: Bool
    var onSend: () -> Void
    var onAttachment: (() -> Void)?

    private let placeholder = "Message"

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if let onAttachment {
                    Button(action: onAttachment) {
                        Image(systemName: "paperclip")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .disabled(isSending)
                }

                GrowingTextView(text: $text, placeholder: placeholder)
                    .frame(minHeight: 36)

                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .rotationEffect(.degrees(45))
                }
                .disabled(isSendDisabled)
                .opacity(isSendDisabled ? 0.4 : 1)
            }

            if isSending {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Material.thin)
    }

    private var isSendDisabled: Bool {
        isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct GrowingTextView: View {
    @Binding var text: String
    let placeholder: String
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.leading, 4)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.tertiaryLabel), lineWidth: 0.5)
                )
                .frame(minHeight: 36, maxHeight: 120)
        }
    }
}

#Preview {
    MessageInputView(
        text: .constant("Hello world"),
        isSending: false,
        onSend: {},
        onAttachment: {}
    )
}

