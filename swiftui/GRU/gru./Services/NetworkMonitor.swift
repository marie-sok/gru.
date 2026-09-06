import Foundation
import Network
import Observation

/// Сервис мониторинга доступности сети в реальном времени на базе NWPathMonitor.
/// Автоматически восстанавливает соединение с WebSocket и синхронизирует чаты при появлении связи.
@MainActor
@Observable
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "sok.com.gru.network.monitor", qos: .utility)

    var isConnected: Bool = true
    var isExpensive: Bool = false
    var connectionType: ConnectionType = .wifi

    enum ConnectionType: String {
        case wifi = "Wi-Fi"
        case cellular = "Сотовая сеть"
        case ethernet = "Ethernet"
        case unknown = "Неизвестно"
    }

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let previousState = self.isConnected
                let isNowConnected = (path.status == .satisfied)

                self.isConnected = isNowConnected
                self.isExpensive = path.isExpensive

                if path.usesInterfaceType(.wifi) {
                    self.connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    self.connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    self.connectionType = .ethernet
                } else {
                    self.connectionType = .unknown
                }

                // Автоматическое восстановление соединения при возвращении интернета
                if !previousState && isNowConnected {
                    print("🌐 Network connection restored (\(self.connectionType.rawValue)) -> Reconnecting")
                    if let token = TokenStorage.shared.token,
                       !token.isEmpty {
                        WebSocketService.shared.connect(token: token)
                    }
                    Task {
                        await ChatService.shared.loadChats()
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
