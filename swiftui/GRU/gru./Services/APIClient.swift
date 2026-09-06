import Foundation

// MARK: - Backend Configuration

enum GRUServerConfiguration {

    static let defaultPort = 8081

    private static let customHostKey = "gru.server.customHost.v11"
    private static let customPortKey = "gru.server.customPort.v1"
    private static let productionHTTPKey = "GRUProductionHTTPBaseURL"
    private static let productionWebSocketKey = "GRUProductionWebSocketURL"

    // Current development Mac on the local Wi-Fi network.
    private static let physicalDeviceHost = "192.168.31.88"

    static var port: Int {
        let configured = UserDefaults.standard.integer(forKey: customPortKey)
        return (1...65_535).contains(configured) ? configured : defaultPort
    }

    private static var productionHTTPBaseURL: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: productionHTTPKey) as? String else {
            return nil
        }

        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.lowercased().hasPrefix("https://"),
              URL(string: clean) != nil else {
            return nil
        }

        return clean.hasSuffix("/") ? String(clean.dropLast()) : clean
    }

    private static var productionWebSocketURL: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: productionWebSocketKey) as? String else {
            return nil
        }

        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.lowercased().hasPrefix("wss://"),
              URL(string: clean) != nil else {
            return nil
        }

        return clean
    }

    static var host: String {
        #if !DEBUG
        if let productionHTTPBaseURL,
           let productionHost = URL(string: productionHTTPBaseURL)?.host {
            return productionHost
        }
        #endif

        if let customHost = UserDefaults.standard.string(forKey: customHostKey),
           isValidHost(customHost) {
            return normalizedHost(customHost)
        }

        #if targetEnvironment(simulator)
        return "127.0.0.1"
        #else
        return physicalDeviceHost
        #endif
    }

    static var httpBaseURL: String {
        #if !DEBUG
        if let productionHTTPBaseURL {
            return productionHTTPBaseURL
        }
        #endif

        return "http://\(host):\(port)"
    }

    static var webSocketURL: String {
        #if !DEBUG
        if let productionWebSocketURL {
            return productionWebSocketURL
        }
        #endif

        return "ws://\(host):\(port)/ws"
    }

    static var automaticHost: String {
        #if !DEBUG
        if let productionHTTPBaseURL,
           let productionHost = URL(string: productionHTTPBaseURL)?.host {
            return productionHost
        }
        #endif

        #if targetEnvironment(simulator)
        return "127.0.0.1"
        #else
        return physicalDeviceHost
        #endif
    }

    static var environmentTitle: String {
        #if !DEBUG
        return productionHTTPBaseURL == nil
            ? "Release • production URL not configured"
            : "Production"
        #elseif targetEnvironment(simulator)
        return "iPhone Simulator"
        #else
        return "Физический iPhone"
        #endif
    }

    static var isUsingCustomHost: Bool {
        #if !DEBUG
        return false
        #else
        return host != automaticHost
        #endif
    }

    static var isUsingCustomPort: Bool {
        #if !DEBUG
        return false
        #else
        return port != defaultPort
        #endif
    }

    static var isProductionTransportConfigured: Bool {
        productionHTTPBaseURL != nil && productionWebSocketURL != nil
    }

    @discardableResult
    static func setCustomHost(_ value: String) -> Bool {
        #if !DEBUG
        return false
        #else
        let clean = normalizedHost(value)
        guard isValidHost(clean) else { return false }
        UserDefaults.standard.set(clean, forKey: customHostKey)
        return true
        #endif
    }

    @discardableResult
    static func setCustomPort(_ value: String) -> Bool {
        #if !DEBUG
        return false
        #else
        guard let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...65_535).contains(parsed) else {
            return false
        }

        UserDefaults.standard.set(parsed, forKey: customPortKey)
        return true
        #endif
    }

    static func resetToAutomaticHost() {
        #if DEBUG
        UserDefaults.standard.removeObject(forKey: customHostKey)
        UserDefaults.standard.removeObject(forKey: customPortKey)
        #endif
    }

    private static func normalizedHost(_ value: String) -> String {
        var clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: clean),
           let urlHost = url.host {
            clean = urlHost
        }

        if clean.hasSuffix("/") {
            clean.removeLast()
        }

        if let colonIndex = clean.lastIndex(of: ":"),
           clean[colonIndex...].dropFirst().allSatisfy({ $0.isNumber }) {
            clean = String(clean[..<colonIndex])
        }

        return clean
    }

    private static func isValidHost(_ value: String) -> Bool {
        let clean = normalizedHost(value)

        guard !clean.isEmpty,
              clean.count <= 253,
              !clean.contains("/"),
              !clean.contains(" ") else {
            return false
        }

        return clean.allSatisfy {
            $0.isLetter ||
            $0.isNumber ||
            $0 == "." ||
            $0 == "-" ||
            $0 == ":"
        }
    }
}

// MARK: - Probe

struct GRUServerProbeResult {
    let isReachable: Bool
    let statusCode: Int?
    let latencyMilliseconds: Int?
    let message: String
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case httpError(Int, String)
    case network(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return GRUL10n.text("Некорректный адрес сервера")
        case .invalidResponse:
            return GRUL10n.text("Некорректный ответ сервера")
        case .unauthorized:
            return GRUL10n.text("Сессия истекла. Войдите снова")
        case .forbidden:
            return GRUL10n.text("Доступ запрещён")
        case .notFound:
            return GRUL10n.text("Запрашиваемые данные не найдены")
        case .serverError(let code):
            return "Ошибка сервера: \(code)"
        case .httpError(let code, let message):
            return message.isEmpty ? "HTTP ошибка: \(code)" : message
        case .network(let error):
            guard let urlError = error as? URLError else {
                return "Ошибка сети: \(error.localizedDescription)"
            }

            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost:
                return "Сервер GRU недоступен по адресу \(GRUServerConfiguration.httpBaseURL). Запустите backend на порту \(GRUServerConfiguration.port)"
            case .notConnectedToInternet:
                return "Нет доступа к сети. Для iPhone также проверьте разрешение «Локальная сеть» у GRU"
            case .timedOut:
                return "Сервер GRU не ответил вовремя. Проверьте backend и адрес \(GRUServerConfiguration.host)"
            default:
                return "Ошибка сети: \(urlError.localizedDescription)"
            }
        }
    }
}

// MARK: - API Client

final class APIClient {

    static let shared = APIClient()

    private init() {}

    private var baseURL: String {
        GRUServerConfiguration.httpBaseURL
    }

    // MARK: Server probe

    func probeServer(
        token: String? = nil
    ) async -> GRUServerProbeResult {
        let resolvedToken: String?

        if let token {
            resolvedToken = token
        } else {
            resolvedToken = await MainActor.run {
                TokenStorage.shared.token
            }
        }

        // With a token we deliberately probe a protected endpoint so a 2xx
        // means "this exact JWT is accepted", not merely "the server is up".
        let path = resolvedToken == nil ? "/actuator/health" : "/chats"

        guard let url = URL(string: baseURL + path) else {
            return GRUServerProbeResult(
                isReachable: false,
                statusCode: nil,
                latencyMilliseconds: nil,
                message: "Некорректный адрес backend"
            )
        }

        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyAuthorization(resolvedToken, to: &request)

        let startedAt = Date()

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                return GRUServerProbeResult(
                    isReachable: false,
                    statusCode: nil,
                    latencyMilliseconds: nil,
                    message: "Backend ответил в неизвестном формате"
                )
            }

            let latency = Int(Date().timeIntervalSince(startedAt) * 1_000)
            let message: String

            switch http.statusCode {
            case 200...299:
                message = resolvedToken == nil
                    ? "Backend GRU доступен"
                    : "Сессия подтверждена backend"
            case 401, 403:
                message = "Backend доступен, но JWT отклонён"
            default:
                message = "Backend доступен, HTTP \(http.statusCode)"
            }

            return GRUServerProbeResult(
                isReachable: true,
                statusCode: http.statusCode,
                latencyMilliseconds: latency,
                message: message
            )
        } catch {
            let description = (error as? URLError)?.localizedDescription
                ?? error.localizedDescription

            return GRUServerProbeResult(
                isReachable: false,
                statusCode: nil,
                latencyMilliseconds: nil,
                message: "Нет соединения: \(description)"
            )
        }
    }

    // MARK: Standard JSON request

    func request(
        path: String,
        method: String = "GET",
        token: String? = nil,
        body: Data? = nil
    ) async throws -> Data {
        let url = try makeURL(path: path)

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        applyAuthorization(token, to: &request)
        request.httpBody = body

        #if DEBUG
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🌐 \(method) \(url.absoluteString)")
        if token != nil { print("🔐 Authorization: Bearer ***") }
        if let body { print("📤 BODY:", debugJSONDescription(body)) }
        #endif

        return try await perform(
            request,
            printResponseBody: true
        )
    }

    // MARK: Multipart upload

    func uploadMultipart(
        path: String,
        token: String,
        fields: [String: String],
        fileFieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data
    ) async throws -> Data {
        let url = try makeURL(path: path)
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        for key in fields.keys.sorted() {
            guard let value = fields[key] else { continue }
            body.appendMultipartString("--\(boundary)\r\n")
            body.appendMultipartString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.appendMultipartString("\(value)\r\n")
        }

        body.appendMultipartString("--\(boundary)\r\n")
        body.appendMultipartString("Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n")
        body.appendMultipartString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendMultipartString("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        applyAuthorization(token, to: &request)
        request.httpBody = body

        #if DEBUG
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🌐 POST \(url.absoluteString)")
        print("🔐 Authorization: Bearer ***")
        print("📤 MULTIPART FIELDS:", fields)
        print("📎 FILE:", fileName, "(\(fileData.count) bytes)")
        #endif

        return try await perform(
            request,
            printResponseBody: true
        )
    }

    // MARK: Authenticated download

    func download(
        path: String,
        token: String
    ) async throws -> Data {
        let url = try makeURL(path: path)

        var request = URLRequest(url: url, timeoutInterval: 60)
        request.httpMethod = "GET"
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        applyAuthorization(token, to: &request)

        #if DEBUG
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🖼 GET MEDIA \(url.absoluteString)")
        print("🔐 Authorization: Bearer ***")
        #endif

        return try await perform(
            request,
            printResponseBody: false
        )
    }

    // MARK: Transport

    private func perform(
        _ request: URLRequest,
        printResponseBody: Bool
    ) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            #if DEBUG
            print("📥 STATUS:", http.statusCode)
            if printResponseBody, !data.isEmpty {
                print("📥 RESPONSE:", debugJSONDescription(data))
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            #endif

            if 200...299 ~= http.statusCode {
                return data
            }

            let serverMessage = extractServerMessage(from: data)

            if shouldInvalidateSession(
                statusCode: http.statusCode,
                serverMessage: serverMessage,
                request: request
            ) {
                await invalidateCurrentSession(
                    statusCode: http.statusCode,
                    request: request
                )
            }

            switch http.statusCode {
            case 401:
                throw APIError.unauthorized
            case 403:
                let hasSession = await MainActor.run {
                    TokenStorage.shared.token != nil
                }
                throw hasSession ? APIError.forbidden : APIError.unauthorized
            case 404:
                throw APIError.notFound
            case 500...599:
                if !serverMessage.isEmpty {
                    throw APIError.httpError(http.statusCode, serverMessage)
                }
                throw APIError.serverError(http.statusCode)
            default:
                throw APIError.httpError(http.statusCode, serverMessage)
            }
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.network(error)
        }
    }

    // MARK: Race-safe session invalidation

    private func shouldInvalidateSession(
        statusCode: Int,
        serverMessage: String,
        request: URLRequest
    ) -> Bool {
        guard bearerToken(from: request) != nil else {
            return false
        }

        if statusCode == 401 {
            return true
        }

        guard statusCode == 403 else {
            return false
        }

        let normalized = serverMessage
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let path = request.url?.path ?? ""

        if path == "/chats" {
            return true
        }

        return normalized == "unauthorized" ||
            normalized.contains("jwt") ||
            normalized.contains("token expired") ||
            normalized.contains("token is expired") ||
            normalized.contains("expired token") ||
            normalized.contains("invalid token")
    }

    private func invalidateCurrentSession(
        statusCode: Int,
        request: URLRequest
    ) async {
        guard let failedToken = bearerToken(from: request) else {
            return
        }

        let didInvalidate = await MainActor.run { () -> Bool in
            guard let currentToken = TokenStorage.shared.token,
                  currentToken == failedToken else {
                // Critical race fix: an old request is allowed to fail, but it
                // must never erase a newer JWT saved after that request began.
                return false
            }

            CacheStorage.shared.clearCurrentUser()
            WebSocketService.shared.resetSession()
            TokenStorage.shared.clear()
            ChatService.shared.clearAuthenticatedUser()
            NotificationService.shared.removeAllNotifications()
            NotificationService.shared.clearBadge()

            NotificationCenter.default.post(
                name: .gruSessionInvalidated,
                object: nil
            )

            return true
        }

        #if DEBUG
        if didInvalidate {
            print("🔐 GRU current session invalidated due to HTTP \(statusCode)")
        } else {
            print("🛡 Ignored stale HTTP \(statusCode): request JWT is not the current session")
        }
        #endif
    }

    private func bearerToken(
        from request: URLRequest
    ) -> String? {
        guard let header = request.value(forHTTPHeaderField: "Authorization"),
              header.hasPrefix("Bearer ") else {
            return nil
        }

        let token = String(header.dropFirst("Bearer ".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return token.isEmpty ? nil : token
    }

    // MARK: URL / Auth

    private func makeURL(
        path: String
    ) throws -> URL {
        if let absolute = URL(string: path),
           absolute.scheme != nil {
            return absolute
        }

        let normalizedPath = path.hasPrefix("/") ? path : "/" + path

        guard let url = URL(string: baseURL + normalizedPath) else {
            throw APIError.invalidURL
        }

        return url
    }

    private func applyAuthorization(
        _ token: String?,
        to request: inout URLRequest
    ) {
        guard let token,
              !token.isEmpty else {
            return
        }

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )
    }

    // MARK: Response / debug helpers

    private func extractServerMessage(
        from data: Data
    ) -> String {
        guard !data.isEmpty else { return "" }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = json["message"] as? String,
               !message.isEmpty {
                return message
            }

            if let error = json["error"] as? String,
               !error.isEmpty {
                return error
            }
        }

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
    }

    private func debugJSONDescription(
        _ data: Data
    ) -> String {
        guard var object = try? JSONSerialization.jsonObject(with: data) else {
            return "<\(data.count) bytes>"
        }

        object = redactSecrets(in: object)

        guard let safeData = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        ),
        let safeString = String(data: safeData, encoding: .utf8) else {
            return "<redacted JSON>"
        }

        return safeString
    }

    private func redactSecrets(
        in value: Any
    ) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, item in
                let key = item.key.lowercased()

                if key.contains("password") ||
                    key.contains("token") ||
                    key.contains("secret") {
                    result[item.key] = "***"
                } else {
                    result[item.key] = redactSecrets(in: item.value)
                }
            }
        }

        if let array = value as? [Any] {
            return array.map { redactSecrets(in: $0) }
        }

        return value
    }
}

private extension Data {
    mutating func appendMultipartString(
        _ string: String
    ) {
        guard let data = string.data(using: .utf8) else {
            return
        }

        append(data)
    }
}
