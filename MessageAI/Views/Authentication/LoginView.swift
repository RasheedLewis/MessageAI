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
                Image(systemName: "message.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.tint)

                Text("Welcome to MessageAI")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Manage every fan DM effortlessly with AI-powered assistants.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button {
                    signInWithGoogle()
                } label: {
                    HStack {
                        GoogleGlyph()
                        Text("Continue with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.gray.opacity(0.3), lineWidth: 1))
                }
                .disabled(viewModel.state == .loading)

                SignInWithAppleButton(.signIn) { request in
                    let appleRequest = AuthenticationService.shared.makeAppleIDRequest()
                    request.requestedScopes = appleRequest.requestedScopes ?? []
                    request.nonce = appleRequest.nonce
                } onCompletion: { result in
                    handleAppleCompletion(result: result)
                }
                .frame(height: 50)
                .disabled(viewModel.state == .loading)
            }

            if viewModel.state == .loading {
                ProgressView("Signing in…")
            }

            Spacer()

            Text("By continuing you agree to our Terms of Service and Privacy Policy.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(red: 0.16, green: 0.32, blue: 0.75))
        }
    }
}

