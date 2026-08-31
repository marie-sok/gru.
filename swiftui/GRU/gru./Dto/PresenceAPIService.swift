//
//  PresenceAPIService.swift
//  gru
//
//  Created by Maria Morozova on 25.08.2026.
//


import Foundation

final class PresenceAPIService {

    static let shared =
        PresenceAPIService()

    private init() {}

    func getOnlineUserIDs(
        token: String
    ) async throws -> Set<String> {

        let data =
            try await APIClient.shared.request(
                path: "/presence",
                method: "GET",
                token: token
            )

        let ids =
            try JSONCoding.decoder.decode(
                [String].self,
                from: data
            )

        return Set(ids)
    }
}