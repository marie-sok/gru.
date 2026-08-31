//
//  AppTab.swift
//  gru.
//
//  Created by Maria Morozova on 03.07.2026.
//


import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case contacts
    case chats
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .contacts:
            return "Люди"
        case .chats:
            return "Чаты"
        case .settings:
            return "Настройки"
        }
    }

    var systemImage: String {
        switch self {
        case .contacts:
            return "person.2"
        case .chats:
            return "envelope"
        case .settings:
            return "gearshape"
        }
    }
}
