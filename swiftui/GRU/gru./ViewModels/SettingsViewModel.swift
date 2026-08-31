//
//  SettingsViewModel.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var notificationsEnabled = true

    @Published var darkModeEnabled = false

    @Published var autoDownloadMedia = true

    @Published var sendReadReceipts = true

    func toggleNotifications() {

        notificationsEnabled.toggle()
    }

    func toggleDarkMode() {

        darkModeEnabled.toggle()
    }

    func toggleAutoDownload() {

        autoDownloadMedia.toggle()
    }

    func toggleReadReceipts() {

        sendReadReceipts.toggle()
    }
}

