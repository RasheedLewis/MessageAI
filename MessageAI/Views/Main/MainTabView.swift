import SwiftUI

struct MainTabView: View {
    let services: ServiceResolver
    @EnvironmentObject private var notificationCoordinator: NotificationCoordinator
    @State private var selectedTab: Tab = .conversations
    @State private var deepLinkConversationID: String?

    enum Tab: Hashable {
        case conversations
        case assistant
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationListView(services: services)
                .tabItem {
                    Label {
                        Text("Messages")
                    } icon: {
                        ThemedIcon(
                            systemName: "bubble.left.and.bubble.right",
                            state: selectedTab == .conversations ? .custom(Color.theme.secondary, glow: true) : .inactive,
                            size: 20,
                            withContainer: true
                        )
                    }
                }
                .tag(Tab.conversations)

            AssistantPlaceholderView()
                .tabItem {
                    Label {
                        Text("Assistant")
                    } icon: {
                        ThemedIcon(
                            systemName: "sparkles",
                            state: selectedTab == .assistant ? .custom(Color.theme.secondary, glow: true) : .inactive,
                            size: 20,
                            withContainer: true
                        )
                    }
                }
                .tag(Tab.assistant)

            SettingsView(onSignOut: AuthenticationViewModel().signOut)
                .tabItem {
                    Label {
                        Text("Settings")
                    } icon: {
                        ThemedIcon(
                            systemName: "gearshape",
                            state: selectedTab == .settings ? .custom(Color.theme.secondary, glow: true) : .inactive,
                            size: 20,
                            withContainer: true
                        )
                    }
                }
                .tag(Tab.settings)
        }
        .tint(Color.theme.secondary)
        .onReceive(notificationCoordinator.$pendingConversationID) { conversationID in
            guard let conversationID else { return }
            deepLinkConversationID = conversationID
            selectedTab = .conversations
            notificationCoordinator.consumePendingConversation()
        }
        .background(Color.theme.primary)
    }
}

private struct AssistantPlaceholderView: View {
    var body: some View {
        VStack(spacing: 12) {
            ThemedIcon(systemName: "sparkles", state: .active, size: 40)
            Text("AI Assistant workspace in progress")
                .font(.theme.subhead)
                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.theme.primaryVariant)
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
                    NavigationLink {
                        ProfileSetupView(viewModel: profileViewModel)
                            .navigationTitle("Edit Profile")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
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

    @State private var profileViewModel = AuthenticationViewModel()

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
        .environmentObject(NotificationCoordinator())
}

