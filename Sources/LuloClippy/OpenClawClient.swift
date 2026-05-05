import Foundation

/// Client-side bridge from the macOS Clippy app to a local/remote OpenClaw Gateway.
///
/// The safest implemented path is the Gateway's OpenResponses-compatible HTTP API:
///   POST {httpBaseURL}/v1/responses
/// This endpoint is documented locally in OpenClaw docs, but is disabled by default until
/// `gateway.http.endpoints.responses.enabled` is true.
public final class OpenClawClient: Sendable {
    public struct Configuration: Sendable, Equatable {
        /// HTTP base URL for OpenAI/OpenResponses-compatible Gateway endpoints.
        /// Example: http://127.0.0.1:18789
        public var httpBaseURL: URL

        /// Gateway WebSocket control-plane URL for the future native RPC/stream bridge.
        /// Example: ws://127.0.0.1:18789
        public var webSocketURL: URL

        /// OpenClaw agent target. Examples: "openclaw", "openclaw/default", "openclaw/main".
        public var agentTarget: String

        /// Stable session target/key for the Clippy app. Used as both `user` and
        /// `x-openclaw-session-key` so repeated turns share context.
        public var sessionTarget: String

        /// Optional Gateway bearer token/password. Do not persist real values in source.
        public var authToken: String?

        /// Optional backend model override, e.g. "openai/gpt-5.5".
        public var modelOverride: String?

        public var timeout: TimeInterval

        public init(
            httpBaseURL: URL = URL(string: "http://127.0.0.1:18789")!,
            webSocketURL: URL = URL(string: "ws://127.0.0.1:18789")!,
            agentTarget: String = "openclaw/default",
            sessionTarget: String = "agent:main:clippy:local",
            authToken: String? = nil,
            modelOverride: String? = nil,
            timeout: TimeInterval = 90
        ) {
            self.httpBaseURL = httpBaseURL
            self.webSocketURL = webSocketURL
            self.agentTarget = agentTarget
            self.sessionTarget = sessionTarget
            self.authToken = authToken
            self.modelOverride = modelOverride
            self.timeout = timeout
        }
    }

    public struct MessageResponse: Sendable, Equatable {
        public let id: String?
        public let text: String
        public let media: [MediaArtifact]
        public let rawJSON: Data
    }

    public struct ConnectivityCheck: Sendable, Equatable {
        public let ok: Bool
        public let statusCode: Int?
        public let message: String
        public let backendOnline: Bool
        public let authOK: Bool
        public let responsesStatus: ResponsesEndpointStatus

        public init(
            ok: Bool,
            statusCode: Int?,
            message: String,
            backendOnline: Bool,
            authOK: Bool,
            responsesStatus: ResponsesEndpointStatus
        ) {
            self.ok = ok
            self.statusCode = statusCode
            self.message = message
            self.backendOnline = backendOnline
            self.authOK = authOK
            self.responsesStatus = responsesStatus
        }
    }

    public enum ResponsesEndpointStatus: Sendable, Equatable {
        case available
        case disabledOrMissing(Int?)
        case authMissingOrInvalid(Int)
        case unknown(String)

        public var label: String {
            switch self {
            case .available:
                return "/v1/responses ready"
            case let .disabledOrMissing(status):
                return "/v1/responses unavailable" + (status.map { " (HTTP \($0))" } ?? "")
            case let .authMissingOrInvalid(status):
                return "Auth issue for /v1/responses (HTTP \(status))"
            case let .unknown(message):
                return "/v1/responses uncertain: \(message)"
            }
        }

        public var isUsable: Bool {
            if case .available = self { return true }
            return false
        }
    }

    public enum ClientError: Error, LocalizedError, Sendable, Equatable {
        case invalidHTTPStatus(Int, String)
        case emptyAssistantText
        case malformedResponse(String)
        case transport(String)

        public var errorDescription: String? {
            switch self {
            case let .invalidHTTPStatus(status, body):
                let hint: String
                switch status {
                case 401, 403:
                    hint = " Check the Gateway auth mode/token in Settings."
                case 404, 405, 501:
                    hint = " The /v1/responses endpoint may be disabled; enable gateway.http.endpoints.responses.enabled."
                default:
                    hint = ""
                }
                return "OpenClaw Gateway returned HTTP \(status): \(body)\(hint)"
            case .emptyAssistantText:
                return "OpenClaw response did not include assistant text."
            case let .malformedResponse(message):
                return "Malformed OpenClaw response: \(message)"
            case let .transport(message):
                return "Could not reach OpenClaw Gateway: \(message)"
            }
        }
    }

    private let configuration: Configuration
    private let urlSession: URLSession
    private let jsonEncoder: JSONEncoder
    private let jsonDecoder: JSONDecoder

    public init(configuration: Configuration = Configuration(), urlSession: URLSession? = nil) {
        self.configuration = configuration
        if let urlSession {
            self.urlSession = urlSession
        } else {
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = configuration.timeout
            sessionConfig.timeoutIntervalForResource = configuration.timeout
            self.urlSession = URLSession(configuration: sessionConfig)
        }
        self.jsonEncoder = JSONEncoder()
        self.jsonDecoder = JSONDecoder()
    }

    /// Sends one user message to OpenClaw and returns the final assistant text.
    ///
    /// Uses `POST /v1/responses` with `stream: false` for a simple, safe first live path.
    /// If the Gateway has not enabled this endpoint, callers surface a clear 404/405/501 hint.
    public func sendMessage(_ text: String, instructions: String? = nil) async throws -> MessageResponse {
        var request = baseRequest(path: "v1/responses")
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ResponsesRequest(
            model: configuration.agentTarget,
            input: text,
            instructions: instructions,
            stream: false,
            user: configuration.sessionTarget
        )
        request.httpBody = try jsonEncoder.encode(payload)

        let data = try await perform(request)
        return try Self.decodeMessageResponse(from: data, decoder: jsonDecoder)
    }

    /// Lightweight Settings probe. It only calls localhost/private Gateway HTTP metadata and does
    /// not create/send an agent chat turn. A successful response means base URL/auth are OK; then
    /// an OPTIONS probe checks whether `/v1/responses` appears enabled without creating a response.
    public func checkConnectivity() async -> ConnectivityCheck {
        var modelsRequest = baseRequest(path: "v1/models")
        modelsRequest.httpMethod = "GET"

        let modelsResult = await status(for: modelsRequest)
        guard modelsResult.reachedTransport else {
            return ConnectivityCheck(
                ok: false,
                statusCode: nil,
                message: "Backend offline: \(modelsResult.message)",
                backendOnline: false,
                authOK: false,
                responsesStatus: .unknown(modelsResult.message)
            )
        }

        let authOK = !(modelsResult.statusCode == 401 || modelsResult.statusCode == 403)
        guard authOK else {
            return ConnectivityCheck(
                ok: false,
                statusCode: modelsResult.statusCode,
                message: "Backend online, but Gateway auth failed. Save the bearer token in Settings.",
                backendOnline: true,
                authOK: false,
                responsesStatus: .authMissingOrInvalid(modelsResult.statusCode ?? 401)
            )
        }

        var responsesRequest = baseRequest(path: "v1/responses")
        responsesRequest.httpMethod = "OPTIONS"
        let responsesResult = await status(for: responsesRequest)
        let responsesStatus = Self.classifyResponsesProbe(statusCode: responsesResult.statusCode, reachedTransport: responsesResult.reachedTransport, message: responsesResult.message)
        let backendOnline = modelsResult.statusCode.map { (200..<500).contains($0) } ?? true
        let modelsOK = modelsResult.statusCode.map { (200..<300).contains($0) } ?? false
        let ok = backendOnline && authOK && responsesStatus.isUsable

        let modelMessage: String
        if modelsOK {
            modelMessage = "Backend online; auth OK."
        } else if let code = modelsResult.statusCode {
            modelMessage = "Backend online, but /v1/models returned HTTP \(code)."
        } else {
            modelMessage = "Backend online."
        }

        return ConnectivityCheck(
            ok: ok,
            statusCode: responsesResult.statusCode ?? modelsResult.statusCode,
            message: "\(modelMessage) \(responsesStatus.label)",
            backendOnline: backendOnline,
            authOK: true,
            responsesStatus: responsesStatus
        )
    }

    public static func classifyResponsesProbe(statusCode: Int?, reachedTransport: Bool = true, message: String = "") -> ResponsesEndpointStatus {
        guard reachedTransport else { return .unknown(message) }
        guard let statusCode else { return .unknown(message) }
        switch statusCode {
        case 200..<300, 204, 405:
            return .available
        case 401, 403:
            return .authMissingOrInvalid(statusCode)
        case 404, 501:
            return .disabledOrMissing(statusCode)
        default:
            return .unknown("HTTP \(statusCode)")
        }
    }

    // MARK: - Future native Gateway WS RPC plan

    /// Placeholder for a future native WS control-plane implementation.
    ///
    /// Native Gateway route discovered locally:
    /// - WebSocket root: ws://127.0.0.1:18789 (or wss:// behind TLS/proxy)
    /// - First frame must be a JSON `connect` RPC with role `operator` and scopes
    ///   `["operator.read", "operator.write"]`.
    /// - Send messages with `sessions.send` params:
    ///   `{ key, message, idempotencyKey }` after the target session exists.
    /// - Subscribe to streaming transcript updates with `sessions.messages.subscribe` and listen
    ///   for `session.message` / `session.tool` events.
    ///
    /// This is intentionally not implemented yet because token/device-pairing UX should be decided
    /// before shipping a full operator-scope WS client in the app.
    public func makeWebSocketTask() -> URLSessionWebSocketTask {
        var request = URLRequest(url: configuration.webSocketURL)
        if let token = configuration.authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return urlSession.webSocketTask(with: request)
    }

    private func baseRequest(path: String) -> URLRequest {
        var request = URLRequest(url: endpointURL(path: path))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(configuration.sessionTarget, forHTTPHeaderField: "x-openclaw-session-key")
        if let modelOverride = configuration.modelOverride, !modelOverride.isEmpty {
            request.setValue(modelOverride, forHTTPHeaderField: "x-openclaw-model")
        }
        if let token = configuration.authToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ClientError.malformedResponse("response was not HTTPURLResponse")
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
                throw ClientError.invalidHTTPStatus(httpResponse.statusCode, Self.truncatedBody(body))
            }
            return data
        } catch let error as ClientError {
            throw error
        } catch let error as URLError {
            throw ClientError.transport(error.localizedDescription)
        } catch {
            throw ClientError.transport(error.localizedDescription)
        }
    }

    private func status(for request: URLRequest) async -> (reachedTransport: Bool, statusCode: Int?, message: String) {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (true, nil, "response was not HTTPURLResponse")
            }
            let body = String(data: data, encoding: .utf8).map { Self.truncatedBody($0) } ?? ""
            return (true, httpResponse.statusCode, body)
        } catch let error as URLError {
            return (false, nil, error.localizedDescription)
        } catch {
            return (false, nil, error.localizedDescription)
        }
    }

    private func endpointURL(path: String) -> URL {
        let base = configuration.httpBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/\(path)")!
    }

    private static func truncatedBody(_ body: String, maxLength: Int = 800) -> String {
        guard body.count > maxLength else { return body }
        return String(body.prefix(maxLength)) + "…"
    }

    static func decodeMessageResponse(from data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> MessageResponse {
        do {
            let decoded = try decoder.decode(ResponsesResponse.self, from: data)
            let assistantText = decoded.assistantText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let media = MediaExtractor.extract(text: assistantText, rawJSON: data)
            guard !assistantText.isEmpty || !media.isEmpty else {
                throw ClientError.emptyAssistantText
            }
            let visibleText = assistantText.isEmpty ? "Generated media is ready." : assistantText
            return MessageResponse(id: decoded.id, text: visibleText, media: media, rawJSON: data)
        } catch let error as ClientError {
            throw error
        } catch {
            throw ClientError.malformedResponse(error.localizedDescription)
        }
    }
}

// MARK: - Wire models

private struct ResponsesRequest: Encodable {
    let model: String
    let input: String
    let instructions: String?
    let stream: Bool
    let user: String
}

private struct ResponsesResponse: Decodable {
    let id: String?
    let outputText: String?
    let output: [OutputItem]?
    let choices: [Choice]?

    enum CodingKeys: String, CodingKey {
        case id
        case outputText = "output_text"
        case output
        case choices
    }

    var assistantText: String? {
        if let outputText, !outputText.isEmpty { return outputText }

        let outputText = output?
            .filter { $0.type == nil || $0.type == "message" || $0.type == "output_text" }
            .compactMap(\.text)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        if let outputText, !outputText.isEmpty { return outputText }

        let choiceText = choices?
            .compactMap { $0.message?.content }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        if let choiceText, !choiceText.isEmpty { return choiceText }

        return nil
    }
}

private struct OutputItem: Decodable {
    let type: String?
    let role: String?
    let content: [ContentItem]?
    let textValue: String?

    enum CodingKeys: String, CodingKey {
        case type
        case role
        case content
        case textValue = "text"
    }

    var text: String? {
        if let textValue, !textValue.isEmpty { return textValue }
        let chunks = content?.compactMap(\.text).filter { !$0.isEmpty } ?? []
        return chunks.isEmpty ? nil : chunks.joined(separator: "")
    }
}

private struct ContentItem: Decodable {
    let type: String?
    let text: String?
}

private struct Choice: Decodable {
    let message: ChoiceMessage?
}

private struct ChoiceMessage: Decodable {
    let role: String?
    let content: String?
}
