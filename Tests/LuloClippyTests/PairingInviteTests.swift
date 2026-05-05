import Foundation
import Testing
@testable import LuloClippy

@Suite("Pairing invite parsing")
struct PairingInviteTests {
    @Test func decodesPrefixedBase64Invite() throws {
        let json = #"{"version":1,"endpoint":"https://pinchys-mac-mini.taild71e14.ts.net/","token":"test-token","session":"agent:main:clippy:remote","agentTarget":"openclaw/default","label":"Ken's Pinchy"}"#
        let payload = Data(json.utf8).base64EncodedString()

        let invite = try PairingInviteParser.decode("\(PairingInvite.clearPrefix)\(payload)")

        #expect(invite.endpoint == "https://pinchys-mac-mini.taild71e14.ts.net/")
        #expect(invite.token == "test-token")
        #expect(invite.session == "agent:main:clippy:remote")
        #expect(invite.agentTarget == "openclaw/default")
        #expect(invite.label == "Ken's Pinchy")
    }

    @Test func decodesRawJSONInvite() throws {
        let invite = try PairingInviteParser.decode(#"{"version":1,"endpoint":"http://100.64.0.1:18789","token":"test-token"}"#)

        #expect(invite.endpoint == "http://100.64.0.1:18789")
        #expect(invite.token == "test-token")
    }

    @Test func rejectsEncryptedInviteWithoutPassphrase() {
        #expect(throws: PairingInviteError.encryptedInviteNeedsPassphrase) {
            _ = try PairingInviteParser.decode("\(PairingInvite.encryptedPrefix)abc123")
        }
    }

    @Test func decryptsOpenSSLEncryptedInvite() throws {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/openssl") else { return }
        let json = #"{"version":1,"endpoint":"https://pinchys-mac-mini.taild71e14.ts.net/","token":"encrypted-test-token"}"#
        let cipher = try encryptWithOpenSSL(json, passphrase: "banana")

        let invite = try PairingInviteParser.decodeEncrypted("\(PairingInvite.encryptedPrefix)\(cipher)", passphrase: "banana")

        #expect(invite.token == "encrypted-test-token")
        #expect(invite.endpoint == "https://pinchys-mac-mini.taild71e14.ts.net/")
    }

    private func encryptWithOpenSSL(_ plaintext: String, passphrase: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = [
            "enc", "-aes-256-cbc", "-pbkdf2", "-iter", "200000",
            "-salt", "-a", "-A", "-pass", "env:TEST_INVITE_PASSPHRASE"
        ]
        process.environment = ProcessInfo.processInfo.environment.merging([
            "TEST_INVITE_PASSPHRASE": passphrase
        ]) { _, new in new }
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(Data(plaintext.utf8))
        input.fileHandleForWriting.closeFile()
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
