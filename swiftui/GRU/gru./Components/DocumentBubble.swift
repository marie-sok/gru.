import SwiftUI

struct DocumentBubble: View {
    let attachment: Attachment

    @State private var downloadedURL: URL?
    @State private var isDownloading = false
    @State private var downloadError: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundStyle(GRUColors.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.fileName)
                    .font(.headline)
                    .lineLimit(1)

                Text(fileSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            trailingAction
        }
        .padding()
        .frame(maxWidth: 280)
        .background(GRUColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(GRUColors.accent.opacity(0.12), lineWidth: 1)
        }
        .task(id: attachment.localPath) {
            if downloadedURL == nil, let localURL {
                downloadedURL = localURL
            }
        }
    }

    @ViewBuilder
    private var trailingAction: some View {
        if let downloadedURL {
            ShareLink(item: downloadedURL) {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .foregroundStyle(GRUColors.accent)
            }
            .buttonStyle(.plain)
        } else if isDownloading {
            ProgressView()
                .tint(GRUColors.accent)
        } else {
            Button {
                Task { await download() }
            } label: {
                Image(systemName: downloadError == nil ? "arrow.down.circle" : "arrow.clockwise.circle")
                    .font(.title3)
                    .foregroundStyle(downloadError == nil ? GRUColors.accent : Color.orange)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(downloadError == nil ? "Скачать документ" : "Повторить загрузку")
        }
    }

    private var fileSize: String {
        guard attachment.size > 0 else { return "Документ" }
        return ByteCountFormatter.string(fromByteCount: attachment.size, countStyle: .file)
    }

    private var localURL: URL? {
        guard
            let path = attachment.localPath,
            !path.isEmpty,
            FileManager.default.fileExists(atPath: path)
        else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    @MainActor
    private func download() async {
        if let localURL {
            downloadedURL = localURL
            return
        }

        guard
            let remotePath = attachment.remoteURL,
            !remotePath.isEmpty,
            let token = TokenStorage.shared.token,
            !token.isEmpty
        else {
            downloadError = "Файл недоступен"
            return
        }

        isDownloading = true
        downloadError = nil
        defer { isDownloading = false }

        do {
            let data = try await APIClient.shared.download(path: remotePath, token: token)
            let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("GRUDocuments", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let safeName = attachment.fileName.replacingOccurrences(of: "/", with: "_")
            let url = folder.appendingPathComponent("\(attachment.id.uuidString)-\(safeName)")
            try data.write(to: url, options: .atomic)
            downloadedURL = url
        } catch {
            downloadError = error.localizedDescription
            print("❌ Document download error:", error)
        }
    }
}

#Preview {
    DocumentBubble(
        attachment: Attachment(
            type: .document,
            fileName: "Contract.pdf",
            size: 1_420_000
        )
    )
}
