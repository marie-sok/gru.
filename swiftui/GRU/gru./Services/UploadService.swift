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

        // Интеллектуальная оптимизация и сжатие перед отправкой
        guard let data = optimizeImage(image) else {
            throw UploadError.imageEncodingFailed
        }

        let fileName = UUID().uuidString + ".jpg"

        let url = try save(
            data: data,
            fileName: fileName
        )

        // Сразу сохраняем в MediaCacheService для мгновенного отображения
        if let optimizedImage = UIImage(data: data) {
            MediaCacheService.shared.store(optimizedImage, for: fileName)
        }

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
        let localURL = try save(data: data, fileName: fileName)

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
        let localURL = try save(data: data, fileName: url.lastPathComponent)

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
        let localURL = try save(data: data, fileName: url.lastPathComponent)

        return Attachment(
            type: .audio,
            fileName: url.lastPathComponent,
            localPath: localURL.path,
            size: Int64(data.count)
        )
    }

    // MARK: - Image Optimization & Downscaling

    /// Оптимизирует фото перед отправкой: уменьшает сторону до 2048px и жмёт до ~250–350 КБ.
    private func optimizeImage(_ image: UIImage, maxDimension: CGFloat = 2048) -> Data? {
        let size = image.size
        var targetSize = size

        if size.width > maxDimension || size.height > maxDimension {
            let ratio = size.width / size.height
            if ratio > 1 {
                targetSize = CGSize(width: maxDimension, height: maxDimension / ratio)
            } else {
                targetSize = CGSize(width: maxDimension * ratio, height: maxDimension)
            }
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        // 0.75 - оптимальный баланс между чётким качеством на дисплеях Retina и лёгким весом файла
        return resizedImage.jpegData(compressionQuality: 0.75)
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
            return "Не удалось оптимизировать изображение."
        }
    }
}
