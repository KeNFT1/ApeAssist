import Foundation
import Security

protocol GatewayTokenStore: Sendable {
    func loadToken() -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
}

enum GatewayTokenStoreError: Error, LocalizedError, Sendable, Equatable {
    case keychainStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .keychainStatus(status):
            return "Keychain operation failed (OSStatus \(status))."
        }
    }
}

struct KeychainGatewayTokenStore: GatewayTokenStore {
    static let service = "app.apeassist.gateway"
    static let account = "openclaw-bearer-token"

    let service: String
    let account: String

    init(service: String = Self.service, account: String = Self.account) {
        self.service = service
        self.account = account
    }

    func loadToken() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty
        else { return nil }
        return token
    }

    func saveToken(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try deleteToken()
            return
        }

        let data = Data(trimmed.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(baseQuery() as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        if updateStatus != errSecItemNotFound {
            throw GatewayTokenStoreError.keychainStatus(updateStatus)
        }

        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw GatewayTokenStoreError.keychainStatus(addStatus)
        }
    }

    func deleteToken() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw GatewayTokenStoreError.keychainStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum GatewayTokenMigration {
    static func migrateUserDefaultsTokenIfNeeded(
        defaults: UserDefaults = .standard,
        tokenStore: GatewayTokenStore = KeychainGatewayTokenStore()
    ) {
        guard let legacyToken = defaults.string(forKey: SettingsKey.token)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !legacyToken.isEmpty
        else { return }

        do {
            if tokenStore.loadToken()?.isEmpty ?? true {
                try tokenStore.saveToken(legacyToken)
            }
            defaults.removeObject(forKey: SettingsKey.token)
        } catch {
            // Keep the legacy value if Keychain is unavailable so the user can retry/save manually.
        }
    }
}
