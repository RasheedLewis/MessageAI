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

                voicePersonaSection
                tonePreferencesSection
                signatureSection
                voiceSamplesSection
                styleGuidelinesSection

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

    private var voicePersonaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Creator Persona")
                .font(.theme.subhead)
            Text("Help the AI capture your vibe. Keep it short but evocative.")
                .font(.theme.caption)
                .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))

            TextField("e.g. " + "Empathetic lifestyle creator who keeps things upbeat", text: $viewModel.persona, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
        .padding(16)
        .background(Color.theme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var tonePreferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tone & Format Preferences")
                .font(.theme.subhead)
            Text("Set the default voice and structure for drafted replies.")
                .font(.theme.caption)
                .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))

            Picker("Default Tone", selection: $viewModel.defaultTone) {
                Text("Friendly").tag("friendly")
                Text("Casual").tag("casual")
                Text("Professional").tag("professional")
                Text("Formal").tag("formal")
            }
            .pickerStyle(.segmented)

            Picker("Preferred Format", selection: $viewModel.preferredFormat) {
                Text("Paragraph").tag("paragraph")
                Text("Text").tag("text")
                Text("Bullet").tag("bullet")
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(Color.theme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var signatureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $viewModel.includeSignature) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Include Signature")
                        .font(.theme.subhead)
                    Text("Automatically append a personal sign-off when it makes sense.")
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))
                }
            }

            if viewModel.includeSignature {
                TextField("With gratitude, [Your Name]", text: Binding(
                    get: { viewModel.signature },
                    set: { viewModel.signature = $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
        .padding(16)
        .background(Color.theme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var voiceSamplesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Samples")
                        .font(.theme.subhead)
                    Text("Add a few real replies so the AI stays true to you.")
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))
                }
                Spacer()
                Button(action: viewModel.addVoiceSampleField) {
                    Label("Add", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }

            ForEach(Array(viewModel.voiceSamples.enumerated()), id: \.offset) { index, sample in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sample \(index + 1)")
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))
                        Spacer()
                        if viewModel.voiceSamples.count > 1 {
                            Button(role: .destructive) {
                                viewModel.removeVoiceSample(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    TextField("Hey hey! Thanks so much for reaching out—this totally made my day!", text: Binding(
                        get: { sample },
                        set: { viewModel.voiceSamples[index] = $0 }
                    ), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                }
            }
        }
        .padding(16)
        .background(Color.theme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var styleGuidelinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Style Notes")
                        .font(.theme.subhead)
                    Text("Optional reminders like \"Always lead with gratitude\".")
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnSurface.opacity(0.6))
                }
                Spacer()
                Button(action: viewModel.addStyleGuidelineField) {
                    Label("Add", systemImage: "plus.circle")
                }
                .buttonStyle(.borderless)
            }

            ForEach(Array(viewModel.styleGuidelines.enumerated()), id: \.offset) { index, note in
                HStack(alignment: .top, spacing: 8) {
                    TextField("Keep it concise and actionable.", text: Binding(
                        get: { note },
                        set: { viewModel.styleGuidelines[index] = $0 }
                    ), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)

                    if viewModel.styleGuidelines.count > 1 {
                        Button(role: .destructive) {
                            viewModel.removeStyleGuideline(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Color.theme.error)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.theme.surfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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

