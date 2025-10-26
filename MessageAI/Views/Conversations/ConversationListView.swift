import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel: ConversationListViewModel
    @State private var isPresentingNewConversation = false
    @EnvironmentObject private var notificationCoordinator: NotificationCoordinator
    @State private var activeConversationID: String?

    init(services: ServiceResolver) {
        _viewModel = StateObject(wrappedValue: ConversationListViewModel(services: services))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                listView

                if case .loading = viewModel.loadingState {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.conversationBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Messages")
                        .font(.theme.navTitle)
                        .fontWeight(.semibold)
                        .tracking(1)
                        .foregroundStyle(Color.theme.accent)
                        .frame(height: 34)
                        .shadow(color: Color.theme.accent.opacity(0.45), radius: 8)
                        .offset(y: 8)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresentingNewConversation = true }) {
                        ThemedIcon(systemName: "square.and.pencil", state: .custom(Color.theme.secondary, glow: true), size: 18)
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewConversation) {
                GroupCreationView(services: viewModel.services) { conversationID in
                    viewModel.refresh()
                    isPresentingNewConversation = false
                    navigate(to: conversationID)
                }
                .presentationDetents([.medium, .large])
            }
        }
        .background(Color.theme.primary)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .onReceive(notificationCoordinator.$pendingConversationID) { conversationID in
            guard let conversationID else { return }
            navigate(to: conversationID)
            notificationCoordinator.consumePendingConversation()
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            CategoryFilterView(
                selectedCategory: $viewModel.selectedFilter,
                counts: viewModel.filterCounts,
                uncategorizedCount: viewModel.uncategorizedCount
            )

            if viewModel.conversations.isEmpty {
                EmptyStateView(
                    title: "No conversations yet",
                    message: "Start a new chat to see messages here."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.conversations) { conversation in
                    NavigationLink(
                        destination: ConversationDetailView(
                            conversationID: conversation.id,
                            services: viewModel.services
                        ),
                        tag: conversation.id,
                        selection: $activeConversationID
                    ) {
                        ConversationRowView(
                            item: conversation,
                            onOverrideCategory: { category in
                                viewModel.overrideCategory(for: conversation.id, to: category)
                            },
                            onClearOverride: {
                                viewModel.clearOverride(for: conversation.id)
                            }
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .environment(\.defaultMinListRowHeight, 76.0)
                .refreshable { viewModel.refresh() }
            }
        }
        .background(AppColors.conversationBackground)
        .onAppear {
            if let pending = notificationCoordinator.pendingConversationID {
                navigate(to: pending)
                notificationCoordinator.consumePendingConversation()
            }
        }
    }

    private func navigate(to conversationID: String) {
        activeConversationID = conversationID
    }
}

#Preview {
    ConversationListView(services: ServiceResolver.previewResolver)
        .environmentObject(NotificationCoordinator())
}

