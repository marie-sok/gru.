//
//  UserSearchDTO.swift
//  gru
//
//  Created by Maria Morozova on 24.08.2026.
//


import Foundation

struct UserSearchDTO: Codable, Identifiable, Hashable {

    let id: String

    let nickname: String
}