import SwiftUI

struct TypingIndicatorView: View {
    enum Actor {
        case ai
        case user

        var gradient: LinearGradient {
            switch self {
            case .ai:
                return LinearGradient(
                    gradient: Gradient(colors: [Color.theme.aiBubbleStart, Color.theme.aiBubbleEnd]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .user:
                return LinearGradient(
                    gradient: Gradient(colors: [Color.theme.userBubbleStart, Color.theme.userBubbleEnd]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }

        var icon: String {
            switch self {
            case .ai:
                return "sparkles"
            case .user:
                return "person"
            }
        }
    }

    var actor: Actor = .ai

    @State private var animate = false

    var body: some View {
        HStack(spacing: 12) {
            ThemedIcon(systemName: actor.icon, state: .custom(Color.theme.accent, glow: false), size: 18)
                .shadow(color: Color.theme.accent.opacity(0.6), radius: 8, x: 0, y: 0)

            Capsule()
                .fill(actor.gradient)
                .frame(width: 60, height: 28)
                .overlay(dotStack)
                .shadow(color: Color.theme.accent.opacity(0.45), radius: 12, x: 0, y: 6)
                .scaleEffect(animate ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animate)
        }
        .onAppear {
            animate = true
            notifyHaptics()
        }
    }

    private var dotStack: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 6, height: 6)
                    .scaleEffect(animate ? 1 : 0.6)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2), value: animate)
            }
        }
    }

    private func notifyHaptics() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5)
    }
}

#Preview {
    TypingIndicatorView()
        .padding()
        .background(Color.theme.primary)
}


