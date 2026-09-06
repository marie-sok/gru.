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
                    VStack(spacing: 18) {
                        identityHero
                        editIdentityCard
                        bioSection
                        privacyNote
                        Spacer(minLength: 34)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
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
    var identityHero: some View {
        ZStack(alignment: .bottom) {
            GRUSignatureWallpaper(
                theme: currentTheme,
                intensity: 0.92,
                animated: true
            )

            LinearGradient(
                colors: [
                    .clear,
                    Color.black.opacity(0.24),
                    Color.black.opacity(0.82)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 15) {
                HStack {
                    themeBadge
                    Spacer()
                    localProfileBadge
                }

                Spacer(minLength: 4)

                HStack(alignment: .center, spacing: 16) {
                    Button {
                        showAvatarSource = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            avatarImage
                                .frame(width: 108, height: 108)
                                .clipShape(Circle())
                                .overlay {
                                    Circle()
                                        .stroke(GRUColors.neonGradient, lineWidth: 2.6)
                                }
                                .shadow(color: currentTheme.accent.opacity(0.55), radius: 20)
                                .shadow(color: currentTheme.secondaryAccent.opacity(0.24), radius: 30)

                            Circle()
                                .fill(service.currentUser.isOnline ? currentTheme.accent : Color.secondary)
                                .frame(width: 18, height: 18)
                                .overlay {
                                    Circle().stroke(Color.black.opacity(0.72), lineWidth: 3)
                                }
                                .shadow(
                                    color: service.currentUser.isOnline ? currentTheme.accent.opacity(0.85) : .clear,
                                    radius: 8
                                )

                            GRUNeonIcon(
                                systemName: "camera.fill",
                                size: 37,
                                iconSize: 14
                            )
                            .offset(x: 5, y: 4)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Изменить аватар")

                    VStack(alignment: .leading, spacing: 7) {
                        Text(displayName)
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text("@\(profile.username)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(currentTheme.accent)

                        HStack(spacing: 7) {
                            Circle()
                                .fill(service.currentUser.isOnline ? currentTheme.accent : Color.secondary.opacity(0.65))
                                .frame(width: 7, height: 7)

                            Text(service.currentUser.isOnline ? "online" : "offline")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }

                    Spacer(minLength: 0)
                }

                heroMetrics
            }
            .padding(16)
        }
        .frame(height: 360)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(currentTheme.accent.opacity(0.34), lineWidth: 1.2)
        }
        .shadow(color: currentTheme.accent.opacity(0.20), radius: 25, y: 12)
    }

    var themeBadge: some View {
        Label(currentTheme.title, systemImage: currentTheme.icon)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(currentTheme.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(currentTheme.accent.opacity(0.32), lineWidth: 1)
            }
    }

    var localProfileBadge: some View {
        Label("MY GRU", systemImage: "person.crop.circle.fill")
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.76))
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.28), in: Capsule())
    }

    var heroMetrics: some View {
        HStack(spacing: 8) {
            metricChip(
                icon: "quote.bubble.fill",
                value: "\(profile.bio.count)/160",
                label: "bio"
            )

            metricChip(
                icon: service.currentUser.isOnline ? "bolt.fill" : "moon.fill",
                value: service.currentUser.isOnline ? "LIVE" : "AWAY",
                label: "status"
            )

            metricChip(
                icon: currentTheme.icon,
                value: currentTheme.title,
                label: "theme"
            )
        }
    }

    func metricChip(icon: String, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(currentTheme.accent)

                Text(value)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }

            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.46))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
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
                                currentTheme.accent.opacity(0.52),
                                currentTheme.card,
                                currentTheme.secondaryAccent.opacity(0.48)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "person.fill")
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(.white.opacity(0.94))
            }
        }
    }

    var editIdentityCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            sectionTitle(
                icon: "slider.horizontal.3",
                title: "Identity",
                subtitle: "локальные данные профиля на этом устройстве"
            )

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
        .padding(15)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(currentTheme.accent.opacity(0.16), lineWidth: 1)
        }
    }

    var bioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                icon: "quote.bubble.fill",
                title: "Био",
                subtitle: "коротко о себе"
            )

            ZStack(alignment: .bottomTrailing) {
                TextEditor(text: $profile.bio)
                    .frame(minHeight: 112)
                    .scrollContentBackground(.hidden)
                    .padding(10)

                Text("\(profile.bio.count)/160")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(profile.bio.count > 145 ? currentTheme.accent : .secondary)
                    .padding(10)
            }
            .background(GRUColors.card.opacity(0.76))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(currentTheme.accent.opacity(0.20), lineWidth: 1)
            }
        }
        .padding(15)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            GRUNeonIcon(
                systemName: "lock.shield.fill",
                size: 38,
                iconSize: 15
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Медиа остаётся в переписках")
                    .font(.subheadline.weight(.bold))

                Text("Голосовые и видео-сообщения не создают отдельную медиатеку gru. на устройстве.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(GRUColors.card.opacity(0.66))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(currentTheme.accent.opacity(0.12), lineWidth: 1)
        }
    }

    func sectionTitle(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            GRUNeonIcon(systemName: icon, size: 34, iconSize: 13)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    func profileRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            GRUNeonIcon(systemName: icon, size: 36, iconSize: 14)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(service.currentUser.isOnline ? currentTheme.accent : .secondary)
        }
        .padding(12)
        .background(GRUColors.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    func fieldRow<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            GRUNeonIcon(systemName: icon, size: 36, iconSize: 14)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            content()
                .foregroundStyle(.secondary)
                .frame(maxWidth: 170)
        }
        .padding(12)
        .background(GRUColors.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(currentTheme.accent.opacity(0.08), lineWidth: 1)
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
