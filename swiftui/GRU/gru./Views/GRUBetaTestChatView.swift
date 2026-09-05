import CoreTransferable
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
struct GRUBetaTestChatView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var vm: ChatViewModel

    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?

    @State private var showVideoSourceDialog = false
    @State private var showVideoLibraryPicker = false
    @State private var selectedVideo: PhotosPickerItem?
    @State private var showVideoCamera = false

    @State private var showDocumentPicker = false
    @State private var showContactPicker = false

    @State private var showVideoNoteRecorder = false
    @State private var videoNoteHolding = false
    @State private var videoNoteLocked = false
    @State private var videoNoteCancelSerial = 0

    @State private var isSelectingMessages = false
    @State private var selectedMessageIDs: Set<UUID> = []

    @AppStorage(GRUTheme.selectionKey)
    private var themeRaw = GRUAppTheme.blackMoonCat.rawValue

    init() {
        _vm = State(initialValue: ChatViewModel(chat: Self.makeSeedChat()))
    }

    private var currentTheme: GRUAppTheme {
        let candidate = GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
        return GRUThemePolicy.allowed.contains(candidate) ? candidate : .blackMoonCat
    }

    var body: some View {
        ZStack {
            GRUSignatureWallpaper(
                theme: currentTheme,
                intensity: 0.96,
                animated: true
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Divider().opacity(0.08)

                messages

                if let editing = vm.editingMessage {
                    localActionBar(
                        title: "Редактирование",
                        subtitle: editing.text,
                        icon: "pencil"
                    ) {
                        vm.cancelEditing()
                    }
                }

                if let reply = vm.replyMessage {
                    localActionBar(
                        title: "Ответ",
                        subtitle: reply.text.isEmpty ? "Вложение" : reply.text,
                        icon: "arrowshape.turn.up.left"
                    ) {
                        vm.cancelReply()
                    }
                }

                ChatInputBar(
                    text: $vm.messageText,
                    sendTrigger: $vm.sendTrigger,
                    onSend: {
                        vm.sendMessage()
                    },
                    onAttachment: { action in
                        switch action {
                        case .photo:
                            showPhotoPicker = true
                        case .video:
                            showVideoSourceDialog = true
                        case .document:
                            showDocumentPicker = true
                        case .contact:
                            showContactPicker = true
                        }
                    },
                    onAudioRecorded: { recording in
                        Task {
                            await vm.sendAudio(
                                url: recording.url,
                                duration: recording.duration,
                                waveform: recording.waveform
                            )
                            try? FileManager.default.removeItem(at: recording.url)
                        }
                    },
                    onVideoNoteStarted: {
                        videoNoteHolding = true
                        videoNoteLocked = false
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                            showVideoNoteRecorder = true
                        }
                    },
                    onVideoNoteReleased: {
                        videoNoteHolding = false
                    },
                    onVideoNoteCancelled: {
                        videoNoteHolding = false
                        videoNoteLocked = false
                        videoNoteCancelSerial &+= 1
                        withAnimation(.easeOut(duration: 0.16)) {
                            showVideoNoteRecorder = false
                        }
                    },
                    onVideoNoteLocked: {
                        videoNoteLocked = true
                        videoNoteHolding = false
                    }
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await vm.loadMessages()
        }
        .onDisappear {
            vm.stopRealtime()
        }
        .confirmationDialog(
            "Видео",
            isPresented: $showVideoSourceDialog,
            titleVisibility: .visible
        ) {
            Button("Выбрать из медиатеки") {
                showVideoLibraryPicker = true
            }

            Button("Снять камерой") {
                showVideoCamera = true
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Test lab использует тот же сценарий видео, что и обычный чат.")
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhoto,
            matching: .images
        )
        .photosPicker(
            isPresented: $showVideoLibraryPicker,
            selection: $selectedVideo,
            matching: .videos
        )
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    vm.sendImage(image)
                }
                selectedPhoto = nil
            }
        }
        .onChange(of: selectedVideo) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let picked = try await item.loadTransferable(type: GRUBetaPickedVideo.self) else {
                        selectedVideo = nil
                        return
                    }
                    await vm.sendVideo(picked.url)
                    try? FileManager.default.removeItem(at: picked.url)
                } catch {
                    print("❌ Test lab video library error:", error)
                }
                selectedVideo = nil
            }
        }
        .fullScreenCover(isPresented: $showVideoCamera) {
            GRUBetaVideoCameraPicker(
                onPicked: { url in
                    showVideoCamera = false
                    Task {
                        await vm.sendVideo(url)
                        try? FileManager.default.removeItem(at: url)
                    }
                },
                onCancel: {
                    showVideoCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task {
                    await vm.sendDocument(url)
                }
            case .failure(let error):
                print("❌ Test lab document picker error:", error)
            }
        }
        .sheet(isPresented: $showContactPicker) {
            ContactSharePickerView { contact in
                guard let phone = contact.primaryPhone else { return }
                vm.sendContactCard(
                    name: contact.displayName,
                    phone: phone
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .bottomTrailing) {
            if showVideoNoteRecorder {
                VideoNoteRecorderView(
                    isHolding: videoNoteHolding,
                    isLocked: videoNoteLocked,
                    cancelSerial: videoNoteCancelSerial,
                    onFinished: { url in
                        videoNoteHolding = false
                        videoNoteLocked = false
                        withAnimation(.easeOut(duration: 0.20)) {
                            showVideoNoteRecorder = false
                        }
                        Task {
                            await vm.sendVideoNote(url)
                            try? FileManager.default.removeItem(at: url)
                        }
                    },
                    onCancel: {
                        videoNoteHolding = false
                        videoNoteLocked = false
                        withAnimation(.easeOut(duration: 0.20)) {
                            showVideoNoteRecorder = false
                        }
                    }
                )
                .padding(.trailing, 14)
                .padding(.bottom, 76)
                .transition(
                    .scale(scale: 0.86, anchor: .bottomTrailing)
                        .combined(with: .opacity)
                )
                .zIndex(20)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if isSelectingMessages {
                GRUNeonIconButton(
                    systemName: "xmark",
                    accessibilityLabel: "Отменить выбор",
                    size: 38,
                    iconSize: 14
                ) {
                    finishSelection()
                }

                Text("Выбрано: \(selectedMessageIDs.count)")
                    .font(.headline)

                Spacer()

                GRUNeonIconButton(
                    systemName: "trash.fill",
                    accessibilityLabel: "Удалить выбранные",
                    size: 38,
                    iconSize: 14,
                    isActive: !selectedMessageIDs.isEmpty
                ) {
                    deleteSelection()
                }
            } else {
                GRUNeonIconButton(
                    systemName: "chevron.left",
                    accessibilityLabel: "Назад",
                    size: 38,
                    iconSize: 15
                ) {
                    dismiss()
                }

                ZStack {
                    Circle()
                        .fill(currentTheme.accent.opacity(0.15))
                    Image(systemName: "testtube.2")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(currentTheme.accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("gru. test lab")
                            .font(.headline)
                        Text("RC")
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(currentTheme.accent)
                    }

                    Text("полный локальный полигон чата")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    cycleTheme()
                } label: {
                    GRUNeonIcon(
                        systemName: "paintpalette.fill",
                        size: 38,
                        iconSize: 15,
                        isActive: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Следующая тема")

                Menu {
                    Button {
                        isSelectingMessages = true
                    } label: {
                        Label("Выбрать сообщения", systemImage: "checkmark.circle")
                    }

                    Button {
                        resetLab()
                    } label: {
                        Label("Сбросить test lab", systemImage: "arrow.counterclockwise")
                    }
                } label: {
                    GRUNeonIcon(
                        systemName: "ellipsis",
                        size: 38,
                        iconSize: 15
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
    }

    private var messages: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    capabilityCard

                    ForEach(vm.chat.messages) { message in
                        MessageBubble(
                            message: message,
                            isCurrentUser: message.senderID == ChatService.shared.currentUser.id,
                            onReply: { vm.startReply(to: $0) },
                            onEdit: { vm.startEditing($0) },
                            onDeleteLocal: { vm.deleteLocal($0) },
                            onDeleteForEveryone: { vm.deleteForEveryone($0) },
                            onRetry: { vm.retryMessage($0) },
                            onReaction: { reaction, message in
                                toggleLocalReaction(reaction, on: message)
                            },
                            isSelectionMode: isSelectingMessages,
                            isSelected: selectedMessageIDs.contains(message.id),
                            onSelect: { toggleSelection($0) }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollToLast(proxy: proxy, animated: false)
            }
            .onChange(of: vm.chat.messages.count) { _, _ in
                scrollToLast(proxy: proxy, animated: true)
            }
        }
    }

    private var capabilityCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("FULL CHAT TEST", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.black))
                .foregroundStyle(currentTheme.accent)

            Text("Проверяй здесь обычный текст, reply, edit, delete, reactions, multi-select, фото, видео, документы, контакты, голосовые и кото-кружки. Ничего из этого test lab не отправляет в реальные чаты.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            GRUColors.card.opacity(0.78),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(currentTheme.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private func localActionBar(
        title: String,
        subtitle: String,
        icon: String,
        onClose: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(currentTheme.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(currentTheme.accent)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(GRUColors.card.opacity(0.92))
    }

    private func toggleLocalReaction(_ reaction: ReactionType, on message: Message) {
        guard let index = vm.chat.messages.firstIndex(where: { $0.id == message.id }) else {
            return
        }

        vm.chat.messages[index].reaction =
            vm.chat.messages[index].reaction == reaction ? nil : reaction

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func toggleSelection(_ message: Message) {
        isSelectingMessages = true
        if selectedMessageIDs.contains(message.id) {
            selectedMessageIDs.remove(message.id)
        } else {
            selectedMessageIDs.insert(message.id)
        }
    }

    private func finishSelection() {
        selectedMessageIDs.removeAll()
        isSelectingMessages = false
    }

    private func deleteSelection() {
        let messages = vm.chat.messages.filter { selectedMessageIDs.contains($0.id) }
        messages.forEach { vm.deleteLocal($0) }
        finishSelection()
    }

    private func resetLab() {
        vm = ChatViewModel(chat: Self.makeSeedChat())
        selectedMessageIDs.removeAll()
        isSelectingMessages = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func cycleTheme() {
        let themes = GRUThemePolicy.allowed
        guard !themes.isEmpty else { return }
        let index = themes.firstIndex(of: currentTheme) ?? 0
        let next = themes[(index + 1) % themes.count]

        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            themeRaw = next.rawValue
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func scrollToLast(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = vm.chat.messages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }

    private static func makeSeedChat() -> Chat {
        let me = ChatService.shared.currentUser
        let lab = User(
            username: "gru_test_lab",
            displayName: "gru. test lab",
            isOnline: true
        )

        let incoming = Message(
            senderID: lab.id,
            text: "Я локальный собеседник test lab. Свайпни это сообщение влево для reply или зажми для реакций и действий.",
            sentAt: Date().addingTimeInterval(-90),
            status: .read
        )

        let own = Message(
            senderID: me.id,
            text: "Это моё тестовое сообщение — его можно редактировать, копировать, выбрать и удалить.",
            sentAt: Date().addingTimeInterval(-45),
            status: .read
        )

        return Chat(
            users: [me, lab],
            messages: [incoming, own],
            title: "gru. test lab",
            unreadCount: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

private struct GRUBetaPickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let source = received.file
            let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("gru-beta-video-\(UUID().uuidString).\(ext)")

            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.copyItem(at: source, to: destination)
            return GRUBetaPickedVideo(url: destination)
        }
    }
}

private struct GRUBetaVideoCameraPicker: UIViewControllerRepresentable {
    let onPicked: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.videoQuality = .typeMedium
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onPicked: (URL) -> Void
        let onCancel: () -> Void

        init(onPicked: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPicked = onPicked
            self.onCancel = onCancel
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let source = info[.mediaURL] as? URL else {
                onCancel()
                return
            }

            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("gru-beta-camera-\(UUID().uuidString).mov")

            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: source, to: destination)
                onPicked(destination)
            } catch {
                print("❌ Test lab camera copy error:", error)
                onCancel()
            }
        }
    }
}
