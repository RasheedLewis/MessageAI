import PhotosUI
import SwiftUI

struct GroupCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: GroupCreationViewModel
    @State private var photoItem: PhotosPickerItem?

    private let services: ServiceResolver
    private let onConversationCreated: (String) -> Void

    init(
        services: ServiceResolver,
        onConversationCreated: @escaping (String) -> Void
    ) {
        self.services = services
        self.onConversationCreated = onConversationCreated
        _viewModel = StateObject(wrappedValue: GroupCreationViewModel(services: services))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("New Group")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: dismiss.callAsFunction)
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: createGroup) {
                            if viewModel.isSaving {
                                ProgressView()
                            } else {
                                Text("Create")
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(viewModel.isSaving)
                    }
                }
        }
        .task(id: photoItem) {
            await loadPhoto()
        }
        .alert("Oops", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.clearError() }
        )) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }

    private var content: some View {
        Form {
            Section("Group Details") {
                TextField("Group Name", text: $viewModel.groupName)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    HStack {
                        if let image = viewModel.groupAvatarImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(viewModel.groupAvatarImage == nil ? "Add Photo" : "Change Photo")
                            .foregroundStyle(.primary)
                    }
                }
            }

            if !viewModel.selectedParticipants.isEmpty {
                Section("Selected Participants") {
                    ForEach(viewModel.selectedParticipants) { participant in
                        HStack {
                            avatar(for: participant)
                            VStack(alignment: .leading) {
                                Text(participant.displayName)
                                    .font(.body)
                                if let email = participant.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                viewModel.removeParticipant(withID: participant.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Add Participants") {
                searchField

                if viewModel.isSearching {
                    HStack {
                        ProgressView()
                        Text("Searching…")
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    Text("No matches found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.searchResults) { result in
                        HStack {
                            avatar(for: result)
                            VStack(alignment: .leading) {
                                Text(result.displayName)
                                    .font(.body)
                                if let email = result.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            if viewModel.isSelected(result) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.toggleSelection(result)
                        }
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search by name or email", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onSubmit { viewModel.searchUsersImmediately() }
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func avatar(for result: GroupCreationViewModel.SearchResult) -> some View {
        Group {
            if let url = result.photoURL {
                AsyncImage(url: url) { image in
                    image.resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            ProgressView()
                        )
                }
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        Text(initials(from: result.displayName))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).map { $0.prefix(1).uppercased() }.joined()
    }

    private func createGroup() {
        Task {
            if let conversationID = await viewModel.createGroupConversation() {
                onConversationCreated(conversationID)
                dismiss()
            }
        }
    }

    private func loadPhoto() async {
        guard let photoItem else { return }
        do {
            if let data = try await photoItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    viewModel.groupAvatarImage = image
                }
            }
        } catch {
            await MainActor.run {
                viewModel.presentError(error.localizedDescription)
            }
        }
    }
}

#Preview {
    GroupCreationView(services: ServiceResolver.previewResolver) { _ in }
}



