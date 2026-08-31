//
//  UnreadAPIService.swift
//  gru
//
//  Created by Maria Morozova on 25.08.2026.
//


import Foundation

final class UnreadAPIService {

    static let shared =
        UnreadAPIService()

    private init() {}

    // MARK: - Get Unread Counts

    func getUnreadCounts(
        token: String
    ) async throws -> UnreadCountsDTO {

        let data =
            try await APIClient.shared.request(
                path:
                    "/messages/unread-counts",
                method:
                    "GET",
                token:
                    token
            )

        let response =
            try JSONCoding.decoder.decode(
                UnreadCountsDTO.self,
                from:
                    data
            )

        return response
    }
}