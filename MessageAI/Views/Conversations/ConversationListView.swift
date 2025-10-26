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
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isPresentingNewConversation = true }) {
                        ThemedIcon(systemName: "square.and.pencil", state: .active, size: 18)
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
                        ConversationRowView(item: conversation)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .refreshable { viewModel.refresh() }
            }
        }
        .background(Color.theme.primary)
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

