import Foundation

// MARK: - Backend Configuration

enum GRUServerConfiguration {

    static let defaultPort = 8081

    private static let customHostKey = "gru.server.customHost.v10"
    private static let customPortKey = "gru.server.customPort.v1"
    private static let productionHTTPKey = "GRUProductionHTTPBaseURL"
    private static let productionWebSocketKey = "GRUProductionWebSocketURL"

    /*
     Debug simulator -> localhost.
     Debug physical iPhone -> LAN IP patched by install.command.
     Release -> HTTPS/WSS values from generated Info.plist keys when configured.
     */
    // Last known LAN address of the development Mac.  The Simulator always
    // uses 127.0.0.1; a physical iPhone can override this in Backend GRU
    // settings without rebuilding the app.
    private static let physicalDeviceHost = "192.168.31.61"

    static var port: Int {
        let configured = UserDefaults.standard.integer(forKey: customPortKey)
        return (1...65_535).contains(configured) ? configured : defaultPort
    }

    private static var productionHTTPBaseURL: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: productionHTTPKey) as? String else {
            return nil
        }
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.lowercased().hasPrefix("https://"), URL(string: clean) != nil else {
            return nil
        }
        return clean.hasSuffix("/") ? String(clean.dropLast()) : clean
    }

    private static var productionWebSocketURL: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: productionWebSocketKey) as? String else {
            return nil
        }
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.lowercased().hasPrefix("wss://"), URL(string: clean) != nil else {
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
            return customHost
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
        return productionHTTPBaseURL == nil ? "Release • production URL not configured" : "Production"
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
        let cleanValue = normalizedHost(value)
        guard isValidHost(cleanValue) else { return false }
        UserDefaults.standard.set(cleanValue, forKey: customHostKey)
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
        var cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if let url = URL(string: cleanValue), let urlHost = url.host {
            cleanValue = urlHost
        }

        if cleanValue.hasSuffix("/") { cleanValue.removeLast() }

        if let colonIndex = cleanValue.lastIndex(of: ":"),
           cleanValue[colonIndex...].dropFirst().allSatisfy({ $0.isNumber }) {
            cleanValue = String(cleanValue[..<colonIndex])
        }

        return cleanValue
    }

    private static func isValidHost(_ value: String) -> Bool {
        let cleanValue = normalizedHost(value)
        guard !cleanValue.isEmpty,
              cleanValue.count <= 253,
              !cleanValue.contains("/"),
              !cleanValue.contains(" ") else {
            return false
        }

        return cleanValue.allSatisfy {
            $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == ":"
        }
    }
}

struct GRUServerProbeResult {
    let isReachable: Bool
    let statusCode: Int?
    let latencyMilliseconds: Int?
    let message: String
}

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
            return "Некорректный адрес сервера"

        case .invalidResponse:
            return "Некорректный ответ сервера"

        case .unauthorized:
            return "Сессия истекла. Войдите снова"

        case .forbidden:
            return "Доступ запрещён"

        case .notFound:
            return "Запрашиваемые данные не найдены"

        case .serverError(let code):
            return "Ошибка сервера: \(code)"

        case .httpError(let code, let message):

            if message.isEmpty {
                return "HTTP ошибка: \(code)"
            }

            return message

        case .network(let error):

            guard let urlError = error as? URLError else {
                return "Ошибка сети: \(error.localizedDescription)"
            }

            switch urlError.code {

            case .cannotConnectToHost,
                 .cannotFindHost:
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

final class APIClient {

    static let shared =
        APIClient()

    private init() {}

    private var baseURL: String {
        GRUServerConfiguration.httpBaseURL
    }

    // MARK: - Server Probe

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

        guard let url = URL(
            string: GRUServerConfiguration.httpBaseURL + "/chats"
        ) else {

            return GRUServerProbeResult(
                isReachable: false,
                statusCode: nil,
                latencyMilliseconds: nil,
                message: "Некорректный адрес backend"
            )
        }

        var request = URLRequest(
            url: url,
            timeoutInterval: 6
        )

        request.httpMethod = "GET"
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Accept"
        )

        applyAuthorization(
            resolvedToken,
            to: &request
        )

        let startedAt = Date()

        do {
            let (_, response) = try await URLSession.shared.data(
                for: request
            )

            guard let httpResponse = response as? HTTPURLResponse else {
                return GRUServerProbeResult(
                    isReachable: false,
                    statusCode: nil,
                    latencyMilliseconds: nil,
                    message: "Backend ответил в неизвестном формате"
                )
            }

            let latency = Int(
                Date().timeIntervalSince(startedAt) * 1_000
            )

            let message: String

            switch httpResponse.statusCode {
            case 200...299:
                message = "Backend GRU доступен"
            case 401, 403:
                message = "Backend доступен, но нужна новая сессия"
            default:
                message = "Backend доступен, HTTP \(httpResponse.statusCode)"
            }

            return GRUServerProbeResult(
                isReachable: true,
                statusCode: httpResponse.statusCode,
                latencyMilliseconds: latency,
                message: message
            )

        } catch {
            let description =
                (error as? URLError)?.localizedDescription
                ?? error.localizedDescription

            return GRUServerProbeResult(
                isReachable: false,
                statusCode: nil,
                latencyMilliseconds: nil,
                message: "Нет соединения: \(description)"
            )
        }
    }

    // MARK: - JSON / Standard Request

    func request(
        path: String,
        method: String = "GET",
        token: String? = nil,
        body: Data? = nil
    ) async throws -> Data {

        let url =
            try makeURL(
                path: path
            )

        var request =
            URLRequest(
                url: url
            )

        request.httpMethod =
            method

        request.timeoutInterval =
            30

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )

        if body != nil {

            request.setValue(
                "application/json",
                forHTTPHeaderField:
                    "Content-Type"
            )
        }

        applyAuthorization(
            token,
            to: &request
        )

        request.httpBody =
            body

        #if DEBUG

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        print(
            "🌐 \(method) \(url.absoluteString)"
        )

        if token != nil {

            print(
                "🔐 Authorization: Bearer ***"
            )
        }

        if let body {

            print(
                "📤 BODY:",
                debugBodyDescription(
                    body
                )
            )
        }

        #endif

        return try await
            perform(
                request,
                printResponseBody:
                    true
            )
    }

    // MARK: - Multipart Upload

    func uploadMultipart(
        path: String,
        token: String,
        fields: [String: String],
        fileFieldName: String,
        fileName: String,
        mimeType: String,
        fileData: Data
    ) async throws -> Data {

        let url =
            try makeURL(
                path: path
            )

        let boundary =
            "Boundary-\(UUID().uuidString)"

        var body =
            Data()

        for key in fields.keys.sorted() {

            guard let value =
                fields[key]
            else {
                continue
            }

            body.appendMultipartString(
                "--\(boundary)\r\n"
            )

            body.appendMultipartString(
                "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n"
            )

            body.appendMultipartString(
                "\(value)\r\n"
            )
        }

        body.appendMultipartString(
            "--\(boundary)\r\n"
        )

        body.appendMultipartString(
            "Content-Disposition: form-data; name=\"\(fileFieldName)\"; filename=\"\(fileName)\"\r\n"
        )

        body.appendMultipartString(
            "Content-Type: \(mimeType)\r\n\r\n"
        )

        body.append(
            fileData
        )

        body.appendMultipartString(
            "\r\n--\(boundary)--\r\n"
        )

        var request =
            URLRequest(
                url: url
            )

        request.httpMethod =
            "POST"

        request.timeoutInterval =
            60

        request.setValue(
            "application/json",
            forHTTPHeaderField:
                "Accept"
        )

        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField:
                "Content-Type"
        )

        applyAuthorization(
            token,
            to: &request
        )

        request.httpBody =
            body

        #if DEBUG

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        print(
            "🌐 POST \(url.absoluteString)"
        )

        print(
            "🔐 Authorization: Bearer ***"
        )

        print(
            "📤 MULTIPART FIELDS:",
            fields
        )

        print(
            "📎 FILE:",
            fileName,
            "(\(fileData.count) bytes)"
        )

        #endif

        return try await
            perform(
                request,
                printResponseBody:
                    true
            )
    }

    // MARK: - Authenticated Download

    func download(
        path: String,
        token: String
    ) async throws -> Data {

        let url =
            try makeURL(
                path: path
            )

        var request =
            URLRequest(
                url: url
            )

        request.httpMethod =
            "GET"

        request.timeoutInterval =
            60

        request.setValue(
            "*/*",
            forHTTPHeaderField:
                "Accept"
        )

        applyAuthorization(
            token,
            to: &request
        )

        #if DEBUG

        print(
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        )

        print(
            "🖼 GET MEDIA \(url.absoluteString)"
        )

        print(
            "🔐 Authorization: Bearer ***"
        )

        #endif

        return try await
            perform(
                request,
                printResponseBody:
                    false
            )
    }

    // MARK: - Perform

    private func perform(
        _ request: URLRequest,
        printResponseBody: Bool
    ) async throws -> Data {

        do {

            let (
                data,
                response
            ) =
                try await
                    URLSession.shared
                    .data(
                        for: request
                    )

            guard let httpResponse =
                response
                as? HTTPURLResponse
            else {

                throw APIError.invalidResponse
            }

            #if DEBUG

            print(
                "📥 STATUS:",
                httpResponse.statusCode
            )

            if printResponseBody,
               let responseString =
                String(
                    data: data,
                    encoding: .utf8
                ),
               !responseString.isEmpty {

                print(
                    "📥 RESPONSE:",
                    responseString
                )
            }

            print(
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            )

            #endif

            if 200...299 ~=
                httpResponse.statusCode {

                return data
            }

            let serverMessage =
                extractServerMessage(
                    from: data
                )

            if shouldInvalidateSession(
                statusCode:
                    httpResponse.statusCode,
                serverMessage:
                    serverMessage,
                request:
                    request
            ) {

                await invalidateCurrentSession(
                    statusCode:
                        httpResponse.statusCode
                )
            }

            switch httpResponse.statusCode {

            case 401:
                throw APIError.unauthorized

            case 403:

                if TokenStorage.shared.token == nil {
                    throw APIError.unauthorized
                }

                throw APIError.forbidden

            case 404:
                throw APIError.notFound

            case 500...599:

                if !serverMessage.isEmpty {

                    throw APIError.httpError(
                        httpResponse.statusCode,
                        serverMessage
                    )
                }

                throw APIError.serverError(
                    httpResponse.statusCode
                )

            default:

                throw APIError.httpError(
                    httpResponse.statusCode,
                    serverMessage
                )
            }

        } catch let error as APIError {

            throw error

        } catch {

            throw APIError.network(
                error
            )
        }
    }

    // MARK: - Session Invalidation
    private func shouldInvalidateSession(
        statusCode: Int,
        serverMessage: String,
        request: URLRequest
    ) -> Bool {

        
        guard
            request.value(
                forHTTPHeaderField:
                    "Authorization"
            ) != nil
        else {
            return false
        }

        if statusCode == 401 {
            return true
        }

        guard statusCode == 403 else {
            return false
        }

        let normalizedMessage =
            serverMessage
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
                .lowercased()

        let path =
            request.url?.path ?? ""

        

        if path == "/chats" {
            return true
        }

        

        return
            normalizedMessage == "unauthorized" ||
            normalizedMessage.contains("jwt") ||
            normalizedMessage.contains(
                "token expired"
            ) ||
            normalizedMessage.contains(
                "token is expired"
            ) ||
            normalizedMessage.contains(
                "expired token"
            ) ||
            normalizedMessage.contains(
                "invalid token"
            )
    }

    private func invalidateCurrentSession(
        statusCode: Int
    ) async {

        await MainActor.run {
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
        }

        #if DEBUG
        print(
            "🔐 GRU session invalidated due to HTTP \(statusCode)"
        )
        #endif
    }
    // MARK: - URL

    private func makeURL(
        path: String
    ) throws -> URL {

        if let absoluteURL =
            URL(
                string: path
            ),
           absoluteURL.scheme != nil {

            return absoluteURL
        }

        let normalizedPath =
            path.hasPrefix("/")
            ? path
            : "/" + path

        guard let url =
            URL(
                string:
                    baseURL +
                    normalizedPath
            )
        else {

            throw APIError.invalidURL
        }

        return url
    }

    // MARK: - Auth

    private func applyAuthorization(
        _ token: String?,
        to request: inout URLRequest
    ) {

        guard let token,
              !token.isEmpty
        else {

            return
        }

        request.setValue(
            "Bearer \(token)",
            forHTTPHeaderField:
                "Authorization"
        )
    }

    // MARK: - Server Error Message

    private func extractServerMessage(
        from data: Data
    ) -> String {

        guard !data.isEmpty else {
            return ""
        }

        if let json =
            try? JSONSerialization
            .jsonObject(
                with: data
            )
            as? [String: Any] {

            if let message =
                json["message"]
                as? String,
               !message.isEmpty {

                return message
            }

            if let error =
                json["error"]
                as? String,
               !error.isEmpty {

                return error
            }
        }

        if let rawText =
            String(
                data: data,
                encoding: .utf8
            ) {

            let text =
                rawText
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

            if !text.isEmpty {
                return text
            }
        }

        return ""
    }

    // MARK: - Safe Debug Logging

    private func debugBodyDescription(
        _ data: Data
    ) -> String {

        guard var object =
                try? JSONSerialization
                    .jsonObject(
                        with: data
                    )
        else {

            return "<\(data.count) bytes>"
        }

        object =
            redactSecrets(
                in: object
            )

        guard let safeData =
                try? JSONSerialization
                    .data(
                        withJSONObject: object,
                        options: [.sortedKeys]
                    ),
              let safeString =
                String(
                    data: safeData,
                    encoding: .utf8
                )
        else {

            return "<redacted JSON>"
        }

        return safeString
    }

    private func redactSecrets(
        in value: Any
    ) -> Any {

        if let dictionary =
            value as? [String: Any] {

            return dictionary.reduce(
                into: [String: Any]()
            ) {
                result,
                item in

                let normalizedKey =
                    item.key.lowercased()

                if normalizedKey.contains("password") ||
                    normalizedKey.contains("token") ||
                    normalizedKey.contains("secret") {

                    result[item.key] = "***"

                } else {

                    result[item.key] =
                        redactSecrets(
                            in: item.value
                        )
                }
            }
        }

        if let array = value as? [Any] {

            return array.map {
                redactSecrets(
                    in: $0
                )
            }
        }

        return value
    }
}

private extension Data {

    mutating func appendMultipartString(
        _ string: String
    ) {

        guard let data =
            string.data(
                using: .utf8
            )
        else {

            return
        }

        append(
            data
        )
    }
}
