//
//  PhotoPickerSheet.swift
//  gru.
//
//  Created by Maria Morozova on 04.07.2026.
//


import SwiftUI
import PhotosUI

struct PhotoPickerSheet: View {

    @State private var selectedItem: PhotosPickerItem?

    var onImage: (UIImage) -> Void

    var body: some View {

        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {

            EmptyView()
        }
        .labelsHidden()

        .onChange(of: selectedItem) { _, newValue in

            guard let item = newValue else {
                return
            }

            Task {

                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {

                    onImage(image)
                }

                selectedItem = nil
            }
        }
    }
}
