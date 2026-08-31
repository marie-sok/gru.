//
//  NotificationService.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import Foundation
import UserNotifications

@MainActor
@Observable
final class NotificationService {

    static let shared = NotificationService()

    private init() {}

    // MARK: - Permission

    func requestPermission() async {

        do {

            let center = UNUserNotificationCenter.current()

            _ = try await center.requestAuthorization(
                options: [
                    .alert,
                    .badge,
                    .sound
                ]
            )

        } catch {

            print(error.localizedDescription)
        }
    }

    // MARK: - Message

    func sendMessageNotification(

        title: String,

        body: String

    ) {

        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: "notifications") as? Bool ?? true
        guard enabled else { return }

        let preview = defaults.object(forKey: "gru.settings.notifications.messagePreview") as? Bool ?? true
        let sounds = defaults.object(forKey: "sounds") as? Bool ?? true
        let badge = defaults.object(forKey: "gru.settings.notifications.badge") as? Bool ?? true

        let content = UNMutableNotificationContent()

        content.title = title
        content.body = preview ? body : "Новое сообщение"
        content.sound = sounds ? .default : nil
        if badge { content.badge = 1 }

        let trigger = UNTimeIntervalNotificationTrigger(

            timeInterval: 1,

            repeats: false

        )

        let request = UNNotificationRequest(

            identifier: UUID().uuidString,

            content: content,

            trigger: trigger

        )

        UNUserNotificationCenter.current()

            .add(request)
    }

    // MARK: - Remove

    func removeAllNotifications() {

        let center = UNUserNotificationCenter.current()

        center.removeAllDeliveredNotifications()

        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Badge

    func clearBadge() {

        UNUserNotificationCenter.current()

            .setBadgeCount(0)
    }
}
