import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct PickedVideo: Transferable {

    let url: URL

    static var transferRepresentation: some TransferRepresentation {

        FileRepresentation(
            contentType: .movie
        ) { video in

            SentTransferredFile(
                video.url
            )

        } importing: { received in

            let sourceURL =
                received.file

            let ext =
                sourceURL.pathExtension.isEmpty
                    ? "mov"
                    : sourceURL.pathExtension

            let destinationURL =
                FileManager.default
                    .temporaryDirectory
                    .appendingPathComponent(
                        UUID().uuidString
                    )
                    .appendingPathExtension(
                        ext
                    )

            try? FileManager.default
                .removeItem(
                    at: destinationURL
                )

            try FileManager.default
                .copyItem(
                    at: sourceURL,
                    to: destinationURL
                )

            return PickedVideo(
                url: destinationURL
            )
        }
    }
}
