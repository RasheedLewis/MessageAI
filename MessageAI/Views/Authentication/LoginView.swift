import AuthenticationServices
import SwiftUI
import UIKit

struct LoginView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var isShowingAlert = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                background

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 32) {
                        heroSection
                        signInCard
                        Spacer(minLength: 12)
                        footerSection
                    }
                    .frame(minHeight: proxy.size.height, alignment: .top)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
        }
        .alert(isPresented: $isShowingAlert) {
            Alert(title: Text("Authentication Error"), message: Text(viewModel.error ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
        .onChange(of: viewModel.error) { _, error in
            isShowingAlert = error != nil
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.25), value: viewModel.state)
    }

    private func signInWithGoogle() {
        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else { return }

        Task {
            await viewModel.signInWithGoogle(presenting: rootVC)
        }
    }

    private func handleAppleCompletion(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                await viewModel.signInWithApple(authorization: authorization)
            }
        case .failure(let error):
            viewModel.error = error.localizedDescription
        }
    }
}

#Preview {
    LoginView(viewModel: AuthenticationViewModel())
}

private extension LoginView {
    var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color.theme.primaryVariant, Color.theme.primary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.theme.accent.opacity(0.35), Color.clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )

            RadialGradient(
                colors: [Color.theme.secondary.opacity(0.25), Color.clear],
                center: .bottomTrailing,
                startRadius: 40,
                endRadius: 360
            )

            Circle()
                .fill(Color.theme.accent.opacity(0.2))
                .frame(width: 280, height: 280)
                .blur(radius: 120)
                .offset(x: -140, y: -220)

            Circle()
                .fill(Color.theme.secondary.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 140)
                .offset(x: 180, y: 260)
        }
        .ignoresSafeArea()
    }

    var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.theme.accent.opacity(0.55), Color.theme.secondary.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.theme.accent.opacity(0.45), radius: 28, x: 0, y: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )

                ThemedIcon(systemName: "message.fill", state: .custom(Color.white, glow: false), size: 40)
            }

            Text("MessageAI")
                .font(.theme.display)
                .foregroundStyle(Color.white)
                .shadow(color: Color.theme.accent.opacity(0.55), radius: 18, x: 0, y: 0)

            Capsule()
                .fill(Color.theme.accent.opacity(0.35))
                .frame(width: 120, height: 4)
                .shadow(color: Color.theme.accent.opacity(0.4), radius: 10, x: 0, y: 0)

            Text("Creators finally get an inbox tailored for high-volume DM workflows—powered by multi-agent AI.")
                .font(.theme.body)
                .foregroundStyle(Color.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
    }

    var signInCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            cardHeader
            featureHighlightsSection
            actionButtons
            gradientDivider
            supportButton
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.02))
                        .blur(radius: 60)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 18)
        .shadow(color: Color.theme.accent.opacity(0.3), radius: 50, x: 0, y: 0)
    }

    var cardHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Log in to unlock your AI inbox")
                .font(.theme.subhead)
                .foregroundStyle(Color.theme.textOnPrimary)

            Text("Bring AI copilots into your DM flow to auto-sort fans, surface collabs, and escalate urgent moments in seconds.")
                .font(.theme.caption)
                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.75))
        }
    }

    var featureHighlightsSection: some View {
        VStack(spacing: 14) {
            ForEach(featureHighlights) { feature in
                LoginFeatureRow(feature: feature)
            }
        }
    }

    var actionButtons: some View {
        VStack(spacing: 14) {
            Button {
                signInWithGoogle()
            } label: {
                HStack(spacing: 12) {
                    GoogleGlyph()

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Continue with Google")
                            .font(.theme.bodyMedium)
                        Text("Use your creator or team account")
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))
                    }

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(viewModel.state == .loading ? .primaryDisabledThemed : .primaryThemed)
            .disabled(viewModel.state == .loading)

            SignInWithAppleButton(.signIn) { request in
                let appleRequest = AuthenticationService.shared.makeAppleIDRequest()
                request.requestedScopes = appleRequest.requestedScopes ?? []
                request.nonce = appleRequest.nonce
            } onCompletion: { result in
                handleAppleCompletion(result: result)
            }
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .signInWithAppleButtonStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .opacity(viewModel.state == .loading ? 0.7 : 1)
            .allowsHitTesting(viewModel.state != .loading)

            if viewModel.state == .loading {
                ProgressView("Signing in…")
                    .font(.theme.caption)
                    .foregroundStyle(Color.theme.textOnPrimary.opacity(0.8))
                    .tint(Color.theme.accent)
            }
        }
    }

    var gradientDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.0), Color.white.opacity(0.25), Color.white.opacity(0.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.top, 8)
    }

    var supportButton: some View {
        Button {
            // Future enhancement: show AI assistant support sheet
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.theme.captionMedium)
                    .foregroundStyle(Color.theme.accent)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.theme.accent.opacity(0.16))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Need a hand? Ask AI")
                        .font(.theme.bodyMedium)
                        .foregroundStyle(Color.theme.accent)
                    Text("Let the assistant walk you through setup")
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.65))
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.theme.captionMedium)
                    .foregroundStyle(Color.theme.accent.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.theme.accent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.theme.accent.opacity(0.25), lineWidth: 1)
                    )
            )
            .shadow(color: Color.theme.accent.opacity(0.25), radius: 16, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    var footerSection: some View {
        VStack(spacing: 16) {
            Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                .font(.theme.caption)
                .foregroundStyle(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
    }

    var featureHighlights: [LoginFeature] {
        [
            .init(
                icon: "wand.and.stars",
                title: "AI triages every DM",
                subtitle: "Categorize fans, business leads, spam, and urgent messages instantly.",
                tint: Color.theme.accent
            ),
            .init(
                icon: "bolt.horizontal.circle",
                title: "Respond in your voice",
                subtitle: "Draft authentic replies with creator-specific tone and style guidance.",
                tint: Color.theme.secondary
            ),
            .init(
                icon: "chart.bar.xaxis",
                title: "Surface what matters",
                subtitle: "Prioritize collaborations, sentiment shifts, and high-value conversations.",
                tint: Color(red: 0.42, green: 0.82, blue: 0.68)
            )
        ]
    }
}

private struct LoginFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
}

private struct LoginFeatureRow: View {
    let feature: LoginFeature

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(feature.tint.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(feature.tint.opacity(0.45), lineWidth: 1)
                    )
                    .frame(width: 42, height: 42)
                    .shadow(color: feature.tint.opacity(0.35), radius: 10, x: 0, y: 6)

                Image(systemName: feature.icon)
                    .font(.theme.captionMedium)
                    .foregroundStyle(feature.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.theme.bodyMedium)
                    .foregroundStyle(Color.theme.textOnPrimary)
                Text(feature.subtitle)
                    .font(.theme.caption)
                    .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))
            }

            Spacer(minLength: 0)
        }
    }
}

private struct GoogleGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)

            Text("G")
                .font(.theme.captionMedium)
                .foregroundStyle(Color(red: 0.16, green: 0.32, blue: 0.75))
        }
    }
}

