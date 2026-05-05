import Foundation

struct PairingInvite: Codable, Equatable, Sendable {
    static let clearPrefix = "APEASSIST-INVITE-v1:"
    static let encryptedPrefix = "APEASSIST-INVITE-ENC-v1:"

    let version: Int
    let endpoint: String
    let token: String
    let session: String?
    let agentTarget: String?
    let label: String?
    let createdAt: String?

    init(
        version: Int = 1,
        endpoint: String,
        token: String,
        session: String? = nil,
        agentTarget: String? = nil,
        label: String? = nil,
        createdAt: String? = nil
    ) {
        self.version = version
        self.endpoint = endpoint
        self.token = token
        self.session = session
        self.agentTarget = agentTarget
        self.label = label
        self.createdAt = createdAt
    }

    var normalizedEndpoint: String {
        endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func validate() throws {
        guard version == 1 else { throw PairingInviteError.unsupportedVersion(version) }
        guard URL(string: normalizedEndpoint) != nil,
              normalizedEndpoint.hasPrefix("http://") || normalizedEndpoint.hasPrefix("https://")
        else { throw PairingInviteError.invalidEndpoint }
        guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PairingInviteError.missingToken
        }
    }
}

enum PairingInviteError: Error, LocalizedError, Equatable {
    case emptyInput
    case encryptedInviteNeedsPassphrase
    case invalidFormat
    case invalidBase64
    case invalidJSON
    case unsupportedVersion(Int)
    case invalidEndpoint
    case missingToken
    case opensslUnavailable
    case decryptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Paste a pairing invite first."
        case .encryptedInviteNeedsPassphrase:
            return "This invite is passphrase protected. Enter the passphrase Ken shared, then import again."
        case .invalidFormat:
            return "That does not look like an ApeAssist pairing invite."
        case .invalidBase64:
            return "The pairing invite payload is not valid base64."
        case .invalidJSON:
            return "The pairing invite JSON could not be decoded."
        case let .unsupportedVersion(version):
            return "Unsupported pairing invite version: \(version)."
        case .invalidEndpoint:
            return "The pairing invite endpoint is invalid."
        case .missingToken:
            return "The pairing invite is missing a Gateway token."
        case .opensslUnavailable:
            return "Could not find /usr/bin/openssl to decrypt this invite."
        case let .decryptionFailed(message):
            return "Invite decryption failed: \(message)"
        }
    }
}

enum PairingInviteParser {
    static func decode(_ input: String) throws -> PairingInvite {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PairingInviteError.emptyInput }
        if trimmed.hasPrefix(PairingInvite.encryptedPrefix) {
            throw PairingInviteError.encryptedInviteNeedsPassphrase
        }

        let payload: String
        if trimmed.hasPrefix(PairingInvite.clearPrefix) {
            payload = String(trimmed.dropFirst(PairingInvite.clearPrefix.count))
        } else if trimmed.hasPrefix("{") {
            return try decodeJSON(Data(trimmed.utf8))
        } else {
            payload = trimmed
        }

        let normalizedPayload = payload
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
        guard let data = Data(base64Encoded: normalizedPayload) else {
            throw PairingInviteError.invalidBase64
        }
        return try decodeJSON(data)
    }

    static func decodeEncrypted(_ input: String, passphrase: String) throws -> PairingInvite {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix(PairingInvite.encryptedPrefix) else {
            return try decode(input)
        }
        let cipherText = String(trimmed.dropFirst(PairingInvite.encryptedPrefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cipherText.isEmpty else { throw PairingInviteError.invalidFormat }
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/openssl") else {
            throw PairingInviteError.opensslUnavailable
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = [
            "enc", "-aes-256-cbc", "-pbkdf2", "-iter", "200000",
            "-d", "-a", "-salt", "-pass", "env:APEASSIST_INVITE_PASSPHRASE"
        ]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "APEASSIST_INVITE_PASSPHRASE": passphrase
        ]) { _, new in new }

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        inputPipe.fileHandleForWriting.write(Data((cipherText + "\n").utf8))
        inputPipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorText = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            throw PairingInviteError.decryptionFailed(errorText.isEmpty ? "wrong passphrase or corrupt payload" : errorText)
        }
        return try decodeJSON(output)
    }

    private static func decodeJSON(_ data: Data) throws -> PairingInvite {
        do {
            let invite = try JSONDecoder().decode(PairingInvite.self, from: data)
            try invite.validate()
            return invite
        } catch let error as PairingInviteError {
            throw error
        } catch DecodingError.dataCorrupted, DecodingError.keyNotFound, DecodingError.typeMismatch, DecodingError.valueNotFound {
            throw PairingInviteError.invalidJSON
        } catch {
            throw PairingInviteError.invalidJSON
        }
    }
}
