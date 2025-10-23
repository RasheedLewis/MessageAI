import SwiftUI

struct MainTabView: View {
    let services: ServiceResolver
    @State private var selectedTab: Tab = .conversations

    enum Tab: Hashable {
        case conversations
        case assistant
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationListView(services: services)
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(Tab.conversations)

            AssistantPlaceholderView()
                .tabItem {
                    Label("Assistant", systemImage: "sparkles")
                }
                .tag(Tab.assistant)

            SettingsView(onSignOut: AuthenticationViewModel().signOut)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
    }
}

private struct AssistantPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(Color.accentColor)
            Text("AI Assistant workspace in progress")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct SettingsView: View {
    let onSignOut: () -> Void

    @State private var isSigningOut = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Label("Profile", systemImage: "person.crop.circle")
                    Label("Notifications", systemImage: "bell.fill")

                    Button(role: .destructive, action: signOut) {
                        if isSigningOut {
                            ProgressView()
                        } else {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                    .disabled(isSigningOut)
                }

                Section("About") {
                    Label("Terms of Service", systemImage: "doc.text")
                    Label("Privacy Policy", systemImage: "lock.shield")
                }
            }
            .navigationTitle("Settings")
            .alert("Couldn't sign out", isPresented: Binding(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }

    private func signOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        do {
            onSignOut()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningOut = false
    }
}

#Preview {
    MainTabView(services: ServiceResolver.previewResolver)
}

