import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel: ConversationListViewModel
    @State private var isPresentingNewConversation = false

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
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $isPresentingNewConversation) {
                GroupCreationView(services: viewModel.services) { conversationID in
                    viewModel.refresh()
                    isPresentingNewConversation = false
                }
                .presentationDetents([.medium, .large])
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            CategoryFilterView(selectedCategory: $viewModel.selectedFilter)

            if viewModel.conversations.isEmpty {
                EmptyStateView(
                    title: "No conversations yet",
                    message: "Start a new chat to see messages here."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.conversations) { conversation in
                    NavigationLink {
                        ConversationDetailView(conversationID: conversation.id, services: viewModel.services)
                    } label: {
                        ConversationRowView(item: conversation)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .refreshable { viewModel.refresh() }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ConversationListView(services: ServiceResolver.previewResolver)
}

