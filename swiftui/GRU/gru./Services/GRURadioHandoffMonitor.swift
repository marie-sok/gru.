import Foundation
import Network

/// Detects live radio changes that do not pass through an offline NWPath state.
/// A Wi-Fi -> cellular handoff can remain `.satisfied`, while the existing
/// URLSessionWebSocketTask is bound to the old route. In that case GRU creates
/// a fresh authenticated STOMP session and refreshes backend readiness.
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
        guard path.status == .satisfied else { return }

        let current: Interface
        if path.usesInterfaceType(.wifi) {
            current = .wifi
        } else if path.usesInterfaceType(.cellular) {
            current = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            current = .wired
        } else {
            current = .other
        }

        lock.lock()
        let previous = previousInterface
        previousInterface = current
        lock.unlock()

        guard let previous, previous != current else { return }

        Task { @MainActor in
            GRUConnectivityCenter.shared.refresh()

            // Only authenticated sessions own realtime state. The method also
            // validates token presence before reconnecting.
            GRUConnectivityCenter.shared.reconnectRealtime()

            #if DEBUG
            print("🌐 GRU route handoff: \(previous.rawValue) -> \(current.rawValue)")
            #endif
        }
    }
}
