import Foundation
import Network

/// Detects live radio changes and offline -> online recovery.
/// A Wi-Fi -> cellular handoff can remain `.satisfied`, while the existing
/// URLSessionWebSocketTask is bound to the old route. Likewise, restoring the
/// same radio after Airplane Mode may not change interface type. In both cases
/// GRU refreshes backend readiness and creates a fresh authenticated STOMP session.
final class GRURadioHandoffMonitor: @unchecked Sendable {
    static let shared = GRURadioHandoffMonitor()

    private enum Interface: String, Equatable {
        case wifi
        case cellular
        case wired
        case other
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "gru.network.radio-handoff", qos: .utility)
    private let lock = NSLock()
    private var started = false
    private var previousInterface: Interface?
    private var previousWasReachable: Bool?

    private init() {}

    func start() {
        lock.lock()
        guard !started else {
            lock.unlock()
            return
        }
        started = true
        lock.unlock()

        monitor.pathUpdateHandler = { [weak self] path in
            self?.consume(path)
        }
        monitor.start(queue: queue)
    }

    private func consume(_ path: NWPath) {
        let reachable = path.status == .satisfied
        let current: Interface?

        if reachable {
            if path.usesInterfaceType(.wifi) {
                current = .wifi
            } else if path.usesInterfaceType(.cellular) {
                current = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                current = .wired
            } else {
                current = .other
            }
        } else {
            current = nil
        }

        lock.lock()
        let previousInterface = self.previousInterface
        let previousWasReachable = self.previousWasReachable
        self.previousWasReachable = reachable
        if let current {
            self.previousInterface = current
        }
        lock.unlock()

        guard reachable else { return }

        let restoredAfterOffline = previousWasReachable == false
        let changedInterface = previousInterface != nil && previousInterface != current

        // The first satisfied path after app launch does not need a forced
        // reconnect: normal startup owns the initial REST/WebSocket connection.
        guard restoredAfterOffline || changedInterface else { return }

        Task { @MainActor in
            GRUConnectivityCenter.shared.refresh()
            GRUConnectivityCenter.shared.reconnectRealtime()

            #if DEBUG
            if restoredAfterOffline {
                print("🌐 GRU network restored on \(current?.rawValue ?? "unknown")")
            } else if let previousInterface, let current {
                print("🌐 GRU route handoff: \(previousInterface.rawValue) -> \(current.rawValue)")
            }
            #endif
        }
    }
}
