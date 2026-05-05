import Foundation
import Testing
@testable import LuloClippy

@Suite("OpenClaw client response parsing")
struct OpenClawClientTests {
    @Test func parsesTopLevelOutputText() throws {
        let data = #"{"id":"resp_1","output_text":"Hello from OpenClaw"}"#.data(using: .utf8)!

        let response = try OpenClawClient.decodeMessageResponse(from: data)

        #expect(response.id == "resp_1")
        #expect(response.text == "Hello from OpenClaw")
    }

    @Test func parsesMessageContentOutputText() throws {
        let data = #"""
        {
          "id": "resp_2",
          "output": [
            {
              "type": "message",
              "role": "assistant",
              "content": [
                { "type": "output_text", "text": "Hello" },
                { "type": "output_text", "text": " Ken" }
              ]
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try OpenClawClient.decodeMessageResponse(from: data)

        #expect(response.id == "resp_2")
        #expect(response.text == "Hello Ken")
    }

    @Test func extractsMediaFromAssistantText() throws {
        let data = #"{"id":"resp_media","output_text":"Here you go.\nMEDIA: /tmp/generated-image.png\n![preview](https://example.com/render.webp)"}"#.data(using: .utf8)!

        let response = try OpenClawClient.decodeMessageResponse(from: data)

        #expect(response.text.contains("Here you go"))
        #expect(response.media.map(\.locator).contains("/tmp/generated-image.png"))
        #expect(response.media.map(\.locator).contains("https://example.com/render.webp"))
    }

    @Test func extractsMediaFromResponseJSONFields() throws {
        let data = #"{"id":"resp_json_media","output_text":"Created it.","output":[{"type":"message","content":[{"type":"output_image","image_url":"file:///tmp/clippy-output.jpg"}]}]}"#.data(using: .utf8)!

        let response = try OpenClawClient.decodeMessageResponse(from: data)

        #expect(response.media.map(\.locator).contains("file:///tmp/clippy-output.jpg"))
    }

    @Test func allowsMediaOnlyResponseWithVisibleFallbackText() throws {
        let data = #"{"id":"resp_media_only","output":[{"type":"message","content":[{"type":"output_image","url":"https://example.com/art.png"}]}]}"#.data(using: .utf8)!

        let response = try OpenClawClient.decodeMessageResponse(from: data)

        #expect(response.text == "Generated media is ready.")
        #expect(response.media.map(\.locator).contains("https://example.com/art.png"))
    }

    @Test func emptyAssistantTextThrowsClearError() throws {
        let data = #"{"id":"resp_empty","output":[{"type":"function_call","name":"noop"}]}"#.data(using: .utf8)!

        #expect(throws: OpenClawClient.ClientError.self) {
            _ = try OpenClawClient.decodeMessageResponse(from: data)
        }
    }

    @Test func sendMessagePostsDocumentedResponsesShapeAndAuthHeaders() async throws {
        final class MockURLProtocol: URLProtocol {
            nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

            override class func canInit(with request: URLRequest) -> Bool { true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

            override func startLoading() {
                guard let handler = Self.requestHandler else {
                    client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                    return
                }

                do {
                    let (response, data) = try handler(request)
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                    client?.urlProtocol(self, didLoad: data)
                    client?.urlProtocolDidFinishLoading(self)
                } catch {
                    client?.urlProtocol(self, didFailWithError: error)
                }
            }

            override func stopLoading() {}

            static func readBodyStream(_ stream: InputStream?) -> Data {
                guard let stream else { return Data() }
                stream.open()
                defer { stream.close() }

                var data = Data()
                let bufferSize = 1_024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                defer { buffer.deallocate() }

                while stream.hasBytesAvailable {
                    let count = stream.read(buffer, maxLength: bufferSize)
                    guard count > 0 else { break }
                    data.append(buffer, count: count)
                }
                return data
            }
        }

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        defer { session.invalidateAndCancel() }

        MockURLProtocol.requestHandler = { request in
            #expect(request.url?.absoluteString == "http://127.0.0.1:18789/v1/responses")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
            #expect(request.value(forHTTPHeaderField: "x-openclaw-session-key") == "agent:main:clippy:local")
            #expect(request.value(forHTTPHeaderField: "x-openclaw-model") == "openai/test-model")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

            let body = request.httpBody ?? MockURLProtocol.readBodyStream(request.httpBodyStream)
            let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(json["model"] as? String == "openclaw/default")
            #expect(json["input"] as? String == "hello from clippy")
            #expect(json["stream"] as? Bool == false)
            #expect(json["user"] as? String == "agent:main:clippy:local")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, #"{"id":"resp_live","output_text":"Visible reply"}"#.data(using: .utf8)!)
        }
        defer { MockURLProtocol.requestHandler = nil }

        let client = OpenClawClient(
            configuration: .init(
                authToken: "test-token",
                modelOverride: "openai/test-model"
            ),
            urlSession: session
        )

        let response = try await client.sendMessage("hello from clippy")

        #expect(response.text == "Visible reply")
        #expect(response.media.isEmpty)
    }

    @Test func configurationDefaultsStayLocalAndPostingEnabled() {
        let suiteName = "LuloClippyTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let config = OpenClawBridgeConfiguration.current(environment: [:], defaults: suite, tokenStore: MockTokenStore())

        #expect(config.httpBaseURL.absoluteString == SettingsKey.defaultEndpoint)
        #expect(config.webSocketURL.absoluteString == SettingsKey.defaultWebSocketURL)
        #expect(config.sessionTarget == SettingsKey.defaultSession)
        #expect(config.agentTarget == SettingsKey.defaultAgentTarget)
        #expect(config.postingEnabled == true)
    }

    @Test func configurationUsesKeychainTokenAndMigratesLegacyDefaultsToken() {
        let suiteName = "LuloClippyTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        suite.set("legacy-secret", forKey: SettingsKey.token)
        let tokenStore = MockTokenStore()

        let config = OpenClawBridgeConfiguration.current(environment: [:], defaults: suite, tokenStore: tokenStore)

        #expect(config.bearerToken == "legacy-secret")
        #expect(tokenStore.loadToken() == "legacy-secret")
        #expect(suite.string(forKey: SettingsKey.token) == nil)
    }

    @Test func environmentTokenOverridesKeychainToken() {
        let tokenStore = MockTokenStore(initialToken: "keychain-secret")

        let config = OpenClawBridgeConfiguration.current(environment: ["LULO_OPENCLAW_TOKEN": "env-secret"], defaults: UserDefaults(suiteName: "LuloClippyTests-\(UUID().uuidString)")!, tokenStore: tokenStore)

        #expect(config.bearerToken == "env-secret")
    }

    @Test func classifiesResponsesProbeStatuses() {
        #expect(OpenClawClient.classifyResponsesProbe(statusCode: 204).isUsable)
        #expect(OpenClawClient.classifyResponsesProbe(statusCode: 405).isUsable)
        #expect(OpenClawClient.classifyResponsesProbe(statusCode: 404) == .disabledOrMissing(404))
        #expect(OpenClawClient.classifyResponsesProbe(statusCode: 401) == .authMissingOrInvalid(401))
    }
}

private final class MockTokenStore: GatewayTokenStore, @unchecked Sendable {
    private var token: String?

    init(initialToken: String? = nil) {
        self.token = initialToken
    }

    func loadToken() -> String? { token }
    func saveToken(_ token: String) throws { self.token = token }
    func deleteToken() throws { token = nil }
}
