//
//  FullScreenImageView.swift
//  gru.
//
//  Created by Maria Morozova on 04.07.2026.
//


import SwiftUI

struct FullScreenImageView: View {

    let image: UIImage

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {

        ZStack {

            Color.black
                .ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .gesture(

                    MagnificationGesture()

                        .onChanged { value in

                            scale = lastScale * value
                        }

                        .onEnded { _ in

                            lastScale = scale

                            if scale < 1 {

                                withAnimation {

                                    scale = 1
                                    lastScale = 1
                                }
                            }
                        }
                )

            VStack {

                HStack {

                    Spacer()

                    Button {

                        dismiss()

                    } label: {

                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                    }
                }

                .padding()

                Spacer()
            }
        }
    }
}

#Preview {

    if let image = UIImage(systemName: "photo") {

        FullScreenImageView(image: image)
    }
}