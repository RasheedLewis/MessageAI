import AuthenticationServices
import SwiftUI
import UIKit

struct LoginView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var isShowingAlert = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 12) {
                ThemedIcon(systemName: "message", state: .active, size: 48)

                Text("Welcome to MessageAI")
                    .font(.theme.display)
                    .multilineTextAlignment(.center)

                Text("Manage every fan DM effortlessly with AI-powered assistants.")
                    .font(.theme.body)
                    .foregroundStyle(Color.theme.textOnSurface.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button {
                    signInWithGoogle()
                } label: {
                    HStack {
                        GoogleGlyph()
                        Text("Continue with Google")
                            .font(.theme.button)
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
                .frame(height: 50)
                .signInWithAppleButtonStyle(.whiteOutline)
                .opacity(viewModel.state == .loading ? 0.6 : 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.theme.secondary.opacity(0.2), lineWidth: viewModel.state == .loading ? 1 : 0)
                )
                .allowsHitTesting(viewModel.state != .loading)
            }

            if viewModel.state == .loading {
                ProgressView("Signing in…")
                    .font(.theme.body)
            }

            Button {
                // Future enhancement: show AI assistant support sheet
            } label: {
                Text("Need a hand? Ask AI")
            }
            .buttonStyle(.tertiaryThemed)
            .padding(.top, 8)

            Spacer()

            Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                .font(.theme.caption)
                .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.horizontal, 24)
        .alert(isPresented: $isShowingAlert) {
            Alert(title: Text("Authentication Error"), message: Text(viewModel.error ?? "Unknown error"), dismissButton: .default(Text("OK")))
        }
        .onChange(of: viewModel.error) { _, error in
            isShowingAlert = error != nil
        }
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

