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
            ZStack(alignment: .top) {
                Color.theme.primaryVariant.ignoresSafeArea()

                VStack(spacing: 24) {
                    header
                    ScrollView {
                        VStack(spacing: 24) {
                            groupDetailsCard
                            participantSelectionCard
                            if !viewModel.selectedParticipants.isEmpty {
                                selectedParticipantsCard
                            }
                            createButton
                        }
                        .padding(.bottom, 40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.theme.primaryVariant, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                        .foregroundStyle(Color.theme.accent)
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

    private var header: some View {
        VStack(spacing: 8) {
            Text("Create Group")
                .font(.theme.navTitle)
                .foregroundStyle(Color.theme.accent)
                .shadow(color: Color.theme.accent.opacity(0.4), radius: 8)
            Capsule()
                .fill(Color.theme.accent.opacity(0.3))
                .frame(width: 60, height: 4)
        }
    }

    private var groupDetailsCard: some View {
        GroupCreationCard(title: "Group Details") {
            VStack(spacing: 16) {
                ZStack(alignment: .leading) {
                    if viewModel.groupName.isEmpty {
                        Text("Group Name")
                            .font(.theme.body)
                            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
                            .padding(.leading, 20)
                    }

                    TextField("Group Name", text: $viewModel.groupName)
                        .font(.theme.body)
                        .foregroundStyle(Color.theme.textOnPrimary)
                        .padding()
                        .background(Color.theme.primaryVariant.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                avatarPicker
            }
        }
    }

    private var avatarPicker: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.theme.surface.opacity(0.2))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(Color.theme.accent.opacity(0.4), lineWidth: 2)
                        )

                    if let image = viewModel.groupAvatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                    } else {
                        ThemedIcon(systemName: "photo", state: .custom(Color.theme.textOnPrimary.opacity(0.7), glow: false), size: 22)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.groupAvatarImage == nil ? "Add Group Photo" : "Change Group Photo")
                        .font(.theme.bodyMedium)
                        .foregroundStyle(Color.theme.textOnPrimary)
                    Text("Recommended 512×512")
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
                }
                Spacer()
                ThemedIcon(systemName: "chevron.right", state: .custom(Color.theme.accent, glow: false), size: 16)
            }
            .padding(14)
            .background(Color.theme.primaryVariant.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private var participantSelectionCard: some View {
        GroupCreationCard(title: "Add Participants") {
            VStack(spacing: 16) {
                searchField

                if viewModel.isSearching {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Searching…")
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))
                    }
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    Text("No matches found")
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.searchResults) { result in
                            Button {
                                viewModel.toggleSelection(result)
                            } label: {
                                HStack(spacing: 12) {
                                    avatar(for: result)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.displayName)
                                            .font(.theme.body)
                                            .foregroundStyle(Color.theme.textOnPrimary)
                                        if let email = result.email {
                                            Text(email)
                                                .font(.theme.caption)
                                                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
                                        }
                                    }
                                    Spacer()
                                    if viewModel.isSelected(result) {
                                        ThemedIcon(systemName: "checkmark.circle.fill", state: .custom(Color.theme.accent, glow: true), size: 18)
                                    }
                                }
                                .padding(12)
                                .background(Color.theme.primaryVariant.opacity(0.35))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var selectedParticipantsCard: some View {
        GroupCreationCard(title: "Selected Participants") {
            VStack(spacing: 12) {
                ForEach(viewModel.selectedParticipants) { participant in
                    HStack(spacing: 12) {
                        avatar(for: participant)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(participant.displayName)
                                .font(.theme.bodyMedium)
                                .foregroundStyle(Color.theme.textOnPrimary)
                            if let email = participant.email {
                                Text(email)
                                    .font(.theme.caption)
                                    .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
                            }
                        }
                        Spacer()
                        Button {
                            viewModel.removeParticipant(withID: participant.id)
                        } label: {
                            ThemedIcon(systemName: "xmark.circle.fill", state: .custom(Color.theme.error, glow: false), size: 16)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.theme.primaryVariant.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var createButton: some View {
        Button(action: createGroup) {
            HStack(spacing: 12) {
                ThemedIcon(systemName: "paperplane.fill", state: .custom(Color.theme.accent, glow: true), size: 18)
                if viewModel.isSaving {
                    ProgressView()
                        .tint(Color.theme.accent)
                } else {
                    Text("Create Group")
                        .font(.theme.bodyMedium)
                        .foregroundStyle(Color.theme.accent)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.theme.accent.opacity(viewModel.isSaving ? 0.15 : 0.25))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.theme.accent.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSaving)
    }

    private var searchField: some View {
        HStack {
            ThemedIcon(systemName: "magnifyingglass", state: .custom(Color.theme.textOnSurface.opacity(0.6), glow: false), size: 14)
            TextField("Search by name or email", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onSubmit { viewModel.searchUsersImmediately() }
                .font(.theme.body)
                .foregroundStyle(Color.theme.textOnPrimary)
                .placeholder(when: viewModel.searchQuery.isEmpty) {
                    Text("Search by name or email")
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
                }
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    ThemedIcon(systemName: "xmark.circle", state: .custom(Color.theme.textOnSurface.opacity(0.4), glow: false), size: 14)
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
                        .fill(Color.theme.primaryVariant.opacity(0.15))
                        .overlay(
                            ThemedIcon(systemName: "photo", state: .inactive, size: 14)
                        )
                }
            } else {
                Circle()
                    .fill(Color.theme.primaryVariant.opacity(0.15))
                    .overlay(
                        Text(initials(from: result.displayName))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))
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

private struct GroupCreationCard<Content: View>: View {
    let title: String
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
            .background(Color.theme.primary.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
}

#Preview {
    GroupCreationView(services: ServiceResolver.previewResolver) { _ in }
}



