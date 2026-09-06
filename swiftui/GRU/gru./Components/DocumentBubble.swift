import SwiftUI

struct DocumentBubble: View {
    let attachment: Attachment

    @State private var downloadedURL: URL?
    @State private var isDownloading = false
    @State private var downloadError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                fileIcon

                VStack(alignment: .leading, spacing: 4) {
                    Text(attachment.fileName.isEmpty ? "Документ" : attachment.fileName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(fileTypeLabel)
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(GRUColors.accent)

                        Circle()
                            .fill(Color.secondary.opacity(0.38))
                            .frame(width: 3, height: 3)

                        Text(fileSize)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                trailingAction
            }

            if let downloadError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text(downloadError)
                        .font(.caption2)
                        .lineLimit(2)
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(13)
        .frame(width: 286, alignment: .leading)
        .background(.ultraThinMaterial)
        .background(GRUColors.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(GRUColors.neonGradient, lineWidth: 1.0)
        }
        .shadow(color: GRUColors.accent.opacity(0.12), radius: 10, y: 4)
        .task(id: attachment.localPath) {
            if downloadedURL == nil, let localURL {
                downloadedURL = localURL
            }
        }
    }

    private var fileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(GRUColors.accent.opacity(0.10))
                .frame(width: 48, height: 48)

            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(GRUColors.neonGradient, lineWidth: 1)
                .frame(width: 48, height: 48)

            Image(systemName: fileSystemIcon)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(GRUColors.accent)
        }
        .shadow(color: GRUColors.accent.opacity(0.18), radius: 7)
    }

    @ViewBuilder
    private var trailingAction: some View {
        if let downloadedURL {
            ShareLink(item: downloadedURL) {
                actionIcon(systemName: "square.and.arrow.up", accessibilityLabel: "Поделиться документом")
            }
            .buttonStyle(.plain)
        } else if isDownloading {
            ZStack {
                Circle()
                    .fill(GRUColors.accent.opacity(0.08))
                    .frame(width: 40, height: 40)
                ProgressView()
                    .controlSize(.small)
                    .tint(GRUColors.accent)
            }
        } else {
            Button {
                Task { await download() }
            } label: {
                actionIcon(
                    systemName: downloadError == nil ? "arrow.down" : "arrow.clockwise",
                    accessibilityLabel: downloadError == nil ? "Скачать документ" : "Повторить загрузку"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func actionIcon(systemName: String, accessibilityLabel: String) -> some View {
        ZStack {
            Circle()
                .fill(GRUColors.accent.opacity(0.10))
                .frame(width: 40, height: 40)
            Circle()
                .stroke(GRUColors.accent.opacity(0.24), lineWidth: 1)
                .frame(width: 40, height: 40)
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(GRUColors.accent)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var fileSize: String {
        guard attachment.size > 0 else { return "файл" }
        return ByteCountFormatter.string(fromByteCount: attachment.size, countStyle: .file)
    }

    private var fileExtension: String {
        URL(fileURLWithPath: attachment.fileName).pathExtension.lowercased()
    }

    private var fileTypeLabel: String {
        fileExtension.isEmpty ? "FILE" : fileExtension.uppercased()
    }

    private var fileSystemIcon: String {
        switch fileExtension {
        case "pdf":
            return "doc.richtext.fill"
        case "zip", "rar", "7z":
            return "archivebox.fill"
        case "txt", "md", "rtf":
            return "doc.text.fill"
        case "doc", "docx", "pages":
            return "doc.fill"
        case "xls", "xlsx", "numbers", "csv":
            return "tablecells.fill"
        case "ppt", "pptx", "key":
            return "rectangle.on.rectangle.angled"
        default:
            return "doc.fill"
        }
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
