//
//  ChatImagePreview.swift
//  gru.
//
//  Created by Maria Morozova on 04.07.2026.
//


import SwiftUI

struct ChatImagePreview: View {

    let image: UIImage

    var onClose: () -> Void

    var body: some View {

        ZStack {

            Color.black
                .ignoresSafeArea()

            VStack {

                HStack {

                    Spacer()

                    Button {

                        onClose()

                    } label: {

                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.white)
                    }
                }

                .padding()

                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()

                Spacer()
            }
        }
    }
}