//
//  MessageStatus.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import Foundation

enum MessageStatus: String, Codable, CaseIterable {

    case sending
    case sent
    case delivered
    case read
    case failed
}