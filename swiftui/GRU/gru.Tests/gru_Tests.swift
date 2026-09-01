//
//  gru_Tests.swift
//  gru.Tests
//
//  Created by Maria Morozova on 18.04.2026.
//

import Testing
import Foundation
import UIKit
@testable import gru

struct gru_Tests {

    // MARK: - 1. Message & Editing Tests

    @Test func testMessageCreationAndEditing() throws {
        let senderID = UUID()
        var message = Message(
            senderID: senderID,
            text: "Первоначальный текст"
        )

        #expect(message.text == "Первоначальный текст")
        #expect(message.isEdited == false)
        #expect(message.editedAt == nil)

        // Имитируем редактирование сообщения
        let newText = "Изменённый текст сообщения"
        message.text = newText
        message.isEdited = true
        message.editedAt = Date()

        #expect(message.text == newText)
        #expect(message.isEdited == true)
        #expect(message.editedAt != nil)

        // Проверяем Codable сериализацию
        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(Message.self, from: data)

        #expect(decoded.id == message.id)
        #expect(decoded.text == newText)
        #expect(decoded.isEdited == true)
    }

    // MARK: - 2. ServerMessageDTO Mapping

    @Test func testServerMessageDTOMapping() throws {
        let serverDTO = ServerMessageDTO(
            id: "msg-12345",
            chatId: "chat-67890",
            senderId: "user-111",
            receiverId: "user-222",
            text: "Привет от сервера!",
            createdAt: Date(),
            deliveredAt: Date(),
            readAt: nil,
            deletedAt: nil,
            isEdited: true,
            editedAt: Date(),
            reaction: .heart,
            replyTo: nil,
            attachment: nil
        )

        var localMessage = Message(
            senderID: UUID(),
            text: "Локальный текст"
        )

        localMessage.applyServerState(serverDTO)

        #expect(localMessage.serverID == "msg-12345")
        #expect(localMessage.text == "Привет от сервера!")
        #expect(localMessage.status == .delivered)
        #expect(localMessage.reaction == .heart)
        #expect(localMessage.isEdited == true)
        #expect(localMessage.editedAt != nil)
    }

    // MARK: - 3. TokenStorage (Keychain) Tests

    @Test func testTokenStoragePersistence() throws {
        let storage = TokenStorage.shared

        let testToken = "test_jwt_token_\(UUID().uuidString)"
        let testUserID = "user_\(UUID().uuidString)"

        // Сохраняем сессию
        storage.save(token: testToken, userID: testUserID)

        #expect(storage.token == testToken)
        #expect(storage.userID == testUserID)

        // Очищаем сессию
        storage.clear()

        #expect(storage.token == nil)
        #expect(storage.userID == nil)
    }

    // MARK: - 4. MediaCacheService Tests

    @Test func testMediaCacheStorageAndRetrieval() throws {
        let cache = MediaCacheService.shared
        let testKey = "test_image_\(UUID().uuidString)"

        // Создаем простое тестовое изображение 10x10
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let testImage = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
        }

        // Сохраняем в кэш
        cache.store(testImage, for: testKey)

        // Проверяем получение из кэша
        let retrieved = cache.image(for: testKey)
        #expect(retrieved != nil)

        // Проверяем бинарные данные
        let testData = "Hello Media Cache".data(using: .utf8)!
        let dataKey = "test_data_\(UUID().uuidString)"
        cache.store(data: testData, for: dataKey)

        let retrievedData = cache.data(for: dataKey)
        #expect(retrievedData == testData)
    }

    // MARK: - 5. User Model & Avatar Tests

    @Test func testUserModelWithAvatar() throws {
        let userWithAvatar = User(
            username: "sarah",
            displayName: "Sarah Connor",
            isOnline: true,
            avatarURL: "https://example.com/avatar.jpg"
        )

        #expect(userWithAvatar.username == "sarah")
        #expect(userWithAvatar.avatarURL == "https://example.com/avatar.jpg")
        #expect(userWithAvatar.isOnline == true)

        let userWithoutAvatar = User(
            username: "john",
            displayName: "John Doe"
        )

        #expect(userWithoutAvatar.avatarURL == nil)
        #expect(userWithoutAvatar.isOnline == false)
    }

    // MARK: - 6. NetworkMonitor Connection Types

    @Test func testNetworkMonitorTypes() throws {
        #expect(NetworkMonitor.ConnectionType.wifi.rawValue == "Wi-Fi")
        #expect(NetworkMonitor.ConnectionType.cellular.rawValue == "Сотовая сеть")
        #expect(NetworkMonitor.ConnectionType.ethernet.rawValue == "Ethernet")
    }
}
