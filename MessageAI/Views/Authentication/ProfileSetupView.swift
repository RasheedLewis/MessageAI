import PhotosUI
import SwiftUI
import UIKit

struct ProfileSetupView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var isSaving = false
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Set up your creator profile")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Let fans know who you are. Add a display name and optional profile photo.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                avatarPicker

                VStack(alignment: .leading, spacing: 12) {
                    Text("Display Name")
                        .font(.headline)

                    TextField("Your name", text: $viewModel.displayName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                }

                Button {
                    Task { await saveProfile() }
                } label: {
                    Text(isSaving ? "Saving…" : "Continue")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isContinueEnabled ? Color.accentColor : Color.gray.opacity(0.3))
                        .foregroundStyle(isContinueEnabled ? Color.white : Color.secondary)
                        .cornerRadius(12)
                }
                .disabled(!isContinueEnabled)
            }
            .padding(24)
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await loadImage(from: newItem)
            }
        }
        .onAppear {
            isNameFieldFocused = true
        }
        .alert("Profile Setup Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "Unknown error")
        }
    }

    private var avatarPicker: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 120, height: 120)

                if let profileImage {
                    profileImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundStyle(.secondary)
                }
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text("Upload Photo")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.accentColor))
            }
        }
    }

    private var isContinueEnabled: Bool {
        !isSaving && !viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadImage(from pickerItem: PhotosPickerItem) async {
        guard let data = try? await pickerItem.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
            return
        }

        await MainActor.run {
            profileImage = Image(uiImage: uiImage)
        }
    }

    private func saveProfile() async {
        isSaving = true
        let imageData = profileImage.flatMap { uiImage(from: $0)?.jpegData(compressionQuality: 0.8) }
        await viewModel.completeProfileSetup(selectedImageData: imageData)
        isSaving = false
    }

    private func uiImage(from image: Image) -> UIImage? {
        let renderer = ImageRenderer(content: image)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

#Preview {
    ProfileSetupView(viewModel: AuthenticationViewModel())
}

