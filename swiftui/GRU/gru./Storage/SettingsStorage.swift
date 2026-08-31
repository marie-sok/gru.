//
//  SettingsStorage.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import Foundation

final class SettingsStorage {

    static let shared = SettingsStorage()

    private let defaults = UserDefaults.standard

    private init() {}

    enum Key: String {

        case darkMode
        case notifications
        case autoDownload
        case readReceipts
    }

    var darkMode: Bool {

        get {

            defaults.bool(
                forKey: Key.darkMode.rawValue
            )
        }

        set {

            defaults.set(
                newValue,
                forKey: Key.darkMode.rawValue
            )
        }
    }

    var notificationsEnabled: Bool {

        get {

            defaults.object(
                forKey: Key.notifications.rawValue
            ) as? Bool ?? true
        }

        set {

            defaults.set(
                newValue,
                forKey: Key.notifications.rawValue
            )
        }
    }

    var autoDownload: Bool {

        get {

            defaults.object(
                forKey: Key.autoDownload.rawValue
            ) as? Bool ?? true
        }

        set {

            defaults.set(
                newValue,
                forKey: Key.autoDownload.rawValue
            )
        }
    }

    var readReceipts: Bool {

        get {

            defaults.object(
                forKey: Key.readReceipts.rawValue
            ) as? Bool ?? true
        }

        set {

            defaults.set(
                newValue,
                forKey: Key.readReceipts.rawValue
            )
        }
    }

    // MARK: - Chat Drafts

    func draft(
        for chatID: String
    ) -> String {
        defaults.string(
            forKey: draftKey(for: chatID)
        ) ?? ""
    }

    func saveDraft(
        _ text: String,
        for chatID: String
    ) {
        if text.isEmpty {
            defaults.removeObject(
                forKey: draftKey(for: chatID)
            )
        } else {
            defaults.set(
                text,
                forKey: draftKey(for: chatID)
            )
        }
    }

    private func draftKey(
        for chatID: String
    ) -> String {
        "gru.chat.draft.\(chatID)"
    }
}
