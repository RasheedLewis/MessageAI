import Photos
import PhotosUI
import SwiftUI
import UIKit

struct ProfileSetupView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var isSaving = false
    @FocusState private var isNameFieldFocused: Bool
    @State private var photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @State private var showPhotoSettingsAlert = false
    @State private var imageLoadErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Set up your creator profile")
                    .font(.theme.display)
                    .multilineTextAlignment(.center)

                Text("Let fans know who you are. Add a display name and optional profile photo.")
                    .font(.theme.body)
                    .foregroundStyle(Color.theme.textOnSurface.opacity(0.7))
                    .multilineTextAlignment(.center)

                avatarPicker

                VStack(alignment: .leading, spacing: 12) {
                    Text("Display Name")
                        .font(.theme.subhead)

                    TextField("Your name", text: $viewModel.displayName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                }

                Button {
                    Task { await saveProfile() }
                } label: {
                    Text(isSaving ? "Saving…" : "Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(isContinueEnabled ? .primaryThemed : .primaryDisabledThemed)
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
        .task {
            await refreshPhotoAuthorizationStatus()
        }
        .alert("Profile Setup Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.error ?? "Unknown error")
        }
        .alert("Photo Access Required", isPresented: $showPhotoSettingsAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow MessageAI to access your photo library from Settings to upload a profile picture.")
        }
        .alert("Photo Error", isPresented: Binding(
            get: { imageLoadErrorMessage != nil },
            set: { if !$0 { imageLoadErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(imageLoadErrorMessage ?? "Unknown error")
        }
    }

    private var avatarPicker: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.theme.primaryVariant.opacity(0.12))
                    .frame(width: 120, height: 120)

                if let profileImage {
                    profileImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    ThemedIcon(systemName: "person", state: .custom(Color.theme.textOnSurface.opacity(0.6), glow: false), size: 32, withContainer: true)
                }
            }

            Group {
                if photoAuthorizationStatus == .denied || photoAuthorizationStatus == .restricted {
                    Button {
                        showPhotoSettingsAlert = true
                    } label: {
                        Text("Enable Photo Access")
                            .font(.theme.bodyMedium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(Color.theme.error))
                            .foregroundStyle(Color.theme.error)
                    }
                } else {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text(profileImage == nil ? "Upload Photo" : "Change Photo")
                            .font(.theme.bodyMedium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).stroke(Color.theme.accent))
                            .foregroundStyle(Color.theme.accent)
                    }
                }
            }
        }
    }

    private var isContinueEnabled: Bool {
        !isSaving && !viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func loadImage(from pickerItem: PhotosPickerItem) async {
        do {
            guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    imageLoadErrorMessage = "Unable to read the selected photo."
                }
                return
            }

            guard let uiImage = UIImage(data: data) else {
                await MainActor.run {
                    imageLoadErrorMessage = "The selected file could not be converted into an image."
                }
                return
            }

            await MainActor.run {
                profileImage = Image(uiImage: uiImage)
            }
        } catch {
            await MainActor.run {
                imageLoadErrorMessage = error.localizedDescription
            }
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

    private func refreshPhotoAuthorizationStatus() async {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus == .notDetermined {
            let grantedStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            await MainActor.run {
                photoAuthorizationStatus = grantedStatus
            }
        } else {
            await MainActor.run {
                photoAuthorizationStatus = currentStatus
            }
        }
    }
}

#Preview {
    ProfileSetupView(viewModel: AuthenticationViewModel())
}

