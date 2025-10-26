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
    @State private var showSignOutToast = false
    @State private var profileViewModel = AuthenticationViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.theme.primaryVariant.ignoresSafeArea()

                VStack(spacing: 24) {
                    settingsHeader
                    settingsContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .toolbarBackground(Color.theme.primaryVariant, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toast(isPresented: $showSignOutToast) {
                ThemedToast(title: "You're signed out", message: "Come back soon")
            }
        }
    }

    private var settingsHeader: some View {
        VStack(spacing: 8) {
            Text("Settings")
                .font(.theme.navTitle)
                .foregroundStyle(Color.theme.accent)
                .shadow(color: Color.theme.accent.opacity(0.4), radius: 8)
            Capsule()
                .fill(Color.theme.accent.opacity(0.3))
                .frame(width: 60, height: 4)
        }
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                accountCard
                aboutCard
                dangerZone
            }
            .padding(.bottom, 24)
        }
    }

    private var accountCard: some View {
        SettingsCard(title: "Account", background: Color.theme.primary) {
            NavigationLink {
                ProfileSetupView(viewModel: profileViewModel)
                    .navigationTitle("Edit Profile")
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                SettingsRow(icon: "person.crop.circle", title: "Profile", subtitle: "Edit creator persona & voice")
            }

            SettingsRow(icon: "bell.fill", title: "Notifications", subtitle: "Manage push preferences")
        }
    }

    private var aboutCard: some View {
        SettingsCard(title: "About", background: Color.theme.primary) {
            SettingsRow(icon: "doc.text", title: "Terms of Service", subtitle: "Legal information")
            SettingsRow(icon: "lock.shield", title: "Privacy Policy", subtitle: "How we protect your data")
        }
    }

    private var dangerZone: some View {
        SettingsCard(title: "Danger Zone", accent: Color.theme.error.opacity(0.8), background: Color.theme.primary) {
            Button(role: .destructive, action: signOut) {
                HStack(spacing: 12) {
                    ThemedIcon(systemName: "rectangle.portrait.and.arrow.right", state: .custom(Color.theme.error, glow: false), size: 18)
                    if isSigningOut {
                        ProgressView().tint(Color.theme.error)
                    } else {
                        Text("Sign Out")
                            .font(.theme.bodyMedium)
                            .foregroundStyle(Color.theme.error)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .disabled(isSigningOut)
        }
    }

    private func signOut() {
        guard !isSigningOut else { return }
        isSigningOut = true
        do {
            onSignOut()
            withAnimation {
                showSignOutToast = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSigningOut = false
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    var accent: Color = Color.white.opacity(0.08)
    var background: Color = Color.theme.primaryVariant.opacity(0.75)
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title.uppercased())
                .font(.theme.captionMedium)
                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.5))
                .padding(.bottom, 4)

            VStack(spacing: 12) {
                content
            }
            .padding(16)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(accent, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            ThemedIcon(systemName: icon, state: .active, size: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.theme.bodyMedium)
                    .foregroundStyle(Color.theme.textOnPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.theme.caption)
                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.3))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct ThemedToast: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.theme.bodyMedium)
                .foregroundStyle(Color.theme.textOnPrimary)
            Text(message)
                .font(.theme.caption)
                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.theme.primaryVariant.opacity(0.9))
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        )
    }
}

#Preview {
    MainTabView(services: ServiceResolver.previewResolver)
        .environmentObject(NotificationCoordinator())
}

