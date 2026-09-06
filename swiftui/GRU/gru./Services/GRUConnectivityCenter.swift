import Combine
import Foundation
import Network
import SwiftUI
import UIKit

enum GRUBackendState: Equatable {
    case checking
    case online(latencyMilliseconds: Int?)
    case degraded(reason: String)
    case offline(message: String)
}

final class GRUConnectivityCenter: ObservableObject, @unchecked Sendable {
    static let shared = GRUConnectivityCenter()

    @Published private(set) var hasNetwork = true
    @Published private(set) var interfaceName = "checking"
    @Published private(set) var backendState: GRUBackendState = .checking
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var lastHTTPStatus: Int?
    @Published private(set) var lastReadyStatus: Int?

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(
        label: "gru.connectivity.path-monitor",
        qos: .utility
    )

    private var heartbeatTask: Task<Void, Never>?
    private var isStarted = false
    private var refreshInFlight = false

    private init() {}

    deinit {
        monitor.cancel()
        heartbeatTask?.cancel()
    }

    @MainActor
    func start() {
        guard !isStarted else {
            refresh()
            return
        }

        isStarted = true

        monitor.pathUpdateHandler = { [weak self] path in
            let reachable = path.status == .satisfied
            let interfaceName: String

            if path.usesInterfaceType(.wifi) {
                interfaceName = "Wi‑Fi"
            } else if path.usesInterfaceType(.cellular) {
                interfaceName = "Cellular"
            } else if path.usesInterfaceType(.wiredEthernet) {
                interfaceName = "Ethernet"
            } else if path.usesInterfaceType(.loopback) {
                interfaceName = "Loopback"
            } else {
                interfaceName = reachable ? "Network" : "Offline"
            }

            Task { @MainActor [weak self] in
                self?.applyNetworkState(
                    reachable: reachable,
                    interfaceName: interfaceName
                )
            }
        }

        monitor.start(queue: monitorQueue)
        refresh()

        heartbeatTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                guard !Task.isCancelled, let self else { return }
                await self.refreshNow()
            }
        }
    }

    @MainActor
    func refresh() {
        Task { @MainActor [weak self] in
            await self?.refreshNow()
        }
    }

    @MainActor
    func refreshNow() async {
        guard !refreshInFlight else { return }

        guard hasNetwork else {
            backendState = .offline(message: "Нет подключения к интернету")
            return
        }

        refreshInFlight = true
        defer {
            refreshInFlight = false
            lastCheckedAt = Date()
        }

        backendState = .checking

        let health = await request(path: "/health")
        lastHTTPStatus = health.statusCode

        guard health.transportSucceeded else {
            backendState = .offline(
                message: health.message ?? "Сервис gru. недоступен"
            )
            return
        }

        guard health.statusCode == 200 else {
            backendState = .offline(
                message: "Backend HTTP \(health.statusCode ?? 0)"
            )
            return
        }

        let ready = await request(path: "/ready")
        lastReadyStatus = ready.statusCode

        if ready.statusCode == 200,
           let payload = ready.payload,
           payload.status == "ok",
           payload.database == "ok" {
            backendState = .online(
                latencyMilliseconds: ready.latencyMilliseconds
            )
            recoverRealtimeIfNeeded()
            return
        }

        let reason = ready.payload?.databaseReason
            ?? ready.payload?.database
            ?? ready.message
            ?? "backend_not_ready"

        backendState = .degraded(reason: reason)
    }

    @MainActor
    func reconnectRealtime() {
        guard hasNetwork,
              let token = TokenStorage.shared.token,
              !token.isEmpty else {
            return
        }

        let socket = WebSocketService.shared
        socket.disconnect()

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            socket.connect(token: token)
        }
    }

    var bannerTitle: String? {
        guard hasNetwork else { return GRUL10n.text("Нет сети") }

        switch backendState {
        case .checking, .online:
            return nil
        case .degraded:
            return GRUL10n.text("Сервис временно ограничен")
        case .offline:
            return GRUL10n.text("Нет связи с gru.")
        }
    }

    var bannerSubtitle: String? {
        guard hasNetwork else {
            return "Соединение восстановится автоматически"
        }

        switch backendState {
        case .checking, .online:
            return nil
        case .degraded(let reason):
            return userFacingReason(reason)
        case .offline(let message):
            return message
        }
    }

    var statusTitle: String {
        guard hasNetwork else { return "offline" }

        switch backendState {
        case .checking:
            return "checking"
        case .online:
            return "online"
        case .degraded:
            return "degraded"
        case .offline:
            return "offline"
        }
    }

    var statusDetail: String {
        if !hasNetwork {
            return "Нет подключения • \(interfaceName)"
        }

        switch backendState {
        case .checking:
            return GRUL10n.text("Проверяем production backend")
        case .online(let latency):
            if let latency {
                return "Backend + Mongo ready • \(latency) ms"
            }
            return GRUL10n.text("Backend + Mongo ready")
        case .degraded(let reason):
            return userFacingReason(reason)
        case .offline(let message):
            return message
        }
    }

    var statusColor: Color {
        guard hasNetwork else { return .orange }

        switch backendState {
        case .checking:
            return .secondary
        case .online:
            return GRUColors.accent
        case .degraded:
            return .orange
        case .offline:
            return .red
        }
    }

    @MainActor
    var diagnosticsText: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "?"

        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "?"

        let checked = lastCheckedAt?.formatted(
            date: .numeric,
            time: .standard
        ) ?? "not yet"

        return """
        gru. diagnostics
        version: \(version) (\(build))
        environment: \(GRUServerConfiguration.environmentTitle)
        network: \(hasNetwork ? "online" : "offline")
        interface: \(interfaceName)
        backend: \(statusTitle)
        backend detail: \(statusDetail)
        health HTTP: \(lastHTTPStatus.map(String.init) ?? "-")
        ready HTTP: \(lastReadyStatus.map(String.init) ?? "-")
        websocket: \(WebSocketService.shared.isConnected ? "connected" : "disconnected")
        HTTP base: \(GRUServerConfiguration.httpBaseURL)
        WSS: \(GRUServerConfiguration.webSocketURL)
        checked: \(checked)
        """
    }

    @MainActor
    private func applyNetworkState(
        reachable: Bool,
        interfaceName: String
    ) {
        let wasOffline = !hasNetwork

        hasNetwork = reachable
        self.interfaceName = interfaceName

        if !reachable {
            backendState = .offline(message: "Нет подключения к интернету")
            lastHTTPStatus = nil
            lastReadyStatus = nil
        } else if wasOffline {
            refresh()
        }
    }

    @MainActor
    private func recoverRealtimeIfNeeded() {
        guard let token = TokenStorage.shared.token,
              !token.isEmpty else {
            return
        }

        let socket = WebSocketService.shared

        guard !socket.isConnected,
              !socket.isReconnecting else {
            return
        }

        socket.connect(token: token)
    }

    private func userFacingReason(_ reason: String) -> String {
        switch reason.lowercased() {
        case "auth_failed":
            return GRUL10n.text("База данных отклонила авторизацию")
        case "dns":
            return "Backend не может найти адрес базы данных"
        case "timeout":
            return GRUL10n.text("Backend не дождался ответа базы данных")
        case "network":
            return GRUL10n.text("Backend не может подключиться к базе данных")
        case "interrupted":
            return GRUL10n.text("Проверка backend была прервана")
        case "unknown", "unavailable":
            return GRUL10n.text("Backend доступен, база данных пока недоступна")
        default:
            return reason
        }
    }

    private struct ReadyPayload: Decodable {
        let status: String?
        let database: String?
        let databaseReason: String?
    }

    private struct EndpointResult {
        let transportSucceeded: Bool
        let statusCode: Int?
        let latencyMilliseconds: Int?
        let payload: ReadyPayload?
        let message: String?
    }

    private func request(path: String) async -> EndpointResult {
        guard let url = URL(
            string: GRUServerConfiguration.httpBaseURL + path
        ) else {
            return EndpointResult(
                transportSucceeded: false,
                statusCode: nil,
                latencyMilliseconds: nil,
                payload: nil,
                message: "Некорректный backend URL"
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let startedAt = Date()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                return EndpointResult(
                    transportSucceeded: false,
                    statusCode: nil,
                    latencyMilliseconds: nil,
                    payload: nil,
                    message: "Некорректный ответ backend"
                )
            }

            let latency = Int(
                Date().timeIntervalSince(startedAt) * 1_000
            )

            let payload = try? JSONDecoder().decode(
                ReadyPayload.self,
                from: data
            )

            return EndpointResult(
                transportSucceeded: true,
                statusCode: http.statusCode,
                latencyMilliseconds: latency,
                payload: payload,
                message: nil
            )
        } catch {
            let message: String

            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    message = "Нет подключения к интернету"
                case .timedOut:
                    message = "Backend не ответил вовремя"
                case .cannotFindHost, .dnsLookupFailed:
                    message = "Не удалось найти backend"
                default:
                    message = urlError.localizedDescription
                }
            } else {
                message = error.localizedDescription
            }

            return EndpointResult(
                transportSucceeded: false,
                statusCode: nil,
                latencyMilliseconds: nil,
                payload: nil,
                message: message
            )
        }
    }
}

@MainActor
struct GRUConnectionBanner: View {
    @ObservedObject var center: GRUConnectivityCenter
    let onOpenDiagnostics: () -> Void

    var body: some View {
        if let title = center.bannerTitle {
            Button(action: onOpenDiagnostics) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(center.statusColor.opacity(0.16))

                        Image(
                            systemName: center.hasNetwork
                                ? "server.rack"
                                : "wifi.slash"
                        )
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(center.statusColor)
                    }
                    .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(GRUColors.text)

                        if let subtitle = center.bannerSubtitle {
                            Text(subtitle)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 50)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(center.statusColor.opacity(0.28), lineWidth: 1)
                }
                .shadow(
                    color: center.statusColor.opacity(0.12),
                    radius: 14,
                    y: 5
                )
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel(
                "\(title). \(center.bannerSubtitle ?? "")"
            )
        }
    }
}

@MainActor
struct GRUConnectivityDiagnosticsView: View {
    @ObservedObject var center: GRUConnectivityCenter
    @State private var copied = false

    private var version: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "?"
    }

    private var build: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "?"
    }

    var body: some View {
        Form {
            Section("Статус") {
                HStack {
                    Label(center.statusTitle, systemImage: statusIcon)
                        .foregroundStyle(center.statusColor)

                    Spacer()

                    Circle()
                        .fill(center.statusColor)
                        .frame(width: 8, height: 8)
                }

                Text(center.statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent(
                    "Сеть",
                    value: center.hasNetwork
                        ? center.interfaceName
                        : "offline"
                )

                LabeledContent(
                    "Realtime",
                    value: WebSocketService.shared.isConnected
                        ? "connected"
                        : "disconnected"
                )
            }

            Section("Production") {
                LabeledContent(
                    "Среда",
                    value: GRUServerConfiguration.environmentTitle
                )

                LabeledContent(
                    "HTTP",
                    value: GRUServerConfiguration.httpBaseURL
                )
                .font(.caption)

                LabeledContent(
                    "WebSocket",
                    value: GRUServerConfiguration.webSocketURL
                )
                .font(.caption)

                LabeledContent(
                    "/health",
                    value: center.lastHTTPStatus.map(String.init) ?? "—"
                )

                LabeledContent(
                    "/ready",
                    value: center.lastReadyStatus.map(String.init) ?? "—"
                )
            }

            Section("Build") {
                LabeledContent("Версия", value: version)
                LabeledContent("Build", value: build)
                LabeledContent(
                    "Production transport",
                    value: GRUServerConfiguration.isProductionTransportConfigured
                        ? "configured"
                        : "missing"
                )
            }

            Section {
                Button {
                    center.refresh()
                } label: {
                    Label("Проверить сейчас", systemImage: "arrow.clockwise")
                }

                Button {
                    center.reconnectRealtime()
                } label: {
                    Label(
                        "Переподключить realtime",
                        systemImage: "bolt.horizontal.circle"
                    )
                }

                Button {
                    UIPasteboard.general.string = center.diagnosticsText
                    copied = true
                } label: {
                    Label(
                        copied
                            ? "Диагностика скопирована"
                            : "Скопировать диагностику",
                        systemImage: copied
                            ? "checkmark.circle.fill"
                            : "doc.on.doc"
                    )
                }
            } footer: {
                Text("JWT, пароли и MONGODB_URI сюда не попадают.")
            }
        }
        .navigationTitle("Диагностика")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            center.start()
            await center.refreshNow()
        }
    }

    private var statusIcon: String {
        if !center.hasNetwork {
            return "wifi.slash"
        }

        switch center.backendState {
        case .checking:
            return "hourglass"
        case .online:
            return "checkmark.circle.fill"
        case .degraded:
            return "exclamationmark.triangle.fill"
        case .offline:
            return "xmark.circle.fill"
        }
    }
}
