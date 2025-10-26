import Photos
import PhotosUI
import SwiftUI
import UIKit

fileprivate struct SettingsCard<Content: View>: View {
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
enum ProfileFormSection: String, CaseIterable {
    case identity
    case personality
    case preferences
    case signature
    case samples
    case guidelines
}

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
        NavigationStack {
            ZStack(alignment: .top) {
                Color.theme.primaryVariant.ignoresSafeArea()

        ScrollView {
                    VStack(spacing: 28) {
                        header
                avatarPicker
                        identitySection
                        voicePersonaSection
                        tonePreferencesSection
                        signatureSection
                        voiceSamplesSection
                        styleGuidelinesSection
                        saveButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
            }
            .toolbarBackground(Color.theme.primaryVariant, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationTitle("Creator Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadImage(from: newItem) }
        }
        .onAppear { isNameFieldFocused = true }
        .task { await refreshPhotoAuthorizationStatus() }
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

    private var header: some View {
        VStack(spacing: 12) {
            Text("Dial in your creator identity")
                .font(.theme.navTitle)
                .foregroundStyle(Color.theme.accent)
                .shadow(color: Color.theme.accent.opacity(0.4), radius: 8)
                .multilineTextAlignment(.center)

            Text("Fine-tune your voice, tone, and style so AI responses feel authentically you.")
                .font(.theme.caption)
                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 36)
    }

    private var avatarPicker: some View {
        SettingsCard(title: "Profile Photo", background: Color.theme.primary) {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                        .fill(Color.theme.primary.opacity(0.15))
                    .frame(width: 120, height: 120)

                if let profileImage {
                    profileImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                        ThemedIcon(
                            systemName: "person",
                            state: .custom(Color.theme.textOnPrimary.opacity(0.6), glow: false),
                            size: 40,
                            withContainer: true
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                if photoAuthorizationStatus == .denied || photoAuthorizationStatus == .restricted {
                    Button {
                        showPhotoSettingsAlert = true
                    } label: {
                        Text("Enable Photo Access")
                            .font(.theme.bodyMedium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.theme.error)
                            )
                            .foregroundStyle(Color.theme.error)
                    }
                } else {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Text(profileImage == nil ? "Upload Photo" : "Change Photo")
                            .font(.theme.bodyMedium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.theme.accent.opacity(0.4))
                            )
                            .foregroundStyle(Color.theme.accent)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var identitySection: some View {
        SettingsCard(title: "Identity", background: Color.theme.primary) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Display Name")
                    .font(.theme.subhead)
                        .foregroundStyle(Color.theme.textOnPrimary)

                TextField("Your name", text: $viewModel.displayName)
                    .padding(12)
                    .background(Color.theme.primaryVariant.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.theme.accent.opacity(0.25), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .foregroundStyle(Color.theme.textOnPrimary)
                        .placeholder(when: viewModel.displayName.isEmpty) {
                            Text("Your name")
                                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.5))
                        }
                    .focused($isNameFieldFocused)
                    .submitLabel(.done)
            }
        }
    }

    private var voicePersonaSection: some View {
        SettingsCard(title: "Creator Persona", background: Color.theme.primary) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Help the AI capture your vibe. Keep it short but evocative.")
                    .font(.theme.caption)
                    .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))

                TextField("Empathetic lifestyle creator who keeps things upbeat", text: $viewModel.persona, axis: .vertical)
                    .padding(12)
                    .background(Color.theme.primaryVariant.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.theme.accent.opacity(0.25), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .foregroundStyle(Color.theme.textOnPrimary)
                    .lineLimit(2...4)
                    .placeholder(when: viewModel.persona.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        Text("Empathetic lifestyle creator who keeps things upbeat")
                            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.5))
                            .padding(.leading, 12)
                    }
            }
        }
    }

    private var tonePreferencesSection: some View {
        SettingsCard(title: "Tone & Format", background: Color.theme.primary) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Set the default voice and structure for drafted replies.")
                    .font(.theme.caption)
                    .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Default Tone")
                        .font(.theme.captionMedium)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.85))

                    Picker("Default Tone", selection: $viewModel.defaultTone) {
                        ForEach(toneOptions, id: \.self) { option in
                            Text(toneLabel(for: option))
                                .tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(6)
                    .background(AppColors.filterInactiveBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.filterInactiveBorder, lineWidth: 1)
                    )
                    .colorScheme(.dark)
                    .tint(Color.theme.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferred Format")
                        .font(.theme.captionMedium)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.85))

                    Picker("Preferred Format", selection: $viewModel.preferredFormat) {
                        ForEach(formatOptions, id: \.self) { option in
                            Text(formatLabel(for: option))
                                .tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(6)
                    .background(AppColors.filterInactiveBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.filterInactiveBorder, lineWidth: 1)
                    )
                    .colorScheme(.dark)
                    .tint(Color.theme.accent)
                }
            }
        }
    }

    private var signatureSection: some View {
        SettingsCard(title: "Signature", background: Color.theme.primary) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $viewModel.includeSignature) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Include Signature")
                            .font(.theme.subhead)
                            .foregroundStyle(Color.theme.textOnPrimary)
                        Text("Automatically append a personal sign-off when it makes sense.")
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.8))
                    }
                }

                if viewModel.includeSignature {
                    TextField("With gratitude, [Your Name]", text: Binding(
                        get: { viewModel.signature },
                        set: { viewModel.signature = $0 }
                    ))
                    .padding(12)
                    .background(Color.theme.primaryVariant.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.theme.accent.opacity(0.25), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .foregroundStyle(Color.theme.textOnPrimary)
                    .placeholder(when: viewModel.signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        Text("With gratitude, [Your Name]")
                            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.5))
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }

    private var voiceSamplesSection: some View {
        SettingsCard(title: "Voice Samples", background: Color.theme.primary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Add a few real replies so the AI stays true to you.")
                            .font(.theme.caption)
                            .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))
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
                                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.6))
                            Spacer()
                            if viewModel.voiceSamples.count > 1 {
                                Button(role: .destructive) {
                                    viewModel.removeVoiceSample(at: index)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(Color.theme.error)
                            }
                        }
                        TextField("Hey hey! Thanks so much for reaching out—this totally made my day!", text: Binding(
                            get: { sample },
                            set: { viewModel.voiceSamples[index] = $0 }
                        ), axis: .vertical)
                        .padding(12)
                        .background(Color.theme.primaryVariant.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.theme.accent.opacity(0.25), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .foregroundStyle(Color.theme.textOnPrimary)
                        .lineLimit(2...4)
                        .placeholder(when: sample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                        Text("Hey hey! Thanks so much for reaching out—this totally made my day!")
                                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.5))
                                .padding(.leading, 12)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var styleGuidelinesSection: some View {
        SettingsCard(title: "Style Notes", background: Color.theme.primary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Optional reminders like \"Always lead with gratitude\".")
                        .font(.theme.caption)
                        .foregroundStyle(Color.theme.textOnPrimary.opacity(0.7))
                    Spacer()
                    Button(action: viewModel.addStyleGuidelineField) {
                        Label("Add", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                }

                ForEach(Array(viewModel.styleGuidelines.enumerated()), id: \.offset) { index, note in
                    HStack(alignment: .top, spacing: 12) {
                        TextField("Keep it concise and actionable.", text: Binding(
                            get: { note },
                            set: { viewModel.styleGuidelines[index] = $0 }
                        ), axis: .vertical)
                        .padding(12)
                        .background(Color.theme.primaryVariant.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.theme.accent.opacity(0.25), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .foregroundStyle(Color.theme.textOnPrimary)
                        .lineLimit(1...3)
                        .placeholder(when: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                            Text("Keep it concise and actionable.")
                                .foregroundStyle(Color.theme.textOnPrimary.opacity(0.5))
                                .padding(.leading, 12)
                        }

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
        }
    }

    private var saveButton: some View {
        Button {
            guard !isSaving else { return }
            Task { await saveProfile() }
        } label: {
            Text(isSaving ? "Saving…" : "Save Profile")
                .font(.theme.bodyMedium)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.theme.accent.opacity(isContinueEnabled ? 0.18 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.theme.accent.opacity(isContinueEnabled ? 0.4 : 0.2), lineWidth: 1)
        )
        .foregroundStyle(Color.theme.accent.opacity(isContinueEnabled ? 0.85 : 0.4))
        .disabled(!isContinueEnabled)
        .frame(maxWidth: .infinity)
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

    private var toneOptions: [String] { ["friendly", "casual", "professional", "formal"] }
    private var formatOptions: [String] { ["paragraph", "text", "bullet"] }

    private func toneLabel(for option: String) -> String {
        switch option {
        case "friendly": return "Friendly"
        case "casual": return "Casual"
        case "professional": return "Professional"
        case "formal": return "Formal"
        default: return option.capitalized
        }
    }

    private func formatLabel(for option: String) -> String {
        switch option {
        case "paragraph": return "Paragraph"
        case "text": return "Text"
        case "bullet": return "Bullet"
        default: return option.capitalized
        }
    }
}

#Preview {
    ProfileSetupView(viewModel: AuthenticationViewModel())
}

