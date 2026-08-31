//
//  SocketService.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import Foundation
import Combine

@MainActor
final class SocketService: ObservableObject {

    static let shared = SocketService()

    @Published private(set) var isConnected = false

    private init() {}

    // MARK: - Connect

    func connect() {

        guard !isConnected else {
            return
        }

        isConnected = true

        print("✅ Socket connected")
    }

    // MARK: - Disconnect

    func disconnect() {

        guard isConnected else {
            return
        }

        isConnected = false

        print("❌ Socket disconnected")
    }

    // MARK: - Send

    func send(
        _ message: Message,
        chatID: UUID
    ) {

        guard isConnected else {
            return
        }

        print("📤 Send message \(message.id)")
    }

    // MARK: - Receive

    func receive(
        _ message: Message,
        chatID: UUID
    ) {

        guard let index = ChatService.shared.chatIndex(
            for: chatID
        ) else {
            return
        }

        ChatService.shared.chats[index]
            .messages
            .append(message)
    }

    // MARK: - Typing

    func sendTyping(
        chatID: UUID,
        typing: Bool
    ) {

        print("⌨️ Typing:", typing)
    }
}