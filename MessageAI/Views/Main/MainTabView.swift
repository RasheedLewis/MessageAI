import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .conversations

    enum Tab: Hashable {
        case conversations
        case assistant
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ConversationsPlaceholderView()
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(Tab.conversations)

            AssistantPlaceholderView()
                .tabItem {
                    Label("Assistant", systemImage: "sparkles")
                }
                .tag(Tab.assistant)

            SettingsPlaceholderView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
    }
}

private struct ConversationsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Conversation list coming soon")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Button("New Conversation") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
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

private struct SettingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Label("Profile", systemImage: "person.crop.circle")
                    Label("Notifications", systemImage: "bell.fill")
                }

                Section("About") {
                    Label("Terms of Service", systemImage: "doc.text")
                    Label("Privacy Policy", systemImage: "lock.shield")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    MainTabView()
}

