import Foundation
import UIKit
import CryptoKit

/// Двухуровневый сервис кэширования медиа-ресурсов (RAM + Диск).
/// Предотвращает повторные скачивания картинок при скролле и ускоряет работу интерфейса.
final class MediaCacheService {

    static let shared = MediaCacheService()

    // MARK: - Level 1: In-Memory Cache (RAM)
    private let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 150 // Хранить до 150 изображений в RAM
        cache.totalCostLimit = 60 * 1024 * 1024 // До 60 МБ
        return cache
    }()

    // MARK: - Level 2: Persistent Disk Cache
    private let diskQueue = DispatchQueue(label: "sok.com.gru.mediacache.disk", qos: .utility)
    private let fileManager = FileManager.default

    private lazy var diskCacheDirectory: URL = {
        let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GRUMediaCache", isDirectory: true)

        if !fileManager.fileExists(atPath: cacheURL.path) {
            try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
        return cacheURL
    }()

    private init() {
        // Очистка памяти при системном Memory Warning
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

    // MARK: - Public API: Images

    /// Возвращает изображение из кэша (сначала RAM, затем Диск).
    func image(for key: String) -> UIImage? {
        guard !key.isEmpty else { return nil }
        let cacheKey = hashKey(key) as NSString

        // 1. Проверяем оперативную память (Level 1)
        if let memoryImage = memoryCache.object(forKey: cacheKey) {
            return memoryImage
        }

        // 2. Проверяем локальный диск (Level 2)
        let fileURL = diskCacheDirectory.appendingPathComponent(cacheKey as String)
        guard fileManager.fileExists(atPath: fileURL.path),
              let diskData = try? Data(contentsOf: fileURL),
              let diskImage = UIImage(data: diskData)
        else {
            return nil
        }

        // Кладем найденное с диска изображение обратно в память для быстрого доступа
        let cost = diskData.count
        memoryCache.setObject(diskImage, forKey: cacheKey, cost: cost)

        return diskImage
    }

    /// Сохраняет изображение в память и асинхронно на диск.
    func store(_ image: UIImage, for key: String) {
        guard !key.isEmpty else { return }
        let cacheKey = hashKey(key) as NSString

        // Сохраняем в RAM
        memoryCache.setObject(image, forKey: cacheKey)

        // Асинхронно сохраняем на диск в фоновом потоке
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            guard let data = image.jpegData(compressionQuality: 0.85) else { return }
            let fileURL = self.diskCacheDirectory.appendingPathComponent(cacheKey as String)
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    /// Сохраняет Data на диск и декодированное изображение в RAM.
    func store(data: Data, for key: String) {
        guard !key.isEmpty, !data.isEmpty else { return }
        let cacheKey = hashKey(key) as NSString

        if let image = UIImage(data: data) {
            memoryCache.setObject(image, forKey: cacheKey, cost: data.count)
        }

        diskQueue.async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.diskCacheDirectory.appendingPathComponent(cacheKey as String)
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    /// Возвращает Data из дискового кэша.
    func data(for key: String) -> Data? {
        guard !key.isEmpty else { return nil }
        let cacheKey = hashKey(key)
        let fileURL = diskCacheDirectory.appendingPathComponent(cacheKey)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    // MARK: - Clear

    func clear() {
        memoryCache.removeAllObjects()
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.diskCacheDirectory)
            try? self.fileManager.createDirectory(at: self.diskCacheDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Key Hashing

    private func hashKey(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
