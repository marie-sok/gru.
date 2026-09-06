import PhotosUI
import SwiftUI
import UIKit

@MainActor
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable private var service = ChatService.shared
    @StateObject private var profile = ProfileStorage.shared

    @AppStorage(GRUTheme.selectionKey)
    private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    @State private var selectedAvatar: PhotosPickerItem?
    @State private var showAvatarSource = false
    @State private var showAvatarLibrary = false
    @State private var showAvatarCamera = false

    private var currentTheme: GRUAppTheme {
        let selected = GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
        return GRUThemePolicy.allowed.contains(selected) ? selected : .blackMoonCat
    }

    private var displayName: String {
        let value = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "gru." : value
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GRUAppBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        compactProfileHeader
                        identitySection
                        bioSection
                        privacyNote
                        Spacer(minLength: 28)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    GRUNeonIconButton(
                        systemName: "chevron.left",
                        accessibilityLabel: GRUL10n.text("Назад"),
                        size: 36,
                        iconSize: 14
                    ) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(GRUL10n.text("Профиль"))
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
            GRUL10n.text("Аватар"),
            isPresented: $showAvatarSource,
            titleVisibility: .visible
        ) {
            Button(GRUL10n.text("Выбрать из медиатеки")) {
                showAvatarLibrary = true
            }

            Button(GRUL10n.text("Снять камерой")) {
                showAvatarCamera = true
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            if profile.avatarData != nil {
                Button(GRUL10n.text("Удалить аватар"), role: .destructive) {
                    profile.removeAvatar()
                    service.currentUser.avatarData = nil
                }
            }

            Button(GRUL10n.text("Отмена"), role: .cancel) {}
        }
    }
}

private extension ProfileView {
    var compactProfileHeader: some View {
        HStack(spacing: 14) {
            Button {
                showAvatarSource = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    avatarImage
                        .frame(width: 78, height: 78)
                        .clipShape(Circle())
                        .overlay {
                            Circle()
                                .stroke(GRUColors.neonGradient, lineWidth: 1.8)
                        }
                        .shadow(
                            color: currentTheme.accent.opacity(0.20),
                            radius: 12
                        )

                    ZStack {
                        Circle()
                            .fill(GRUColors.card)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(currentTheme.accent)
                    }
                    .frame(width: 27, height: 27)
                    .overlay {
                        Circle()
                            .stroke(currentTheme.accent.opacity(0.42), lineWidth: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(GRUL10n.text("Изменить аватар"))

            VStack(alignment: .leading, spacing: 5) {
                Text(displayName)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .lineLimit(1)

                if !profile.username.isEmpty {
                    Text("@\(profile.username)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(currentTheme.accent)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(
                            service.currentUser.isOnline
                                ? currentTheme.accent
                                : Color.secondary.opacity(0.55)
                        )
                        .frame(width: 6, height: 6)

                    Text(
                        GRUL10n.text(
                            service.currentUser.isOnline ? "online" : "offline"
                        )
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(currentTheme.accent.opacity(0.12), lineWidth: 1)
        }
    }

    var identitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                icon: "person.text.rectangle.fill",
                title: "Данные профиля",
                subtitle: "имя и username"
            )

            fieldRow(icon: "person.fill", title: "Никнейм") {
                TextField(GRUL10n.text("Никнейм"), text: $profile.nickname)
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
                value: service.currentUser.isOnline ? "online" : "offline"
            )
        }
        .padding(14)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(currentTheme.accent.opacity(0.12), lineWidth: 1)
        }
    }

    var bioSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionTitle(
                icon: "quote.bubble.fill",
                title: "Био",
                subtitle: "коротко о себе"
            )

            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $profile.bio)
                    .frame(minHeight: 96)
                    .scrollContentBackground(.hidden)
                    .padding(8)

                Text("\(profile.bio.count)/160")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(
                        profile.bio.count > 145
                            ? currentTheme.accent
                            : .secondary
                    )
                    .padding(9)
            }
            .background(
                GRUColors.card.opacity(0.70),
                in: RoundedRectangle(cornerRadius: 17, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(currentTheme.accent.opacity(0.14), lineWidth: 1)
            }
        }
        .padding(14)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
    }

    var privacyNote: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(currentTheme.accent)
                .frame(width: 34, height: 34)
                .background(currentTheme.accent.opacity(0.09), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(GRUL10n.text("Медиа остаётся в переписках"))
                    .font(.subheadline.weight(.semibold))

                Text(
                    GRUL10n.text(
                        "Голосовые и видео-сообщения не создают отдельную медиатеку gru. на устройстве."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(
            GRUColors.card.opacity(0.56),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    func sectionTitle(
        icon: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 9) {
            GRUNeonIcon(systemName: icon, size: 32, iconSize: 12)

            VStack(alignment: .leading, spacing: 1) {
                Text(GRUL10n.text(title))
                    .font(.headline)
                Text(GRUL10n.text(subtitle))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    func profileRow(
        icon: String,
        title: String,
        value: String
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(currentTheme.accent)
                .frame(width: 30, height: 30)
                .background(currentTheme.accent.opacity(0.08), in: Circle())

            Text(GRUL10n.text(title))
                .font(.subheadline.weight(.semibold))

            Spacer()

            Text(GRUL10n.text(value))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 11)
        .frame(height: 48)
        .background(
            GRUColors.card.opacity(0.62),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    func fieldRow<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(currentTheme.accent)
                .frame(width: 30, height: 30)
                .background(currentTheme.accent.opacity(0.08), in: Circle())

            Text(GRUL10n.text(title))
                .font(.subheadline.weight(.semibold))

            Spacer()

            content()
                .foregroundStyle(.secondary)
                .frame(maxWidth: 170)
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 48)
        .background(
            GRUColors.card.opacity(0.62),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
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
                    .fill(
                        LinearGradient(
                            colors: [
                                currentTheme.accent.opacity(0.44),
                                currentTheme.card,
                                currentTheme.secondaryAccent.opacity(0.36)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "person.fill")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
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
