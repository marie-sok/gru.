import PhotosUI
import SwiftUI
import UIKit

@MainActor
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable private var service = ChatService.shared
    @StateObject private var profile = ProfileStorage.shared

    @State private var selectedAvatar: PhotosPickerItem?
    @State private var showAvatarSource = false
    @State private var showAvatarLibrary = false
    @State private var showAvatarCamera = false

    var body: some View {
        NavigationStack {
            ZStack {
                GRUAppBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        avatarSection
                        identitySection
                        bioSection
                        privacyNote
                        Spacer(minLength: 30)
                    }
                    .padding(18)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GRUNeonIconButton(
                        systemName: "chevron.left",
                        accessibilityLabel: "Назад",
                        size: 36,
                        iconSize: 14
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Профиль")
                        .font(.headline)
                }
            }
        }
        .onAppear {
            profile.applyFallbackNickname(service.currentUser.displayName)
            service.currentUser.username = profile.username
            service.currentUser.displayName = profile.nickname
        }
        .onChange(of: profile.username) { _, value in
            service.currentUser.username = value
        }
        .onChange(of: profile.nickname) { _, value in
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                service.currentUser.displayName = clean
            }
        }
        .onChange(of: selectedAvatar) { _, item in
            loadAvatar(item)
        }
        .photosPicker(
            isPresented: $showAvatarLibrary,
            selection: $selectedAvatar,
            matching: .images
        )
        .fullScreenCover(isPresented: $showAvatarCamera) {
            AvatarCameraPicker(
                onPicked: { image in
                    saveAvatar(image)
                    showAvatarCamera = false
                },
                onCancel: {
                    showAvatarCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .confirmationDialog(
            "Аватар",
            isPresented: $showAvatarSource,
            titleVisibility: .visible
        ) {
            Button("Выбрать из медиатеки") {
                showAvatarLibrary = true
            }

            Button("Снять камерой") {
                showAvatarCamera = true
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            if profile.avatarData != nil {
                Button("Удалить аватар", role: .destructive) {
                    profile.removeAvatar()
                    service.currentUser.avatarData = nil
                }
            }

            Button("Отмена", role: .cancel) {}
        }
    }
}

private extension ProfileView {
    var avatarSection: some View {
        VStack(spacing: 14) {
            Button {
                showAvatarSource = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    avatarImage
                        .frame(width: 116, height: 116)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(GRUColors.neonGradient, lineWidth: 2.4)
                        }
                        .shadow(color: GRUColors.accent.opacity(0.52), radius: 20)
                        .shadow(color: GRUColors.accentSecondary.opacity(0.22), radius: 30)

                    GRUNeonIcon(
                        systemName: "camera.fill",
                        size: 40,
                        iconSize: 15
                    )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Изменить аватар")

            Text(profile.nickname.isEmpty ? "gru." : profile.nickname)
                .font(.title2.bold())

            Text("@\(profile.username)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(GRUColors.accent)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    var avatarImage: some View {
        if let data = profile.avatarData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Circle()
                    .fill(GRUColors.accent.opacity(0.14))
                Image(systemName: "person.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(GRUColors.accent)
            }
        }
    }

    var identitySection: some View {
        VStack(spacing: 12) {
            fieldRow(icon: "person.text.rectangle.fill", title: "Никнейм") {
                TextField("Никнейм", text: $profile.nickname)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.words)
            }

            fieldRow(icon: "at", title: "Username") {
                TextField("gru.user", text: $profile.username)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            profileRow(
                icon: "circle.fill",
                title: "Статус",
                value: service.currentUser.isOnline ? "Online" : "Offline"
            )
        }
    }

    var bioSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                GRUNeonIcon(
                    systemName: "quote.bubble.fill",
                    size: 34,
                    iconSize: 14
                )
                Text("Био")
                    .font(.headline)
                Spacer()
                Text("\(profile.bio.count)/160")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: $profile.bio)
                .frame(minHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(GRUColors.card.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(GRUColors.accent.opacity(0.22), lineWidth: 1)
                }
        }
    }

    var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            GRUNeonIcon(
                systemName: "lock.shield.fill",
                size: 36,
                iconSize: 14
            )

            Text("Голосовые и видео-сообщения остаются только внутри переписок и не создают отдельную медиатеку.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GRUColors.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func profileRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            GRUNeonIcon(systemName: icon, size: 36, iconSize: 14)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(GRUColors.card.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func fieldRow<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            GRUNeonIcon(systemName: icon, size: 36, iconSize: 14)
            Text(title)
            Spacer()
            content()
                .foregroundStyle(.secondary)
                .frame(maxWidth: 170)
        }
        .padding(12)
        .background(GRUColors.card.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    func loadAvatar(_ item: PhotosPickerItem?) {
        guard let item else { return }

        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else {
                    return
                }

                await MainActor.run {
                    saveAvatar(image)
                    service.currentUser.avatarData = profile.avatarData
                    selectedAvatar = nil
                }
            } catch {
                print("❌ Avatar picker error:", error)
            }
        }
    }

    func saveAvatar(_ image: UIImage) {
        let targetSize = CGSize(width: 720, height: 720)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let rendered = renderer.image { _ in
            let scale = max(
                targetSize.width / image.size.width,
                targetSize.height / image.size.height
            )
            let drawSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            let origin = CGPoint(
                x: (targetSize.width - drawSize.width) / 2,
                y: (targetSize.height - drawSize.height) / 2
            )

            image.draw(in: CGRect(origin: origin, size: drawSize))
        }

        profile.avatarData = rendered.jpegData(compressionQuality: 0.84)
        service.currentUser.avatarData = profile.avatarData
        UINotificationFeedbackGenerator()
            .notificationOccurred(.success)
    }
}

struct AvatarCameraPicker: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    final class Coordinator: NSObject,
        UINavigationControllerDelegate,
        UIImagePickerControllerDelegate {
        let parent: AvatarCameraPicker

        init(parent: AvatarCameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image =
                info[.editedImage] as? UIImage ??
                info[.originalImage] as? UIImage

            if let image {
                parent.onPicked(image)
            } else {
                parent.onCancel()
            }
        }
    }
}

#Preview { ProfileView() }
