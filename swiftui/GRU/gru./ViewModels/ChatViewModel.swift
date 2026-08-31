import AVFoundation
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ChatViewModel {
  // **MARK: - Chat**
  var chat: Chat
  private let service = ChatService.shared
  // **MARK: - Input**
  var messageText = "" {
    didSet {
      persistDraft()
      handleTypingInputChange()
    }
  }
  var sendTrigger = false
  // **MARK: - Typing**
  var isOtherUserTyping = false
  private var isTypingSent = false
  private var typingStopTask: Task<Void, Never>?
  private var otherTypingTimeoutTask: Task<Void, Never>?
  // **MARK: - Reply**
  var replyMessage: Message?
  // **MARK: - Search**
  var searchText = ""
  var searchResults: [Message] = []
  var selectedSearchIndex = 0
  // **MARK: - Loading**
  var isLoadingMessages = false
  var loadingError: String?
  var actionError: String?
  var chatWasDeleted = false
  private var hasLoadedMessages = false
  // **MARK: - Realtime Message**
  private var realtimeListenerID: UUID?
  private var realtimeChatID: String?
  // **MARK: - Realtime Typing**
  private var typingListenerID: UUID?
  private var typingChatID: String?
  // **MARK: - Init**
  init(chat: Chat) {
    var visibleChat = chat
    visibleChat.messages.removeAll { message in
      guard let serverID = message.serverID else { return false }
      return LocalMessageDeletionStore.shared.isHidden(serverID)
    }
    self.chat = visibleChat
    self.messageText = visibleChat.draft
  }
  private func persistDraft() {
    let value = messageText
    guard chat.draft != value else { return }
    chat.draft = value
    service.update(chat)
  }

  // **MARK: - Load Messages**
  func loadMessages() async {
    startRealtimeIfNeeded()
    startTypingRealtimeIfNeeded()
    guard !hasLoadedMessages else {
      return
    }
    guard
      let serverChatID =
        chat.serverID
    else {
      hasLoadedMessages = true
      return
    }
    guard
      let token =
        TokenStorage.shared.token
    else {
      loadingError =
        "Нет токена авторизации"
      return
    }
    isLoadingMessages = true
    loadingError = nil
    defer {
      isLoadingMessages = false
    }
    do {
      let serverMessages =
        try await MessageAPIService.shared
        .getMessages(
          chatID: serverChatID,
          token: token
        )
      let localMessages =
        makeLocalMessages(
          from: serverMessages
        )
      mergeLoadedMessages(
        localMessages
      )
      if let lastMessage =
        chat.messages.last
      {
        chat.updatedAt =
          lastMessage.sentAt
      }
      service.update(
        chat
      )
      hasLoadedMessages = true
      refreshSearch()
      print(
        "✅ Chat messages loaded:",
        chat.messages.count
      )
    } catch {
      loadingError =
        error.localizedDescription
      print(
        "❌ Load messages error:",
        error
      )
    }
  }
  // **MARK: - Merge Loaded Messages**
  private func mergeLoadedMessages(
    _ loadedMessages: [Message]
  ) {
    var merged =
      loadedMessages
    let loadedServerIDs =
      Set(
        loadedMessages.compactMap {
          $0.serverID
        }
      )
    for existingMessage
      in chat.messages
    {
      if let serverID = existingMessage.serverID {
        if LocalMessageDeletionStore.shared.isHidden(serverID) {
          continue
        }

        if !loadedServerIDs.contains(serverID) {
          merged.append(existingMessage)
        }
      } else {
        merged.append(existingMessage)
      }
    }
    chat.messages =
      removeDuplicates(
        from: merged
      )
      .sorted {
        $0.sentAt < $1.sentAt
      }
  }
  // **MARK: - Remove Duplicates**
  private func removeDuplicates(
    from messages: [Message]
  ) -> [Message] {
    var result: [Message] = []
    var serverIDs: Set<String> = []
    var localIDs: Set<UUID> = []
    for message in messages {
      if let serverID =
        message.serverID
      {
        guard
          !serverIDs.contains(
            serverID
          )
        else {
          continue
        }
        serverIDs.insert(
          serverID
        )
      }
      guard
        !localIDs.contains(
          message.id
        )
      else {
        continue
      }
      localIDs.insert(
        message.id
      )
      result.append(
        message
      )
    }
    return result
  }
  // **MARK: - Message Realtime Start**
  private func startRealtimeIfNeeded() {
    guard
      realtimeListenerID == nil
    else {
      return
    }
    guard
      let serverChatID =
        chat.serverID
    else {
      return
    }
    realtimeChatID =
      serverChatID
    realtimeListenerID =
      WebSocketService.shared
      .addListener(
        chatID: serverChatID
      ) {
        [weak self]
        serverMessage in
        guard let self else {
          return
        }
        self.handleRealtimeMessage(
          serverMessage
        )
      }
    print("")
    print(
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    )
    print(
      "📡 Chat realtime listener ready"
    )
    print(
      "💬 chatId:",
      serverChatID
    )
    print(
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    )
  }
  // **MARK: - Typing Realtime Start**
  private func startTypingRealtimeIfNeeded() {
    guard
      typingListenerID == nil
    else {
      return
    }
    guard
      let serverChatID =
        chat.serverID
    else {
      return
    }
    typingChatID =
      serverChatID
    typingListenerID =
      WebSocketService.shared
      .addTypingListener(
        chatID: serverChatID
      ) {
        [weak self]
        event in
        guard let self else {
          return
        }
        self.handleTypingEvent(
          event
        )
      }
    print("")
    print(
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    )
    print(
      "⌨️ Typing listener ready"
    )
    print(
      "💬 chatId:",
      serverChatID
    )
    print(
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    )
  }
  // **MARK: - Stop Realtime**
  func stopRealtime() {
    stopOwnTyping()
    typingStopTask?
      .cancel()
    typingStopTask =
      nil
    otherTypingTimeoutTask?
      .cancel()
    otherTypingTimeoutTask =
      nil
    isOtherUserTyping =
      false
    if let chatID =
      realtimeChatID,
      let listenerID =
        realtimeListenerID
    {
      WebSocketService.shared
        .removeListener(
          chatID: chatID,
          listenerID: listenerID
        )
      print(
        "📴 Chat realtime listener stopped:",
        chatID
      )
    }
    realtimeListenerID =
      nil
    realtimeChatID =
      nil
    if let chatID =
      typingChatID,
      let listenerID =
        typingListenerID
    {
      WebSocketService.shared
        .removeTypingListener(
          chatID: chatID,
          listenerID: listenerID
        )
      print(
        "📴 Typing listener stopped:",
        chatID
      )
    }
    typingListenerID =
      nil
    typingChatID =
      nil
  }
  // **MARK: - Local Typing**
  private func handleTypingInputChange() {
    guard
      let chatID =
        chat.serverID
    else {
      return
    }
    let typingEnabled =
      UserDefaults.standard.object(
        forKey: "gru.settings.privacy.typing"
      ) as? Bool ?? true

    if !typingEnabled {
      if isTypingSent {
        WebSocketService.shared.sendTyping(chatID: chatID, typing: false)
        isTypingSent = false
      }
      return
    }

    let hasText =
      !messageText
      .trimmingCharacters(
        in: .whitespacesAndNewlines
      )
      .isEmpty
    typingStopTask?
      .cancel()
    typingStopTask =
      nil
    guard hasText else {
      sendTypingState(
        false,
        chatID: chatID
      )
      return
    }
    sendTypingState(
      true,
      chatID: chatID
    )
    /*
     Если пользователь перестал вводить,
     примерно через 1.3 сек отправляем false.
     */
    typingStopTask =
      Task {
        [weak self] in
        do {
          try await Task.sleep(
            nanoseconds:
              1_300_000_000
          )
        } catch {
          return
        }
        guard let self else {
          return
        }
        self.sendTypingState(
          false,
          chatID: chatID
        )
      }
  }
  // **MARK: - Send Typing State**
  private func sendTypingState(
    _ typing: Bool,
    chatID: String
  ) {
    /*
     Не шлём одинаковое состояние
     снова и снова на каждый символ.
     */
    if typing == isTypingSent {
      return
    }
    isTypingSent =
      typing
    WebSocketService.shared
      .sendTyping(
        chatID: chatID,
        typing: typing
      )
  }
  // **MARK: - Stop Own Typing**
  private func stopOwnTyping() {
    typingStopTask?
      .cancel()
    typingStopTask =
      nil
    guard
      let chatID =
        chat.serverID
    else {
      isTypingSent =
        false
      return
    }
    sendTypingState(
      false,
      chatID: chatID
    )
  }
  // **MARK: - Receive Typing Event**
  private func handleTypingEvent(
    _ event: TypingEventDTO
  ) {
    guard
      event.chatId == chat.serverID
    else {
      return
    }
    /*
     Собственные typing-события
     в интерфейсе не показываем.
     */
    if event.userId == service.currentUser.serverID {
      return
    }
    otherTypingTimeoutTask?
      .cancel()
    otherTypingTimeoutTask =
      nil
    isOtherUserTyping =
      event.typing
    print(
      event.typing
        ? "⌨️ Другой пользователь печатает"
        : "⌨️ Другой пользователь перестал печатать"
    )
    /*
     Страховка:
     если typing=false потеряется,
     индикатор сам исчезнет.
     */
    if event.typing {
      otherTypingTimeoutTask =
        Task {
          [weak self] in
          do {
            try await Task.sleep(
              nanoseconds:
                3_000_000_000
            )
          } catch {
            return
          }
          guard let self else {
            return
          }
          self.isOtherUserTyping =
            false
        }
    }
  }
  // **MARK: - Handle Realtime Message**
  private func handleRealtimeMessage(
    _ serverMessage: ServerMessageDTO
  ) {
    guard
      serverMessage.chatId == chat.serverID
    else {
      return
    }
    if LocalMessageDeletionStore.shared.isHidden(serverMessage.id) {
      return
    }
    print("")
    print(
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    )
    print(
      "💬 ChatViewModel realtime"
    )
    print(
      "🆔",
      serverMessage.id
    )
    print(
      "👤",
      serverMessage.senderId
    )
    print(
      "💬",
      serverMessage.text
    )
    print(
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    )

    if serverMessage.text == "__GRU_CHAT_DELETED__" {
      chatWasDeleted = true
      service.deleteChat(chat.id)
      return
    }

    if serverMessage.deletedAt != nil {
      chat.messages.removeAll { $0.serverID == serverMessage.id }
      chat.updatedAt = Date()
      service.update(chat)
      refreshSearch()
      return
    }

    /*
     При получении реального сообщения
     другого пользователя typing сразу
     можно скрыть.
     */
    if serverMessage.senderId != service.currentUser.serverID {
      isOtherUserTyping =
        false
      otherTypingTimeoutTask?
        .cancel()
      otherTypingTimeoutTask =
        nil
    }
    // **MARK: Existing Message**
    if let existingIndex =
      chat.messages.firstIndex(
        where: {
          $0.serverID == serverMessage.id
        }
      )
    {
      chat.messages[
        existingIndex
      ].applyServerState(
        serverMessage
      )
      applyReplyState(
        serverMessage,
        to: existingIndex
      )
      applyReactionState(
        serverMessage,
        to: existingIndex
      )
      chat.updatedAt =
        max(
          chat.updatedAt,
          serverMessage.createdAt
        )
      service.update(
        chat
      )
      refreshSearch()
      markIncomingAsReadIfNeeded(
        serverMessage
      )
      return
    }
    // **MARK: Optimistic Message**
    if isMessageFromCurrentUser(
      serverMessage
    ),
      let optimisticIndex =
        findOptimisticMessage(
          matching:
            serverMessage
        )
    {
      chat.messages[
        optimisticIndex
      ].applyServerState(
        serverMessage
      )
      applyReplyState(
        serverMessage,
        to: optimisticIndex
      )
      applyReactionState(
        serverMessage,
        to: optimisticIndex
      )
      chat.updatedAt =
        serverMessage.createdAt
      chat.messages.sort {
        $0.sentAt < $1.sentAt
      }
      service.update(
        chat
      )
      refreshSearch()
      print(
        "♻️ Realtime matched optimistic message"
      )
      return
    }
    // **MARK: New Incoming Message**
    let localMessage =
      makeLocalMessage(
        from: serverMessage,
        replyTo:
          replyForServerMessage(
            serverMessage
          )
      )
    chat.messages.append(
      localMessage
    )
    chat.messages =
      removeDuplicates(
        from:
          chat.messages
      )
      .sorted {
        $0.sentAt < $1.sentAt
      }
    chat.updatedAt =
      serverMessage.createdAt
    service.update(
      chat
    )
    refreshSearch()
    print(
      "✅ Realtime bubble added"
    )
    markIncomingAsReadIfNeeded(
      serverMessage
    )
  }
  // **MARK: - Incoming -> Read**
  private func markIncomingAsReadIfNeeded(
    _ serverMessage: ServerMessageDTO
  ) {
    guard
      serverMessage.receiverId == service.currentUser.serverID
    else {
      return
    }
    guard
      serverMessage.readAt == nil
    else {
      return
    }
    Task {
      await markChatRead()
    }
  }
  // **MARK: - Current User Message**
  private func isMessageFromCurrentUser(
    _ serverMessage: ServerMessageDTO
  ) -> Bool {
    guard
      let currentServerID =
        service.currentUser.serverID
    else {
      return false
    }
    return serverMessage.senderId == currentServerID
  }
  // **MARK: - Find Optimistic Message**
  private func findOptimisticMessage(
    matching serverMessage:
      ServerMessageDTO
  ) -> Int? {
    chat.messages.lastIndex {
      message in
      guard
        message.senderID == service.currentUser.id
      else {
        return false
      }
      guard
        message.serverID == nil
      else {
        return false
      }
      guard
        message.status == .sending || message.status == .sent
      else {
        return false
      }
      guard
        message.text == serverMessage.text
      else {
        return false
      }
      guard
        message.replyTo?.serverID == serverMessage.replyTo?.messageId
      else {
        return false
      }
      guard
        attachmentsMatch(
          local:
            message.attachment,
          server:
            serverMessage.attachment
        )
      else {
        return false
      }
      let difference =
        abs(
          message.sentAt
            .timeIntervalSince(
              serverMessage.createdAt
            )
        )
      return difference < 60
    }
  }
  // **MARK: - Attachment Match**
  private func attachmentsMatch(
    local: Attachment?,
    server: Attachment?
  ) -> Bool {
    switch (local, server) {
    case (nil, nil):
      return true
    case let (local?, server?):
      return
        local.type == server.type &&
        local.fileName == server.fileName
    default:
      return false
    }
  }
  // **MARK: - Server Messages -> Local Messages**
  private func makeLocalMessages(
    from serverMessages: [ServerMessageDTO]
  ) -> [Message] {
    let visibleServerMessages = serverMessages.filter {
      !LocalMessageDeletionStore.shared.isHidden($0.id)
    }

    var localMessages = visibleServerMessages.map { serverMessage in
      makeLocalMessage(
        from: serverMessage,
        replyTo: nil
      )
    }

    var messageIndexByServerID: [String: Int] = [:]
    for index in localMessages.indices {
      guard let serverID = localMessages[index].serverID else { continue }
      messageIndexByServerID[serverID] = index
    }

    for index in visibleServerMessages.indices {
      guard let reply = visibleServerMessages[index].replyTo else { continue }

      if let originalIndex = messageIndexByServerID[reply.messageId] {
        localMessages[index].replyTo = localMessages[originalIndex]
        continue
      }

      if let existingMessage = chat.messages.first(where: {
        $0.serverID == reply.messageId &&
        !LocalMessageDeletionStore.shared.isHidden(reply.messageId)
      }) {
        localMessages[index].replyTo = existingMessage
        continue
      }

      localMessages[index].replyTo = makeReplySnapshot(from: reply)
    }

    return localMessages
  }
  // **MARK: - Server -> Local**
  private func makeLocalMessage(
    from serverMessage:
      ServerMessageDTO,
    replyTo: Message? = nil
  ) -> Message {
    let senderID =
      localSenderID(
        serverID:
          serverMessage.senderId
      )
    return Message(
      serverID:
        serverMessage.id,
      senderID:
        senderID,
      text:
        serverMessage.text,
      sentAt:
        serverMessage.createdAt,
      status:
        serverMessage.messageStatus,
      deliveredAt:
        serverMessage.deliveredAt,
      readAt:
        serverMessage.readAt,
      reaction:
        serverMessage.reaction,
      replyTo:
        replyTo,
      attachment:
        serverMessage.attachment
    )
  }
  // **MARK: - Resolve Server Reply**
  private func replyForServerMessage(
    _ serverMessage: ServerMessageDTO
  ) -> Message? {
    guard
      let reply =
        serverMessage.replyTo
    else {
      return nil
    }
    if let originalMessage =
      chat.messages.first(
        where: {
          $0.serverID == reply.messageId
        }
      )
    {
      return originalMessage
    }
    return makeReplySnapshot(
      from: reply
    )
  }
  // **MARK: - Reply Snapshot**
  private func makeReplySnapshot(
    from reply: ServerReplyReferenceDTO
  ) -> Message {
    Message(
      serverID:
        reply.messageId,
      senderID:
        localSenderID(
          serverID:
            reply.senderId
        ),
      text:
        reply.text,
      sentAt:
        .distantPast,
      status:
        .sent,
      reaction:
        nil,
      replyTo:
        nil,
      attachment:
        nil
    )
  }
  // **MARK: - Apply Server Reply**
  private func applyReplyState(
    _ serverMessage: ServerMessageDTO,
    to messageIndex: Int
  ) {
    guard
      chat.messages.indices.contains(
        messageIndex
      )
    else {
      return
    }
    chat.messages[messageIndex].replyTo =
      replyForServerMessage(
        serverMessage
      )
  }
  // **MARK: - Apply Server Reaction**
  private func applyReactionState(
    _ serverMessage: ServerMessageDTO,
    to messageIndex: Int
  ) {
    guard
      chat.messages.indices.contains(
        messageIndex
      )
    else {
      return
    }

    chat.messages[messageIndex].reaction =
      serverMessage.reaction
  }

  // **MARK: - Resolve Sender**
  private func localSenderID(
    serverID: String
  ) -> UUID {
    if let user =
      chat.users.first(
        where: {
          $0.serverID == serverID
        }
      )
    {
      return user.id
    }
    if service.currentUser.serverID == serverID {
      return service.currentUser.id
    }
    if chat.users.count == 2 {
      if let otherUser =
        chat.users.first(
          where: {
            $0.id != service.currentUser.id
          }
        )
      {
        return otherUser.id
      }
    }
    return service.currentUser.id
  }
  // **MARK: - Send Message**
  func sendMessage() {
    let text =
      messageText
      .trimmingCharacters(
        in:
          .whitespacesAndNewlines
      )
    guard
      !text.isEmpty
    else {
      return
    }
    let selectedReply =
      resolvedReplyMessage(
        replyMessage
      )
    let replyToServerID =
      selectedReply?.serverID

    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("↩️ REPLY SEND")
    print(
      "💬 selected text:",
      selectedReply?.text ?? "nil"
    )
    print(
      "🆔 local id:",
      selectedReply?.id.uuidString ?? "nil"
    )
    print(
      "🌐 server id:",
      replyToServerID ?? "nil"
    )
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if
      selectedReply != nil,
      chat.serverID != nil,
      replyToServerID == nil
    {
      print("❌ Reply source has no serverID yet")
      replyMessage = selectedReply
      return
    }

    /*
     Сообщение отправляется —
     typing сразу выключаем.
     */
    stopOwnTyping()
    let localMessage =
      Message(
        senderID:
          service.currentUser.id,
        text:
          text,
        status:
          .sending,
        reaction:
          nil,
        replyTo:
          selectedReply,
        attachment:
          nil
      )
    chat.messages.append(
      localMessage
    )
    chat.updatedAt =
      Date()
    service.update(
      chat
    )
    messageText = ""
    replyMessage = nil
    sendTrigger.toggle()
    refreshSearch()
    guard
      let serverChatID =
        chat.serverID
    else {
      updateMessageStatus(
        messageID:
          localMessage.id,
        status:
          .sent
      )
      return
    }
    guard
      let token =
        TokenStorage.shared.token
    else {
      updateMessageStatus(
        messageID:
          localMessage.id,
        status:
          .failed
      )
      return
    }
    Task {
      do {
        let serverMessage =
          try await MessageAPIService.shared
          .sendMessage(
            chatID:
              serverChatID,
            text:
              text,
            replyToMessageID:
              replyToServerID,
            token:
              token
          )
        markMessageAsSent(
          messageID:
            localMessage.id,
          serverMessage:
            serverMessage
        )
      } catch {
        print(
          "❌ Send message error:",
          error
        )
        updateMessageStatus(
          messageID:
            localMessage.id,
          status:
            .failed
        )
      }
    }
  }
  // **MARK: - Server Confirmation**
  private func markMessageAsSent(
    messageID: UUID,
    serverMessage:
      ServerMessageDTO
  ) {
    if let index =
      chat.messages.firstIndex(
        where: {
          $0.id == messageID
        }
      )
    {
      chat.messages[
        index
      ].applyServerState(
        serverMessage
      )
      applyReplyState(
        serverMessage,
        to: index
      )
      applyReactionState(
        serverMessage,
        to: index
      )
      chat.updatedAt =
        serverMessage.createdAt
      chat.messages.sort {
        $0.sentAt < $1.sentAt
      }
      service.update(
        chat
      )
      refreshSearch()
      return
    }
    if let index =
      chat.messages.firstIndex(
        where: {
          $0.serverID == serverMessage.id
        }
      )
    {
      chat.messages[
        index
      ].applyServerState(
        serverMessage
      )
      applyReplyState(
        serverMessage,
        to: index
      )
      applyReactionState(
        serverMessage,
        to: index
      )
      service.update(
        chat
      )
      refreshSearch()
      return
    }
    let message =
      makeLocalMessage(
        from:
          serverMessage,
        replyTo:
          replyForServerMessage(
            serverMessage
          )
      )
    chat.messages.append(
      message
    )
    chat.messages =
      removeDuplicates(
        from:
          chat.messages
      )
      .sorted {
        $0.sentAt < $1.sentAt
      }
    chat.updatedAt =
      serverMessage.createdAt
    service.update(
      chat
    )
    refreshSearch()
  }
  // **MARK: - Message Status**
  private func updateMessageStatus(
    messageID: UUID,
    status: MessageStatus
  ) {
    guard
      let index =
        chat.messages.firstIndex(
          where: {
            $0.id == messageID
          }
        )
    else {
      return
    }
    chat.messages[
      index
    ].status =
      status
    chat.updatedAt =
      Date()
    service.update(
      chat
    )
  }
  // **MARK: - Mark Chat Read**
  func markChatRead() async {
    guard SettingsStorage.shared.readReceipts else {
      return
    }

    guard
      let chatID =
        chat.serverID
    else {
      return
    }
    guard
      let token =
        TokenStorage.shared.token
    else {
      return
    }
    do {
      let updatedMessages =
        try await MessageAPIService.shared
        .markChatRead(
          chatID:
            chatID,
          token:
            token
        )
      guard
        !updatedMessages.isEmpty
      else {
        return
      }
      for serverMessage
        in updatedMessages
      {
        applyStatusUpdate(
          serverMessage
        )
      }
      print(
        "👀 Chat marked read:",
        updatedMessages.count
      )
    } catch {
      print(
        "❌ Mark chat read error:",
        error
      )
    }
  }
  // **MARK: - Mark Single Read**
  func markMessageRead(
    messageID: String
  ) async {
    guard SettingsStorage.shared.readReceipts else {
      return
    }

    guard
      let token =
        TokenStorage.shared.token
    else {
      return
    }
    do {
      let serverMessage =
        try await MessageAPIService.shared
        .markRead(
          messageID:
            messageID,
          token:
            token
        )
      applyStatusUpdate(
        serverMessage
      )
    } catch {
      print(
        "❌ Mark message read error:",
        error
      )
    }
  }
  // **MARK: - Apply Status**
  private func applyStatusUpdate(
    _ serverMessage:
      ServerMessageDTO
  ) {
    guard
      let index =
        chat.messages.firstIndex(
          where: {
            $0.serverID == serverMessage.id
          }
        )
    else {
      return
    }
    chat.messages[
      index
    ].applyServerState(
      serverMessage
    )
    applyReplyState(
      serverMessage,
      to: index
    )
    applyReactionState(
      serverMessage,
      to: index
    )
    chat.updatedAt =
      max(
        chat.updatedAt,
        serverMessage.createdAt
      )
    service.update(
      chat
    )
    refreshSearch()
  }
  // **MARK: - Retry Message**
  func retryMessage(
    _ message: Message
  ) {
    guard
      message.status == .failed
    else {
      return
    }

    if message.attachment?.type == .photo {
      retryPhotoMessage(
        message
      )
      return
    }

    if message.attachment?.type == .document {
      retryDocumentMessage(message)
      return
    }

    if message.attachment?.type == .video ||
       message.attachment?.type == .videoNote {
      retryVideoMessage(
        message
      )
      return
    }

    if message.attachment?.type == .audio {
      retryAudioMessage(
        message
      )
      return
    }

    let text =
      message.text
      .trimmingCharacters(
        in:
          .whitespacesAndNewlines
      )
    guard
      !text.isEmpty
    else {
      return
    }
    let replyToServerID =
      message.replyTo?.serverID
    guard
      let index =
        chat.messages.firstIndex(
          where: {
            $0.id == message.id
          }
        )
    else {
      return
    }
    guard
      let serverChatID =
        chat.serverID
    else {
      chat.messages[
        index
      ].status =
        .sent
      service.update(
        chat
      )
      return
    }
    guard
      let token =
        TokenStorage.shared.token
    else {
      chat.messages[
        index
      ].status =
        .failed
      service.update(
        chat
      )
      return
    }
    stopOwnTyping()
    chat.messages[
      index
    ].status =
      .sending
    service.update(
      chat
    )
    let localMessageID =
      message.id
    Task {
      do {
        let serverMessage =
          try await MessageAPIService.shared
          .sendMessage(
            chatID:
              serverChatID,
            text:
              text,
            replyToMessageID:
              replyToServerID,
            token:
              token
          )
        markMessageAsSent(
          messageID:
            localMessageID,
          serverMessage:
            serverMessage
        )
      } catch {
        print(
          "❌ Retry message error:",
          error
        )
        updateMessageStatus(
          messageID:
            localMessageID,
          status:
            .failed
        )
      }
    }
  }

  // **MARK: - Retry Photo**
  private func retryPhotoMessage(
    _ message: Message
  ) {
    guard
      let attachment =
        message.attachment,
      attachment.type == .photo,
      let localPath =
        attachment.localPath,
      let data =
        try? Data(
          contentsOf:
            URL(
              fileURLWithPath:
                localPath
            )
        )
    else {
      print(
        "❌ Retry photo failed: local file missing"
      )
      return
    }

    guard
      let index =
        chat.messages.firstIndex(
          where: {
            $0.id == message.id
          }
        )
    else {
      return
    }

    guard
      let serverChatID =
        chat.serverID,
      let token =
        TokenStorage.shared.token
    else {
      return
    }

    let replyToServerID =
      message.replyTo?.serverID

    chat.messages[
      index
    ].status =
      .sending

    service.update(
      chat
    )

    let localMessageID =
      message.id

    Task {
      do {
        let serverMessage =
          try await MessageAPIService.shared
          .sendPhoto(
            chatID:
              serverChatID,
            data:
              data,
            fileName:
              attachment.fileName,
            width:
              attachment.width ?? 0,
            height:
              attachment.height ?? 0,
            replyToMessageID:
              replyToServerID,
            token:
              token
          )

        markMessageAsSent(
          messageID:
            localMessageID,
          serverMessage:
            serverMessage
        )
      } catch {
        print(
          "❌ Retry photo error:",
          error
        )

        updateMessageStatus(
          messageID:
            localMessageID,
          status:
            .failed
        )
      }
    }
  }

  // **MARK: - Retry Document**
  private func retryDocumentMessage(
    _ message: Message
  ) {
    guard
      let attachment = message.attachment,
      attachment.type == .document,
      let localPath = attachment.localPath,
      let data = try? Data(contentsOf: URL(fileURLWithPath: localPath)),
      let index = chat.messages.firstIndex(where: { $0.id == message.id }),
      let serverChatID = chat.serverID,
      let token = TokenStorage.shared.token
    else {
      print("❌ Retry document failed: local file missing")
      return
    }

    chat.messages[index].status = .sending
    service.update(chat)

    let localMessageID = message.id
    let replyToServerID = message.replyTo?.serverID

    Task {
      do {
        let serverMessage = try await MessageAPIService.shared.sendDocument(
          chatID: serverChatID,
          data: data,
          fileName: attachment.fileName,
          replyToMessageID: replyToServerID,
          token: token
        )
        markMessageAsSent(messageID: localMessageID, serverMessage: serverMessage)
      } catch {
        print("❌ Retry document error:", error)
        updateMessageStatus(messageID: localMessageID, status: .failed)
      }
    }
  }

  // **MARK: - Retry Video**
  private func retryVideoMessage(
    _ message: Message
  ) {
    guard
      let attachment =
        message.attachment,
      (attachment.type == .video || attachment.type == .videoNote),
      let localPath =
        attachment.localPath,
      let data =
        try? Data(
          contentsOf:
            URL(
              fileURLWithPath:
                localPath
            )
        )
    else {
      print(
        "❌ Retry video failed: local file missing"
      )
      return
    }

    guard
      let index =
        chat.messages.firstIndex(
          where: {
            $0.id == message.id
          }
        )
    else {
      return
    }

    guard
      let serverChatID =
        chat.serverID,
      let token =
        TokenStorage.shared.token
    else {
      return
    }

    let replyToServerID =
      message.replyTo?.serverID

    chat.messages[
      index
    ].status =
      .sending

    service.update(
      chat
    )

    let localMessageID =
      message.id

    Task {
      do {
        let serverMessage: ServerMessageDTO

        if attachment.type == .videoNote {
          serverMessage = try await MessageAPIService.shared.sendVideoNote(
            chatID: serverChatID,
            data: data,
            fileName: attachment.fileName,
            mimeType: videoMimeType(fileName: attachment.fileName),
            width: attachment.width,
            height: attachment.height,
            duration: attachment.duration,
            replyToMessageID: replyToServerID,
            token: token
          )
        } else {
          serverMessage = try await MessageAPIService.shared.sendVideo(
            chatID: serverChatID,
            data: data,
            fileName: attachment.fileName,
            mimeType: videoMimeType(fileName: attachment.fileName),
            width: attachment.width,
            height: attachment.height,
            duration: attachment.duration,
            replyToMessageID: replyToServerID,
            token: token
          )
        }

        markMessageAsSent(
          messageID:
            localMessageID,
          serverMessage:
            serverMessage
        )
      } catch {
        print(
          "❌ Retry video error:",
          error
        )

        updateMessageStatus(
          messageID:
            localMessageID,
          status:
            .failed
        )
      }
    }
  }

  // **MARK: - Retry Voice Audio**
  private func retryAudioMessage(
    _ message: Message
  ) {
    guard
      let attachment = message.attachment,
      attachment.type == .audio,
      let localPath = attachment.localPath,
      let data = try? Data(contentsOf: URL(fileURLWithPath: localPath))
    else {
      print("❌ Retry voice audio failed: local file missing")
      return
    }

    guard
      let index = chat.messages.firstIndex(where: { $0.id == message.id }),
      let serverChatID = chat.serverID,
      let token = TokenStorage.shared.token
    else {
      return
    }

    let replyToServerID = message.replyTo?.serverID
    chat.messages[index].status = .sending
    service.update(chat)
    let localMessageID = message.id

    Task {
      do {
        let serverMessage = try await MessageAPIService.shared.sendAudio(
          chatID: serverChatID,
          data: data,
          fileName: attachment.fileName,
          mimeType: audioMimeType(fileName: attachment.fileName),
          duration: attachment.duration,
          waveform: attachment.waveform,
          replyToMessageID: replyToServerID,
          token: token
        )
        markMessageAsSent(messageID: localMessageID, serverMessage: serverMessage)
      } catch {
        print("❌ Retry voice audio error:", error)
        updateMessageStatus(messageID: localMessageID, status: .failed)
      }
    }
  }

  // **MARK: - Send Contact Card**
  func sendContactCard(
    name: String,
    phone: String
  ) {
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !cleanPhone.isEmpty else { return }

    messageText = "👤 \(cleanName.isEmpty ? "Контакт" : cleanName)\n📞 \(cleanPhone)"
    sendMessage()
  }

  // **MARK: - Send Document**
  func sendDocument(
    _ sourceURL: URL
  ) async {
    let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
    defer {
      if didStartAccess {
        sourceURL.stopAccessingSecurityScopedResource()
      }
    }

    let data: Data
    do {
      data = try Data(contentsOf: sourceURL)
    } catch {
      print("❌ Read document error:", error)
      return
    }

    let selectedReply = resolvedReplyMessage(replyMessage)
    let replyToServerID = selectedReply?.serverID

    if selectedReply != nil, chat.serverID != nil, replyToServerID == nil {
      print("❌ Document reply source has no serverID yet")
      replyMessage = selectedReply
      return
    }

    stopOwnTyping()

    let originalName = sourceURL.lastPathComponent.isEmpty
      ? UUID().uuidString + ".bin"
      : sourceURL.lastPathComponent

    let safeName = UUID().uuidString + "-" + originalName
    guard let localPath = saveDocument(data, fileName: safeName) else { return }

    let attachment = Attachment(
      type: .document,
      fileName: originalName,
      localPath: localPath,
      remoteURL: nil,
      size: Int64(data.count)
    )

    let localMessage = Message(
      senderID: service.currentUser.id,
      text: "",
      status: .sending,
      reaction: nil,
      replyTo: selectedReply,
      attachment: attachment
    )

    chat.messages.append(localMessage)
    chat.updatedAt = Date()
    service.update(chat)
    replyMessage = nil
    sendTrigger.toggle()
    refreshSearch()

    guard let serverChatID = chat.serverID else {
      updateMessageStatus(messageID: localMessage.id, status: .sent)
      return
    }

    guard let token = TokenStorage.shared.token else {
      updateMessageStatus(messageID: localMessage.id, status: .failed)
      return
    }

    do {
      let serverMessage = try await MessageAPIService.shared.sendDocument(
        chatID: serverChatID,
        data: data,
        fileName: originalName,
        replyToMessageID: replyToServerID,
        token: token
      )
      markMessageAsSent(messageID: localMessage.id, serverMessage: serverMessage)
    } catch {
      print("❌ Send document error:", error)
      updateMessageStatus(messageID: localMessage.id, status: .failed)
    }
  }

  private func saveDocument(
    _ data: Data,
    fileName: String
  ) -> String? {
    guard let directory = FileManager.default.urls(
      for: .cachesDirectory,
      in: .userDomainMask
    ).first else {
      return nil
    }

    let url = directory.appendingPathComponent(fileName)
    do {
      try data.write(to: url, options: .atomic)
      return url.path
    } catch {
      print("❌ Save document error:", error)
      return nil
    }
  }

  // **MARK: - Send Image**
  func sendImage(
    _ image: UIImage
  ) {
    guard
      let data =
        image.jpegData(
          compressionQuality:
            0.85
        )
    else {
      return
    }

    let selectedReply =
      resolvedReplyMessage(
        replyMessage
      )

    let replyToServerID =
      selectedReply?.serverID

    if
      selectedReply != nil,
      chat.serverID != nil,
      replyToServerID == nil
    {
      print(
        "❌ Photo reply source has no serverID yet"
      )
      replyMessage =
        selectedReply
      return
    }

    stopOwnTyping()

    let fileName =
      UUID().uuidString + ".jpg"

    guard
      let localPath =
        saveImage(
          data,
          fileName:
            fileName
        )
    else {
      return
    }

    let attachment =
      Attachment(
        type:
          .photo,
        fileName:
          fileName,
        localPath:
          localPath,
        remoteURL:
          nil,
        width:
          Double(
            image.size.width
          ),
        height:
          Double(
            image.size.height
          ),
        size:
          Int64(
            data.count
          )
      )

    let localMessage =
      Message(
        senderID:
          service.currentUser.id,
        text:
          "",
        status:
          .sending,
        reaction:
          nil,
        replyTo:
          selectedReply,
        attachment:
          attachment
      )

    chat.messages.append(
      localMessage
    )

    chat.updatedAt =
      Date()

    service.update(
      chat
    )

    replyMessage =
      nil

    sendTrigger.toggle()

    refreshSearch()

    guard
      let serverChatID =
        chat.serverID
    else {
      updateMessageStatus(
        messageID:
          localMessage.id,
        status:
          .sent
      )
      return
    }

    guard
      let token =
        TokenStorage.shared.token
    else {
      updateMessageStatus(
        messageID:
          localMessage.id,
        status:
          .failed
      )
      return
    }

    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🖼 PHOTO UPLOAD")
    print(
      "📎 file:",
      fileName
    )
    print(
      "📦 bytes:",
      data.count
    )
    print(
      "↩️ reply:",
      replyToServerID ?? "nil"
    )
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    Task {
      do {
        let serverMessage =
          try await MessageAPIService.shared
          .sendPhoto(
            chatID:
              serverChatID,
            data:
              data,
            fileName:
              fileName,
            width:
              Double(
                image.size.width
              ),
            height:
              Double(
                image.size.height
              ),
            replyToMessageID:
              replyToServerID,
            token:
              token
          )

        markMessageAsSent(
          messageID:
            localMessage.id,
          serverMessage:
            serverMessage
        )
      } catch {
        print(
          "❌ Send photo error:",
          error
        )

        updateMessageStatus(
          messageID:
            localMessage.id,
          status:
            .failed
        )
      }
    }
  }

  // **MARK: - Send Video**
  func sendVideo(
    _ sourceURL: URL
  ) async {
    let selectedReply = resolvedReplyMessage(replyMessage)
    let replyToServerID = selectedReply?.serverID

    if selectedReply != nil, chat.serverID != nil, replyToServerID == nil {
      print("❌ Video reply source has no serverID yet")
      replyMessage = selectedReply
      return
    }

    stopOwnTyping()

    let prepared: PreparedVideo
    do {
      prepared = try await Self.prepareVideo(from: sourceURL)
    } catch {
      print("❌ Prepare video error:", error)
      return
    }

    let fileName = UUID().uuidString + "." + prepared.fileExtension
    guard let localPath = saveVideo(prepared.data, fileName: fileName) else { return }

    let attachment = Attachment(
      type: .video,
      fileName: fileName,
      localPath: localPath,
      remoteURL: nil,
      width: prepared.width,
      height: prepared.height,
      duration: prepared.duration,
      size: Int64(prepared.data.count)
    )

    let localMessage = Message(
      senderID: service.currentUser.id,
      text: "",
      status: .sending,
      reaction: nil,
      replyTo: selectedReply,
      attachment: attachment
    )

    chat.messages.append(localMessage)
    chat.updatedAt = Date()
    service.update(chat)
    replyMessage = nil
    sendTrigger.toggle()
    refreshSearch()

    guard let serverChatID = chat.serverID else {
      updateMessageStatus(messageID: localMessage.id, status: .sent)
      return
    }

    guard let token = TokenStorage.shared.token else {
      updateMessageStatus(messageID: localMessage.id, status: .failed)
      return
    }

    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🎬 VIDEO UPLOAD")
    print("📎 file:", fileName)
    print("📦 bytes:", prepared.data.count)
    print("⏱ duration:", prepared.duration ?? 0)
    print("↩️ reply:", replyToServerID ?? "nil")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    do {
      let serverMessage = try await MessageAPIService.shared.sendVideo(
        chatID: serverChatID,
        data: prepared.data,
        fileName: fileName,
        mimeType: prepared.mimeType,
        width: prepared.width,
        height: prepared.height,
        duration: prepared.duration,
        replyToMessageID: replyToServerID,
        token: token
      )

      markMessageAsSent(
        messageID: localMessage.id,
        serverMessage: serverMessage
      )
    } catch {
      print("❌ Send video error:", error)
      updateMessageStatus(messageID: localMessage.id, status: .failed)
    }
  }

  // **MARK: - Send Cat Video Note**
  func sendVideoNote(
    _ sourceURL: URL
  ) async {
    let selectedReply =
      resolvedReplyMessage(
        replyMessage
      )

    let replyToServerID =
      selectedReply?.serverID

    if
      selectedReply != nil,
      chat.serverID != nil,
      replyToServerID == nil
    {
      print(
        "❌ Video reply source has no serverID yet"
      )
      replyMessage =
        selectedReply
      return
    }

    stopOwnTyping()

    let prepared: PreparedVideo

    do {
      prepared =
        try await Self.prepareVideo(
          from:
            sourceURL
        )
    } catch {
      print(
        "❌ Prepare video error:",
        error
      )
      return
    }

    let fileName =
      UUID().uuidString +
      "." +
      prepared.fileExtension

    guard
      let localPath =
        saveVideo(
          prepared.data,
          fileName:
            fileName
        )
    else {
      return
    }

    let attachment =
      Attachment(
        type:
          .videoNote,
        fileName:
          fileName,
        localPath:
          localPath,
        remoteURL:
          nil,
        width:
          prepared.width,
        height:
          prepared.height,
        duration:
          prepared.duration,
        size:
          Int64(
            prepared.data.count
          )
      )

    let localMessage =
      Message(
        senderID:
          service.currentUser.id,
        text:
          "",
        status:
          .sending,
        reaction:
          nil,
        replyTo:
          selectedReply,
        attachment:
          attachment
      )

    chat.messages.append(
      localMessage
    )

    chat.updatedAt =
      Date()

    service.update(
      chat
    )

    replyMessage =
      nil

    sendTrigger.toggle()

    refreshSearch()

    guard
      let serverChatID =
        chat.serverID
    else {
      updateMessageStatus(
        messageID:
          localMessage.id,
        status:
          .sent
      )
      return
    }

    guard
      let token =
        TokenStorage.shared.token
    else {
      updateMessageStatus(
        messageID:
          localMessage.id,
        status:
          .failed
      )
      return
    }

    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🐱 VIDEO MESSAGE UPLOAD")
    print(
      "📎 file:",
      fileName
    )
    print(
      "📦 bytes:",
      prepared.data.count
    )
    print(
      "⏱ duration:",
      prepared.duration ?? 0
    )
    print(
      "↩️ reply:",
      replyToServerID ?? "nil"
    )
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    do {
      let serverMessage =
        try await MessageAPIService.shared
        .sendVideoNote(
          chatID:
            serverChatID,
          data:
            prepared.data,
          fileName:
            fileName,
          mimeType:
            prepared.mimeType,
          width:
            prepared.width,
          height:
            prepared.height,
          duration:
            prepared.duration,
          replyToMessageID:
            replyToServerID,
          token:
            token
        )

      markMessageAsSent(
        messageID:
          localMessage.id,
        serverMessage:
          serverMessage
      )
    } catch {
      print(
        "❌ Send video note error:",
        error
      )

      updateMessageStatus(
        messageID:
          localMessage.id,
        status:
          .failed
      )
    }
  }

  // **MARK: - Send Voice Audio**
  func sendAudio(
    url: URL,
    duration: Double,
    waveform: [Double]
  ) async {
    let selectedReply = resolvedReplyMessage(replyMessage)
    let replyToServerID = selectedReply?.serverID

    if selectedReply != nil, chat.serverID != nil, replyToServerID == nil {
      print("❌ Audio reply source has no serverID yet")
      replyMessage = selectedReply
      return
    }

    stopOwnTyping()

    let data: Data
    do {
      data = try Data(contentsOf: url)
    } catch {
      print("❌ Read voice audio error:", error)
      return
    }

    let fileName = UUID().uuidString + ".m4a"
    guard let localPath = saveAudio(data, fileName: fileName) else { return }

    let safeWaveform = waveform.prefix(64).map { max(0.04, min(1.0, $0)) }
    let attachment = Attachment(
      type: .audio,
      fileName: fileName,
      localPath: localPath,
      remoteURL: nil,
      width: nil,
      height: nil,
      duration: duration > 0 ? duration : nil,
      waveform: Array(safeWaveform),
      size: Int64(data.count)
    )

    let localMessage = Message(
      senderID: service.currentUser.id,
      text: "",
      status: .sending,
      reaction: nil,
      replyTo: selectedReply,
      attachment: attachment
    )

    chat.messages.append(localMessage)
    chat.updatedAt = Date()
    service.update(chat)
    replyMessage = nil
    sendTrigger.toggle()
    refreshSearch()

    guard let serverChatID = chat.serverID else {
      updateMessageStatus(messageID: localMessage.id, status: .sent)
      return
    }

    guard let token = TokenStorage.shared.token else {
      updateMessageStatus(messageID: localMessage.id, status: .failed)
      return
    }

    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🎙️ VOICE AUDIO UPLOAD")
    print("📎 file:", fileName)
    print("📦 bytes:", data.count)
    print("⏱ duration:", duration)
    print("〰 waveform samples:", safeWaveform.count)
    print("↩️ reply:", replyToServerID ?? "nil")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    do {
      let serverMessage = try await MessageAPIService.shared.sendAudio(
        chatID: serverChatID,
        data: data,
        fileName: fileName,
        mimeType: "audio/mp4",
        duration: duration,
        waveform: Array(safeWaveform),
        replyToMessageID: replyToServerID,
        token: token
      )
      markMessageAsSent(messageID: localMessage.id, serverMessage: serverMessage)
    } catch {
      print("❌ Send voice audio error:", error)
      updateMessageStatus(messageID: localMessage.id, status: .failed)
    }
  }

  // **MARK: - Save Audio**
  private func saveAudio(
    _ data: Data,
    fileName: String
  ) -> String? {
    let fileManager = FileManager.default
    guard let directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
      return nil
    }
    let fileURL = directory.appendingPathComponent(fileName)
    do {
      try data.write(to: fileURL, options: .atomic)
      return fileURL.path
    } catch {
      print("❌ Failed to save voice audio:", error)
      return nil
    }
  }

  private func audioMimeType(
    fileName: String
  ) -> String {
    switch URL(fileURLWithPath: fileName).pathExtension.lowercased() {
    case "aac":
      return "audio/aac"
    default:
      return "audio/mp4"
    }
  }

  // **MARK: - Prepared Video**
  private struct PreparedVideo: Sendable {
    let data: Data
    let fileExtension: String
    let mimeType: String
    let width: Double?
    let height: Double?
    let duration: Double?
  }

  private nonisolated static func prepareVideo(
    from sourceURL: URL
  ) async throws -> PreparedVideo {
    let data =
      try Data(
        contentsOf:
          sourceURL
      )

    let rawExtension =
      sourceURL.pathExtension
        .lowercased()

    let fileExtension: String
    let mimeType: String

    switch rawExtension {
    case "mp4":
      fileExtension = "mp4"
      mimeType = "video/mp4"
    case "m4v":
      fileExtension = "m4v"
      mimeType = "video/x-m4v"
    default:
      fileExtension = "mov"
      mimeType = "video/quicktime"
    }

    let asset =
      AVURLAsset(
        url:
          sourceURL
      )

    var duration: Double?
    var width: Double?
    var height: Double?

    do {
      let durationTime =
        try await asset.load(
          .duration
        )

      let seconds =
        CMTimeGetSeconds(
          durationTime
        )

      if seconds.isFinite,
         seconds > 0 {
        duration = seconds
      }

      if let track =
        try await asset
          .loadTracks(
            withMediaType:
              .video
          )
          .first
      {
        let naturalSize =
          try await track.load(
            .naturalSize
          )

        let transform =
          try await track.load(
            .preferredTransform
          )

        let transformed =
          naturalSize.applying(
            transform
          )

        let resolvedWidth =
          abs(
            Double(
              transformed.width
            )
          )

        let resolvedHeight =
          abs(
            Double(
              transformed.height
            )
          )

        if resolvedWidth > 0 {
          width = resolvedWidth
        }

        if resolvedHeight > 0 {
          height = resolvedHeight
        }
      }

    } catch {
      print(
        "⚠️ Video metadata error:",
        error
      )
    }

    return PreparedVideo(
      data:
        data,
      fileExtension:
        fileExtension,
      mimeType:
        mimeType,
      width:
        width,
      height:
        height,
      duration:
        duration
    )
  }

  private func saveVideo(
    _ data: Data,
    fileName: String
  ) -> String? {
    let fileManager =
      FileManager.default

    guard
      let directory =
        fileManager.urls(
          for:
            .cachesDirectory,
          in:
            .userDomainMask
        ).first
    else {
      return nil
    }

    let fileURL =
      directory
        .appendingPathComponent(
          fileName
        )

    do {
      try data.write(
        to:
          fileURL,
        options:
          .atomic
      )

      return fileURL.path

    } catch {
      print(
        "❌ Failed to save video:",
        error
      )
      return nil
    }
  }

  private func videoMimeType(
    fileName: String
  ) -> String {
    switch URL(
      fileURLWithPath:
        fileName
    )
    .pathExtension
    .lowercased() {
    case "mp4":
      return "video/mp4"
    case "m4v":
      return "video/x-m4v"
    default:
      return "video/quicktime"
    }
  }

  // **MARK: - Save Image**
  private func saveImage(
    _ data: Data,
    fileName: String
  ) -> String? {
    let fileManager =
      FileManager.default
    guard
      let directory =
        fileManager.urls(
          for:
            .cachesDirectory,
          in:
            .userDomainMask
        ).first
    else {
      return nil
    }
    let fileURL =
      directory
      .appendingPathComponent(
        fileName
      )
    do {
      try data.write(
        to:
          fileURL,
        options:
          .atomic
      )
      return fileURL.path
    } catch {
      print(
        "❌ Failed to save image:",
        error
      )
      return nil
    }
  }
  // **MARK: - Reply**
  func startReply(
    to message: Message
  ) {
    if message.text ==
      "Сообщение удалено"
    {
      print(
        "❌ Cannot reply to deleted message"
      )
      return
    }

    let resolved =
      resolvedReplyMessage(
        message
      ) ?? message

    replyMessage =
      resolved

    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("↩️ REPLY SELECTED")
    print(
      "💬 text:",
      resolved.text
    )
    print(
      "🆔 local id:",
      resolved.id.uuidString
    )
    print(
      "🌐 server id:",
      resolved.serverID ?? "nil"
    )
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
  }

  private func resolvedReplyMessage(
    _ message: Message?
  ) -> Message? {
    guard let message else {
      return nil
    }

    if let serverID =
      message.serverID,
      let current =
        chat.messages.first(
          where: {
            $0.serverID == serverID
          }
        )
    {
      return current
    }

    if let current =
      chat.messages.first(
        where: {
          $0.id == message.id
        }
      )
    {
      return current
    }

    return message
  }
  func cancelReply() {
    replyMessage =
      nil
  }
  // **MARK: - Delete Local**
  func deleteLocal(
    _ message: Message
  ) {
    guard let index = chat.messages.firstIndex(where: { $0.id == message.id }) else {
      return
    }

    let serverID = chat.messages[index].serverID
    if let serverID, !serverID.isEmpty {
      LocalMessageDeletionStore.shared.hide(serverID)
    }

    chat.messages.remove(at: index)
    chat.updatedAt = Date()
    service.update(chat)
    refreshSearch()

    // Keep "delete for me" across reloads when the backend supports it. The
    // optimistic local removal remains valid if an older server returns 404.
    if let serverID,
       !serverID.isEmpty,
       let token = TokenStorage.shared.token,
       !token.isEmpty {
      Task {
        do {
          _ = try await MessageAPIService.shared.deleteMessageForMe(
            messageID: serverID,
            token: token
          )
        } catch {
          print("⚠️ Delete for me sync unavailable; local hide kept:", error)
        }
      }
    }
  }

  // **MARK: - Delete For Everyone**
  func deleteForEveryone(
    _ message: Message
  ) {
    guard
      let index =
        chat.messages.firstIndex(
          where: {
            $0.id == message.id
          }
        )
    else {
      return
    }

    guard
      let serverMessageID =
        chat.messages[index].serverID,
      !serverMessageID.isEmpty
    else {
      /*
       Локальное сообщение ещё не существует
       на сервере. Его можно удалить только
       из локального массива.
       */
      chat.messages.remove(
        at: index
      )
      chat.updatedAt =
        Date()
      service.update(
        chat
      )
      refreshSearch()
      return
    }

    guard
      let token =
        TokenStorage.shared.token,
      !token.isEmpty
    else {
      actionError =
        "Не удалось удалить сообщение: сессия не найдена."
      print(
        "❌ Delete failed: no auth token"
      )
      return
    }

    let previousMessage = chat.messages[index]
    let previousIndex = index

    // V10: сообщение исчезает сразу, без placeholder или системной плашки.
    chat.messages.remove(at: index)
    chat.updatedAt = Date()
    service.update(chat)
    refreshSearch()

    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🗑 MESSAGE DELETE")
    print(
      "🆔 message:",
      serverMessageID
    )
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    Task {
      [weak self] in

      guard let self else {
        return
      }

      do {
        let serverMessage =
          try await MessageAPIService.shared
          .deleteMessage(
            messageID:
              serverMessageID,
            token:
              token
          )

        self.chat.messages.removeAll { $0.serverID == serverMessage.id }
        self.service.update(self.chat)
        self.refreshSearch()

      } catch {

        if !self.chat.messages.contains(where: { $0.serverID == serverMessageID }) {
          let safeIndex = min(previousIndex, self.chat.messages.count)
          self.chat.messages.insert(previousMessage, at: safeIndex)
        }

        self.service.update(self.chat)

        self.refreshSearch()

        self.actionError =
          "Не удалось удалить сообщение у собеседника. Изменение отменено: \(error.localizedDescription)"

        print(
          "❌ Delete message error:",
          error
        )
      }
    }
  }

  func clearActionError() {
    actionError = nil
  }
  // **MARK: - Add Reaction**
  func addReaction(
    _ reaction: ReactionType,
    to message: Message
  ) {
    guard
      let index =
        chat.messages.firstIndex(
          where: {
            $0.id == message.id
          }
        )
    else {
      return
    }

    if chat.messages[index].text ==
      "Сообщение удалено"
    {
      print(
        "❌ Cannot react to deleted message"
      )
      return
    }

    guard
      let serverMessageID =
        chat.messages[index].serverID,
      !serverMessageID.isEmpty
    else {
      print(
        "❌ Reaction source has no serverID yet"
      )
      return
    }

    guard
      let token =
        TokenStorage.shared.token,
      !token.isEmpty
    else {
      print(
        "❌ Reaction failed: no auth token"
      )
      return
    }

    let previousReaction =
      chat.messages[index].reaction

    // Optimistic UI.
    chat.messages[index].reaction =
      reaction

    service.update(
      chat
    )

    refreshSearch()

    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("❤️ REACTION SET")
    print(
      "🆔 message:",
      serverMessageID
    )
    print(
      "😀 reaction:",
      reaction.rawValue
    )
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    Task {
      [weak self] in

      guard let self else {
        return
      }

      do {
        let serverMessage =
          try await MessageAPIService.shared
          .setReaction(
            messageID:
              serverMessageID,
            reaction:
              reaction,
            token:
              token
          )

        self.applyStatusUpdate(
          serverMessage
        )

      } catch {

        guard
          let rollbackIndex =
            self.chat.messages.firstIndex(
              where: {
                $0.serverID ==
                  serverMessageID
              }
            )
        else {
          return
        }

        self.chat.messages[
          rollbackIndex
        ].reaction =
          previousReaction

        self.service.update(
          self.chat
        )

        self.refreshSearch()

        print(
          "❌ Set reaction error:",
          error
        )
      }
    }
  }

  // **MARK: - Remove Reaction**
  func removeReaction(
    from message: Message
  ) {
    guard
      let index =
        chat.messages.firstIndex(
          where: {
            $0.id == message.id
          }
        )
    else {
      return
    }

    if chat.messages[index].text ==
      "Сообщение удалено"
    {
      print(
        "❌ Cannot react to deleted message"
      )
      return
    }

    guard
      let serverMessageID =
        chat.messages[index].serverID,
      !serverMessageID.isEmpty
    else {
      print(
        "❌ Reaction source has no serverID yet"
      )
      return
    }

    guard
      let token =
        TokenStorage.shared.token,
      !token.isEmpty
    else {
      print(
        "❌ Remove reaction failed: no auth token"
      )
      return
    }

    let previousReaction =
      chat.messages[index].reaction

    // Optimistic UI.
    chat.messages[index].reaction =
      nil

    service.update(
      chat
    )

    refreshSearch()

    print("")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🤍 REACTION REMOVE")
    print(
      "🆔 message:",
      serverMessageID
    )
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    Task {
      [weak self] in

      guard let self else {
        return
      }

      do {
        let serverMessage =
          try await MessageAPIService.shared
          .removeReaction(
            messageID:
              serverMessageID,
            token:
              token
          )

        self.applyStatusUpdate(
          serverMessage
        )

      } catch {

        guard
          let rollbackIndex =
            self.chat.messages.firstIndex(
              where: {
                $0.serverID ==
                  serverMessageID
              }
            )
        else {
          return
        }

        self.chat.messages[
          rollbackIndex
        ].reaction =
          previousReaction

        self.service.update(
          self.chat
        )

        self.refreshSearch()

        print(
          "❌ Remove reaction error:",
          error
        )
      }
    }
  }

  // **MARK: - Search**
  func performSearch() {
    let query =
      searchText
      .trimmingCharacters(
        in:
          .whitespacesAndNewlines
      )
      .lowercased()
    guard
      !query.isEmpty
    else {
      searchResults
        .removeAll()
      selectedSearchIndex =
        0
      return
    }
    searchResults =
      chat.messages.filter {
        message in
        message.text
          .lowercased()
          .contains(
            query
          )
      }
    selectedSearchIndex =
      0
  }
  func clearSearch() {
    searchText =
      ""
    searchResults
      .removeAll()
    selectedSearchIndex =
      0
  }
  func nextResult() {
    guard
      !searchResults.isEmpty
    else {
      return
    }
    selectedSearchIndex +=
      1
    if selectedSearchIndex >= searchResults.count {
      selectedSearchIndex =
        0
    }
  }
  func previousResult() {
    guard
      !searchResults.isEmpty
    else {
      return
    }
    selectedSearchIndex -=
      1
    if selectedSearchIndex < 0 {
      selectedSearchIndex =
        searchResults.count - 1
    }
  }
  // **MARK: - Current Search Message**
  var currentSearchMessage: Message? {
    guard
      searchResults.indices
        .contains(
          selectedSearchIndex
        )
    else {
      return nil
    }
    return searchResults[
      selectedSearchIndex
    ]
  }
  // **MARK: - Search Counter**
  var searchCountText: String {
    guard
      !searchResults.isEmpty
    else {
      return "0"
    }
    return
      "\(selectedSearchIndex + 1)/\(searchResults.count)"
  }
  // **MARK: - Refresh Search**
  private func refreshSearch() {
    guard
      !searchText.isEmpty
    else {
      return
    }
    performSearch()
  }
}
