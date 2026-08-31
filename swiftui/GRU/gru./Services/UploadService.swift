//
//  UploadService.swift
//  gru.
//
//  Created by Maria Morozova on 06.07.2026.
//


import Foundation
import UIKit

@MainActor
final class UploadService {

    static let shared = UploadService()

    private init() {}

    // MARK: - Image

    func uploadImage(
        _ image: UIImage
    ) async throws -> Attachment {

        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw UploadError.imageEncodingFailed
        }

        let fileName = UUID().uuidString + ".jpg"

        let url = try save(
            data: data,
            fileName: fileName
        )

        return Attachment(
            type: .photo,
            fileName: fileName,
            localPath: url.path,
            size: Int64(data.count)
        )
    }

    // MARK: - Video

    func uploadVideo(
        from url: URL
    ) async throws -> Attachment {

        let data = try Data(contentsOf: url)

        let fileName = url.lastPathComponent

        let localURL = try save(
            data: data,
            fileName: fileName
        )

        return Attachment(
            type: .video,
            fileName: fileName,
            localPath: localURL.path,
            size: Int64(data.count)
        )
    }

    // MARK: - Document

    func uploadDocument(
        from url: URL
    ) async throws -> Attachment {

        let data = try Data(contentsOf: url)

        let localURL = try save(
            data: data,
            fileName: url.lastPathComponent
        )

        return Attachment(
            type: .document,
            fileName: url.lastPathComponent,
            localPath: localURL.path,
            size: Int64(data.count)
        )
    }

    // MARK: - Audio

    func uploadAudio(
        from url: URL
    ) async throws -> Attachment {

        let data = try Data(contentsOf: url)

        let localURL = try save(
            data: data,
            fileName: url.lastPathComponent
        )

        return Attachment(
            type: .audio,
            fileName: url.lastPathComponent,
            localPath: localURL.path,
            size: Int64(data.count)
        )
    }

    // MARK: - Save

    private func save(
        data: Data,
        fileName: String
    ) throws -> URL {

        let folder = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let url = folder.appendingPathComponent(fileName)

        try data.write(to: url)

        return url
    }
}

// MARK: - Error

enum UploadError: LocalizedError {

    case imageEncodingFailed

    var errorDescription: String? {

        switch self {

        case .imageEncodingFailed:
            return "Не удалось сохранить изображение."
        }
    }
}