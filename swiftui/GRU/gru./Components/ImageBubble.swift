import SwiftUI

struct ImageBubble: View {

    let attachment: Attachment

    @State private var remoteImage: UIImage?

    @State private var isLoadingRemote = false

    @State private var showFullScreen = false

    var body: some View {

        Group {

            if let image = localImage ?? remoteImage {

                imageView(
                    image
                )

            } else {

                placeholder
            }
        }
        .task(
            id: attachment.remoteURL
        ) {

            await loadRemoteImageIfNeeded()
        }
    }

    // MARK: - Local Image

    private var localImage: UIImage? {

        guard let path =
                attachment.localPath,
              !path.isEmpty
        else {

            return nil
        }

        return UIImage(
            contentsOfFile: path
        )
    }

    // MARK: - Image

    private func imageView(
        _ image: UIImage
    ) -> some View {

        Image(
            uiImage: image
        )
        .resizable()
        .scaledToFill()
        .frame(
            width: 220,
            height: 220
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20
            )
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius: 20
            )
        )
        .onTapGesture {

            showFullScreen = true
        }
        .fullScreenCover(
            isPresented:
                $showFullScreen
        ) {

            FullScreenImageView(
                image: image
            )
        }
    }

    // MARK: - Placeholder

    private var placeholder: some View {

        RoundedRectangle(
            cornerRadius: 20
        )
        .fill(
            .gray.opacity(
                0.15
            )
        )
        .frame(
            width: 220,
            height: 220
        )
        .overlay {

            if isLoadingRemote {

                ProgressView()

            } else {

                Image(
                    systemName: "photo"
                )
                .font(
                    .largeTitle
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
    }

    // MARK: - Remote Image

    @MainActor
    private func loadRemoteImageIfNeeded() async {

        guard localImage == nil else {
            return
        }

        guard remoteImage == nil else {
            return
        }

        guard let remoteURL =
                attachment.remoteURL,
              !remoteURL.isEmpty
        else {
            return
        }

        guard let token =
                TokenStorage.shared.token,
              !token.isEmpty
        else {
            return
        }

        isLoadingRemote = true

        defer {
            isLoadingRemote = false
        }

        do {

            let data =
                try await APIClient.shared
                    .download(
                        path: remoteURL,
                        token: token
                    )

            guard let image =
                    UIImage(
                        data: data
                    )
            else {

                print(
                    "❌ Remote image decode failed"
                )

                return
            }

            remoteImage = image

            print("")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🖼 REMOTE PHOTO LOADED")
            print(
                "📎",
                attachment.fileName
            )
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        } catch {

            print(
                "❌ Remote image load error:",
                error
            )
        }
    }
}

#Preview {

    ImageBubble(
        attachment:
            Attachment(
                type: .photo,
                fileName:
                    "example.jpg"
            )
    )
}
