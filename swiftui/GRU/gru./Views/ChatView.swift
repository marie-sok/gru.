import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
struct ChatView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var vm: ChatViewModel
    @State private var socket = WebSocketService.shared

    @State private var showPhotoPicker = false
    @State private var selectedPhoto: PhotosPickerItem?

    @State private var showVideoSourceDialog = false
    @State private var showVideoLibraryPicker = false
    @State private var selectedVideo: PhotosPickerItem?
    @State private var showVideoCamera = false

    @State private var showVideoNoteRecorder = false
    @State private var videoNoteHolding = false
    @State private var videoNoteLocked = false
    @State private var videoNoteCancelSerial = 0
    @State private var showDocumentPicker = false
    @State private var showContactPicker = false
    @State private var showBackgroundPicker = false
    @State private var searching = false
    @State private var showPeerProfile = false
    @State private var isSelectingMessages = false
    @State private var selectedMessageIDs: Set<UUID> = []
    @State private var showBulkDeleteConfirmation = false
    @State private var showDeleteChatConfirmation = false
    @State private var deletingChat = false

    @AppStorage(GRUTheme.selectionKey) private var themeRaw = GRUAppTheme.blackMoonCat.rawValue
    @AppStorage("showStatus") private var showOnlineStatus = true
    @AppStorage("gru.settings.privacy.typing") private var showTypingStatus = true
    @AppStorage("gru.settings.chats.wallpaperBlur") private var wallpaperBlur = false

    @AppStorage private var chatBackgroundRaw: String

    init(chat: Chat) {
        _vm = State(initialValue: ChatViewModel(chat: chat))

        let key = chat.serverID ?? chat.id.uuidString
        _chatBackgroundRaw = AppStorage(
            wrappedValue: ChatBackgroundStyle.obsidian.rawValue,
            "gru.chat.background.\(key)"
        )
    }

    private var backgroundStyle: ChatBackgroundStyle {
        ChatBackgroundStyle(rawValue: chatBackgroundRaw) ?? .obsidian
    }

    private var currentTheme: GRUAppTheme {
        GRUAppTheme(rawValue: themeRaw) ?? .blackMoonCat
    }

    private var peerUser: User? {
        vm.chat.users.first { $0.id != ChatService.shared.currentUser.id }
    }

    var body: some View {
        ZStack {
            Group {
                if let theme = GRUAppTheme(rawValue: chatBackgroundRaw), GRUThemePolicy.allowed.contains(theme) {
                    GRUSignatureWallpaper(theme: theme, intensity: 0.92)
                } else if backgroundStyle == .obsidian {
                    GRUSignatureWallpaper(theme: currentTheme, intensity: 0.92)
                } else {
                    ChatBackgroundView(style: backgroundStyle)
                }
            }
            .blur(radius: wallpaperBlur ? 7 : 0)

            VStack(spacing: 0) {
                header

                if !socket.isConnected {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(socket.isReconnecting ? "Подключаемся…" : "Нет соединения")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("Сообщения можно повторить после восстановления связи")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(GRUColors.card.opacity(0.88))
                }

                if searching {
                    SearchBar(
                        text: $vm.searchText,
                        resultsText: vm.searchCountText,
                        onSearch: { vm.performSearch() },
                        onNext: { vm.nextResult() },
                        onPrevious: { vm.previousResult() },
                        onClose: {
                            withAnimation {
                                searching = false
                                vm.clearSearch()
                            }
                        }
                    )
                }

                Divider().opacity(0.08)

                messages

                if let editing = vm.editingMessage {
                    EditBar(message: editing) {
                        vm.cancelEditing()
                    }
                }

                if let reply = vm.replyMessage {
                    ReplyBar(message: reply) {
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
        .onChange(of: vm.chatWasDeleted) { _, deleted in
            if deleted { dismiss() }
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
            Text("Отправь обычное видео из медиатеки или сними новое.")
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

                await MainActor.run {
                    selectedPhoto = nil
                }
            }
        }
        .onChange(of: selectedVideo) { _, item in
            guard let item else { return }

            Task {
                do {
                    guard let picked = try await item.loadTransferable(type: PickedVideo.self) else {
                        return
                    }

                    await vm.sendVideo(picked.url)
                    try? FileManager.default.removeItem(at: picked.url)
                } catch {
                    print("❌ Video library error:", error)
                }

                await MainActor.run {
                    selectedVideo = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showVideoCamera) {
            VideoCameraPicker(
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
                print("❌ Document picker error:", error)
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
        .sheet(isPresented: $showPeerProfile) {
            if let user = peerUser {
                ChatPeerProfileView(
                    user: user,
                    chat: vm.chat,
                    onSearch: {
                        showPeerProfile = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            searching = true
                        }
                    },
                    onAppearance: {
                        showPeerProfile = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            showBackgroundPicker = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showBackgroundPicker) {
            ChatBackgroundPicker(selectedRawValue: $chatBackgroundRaw)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(
            "Действие не выполнено",
            isPresented: Binding(
                get: { vm.actionError != nil },
                set: { visible in
                    if !visible {
                        vm.clearActionError()
                    }
                }
            )
        ) {
            Button("Понятно", role: .cancel) {
                vm.clearActionError()
            }
        } message: {
            Text(vm.actionError ?? "Неизвестная ошибка")
        }
        .confirmationDialog(
            "Удалить выбранные сообщения?",
            isPresented: $showBulkDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить у себя (\(selectedMessages.count))", role: .destructive) {
                selectedMessages.forEach { vm.deleteLocal($0) }
                finishMessageSelection()
            }

            if canDeleteSelectionForEveryone {
                Button("Удалить у всех (\(selectedMessages.count))", role: .destructive) {
                    selectedMessages.forEach { vm.deleteForEveryone($0) }
                    finishMessageSelection()
                }
            }

            Button("Отмена", role: .cancel) {}
        } message: {
            Text(canDeleteSelectionForEveryone
                 ? "Выбранные сообщения исчезнут без служебных заглушек."
                 : "У всех можно удалить только сообщения, отправленные тобой. Для смешанного выбора доступно удаление у себя.")
        }
        .confirmationDialog(
            "Удалить чат целиком?",
            isPresented: $showDeleteChatConfirmation,
            titleVisibility: .visible
        ) {
            Button("Удалить чат у обоих", role: .destructive) {
                deleteCurrentChat()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("История и вложения этого чата будут удалены с сервера. Действие нельзя отменить.")
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
}

// MARK: - Header

private extension ChatView {
    var header: some View {
        HStack(spacing: 12) {
            if isSelectingMessages {
                GRUNeonIconButton(
                    systemName: "xmark",
                    accessibilityLabel: "Отменить выбор",
                    size: 38,
                    iconSize: 14
                ) {
                    finishMessageSelection()
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
                    if !selectedMessageIDs.isEmpty {
                        showBulkDeleteConfirmation = true
                    }
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

                Button {
                    if peerUser != nil {
                        showPeerProfile = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        if let peerUser {
                            AvatarView(user: peerUser, size: 40)
                        } else {
                            Circle()
                                .fill(GRUColors.card.opacity(0.90))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(GRUColors.accent)
                                }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(chatName)
                                .font(.headline)

                            Text(showTypingStatus && vm.isOtherUserTyping ? "печатает…" : chatStatus)
                                .font(.caption)
                                .foregroundStyle(showTypingStatus && vm.isOtherUserTyping ? GRUColors.accent : .secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Открыть профиль пользователя")

                Spacer()

                GRUNeonIconButton(
                    systemName: "magnifyingglass",
                    accessibilityLabel: "Поиск",
                    size: 38,
                    iconSize: 15,
                    isActive: searching
                ) {
                    withAnimation {
                        searching.toggle()
                        if !searching { vm.clearSearch() }
                    }
                }

                Menu {
                    Button {
                        beginMessageSelection()
                    } label: {
                        Label("Выбрать сообщения", systemImage: "checkmark.circle")
                    }

                    Button {
                        showBackgroundPicker = true
                    } label: {
                        Label("Фон чата", systemImage: "paintpalette.fill")
                    }

                    Divider()

                    Button(role: .destructive) {
                        showDeleteChatConfirmation = true
                    } label: {
                        Label("Удалить чат", systemImage: "trash")
                    }
                } label: {
                    GRUNeonIcon(
                        systemName: "ellipsis",
                        size: 38,
                        iconSize: 15
                    )
                }
                .buttonStyle(.plain)
                .disabled(deletingChat)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    var chatName: String {
        vm.chat.users.first {
            $0.id != ChatService.shared.currentUser.id
        }?.displayName ?? "Chat"
    }

    var chatStatus: String {
        guard let user = vm.chat.users.first(where: {
            $0.id != ChatService.shared.currentUser.id
        }) else {
            return ""
        }

        guard showOnlineStatus else { return "" }
        return user.isOnline ? "Online" : "Offline"
    }
}

private extension ChatView {
    var selectedMessages: [Message] {
        vm.chat.messages.filter { selectedMessageIDs.contains($0.id) }
    }

    var canDeleteSelectionForEveryone: Bool {
        !selectedMessages.isEmpty &&
        selectedMessages.allSatisfy {
            $0.senderID == ChatService.shared.currentUser.id &&
            $0.serverID?.isEmpty == false
        }
    }

    func beginMessageSelection() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isSelectingMessages = true
        }
    }

    func toggleMessageSelection(_ message: Message) {
        isSelectingMessages = true
        if selectedMessageIDs.contains(message.id) {
            selectedMessageIDs.remove(message.id)
        } else {
            selectedMessageIDs.insert(message.id)
        }
    }

    func finishMessageSelection() {
        selectedMessageIDs.removeAll()
        withAnimation(.easeInOut(duration: 0.16)) {
            isSelectingMessages = false
        }
    }

    func deleteCurrentChat() {
        guard !deletingChat,
              let serverID = vm.chat.serverID,
              !serverID.isEmpty,
              let token = TokenStorage.shared.token,
              !token.isEmpty else {
            vm.actionError = "Не удалось удалить чат: серверный идентификатор или сессия недоступны."
            return
        }

        deletingChat = true
        Task {
            do {
                try await ChatAPIService.shared.deleteChat(chatID: serverID, token: token)
                ChatService.shared.deleteChat(vm.chat.id)
                dismiss()
            } catch {
                deletingChat = false
                vm.actionError = "Не удалось удалить чат: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Messages

private extension ChatView {
    var messages: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    ForEach(vm.chat.messages) { message in
                        MessageBubble(
                            message: message,
                            isCurrentUser: message.senderID == ChatService.shared.currentUser.id,
                            onReply: { message in
                                vm.startReply(to: message)
                            },
                            onEdit: { message in
                                vm.startEditing(message)
                            },
                            onDeleteLocal: { message in
                                vm.deleteLocal(message)
                            },
                            onDeleteForEveryone: { message in
                                vm.deleteForEveryone(message)
                            },
                            onRetry: { message in
                                vm.retryMessage(message)
                            },
                            onReaction: { reaction, message in
                                if message.reaction == reaction {
                                    vm.removeReaction(from: message)
                                } else {
                                    vm.addReaction(reaction, to: message)
                                }
                            },
                            isSelectionMode: isSelectingMessages,
                            isSelected: selectedMessageIDs.contains(message.id),
                            onSelect: { message in
                                toggleMessageSelection(message)
                            }
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

    func scrollToLast(proxy: ScrollViewProxy, animated: Bool) {
        guard let last = vm.chat.messages.last else { return }

        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

private struct ChatPeerProfileView: View {
    @Environment(\.dismiss) private var dismiss

    let user: User
    let chat: Chat
    let onSearch: () -> Void
    let onAppearance: () -> Void

    @State private var showMedia = false
    @State private var showReportDialog = false
    @State private var showBlockConfirmation = false
    @State private var isBlocked = false
    @State private var isSafetyLoading = false
    @State private var safetyMessage: String?
    @State private var safetyError: String?

    private var mediaMessages: [Message] {
        chat.messages.filter { $0.attachment != nil }
    }

    private var mediaCount: Int { mediaMessages.count }

    private var serverUserID: String? { user.serverID }

    var body: some View {
        NavigationStack {
            ZStack {
                GRUAppBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        profileHero

                        HStack(spacing: 10) {
                            profileMetric("\(chat.messages.count)", "сообщений", "bubble.left.fill")
                            profileMetric("\(mediaCount)", "медиа", "photo.stack.fill")
                            profileMetric(chat.isMuted ? "off" : "on", "звук", chat.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        }

                        VStack(spacing: 10) {
                            Button(action: onSearch) {
                                profileAction("Поиск в переписке", "magnifyingglass")
                            }

                            Button {
                                showMedia = true
                            } label: {
                                profileAction("Общие медиа", "photo.stack.fill")
                            }
                            .disabled(mediaMessages.isEmpty)

                            Button(action: onAppearance) {
                                profileAction("Оформление переписки", "paintpalette.fill")
                            }
                        }

                        safetyCard

                        VStack(alignment: .leading, spacing: 8) {
                            Label("SIGNAL CARD", systemImage: "dot.radiowaves.left.and.right")
                                .font(.caption.weight(.black))
                                .foregroundStyle(GRUColors.accent)
                            Text("Профиль связан с реальным участником переписки. Поиск, медиа, оформление, жалоба и блокировка находятся в одном месте.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(GRUColors.card.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(GRUColors.accent.opacity(0.18), lineWidth: 1) }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .task { await loadSafetyState() }
        .sheet(isPresented: $showMedia) {
            SharedMediaSummaryView(messages: mediaMessages)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Пожаловаться",
            isPresented: $showReportDialog,
            titleVisibility: .visible
        ) {
            Button("Спам") { submitReport(reason: "spam") }
            Button("Оскорбления или травля") { submitReport(reason: "harassment") }
            Button("Опасный или незаконный контент") { submitReport(reason: "illegal") }
            Button("Другое") { submitReport(reason: "other") }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Жалоба сохраняется на backend GRU для последующей модерации.")
        }
        .confirmationDialog(
            "Заблокировать пользователя?",
            isPresented: $showBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Заблокировать", role: .destructive) {
                updateBlocked(true)
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("После блокировки новые сообщения между вами будут отклоняться backend.")
        }
        .alert(
            "GRU Safety",
            isPresented: Binding(
                get: { safetyMessage != nil || safetyError != nil },
                set: { visible in
                    if !visible {
                        safetyMessage = nil
                        safetyError = nil
                    }
                }
            )
        ) {
            Button("Понятно", role: .cancel) {
                safetyMessage = nil
                safetyError = nil
            }
        } message: {
            Text(safetyError ?? safetyMessage ?? "")
        }
    }

    private var profileHero: some View {
        VStack(spacing: 10) {
            AvatarView(user: user, size: 104)
                .overlay {
                    Circle().stroke(GRUColors.neonGradient, lineWidth: 2)
                }
                .shadow(color: GRUColors.accent.opacity(0.28), radius: 22)

            Text(user.displayName.isEmpty ? user.username : user.displayName)
                .font(.system(size: 28, weight: .black, design: .rounded))

            if !user.username.isEmpty {
                Text("@\(user.username)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GRUColors.accent)
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(user.isOnline ? GRUColors.accent : Color.secondary.opacity(0.6))
                    .frame(width: 7, height: 7)
                Text(user.isOnline ? "Online" : "Offline")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(user.isOnline ? GRUColors.accent : .secondary)
            }
        }
    }

    private var safetyCard: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Безопасность", systemImage: "shield.lefthalf.filled")
                    .font(.subheadline.weight(.black))
                Spacer()
                if isSafetyLoading {
                    ProgressView().controlSize(.small)
                } else if isBlocked {
                    Text("BLOCKED")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(.red)
                }
            }

            Button {
                if isBlocked {
                    updateBlocked(false)
                } else {
                    showBlockConfirmation = true
                }
            } label: {
                safetyAction(
                    isBlocked ? "Разблокировать" : "Заблокировать",
                    isBlocked ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.xmark",
                    destructive: !isBlocked
                )
            }
            .disabled(serverUserID == nil || isSafetyLoading)

            Button {
                showReportDialog = true
            } label: {
                safetyAction("Пожаловаться", "exclamationmark.bubble.fill", destructive: true)
            }
            .disabled(serverUserID == nil || isSafetyLoading)
        }
        .padding(16)
        .background(GRUColors.card.opacity(0.84), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.red.opacity(0.12), lineWidth: 1) }
    }

    private func profileMetric(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).foregroundStyle(GRUColors.accent)
            Text(value).font(.headline.weight(.black))
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(GRUColors.card.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func profileAction(_ title: String, _ icon: String) -> some View {
        HStack {
            GRUNeonIcon(systemName: icon, size: 36, iconSize: 14)
            Text(title).font(.body.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(GRUColors.card.opacity(0.82), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func safetyAction(_ title: String, _ icon: String, destructive: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 32, height: 32)
                .background((destructive ? Color.red : GRUColors.accent).opacity(0.10), in: Circle())
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.secondary)
        }
        .foregroundStyle(destructive ? Color.red : GRUColors.text)
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func loadSafetyState() async {
        guard let userID = serverUserID,
              let token = TokenStorage.shared.token else { return }
        isSafetyLoading = true
        defer { isSafetyLoading = false }
        do {
            let state = try await UserAPIService.shared.safetyState(userID: userID, token: token)
            isBlocked = state.blocked
        } catch {
            safetyError = error.localizedDescription
        }
    }

    private func updateBlocked(_ blocked: Bool) {
        guard let userID = serverUserID,
              let token = TokenStorage.shared.token else { return }
        isSafetyLoading = true
        Task {
            defer { isSafetyLoading = false }
            do {
                let state = try await UserAPIService.shared.setBlocked(blocked, userID: userID, token: token)
                isBlocked = state.blocked
                safetyMessage = state.blocked
                    ? "Пользователь заблокирован. Backend не позволит отправлять новые сообщения между вами."
                    : "Пользователь разблокирован."
            } catch {
                safetyError = error.localizedDescription
            }
        }
    }

    private func submitReport(reason: String) {
        guard let userID = serverUserID,
              let token = TokenStorage.shared.token else { return }
        isSafetyLoading = true
        Task {
            defer { isSafetyLoading = false }
            do {
                try await UserAPIService.shared.reportUser(
                    userID: userID,
                    chatID: chat.serverID,
                    reason: reason,
                    details: nil,
                    token: token
                )
                safetyMessage = "Жалоба отправлена."
            } catch {
                safetyError = error.localizedDescription
            }
        }
    }
}

private struct SharedMediaSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let messages: [Message]

    var body: some View {
        NavigationStack {
            ZStack {
                GRUAppBackdrop()

                if messages.isEmpty {
                    ContentUnavailableView(
                        "Медиа пока нет",
                        systemImage: "photo.stack",
                        description: Text("Фото, видео, голосовые и файлы из переписки появятся здесь.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(messages) { message in
                                if let attachment = message.attachment {
                                    HStack(spacing: 12) {
                                        GRUNeonIcon(
                                            systemName: mediaIcon(attachment.type),
                                            size: 42,
                                            iconSize: 16
                                        )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(mediaTitle(attachment.type))
                                                .font(.subheadline.weight(.bold))
                                            Text(attachment.fileName.isEmpty ? "Вложение" : attachment.fileName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Text(message.sentAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .background(GRUColors.card.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Общие медиа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }

    private func mediaIcon(_ type: AttachmentType) -> String {
        switch type {
        case .photo: return "photo.fill"
        case .video: return "video.fill"
        case .videoNote: return "video.circle.fill"
        case .document: return "doc.fill"
        case .audio: return "waveform"
        }
    }

    private func mediaTitle(_ type: AttachmentType) -> String {
        switch type {
        case .photo: return "Фото"
        case .video, .videoNote: return "Видео"
        case .document: return "Документ"
        case .audio: return "Голосовое"
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(
            chat: Chat(
                users: [
                    ChatService.shared.currentUser,
                    User(username: "alex", displayName: "Alex", isOnline: true)
                ],
                messages: [
                    Message(senderID: UUID(), text: "Привет 👋"),
                    Message(
                        senderID: ChatService.shared.currentUser.id,
                        text: "GRU Messenger"
                    )
                ]
            )
        )
    }
}
