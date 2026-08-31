//
//  MediaService.swift
//  gru.
//
//  Created by Maria Morozova on 04.07.2026.
//


import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Combine

@MainActor
final class MediaService: ObservableObject {

    static let shared = MediaService()

    @Published var selectedImage: UIImage?
    @Published var selectedVideoURL: URL?
    @Published var selectedDocumentURL: URL?

    private init() { }

    // MARK: Photo

    func loadPhoto(from item: PhotosPickerItem?) async {

        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {

            selectedImage = nil
            return
        }

        selectedImage = image
    }

    func saveImage(_ image: UIImage) -> Attachment? {

        guard let data = image.jpegData(compressionQuality: 0.9) else {
            return nil
        }

        let name = UUID().uuidString + ".jpg"

        let url = FileManager.default
            .urls(for: .documentDirectory,
                  in: .userDomainMask)[0]
            .appendingPathComponent(name)

        do {

            try data.write(to: url)

            return Attachment(
                type: .photo,
                fileName: name,
                localPath: url.path,
                width: image.size.width,
                height: image.size.height,
                size: Int64(data.count)
            )

        } catch {

            print(error)

            return nil
        }
    }    // MARK: Reset

    func clear() {

        selectedImage = nil
        selectedVideoURL = nil
        selectedDocumentURL = nil
    }
}
