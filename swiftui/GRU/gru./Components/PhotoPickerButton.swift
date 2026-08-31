//
//  PhotoPickerButton.swift
//  gru.
//
//  Created by Maria Morozova on 04.07.2026.
//


import SwiftUI
import PhotosUI

struct PhotoPickerButton: View {

    @State private var item: PhotosPickerItem?

    @ObservedObject
    private var media = MediaService.shared

    var body: some View {

        PhotosPicker(
            selection: $item,
            matching: .images
        ) {

            Label("Фото", systemImage: "photo")
        }
        .onChange(of: item) { _, newItem in

            Task {

                await media.loadPhoto(from: newItem)
            }
        }
    }
}
