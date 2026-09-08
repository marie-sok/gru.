import Foundation
import UIKit
import CryptoKit

/// Two-level media cache. Persistent media is encrypted with the same
/// device-bound protection layer as chat/message cache data.
final class MediaCacheService {

    static let shared = MediaCacheService()

    private let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 150
        cache.totalCostLimit = 60 * 1024 * 1024
        return cache
    }()

    private let diskQueue = DispatchQueue(label: "sok.com.gru.mediacache.disk", qos: .utility)
    private let fileManager = FileManager.default
    private let protector = GRUDataProtection.shared

    private lazy var diskCacheDirectory: URL = {
        let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GRUMediaCache", isDirectory: true)

        if !fileManager.fileExists(atPath: cacheURL.path) {
            try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
        return cacheURL
    }()

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
    }

    func image(for key: String) -> UIImage? {
        guard !key.isEmpty else { return nil }
        let cacheKey = hashKey(key) as NSString

        if let memoryImage = memoryCache.object(forKey: cacheKey) {
            return memoryImage
        }

        let fileURL = diskCacheDirectory.appendingPathComponent(cacheKey as String)
        guard fileManager.fileExists(atPath: fileURL.path),
              let stored = try? Data(contentsOf: fileURL),
              let diskData = try? protector.open(stored),
              let diskImage = UIImage(data: diskData)
        else {
            return nil
        }

        memoryCache.setObject(diskImage, forKey: cacheKey, cost: diskData.count)

        if !stored.starts(with: Data("GRUENC1".utf8)) {
            store(data: diskData, for: key)
        }
        return diskImage
    }

    func store(_ image: UIImage, for key: String) {
        guard !key.isEmpty else { return }
        let cacheKey = hashKey(key) as NSString
        memoryCache.setObject(image, forKey: cacheKey)

        diskQueue.async { [weak self] in
            guard let self,
                  let data = image.jpegData(compressionQuality: 0.85)
            else { return }
            self.writeProtected(data, cacheKey: cacheKey as String)
        }
    }

    func store(data: Data, for key: String) {
        guard !key.isEmpty, !data.isEmpty else { return }
        let cacheKey = hashKey(key) as NSString

        if let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: cacheKey, cost: data.count)
        }

        diskQueue.async { [weak self] in
            self?.writeProtected(data, cacheKey: cacheKey as String)
        }
    }

    func data(for key: String) -> Data? {
        guard !key.isEmpty else { return nil }
        let cacheKey = hashKey(key)
        let fileURL = diskCacheDirectory.appendingPathComponent(cacheKey)
        guard fileManager.fileExists(atPath: fileURL.path),
              let stored = try? Data(contentsOf: fileURL),
              let plaintext = try? protector.open(stored)
        else { return nil }

        if !stored.starts(with: Data("GRUENC1".utf8)) {
            store(data: plaintext, for: key)
        }
        return plaintext
    }

    func clear() {
        memoryCache.removeAllObjects()
        diskQueue.async { [weak self] in
            guard let self else { return }
            try? self.fileManager.removeItem(at: self.diskCacheDirectory)
            try? self.fileManager.createDirectory(
                at: self.diskCacheDirectory,
                withIntermediateDirectories: true
            )
        }
    }

    private func writeProtected(_ data: Data, cacheKey: String) {
        do {
            let encrypted = try protector.seal(data)
            let fileURL = diskCacheDirectory.appendingPathComponent(cacheKey)
            try encrypted.write(
                to: fileURL,
                options: [.atomic, .completeFileProtection]
            )
        } catch {
            print("⚠️ Protected media cache save failed:", error.localizedDescription)
        }
    }

    private func hashKey(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
