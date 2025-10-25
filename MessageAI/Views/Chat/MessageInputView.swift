import SwiftUI

struct MessageInputView: View {
    @Binding var text: String
    var isSending: Bool
    var onSend: () -> Void
    var onAttachment: (() -> Void)?

    @State private var isPressingSend = false

    private let placeholder = "Message"

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if let onAttachment {
                    Button(action: onAttachment) {
                        ThemedIcon(systemName: "paperclip", state: .custom(Color.theme.disabled, glow: false), size: 18)
                    }
                    .disabled(isSending)
                }

                GrowingTextView(text: $text, placeholder: placeholder)
                    .frame(minHeight: 36)

                Button(action: handleSend) {
                    ThemedIcon(systemName: "paperplane", state: .custom(Color.theme.secondary, glow: true), size: 18)
                        .rotationEffect(.degrees(45))
                        .shadow(color: Color.theme.accent.opacity(0.4), radius: 8, x: 0, y: 0)
                        .overlay(
                            Circle()
                                .fill(Color.theme.accent.opacity(isSendDisabled ? 0.0 : 0.4))
                                .blur(radius: isSendDisabled ? 0 : 6)
                                .scaleEffect(isSendDisabled ? 0.95 : (isPressingSend ? 1.0 : 1.2))
                        )
                }
                .buttonStyle(.primaryThemed)
                .scaleEffect(isSendDisabled ? 1.0 : (isPressingSend ? 1.03 : 1.0))
                .opacity(isSendDisabled ? 0.4 : 1)
                .animation(.cubicBezier(0.4, 0, 0.2, 1), value: isPressingSend)
                .disabled(isSendDisabled)
            }

            if isSending {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
                    .font(.theme.body)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.theme.inputBar)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color.theme.inputBorder.opacity(0.7), lineWidth: 1)
        )
    }

    private var isSendDisabled: Bool {
        isSending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handleSend() {
        guard !isSendDisabled else { return }
        isPressingSend = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isPressingSend = false
        }
        onSend()
    }
}

private struct GrowingTextView: View {
    @Binding var text: String
    let placeholder: String
    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.theme.body)
                    .foregroundStyle(Color.theme.disabled)
                    .padding(.vertical, 8)
                    .padding(.leading, 4)
            }

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .background(Color.theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.vertical, 8)
                .font(.theme.body)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.theme.inputBorder, lineWidth: 1)
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

