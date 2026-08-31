//
//  RegisterRequest.swift
//  gru.
//
//  Created by Maria Morozova on 27.06.2026.
//


import Foundation

struct RegisterRequest: Codable {
    let phone: String
    let password: String
    let nickname: String
}