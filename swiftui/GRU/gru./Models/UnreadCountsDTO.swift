//
//  UnreadCountsDTO.swift
//  gru
//
//  Created by Maria Morozova on 25.08.2026.
//


import Foundation

struct UnreadCountsDTO: Codable {

    let chats: [String: Int]

    let total: Int
}